import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/application/reconcile_item_stock_use_case.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/lifecycle_repository.dart';
import 'package:getto/features/household/domain/stock_status.dart';

import '../../../support/lifecycle_repository_fixture.dart';

void main() {
  late LifecycleFixture f;
  setUp(() => f = LifecycleFixture());
  tearDown(() => f.db.close());

  test('Start persists generated identity and unknown count without touching metadata', () async {
    final item = await f.item();
    final next = await f.start(item);
    expect(next.activeCycle!.id, isPositive);
    expect(next.activeCycle!.itemId, item.id);
    expect(next.item.packageCount, isNull);
    expect(next.item.stockStatus, StockStatus.inStock);
    expect(next.item.updatedAt.isAtSameMomentAs(commitInstant), isTrue);
    expect(next.item.name, item.name);
    expect(next.item.notes, item.notes);
    expect(next.item.createdAt, item.createdAt);
    expect((await f.snapshot(item.id)).cycles, next.cycles);
  });

  for (final count in [null, 0, 5]) {
    test(
      'countable Restock stores explicit absolute total from prior $count',
      () async {
        final item = await f.item(
          profile: BehaviorProfile.countableReplenishable,
          count: count,
        );
        final before = await databaseFacts(f.db);
        for (final invalid in [null, 0, -1]) {
          final result = await f.lifecycle.restock(
            itemId: item.id,
            startedOn: date(10),
            today: currentDate,
            absolutePackageCount: invalid,
          );
          expect(result.failureOrNull, isA<LifecycleCountFailure>());
          expect(await databaseFacts(f.db), before);
        }
        final next = saved(
          await f.lifecycle.restock(
            itemId: item.id,
            startedOn: date(10),
            today: currentDate,
            absolutePackageCount: 4,
          ),
        );
        expect(next.item.packageCount, 4);
        expect(next.item.stockStatus, StockStatus.inStock);
        expect(next.cycles.length, 1);
      },
    );
  }

  test('Start rejects zero stock and future dates without writes', () async {
    final zero = await f.item(count: 0);
    final regular = await f.item();
    final before = await databaseFacts(f.db);
    expect(
      (await f.lifecycle.start(
        itemId: zero.id,
        startedOn: date(10),
        today: currentDate,
      )).failureOrNull,
      isA<LifecycleCountFailure>(),
    );
    expect(
      (await f.lifecycle.start(
        itemId: regular.id,
        startedOn: date(30),
        today: currentDate,
      )).failureOrNull,
      isA<InvalidLifecycleDateFailure>(),
    );
    expect(await databaseFacts(f.db), before);
  });

  test(
    'repeated Start and unresolved Restock cannot add a second active cycle',
    () async {
      final item = await f.item();
      final first = await f.start(item);
      final before = await databaseFacts(f.db);
      for (final command in [
        f.lifecycle.start(
          itemId: item.id,
          startedOn: date(11),
          today: currentDate,
        ),
        f.lifecycle.restock(
          itemId: item.id,
          startedOn: date(11),
          today: currentDate,
        ),
      ]) {
        final failure = (await command).failureOrNull;
        expect(failure, isA<LifecycleConflictFailure>());
        expect(
          (failure as LifecycleConflictFailure).cycleId,
          first.activeCycle!.id,
        );
      }
      expect(await databaseFacts(f.db), before);
    },
  );

  for (final count in [null, 3]) {
    test(
      'Finish reconciles non-countable known/unknown count $count',
      () async {
        final item = await f.item(count: count);
        final started = await f.start(item);
        final result = saved(
          await f.lifecycle.finish(
            expected: started.activeCycle!,
            finishedOn: date(10),
            today: currentDate,
          ),
        );
        expect(result.activeCycle, isNull);
        expect(result.completedCycles.single.durationDays, 0);
        expect(result.item.stockStatus, StockStatus.outOfStock);
        expect(result.item.packageCount, count == null ? isNull : 0);
      },
    );
  }

  test('Finished earlier closes countable active target and preserves old history/checkpoints', () async {
    final item = await f.item(
      profile: BehaviorProfile.countableReplenishable,
      count: 4,
    );
    final first = await f.start(item, day: 1);
    final old = saved(
      await f.lifecycle.finish(
        expected: first.activeCycle!,
        finishedOn: date(2),
        today: currentDate,
      ),
    ).completedCycles.single;
    final active = saved(
      await f.lifecycle.restock(
        itemId: item.id,
        startedOn: date(10),
        today: currentDate,
        absolutePackageCount: 6,
      ),
    ).activeCycle!;
    final observed = saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    ).checkpoints.single;
    final finished = saved(
      await f.lifecycle.finish(
        expected: active,
        finishedOn: date(15),
        today: currentDate,
      ),
    );
    expect(finished.completedCycles, contains(old));
    expect(finished.checkpoints, [observed]);
    expect(finished.item.packageCount, 0);
    expect(finished.item.stockStatus, StockStatus.outOfStock);
  });

  test('stale/repeated Finish never closes a later active cycle', () async {
    final item = await f.item();
    final original = (await f.start(item)).activeCycle!;
    saved(
      await f.lifecycle.finish(
        expected: original,
        finishedOn: date(12),
        today: currentDate,
      ),
    );
    final replacement = saved(
      await f.lifecycle.restock(
        itemId: item.id,
        startedOn: date(15),
        today: currentDate,
      ),
    );
    final before = await databaseFacts(f.db);
    expect(
      (await f.lifecycle.finish(
        expected: original,
        finishedOn: date(16),
        today: currentDate,
      )).failureOrNull,
      isA<LifecycleTargetFailure>(),
    );
    expect(await databaseFacts(f.db), before);
    expect((await f.snapshot(item.id)).activeCycle, replacement.activeCycle);
  });

  test('date correction requires explicit checkpoint reconciliation and preserves unrelated evidence', () async {
    final item = await f.item();
    final active = (await f.start(item)).activeCycle!;
    final p1 = saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    ).checkpoints.single;
    final p2 = saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.nearlyFinished,
        observedOn: date(18),
        today: currentDate,
      ),
    ).checkpoints.last;
    final completed = saved(
      await f.lifecycle.finish(
        expected: active,
        finishedOn: date(20),
        today: currentDate,
      ),
    ).completedCycles.single;
    final unrelated = saved(
      await f.lifecycle.restock(
        itemId: item.id,
        startedOn: date(22),
        today: currentDate,
      ),
    ).activeCycle!;
    final before = await databaseFacts(f.db);
    final rejected = await f.lifecycle.correctCycleDates(
      expected: completed,
      startedOn: date(13),
      finishedOn: date(17),
      today: currentDate,
    );
    expect(
      (rejected.failureOrNull as LifecycleCheckpointReconciliationFailure)
          .checkpointIds,
      unorderedEquals([p1.id, p2.id]),
    );
    expect(await databaseFacts(f.db), before);
    final corrected = saved(
      await f.lifecycle.correctCycleDates(
        expected: completed,
        startedOn: date(13),
        finishedOn: date(17),
        today: currentDate,
        reconciliation: CheckpointReconciliation(
          corrected: {p1: date(14)},
          removed: {p2},
        ),
      ),
    );
    expect(corrected.activeCycle, unrelated);
    expect(corrected.checkpoints.single.observedOn, date(14));
    expect(corrected.checkpoints.single.id, p1.id);
    expect(corrected.item.stockStatus, StockStatus.inStock);
    expect(corrected.item.packageCount, isNull);
  });

  test(
    'historical date edits cannot reopen cycles or target changed evidence',
    () async {
      final item = await f.item();
      final active = (await f.start(item)).activeCycle!;
      final completed = saved(
        await f.lifecycle.finish(
          expected: active,
          finishedOn: date(15),
          today: currentDate,
        ),
      ).completedCycles.single;
      final before = await databaseFacts(f.db);
      expect(
        (await f.lifecycle.correctCycleDates(
          expected: completed,
          startedOn: date(10),
          finishedOn: null,
          today: currentDate,
        )).failureOrNull,
        isA<LifecycleTargetFailure>(),
      );
      expect(
        (await f.lifecycle.correctCycleDates(
          expected: active,
          startedOn: date(11),
          finishedOn: null,
          today: currentDate,
        )).failureOrNull,
        isA<LifecycleTargetFailure>(),
      );
      expect(
        (await f.lifecycle.correctCycleDates(
          expected: completed,
          startedOn: date(10),
          finishedOn: date(30),
          today: currentDate,
        )).failureOrNull,
        isA<InvalidLifecycleDateFailure>(),
      );
      expect(await databaseFacts(f.db), before);
    },
  );

  test('erroneous-cycle removal cascades only its checkpoints and retains availability', () async {
    final item = await f.item();
    final active = (await f.start(item)).activeCycle!;
    saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    );
    final closed = saved(
      await f.lifecycle.finish(
        expected: active,
        finishedOn: date(15),
        today: currentDate,
      ),
    ).completedCycles.single;
    final replacement = saved(
      await f.lifecycle.restock(
        itemId: item.id,
        startedOn: date(16),
        today: currentDate,
      ),
    ).activeCycle!;
    final after = saved(await f.lifecycle.removeCycle(expected: closed));
    expect(after.cycles, [replacement]);
    expect(after.checkpoints, isEmpty);
    expect(after.item.stockStatus, StockStatus.inStock);
    expect(
      (await f.lifecycle.removeCycle(expected: closed)).failureOrNull,
      isA<LifecycleTargetFailure>(),
    );
  });

  test('checkpoint ownership, uniqueness and future/boundary checks persist safely', () async {
    final first = await f.item();
    final other = await f.item();
    final active = (await f.start(first)).activeCycle!;
    final otherCycle = (await f.start(other)).activeCycle!;
    final p = saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    ).checkpoints.single;
    final before = await databaseFacts(f.db);
    expect(
      (await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: p.kind,
        observedOn: date(13),
        today: currentDate,
      )).failureOrNull,
      isA<LifecycleConflictFailure>(),
    );
    for (final bad in [date(9), date(30)]) {
      expect(
        (await f.lifecycle.correctCheckpoint(
          itemId: first.id,
          expected: p,
          observedOn: bad,
          today: currentDate,
        )).failureOrNull,
        isA<InvalidLifecycleDateFailure>(),
      );
    }
    expect(
      (await f.lifecycle.correctCheckpoint(
        itemId: other.id,
        expected: p,
        observedOn: date(13),
        today: currentDate,
      )).failureOrNull,
      isA<LifecycleTargetFailure>(),
    );
    expect(
      (await f.lifecycle.finish(
        expected: active,
        finishedOn: date(14),
        today: currentDate,
        reconciliation: CheckpointReconciliation(
          removed: {
            LifecycleCheckpoint(
              id: p.id,
              cycleId: otherCycle.id,
              kind: p.kind,
              observedOn: p.observedOn,
            ),
          },
        ),
      )).failureOrNull,
      isA<LifecycleTargetFailure>(),
    );
    expect(await databaseFacts(f.db), before);
    final corrected = saved(
      await f.lifecycle.correctCheckpoint(
        itemId: first.id,
        expected: p,
        observedOn: date(13),
        today: currentDate,
      ),
    ).checkpoints.single;
    expect(corrected.id, p.id);
    expect(corrected.observedOn, date(13));
    expect(
      (await f.lifecycle.correctCheckpoint(
        itemId: first.id,
        expected: p,
        observedOn: date(14),
        today: currentDate,
      )).failureOrNull,
      isA<LifecycleTargetFailure>(),
    );
  });

  test('stale and overlapping reconciliation cannot overwrite newer checkpoint evidence', () async {
    final item = await f.item();
    final active = (await f.start(item)).activeCycle!;
    final p = saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    ).checkpoints.single;
    final stale = CheckpointReconciliation(corrected: {p: date(14)});
    final current = saved(
      await f.lifecycle.correctCheckpoint(
        itemId: item.id,
        expected: p,
        observedOn: date(13),
        today: currentDate,
      ),
    ).checkpoints.single;
    final before = await databaseFacts(f.db);
    expect(
      (await f.lifecycle.finish(
        expected: active,
        finishedOn: date(16),
        today: currentDate,
        reconciliation: stale,
      )).failureOrNull,
      isA<LifecycleTargetFailure>(),
    );
    expect(
      (await f.lifecycle.finish(
        expected: active,
        finishedOn: date(16),
        today: currentDate,
        reconciliation: CheckpointReconciliation(
          corrected: {current: date(14)},
          removed: {current},
        ),
      )).failureOrNull,
      isA<LifecycleTargetFailure>(),
    );
    expect(await databaseFacts(f.db), before);
  });

  test('count reconciliation preserves unrelated metadata and rejects stale availability', () async {
    final item = await f.item(profile: BehaviorProfile.countableReplenishable);
    await f.start(item);
    saved(
      await f.items.updateMetadata(
        expected: saved(await f.items.getItemById(item.id)),
        name: 'Renamed synthetic item',
        areaId: 2,
        unit: 'new context',
      ),
    );
    final next = saved(
      await f.lifecycle.correctCount(expected: item, absoluteCurrentTotal: 7),
    );
    expect(next.item.name, 'Renamed synthetic item');
    expect(next.item.areaId, 2);
    expect(next.item.unit, 'new context');
    expect(next.item.packageCount, 7);
    final before = await databaseFacts(f.db);
    expect(
      (await f.lifecycle.correctCount(
        expected: item,
        absoluteCurrentTotal: 9,
      )).failureOrNull,
      isA<StaleItemFailure>(),
    );
    expect(
      (await f.lifecycle.correctCount(
        expected: next.item,
        absoluteCurrentTotal: 0,
      )).failureOrNull,
      isA<LifecycleConflictFailure>(),
    );
    expect(await databaseFacts(f.db), before);
  });

  test(
    'explicit resolution plus Restock is atomic and uses absolute total',
    () async {
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 5,
      );
      final active = (await f.start(item)).activeCycle!;
      final next = saved(
        await f.lifecycle.restock(
          itemId: item.id,
          startedOn: date(15),
          today: currentDate,
          absolutePackageCount: 3,
          resolution: FinishActiveCycle(expected: active, finishedOn: date(14)),
        ),
      );
      expect(next.completedCycles.single.id, active.id);
      expect(next.completedCycles.single.finishedOn, date(14));
      expect(next.activeCycle!.id, greaterThan(active.id));
      expect(next.item.packageCount, 3);
      final before = await databaseFacts(f.db);
      expect(
        (await f.lifecycle.restock(
          itemId: item.id,
          startedOn: date(16),
          today: currentDate,
          absolutePackageCount: 4,
          resolution: FinishActiveCycle(expected: active, finishedOn: date(15)),
        )).failureOrNull,
        isA<LifecycleTargetFailure>(),
      );
      expect(await databaseFacts(f.db), before);
    },
  );

  test('erroneous-active resolution deletes owned checkpoints and creates one replacement', () async {
    final item = await f.item();
    final active = (await f.start(item)).activeCycle!;
    saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    );
    final next = saved(
      await f.lifecycle.restock(
        itemId: item.id,
        startedOn: date(15),
        today: currentDate,
        resolution: RemoveErroneousActiveCycle(expected: active),
      ),
    );
    expect(next.cycles.length, 1);
    expect(next.activeCycle!.id, greaterThan(active.id));
    expect(next.checkpoints, isEmpty);
    expect(next.item.packageCount, isNull);
  });

  test(
    'invalid replacement never partially resolves old cycle or checkpoints',
    () async {
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 5,
      );
      final active = (await f.start(item)).activeCycle!;
      final before = await databaseFacts(f.db);
      expect(
        (await f.lifecycle.restock(
          itemId: item.id,
          startedOn: date(16),
          today: currentDate,
          absolutePackageCount: 0,
          resolution: FinishActiveCycle(expected: active, finishedOn: date(15)),
        )).failureOrNull,
        isA<LifecycleCountFailure>(),
      );
      expect(await databaseFacts(f.db), before);
    },
  );

  test(
    'bounded history pages and checkpoint reads retain item ownership',
    () async {
      final item = await f.item();
      for (var day = 1; day < 4; day++) {
        final active = saved(
          await f.lifecycle.start(
            itemId: item.id,
            startedOn: date(day),
            today: currentDate,
          ),
        ).activeCycle!;
        saved(
          await f.lifecycle.finish(
            expected: active,
            finishedOn: date(day),
            today: currentDate,
          ),
        );
      }
      final latest = saved(
        await f.lifecycle.getCompletedCycles(item.id, limit: 1),
      ).single;
      final earlier = saved(
        await f.lifecycle.getCompletedCycles(item.id, beforeCycleId: latest.id),
      );
      expect(earlier.length, 2);
      expect(earlier.every((c) => c.id < latest.id), isTrue);
      expect(
        saved(
          await f.lifecycle.getCheckpoints(itemId: item.id, cycleId: latest.id),
        ),
        isEmpty,
      );
      expect(
        (await f.lifecycle.getCheckpoints(
          itemId: 9999,
          cycleId: latest.id,
        )).failureOrNull,
        isA<LifecycleTargetFailure>(),
      );
      expect(
        (await f.lifecycle.getCompletedCycles(
          item.id,
          limit: 101,
        )).failureOrNull,
        isA<ValidationError>(),
      );
      expect(
        (await f.lifecycle.getCompletedCycles(9999)).failureOrNull,
        isA<EntityNotFoundFailure>(),
      );
    },
  );

  test('all mutators reject archived items while archived aggregate/history remains readable', () async {
    final item = await f.item();
    final active = (await f.start(item)).activeCycle!;
    final p = saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    ).checkpoints.single;
    saved(await f.items.archiveItem(item.id));
    final before = await databaseFacts(f.db);
    final commands = [
      f.lifecycle.start(
        itemId: item.id,
        startedOn: date(15),
        today: currentDate,
      ),
      f.lifecycle.restock(
        itemId: item.id,
        startedOn: date(15),
        today: currentDate,
      ),
      f.lifecycle.finish(
        expected: active,
        finishedOn: date(15),
        today: currentDate,
      ),
      f.lifecycle.correctCycleDates(
        expected: active,
        startedOn: date(11),
        finishedOn: null,
        today: currentDate,
      ),
      f.lifecycle.removeCycle(expected: active),
      f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.nearlyFinished,
        observedOn: date(15),
        today: currentDate,
      ),
      f.lifecycle.correctCheckpoint(
        itemId: item.id,
        expected: p,
        observedOn: date(13),
        today: currentDate,
      ),
      f.lifecycle.correctCount(expected: item, absoluteCurrentTotal: 2),
    ];
    for (final result in await Future.wait(commands)) {
      expect(result.failureOrNull, isA<LifecycleConflictFailure>());
    }
    expect(await databaseFacts(f.db), before);
    expect((await f.snapshot(item.id)).item.isArchived, isTrue);
    saved(await f.items.restoreItem(item.id));
    expect((await f.snapshot(item.id)).activeCycle, active);
  });

  test(
    'durable and deleted/missing items fail without fabricating history',
    () async {
      final durable = await f.item(profile: BehaviorProfile.durable);
      expect(
        (await f.lifecycle.start(
          itemId: durable.id,
          startedOn: date(10),
          today: currentDate,
        )).failureOrNull,
        isA<LifecycleProfileFailure>(),
      );
      expect(
        (await f.lifecycle.restock(
          itemId: durable.id,
          startedOn: date(10),
          today: currentDate,
        )).failureOrNull,
        isA<LifecycleProfileFailure>(),
      );
      expect(
        (await f.lifecycle.correctCount(
          expected: durable,
          absoluteCurrentTotal: 3,
        )).failureOrNull,
        isA<LifecycleProfileFailure>(),
      );
      saved(await f.items.deleteItem(durable.id));
      expect(
        (await f.lifecycle.getLifecycle(durable.id)).failureOrNull,
        isA<EntityNotFoundFailure>(),
      );
      expect(
        (await f.lifecycle.start(
          itemId: durable.id,
          startedOn: date(10),
          today: currentDate,
        )).failureOrNull,
        isA<EntityNotFoundFailure>(),
      );
      expect(
        (await f.lifecycle.start(
          itemId: 9999,
          startedOn: date(10),
          today: currentDate,
        )).failureOrNull,
        isA<EntityNotFoundFailure>(),
      );
    },
  );

  for (final profile in [
    BehaviorProfile.replenishable,
    BehaviorProfile.countableReplenishable,
  ]) {
    for (final command in ['count', 'presence', 'whole-item']) {
      test(
        'M2 $command guards active $profile while preserving no-cycle behavior',
        () async {
          final item = await f.item(profile: profile, count: 4);
          final active = (await f.start(item)).activeCycle!;
          final before = await databaseFacts(f.db);
          final useCase = ReconcileItemStockUseCase(f.items);
          final result = switch (command) {
            'count' => await useCase.updatePackageCount(
              itemId: item.id,
              newPackageCount: 0,
            ),
            'presence' => await useCase.updateStockStatus(
              itemId: item.id,
              newStatus: StockStatus.outOfStock,
            ),
            _ => await f.items.updateItem(
              item.copyWith(
                stockStatus: StockStatus.outOfStock,
                packageCount: 0,
              ),
            ),
          };
          expect(
            (result.failureOrNull as ActiveLifecycleResolutionFailure).cycleId,
            active.id,
          );
          expect(await databaseFacts(f.db), before);
          saved(await f.lifecycle.removeCycle(expected: active));
          final after = saved(
            await useCase.updatePackageCount(
              itemId: item.id,
              newPackageCount: 0,
            ),
          );
          expect(after.packageCount, 0);
          expect(after.stockStatus, StockStatus.outOfStock);
          final restored = await useCase.updateStockStatus(
            itemId: item.id,
            newStatus: StockStatus.inStock,
          );
          if (profile == BehaviorProfile.countableReplenishable) {
            expect(saved(restored).packageCount, 1);
          } else {
            expect(restored.failureOrNull, isA<CheckConstraintFailure>());
            expect(saved(await f.items.getItemById(item.id)).packageCount, 0);
          }
        },
      );
    }
  }

  test('move/archive/restore preserve history; permanent delete removes only owned records', () async {
    final item = await f.item();
    final other = await f.item();
    final active = (await f.start(item)).activeCycle!;
    final otherActive = (await f.start(other)).activeCycle!;
    saved(
      await f.lifecycle.addCheckpoint(
        expectedCycle: active,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: date(12),
        today: currentDate,
      ),
    );
    final evidence = await f.snapshot(item.id);
    saved(await f.items.moveItem(itemId: item.id, targetAreaId: 2));
    saved(await f.items.archiveItem(item.id));
    saved(await f.items.restoreItem(item.id));
    final moved = await f.snapshot(item.id);
    expect(moved.item.areaId, 2);
    expect(moved.cycles, evidence.cycles);
    expect(moved.checkpoints, evidence.checkpoints);
    expect(
      (await f.items.updateItem(
        moved.item.copyWith(behaviorProfile: BehaviorProfile.durable),
      )).failureOrNull,
      isA<CheckConstraintFailure>(),
    );
    saved(await f.items.deleteItem(item.id));
    expect(
      (await f.lifecycle.getLifecycle(item.id)).failureOrNull,
      isA<EntityNotFoundFailure>(),
    );
    expect((await f.snapshot(other.id)).activeCycle, otherActive);
    expect(await f.db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
