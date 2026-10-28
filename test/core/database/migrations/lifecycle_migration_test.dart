import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

// These fixtures contain no real household data. All v1 tables are instantiated
// from the retained v1 snapshot rather than the current database definitions.
Future<void> seedV1(GeneratedDatabase db, {bool legacyCatalog = false}) async {
  final names = legacyCatalog
      ? ['Kitchen', 'Bathroom', 'Pantry', 'Living Room', 'Bedroom', 'Storage']
      : ['Custom fixture room', 'Archived fixture room'];
  for (var index = 0; index < names.length; index++) {
    await db.customStatement(
      'INSERT INTO areas (id, name, icon_name, display_order, is_archived, is_system, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        10 + index,
        names[index],
        'fixture_icon',
        index + 2,
        index == 1 ? 1 : 0,
        legacyCatalog ? 1 : 0,
        1700000000 + index,
        1700000100 + index,
      ],
    );
  }
  for (var index = 0; index < 6; index++) {
    final count = [null, 0, 7, null, 2, null][index];
    final profile = index == 5
        ? 'durable'
        : (index == 0 ? 'replenishable' : 'countableReplenishable');
    await db.customStatement(
      'INSERT INTO items (id, area_id, name, behavior_profile, stock_status, unit, package_count, is_archived, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        100 + index,
        10 + index % names.length,
        'Fixture item $index',
        profile,
        count == 0 || index == 5 ? 'outOfStock' : 'inStock',
        index == 5 ? null : 'fixture units',
        count,
        index.isOdd ? 1 : 0,
        index == 0 ? null : 'Fixture note $index',
        1700000200 + index,
        1700000300 + index,
      ],
    );
  }
  // A relocated item keeps its identity and all other facts.
  await db.customStatement('UPDATE items SET area_id = ? WHERE id = 100', [
    10 + names.length - 1,
  ]);
}

Future<Map<String, List<Map<String, Object?>>>> facts(
  GeneratedDatabase db,
) async => {
  for (final table in ['areas', 'items'])
    table: [
      for (final row
          in await db.customSelect('SELECT * FROM $table ORDER BY id').get())
        Map<String, Object?>.from(row.data),
    ],
  'sequences': [
    for (final row
        in await db
            .customSelect(
              "SELECT * FROM sqlite_sequence WHERE name IN ('areas', 'items') ORDER BY name",
            )
            .get())
      Map<String, Object?>.from(row.data),
  ],
};

