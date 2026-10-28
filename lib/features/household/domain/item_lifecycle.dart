import '../../../core/domain/local_date/local_date.dart';
import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import 'behavior_profile.dart';
import 'item.dart';
import 'lifecycle_checkpoint.dart';
import 'lifecycle_cycle.dart';
import 'stock_status.dart';

/// Immutable factual snapshot and pure transitions, not a persistence mechanism.
///
/// Callers supply today's calendar date; there is no ambient clock or prediction
/// input. Future repositories must load, validate and persist each transition in
/// one transaction, enforce DB uniqueness, and acknowledge only after commit.
/// IDs are supplied by that boundary. Item technical timestamps are left intact
/// here so the persistence boundary can assign its actual commit-time metadata.
final class ItemLifecycle {
  factory ItemLifecycle({
    required Item item,
    Iterable<LifecycleCycle> cycles = const [],
    Iterable<LifecycleCheckpoint> checkpoints = const [],
  }) {
    final savedCycles = List<LifecycleCycle>.unmodifiable(cycles);
    final savedCheckpoints = List<LifecycleCheckpoint>.unmodifiable(
      checkpoints,
    );
    if (savedCycles.any((cycle) => cycle.itemId != item.id) ||
        savedCycles.map((cycle) => cycle.id).toSet().length !=
            savedCycles.length) {
      throw ArgumentError(
        'Cycles must have unique IDs and belong to this item.',
      );
    }
    if (savedCycles.where((cycle) => cycle.isActive).length > 1) {
      throw ArgumentError(
        'At most one unfinished cycle may belong to an item.',
      );
    }
    if (item.behaviorProfile == BehaviorProfile.durable &&
        savedCycles.isNotEmpty) {
      throw ArgumentError(
        'Durable possessions do not have consumption cycles.',
      );
    }
    final cycleById = {for (final cycle in savedCycles) cycle.id: cycle};
    final kinds = <(int, LifecycleCheckpointKind)>{};
    final ids = <int>{};
    for (final checkpoint in savedCheckpoints) {
      final cycle = cycleById[checkpoint.cycleId];
      if (cycle == null ||
          !ids.add(checkpoint.id) ||
          !kinds.add((checkpoint.cycleId, checkpoint.kind)) ||
          !_within(checkpoint.observedOn, cycle)) {
        throw ArgumentError(
          'Checkpoint identity or cycle boundaries are invalid.',
        );
      }
    }
    return ItemLifecycle._(item, savedCycles, savedCheckpoints);
  }

  ItemLifecycle._(this.item, this.cycles, this.checkpoints);

  final Item item;
  final List<LifecycleCycle> cycles;
  final List<LifecycleCheckpoint> checkpoints;

  LifecycleCycle? get activeCycle {
    for (final cycle in cycles) {
      if (cycle.isActive) return cycle;
    }
    return null;
  }

  /// Factual evidence only; no prediction/confidence is stored or computed here.
  List<LifecycleCycle> get completedCycles =>
      List.unmodifiable(cycles.where((cycle) => !cycle.isActive));

  LifecycleFailure? get _eligibilityFailure {
    if (item.isArchived) {
      return const LifecycleConflictFailure(
        'Restore the item before changing lifecycle facts.',
      );
    }
    if (item.behaviorProfile == BehaviorProfile.durable) {
      return const LifecycleProfileFailure(
        'Durable possessions do not use consumption lifecycles.',
      );
    }
    return null;
  }

  /// Starts observation of existing stock. Unknown count remains unknown.
  Result<ItemLifecycle, LifecycleFailure> start({
    required int cycleId,
    required LocalDate startedOn,
    required LocalDate today,
  }) => _begin(
    cycleId: cycleId,
    startedOn: startedOn,
    today: today,
    currentTotal: item.packageCount,
  );

