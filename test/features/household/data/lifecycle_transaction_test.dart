import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/lifecycle_repository.dart';
import 'package:getto/features/household/domain/stock_status.dart';

import '../../../support/lifecycle_repository_fixture.dart';

void main() {
  group('Atomic rollback and committed streams', () {
    late LifecycleFixture f;
    setUp(() => f = LifecycleFixture());
    tearDown(() => f.db.close());

    test('late item-write failure rolls back cycle, checkpoint and availability; retry is safe', () async {
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 4,
      );
      final active = (await f.start(item)).activeCycle!;
      final p = saved(
        await f.lifecycle.addCheckpoint(
          expectedCycle: active,
          kind: LifecycleCheckpointKind.aboutHalf,
          observedOn: date(12),
          today: currentDate,
        ),
      ).checkpoints.single;
      await f.db.customStatement(
        "CREATE TEMP TRIGGER fail_item AFTER UPDATE ON items BEGIN SELECT RAISE(ABORT, 'sensitive fixture SQL payload'); END",
      );
      final before = await databaseFacts(f.db);
      final result = await f.lifecycle.finish(
        expected: active,
        finishedOn: date(14),
        today: currentDate,
        reconciliation: CheckpointReconciliation(corrected: {p: date(11)}),
      );
      expect(result.failureOrNull, isA<CheckConstraintFailure>());
      expect(
        result.failureOrNull.toString(),
        isNot(contains('sensitive fixture')),
      );
      expect(result.failureOrNull.toString(), isNot(contains('SQL payload')));
      expect(await databaseFacts(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_item');
      final next = saved(
        await f.lifecycle.finish(
          expected: active,
          finishedOn: date(14),
          today: currentDate,
          reconciliation: CheckpointReconciliation(corrected: {p: date(11)}),
        ),
      );
      expect(next.completedCycles.length, 1);
      expect(next.checkpoints.single.observedOn, date(11));
      expect(next.item.packageCount, 0);
      expect(
        (await f.lifecycle.finish(
          expected: active,
          finishedOn: date(14),
          today: currentDate,
        )).failureOrNull,
        isA<LifecycleTargetFailure>(),
      );
    });

    test(
      'deferred commit failure returns failure and rolls back all writes',
      () async {
        final item = await f.item();
        final active = (await f.start(item)).activeCycle!;
        await f.db.customStatement(
          'CREATE TABLE m303_commit_guard (owner INTEGER REFERENCES items(id) DEFERRABLE INITIALLY DEFERRED)',
        );
        await f.db.customStatement(
          'CREATE TEMP TRIGGER fail_commit AFTER UPDATE ON items BEGIN INSERT INTO m303_commit_guard VALUES (999999); END',
        );
        final before = await databaseFacts(f.db);
        final result = await f.lifecycle.finish(
          expected: active,
          finishedOn: date(14),
          today: currentDate,
        );
        expect(result.failureOrNull, isA<ForeignConstraintFailure>());
        expect(await databaseFacts(f.db), before);
        expect(
          await f.db.customSelect('SELECT * FROM m303_commit_guard').get(),
          isEmpty,
        );
        await f.db.customStatement('DROP TRIGGER fail_commit');
        expect(
          saved(
            await f.lifecycle.finish(
              expected: active,
              finishedOn: date(14),
              today: currentDate,
            ),
          ).completedCycles.length,
          1,
        );
      },
    );

    test('replacement-insert failure rolls back resolution and all identity allocations', () async {
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 5,
      );
      final active = (await f.start(item)).activeCycle!;
      final p = saved(
        await f.lifecycle.addCheckpoint(
          expectedCycle: active,
          kind: LifecycleCheckpointKind.aboutHalf,
          observedOn: date(12),
          today: currentDate,
        ),
      ).checkpoints.single;
      await f.db.customStatement(
        "CREATE TEMP TRIGGER fail_replacement AFTER INSERT ON lifecycle_cycles BEGIN SELECT RAISE(ABORT, 'controlled replacement fault'); END",
      );
      final before = await databaseFacts(f.db);
      final failed = await f.lifecycle.restock(
        itemId: item.id,
        startedOn: date(16),
        today: currentDate,
        absolutePackageCount: 3,
        resolution: FinishActiveCycle(
          expected: active,
          finishedOn: date(14),
          reconciliation: CheckpointReconciliation(removed: {p}),
        ),
      );
      expect(failed.failureOrNull, isA<CheckConstraintFailure>());
      expect(await databaseFacts(f.db), before);
      await f.db.customStatement('DROP TRIGGER fail_replacement');
      final retried = saved(
        await f.lifecycle.restock(
          itemId: item.id,
          startedOn: date(16),
          today: currentDate,
          absolutePackageCount: 3,
          resolution: FinishActiveCycle(
            expected: active,
            finishedOn: date(14),
            reconciliation: CheckpointReconciliation(removed: {p}),
          ),
        ),
      );
      expect(retried.cycles.length, 2);
      expect(retried.completedCycles.length, 1);
      expect(retried.item.packageCount, 3);
      expect(retried.checkpoints, isEmpty);
    });

    test(
      'zero-row update cannot acknowledge success or retain prior cycle writes',
      () async {
        final item = await f.item();
        await f.db.customStatement(
          'CREATE TEMP TRIGGER ignore_item BEFORE UPDATE ON items BEGIN SELECT RAISE(IGNORE); END',
        );
        final before = await databaseFacts(f.db);
        expect(
          (await f.lifecycle.start(
            itemId: item.id,
            startedOn: date(10),
            today: currentDate,
          )).failureOrNull,
          isA<StaleItemFailure>(),
        );
        expect(await databaseFacts(f.db), before);
        await f.db.customStatement('DROP TRIGGER ignore_item');
        final active = (await f.start(item)).activeCycle!;
        await f.db.customStatement(
          'CREATE TEMP TRIGGER ignore_cycle BEFORE UPDATE ON lifecycle_cycles BEGIN SELECT RAISE(IGNORE); END',
        );
        final started = await databaseFacts(f.db);
        expect(
          (await f.lifecycle.finish(
            expected: active,
            finishedOn: date(14),
            today: currentDate,
          )).failureOrNull,
          isA<StaleItemFailure>(),
        );
        expect(await databaseFacts(f.db), started);
      },
    );

    test('post-write disappearance must throw and roll back instead of returning a committed failure', () async {
      final item = await f.item();
      final active = (await f.start(item)).activeCycle!;
      await f.db.customStatement(
        'CREATE TEMP TRIGGER vanish_item AFTER UPDATE ON items BEGIN DELETE FROM items WHERE id = NEW.id; END',
      );
      final before = await databaseFacts(f.db);
      final result = await f.lifecycle.finish(
        expected: active,
        finishedOn: date(14),
        today: currentDate,
      );
      expect(await databaseFacts(f.db), before);
      expect(result.failureOrNull, isA<StaleItemFailure>());
    });

    test('suppressed insert cannot reuse a previous generated identity or return success', () async {
      final first = await f.item();
      await f.start(first);
      final item = await f.item();
      await f.db.customStatement(
        'CREATE TEMP TRIGGER ignore_cycle BEFORE INSERT ON lifecycle_cycles BEGIN SELECT RAISE(IGNORE); END',
      );
      final before = await databaseFacts(f.db);
      expect(
        (await f.lifecycle.start(
          itemId: item.id,
          startedOn: date(10),
          today: currentDate,
        )).isFailure,
        isTrue,
      );
      expect(await databaseFacts(f.db), before);
    });

    test('aggregate stream exposes committed cross-table facts, rollback silence and deletion', () async {
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 5,
      );
      final iterator = StreamIterator(f.lifecycle.watchLifecycle(item.id));
      try {
        expect(await iterator.moveNext(), isTrue);
        expect(saved(iterator.current).cycles, isEmpty);
        var event = iterator.moveNext();
        final first = saved(
          await f.lifecycle.restock(
            itemId: item.id,
            startedOn: date(10),
            today: currentDate,
            absolutePackageCount: 7,
          ),
        );
        expect(await event, isTrue);
        expect(saved(iterator.current).activeCycle, first.activeCycle);
        expect(saved(iterator.current).item.packageCount, 7);
        event = iterator.moveNext();
        final next = saved(
          await f.lifecycle.restock(
            itemId: item.id,
            startedOn: date(16),
            today: currentDate,
            absolutePackageCount: 3,
            resolution: FinishActiveCycle(
              expected: first.activeCycle!,
              finishedOn: date(15),
            ),
          ),
        );
        expect(await event, isTrue);
        final committed = saved(iterator.current);
        expect(committed.activeCycle, next.activeCycle);
        expect(committed.completedCycles.length, 1);
        expect(committed.item.packageCount, 3);
        expect(committed.item.stockStatus, StockStatus.inStock);
        await f.db.customStatement(
          "CREATE TEMP TRIGGER fail_item AFTER UPDATE ON items BEGIN SELECT RAISE(ABORT, 'controlled'); END",
        );
        event = iterator.moveNext();
        expect(
          (await f.lifecycle.finish(
            expected: next.activeCycle!,
            finishedOn: date(20),
            today: currentDate,
          )).isFailure,
          isTrue,
        );
        await f.db.customStatement('DROP TRIGGER fail_item');
        saved(
          await f.lifecycle.addCheckpoint(
            expectedCycle: next.activeCycle!,
            kind: LifecycleCheckpointKind.aboutHalf,
            observedOn: date(18),
            today: currentDate,
          ),
        );
        expect(await event, isTrue);
        expect(saved(iterator.current).checkpoints.length, 1);
        expect(saved(iterator.current).activeCycle, next.activeCycle);
        event = iterator.moveNext();
        saved(await f.items.deleteItem(item.id));
        expect(await event, isTrue);
        expect(iterator.current.failureOrNull, isA<EntityNotFoundFailure>());
      } finally {
        await iterator.cancel();
      }
    });

    test(
      'simultaneous Starts have one winner and one actionable conflict',
      () async {
        final item = await f.item();
        final results = await Future.wait([
          f.lifecycle.start(
            itemId: item.id,
            startedOn: date(10),
            today: currentDate,
          ),
          f.lifecycle.start(
            itemId: item.id,
            startedOn: date(11),
            today: currentDate,
          ),
        ]);
        expect(results.where((r) => r.isSuccess).length, 1);
        expect(
          results.singleWhere((r) => r.isFailure).failureOrNull,
          isA<LifecycleConflictFailure>(),
        );
        expect((await f.snapshot(item.id)).cycles.length, 1);
      },
    );

    test('concurrent count correction and Finish retain one consistent committed truth', () async {
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 4,
      );
      final initial = await f.start(item);
      final results = await Future.wait([
        f.lifecycle.correctCount(
          expected: initial.item,
          absoluteCurrentTotal: 7,
        ),
        f.lifecycle.finish(
          expected: initial.activeCycle!,
          finishedOn: date(15),
          today: currentDate,
        ),
      ]);
      expect(results.last.isSuccess, isTrue);
      expect(
        results.first.isSuccess ||
            results.first.failureOrNull is StaleItemFailure,
        isTrue,
      );
      final next = await f.snapshot(item.id);
      expect(next.activeCycle, isNull);
      expect(next.item.packageCount, 0);
      expect(next.item.stockStatus, StockStatus.outOfStock);
    });

    test('concurrent checkpoint correction and earlier Finish serialize or reject incompatibility', () async {
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
      final results = await Future.wait([
        f.lifecycle.correctCheckpoint(
          itemId: item.id,
          expected: p,
          observedOn: date(15),
          today: currentDate,
        ),
        f.lifecycle.finish(
          expected: active,
          finishedOn: date(13),
          today: currentDate,
        ),
      ]);
      expect(results.where((r) => r.isSuccess).length, 1);
      expect(
        results.singleWhere((r) => r.isFailure).failureOrNull,
        anyOf(
          isA<InvalidLifecycleDateFailure>(),
          isA<LifecycleCheckpointReconciliationFailure>(),
        ),
      );
      final next = await f.snapshot(item.id);
      final finishedOn = next.cycles.single.finishedOn;
      expect(
        finishedOn == null ||
            !next.checkpoints.single.observedOn.isAfter(finishedOn),
        isTrue,
      );
    });
  });

  group('Isolated file connections', () {
    late bool originalWarningSetting;
    setUpAll(() {
      // These tests intentionally use independent executors for one isolated file.
      originalWarningSetting =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });
    tearDownAll(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          originalWarningSetting,
    );
    late Directory directory;
    late File file;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('getto_m303_');
      file = File('${directory.path}/isolated.sqlite');
    });
    tearDown(() => directory.delete(recursive: true));
    AppDatabase open() => AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (raw) {
          raw.execute('PRAGMA foreign_keys = ON');
          raw.execute('PRAGMA journal_mode = WAL');
          raw.execute('PRAGMA synchronous = FULL');
          raw.execute('PRAGMA busy_timeout = 0');
        },
      ),
    );

    test('committed cycle/checkpoint/count facts survive close and background reopen', () async {
      var f = LifecycleFixture(open());
      final item = await f.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 4,
      );
      final active = (await f.start(item)).activeCycle!;
      final p = saved(
        await f.lifecycle.addCheckpoint(
          expectedCycle: active,
          kind: LifecycleCheckpointKind.aboutHalf,
          observedOn: date(12),
          today: currentDate,
        ),
      ).checkpoints.single;
      saved(
        await f.lifecycle.finish(
          expected: active,
          finishedOn: date(14),
          today: currentDate,
          reconciliation: CheckpointReconciliation(corrected: {p: date(13)}),
        ),
      );
      final before = await databaseFacts(f.db);
      await f.db.close();
      f = LifecycleFixture(open());
      try {
        expect(await databaseFacts(f.db), before);
        expect(
          (await f.snapshot(item.id)).completedCycles.single.finishedOn,
          date(14),
        );
        expect(
          (await f.snapshot(item.id)).checkpoints.single.observedOn,
          date(13),
        );
        expect(
          await f.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await f.db.close();
      }
    });

    test('independent competing Start/Restock connections cannot bypass active uniqueness', () async {
      final a = LifecycleFixture(open());
      final item = await a.item(
        profile: BehaviorProfile.countableReplenishable,
        count: 4,
      );
      final b = LifecycleFixture(open());
      try {
        await b.snapshot(item.id);
        var results = await Future.wait([
          a.lifecycle.start(
            itemId: item.id,
            startedOn: date(10),
            today: currentDate,
          ),
          b.lifecycle.start(
            itemId: item.id,
            startedOn: date(11),
            today: currentDate,
          ),
        ]);
        expect(results.where((r) => r.isSuccess).length, 1);
        expect(
          results.singleWhere((r) => r.isFailure).failureOrNull,
          anyOf(isA<LifecycleConflictFailure>(), isA<DatabaseLockedFailure>()),
        );
        final expected = (await a.snapshot(item.id)).activeCycle!;
        results = await Future.wait([
          a.lifecycle.restock(
            itemId: item.id,
            startedOn: date(16),
            today: currentDate,
            absolutePackageCount: 3,
            resolution: FinishActiveCycle(
              expected: expected,
              finishedOn: date(15),
            ),
          ),
          b.lifecycle.restock(
            itemId: item.id,
            startedOn: date(17),
            today: currentDate,
            absolutePackageCount: 6,
            resolution: FinishActiveCycle(
              expected: expected,
              finishedOn: date(15),
            ),
          ),
        ]);
        expect(results.where((r) => r.isSuccess).length, 1);
        expect(
          results.singleWhere((r) => r.isFailure).failureOrNull,
          anyOf(isA<LifecycleTargetFailure>(), isA<DatabaseLockedFailure>()),
        );
        final finalState = await a.snapshot(item.id);
        expect(finalState.cycles.length, 2);
        expect(finalState.completedCycles.length, 1);
        expect(finalState.item.packageCount, anyOf(3, 6));
        final before = await databaseFacts(a.db);
        expect(
          (await b.lifecycle.restock(
            itemId: item.id,
            startedOn: date(18),
            today: currentDate,
            absolutePackageCount: 9,
            resolution: FinishActiveCycle(
              expected: expected,
              finishedOn: date(15),
            ),
          )).failureOrNull,
          isA<LifecycleTargetFailure>(),
        );
        expect(await databaseFacts(a.db), before);
        expect(
          await a.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await b.db.close();
        await a.db.close();
      }
    });

    test('background constraint errors remain typed and redact transported SQL payloads', () async {
      final f = LifecycleFixture(open());
      try {
        final item = await f.item();
        final active = (await f.start(item)).activeCycle!;
        await f.db.customStatement(
          "CREATE TRIGGER m303_fixture_fault AFTER UPDATE ON items BEGIN SELECT RAISE(ABORT, 'private background fixture payload'); END",
        );
        final before = await databaseFacts(f.db);
        final result = await f.lifecycle.finish(
          expected: active,
          finishedOn: date(14),
          today: currentDate,
        );
        expect(result.failureOrNull, isA<CheckConstraintFailure>());
        expect(
          result.failureOrNull.toString(),
          isNot(contains('private background')),
        );
        expect(result.failureOrNull.toString(), isNot(contains('UPDATE')));
        expect(await databaseFacts(f.db), before);
        final invalid = await f.lifecycle.finish(
          expected: active,
          finishedOn: date(30),
          today: currentDate,
        );
        expect(invalid.failureOrNull, isA<InvalidLifecycleDateFailure>());
      } finally {
        await f.db.close();
      }
    });

    test('controlled writer lock returns typed failure and retry never invents a cycle', () async {
      final a = LifecycleFixture(open());
      final item = await a.item();
      final b = LifecycleFixture(open());
      final acquired = Completer<void>();
      final release = Completer<void>();
      try {
        await b.snapshot(item.id);
        final holding = a.db.transaction(() async {
          await a.db.customSelect('SELECT id FROM items').get();
          acquired.complete();
          await release.future;
        });
        await acquired.future;
        try {
          expect(
            (await b.lifecycle.start(
              itemId: item.id,
              startedOn: date(10),
              today: currentDate,
            )).failureOrNull,
            isA<DatabaseLockedFailure>(),
          );
        } finally {
          release.complete();
          await holding;
        }
        expect((await a.snapshot(item.id)).cycles, isEmpty);
        expect(
          saved(
            await b.lifecycle.start(
              itemId: item.id,
              startedOn: date(10),
              today: currentDate,
            ),
          ).cycles.length,
          1,
        );
        expect(
          (await b.lifecycle.start(
            itemId: item.id,
            startedOn: date(10),
            today: currentDate,
          )).failureOrNull,
          isA<LifecycleConflictFailure>(),
        );
      } finally {
        await b.db.close();
        await a.db.close();
      }
    });
  });
}
