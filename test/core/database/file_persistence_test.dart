import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  group('File-Backed Persistence & Restart Durability', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('getto_test_db_');
      dbFile = File('${tempDir.path}/getto_durability.sqlite');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'preserves household areas and items across database close and reopen',
      () async {
        // 1. Initial Launch
        final db1 = AppDatabase(
          NativeDatabase(
            dbFile,
            setup: (rawDb) {
              rawDb.execute('PRAGMA foreign_keys = ON;');
              rawDb.execute('PRAGMA journal_mode = WAL;');
              rawDb.execute('PRAGMA synchronous = FULL;');
            },
          ),
        );

        // Verify effective connection PRAGMAs on live disk-backed database
        final sync1 = await db1.customSelect('PRAGMA synchronous;').getSingle();
        final journal1 = await db1
            .customSelect('PRAGMA journal_mode;')
            .getSingle();
        final fk1 = await db1.customSelect('PRAGMA foreign_keys;').getSingle();
        expect(
          sync1.data['synchronous'],
          2,
          reason: 'Expected synchronous=FULL (2)',
        );
        expect(
          journal1.data['journal_mode'].toString().toLowerCase(),
          'wal',
          reason: 'Expected journal_mode=WAL',
        );
        expect(
          fk1.data['foreign_keys'],
          1,
          reason: 'Expected foreign_keys=ON (1)',
        );

        // Verify default seed was created
        final initialAreas = await db1.select(db1.areasTable).get();
        expect(
          initialAreas.length,
          4,
          reason: 'Expected exactly 4 default areas on first launch',
        );
        expect(initialAreas.every((a) => a.isSystem), isTrue);

        final kitchen = initialAreas.firstWhere((a) => a.name == 'Kitchen');

        // Insert an item into the kitchen
        final insertedItemId = await db1
            .into(db1.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: kitchen.id,
                name: 'Coffee Beans',
                behaviorProfile: BehaviorProfile.replenishable,
                stockStatus: StockStatus.inStock,
                unit: const Value('bag'),
                packageCount: const Value(2),
              ),
            );
        expect(insertedItemId, isPositive);

        // Verify item exists in first session
        final itemsSession1 = await db1.select(db1.itemsTable).get();
        expect(itemsSession1.length, 1);
        expect(itemsSession1.first.name, 'Coffee Beans');

        // Close the first database connection cleanly
        await db1.close();

        // Ensure SQLite file exists on disk
        expect(await dbFile.exists(), isTrue);

        // 2. Restart / Reopen session against the existing file
        final db2 = AppDatabase(
          NativeDatabase(
            dbFile,
            setup: (rawDb) {
              rawDb.execute('PRAGMA foreign_keys = ON;');
              rawDb.execute('PRAGMA journal_mode = WAL;');
              rawDb.execute('PRAGMA synchronous = FULL;');
            },
          ),
        );

        // Verify areas count is still 4 (onCreate did NOT re-run to duplicate seeds)
        final reopenedAreas = await db2.select(db2.areasTable).get();
        expect(
          reopenedAreas.length,
          4,
          reason: 'Areas must not be duplicated on reopen',
        );

        // Verify inserted item survived restart identically
        final itemsSession2 = await db2.select(db2.itemsTable).get();
        expect(itemsSession2.length, 1);
        final reopenedItem = itemsSession2.first;
        expect(reopenedItem.id, insertedItemId);
        expect(reopenedItem.areaId, kitchen.id);
        expect(reopenedItem.name, 'Coffee Beans');
        expect(reopenedItem.behaviorProfile, BehaviorProfile.replenishable);
        expect(reopenedItem.stockStatus, StockStatus.inStock);
        expect(reopenedItem.packageCount, 2);
        expect(reopenedItem.unit, 'bag');

        // Close the second connection
        await db2.close();
      },
    );
    test(
      'four-area seed preserves an existing six-area household on reopen',
      () async {
        var db = AppDatabase(NativeDatabase(dbFile));
        await db.select(db.areasTable).get();
        // Reconstruct the previous catalog in an isolated local fixture.
        await db.transaction(() async {
          await db.delete(db.areasTable).go();
          const legacyNames = [
            'Kitchen',
            'Bathroom',
            'Pantry',
            'Living Room',
            'Bedroom',
            'Storage',
          ];
          for (var index = 0; index < legacyNames.length; index++) {
            await db
                .into(db.areasTable)
                .insert(
                  AreasTableCompanion.insert(
                    id: Value(index + 1),
                    name: legacyNames[index],
                    displayOrder: Value(index),
                    isSystem: const Value(true),
                  ),
                );
          }
          await db
              .into(db.itemsTable)
              .insert(
                ItemsTableCompanion.insert(
                  areaId: 3,
                  name: 'Retained pantry item',
                  behaviorProfile: BehaviorProfile.replenishable,
                  stockStatus: StockStatus.inStock,
                ),
              );
          await db
              .into(db.itemsTable)
              .insert(
                ItemsTableCompanion.insert(
                  areaId: 6,
                  name: 'Retained storage item',
                  behaviorProfile: BehaviorProfile.durable,
                  stockStatus: StockStatus.outOfStock,
                ),
              );
        });
        final areasBefore = await db.select(db.areasTable).get();
        final itemsBefore = await db.select(db.itemsTable).get();
        await db.close();

        db = AppDatabase(NativeDatabase(dbFile));
        try {
          expect(db.schemaVersion, 2);
          expect(await db.select(db.areasTable).get(), areasBefore);
          expect(await db.select(db.itemsTable).get(), itemsBefore);
        } finally {
          await db.close();
        }
      },
    );
  });
}