  /// Countable Restock requires an explicit absolute total, never an increment.
  Result<ItemLifecycle, LifecycleFailure> restock({
    required int cycleId,
    required LocalDate startedOn,
    required LocalDate today,
    int? absolutePackageCount,
  }) {
    final eligibility = _eligibilityFailure;
    if (eligibility != null) return Result.failure(eligibility);
    if (item.behaviorProfile == BehaviorProfile.countableReplenishable &&
        absolutePackageCount == null) {
      return const Result.failure(
        LifecycleCountFailure('Enter the absolute current usable-stock total.'),
      );
    }
    return _begin(
      cycleId: cycleId,
      startedOn: startedOn,
      today: today,
      currentTotal: absolutePackageCount ?? item.packageCount,
    );
  }

  Result<ItemLifecycle, LifecycleFailure> _begin({
    required int cycleId,
    required LocalDate startedOn,
    required LocalDate today,
    required int? currentTotal,
  }) {
    final eligibility = _eligibilityFailure;
    if (eligibility != null) return Result.failure(eligibility);
    final active = activeCycle;
    if (active != null) {
      return Result.failure(
        LifecycleConflictFailure(
          'Resolve the existing active cycle before starting another.',
          cycleId: active.id,
        ),
      );
    }
    if (cycles.any((cycle) => cycle.id == cycleId)) {
      return const Result.failure(
        LifecycleTargetFailure('A cycle with this identity already exists.'),
      );
    }
    final dateFailure = _dates(startedOn, null, today);
    if (dateFailure != null) return Result.failure(dateFailure);
    if (currentTotal != null && currentTotal <= 0) {
      return const Result.failure(
        LifecycleCountFailure(
          'Usable-stock cycles cannot start at zero or less.',
        ),
      );
    }
    return Result.success(
      ItemLifecycle(
        item: item.copyWith(
          stockStatus: StockStatus.inStock,
          packageCount: currentTotal,
        ),
        cycles: [
          ...cycles,
          LifecycleCycle(id: cycleId, itemId: item.id, startedOn: startedOn),
        ],
        checkpoints: checkpoints,
      ),
    );
  }

  /// Explicit Finish/Out, including Finished earlier, targets one active record.
  Result<ItemLifecycle, LifecycleFailure> finish({
    required LifecycleCycle expected,
    required LocalDate finishedOn,
    required LocalDate today,
    Map<int, LocalDate> checkpointDates = const {},
    Set<int> removedCheckpointIds = const {},
  }) {
    final targetFailure = _target(expected);
    if (targetFailure != null) return Result.failure(targetFailure);
    if (!expected.isActive) {
      return const Result.failure(
        LifecycleTargetFailure('This cycle is already finished.'),
      );
    }
    return _changeDates(
      expected: expected,
      startedOn: expected.startedOn,
      finishedOn: finishedOn,
      today: today,
      checkpointDates: checkpointDates,
      removedCheckpointIds: removedCheckpointIds,
      updatedItem: item.copyWith(
        stockStatus: StockStatus.outOfStock,
        packageCount:
            item.behaviorProfile == BehaviorProfile.countableReplenishable ||
                item.packageCount != null
            ? 0
            : null,
      ),
    );
  }

  /// Corrects selected date evidence without changing completion or stock facts.
  ///
  /// Closing uses Finish. Reopening completed evidence is not silently inferred
  /// from a date edit; it requires a separately specified resolution workflow.
  Result<ItemLifecycle, LifecycleFailure> correctCycleDates({
    required LifecycleCycle expected,
    required LocalDate startedOn,
    required LocalDate? finishedOn,
    required LocalDate today,
    Map<int, LocalDate> checkpointDates = const {},
    Set<int> removedCheckpointIds = const {},
  }) {
    final targetFailure = _target(expected);
    if (targetFailure != null) return Result.failure(targetFailure);
    if (expected.isActive != (finishedOn == null)) {
      return const Result.failure(
        LifecycleTargetFailure(
          'Changing completion state requires explicit lifecycle resolution.',
        ),
      );
    }
    return _changeDates(
      expected: expected,
      startedOn: startedOn,
      finishedOn: finishedOn,
      today: today,
      checkpointDates: checkpointDates,
      removedCheckpointIds: removedCheckpointIds,
      updatedItem: item,
    );
  }