void main() {
  late SchemaVerifier verifier;
  setUp(() => verifier = SchemaVerifier(GeneratedHelper()));

  for (final legacy in [false, true]) {
    test(
      'real v1 to v2 preserves every household field and ID (legacy catalog: $legacy)',
      () async {
        final schema = await verifier.schemaAt(1);
        final old = v1.DatabaseAtV1(schema.newConnection());
        late Map<String, List<Map<String, Object?>>> before;
        try {
          await seedV1(old, legacyCatalog: legacy);
          before = await facts(old);
          expect(
            (await old.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            1,
          );
        } finally {
          await old.close();
        }
        final db = AppDatabase(schema.newConnection());
        try {
          await verifier.migrateAndValidate(
            db,
            2,
            options: const ValidationOptions(validateDropped: true),
          );
          expect(await facts(db), before);
          expect(await db.select(db.lifecycleCyclesTable).get(), isEmpty);
          expect(await db.select(db.lifecycleCheckpointsTable).get(), isEmpty);
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          expect(
            (await db.customSelect('PRAGMA foreign_keys').getSingle())
                .read<int>('foreign_keys'),
            1,
          );
          expect(
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version'),
            2,
          );
          final active = await db
              .customSelect(
                "SELECT sql FROM sqlite_master WHERE name = 'idx_lifecycle_cycles_active'",
              )
              .getSingle();
          expect(
            active.read<String>('sql'),
            contains('WHERE finished_on IS NULL'),
          );
          // Upgraded databases enforce the same constraint, not just fresh ones.
          await db.customStatement(
            "INSERT INTO lifecycle_cycles (item_id, started_on) VALUES (100, '2026-10-01')",
          );
          await expectLater(
            db.customStatement(
              "INSERT INTO lifecycle_cycles (item_id, started_on) VALUES (100, '2026-10-02')",
            ),
            throwsA(isA<SqliteException>()),
          );
        } finally {
          await db.close();
          schema.close();
        }
      },
    );
  }

  test(
    'empty v1 catalog remains empty without rerunning default-area seed',
    () async {
      final schema = await verifier.schemaAt(1);
      final db = AppDatabase(schema.newConnection());
      try {
        await verifier.migrateAndValidate(db, 2);
        expect(await db.select(db.areasTable).get(), isEmpty);
        expect(await db.select(db.itemsTable).get(), isEmpty);
      } finally {
        await db.close();
        schema.close();
      }
    },
  );

  test('file-backed v1 upgrade persists unchanged facts and v2 schema across reopen', () async {
    final dir = await Directory.systemTemp.createTemp('getto_m302_upgrade_');
    final file = File('${dir.path}/fixture.sqlite');
    QueryExecutor executor() => NativeDatabase(
      file,
      setup: (raw) {
        raw.execute('PRAGMA foreign_keys = ON');
        raw.execute('PRAGMA journal_mode = WAL');
        raw.execute('PRAGMA synchronous = FULL');
      },
    );
    final old = v1.DatabaseAtV1(executor());
    late Map<String, List<Map<String, Object?>>> before;
    try {
      await seedV1(old);
      before = await facts(old);
    } finally {
      await old.close();
    }
    var db = AppDatabase(executor());
    try {
      await verifier.migrateAndValidate(
        db,
        2,
        options: const ValidationOptions(validateDropped: true),
      );
      expect(await facts(db), before);
      await db.close();
      db = AppDatabase(executor());
      expect(await facts(db), before);
      expect(await db.select(db.lifecycleCyclesTable).get(), isEmpty);
      expect(await db.select(db.lifecycleCheckpointsTable).get(), isEmpty);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        2,
      );
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });

  test('mid-migration DDL failure rolls back schema/version, preserves data and permits retry', () async {
    final dir = await Directory.systemTemp.createTemp('getto_m302_failure_');
    final file = File('${dir.path}/fixture.sqlite');
    final old = v1.DatabaseAtV1(NativeDatabase(file));
    late Map<String, List<Map<String, Object?>>> before;
    try {
      await seedV1(old);
      before = await facts(old);
      // Collision forces failure after cycles were created, before completion.
      await old.customStatement(
        'CREATE TABLE lifecycle_checkpoints (sentinel TEXT)',
      );
      await old.customStatement(
        "INSERT INTO lifecycle_checkpoints VALUES ('keep fixture')",
      );
    } finally {
      await old.close();
    }
    final failed = AppDatabase(NativeDatabase(file));
    try {
      await expectLater(
        failed.select(failed.areasTable).get(),
        throwsA(isA<SqliteException>()),
      );
      // Failed-open executor must reject further queries rather than expose
      // a partially migrated schema through the same connection.
      await expectLater(
        failed.select(failed.areasTable).get(),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      await failed.close();
    }
    final raw = sqlite.sqlite3.open(file.path);
    try {
      expect(raw.userVersion, 1);
      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name = 'lifecycle_cycles'",
        ),
        isEmpty,
      );
      expect(
        raw
            .select('SELECT sentinel FROM lifecycle_checkpoints')
            .single['sentinel'],
        'keep fixture',
      );
      for (final table in ['areas', 'items']) {
        expect(
          raw
              .select('SELECT * FROM $table ORDER BY id')
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
          before[table],
        );
      }
      expect(raw.select('PRAGMA foreign_key_check'), isEmpty);
      // Only the deliberately injected fixture collision is removed; production
      // migration has no destructive fallback or collision cleanup.
      raw.execute('DROP TABLE lifecycle_checkpoints');
    } finally {
      raw.close();
    }
    final retry = AppDatabase(NativeDatabase(file));
    try {
      await verifier.migrateAndValidate(
        retry,
        2,
        options: const ValidationOptions(validateDropped: true),
      );
      expect(await facts(retry), before);
      expect(await retry.select(retry.lifecycleCyclesTable).get(), isEmpty);
      expect(
        await retry.select(retry.lifecycleCheckpointsTable).get(),
        isEmpty,
      );
    } finally {
      await retry.close();
      await dir.delete(recursive: true);
    }
  });

  test('pre-existing foreign-key corruption aborts upgrade without repair or data loss', () async {
    final schema = await verifier.schemaAt(1);
    final raw = schema.rawDatabase;
    raw.execute('PRAGMA foreign_keys = OFF');
    raw.execute(
      "INSERT INTO items (id, area_id, name, behavior_profile, stock_status) VALUES (101, 999, 'Isolated orphan fixture', 'replenishable', 'inStock')",
    );
    final db = AppDatabase(schema.newConnection());
    try {
      await expectLater(db.select(db.areasTable).get(), throwsStateError);
      expect(raw.userVersion, 1);
      expect(raw.select('SELECT * FROM items').single['id'], 101);
      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name LIKE 'lifecycle_%'",
        ),
        isEmpty,
      );
      expect(raw.select('PRAGMA foreign_key_check').length, 1);
    } finally {
      await db.close();
      schema.close();
    }
  });
}
