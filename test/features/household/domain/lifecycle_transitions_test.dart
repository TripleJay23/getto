import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/local_date/local_date.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/stock_status.dart';

import '../../../support/lifecycle_fixtures.dart';

void main() {
  for (final profile in [
    BehaviorProfile.replenishable,
    BehaviorProfile.countableReplenishable,
  ]) {
    test(
      '$profile starts unknown stock without assuming one or completed evidence',
      () {
        final original = ItemLifecycle(
          item: householdItem(profile: profile, status: StockStatus.outOfStock),
        );
        final result = success(
          original.start(cycleId: 10, startedOn: day(10), today: today),
        );
        expect(result.activeCycle, cycle());
        expect(result.item.stockStatus, StockStatus.inStock);
        expect(result.item.packageCount, isNull);
        expect(result.completedCycles, isEmpty);
        expect(original.cycles, isEmpty);
        expect(original.item.stockStatus, StockStatus.outOfStock);
      },
    );

    test('$profile preserves known usable stock on Start', () {
      final state = ItemLifecycle(
        item: householdItem(profile: profile, count: 6),
      );
      expect(
        success(state.start(cycleId: 10, startedOn: day(10), today: today))
            .item
            .packageCount,
        6,
      );
    });

    test('$profile rejects a zero-stock Start', () {
      final state = ItemLifecycle(
        item: householdItem(profile: profile, count: 0),
      );
      failure<LifecycleCountFailure>(
        state.start(cycleId: 10, startedOn: day(10), today: today),
      );
      expect(state.item.packageCount, 0);
      expect(state.cycles, isEmpty);
    });

    test(
      '$profile Finish closes exactly one cycle and reconciles factual Out',
      () {
        final completed = cycle(id: 9, start: 1, finish: 5);
        final active = cycle();
        final state = ItemLifecycle(
          item: householdItem(profile: profile, count: 6),
          cycles: [completed, active],
          checkpoints: [checkpoint()],
        );
        final result = success(
          state.finish(expected: active, finishedOn: day(20), today: today),
        );
        expect(result.activeCycle, isNull);
        expect(result.cycles.first, same(completed));
        expect(result.cycles.last.durationDays, 10);
        expect(result.item.stockStatus, StockStatus.outOfStock);
        expect(result.item.packageCount, 0);
        expect(result.checkpoints, state.checkpoints);
        expect(state.activeCycle, same(active));
        expect(state.item.packageCount, 6);
      },
    );
  }

  test(
    'single-unit Finish preserves null count and permits a two-action cycle',
    () {
      final initial = ItemLifecycle(item: householdItem());
      final started = success(
        initial.start(cycleId: 10, startedOn: today, today: today),
      );
      final finished = success(
        started.finish(
          expected: started.activeCycle!,
          finishedOn: today,
          today: today,
        ),
      );
      expect(finished.cycles.single.durationDays, 0);
      expect(finished.item.packageCount, isNull);
      expect(finished.item.stockStatus, StockStatus.outOfStock);
      expect(finished.checkpoints, isEmpty);
    },
  );

  test(
    'countable Restock uses absolute total, not old stock plus entered amount',
    () {
      final prior = cycle(id: 9, start: 1, finish: 5);
      final initial = ItemLifecycle(
        item: householdItem(
          profile: BehaviorProfile.countableReplenishable,
          count: 6,
        ),
        cycles: [prior],
      );
      final restocked = success(
        initial.restock(
          cycleId: 10,
          startedOn: day(10),
          today: today,
          absolutePackageCount: 2,
        ),
      );
      expect(restocked.item.packageCount, 2);
      expect(restocked.cycles.first, same(prior));
      expect(restocked.activeCycle, cycle());
      expect(initial.item.packageCount, 6);
    },
  );

  for (final total in <int?>[null, 0, -1]) {
    test('countable Restock rejects missing/invalid absolute total $total', () {
      final state = ItemLifecycle(
        item: householdItem(profile: BehaviorProfile.countableReplenishable),
      );
      failure<LifecycleCountFailure>(
        state.restock(
          cycleId: 10,
          startedOn: day(10),
          today: today,
          absolutePackageCount: total,
        ),
      );
      expect(state.item.packageCount, isNull);
      expect(state.cycles, isEmpty);
    });
  }

  test('single-unit Restock with unknown count never invents quantity one', () {
    final state = ItemLifecycle(item: householdItem());
    expect(
      success(state.restock(cycleId: 10, startedOn: day(10), today: today))
          .item
          .packageCount,
      isNull,
    );
  });

  test(
    'active Start and Restock conflicts preserve exact cycle and history',
    () {
      final active = cycle();
      final state = ItemLifecycle(
        item: householdItem(count: 6),
        cycles: [active],
      );
      for (final result in [
        state.start(cycleId: 11, startedOn: day(20), today: today),
        state.restock(
          cycleId: 11,
          startedOn: day(20),
          today: today,
          absolutePackageCount: 9,
        ),
      ]) {
        failure<LifecycleConflictFailure>(result);
        expect(
          (result.failureOrNull as LifecycleConflictFailure).cycleId,
          active.id,
        );
      }
      expect(state.cycles, [active]);
      expect(state.item.packageCount, 6);
    },
  );

  test('explicit Finish then Restock preserves the old observation', () {
    final state = ItemLifecycle(
      item: householdItem(
        profile: BehaviorProfile.countableReplenishable,
        count: 3,
      ),
      cycles: [cycle()],
    );
    final closed = success(
      state.finish(expected: cycle(), finishedOn: day(20), today: today),
    );
    final next = success(
      closed.restock(
        cycleId: 11,
        startedOn: day(20),
        today: today,
        absolutePackageCount: 5,
      ),
    );
    expect(next.cycles.first.finishedOn, day(20));
    expect(next.activeCycle!.id, 11);
    expect(next.item.packageCount, 5);
    expect(state.activeCycle!.id, 10);
  });

  test('repeated Finish cannot close a subsequent active cycle', () {
    final old = cycle();
    final state = ItemLifecycle(item: householdItem(), cycles: [old]);
    final closed = success(
      state.finish(expected: old, finishedOn: day(20), today: today),
    );
    final next = success(
      closed.start(cycleId: 11, startedOn: day(21), today: today),
    );
    failure<LifecycleTargetFailure>(
      next.finish(expected: old, finishedOn: day(22), today: today),
    );
    expect(next.activeCycle!.id, 11);
    expect(next.cycles.first.finishedOn, day(20));
    failure<LifecycleTargetFailure>(
      closed.finish(
        expected: closed.cycles.single,
        finishedOn: day(21),
        today: today,
      ),
    );
  });

  test('used cycle identity cannot overwrite completed evidence', () {
    final old = cycle(finish: 20);
    final state = ItemLifecycle(item: householdItem(), cycles: [old]);
    failure<LifecycleTargetFailure>(
      state.start(cycleId: old.id, startedOn: day(21), today: today),
    );
    expect(state.cycles, [old]);
  });

  test('commands reject missing, foreign and changed expected cycles', () {
    final state = ItemLifecycle(item: householdItem(), cycles: [cycle()]);
    for (final expected in [
      cycle(id: 99),
      cycle(itemId: 2),
      cycle(start: 11),
    ]) {
      failure<LifecycleTargetFailure>(
        state.finish(expected: expected, finishedOn: day(20), today: today),
      );
    }
    expect(state.activeCycle, cycle());
  });

  test('durable profile rejects consumption commands with a typed failure', () {
    final state = ItemLifecycle(
      item: householdItem(profile: BehaviorProfile.durable),
    );
    for (final result in [
      state.start(cycleId: 10, startedOn: day(10), today: today),
      state.restock(cycleId: 10, startedOn: day(10), today: today),
      state.finish(expected: cycle(), finishedOn: day(20), today: today),
      state.correctCount(absoluteCurrentTotal: 2),
    ]) {
      failure<LifecycleProfileFailure>(result);
    }
    expect(state.item.packageCount, isNull);
  });

  test('archived new lifecycle commands respect restore-first without altering Item APIs', () {
    final state = ItemLifecycle(
      item: householdItem(archived: true),
      cycles: [cycle()],
    );
    for (final result in [
      state.start(cycleId: 11, startedOn: day(20), today: today),
      state.restock(cycleId: 11, startedOn: day(20), today: today),
      state.finish(expected: cycle(), finishedOn: day(20), today: today),
      state.removeCycle(expected: cycle()),
      state.correctCount(absoluteCurrentTotal: 2),
    ]) {
      failure<LifecycleConflictFailure>(result);
    }
    expect(state.item.isArchived, isTrue);
    expect(state.activeCycle, cycle());
  });

  test(
    'future Start/Restock and invalid Finish dates return typed date failures',
    () {
      final state = ItemLifecycle(item: householdItem());
      failure<InvalidLifecycleDateFailure>(
        state.start(cycleId: 10, startedOn: day(29), today: today),
      );
      failure<InvalidLifecycleDateFailure>(
        state.restock(cycleId: 10, startedOn: day(29), today: today),
      );
      final active = ItemLifecycle(item: householdItem(), cycles: [cycle()]);
      for (final finish in [day(9), day(29)]) {
        failure<InvalidLifecycleDateFailure>(
          active.finish(expected: cycle(), finishedOn: finish, today: today),
        );
      }
      expect(active.activeCycle, cycle());
    },
  );

  test('supplied calendar clock makes leap-day transitions deterministic', () {
    final leap = LocalDate(2024, 2, 29);
    final started = success(
      ItemLifecycle(item: householdItem())
          .start(cycleId: 1, startedOn: LocalDate(2024, 2, 28), today: leap),
    );
    final closed = success(
      started.finish(
        expected: started.activeCycle!,
        finishedOn: leap,
        today: leap,
      ),
    );
    expect(closed.cycles.single.durationDays, 1);
    expect(closed.cycles.single.finishedOn.toString(), '2024-02-29');
    failure<InvalidLifecycleDateFailure>(
      started.finish(
        expected: started.activeCycle!,
        finishedOn: LocalDate(2024, 3, 1),
        today: leap,
      ),
    );
  });

  test('count correction cannot silently finish an active observation', () {
    final state = ItemLifecycle(
      item: householdItem(
        profile: BehaviorProfile.countableReplenishable,
        count: 5,
      ),
      cycles: [cycle()],
    );
    failure<LifecycleConflictFailure>(
      state.correctCount(absoluteCurrentTotal: 0),
    );
    failure<LifecycleCountFailure>(
      state.correctCount(absoluteCurrentTotal: -1),
    );
    final corrected = success(state.correctCount(absoluteCurrentTotal: 2));
    expect(corrected.item.packageCount, 2);
    expect(corrected.activeCycle, same(state.activeCycle));
    expect(state.item.packageCount, 5);
    expect(state.completedCycles, isEmpty);
  });

  test('zero count after explicit Finish is consistent and does not fabricate cycles', () {
    final legacy = ItemLifecycle(
      item: householdItem(profile: BehaviorProfile.countableReplenishable),
    );
    final corrected = success(legacy.correctCount(absoluteCurrentTotal: 0));
    expect(corrected.item.packageCount, 0);
    expect(corrected.item.stockStatus, StockStatus.outOfStock);
    expect(corrected.cycles, isEmpty);
    expect(legacy.item.packageCount, isNull);
    final active = success(
      legacy.start(cycleId: 10, startedOn: day(10), today: today),
    );
    final closed = success(
      active.finish(expected: cycle(), finishedOn: day(20), today: today),
    );
    expect(
      success(closed.correctCount(absoluteCurrentTotal: 0)).cycles,
      closed.cycles,
    );
  });

  test(
    'transitions preserve unrelated metadata, identity, notes and timestamps',
    () {
      final before = householdItem();
      final after = success(
        ItemLifecycle(item: before)
            .start(cycleId: 10, startedOn: day(10), today: today),
      ).item;
      expect(after.id, before.id);
      expect(after.areaId, before.areaId);
      expect(after.name, before.name);
      expect(after.behaviorProfile, before.behaviorProfile);
      expect(after.unit, before.unit);
      expect(after.notes, before.notes);
      expect(after.isArchived, before.isArchived);
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt, before.updatedAt);
    },
  );
}
