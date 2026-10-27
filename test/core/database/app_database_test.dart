import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AppDatabase Foundation & Schema v1', () {
    test('enforces foreign keys pragma on open', () async {
      final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
      expect(result.data['foreign_keys'], 1);
    });

    test(
      'initializes schema v1 and seeds default 4 areas on first creation',
      () async {
        final areas = await db.select(db.areasTable).get();
        expect(areas.length, 4);

        final expectedAreas = [
          ('Kitchen', 'kitchen', 0),
          ('Bathroom', 'bathroom', 1),
          ('Bedroom', 'bedroom', 2),
          ('Living Room', 'living_room', 3),
        ];

        for (var i = 0; i < expectedAreas.length; i++) {
          final expected = expectedAreas[i];
          final actual = areas[i];
          expect(actual.name, expected.$1);
          expect(actual.iconName, expected.$2);
          expect(actual.displayOrder, expected.$3);
          expect(actual.isArchived, isFalse);
          expect(actual.isSystem, isTrue);
        }
      },
    );

    test('enforces active area name uniqueness (case-insensitive)', () async {
      // 'Kitchen' already exists from seed. Attempting to add 'kitchen' must fail.
      expect(
        () => db
            .into(db.areasTable)
            .insert(
              AreasTableCompanion.insert(
                name: 'kitchen',
                iconName: const Value('kitchen_alt'),
              ),
            ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.resultCode,
            'resultCode',
            19, // SQLITE_CONSTRAINT_UNIQUE
          ),
        ),
      );
    });

    test('allows reusing archived area name for new active area', () async {
      // Archive existing 'Living Room' area
      await (db.update(db.areasTable)
            ..where((t) => t.name.equals('Living Room')))
          .write(const AreasTableCompanion(isArchived: Value(true)));

      // Now adding a new active 'Living Room' area should succeed
      final newId = await db
          .into(db.areasTable)
          .insert(
            AreasTableCompanion.insert(
              name: 'Living Room',
              iconName: const Value('living_room'),
              displayOrder: const Value(10),
            ),
          );

      expect(newId, isPositive);

      final livingRoomAreas = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Living Room'))).get();
      expect(livingRoomAreas.length, 2);
      expect(livingRoomAreas.where((a) => a.isArchived).length, 1);
      expect(livingRoomAreas.where((a) => !a.isArchived).length, 1);
    });

    test('enforces foreign key integrity when inserting items', () async {
      // Find Kitchen area ID
      final kitchen = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Kitchen'))).getSingle();

      // Insert item with valid areaId
      final itemId = await db
          .into(db.itemsTable)
          .insert(
            ItemsTableCompanion.insert(
              areaId: kitchen.id,
              name: 'Olive Oil',
              behaviorProfile: BehaviorProfile.replenishable,
              stockStatus: StockStatus.inStock,
            ),
          );
      expect(itemId, isPositive);

      // Insert item with invalid non-existent areaId
      expect(
        () => db
            .into(db.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: 99999, // non-existent
                name: 'Ghost Item',
                behaviorProfile: BehaviorProfile.replenishable,
                stockStatus: StockStatus.inStock,
              ),
            ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('FOREIGN KEY'),
          ),
        ),
      );
    });

    test('restricts area deletion when referencing items exist (ON DELETE RESTRICT)', () async {
      final kitchen = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Kitchen'))).getSingle();

      await db
          .into(db.itemsTable)
          .insert(
            ItemsTableCompanion.insert(
              areaId: kitchen.id,
              name: 'Dish Soap',
              behaviorProfile: BehaviorProfile.replenishable,
              stockStatus: StockStatus.inStock,
            ),
          );

      // Attempting to delete Kitchen area must be restricted
      expect(
        () => (db.delete(
          db.areasTable,
        )..where((t) => t.id.equals(kitchen.id))).go(),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('FOREIGN KEY'),
          ),
        ),
      );
    });

    test('allows area deletion if no referencing items exist', () async {
      final livingRoom = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Living Room'))).getSingle();

      // Living Room has 0 items, deletion should succeed
      final rowsDeleted = await (db.delete(
        db.areasTable,
      )..where((t) => t.id.equals(livingRoom.id))).go();
      expect(rowsDeleted, 1);

      final exists = await (db.select(
        db.areasTable,
      )..where((t) => t.id.equals(livingRoom.id))).getSingleOrNull();
      expect(exists, isNull);
    });

    test('allows duplicate item names within the same area', () async {
      final bedroom = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Bedroom'))).getSingle();

      // Insert first 'Tissues' in Bedroom
      final id1 = await db
          .into(db.itemsTable)
          .insert(
            ItemsTableCompanion.insert(
              areaId: bedroom.id,
              name: 'Tissues',
              behaviorProfile: BehaviorProfile.countableReplenishable,
              stockStatus: StockStatus.inStock,
              packageCount: const Value(2),
            ),
          );
      expect(id1, isPositive);

      // Inserting second 'Tissues' in same Bedroom must succeed
      final id2 = await db
          .into(db.itemsTable)
          .insert(
            ItemsTableCompanion.insert(
              areaId: bedroom.id,
              name: 'Tissues',
              behaviorProfile: BehaviorProfile.countableReplenishable,
              stockStatus: StockStatus.inStock,
              packageCount: const Value(5),
            ),
          );
      expect(id2, isPositive);
      expect(id2, isNot(id1));

      final bedroomItems = await (db.select(
        db.itemsTable,
      )..where((t) => t.areaId.equals(bedroom.id))).get();
      expect(bedroomItems.where((i) => i.name == 'Tissues').length, 2);
    });

    test('enforces check constraints on behaviorProfile, stockStatus, and packageCount', () async {
      final kitchen = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Kitchen'))).getSingle();

      // Invalid behaviorProfile via raw SQL
      expect(
        () => db.customInsert(
          'INSERT INTO items (area_id, name, behavior_profile, stock_status) VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withInt(kitchen.id),
            Variable.withString('Invalid Profile'),
            Variable.withString('bogus'),
            Variable.withString('inStock'),
          ],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // Invalid stockStatus via raw SQL
      expect(
        () => db.customInsert(
          'INSERT INTO items (area_id, name, behavior_profile, stock_status) VALUES (?, ?, ?, ?)',
          variables: [
            Variable.withInt(kitchen.id),
            Variable.withString('Invalid Status'),
            Variable.withString('replenishable'),
            Variable.withString('runningLow'),
          ],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // Negative packageCount via raw SQL
      expect(
        () => db.customInsert(
          'INSERT INTO items (area_id, name, behavior_profile, stock_status, package_count) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(kitchen.id),
            Variable.withString('Negative Count'),
            Variable.withString('replenishable'),
            Variable.withString('inStock'),
            Variable.withInt(-1),
          ],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // Factual contradiction: package_count = 0 with stock_status = 'inStock'
      expect(
        () => db.customInsert(
          'INSERT INTO items (area_id, name, behavior_profile, stock_status, package_count) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(kitchen.id),
            Variable.withString('Zero InStock Contradiction'),
            Variable.withString('countableReplenishable'),
            Variable.withString('inStock'),
            Variable.withInt(0),
          ],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // Factual contradiction: package_count > 0 with stock_status = 'outOfStock'
      expect(
        () => db.customInsert(
          'INSERT INTO items (area_id, name, behavior_profile, stock_status, package_count) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(kitchen.id),
            Variable.withString('Positive OutOfStock Contradiction'),
            Variable.withString('countableReplenishable'),
            Variable.withString('outOfStock'),
            Variable.withInt(5),
          ],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // Durable profile restriction: durable item with non-null package_count
      expect(
        () => db.customInsert(
          'INSERT INTO items (area_id, name, behavior_profile, stock_status, package_count) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(kitchen.id),
            Variable.withString('Durable With Count'),
            Variable.withString('durable'),
            Variable.withString('inStock'),
            Variable.withInt(1),
          ],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );
    });

    test('enforces factual integrity check constraints on updates', () async {
      final kitchen = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Kitchen'))).getSingle();

      // Insert valid item initially
      final itemId = await db
          .into(db.itemsTable)
          .insert(
            ItemsTableCompanion.insert(
              areaId: kitchen.id,
              name: 'Paper Napkins',
              behaviorProfile: BehaviorProfile.countableReplenishable,
              stockStatus: StockStatus.inStock,
              packageCount: const Value(4),
            ),
          );

      // 1. Invalid update: change status to outOfStock while keeping package_count = 4
      expect(
        () => db.customUpdate(
          'UPDATE items SET stock_status = ? WHERE id = ?',
          variables: [
            Variable.withString('outOfStock'),
            Variable.withInt(itemId),
          ],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // 2. Invalid update: change package_count to 0 while keeping status = inStock
      expect(
        () => db.customUpdate(
          'UPDATE items SET package_count = ? WHERE id = ?',
          variables: [Variable.withInt(0), Variable.withInt(itemId)],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // 3. Invalid update: change package_count to negative
      expect(
        () => db.customUpdate(
          'UPDATE items SET package_count = ? WHERE id = ?',
          variables: [Variable.withInt(-2), Variable.withInt(itemId)],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // 4. Invalid update: change profile to durable while package_count is 4
      expect(
        () => db.customUpdate(
          'UPDATE items SET behavior_profile = ? WHERE id = ?',
          variables: [Variable.withString('durable'), Variable.withInt(itemId)],
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.message,
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );

      // 5. Valid atomic update: reconcile status and count to outOfStock and 0
      final rowsUpdated = await db.customUpdate(
        'UPDATE items SET stock_status = ?, package_count = ? WHERE id = ?',
        variables: [
          Variable.withString('outOfStock'),
          Variable.withInt(0),
          Variable.withInt(itemId),
        ],
      );
      expect(rowsUpdated, 1);

      final updatedRow = await (db.select(
        db.itemsTable,
      )..where((t) => t.id.equals(itemId))).getSingle();
      expect(updatedRow.stockStatus, StockStatus.outOfStock);
      expect(updatedRow.packageCount, 0);
    });

    test('rolls back transactions completely upon SQLite constraint failure', () async {
      final initialItems = await db.select(db.itemsTable).get();
      final kitchen = await (db.select(
        db.areasTable,
      )..where((t) => t.name.equals('Kitchen'))).getSingle();

      expect(
        () => db.transaction(() async {
          // 1. Valid operation inside transaction
          await db
              .into(db.itemsTable)
              .insert(
                ItemsTableCompanion.insert(
                  areaId: kitchen.id,
                  name: 'Valid Item Inside Transaction',
                  behaviorProfile: BehaviorProfile.replenishable,
                  stockStatus: StockStatus.inStock,
                ),
              );

          // 2. Invalid operation inside same transaction (violates check constraint)
          await db.customInsert(
            'INSERT INTO items (area_id, name, behavior_profile, stock_status, package_count) VALUES (?, ?, ?, ?, ?)',
            variables: [
              Variable.withInt(kitchen.id),
              Variable.withString('Invalid Item In Transaction'),
              Variable.withString('countableReplenishable'),
              Variable.withString('inStock'),
              Variable.withInt(0), // Fails CHECK constraint!
            ],
          );
        }),
        throwsA(isA<SqliteException>()),
      );

      final postItems = await db.select(db.itemsTable).get();
      expect(postItems.length, initialItems.length);
      expect(
        postItems.any((i) => i.name == 'Valid Item Inside Transaction'),
        isFalse,
        reason:
            'Valid item inserted before failure must be completely rolled back',
      );
    });

    test('verifies all four declared indexes exist in live SQLite schema', () async {
      final rows = await db
          .customSelect(
            "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%' ORDER BY name;",
          )
          .get();

      final indexMap = {
        for (final row in rows)
          row.data['name'] as String: row.data['sql'] as String,
      };

      expect(
        indexMap.keys,
        containsAll([
          'idx_areas_name_active',
          'idx_areas_order',
          'idx_items_area',
          'idx_items_status',
        ]),
      );

      // Verify index definitions match expected SQL
      expect(
        indexMap['idx_areas_name_active'],
        contains(
          'CREATE UNIQUE INDEX idx_areas_name_active ON areas (LOWER(name)) WHERE is_archived = 0',
        ),
      );
      expect(
        indexMap['idx_areas_order'],
        contains(
          'CREATE INDEX idx_areas_order ON areas (display_order) WHERE is_archived = 0',
        ),
      );
      expect(
        indexMap['idx_items_area'],
        contains('CREATE INDEX idx_items_area ON items (area_id, is_archived)'),
      );
      expect(
        indexMap['idx_items_status'],
        contains(
          'CREATE INDEX idx_items_status ON items (stock_status, is_archived)',
        ),
      );
    });

    test(
      'persists representative profile, count, and stock status combinations',
      () async {
        final kitchen = await (db.select(
          db.areasTable,
        )..where((t) => t.name.equals('Kitchen'))).getSingle();

        // 1. Regular replenishable (inStock, null packageCount)
        final repId = await db
            .into(db.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: kitchen.id,
                name: 'Olive Oil',
                behaviorProfile: BehaviorProfile.replenishable,
                stockStatus: StockStatus.inStock,
              ),
            );
        expect(repId, isPositive);

        // 2. Countable replenishable in stock (inStock, packageCount > 0)
        final countInId = await db
            .into(db.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: kitchen.id,
                name: 'Paper Towels',
                behaviorProfile: BehaviorProfile.countableReplenishable,
                stockStatus: StockStatus.inStock,
                packageCount: const Value(6),
                unit: const Value('rolls'),
              ),
            );
        expect(countInId, isPositive);

        // 3. Countable replenishable depleted (outOfStock, packageCount = 0)
        final countOutId = await db
            .into(db.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: kitchen.id,
                name: 'Garbage Bags',
                behaviorProfile: BehaviorProfile.countableReplenishable,
                stockStatus: StockStatus.outOfStock,
                packageCount: const Value(0),
                unit: const Value('boxes'),
              ),
            );
        expect(countOutId, isPositive);

        // 4. Durable possession (inStock, null packageCount)
        final durableId = await db
            .into(db.itemsTable)
            .insert(
              ItemsTableCompanion.insert(
                areaId: kitchen.id,
                name: 'Blender',
                behaviorProfile: BehaviorProfile.durable,
                stockStatus: StockStatus.inStock,
              ),
            );
        expect(durableId, isPositive);

        // Verify all 4 items retrieved accurately
        final items = await (db.select(
          db.itemsTable,
        )..where((t) => t.areaId.equals(kitchen.id))).get();
        expect(items.length, 4);

        final repItem = items.firstWhere((i) => i.id == repId);
        expect(repItem.behaviorProfile, BehaviorProfile.replenishable);
        expect(repItem.stockStatus, StockStatus.inStock);
        expect(repItem.packageCount, isNull);

        final countInItem = items.firstWhere((i) => i.id == countInId);
        expect(
          countInItem.behaviorProfile,
          BehaviorProfile.countableReplenishable,
        );
        expect(countInItem.stockStatus, StockStatus.inStock);
        expect(countInItem.packageCount, 6);

        final countOutItem = items.firstWhere((i) => i.id == countOutId);
        expect(
          countOutItem.behaviorProfile,
          BehaviorProfile.countableReplenishable,
        );
        expect(countOutItem.stockStatus, StockStatus.outOfStock);
        expect(countOutItem.packageCount, 0);

        final durItem = items.firstWhere((i) => i.id == durableId);
        expect(durItem.behaviorProfile, BehaviorProfile.durable);
        expect(durItem.stockStatus, StockStatus.inStock);
        expect(durItem.packageCount, isNull);

        // Verify mapping to pure Domain Item entity succeeds for all valid rows
        for (final itemData in items) {
          final domainItem = Item(
            id: itemData.id,
            areaId: itemData.areaId,
            name: itemData.name,
            behaviorProfile: itemData.behaviorProfile,
            stockStatus: itemData.stockStatus,
            unit: itemData.unit,
            packageCount: itemData.packageCount,
            isArchived: itemData.isArchived,
            notes: itemData.notes,
            createdAt: itemData.createdAt,
            updatedAt: itemData.updatedAt,
          );
          expect(domainItem.name, itemData.name);
          expect(domainItem.stockStatus, itemData.stockStatus);
          expect(domainItem.packageCount, itemData.packageCount);
        }
      },
    );
  });
}
