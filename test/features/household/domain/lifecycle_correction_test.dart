import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';

import '../../../support/lifecycle_fixtures.dart';

void main() {
  test('historical date correction changes only selected factual evidence', () {
    final old = cycle(start: 1, finish: 10);
    final current = cycle(id: 11, start: 20);
    final state = ItemLifecycle(
      item: householdItem(count: 6),
      cycles: [old, current],
      checkpoints: [checkpoint(observed: 5)],
    );
    final corrected = success(
      state.correctCycleDates(
        expected: old,
        startedOn: day(2),
        finishedOn: day(12),
        today: today,
      ),
    );
    expect(corrected.cycles.first.durationDays, 10);
    expect(corrected.activeCycle, same(current));
    expect(corrected.checkpoints, state.checkpoints);
    expect(corrected.item, same(state.item));
    expect(state.cycles.first, same(old));
    expect(state.cycles.first.durationDays, 9);
  });

  test(
    'historical same-day correction remains a valid zero-day observation',
    () {
      final old = cycle(finish: 20);
      final state = ItemLifecycle(item: householdItem(), cycles: [old]);
      final corrected = success(
        state.correctCycleDates(
          expected: old,
          startedOn: day(15),
          finishedOn: day(15),
          today: today,
        ),
      );
      expect(corrected.completedCycles.single.durationDays, 0);
    },
  );

  test('date correction does not impose global historical non-overlap', () {
    final selected = cycle(start: 1, finish: 10);
    final other = cycle(id: 11, start: 11, finish: 20);
    final state = ItemLifecycle(
      item: householdItem(),
      cycles: [selected, other],
    );
    final corrected = success(
      state.correctCycleDates(
        expected: selected,
        startedOn: day(1),
        finishedOn: day(15),
        today: today,
      ),
    );
    expect(corrected.completedCycles, hasLength(2));
    expect(corrected.cycles.last, same(other));
  });

  test('invalid/future cycle corrections preserve all facts', () {
    final old = cycle(finish: 20);
    final state = ItemLifecycle(item: householdItem(), cycles: [old]);
    for (final dates in [
      (day(21), day(20)),
      (day(10), day(29)),
      (day(29), day(29)),
    ]) {
      failure<InvalidLifecycleDateFailure>(
        state.correctCycleDates(
          expected: old,
          startedOn: dates.$1,
          finishedOn: dates.$2,
          today: today,
        ),
      );
    }
    expect(state.cycles, [old]);
  });

  test('date edits cannot implicitly close or reopen observations', () {
    for (final selected in [cycle(), cycle(finish: 20)]) {
      final state = ItemLifecycle(item: householdItem(), cycles: [selected]);
      failure<LifecycleTargetFailure>(
        state.correctCycleDates(
          expected: selected,
          startedOn: selected.startedOn,
          finishedOn: selected.isActive ? day(20) : null,
          today: today,
        ),
      );
      expect(state.cycles, [selected]);
    }
  });

  test(
    'date correction identifies invalidated checkpoints without deleting them',
    () {
      final original = cycle();
      final notes = [
        checkpoint(observed: 12),
        checkpoint(
          id: 101,
          observed: 14,
          kind: LifecycleCheckpointKind.nearlyFinished,
        ),
      ];
      final state = ItemLifecycle(
        item: householdItem(),
        cycles: [original],
        checkpoints: notes,
      );
      final result = state.correctCycleDates(
        expected: original,
        startedOn: day(15),
        finishedOn: null,
        today: today,
      );
      failure<LifecycleCheckpointReconciliationFailure>(result);
      final error =
          result.failureOrNull as LifecycleCheckpointReconciliationFailure;
      expect(error.checkpointIds, [100, 101]);
      expect(() => error.checkpointIds.clear(), throwsUnsupportedError);
      expect(state.activeCycle, same(original));
      expect(state.checkpoints, notes);
    },
  );

  test('explicit checkpoint corrections/removals reconcile a cycle date atomically', () {
    final original = cycle();
    final unrelated = cycle(id: 11, start: 1, finish: 5);
    final unrelatedNote = checkpoint(id: 102, cycleId: 11, observed: 3);
    final state = ItemLifecycle(
      item: householdItem(),
      cycles: [original, unrelated],
      checkpoints: [
        checkpoint(observed: 12),
        checkpoint(
          id: 101,
          observed: 14,
          kind: LifecycleCheckpointKind.nearlyFinished,
        ),
        unrelatedNote,
      ],
    );
    final corrected = success(
      state.correctCycleDates(
        expected: original,
        startedOn: day(15),
        finishedOn: null,
        today: today,
        checkpointDates: {100: day(16)},
        removedCheckpointIds: {101},
      ),
    );
    expect(corrected.activeCycle!.startedOn, day(15));
    expect(corrected.checkpoints.map((c) => c.id), [100, 102]);
    expect(corrected.checkpoints.first.observedOn, day(16));
    expect(corrected.checkpoints.last, same(unrelatedNote));
    expect(corrected.cycles.last, same(unrelated));
    expect(state.checkpoints, hasLength(3));
    expect(state.activeCycle!.startedOn, day(10));
  });

  test(
    'reconciliation rejects foreign IDs and ambiguous remove-plus-correct',
    () {
      final selected = cycle();
      final state = ItemLifecycle(
        item: householdItem(),
        cycles: [selected, cycle(id: 11, start: 1, finish: 5)],
        checkpoints: [
          checkpoint(),
          checkpoint(id: 101, cycleId: 11, observed: 3),
        ],
      );
      for (final result in [
        state.correctCycleDates(
          expected: selected,
          startedOn: day(10),
          finishedOn: null,
          today: today,
          checkpointDates: {101: day(4)},
        ),
        state.correctCycleDates(
          expected: selected,
          startedOn: day(10),
          finishedOn: null,
          today: today,
          removedCheckpointIds: {101},
        ),
        state.correctCycleDates(
          expected: selected,
          startedOn: day(10),
          finishedOn: null,
          today: today,
          checkpointDates: {100: day(16)},
          removedCheckpointIds: {100},
        ),
        state.correctCycleDates(
          expected: selected,
          startedOn: day(10),
          finishedOn: null,
          today: today,
          removedCheckpointIds: {999},
        ),
      ]) {
        failure<LifecycleTargetFailure>(result);
      }
      expect(state.checkpoints, hasLength(2));
    },
  );

  test('failed explicit checkpoint reconciliation never partly applies the date edit', () {
    final selected = cycle();
    final state = ItemLifecycle(
      item: householdItem(),
      cycles: [selected],
      checkpoints: [checkpoint()],
    );
    failure<InvalidLifecycleDateFailure>(
      state.correctCycleDates(
        expected: selected,
        startedOn: day(11),
        finishedOn: null,
        today: today,
        checkpointDates: {100: day(29)},
      ),
    );
    failure<LifecycleCheckpointReconciliationFailure>(
      state.correctCycleDates(
        expected: selected,
        startedOn: day(16),
        finishedOn: null,
        today: today,
        checkpointDates: {100: day(14)},
      ),
    );
    expect(state.activeCycle, same(selected));
    expect(state.checkpoints.single.observedOn, day(15));
  });

  test('Finished earlier also requires reconciliation of observations after its date', () {
    final selected = cycle();
    final state = ItemLifecycle(
      item: householdItem(count: 5),
      cycles: [selected],
      checkpoints: [checkpoint()],
    );
    failure<LifecycleCheckpointReconciliationFailure>(
      state.finish(expected: selected, finishedOn: day(12), today: today),
    );
    final closed = success(
      state.finish(
        expected: selected,
        finishedOn: day(12),
        today: today,
        checkpointDates: {100: day(12)},
      ),
    );
    expect(closed.cycles.single.finishedOn, day(12));
    expect(closed.checkpoints.single.observedOn, day(12));
    expect(closed.item.packageCount, 0);
    expect(state.item.packageCount, 5);
    expect(state.activeCycle, same(selected));
  });

  test(
    'removing wrong evidence retains item/current facts and unrelated evidence',
    () {
      final selected = cycle(start: 1, finish: 10);
      final active = cycle(id: 11, start: 20);
      final state = ItemLifecycle(
        item: householdItem(count: 8),
        cycles: [selected, active],
        checkpoints: [
          checkpoint(observed: 5),
          checkpoint(id: 101, cycleId: 11, observed: 22),
        ],
      );
      final removed = success(state.removeCycle(expected: selected));
      expect(removed.cycles, [active]);
      expect(removed.completedCycles, isEmpty);
      expect(removed.checkpoints.single.id, 101);
      expect(removed.item, same(state.item));
      expect(state.cycles, hasLength(2));
      expect(state.checkpoints, hasLength(2));
    },
  );

  test(
    'wrong active-cycle removal is deliberate and permits a new observation',
    () {
      final selected = cycle();
      final state = ItemLifecycle(item: householdItem(), cycles: [selected]);
      final removed = success(state.removeCycle(expected: selected));
      expect(removed.item, same(state.item));
      final restarted = success(
        removed.start(cycleId: 11, startedOn: day(20), today: today),
      );
      expect(restarted.activeCycle!.id, 11);
      expect(restarted.completedCycles, isEmpty);
    },
  );

  test(
    'stale correction or removal cannot overwrite changed selected evidence',
    () {
      final selected = cycle(finish: 20);
      final state = ItemLifecycle(item: householdItem(), cycles: [selected]);
      final corrected = success(
        state.correctCycleDates(
          expected: selected,
          startedOn: day(11),
          finishedOn: day(20),
          today: today,
        ),
      );
      failure<LifecycleTargetFailure>(
        corrected.removeCycle(expected: selected),
      );
      failure<LifecycleTargetFailure>(
        corrected.correctCycleDates(
          expected: selected,
          startedOn: day(12),
          finishedOn: day(20),
          today: today,
        ),
      );
      expect(corrected.cycles.single.startedOn, day(11));
    },
  );

  for (final kind in LifecycleCheckpointKind.values) {
    test(
      '$kind is optional and does not require another kind or close the cycle',
      () {
        final selected = cycle();
        final state = ItemLifecycle(item: householdItem(), cycles: [selected]);
        final noted = success(
          state.addCheckpoint(
            expectedCycle: selected,
            checkpoint: checkpoint(kind: kind),
            today: today,
          ),
        );
        expect(noted.checkpoints.single.kind, kind);
        expect(noted.activeCycle, same(selected));
        expect(noted.completedCycles, isEmpty);
        expect(noted.item, same(state.item));
        expect(state.checkpoints, isEmpty);
      },
    );
  }

  test(
    'repeated checkpoint and duplicate kind cannot create duplicate evidence',
    () {
      final selected = cycle();
      final note = checkpoint();
      final state = ItemLifecycle(
        item: householdItem(),
        cycles: [selected],
        checkpoints: [note],
      );
      for (final entry in [
        note,
        checkpoint(id: 101),
        checkpoint(kind: LifecycleCheckpointKind.nearlyFinished),
      ]) {
        failure<LifecycleConflictFailure>(
          state.addCheckpoint(
            expectedCycle: selected,
            checkpoint: entry,
            today: today,
          ),
        );
      }
      expect(state.checkpoints, [note]);
    },
  );

  test(
    'both checkpoint kinds can be recorded without mandatory stage ordering',
    () {
      final selected = cycle();
      final state = ItemLifecycle(item: householdItem(), cycles: [selected]);
      final lateKind = success(
        state.addCheckpoint(
          expectedCycle: selected,
          checkpoint: checkpoint(kind: LifecycleCheckpointKind.nearlyFinished),
          today: today,
        ),
      );
      final both = success(
        lateKind.addCheckpoint(
          expectedCycle: selected,
          checkpoint: checkpoint(id: 101, observed: 15),
          today: today,
        ),
      );
      expect(both.checkpoints, hasLength(2));
      expect(both.activeCycle, same(selected));
    },
  );

  test('checkpoint creation rejects future and out-of-cycle dates', () {
    for (final selected in [cycle(), cycle(finish: 20)]) {
      final state = ItemLifecycle(item: householdItem(), cycles: [selected]);
      for (final observed in [9, 29, if (!selected.isActive) 21]) {
        failure<InvalidLifecycleDateFailure>(
          state.addCheckpoint(
            expectedCycle: selected,
            checkpoint: checkpoint(observed: observed),
            today: today,
          ),
        );
      }
      expect(state.checkpoints, isEmpty);
    }
  });

  test(
    'checkpoint creation targets the expected cycle, not whichever is active',
    () {
      final selected = cycle();
      final state = ItemLifecycle(item: householdItem(), cycles: [selected]);
      failure<LifecycleTargetFailure>(
        state.addCheckpoint(
          expectedCycle: cycle(id: 11),
          checkpoint: checkpoint(cycleId: 11),
          today: today,
        ),
      );
      failure<LifecycleTargetFailure>(
        state.addCheckpoint(
          expectedCycle: selected,
          checkpoint: checkpoint(cycleId: 11),
          today: today,
        ),
      );
      expect(state.checkpoints, isEmpty);
    },
  );

  test('checkpoint correction updates one logical observation and rejects stale input', () {
    final selected = cycle(finish: 20);
    final original = checkpoint();
    final other = checkpoint(
      id: 101,
      kind: LifecycleCheckpointKind.nearlyFinished,
    );
    final state = ItemLifecycle(
      item: householdItem(),
      cycles: [selected],
      checkpoints: [original, other],
    );
    final corrected = success(
      state.correctCheckpoint(
        expected: original,
        observedOn: day(16),
        today: today,
      ),
    );
    expect(corrected.checkpoints.first.id, original.id);
    expect(corrected.checkpoints.first.kind, original.kind);
    expect(corrected.checkpoints.first.observedOn, day(16));
    expect(corrected.checkpoints.last, same(other));
    expect(corrected.item, same(state.item));
    expect(corrected.cycles, state.cycles);
    failure<LifecycleTargetFailure>(
      corrected.correctCheckpoint(
        expected: original,
        observedOn: day(17),
        today: today,
      ),
    );
    for (final observed in [9, 21, 29]) {
      failure<InvalidLifecycleDateFailure>(
        state.correctCheckpoint(
          expected: original,
          observedOn: day(observed),
          today: today,
        ),
      );
    }
    failure<LifecycleTargetFailure>(
      state.correctCheckpoint(
        expected: checkpoint(id: 999),
        observedOn: day(16),
        today: today,
      ),
    );
    expect(state.checkpoints.first, same(original));
  });
}
