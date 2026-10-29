import 'package:flutter/foundation.dart';

import '../../../core/domain/local_date/local_date.dart';
import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../application/restock_item_use_case.dart';
import '../domain/behavior_profile.dart';
import '../domain/item_lifecycle.dart';
import '../domain/lifecycle_checkpoint.dart';
import '../domain/lifecycle_cycle.dart';
import '../domain/lifecycle_repository.dart';
import '../domain/stock_status.dart';

enum LifecycleTask {
  start,
  restock,
  finish,
  correctDates,
  removeCycle,
  checkpoint,
  correctCount,
  resolveAvailability,
}

enum LifecycleResolutionChoice { finishedNow, finishedEarlier, wrong }

enum ObservationReconciliation { keep, changeDate, remove }

class LifecycleTaskOutcome {
  const LifecycleTaskOutcome(
    this.committed,
    this.message, {
    this.availabilityResolved = true,
  });
  final ItemLifecycle committed;
  final String message;
  final bool availabilityResolved;
}

class _DraftProblem implements Exception {
  const _DraftProblem(this.message);
  final String message;
}

/// Owns the recoverable draft and command state; visible facts remain in streams.
class LifecycleController extends ChangeNotifier {
  LifecycleController({
    required this.repository,
    required this.restockUseCase,
    required this.today,
    required this.expected,
    required this.task,
    LifecycleCycle? cycle,
    LifecycleCheckpoint? checkpoint,
    String? countDraft,
  }) : cycle = cycle ?? expected.activeCycle,
       checkpoint = checkpoint {
    final current = today().toString();
    startText = task == LifecycleTask.correctDates
        ? this.cycle!.startedOn.toString()
        : current;
    finishText = this.cycle?.finishedOn?.toString() ?? current;
    observedText = checkpoint?.observedOn.toString() ?? current;
    countText =
        countDraft ??
        (task == LifecycleTask.restock
            ? ''
            : expected.item.packageCount?.toString() ?? '');
    kind = checkpoint?.kind;
  }
  final LifecycleRepository repository;
  final RestockItemUseCase restockUseCase;
  final LocalDate Function() today;
  final LifecycleTask task;
  ItemLifecycle expected;
  LifecycleCycle? cycle;
  LifecycleCheckpoint? checkpoint;
  LifecycleCheckpointKind? kind;
  late String startText, finishText, observedText, countText;
  LifecycleResolutionChoice? resolution;
  bool busy = false, unavailable = false, destructiveConfirmed = false;
  bool resolvingCount = false;
  Failure? failure;
  String? information;
  LifecycleTaskOutcome? outcome;
  final Map<int, ObservationReconciliation> reconciliationChoices = {};
  final Map<int, String> observationDates = {};
  bool _disposed = false;

  bool get conflict =>
      failure is LifecycleTargetFailure ||
      failure is StaleItemFailure ||
      (failure is LifecycleConflictFailure &&
          !(activeConflict && task == LifecycleTask.correctCount));
  bool get activeConflict =>
      (failure is LifecycleConflictFailure &&
          (failure as LifecycleConflictFailure).cycleId != null) ||
      failure is ActiveLifecycleResolutionFailure;
  bool get storageFailure =>
      failure is DataFailure &&
      failure is! StaleItemFailure &&
      failure is! EntityNotFoundFailure &&
      failure is! ItemArchivedFailure &&
      failure is! ActiveLifecycleResolutionFailure;
  bool get needsResolution =>
      (task == LifecycleTask.restock && expected.activeCycle != null) ||
      task == LifecycleTask.resolveAvailability ||
      resolvingCount;
  bool get destructive =>
      task == LifecycleTask.removeCycle ||
      (needsResolution && resolution == LifecycleResolutionChoice.wrong);
  bool get canSubmit => !busy && !unavailable && !conflict;
  bool get needsReconciliation =>
      failure is LifecycleCheckpointReconciliationFailure;
  List<LifecycleCheckpoint> get ownedCheckpoints => expected.checkpoints
      .where((p) => p.cycleId == cycle?.id)
      .toList(growable: false);
  bool get needsTotal =>
      task == LifecycleTask.correctCount ||
      (task == LifecycleTask.restock &&
          (expected.item.behaviorProfile ==
                  BehaviorProfile.countableReplenishable ||
              expected.item.packageCount != null));

  String get errorMessage => switch (failure) {
    InvalidLifecycleDateFailure() => 'Choose valid dates on or before today. Finish must be on or after Start.',
    LifecycleCheckpointReconciliationFailure() => 'Some progress notes fall outside these dates. Change their dates or explicitly remove them below.',
    LifecycleTargetFailure() || StaleItemFailure() => 'Saved facts changed. Your draft is still here. Review the current observation before retrying.',
    LifecycleConflictFailure() || ActiveLifecycleResolutionFailure() =>
      activeConflict
          ? 'An observation is still active. Resolve it explicitly before recording zero stock or a replacement.'
          : 'Restore this item before changing lifecycle facts. Your draft is still here.',
    LifecycleCountFailure(:final message) ||
    ValidationError(:final message) => message,
    LifecycleProfileFailure() =>
      'This item uses presence only and does not need a lifecycle.',
    ItemArchivedFailure() => 'This item is archived. Restore it from item details before saving. Your draft is retained.',
    EntityNotFoundFailure() =>
      'This item is no longer available. Your entry has not been saved.',
    _ => "Not Saved. Couldn't save this change. Your entry is still here. Retry or keep editing.",
  };

