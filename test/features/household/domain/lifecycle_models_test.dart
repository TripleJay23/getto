import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/local_date/local_date.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/lifecycle_cycle.dart';

import '../../../support/lifecycle_fixtures.dart';

void main() {
  test('active duration is unknown; same-day completed duration is zero', () {
    expect(cycle().durationDays, isNull);
    expect(cycle().isActive, isTrue);
    expect(cycle(finish: 10).durationDays, 0);
    expect(cycle(finish: 10).isActive, isFalse);
  });

  test('calendar duration respects leap years and year boundaries', () {
    for (final entry in [
      (LocalDate(2024, 2, 28), LocalDate(2024, 3, 1), 2),
      (LocalDate(2025, 2, 28), LocalDate(2025, 3, 1), 1),
      (LocalDate(2025, 12, 31), LocalDate(2026, 1, 1), 1),
    ]) {
      final value = LifecycleCycle(
        id: 1,
        itemId: 1,
        startedOn: entry.$1,
        finishedOn: entry.$2,
      );
      expect(value.durationDays, entry.$3);
    }
  });

  test('constructor rejects finish before start at runtime', () {
    expect(() => cycle(start: 12, finish: 11), throwsArgumentError);
  });

  test(
    'cycle and checkpoint value equality includes exact identity and dates',
    () {
      expect(cycle(finish: 20), cycle(finish: 20));
      expect(cycle(finish: 20).hashCode, cycle(finish: 20).hashCode);
      expect(cycle(), isNot(cycle(id: 11)));
      expect(cycle(), isNot(cycle(itemId: 2)));
      expect(cycle(), isNot(cycle(start: 11)));
      expect(cycle(), isNot(cycle(finish: 20)));
      expect(checkpoint(), checkpoint());
      expect(checkpoint().hashCode, checkpoint().hashCode);
      expect(checkpoint(), isNot(checkpoint(id: 101)));
      expect(checkpoint(), isNot(checkpoint(cycleId: 11)));
      expect(checkpoint(), isNot(checkpoint(observed: 16)));
      expect(
        checkpoint(),
        isNot(checkpoint(kind: LifecycleCheckpointKind.nearlyFinished)),
      );
    },
  );

  test(
    'checkpoint kinds round-trip canonical names and reject unsupported data',
    () {
      expect(LifecycleCheckpointKind.values, hasLength(2));
      for (final kind in LifecycleCheckpointKind.values) {
        expect(LifecycleCheckpointKind.fromWireName(kind.wireName), kind);
      }
      expect(
        () => LifecycleCheckpointKind.fromWireName('perUse'),
        throwsArgumentError,
      );
    },
  );

  test('snapshot copies collections and exposes immutable evidence', () {
    final rows = [cycle()];
    final notes = [checkpoint()];
    final state = ItemLifecycle(
      item: householdItem(),
      cycles: rows,
      checkpoints: notes,
    );
    rows.clear();
    notes.clear();
    expect(state.cycles, hasLength(1));
    expect(state.checkpoints, hasLength(1));
    expect(() => state.cycles.clear(), throwsUnsupportedError);
    expect(() => state.checkpoints.clear(), throwsUnsupportedError);
    expect(() => state.completedCycles.clear(), throwsUnsupportedError);
  });

  test('one item cannot own multiple unfinished observations', () {
    expect(
      () => ItemLifecycle(
        item: householdItem(),
        cycles: [cycle(), cycle(id: 11)],
      ),
      throwsArgumentError,
    );
  });

  test('cycle IDs and ownership must be unambiguous', () {
    for (final rows in [
      [cycle(finish: 20), cycle(finish: 21)],
      [cycle(itemId: 999)],
    ]) {
      expect(
        () => ItemLifecycle(item: householdItem(), cycles: rows),
        throwsArgumentError,
      );
    }
  });

  test('durable possessions are valid without consumption evidence', () {
    final item = householdItem(profile: BehaviorProfile.durable);
    expect(ItemLifecycle(item: item).cycles, isEmpty);
    expect(
      () => ItemLifecycle(item: item, cycles: [cycle()]),
      throwsArgumentError,
    );
  });

  test('foreign checkpoint, duplicate ID and duplicate kind are rejected', () {
    for (final notes in [
      [checkpoint(cycleId: 999)],
      [checkpoint(), checkpoint(kind: LifecycleCheckpointKind.nearlyFinished)],
      [checkpoint(), checkpoint(id: 101)],
    ]) {
      expect(
        () => ItemLifecycle(
          item: householdItem(),
          cycles: [cycle()],
          checkpoints: notes,
        ),
        throwsArgumentError,
      );
    }
  });

  test(
    'checkpoint boundaries are inclusive and kinds are unique per cycle',
    () {
      final state = ItemLifecycle(
        item: householdItem(),
        cycles: [cycle(finish: 20), cycle(id: 11, start: 20)],
        checkpoints: [
          checkpoint(observed: 10),
          checkpoint(
            id: 101,
            observed: 20,
            kind: LifecycleCheckpointKind.nearlyFinished,
          ),
          checkpoint(id: 102, cycleId: 11, observed: 20),
        ],
      );
      expect(state.checkpoints, hasLength(3));
      for (final observed in [9, 21]) {
        expect(
          () => ItemLifecycle(
            item: householdItem(),
            cycles: [cycle(finish: 20)],
            checkpoints: [checkpoint(observed: observed)],
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'completed historical intervals have no invented global overlap rule',
    () {
      final state = ItemLifecycle(
        item: householdItem(),
        cycles: [
          cycle(start: 1, finish: 20),
          cycle(id: 11, start: 10, finish: 25),
        ],
      );
      expect(state.completedCycles, hasLength(2));
      expect(state.activeCycle, isNull);
    },
  );

  for (final count in <int?>[null, 0, 8]) {
    test(
      'legacy count $count is preserved without fabricated lifecycle history',
      () {
        final item = householdItem(
          profile: BehaviorProfile.countableReplenishable,
          count: count,
        );
        final state = ItemLifecycle(item: item);
        expect(state.item, same(item));
        expect(state.item.packageCount, count);
        expect(state.cycles, isEmpty);
        expect(state.completedCycles, isEmpty);
        expect(state.checkpoints, isEmpty);
      },
    );
  }

  test('reading evidence cannot automatically finish an old active cycle', () {
    final old = LifecycleCycle(
      id: 1,
      itemId: 1,
      startedOn: LocalDate(2020, 1, 1),
    );
    final state = ItemLifecycle(item: householdItem(), cycles: [old]);
    expect(state.completedCycles, isEmpty);
    expect(state.activeCycle, same(old));
    expect(state.activeCycle!.durationDays, isNull);
  });
}