  Result<ItemLifecycle, LifecycleFailure> _changeDates({
    required LifecycleCycle expected,
    required LocalDate startedOn,
    required LocalDate? finishedOn,
    required LocalDate today,
    required Map<int, LocalDate> checkpointDates,
    required Set<int> removedCheckpointIds,
    required Item updatedItem,
  }) {
    final dateFailure = _dates(startedOn, finishedOn, today);
    if (dateFailure != null) return Result.failure(dateFailure);
    final ownedIds = checkpoints
        .where((checkpoint) => checkpoint.cycleId == expected.id)
        .map((checkpoint) => checkpoint.id)
        .toSet();
    if (!ownedIds.containsAll(checkpointDates.keys) ||
        !ownedIds.containsAll(removedCheckpointIds) ||
        checkpointDates.keys.any(removedCheckpointIds.contains)) {
      return const Result.failure(
        LifecycleTargetFailure(
          'Reconcile only checkpoints of the selected cycle.',
        ),
      );
    }
    final replacement = LifecycleCycle(
      id: expected.id,
      itemId: expected.itemId,
      startedOn: startedOn,
      finishedOn: finishedOn,
    );
    final revised = <LifecycleCheckpoint>[];
    final invalidIds = <int>[];
    for (final checkpoint in checkpoints) {
      if (checkpoint.cycleId != expected.id) {
        revised.add(checkpoint);
        continue;
      }
      if (removedCheckpointIds.contains(checkpoint.id)) continue;
      final date = checkpointDates[checkpoint.id] ?? checkpoint.observedOn;
      if (date.isAfter(today)) {
        return const Result.failure(
          InvalidLifecycleDateFailure(
            'Factual observations cannot be future-dated.',
          ),
        );
      }
      if (!_within(date, replacement)) invalidIds.add(checkpoint.id);
      revised.add(
        LifecycleCheckpoint(
          id: checkpoint.id,
          cycleId: checkpoint.cycleId,
          kind: checkpoint.kind,
          observedOn: date,
        ),
      );
    }
    if (invalidIds.isNotEmpty) {
      return Result.failure(
        LifecycleCheckpointReconciliationFailure(invalidIds),
      );
    }
    return Result.success(
      ItemLifecycle(
        item: updatedItem,
        cycles: [
          for (final cycle in cycles)
            if (cycle.id == expected.id) replacement else cycle,
        ],
        checkpoints: revised,
      ),
    );
  }

  /// Deliberate removal of erroneous cycle evidence includes its owned notes.
  /// Current availability and unrelated history are retained.
  Result<ItemLifecycle, LifecycleFailure> removeCycle({
    required LifecycleCycle expected,
  }) {
    final targetFailure = _target(expected);
    if (targetFailure != null) return Result.failure(targetFailure);
    return Result.success(
      ItemLifecycle(
        item: item,
        cycles: cycles.where((cycle) => cycle.id != expected.id),
        checkpoints: checkpoints.where(
          (checkpoint) => checkpoint.cycleId != expected.id,
        ),
      ),
    );
  }

  Result<ItemLifecycle, LifecycleFailure> addCheckpoint({
    required LifecycleCycle expectedCycle,
    required LifecycleCheckpoint checkpoint,
    required LocalDate today,
  }) {
    final targetFailure = _target(expectedCycle);
    if (targetFailure != null) return Result.failure(targetFailure);
    if (checkpoint.cycleId != expectedCycle.id) {
      return const Result.failure(
        LifecycleTargetFailure('The checkpoint belongs to a different cycle.'),
      );
    }
    final failure = _checkpointDate(
      checkpoint.observedOn,
      expectedCycle,
      today,
    );
    if (failure != null) return Result.failure(failure);
    if (checkpoints.any(
      (saved) =>
          saved.id == checkpoint.id ||
          (saved.cycleId == checkpoint.cycleId &&
              saved.kind == checkpoint.kind),
    )) {
      return Result.failure(
        LifecycleConflictFailure(
          'Correct the existing observation rather than creating a duplicate.',
          cycleId: expectedCycle.id,
        ),
      );
    }
    return Result.success(
      ItemLifecycle(
        item: item,
        cycles: cycles,
        checkpoints: [...checkpoints, checkpoint],
      ),
    );
  }

