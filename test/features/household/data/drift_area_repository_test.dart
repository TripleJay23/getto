import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/database/database_exception_mapper.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/area.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  late AppDatabase db;
  late DriftAreaRepository areaRepo;
  late DriftItemRepository itemRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    areaRepo = DriftAreaRepository(db);
    itemRepo = DriftItemRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftAreaRepository', () {
    test(
      'getAreas returns default seeded areas ordered by displayOrder',
      () async {
        final result = await areaRepo.getAreas();
        expect(result.isSuccess, isTrue);

        final areas = result.valueOrNull!;
        expect(areas.length, 4);
        expect(areas.map((a) => a.name).toList(), [
          'Kitchen',
          'Bathroom',
          'Bedroom',
          'Living Room',
        ]);
        expect(areas.every((a) => a.isSystem), isTrue);
        expect(areas.every((a) => !a.isArchived), isTrue);
      },
    );

    test(
      'getAreaById returns Area if found or EntityNotFoundFailure',
      () async {
        final result = await areaRepo.getAreaById(1);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.name, 'Kitchen');

        final notFound = await areaRepo.getAreaById(9999);
        expect(notFound.isFailure, isTrue);
        expect(notFound.failureOrNull, isA<EntityNotFoundFailure>());
      },
    );

    test('watchAreas emits reactive stream of areas', () async {
      final initialFuture = areaRepo.watchAreas().first;
      final initial = await initialFuture;
      expect(initial.length, 4);

      // Create new area and observe stream emission
      final expectation = expectLater(
        areaRepo.watchAreas(),
        emitsThrough(
          predicate<List<Area>>(
            (list) => list.length == 5 && list.any((a) => a.name == 'Balcony'),
          ),
        ),
      );

      await areaRepo.createArea(name: 'Balcony', iconName: 'balcony');
      await expectation;
    });

    test('watchAreaById emits reactive updates for specific area', () async {
      final expectation = expectLater(
        areaRepo.watchAreaById(1),
        emitsThrough(
          predicate<Area?>((a) => a != null && a.name == 'Chef Kitchen'),
        ),
      );

      final kitchen = (await areaRepo.getAreaById(1)).valueOrNull!;
      await areaRepo.updateArea(kitchen.copyWith(name: 'Chef Kitchen'));
      await expectation;
    });

    test(
      'createArea succeeds and assigns sequential display order if null',
      () async {
        final createResult = await areaRepo.createArea(
          name: 'Garden',
          iconName: 'garden',
        );
        expect(createResult.isSuccess, isTrue);

        final garden = createResult.valueOrNull!;
        expect(garden.name, 'Garden');
        expect(garden.iconName, 'garden');
        expect(garden.displayOrder, 4); // next sequential order
        expect(garden.isSystem, isFalse);
        expect(garden.isArchived, isFalse);
      },
    );

    test(
      'createArea rejects duplicate active name with UniqueConflictFailure',
      () async {
        final duplicateResult = await areaRepo.createArea(
          name: 'kitchen',
        ); // lowercase of Kitchen
        expect(duplicateResult.isFailure, isTrue);
        expect(duplicateResult.failureOrNull, isA<UniqueConflictFailure>());
      },
    );

    test('updateArea preserves canonical isSystem status', () async {
      final kitchen = (await areaRepo.getAreaById(1)).valueOrNull!;
      expect(kitchen.isSystem, isTrue);

      // Attempt to modify isSystem to false via copyWith
      final tampered = kitchen.copyWith(name: 'Main Kitchen', isSystem: false);
      final updateResult = await areaRepo.updateArea(tampered);
      expect(updateResult.isSuccess, isTrue);

      final updated = updateResult.valueOrNull!;
      expect(updated.name, 'Main Kitchen');
      expect(updated.isSystem, isTrue); // Preserved from database record
    });

    test(
      'updateArea returns EntityNotFoundFailure for non-existent ID',
      () async {
        final nonExistent = Area(
          id: 9999,
          name: 'Ghost',
          iconName: 'ghost',
          displayOrder: 0,
          isArchived: false,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        );

        final result = await areaRepo.updateArea(nonExistent);
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<EntityNotFoundFailure>());
      },
    );

    test(
      'reorderAreas updates display orders atomically in a single transaction',
      () async {
        // Reorder areas: Bedroom (3), Kitchen (1), Bathroom (2)
        final reorderResult = await areaRepo.reorderAreas([3, 1, 2]);
        expect(reorderResult.isSuccess, isTrue);

        final bedroom = (await areaRepo.getAreaById(3)).valueOrNull!;
        final kitchen = (await areaRepo.getAreaById(1)).valueOrNull!;
        final bathroom = (await areaRepo.getAreaById(2)).valueOrNull!;

        expect(bedroom.displayOrder, 0);
        expect(kitchen.displayOrder, 1);
        expect(bathroom.displayOrder, 2);
      },
    );

    test(
      'reorderAreas rolls back completely if any ID is non-existent',
      () async {
        final initialKitchen = (await areaRepo.getAreaById(1)).valueOrNull!;

        // Include non-existent ID 9999
        final reorderResult = await areaRepo.reorderAreas([2, 1, 9999]);
        expect(reorderResult.isFailure, isTrue);
        expect(reorderResult.failureOrNull, isA<EntityNotFoundFailure>());

        // Verification of rollback: kitchen still has original order
        final kitchenAfter = (await areaRepo.getAreaById(1)).valueOrNull!;
        expect(kitchenAfter.displayOrder, initialKitchen.displayOrder);
      },
    );

    test('archiveArea and restoreArea manage soft-archival', () async {
      final archiveResult = await areaRepo.archiveArea(4); // Living Room
      expect(archiveResult.isSuccess, isTrue);
      expect(archiveResult.valueOrNull!.isArchived, isTrue);

      // Living Room should not appear in active areas
      final activeAreas = (await areaRepo.getAreas()).valueOrNull!;
      expect(activeAreas.any((a) => a.id == 4), isFalse);

      // Living Room should appear when includeArchived = true
      final allAreas = (await areaRepo.getAreas(includeArchived: true))
          .valueOrNull!;
      expect(allAreas.any((a) => a.id == 4), isTrue);

      // Now create another active area named 'Living Room'
      final newLivingRoom = await areaRepo.createArea(name: 'Living Room');
      expect(newLivingRoom.isSuccess, isTrue);

      // Restoring original archived area should now fail with UniqueConflictFailure
      final restoreResult = await areaRepo.restoreArea(4);
      expect(restoreResult.isFailure, isTrue);
      expect(restoreResult.failureOrNull, isA<UniqueConflictFailure>());
    });

    test('deleteArea succeeds on empty default area (Option 3)', () async {
      // Living Room (area 4) is a default seeded area and has 0 items
      final deleteResult = await areaRepo.deleteArea(4);
      expect(deleteResult.isSuccess, isTrue);

      final check = await areaRepo.getAreaById(4);
      expect(check.isFailure, isTrue);
      expect(check.failureOrNull, isA<EntityNotFoundFailure>());
    });

    test('deleteArea fails with ForeignConstraintFailure on populated default area', () async {
      // Kitchen (area 1) is a default area. Add an item into Kitchen.
      await itemRepo.createItem(
        areaId: 1,
        name: 'Kettle',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      );

      final deleteResult = await areaRepo.deleteArea(1);
      expect(deleteResult.isFailure, isTrue);
      expect(deleteResult.failureOrNull, isA<ForeignConstraintFailure>());
    });

    test(
      'rename default area updates name and preserves isSystem marker',
      () async {
        final kitchen = (await areaRepo.getAreaById(1)).valueOrNull!;
        expect(kitchen.name, 'Kitchen');
        expect(kitchen.isSystem, isTrue);

        final renamed = kitchen.copyWith(name: 'Gourmet Kitchen');
        final updateResult = await areaRepo.updateArea(renamed);
        expect(updateResult.isSuccess, isTrue);
        expect(updateResult.valueOrNull!.name, 'Gourmet Kitchen');
        expect(updateResult.valueOrNull!.isSystem, isTrue);
      },
    );

    test('createArea always assigns isSystem = false and updateArea cannot forge isSystem', () async {
      final userArea = (await areaRepo.createArea(name: 'Sunroom'))
          .valueOrNull!;
      expect(userArea.isSystem, isFalse);

      // Caller attempts to forge isSystem = true via updateArea
      final forged = userArea.copyWith(isSystem: true);
      final updateResult = await areaRepo.updateArea(forged);
      expect(updateResult.isSuccess, isTrue);
      expect(updateResult.valueOrNull!.isSystem, isFalse);

      final fetched = (await areaRepo.getAreaById(userArea.id)).valueOrNull!;
      expect(fetched.isSystem, isFalse);
    });

    test('deleteArea fails with ForeignConstraintFailure if referencing items exist', () async {
      // Create user-defined area
      final workshop = (await areaRepo.createArea(name: 'Workshop'))
          .valueOrNull!;

      // Add item into workshop
      await itemRepo.createItem(
        areaId: workshop.id,
        name: 'Hammer',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      );

      // Attempting deletion of non-empty workshop must fail with ForeignConstraintFailure
      final deleteResult = await areaRepo.deleteArea(workshop.id);
      expect(deleteResult.isFailure, isTrue);
      expect(deleteResult.failureOrNull, isA<ForeignConstraintFailure>());
    });

    test('deleteArea succeeds on empty non-system area', () async {
      final shed = (await areaRepo.createArea(name: 'Shed')).valueOrNull!;
      final deleteResult = await areaRepo.deleteArea(shed.id);
      expect(deleteResult.isSuccess, isTrue);

      final check = await areaRepo.getAreaById(shed.id);
      expect(check.isFailure, isTrue);
      expect(check.failureOrNull, isA<EntityNotFoundFailure>());
    });

    test(
      'getItemCountForArea returns accurate count of active and archived items',
      () async {
        final kitchen = (await areaRepo.getAreaById(1)).valueOrNull!;
        expect((await areaRepo.getItemCountForArea(kitchen.id)).valueOrNull, 0);

        // Add 2 active items and 1 archived item
        await itemRepo.createItem(
          areaId: kitchen.id,
          name: 'Salt',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        );
        final pepper = (await itemRepo.createItem(
          areaId: kitchen.id,
          name: 'Pepper',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;
        await itemRepo.archiveItem(pepper.id);

        expect((await areaRepo.getItemCountForArea(kitchen.id)).valueOrNull, 2);
      },
    );

    test(
      'deleteAreaAndRelocateItems atomically moves items and deletes area',
      () async {
        final workshop = (await areaRepo.createArea(name: 'Workshop'))
            .valueOrNull!;
        final garage = (await areaRepo.createArea(name: 'Garage')).valueOrNull!;

        final wrench = (await itemRepo.createItem(
          areaId: workshop.id,
          name: 'Wrench',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;
        final pliers = (await itemRepo.createItem(
          areaId: workshop.id,
          name: 'Pliers',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;

        final result = await areaRepo.deleteAreaAndRelocateItems(
          areaId: workshop.id,
          targetAreaId: garage.id,
        );
        expect(result.isSuccess, isTrue);

        // Workshop area is deleted
        final checkArea = await areaRepo.getAreaById(workshop.id);
        expect(checkArea.isFailure, isTrue);
        expect(checkArea.failureOrNull, isA<EntityNotFoundFailure>());

        // Items are now in Garage
        final wUpdated = (await itemRepo.getItemById(wrench.id)).valueOrNull!;
        final pUpdated = (await itemRepo.getItemById(pliers.id)).valueOrNull!;
        expect(wUpdated.areaId, garage.id);
        expect(pUpdated.areaId, garage.id);
      },
    );

    test('failure injection: failure during area deletion rolls back item relocation completely', () async {
      final doomedArea = (await areaRepo.createArea(name: 'DoomedArea'))
          .valueOrNull!;
      final safeArea = (await areaRepo.createArea(name: 'SafeArea'))
          .valueOrNull!;

      final item1 = (await itemRepo.createItem(
        areaId: doomedArea.id,
        name: 'Item1',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;
      final item2 = (await itemRepo.createItem(
        areaId: doomedArea.id,
        name: 'Item2',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      // Inject failure: Trigger that aborts deletion when trying to delete DoomedArea
      await db.customStatement('''
          CREATE TRIGGER inject_delete_failure
          BEFORE DELETE ON areas
          WHEN OLD.name = 'DoomedArea'
          BEGIN
            SELECT RAISE(ABORT, 'Simulated area deletion failure');
          END;
        ''');

      // Attempt atomic relocation and deletion
      final result = await areaRepo.deleteAreaAndRelocateItems(
        areaId: doomedArea.id,
        targetAreaId: safeArea.id,
      );
      expect(result.isFailure, isTrue);

      // Verify complete rollback: DoomedArea still exists
      final areaCheck = await areaRepo.getAreaById(doomedArea.id);
      expect(areaCheck.isSuccess, isTrue);
      expect(areaCheck.valueOrNull!.name, 'DoomedArea');

      // Verify complete rollback: Items are still in DoomedArea, NOT in SafeArea
      final i1 = (await itemRepo.getItemById(item1.id)).valueOrNull!;
      final i2 = (await itemRepo.getItemById(item2.id)).valueOrNull!;
      expect(i1.areaId, doomedArea.id);
      expect(i2.areaId, doomedArea.id);

      final safeItems = (await itemRepo.getItemsByArea(safeArea.id))
          .valueOrNull!;
      expect(safeItems, isEmpty);
    });

    test('deleteAreaAndRelocateItems preserves active and archived items and their factual state', () async {
      final workshop = (await areaRepo.createArea(name: 'Workshop'))
          .valueOrNull!;
      final garage = (await areaRepo.createArea(name: 'Garage')).valueOrNull!;

      // Active item with package count
      final nails = (await itemRepo.createItem(
        areaId: workshop.id,
        name: 'Nails',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.inStock,
        packageCount: 50,
      )).valueOrNull!;

      // Archived item
      final oldSaw = (await itemRepo.createItem(
        areaId: workshop.id,
        name: 'Old Saw',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;
      await itemRepo.archiveItem(oldSaw.id);

      final res = await areaRepo.deleteAreaAndRelocateItems(
        areaId: workshop.id,
        targetAreaId: garage.id,
      );
      expect(res.isSuccess, isTrue);

      // Verify active item in garage
      final updatedNails = (await itemRepo.getItemById(nails.id)).valueOrNull!;
      expect(updatedNails.areaId, garage.id);
      expect(updatedNails.isArchived, isFalse);
      expect(updatedNails.packageCount, 50);
      expect(updatedNails.stockStatus, StockStatus.inStock);

      // Verify archived item in garage retains archived status and factual state
      final updatedSaw = (await itemRepo.getItemById(oldSaw.id)).valueOrNull!;
      expect(updatedSaw.areaId, garage.id);
      expect(updatedSaw.isArchived, isTrue);
      expect(updatedSaw.stockStatus, StockStatus.inStock);
    });

    test('DatabaseExceptionMapper produces sanitized typed failures with zero SQL or user data leaks', () {
      final sqlError = SqliteException(
        extendedResultCode: 275,
        message: 'CHECK constraint failed: items',
        causingStatement: 'INSERT INTO items (name, notes) VALUES (?, ?)',
        parametersToStatement: ['Secret Meds', 'Private note'],
      );
      final mapped = mapDatabaseException(sqlError);
      expect(mapped, isA<CheckConstraintFailure>());
      expect(
        mapped.message,
        'Operation violates database check constraints and consistency rules',
      );
      expect(mapped.toString(), contains('SQLite[code: 19, extended: 275]'));
      expect(mapped.toString(), isNot(contains('Secret Meds')));
      expect(mapped.toString(), isNot(contains('Private note')));
      expect(mapped.toString(), isNot(contains('INSERT INTO')));
    });
  });
}