  void changed() {
    if (!_disposed) notifyListeners();
  }

  void keepEditing() {
    if (busy) return;
    failure = null;
    information = null;
    changed();
  }

  void chooseResolution(LifecycleResolutionChoice value) {
    if (busy) return;
    resolution = value;
    destructiveConfirmed = false;
    failure = null;
    if (value == LifecycleResolutionChoice.finishedNow) {
      finishText = today().toString();
    }
    changed();
  }

  Future<void> resolveCount() async {
    if (busy) return;
    if (int.tryParse(countText.trim()) != 0) {
      failure = null;
      information = 'Only a zero total needs Finish or removal. Review and save your retained count.';
      changed();
      return;
    }
    if (!await reviewCurrent()) return;
    if (expected.activeCycle == null) {
      information = 'The active observation has changed. Review and save your retained count.';
      changed();
      return;
    }
    cycle = expected.activeCycle;
    resolvingCount = true;
    resolution = null;
    failure = null;
    changed();
  }

  void chooseKind(LifecycleCheckpointKind value) {
    if (busy) return;
    kind = value;
    checkpoint = ownedCheckpoints.where((p) => p.kind == value).firstOrNull;
    observedText = checkpoint?.observedOn.toString() ?? today().toString();
    failure = null;
    changed();
  }

  LocalDate _date(String value, String label) {
    try {
      final parsed = LocalDate.parse(value.trim());
      if (parsed.toString() != value.trim()) throw const FormatException();
      return parsed;
    } on ArgumentError {
      throw _DraftProblem('Enter a valid $label as YYYY-MM-DD.');
    } on FormatException {
      throw _DraftProblem('Enter a valid $label as YYYY-MM-DD.');
    }
  }

