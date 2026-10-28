import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/database/converters/lifecycle_converters.dart';
import 'package:getto/core/domain/local_date/local_date.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/lifecycle_cycle.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  group('In-memory lifecycle constraints', () {
    late AppDatabase db;
    late int itemId;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final area = (await db.select(db.areasTable).get()).first;
      itemId = await db
          .into(db.itemsTable)
          .insert(
            ItemsTableCompanion.insert(
              areaId: area.id,
              name: 'Fixture coffee',
              behaviorProfile: BehaviorProfile.replenishable,
              stockStatus: StockStatus.inStock,
            ),
          );
    });

    tearDown(() => db.close());

    Future<int> cycle({
      int? owner,
      String start = '2026-10-01',
      String? finish,
    }) => db.customInsert(
      'INSERT INTO lifecycle_cycles (item_id, started_on, finished_on) VALUES (?, ?, ?)',
      variables: [
        Variable.withInt(owner ?? itemId),
        Variable.withString(start),
        Variable<String>(finish),
      ],
      updates: {db.lifecycleCyclesTable},
    );

    Future<int> checkpoint(
      int cycleId, {
      String kind = 'aboutHalf',
      String date = '2026-10-05',
    }) => db.customInsert(
      'INSERT INTO lifecycle_checkpoints (cycle_id, kind, observed_on) VALUES (?, ?, ?)',
      variables: [
        Variable.withInt(cycleId),
        Variable.withString(kind),
        Variable.withString(date),
      ],
      updates: {db.lifecycleCheckpointsTable},
    );

    test(
      'fresh v2 matches declared schema, tables, indexes and foreign keys',
      () async {
        expect(db.schemaVersion, 2);
        await db.validateDatabaseSchema(
          options: const ValidationOptions(validateDropped: true),
        );
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
            )
            .get();
        expect(tables.map((row) => row.read<String>('name')), [
          'areas',
          'items',
          'lifecycle_checkpoints',
          'lifecycle_cycles',
        ]);
        final indexes = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
            )
            .get();
        expect(
          indexes.map((row) => row.read<String>('name')),
          unorderedEquals([
            'idx_areas_name_active',
            'idx_areas_order',
            'idx_items_area',
            'idx_items_status',
            'idx_lifecycle_cycles_active',
            'idx_lifecycle_cycles_history',
            'idx_lifecycle_checkpoints_kind',
          ]),
        );
        final active = await db
            .customSelect("PRAGMA index_list('lifecycle_cycles')")
            .get();
        final unique = active.singleWhere(
          (row) => row.read<String>('name') == 'idx_lifecycle_cycles_active',
        );
        expect(unique.read<int>('unique'), 1);
        expect(unique.read<int>('partial'), 1);
        for (final (child, parent, column) in [
          ('lifecycle_cycles', 'items', 'item_id'),
          ('lifecycle_checkpoints', 'lifecycle_cycles', 'cycle_id'),
        ]) {
          final fk = await db
              .customSelect('PRAGMA foreign_key_list($child)')
              .getSingle();
          expect(fk.read<String>('table'), parent);
          expect(fk.read<String>('from'), column);
          expect(fk.read<String>('on_delete'), 'CASCADE');
        }
        expect(
          (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
            'foreign_keys',
          ),
          1,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );

    test(
      'typed dates and checkpoint kinds round trip through relationship query',
      () async {
        final started = LocalDate(2024, 2, 29);
        final id = await db
            .into(db.lifecycleCyclesTable)
            .insert(
              LifecycleCyclesTableCompanion.insert(
                itemId: itemId,
                startedOn: started,
                finishedOn: Value(LocalDate(2024, 3, 1)),
              ),
            );
        await db
            .into(db.lifecycleCheckpointsTable)
            .insert(
              LifecycleCheckpointsTableCompanion.insert(
                cycleId: id,
                kind: LifecycleCheckpointKind.nearlyFinished,
                observedOn: started,
              ),
            );
        final query = db.select(db.lifecycleCyclesTable).join([
          innerJoin(
            db.lifecycleCheckpointsTable,
            db.lifecycleCheckpointsTable.cycleId.equalsExp(
              db.lifecycleCyclesTable.id,
            ),
          ),
        ]);
        final row = await query.getSingle();
        expect(row.readTable(db.lifecycleCyclesTable).startedOn, started);
        expect(
          row.readTable(db.lifecycleCheckpointsTable).kind,
          LifecycleCheckpointKind.nearlyFinished,
        );
        final raw = await db
            .customSelect(
              'SELECT started_on, finished_on FROM lifecycle_cycles',
            )
            .getSingle();
        expect(raw.data, {
          'started_on': '2024-02-29',
          'finished_on': '2024-03-01',
        });
      },
    );

    test(
      'one active cycle per item rejects repeated inserts and stale reopening',
      () async {
        await cycle();
        await expectLater(cycle(), throwsA(isA<SqliteException>()));
        final completed = await cycle(
          start: '2026-09-01',
          finish: '2026-09-02',
        );
        await expectLater(
          db.customStatement(
            'UPDATE lifecycle_cycles SET finished_on = NULL WHERE id = ?',
            [completed],
          ),
          throwsA(isA<SqliteException>()),
        );
        expect((await db.select(db.lifecycleCyclesTable).get()).length, 2);
        final other = await db
            .into(db.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: (await db.select(db.areasTable).get()).first.id,
                name: 'Other fixture',
                behaviorProfile: BehaviorProfile.replenishable,
                stockStatus: StockStatus.inStock,
              ),
            );
        await cycle(owner: other);
      },
    );

    test(
      'completed overlapping cycles and same-day zero duration remain valid',
      () async {
        await cycle(finish: '2026-10-10');
        await cycle(start: '2026-10-05', finish: '2026-10-05');
        await cycle();
        final rows = await db.select(db.lifecycleCyclesTable).get();
        final sameDay = rows.singleWhere(
          (row) => row.startedOn == row.finishedOn,
        );
        expect(
          LifecycleCycle(
            id: sameDay.id,
            itemId: sameDay.itemId,
            startedOn: sameDay.startedOn,
            finishedOn: sameDay.finishedOn,
          ).durationDays,
          0,
        );
      },
    );

    test('invalid finish ordering rejected on insert and update', () async {
      await expectLater(
        cycle(finish: '2026-09-30'),
        throwsA(isA<SqliteException>()),
      );
      final id = await cycle(finish: '2026-10-10');
      await expectLater(
        db.customStatement(
          "UPDATE lifecycle_cycles SET started_on = '2026-10-11' WHERE id = ?",
          [id],
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test(
      'checkpoint kinds unique per cycle and reusable across cycles',
      () async {
        final first = await cycle(finish: '2026-10-10');
        final second = await cycle();
        await checkpoint(first);
        await checkpoint(first, kind: 'nearlyFinished');
        await expectLater(checkpoint(first), throwsA(isA<SqliteException>()));
        await checkpoint(second);
        await expectLater(
          db.customStatement(
            "UPDATE lifecycle_checkpoints SET kind = 'aboutHalf' WHERE cycle_id = ? AND kind = 'nearlyFinished'",
            [first],
          ),
          throwsA(isA<SqliteException>()),
        );
        expect((await db.select(db.lifecycleCheckpointsTable).get()).length, 3);
      },
    );

    test('invalid foreign keys and unsupported kinds rejected', () async {
      await expectLater(cycle(owner: 99999), throwsA(isA<SqliteException>()));
      await expectLater(checkpoint(99999), throwsA(isA<SqliteException>()));
      final id = await cycle();
      await expectLater(
        checkpoint(id, kind: 'almostEmpty'),
        throwsA(isA<SqliteException>()),
      );
      await expectLater(
        db.customStatement(
          'UPDATE lifecycle_cycles SET item_id = 99999 WHERE id = ?',
          [id],
        ),
        throwsA(isA<SqliteException>()),
      );
      final cp = await checkpoint(id);
      await expectLater(
        db.customStatement(
          'UPDATE lifecycle_checkpoints SET cycle_id = 99999 WHERE id = ?',
          [cp],
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    for (final value in [
      '2026-2-01',
      '2026-02-29',
      '2100-02-29',
      '2026-04-31',
      '2026-13-01',
      '2026-00-01',
      '2026-10-00',
      '2026-10-32',
      '2026-10-01T00:00:00Z',
      '1899-12-31',
      '2201-01-01',
      'not-a-date',
      '',
    ]) {
      test(
        'all date columns reject noncanonical/impossible date: $value',
        () async {
          await expectLater(
            cycle(start: value),
            throwsA(isA<SqliteException>()),
          );
          await expectLater(
            cycle(finish: value),
            throwsA(isA<SqliteException>()),
          );
          final id = await cycle();
          await expectLater(
            checkpoint(id, date: value),
            throwsA(isA<SqliteException>()),
          );
        },
      );
    }

    test('date endpoints and Gregorian leap dates match LocalDate', () async {
      for (final value in [
        '1900-01-01',
        '2000-02-29',
        '2024-02-29',
        '2200-12-31',
      ]) {
        final id = await cycle(start: value, finish: value);
        await checkpoint(id, date: value);
      }
      expect((await db.select(db.lifecycleCyclesTable).get()).length, 4);
    });

    test('converters fail closed for unsupported stored values', () {
      const dates = LocalDateConverter();
      expect(dates.toSql(LocalDate(2024, 2, 29)), '2024-02-29');
      expect(() => dates.fromSql('2024-2-29'), throwsFormatException);
      expect(() => dates.fromSql('2026-02-29'), throwsFormatException);
      expect(
        () => const LifecycleCheckpointKindConverter().fromSql('unknown'),
        throwsArgumentError,
      );
    });

    test('M2 rename, relocate, archive and restore retain exact historical evidence', () async {
      final id = await cycle(finish: '2026-10-10');
      await checkpoint(id);
      final cyclesBefore = await db.select(db.lifecycleCyclesTable).get();
      final checkpointsBefore = await db
          .select(db.lifecycleCheckpointsTable)
          .get();
      final repo = DriftItemRepository(db);
      final item = (await repo.getItemById(itemId)).valueOrNull!;
      final otherArea = (await db.select(db.areasTable).get()).last;
      expect(
        (await repo.updateMetadata(
          expected: item,
          name: 'Renamed fixture',
          areaId: otherArea.id,
          unit: 'bag',
        )).isSuccess,
        isTrue,
      );
      expect((await repo.archiveItem(itemId)).isSuccess, isTrue);
      expect(await db.select(db.lifecycleCyclesTable).get(), cyclesBefore);
      expect(
        await db.select(db.lifecycleCheckpointsTable).get(),
        checkpointsBefore,
      );
      expect((await repo.restoreItem(itemId)).isSuccess, isTrue);
      expect(await db.select(db.lifecycleCyclesTable).get(), cyclesBefore);
      expect(
        await db.select(db.lifecycleCheckpointsTable).get(),
        checkpointsBefore,
      );
      await expectLater(
        (db.delete(
          db.areasTable,
        )..where((t) => t.id.equals(otherArea.id))).go(),
        throwsA(isA<SqliteException>()),
      );
    });

    test('controlled transaction failure rolls back item, cycle and checkpoint facts', () async {
      final before = await db.select(db.itemsTable).getSingle();
      await expectLater(
        db.transaction(() async {
          await (db.update(db.itemsTable)..where((t) => t.id.equals(itemId)))
              .write(const ItemsTableCompanion(name: Value('Must roll back')));
          final id = await cycle();
          await checkpoint(id);
          await checkpoint(id);
        }),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.itemsTable).getSingle(), before);
      expect(await db.select(db.lifecycleCyclesTable).get(), isEmpty);
      expect(await db.select(db.lifecycleCheckpointsTable).get(), isEmpty);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    });

    test(
      'permanent deletion cascades only targeted item-owned history atomically',
      () async {
        final first = await cycle(finish: '2026-10-10');
        final second = await cycle();
        await checkpoint(first);
        await checkpoint(second);
        final area = (await db.select(db.areasTable).get()).first;
        final unrelatedItem = await db
            .into(db.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: area.id,
                name: 'Unrelated fixture',
                behaviorProfile: BehaviorProfile.replenishable,
                stockStatus: StockStatus.inStock,
              ),
            );
        final unrelatedCycle = await cycle(owner: unrelatedItem);
        await checkpoint(unrelatedCycle);
        await expectLater(
          db.transaction(() async {
            await (db.delete(
              db.itemsTable,
            )..where((t) => t.id.equals(itemId))).go();
            expect((await db.select(db.lifecycleCyclesTable).get()).length, 1);
            throw StateError('Controlled rollback');
          }),
          throwsStateError,
        );
        expect((await db.select(db.lifecycleCyclesTable).get()).length, 3);
        expect((await db.select(db.lifecycleCheckpointsTable).get()).length, 3);
        expect(
          (await DriftItemRepository(db).deleteItem(itemId)).isSuccess,
          isTrue,
        );
        expect((await db.select(db.itemsTable).getSingle()).id, unrelatedItem);
        expect(
          (await db.select(db.lifecycleCyclesTable).getSingle()).id,
          unrelatedCycle,
        );
        expect(
          (await db.select(db.lifecycleCheckpointsTable).getSingle()).cycleId,
          unrelatedCycle,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      },
    );
  });

  test(
    'file-backed lifecycle facts and cascade deletion survive close/reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'getto_m302_history_',
      );
      final file = File('${directory.path}/isolated.sqlite');
      AppDatabase open() => AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute('PRAGMA foreign_keys = ON');
            raw.execute('PRAGMA journal_mode = WAL');
            raw.execute('PRAGMA synchronous = FULL');
          },
        ),
      );
      var disk = open();
      try {
        final area = (await disk.select(disk.areasTable).get()).first;
        final owner = await disk
            .into(disk.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: area.id,
                name: 'Disk fixture',
                behaviorProfile: BehaviorProfile.replenishable,
                stockStatus: StockStatus.inStock,
              ),
            );
        final id = await disk
            .into(disk.lifecycleCyclesTable)
            .insert(
              LifecycleCyclesTableCompanion.insert(
                itemId: owner,
                startedOn: LocalDate(2024, 2, 29),
                finishedOn: Value(LocalDate(2024, 3, 1)),
              ),
            );
        await disk
            .into(disk.lifecycleCheckpointsTable)
            .insert(
              LifecycleCheckpointsTableCompanion.insert(
                cycleId: id,
                kind: LifecycleCheckpointKind.aboutHalf,
                observedOn: LocalDate(2024, 2, 29),
              ),
            );
        final before = await disk.select(disk.lifecycleCyclesTable).get();
        final cpBefore = await disk
            .select(disk.lifecycleCheckpointsTable)
            .get();
        await disk.close();
        disk = open();
        expect(await disk.select(disk.lifecycleCyclesTable).get(), before);
        expect(
          await disk.select(disk.lifecycleCheckpointsTable).get(),
          cpBefore,
        );
        expect(
          (await disk.customSelect('PRAGMA synchronous').getSingle()).read<int>(
            'synchronous',
          ),
          2,
        );
        expect(
          (await disk.customSelect('PRAGMA journal_mode').getSingle())
              .read<String>('journal_mode'),
          'wal',
        );
        expect(
          await disk.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await DriftItemRepository(disk).deleteItem(owner)).isSuccess,
          isTrue,
        );
        await disk.close();
        disk = open();
        expect(await disk.select(disk.itemsTable).get(), isEmpty);
        expect(await disk.select(disk.lifecycleCyclesTable).get(), isEmpty);
        expect(
          await disk.select(disk.lifecycleCheckpointsTable).get(),
          isEmpty,
        );
        expect(
          await disk.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await disk.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