  Result<ItemLifecycle, LifecycleFailure> correctCheckpoint({
    required LifecycleCheckpoint expected,
    required LocalDate observedOn,
    required LocalDate today,
  }) {
    final eligibility = _eligibilityFailure;
    if (eligibility != null) return Result.failure(eligibility);
    final matches = checkpoints.where((saved) => saved.id == expected.id);
    if (matches.isEmpty || matches.single != expected) {
      return const Result.failure(
        LifecycleTargetFailure(
          'The selected checkpoint is missing or changed.',
        ),
      );
    }
    final cycle = cycles.singleWhere((cycle) => cycle.id == expected.cycleId);
    final failure = _checkpointDate(observedOn, cycle, today);
    if (failure != null) return Result.failure(failure);
    return Result.success(
      ItemLifecycle(
        item: item,
        cycles: cycles,
        checkpoints: [
          for (final saved in checkpoints)
            if (saved.id == expected.id)
              LifecycleCheckpoint(
                id: saved.id,
                cycleId: saved.cycleId,
                kind: saved.kind,
                observedOn: observedOn,
              )
            else
              saved,
        ],
      ),
    );
  }

  /// Existing unknown count stays null until explicitly reconciled.
  /// Zero while active requires deliberate Finish/Out or erroneous-cycle removal.
  Result<ItemLifecycle, LifecycleFailure> correctCount({
    required int absoluteCurrentTotal,
  }) {
    final eligibility = _eligibilityFailure;
    if (eligibility != null) return Result.failure(eligibility);
    if (absoluteCurrentTotal < 0) {
      return const Result.failure(
        LifecycleCountFailure('Current total must be a nonnegative integer.'),
      );
    }
    final active = activeCycle;
    if (absoluteCurrentTotal == 0 && active != null) {
      return Result.failure(
        LifecycleConflictFailure(
          'Resolve the active cycle explicitly before recording zero stock.',
          cycleId: active.id,
        ),
      );
    }
    return Result.success(
      ItemLifecycle(
        item: item.copyWith(
          packageCount: absoluteCurrentTotal,
          stockStatus: absoluteCurrentTotal == 0
              ? StockStatus.outOfStock
              : StockStatus.inStock,
        ),
        cycles: cycles,
        checkpoints: checkpoints,
      ),
    );
  }

  LifecycleFailure? _target(LifecycleCycle expected) {
    final eligibility = _eligibilityFailure;
    if (eligibility != null) return eligibility;
    final matches = cycles.where((cycle) => cycle.id == expected.id);
    if (expected.itemId != item.id ||
        matches.isEmpty ||
        matches.single != expected) {
      return const LifecycleTargetFailure(
        'The selected cycle is missing or changed. Review saved evidence.',
      );
    }
    return null;
  }

  static InvalidLifecycleDateFailure? _dates(
    LocalDate startedOn,
    LocalDate? finishedOn,
    LocalDate today,
  ) {
    if (startedOn.isAfter(today) ||
        (finishedOn != null && finishedOn.isAfter(today))) {
      return const InvalidLifecycleDateFailure(
        'Factual observations cannot be future-dated.',
      );
    }
    if (finishedOn != null && finishedOn.isBefore(startedOn)) {
      return const InvalidLifecycleDateFailure('Finish cannot precede Start.');
    }
    return null;
  }

  static InvalidLifecycleDateFailure? _checkpointDate(
    LocalDate date,
    LifecycleCycle cycle,
    LocalDate today,
  ) {
    if (date.isAfter(today) || !_within(date, cycle)) {
      return const InvalidLifecycleDateFailure(
        'Checkpoint date must be nonfuture and within its cycle boundaries.',
      );
    }
    return null;
  }

  static bool _within(LocalDate date, LifecycleCycle cycle) =>
      !date.isBefore(cycle.startedOn) &&
      (cycle.finishedOn == null || !date.isAfter(cycle.finishedOn!));
}
