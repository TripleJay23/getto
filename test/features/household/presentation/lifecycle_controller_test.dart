import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/application/restock_item_use_case.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/lifecycle_cycle.dart';
import 'package:getto/features/household/domain/lifecycle_repository.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:getto/features/household/presentation/lifecycle_controller.dart';

import '../../../support/lifecycle_fake.dart';

void main() {
  late FakeLifecycleRepository repo;
  final controllers = <LifecycleController>[];
  LifecycleController make(
    LifecycleTask task, {
    ItemLifecycle? initial,
    LifecycleCycle? cycle,
    LifecycleCheckpoint? checkpoint,
  }) {
    final c = LifecycleController(
      repository: repo,
      restockUseCase: RestockItemUseCase(repo, today: () => testToday),
      today: () => testToday,
      expected: initial ?? repo.saved,
      task: task,
      cycle: cycle,
      checkpoint: checkpoint,
    );
    controllers.add(c);
    return c;
  }

  setUp(() {
    repo = FakeLifecycleRepository(
      lifecycleFixture(history: true, notes: true, count: 3),
    );
  });
  tearDown(() async {
    for (final c in controllers) {
      c.dispose();
    }
    controllers.clear();
    await repo.close();
  });

  test(
    'Start preserves unknown count; ordinary creation has no automatic write',
    () async {
      repo.saved = lifecycleFixture(active: false);
      final c = make(LifecycleTask.start);
      expect(repo.calls, isEmpty);
      expect(await c.submit(), isTrue);
      expect(repo.saved.item.packageCount, isNull);
      expect(repo.saved.activeCycle!.startedOn, testToday);
      expect(c.outcome!.message, contains('Started'));
    },
  );
  for (final value in [
    '',
    '0',
    '-1',
    '2.5',
    '0x10',
    '+5',
    '9223372036854775808',
  ]) {
    test(
      'Restock rejects invalid absolute total "$value" retaining draft and facts',
      () async {
        repo.saved = lifecycleFixture(active: false, count: 2);
        final before = repo.saved;
        final c = make(LifecycleTask.restock)..countText = value;
        expect(await c.submit(), isFalse);
        expect(c.countText, value);
        expect(repo.saved, same(before));
        expect(c.outcome, isNull);
      },
    );
  }
  test(
    'Restock uses positive absolute total, never adds to saved count',
    () async {
      repo.saved = lifecycleFixture(active: false, count: 7);
      final c = make(LifecycleTask.restock)..countText = '2';
      expect(await c.submit(), isTrue);
      expect(repo.saved.item.packageCount, 2);
      expect(repo.lastTotal, 2);
      expect(repo.calls, ['restock']);
    },
  );
  for (final choice in LifecycleResolutionChoice.values) {
    test(
      'Restock $choice resolves and replaces in exactly one command preserving unrelated history',
      () async {
        final c = make(LifecycleTask.restock)..countText = '4';
        c.chooseResolution(choice);
        c.finishText = '2026-10-26';
        c.destructiveConfirmed = true;
        expect(await c.submit(), isTrue);
        expect(repo.calls, ['restock']);
        expect(repo.saved.activeCycle!.id, isNot(10));
        expect(repo.saved.item.packageCount, 4);
        expect(repo.saved.cycles.any((c) => c.id == 1), isTrue);
        expect(repo.saved.checkpoints.any((p) => p.id == 1), isTrue);
        if (choice == LifecycleResolutionChoice.wrong) {
          expect(repo.lastResolution, isA<RemoveErroneousActiveCycle>());
          expect(repo.saved.cycles.any((c) => c.id == 10), isFalse);
          expect(repo.saved.checkpoints.any((p) => p.id == 10), isFalse);
        } else {
          expect(repo.lastResolution, isA<FinishActiveCycle>());
          expect(
            repo.saved.cycles.singleWhere((c) => c.id == 10).finishedOn,
            day(26),
          );
        }
      },
    );
  }
  test(
    'Restock missing resolution and destructive consent write nothing',
    () async {
      final c = make(LifecycleTask.restock)..countText = '4';
      expect(await c.submit(), isFalse);
      c.chooseResolution(LifecycleResolutionChoice.wrong);
      expect(await c.submit(), isFalse);
      expect(repo.calls, isEmpty);
      expect(c.errorMessage, contains('Confirm removal'));
    },
  );
  for (final text in [
    '2026-10-30',
    '2026-10-19',
    '0000-01-01',
    '2026-02-30',
    'invalid',
  ]) {
    test(
      'Finish invalid calendar date $text retains input and never acknowledges',
      () async {
        final c = make(LifecycleTask.finish)..finishText = text;
        expect(await c.submit(), isFalse);
        expect(c.finishText, text);
        expect(repo.saved.activeCycle, isNotNull);
        expect(c.outcome, isNull);
      },
    );
  }
  test(
    'Finish same day has actual zero duration and reconciles physical count',
    () async {
      repo.saved = lifecycleFixture(
        active: false,
        count: 1,
      ).start(cycleId: 10, startedOn: testToday, today: testToday).valueOrNull!;
      final c = make(LifecycleTask.finish);
      expect(await c.submit(), isTrue);
      expect(repo.saved.cycles.single.durationDays, 0);
      expect(repo.saved.item.packageCount, 0);
      expect(repo.saved.item.stockStatus, StockStatus.outOfStock);
    },
  );
  for (final action in ObservationReconciliation.values.where(
    (x) => x != ObservationReconciliation.keep,
  )) {
    test(
      'Earlier finish requires explicit checkpoint reconciliation $action',
      () async {
        final c = make(LifecycleTask.finish)..finishText = '2026-10-23';
        expect(await c.submit(), isFalse);
        expect(c.needsReconciliation, isTrue);
        expect(repo.saved.checkpoints.length, 2);
        c.reconciliationChoices[10] = action;
        c.observationDates[10] = '2026-10-22';
        expect(await c.submit(), isTrue);
        expect(
          repo.saved.checkpoints.singleWhere((p) => p.id == 1).observedOn,
          day(2),
        );
        expect(
          repo.saved.checkpoints.any((p) => p.id == 10),
          action == ObservationReconciliation.changeDate,
        );
      },
    );
  }
  test('Historical corrections preserve stock, count, unrelated notes and completion state', () async {
    final c = make(LifecycleTask.correctDates, cycle: repo.saved.cycles.first)
      ..startText = '2026-10-02';
    expect(await c.submit(), isTrue);
    expect(repo.saved.item.packageCount, 3);
    expect(repo.saved.item.stockStatus, StockStatus.inStock);
    expect(repo.saved.cycles.first.durationDays, 0);
    expect(repo.saved.activeCycle!.id, 10);
    expect(repo.saved.checkpoints.length, 2);
  });
  test('Removal requires confirmation, removes only owned evidence, retains physical reality', () async {
    final c = make(LifecycleTask.removeCycle, cycle: repo.saved.cycles.first);
    expect(await c.submit(), isFalse);
    c.destructiveConfirmed = true;
    expect(await c.submit(), isTrue);
    expect(repo.saved.cycles.single.id, 10);
    expect(repo.saved.checkpoints.single.id, 10);
    expect(repo.saved.item.packageCount, 3);
  });
  for (final kind in LifecycleCheckpointKind.values) {
    test(
      'Checkpoint $kind selects existing identity for correction or creates optional note',
      () async {
        final c = make(LifecycleTask.checkpoint);
        c.chooseKind(kind);
        c.observedText = '2026-10-26';
        expect(await c.submit(), isTrue);
        expect(repo.calls, [
          kind == LifecycleCheckpointKind.aboutHalf
              ? 'checkpoint-date'
              : 'checkpoint',
        ]);
        expect(
          repo.saved.checkpoints
              .where((p) => p.cycleId == 10 && p.kind == kind)
              .length,
          1,
        );
      },
    );
  }
  test('No checkpoint is saved without an explicit kind', () async {
    expect(await make(LifecycleTask.checkpoint).submit(), isFalse);
    expect(repo.calls, isEmpty);
  });
  test(
    'Zero count conflict is actionable; explicit Finish atomically saves zero',
    () async {
      final c = make(LifecycleTask.correctCount)..countText = '0';
      expect(await c.submit(), isFalse);
      expect(c.activeConflict, isTrue);
      expect(c.storageFailure, isFalse);
      await c.resolveCount();
      c.chooseResolution(LifecycleResolutionChoice.finishedNow);
      expect(await c.submit(), isTrue);
      expect(repo.calls, ['count', 'finish']);
      expect(repo.saved.activeCycle, isNull);
      expect(repo.saved.item.packageCount, 0);
    },
  );
  test('Wrong-cycle zero recovery removes evidence then requires explicit retained-count save', () async {
    final c = make(LifecycleTask.correctCount)..countText = '0';
    await c.submit();
    await c.resolveCount();
    c.chooseResolution(LifecycleResolutionChoice.wrong);
    c.destructiveConfirmed = true;
    expect(await c.submit(), isFalse);
    expect(c.outcome, isNull);
    expect(c.countText, '0');
    expect(c.information, contains('count has not been saved'));
    expect(repo.saved.item.packageCount, 3);
    expect(await c.submit(), isTrue);
    expect(repo.saved.item.packageCount, 0);
    expect(repo.calls, ['count', 'remove', 'count']);
  });
  test(
    'Changing zero draft to positive never resolves or closes an active cycle',
    () async {
      final c = make(LifecycleTask.correctCount)..countText = '0';
      await c.submit();
      c.countText = '5';
      await c.resolveCount();
      expect(c.resolvingCount, isFalse);
      expect(await c.submit(), isTrue);
      expect(repo.saved.activeCycle, isNotNull);
      expect(repo.saved.item.packageCount, 5);
    },
  );
  for (final mode in ['failure', 'throw']) {
    test(
      'Persistence $mode keeps all draft fields and permits retry without false success',
      () async {
        final c = make(LifecycleTask.restock)
          ..startText = '2026-10-28'
          ..countText = '4';
        c.chooseResolution(LifecycleResolutionChoice.finishedEarlier);
        c.finishText = '2026-10-26';
        repo.writeFailure = mode == 'failure'
            ? const StorageIoFailure('injected')
            : null;
        repo.throwWrite = mode == 'throw';
        expect(await c.submit(), isFalse);
        expect(c.storageFailure, isTrue);
        expect(c.outcome, isNull);
        expect(c.countText, '4');
        expect(c.startText, '2026-10-28');
        expect(c.finishText, '2026-10-26');
        c.keepEditing();
        expect(c.failure, isNull);
        repo.writeFailure = null;
        repo.throwWrite = false;
        expect(await c.submit(), isTrue);
      },
    );
  }
  test(
    'Busy gate prevents duplicates and publishes no success before commit',
    () async {
      final c = make(LifecycleTask.finish);
      repo.gate = Completer<void>();
      final pending = c.submit();
      expect(c.busy, isTrue);
      expect(await c.submit(), isFalse);
      expect(repo.calls, ['finish']);
      expect(c.outcome, isNull);
      expect(repo.saved.activeCycle, isNotNull);
      repo.gate!.complete();
      expect(await pending, isTrue);
      expect(c.busy, isFalse);
      expect(c.outcome, isNotNull);
    },
  );
  test('Stale correction blocks overwrite until explicit review and retains date draft', () async {
    final c = make(LifecycleTask.correctDates)..startText = '2026-10-21';
    repo.saved = repo.saved
        .correctCycleDates(
          expected: repo.saved.activeCycle!,
          startedOn: day(19),
          finishedOn: null,
          today: testToday,
        )
        .valueOrNull!;
    expect(await c.submit(), isFalse);
    expect(c.conflict, isTrue);
    expect(await c.submit(), isFalse);
    expect(repo.calls.length, 1);
    expect(await c.reviewCurrent(), isTrue);
    expect(c.startText, '2026-10-21');
    expect(c.cycle!.startedOn, day(19));
    expect(await c.submit(), isTrue);
  });
  for (final replacement in ['removed', 'finished', 'archived', 'deleted']) {
    test(
      'Review $replacement target never silently retargets or reopens',
      () async {
        final c = make(LifecycleTask.finish);
        switch (replacement) {
          case 'removed':
            repo.saved = repo.saved
                .removeCycle(expected: repo.saved.activeCycle!)
                .valueOrNull!;
          case 'finished':
            repo.saved = repo.saved
                .finish(
                  expected: repo.saved.activeCycle!,
                  finishedOn: testToday,
                  today: testToday,
                )
                .valueOrNull!;
          case 'archived':
            repo.saved = ItemLifecycle(
              item: repo.saved.item.copyWith(isArchived: true),
              cycles: repo.saved.cycles,
              checkpoints: repo.saved.checkpoints,
            );
          case 'deleted':
            repo.readFailure = const EntityNotFoundFailure('deleted');
        }
        expect(await c.reviewCurrent(), isFalse);
        expect(c.unavailable, isTrue);
        expect(await c.submit(), isFalse);
        expect(repo.calls, isEmpty);
      },
    );
  }
  test(
    'Archived and durable writes are typed failures with retained draft',
    () async {
      for (final fixture in [
        lifecycleFixture(active: false, archived: true),
        lifecycleFixture(active: false, profile: BehaviorProfile.durable),
      ]) {
        repo.saved = fixture;
        final c = make(LifecycleTask.start);
        expect(await c.submit(), isFalse);
        expect(c.outcome, isNull);
        expect(c.storageFailure, isFalse);
      }
    },
  );
}