  int? get draftTotal {
    final text = countText.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(text)) return null;
    final value = int.tryParse(text);
    return value != null && value >= 0 && value <= 9223372036854775807
        ? value
        : null;
  }

  int _count() {
    final value = draftTotal;
    if (value == null) {
      throw const _DraftProblem(
        'Enter an explicit nonnegative whole current total. Unknown is different from zero.',
      );
    }
    return value;
  }

  CheckpointReconciliation _reconciliation() {
    final corrected = <LifecycleCheckpoint, LocalDate>{};
    final removed = <LifecycleCheckpoint>{};
    for (final p in ownedCheckpoints) {
      switch (reconciliationChoices[p.id] ?? ObservationReconciliation.keep) {
        case ObservationReconciliation.keep:
          break;
        case ObservationReconciliation.changeDate:
          corrected[p] = _date(
            observationDates[p.id] ?? '',
            'progress-note date',
          );
        case ObservationReconciliation.remove:
          removed.add(p);
      }
    }
    return CheckpointReconciliation(corrected: corrected, removed: removed);
  }

  Future<bool> reviewCurrent() async {
    if (busy) return false;
    busy = true;
    changed();
    try {
      final result = await repository.getLifecycle(expected.item.id);
      if (result.isFailure) {
        failure = result.failureOrNull;
        unavailable = failure is EntityNotFoundFailure;
        return false;
      }
      final latest = result.valueOrNull!;
      final selected = cycle == null
          ? null
          : latest.cycles.where((c) => c.id == cycle!.id).firstOrNull;
      final selectedNote = checkpoint == null
          ? null
          : latest.checkpoints.where((p) => p.id == checkpoint!.id).firstOrNull;
      final targetsCycle =
          task != LifecycleTask.correctCount && task != LifecycleTask.start;
      if (latest.item.isArchived ||
          (targetsCycle &&
              cycle != null &&
              (selected == null || selected.isActive != cycle!.isActive)) ||
          (checkpoint != null && selectedNote == null) ||
          (task == LifecycleTask.start && latest.activeCycle != null)) {
        unavailable = true;
        information = latest.item.isArchived
            ? 'This item is archived. Restore it from item details. Your draft is retained.'
            : 'This observation was removed or its completion state changed. Choose an observation again from item details. Your draft is retained.';
        return false;
      }
      expected = latest;
      cycle =
          task == LifecycleTask.correctCount ||
              (task == LifecycleTask.restock && cycle == null)
          ? latest.activeCycle
          : selected;
      checkpoint = selectedNote;
      failure = null;
      destructiveConfirmed = false;
      reconciliationChoices.removeWhere(
        (id, choice) =>
            choice == ObservationReconciliation.remove ||
            !latest.checkpoints.any((p) => p.id == id),
      );
      information = 'Current saved facts reviewed. Your draft is retained. Review progress-note choices again before saving.';
      return true;
    } catch (_) {
      failure = const UnexpectedDataFailure('Read unavailable');
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;
    if (needsResolution && resolution == null) {
      failure = const ValidationError(
        'Choose what happened to the previous observation.',
      );
      changed();
      return false;
    }
    if (destructive && !destructiveConfirmed) {
      failure = const ValidationError(
        'Confirm removal of the named observation and its progress notes.',
      );
      changed();
      return false;
    }
    busy = true;
    failure = null;
    information = null;
    changed();
    try {
      final reconciliation = _reconciliation();
      late Result<ItemLifecycle, Failure> result;
      if (task == LifecycleTask.resolveAvailability || resolvingCount) {
        result = resolution == LifecycleResolutionChoice.wrong
            ? await repository.removeCycle(expected: cycle!)
            : await repository.finish(
                expected: cycle!,
                finishedOn: _date(finishText, 'finish date'),
                today: today(),
                reconciliation: reconciliation,
              );
      } else {
        switch (task) {
          case LifecycleTask.start:
            result = await repository.start(
              itemId: expected.item.id,
              startedOn: _date(startText, 'start date'),
              today: today(),
            );
          case LifecycleTask.restock:
            final activeResolution = !needsResolution
                ? null
                : resolution == LifecycleResolutionChoice.wrong
                ? RemoveErroneousActiveCycle(expected: cycle!)
                : FinishActiveCycle(
                    expected: cycle!,
                    finishedOn: _date(finishText, 'previous finish date'),
                    reconciliation: reconciliation,
                  );
            result = await restockUseCase.execute(
              itemId: expected.item.id,
              startedOn: _date(startText, 'start date'),
              absolutePackageCount: needsTotal ? _count() : null,
              resolution: activeResolution,
            );
          case LifecycleTask.finish:
            result = await repository.finish(
              expected: cycle!,
              finishedOn: _date(finishText, 'finish date'),
              today: today(),
              reconciliation: reconciliation,
            );
          case LifecycleTask.correctDates:
            result = await repository.correctCycleDates(
              expected: cycle!,
              startedOn: _date(startText, 'start date'),
              finishedOn: cycle!.isActive
                  ? null
                  : _date(finishText, 'finish date'),
              today: today(),
              reconciliation: reconciliation,
            );
          case LifecycleTask.removeCycle:
            result = await repository.removeCycle(expected: cycle!);
          case LifecycleTask.checkpoint:
            if (kind == null) {
              throw const _DraftProblem(
                'Choose About half or Nearly finished.',
              );
            }
            result = checkpoint == null
                ? await repository.addCheckpoint(
                    expectedCycle: cycle!,
                    kind: kind!,
                    observedOn: _date(observedText, 'progress-note date'),
                    today: today(),
                  )
                : await repository.correctCheckpoint(
                    itemId: expected.item.id,
                    expected: checkpoint!,
                    observedOn: _date(observedText, 'progress-note date'),
                    today: today(),
                  );
          case LifecycleTask.correctCount:
            result = await repository.correctCount(
              expected: expected.item,
              absoluteCurrentTotal: _count(),
            );
          case LifecycleTask.resolveAvailability:
            throw StateError('Resolution handled above');
        }
      }
      if (result.isFailure) {
        failure = result.failureOrNull;
        unavailable = failure is EntityNotFoundFailure;
        return false;
      }
      final committed = result.valueOrNull!;
      if (resolvingCount && resolution == LifecycleResolutionChoice.wrong) {
        expected = committed;
        cycle = null;
        resolvingCount = false;
        resolution = null;
        destructiveConfirmed = false;
        information = 'Wrong observation removed. Your count has not been saved yet. Review and save the retained count when ready.';
        return false;
      }
      final message = switch (task) {
        LifecycleTask.start => 'Started · observation saved',
        LifecycleTask.restock => 'Restocked · new observation started',
        LifecycleTask.finish => 'Finished · observation saved',
        LifecycleTask.correctDates => 'Observation dates saved',
        LifecycleTask.removeCycle => 'Wrong observation removed',
        LifecycleTask.checkpoint =>
          checkpoint == null
              ? 'Progress note saved'
              : 'Progress note corrected',
        LifecycleTask.correctCount => 'Current count saved',
        LifecycleTask.resolveAvailability =>
          resolution == LifecycleResolutionChoice.wrong
              ? 'Wrong observation removed. Availability is unchanged.'
              : 'Finished · current availability saved',
      };
      outcome = LifecycleTaskOutcome(
        committed,
        message,
        availabilityResolved:
            task != LifecycleTask.resolveAvailability ||
            committed.item.stockStatus == StockStatus.outOfStock,
      );
      return true;
    } on _DraftProblem catch (problem) {
      failure = ValidationError(problem.message);
      return false;
    } catch (_) {
      failure = const UnexpectedDataFailure('Write unavailable');
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
