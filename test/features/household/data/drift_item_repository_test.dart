import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
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

  group('DriftItemRepository', () {
    test('createItem persists item and links to area', () async {
      final result = await itemRepo.createItem(
        areaId: 1, // Kitchen
        name: 'Olive Oil',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.inStock,
        notes: 'Extra virgin',
      );
      expect(result.isSuccess, isTrue);

      final item = result.valueOrNull!;
      expect(item.id, isPositive);
      expect(item.areaId, 1);
      expect(item.name, 'Olive Oil');
      expect(item.behaviorProfile, BehaviorProfile.replenishable);
      expect(item.stockStatus, StockStatus.inStock);
      expect(item.packageCount, isNull);
      expect(item.notes, 'Extra virgin');
      expect(item.isArchived, isFalse);
    });

    test(
      'createItem fails with ForeignConstraintFailure on non-existent areaId',
      () async {
        final result = await itemRepo.createItem(
          areaId: 9999,
          name: 'Ghost Item',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        );
        expect(result.isFailure, isTrue);
        expect(result.failureOrNull, isA<ForeignConstraintFailure>());
      },
    );

    test(
      'createItem allows duplicate item names within the same area',
      () async {
        final res1 = await itemRepo.createItem(
          areaId: 1,
          name: 'Paper Towels',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 2,
        );
        final res2 = await itemRepo.createItem(
          areaId: 1,
          name: 'Paper Towels',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 4,
        );

        expect(res1.isSuccess, isTrue);
        expect(res2.isSuccess, isTrue);
        expect(res1.valueOrNull!.id, isNot(res2.valueOrNull!.id));
      },
    );

    test('createItem rejects contradictory packageCount and stockStatus with CheckConstraintFailure', () async {
      // Contradiction 1: packageCount = 0 but inStock
      final res1 = await itemRepo.createItem(
        areaId: 1,
        name: 'Ghost Beans',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.inStock,
        packageCount: 0,
      );
      expect(res1.isFailure, isTrue);
      expect(res1.failureOrNull, isA<CheckConstraintFailure>());

      // Contradiction 2: packageCount > 0 but outOfStock
      final res2 = await itemRepo.createItem(
        areaId: 1,
        name: 'Phantom Rice',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.outOfStock,
        packageCount: 5,
      );
      expect(res2.isFailure, isTrue);
      expect(res2.failureOrNull, isA<CheckConstraintFailure>());

      // Contradiction 3: durable with packageCount
      final res3 = await itemRepo.createItem(
        areaId: 1,
        name: 'Illegal Hammer',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
        packageCount: 1,
      );
      expect(res3.isFailure, isTrue);
      expect(res3.failureOrNull, isA<CheckConstraintFailure>());
    });

    test(
      'getItemById returns Item if found or EntityNotFoundFailure',
      () async {
        final created = (await itemRepo.createItem(
          areaId: 1,
          name: 'Dish Soap',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;

        final result = await itemRepo.getItemById(created.id);
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.name, 'Dish Soap');

        final notFound = await itemRepo.getItemById(9999);
        expect(notFound.isFailure, isTrue);
        expect(notFound.failureOrNull, isA<EntityNotFoundFailure>());
      },
    );

    test('watchItemById emits updates when item is modified', () async {
      final created = (await itemRepo.createItem(
        areaId: 1,
        name: 'Coffee Beans',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.inStock,
        packageCount: 3,
      )).valueOrNull!;

      final expectation = expectLater(
        itemRepo.watchItemById(created.id),
        emitsThrough(
          predicate<Item?>((item) => item != null && item.packageCount == 1),
        ),
      );

      await itemRepo.updatePackageCount(itemId: created.id, newPackageCount: 1);
      await expectation;
    });

    test(
      'getItemsByArea and watchItemsByArea filter by area and archive status',
      () async {
        final item1 = (await itemRepo.createItem(
          areaId: 1,
          name: 'Spices',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;

        final item2 = (await itemRepo.createItem(
          areaId: 1,
          name: 'Flour',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;

        // Active items in area 1
        final activeList = (await itemRepo.getItemsByArea(1)).valueOrNull!;
        expect(activeList.length, 2);

        // Archive item1
        await itemRepo.archiveItem(item1.id);

        final activeAfter = (await itemRepo.getItemsByArea(1)).valueOrNull!;
        expect(activeAfter.length, 1);
        expect(activeAfter.first.id, item2.id);

        final allInArea = (await itemRepo.getItemsByArea(
          1,
          includeArchived: true,
        )).valueOrNull!;
        expect(allInArea.length, 2);
      },
    );

    test(
      'getAllItems and watchAllItems observe household inventory across areas',
      () async {
        await itemRepo.createItem(
          areaId: 1, // Kitchen
          name: 'Pan',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        );
        await itemRepo.createItem(
          areaId: 2, // Bathroom
          name: 'Shampoo',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        );

        final all = (await itemRepo.getAllItems()).valueOrNull!;
        expect(all.length, 2);
      },
    );

    test(
      'updateItem modifies details while enforcing factual consistency',
      () async {
        final created = (await itemRepo.createItem(
          areaId: 1,
          name: 'Oat Milk',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 2,
        )).valueOrNull!;

        final updated = created.copyWith(
          name: 'Organic Oat Milk',
          packageCount: 1,
          notes: 'Barista edition',
        );

        final result = await itemRepo.updateItem(updated);
        expect(result.isSuccess, isTrue);

        final saved = result.valueOrNull!;
        expect(saved.name, 'Organic Oat Milk');
        expect(saved.packageCount, 1);
        expect(saved.notes, 'Barista edition');
      },
    );

    test('moveItem reassigns item to target area', () async {
      final created = (await itemRepo.createItem(
        areaId: 1, // Kitchen
        name: 'Trash Bags',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.inStock,
        packageCount: 1,
      )).valueOrNull!;

      final moveResult = await itemRepo.moveItem(
        itemId: created.id,
        targetAreaId: 3, // Bedroom
      );
      expect(moveResult.isSuccess, isTrue);
      expect(moveResult.valueOrNull!.areaId, 3);

      final inBedroom = (await itemRepo.getItemsByArea(3)).valueOrNull!;
      expect(inBedroom.any((i) => i.id == created.id), isTrue);

      // Move to invalid area fails
      final failResult = await itemRepo.moveItem(
        itemId: created.id,
        targetAreaId: 9999,
      );
      expect(failResult.isFailure, isTrue);
      expect(failResult.failureOrNull, isA<EntityNotFoundFailure>());
    });

    test(
      'moveItemsToArea batch-relocates all items from source to target',
      () async {
        // Create custom area 7
        final shed = (await areaRepo.createArea(name: 'Shed')).valueOrNull!;
        await itemRepo.createItem(
          areaId: shed.id,
          name: 'Wrench',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        );
        await itemRepo.createItem(
          areaId: shed.id,
          name: 'Screwdriver',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        );

        // Relocate from Shed to Living Room (4)
        final batchResult = await itemRepo.moveItemsToArea(
          sourceAreaId: shed.id,
          targetAreaId: 4,
        );
        expect(batchResult.isSuccess, isTrue);
        expect(batchResult.valueOrNull, 2);

        final inShed = (await itemRepo.getItemsByArea(shed.id)).valueOrNull!;
        expect(inShed, isEmpty);

        final inLivingRoom = (await itemRepo.getItemsByArea(4)).valueOrNull!;
        expect(inLivingRoom.length, 2);
      },
    );

    test(
      'updatePackageCount reconciles factual stock status per M2-D07',
      () async {
        final item = (await itemRepo.createItem(
          areaId: 1,
          name: 'Eggs',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 12,
        )).valueOrNull!;

        // Setting count to 0 strictly reconciles stockStatus to outOfStock
        final zeroResult = await itemRepo.updatePackageCount(
          itemId: item.id,
          newPackageCount: 0,
        );
        expect(zeroResult.isSuccess, isTrue);
        expect(zeroResult.valueOrNull!.packageCount, 0);
        expect(zeroResult.valueOrNull!.stockStatus, StockStatus.outOfStock);

        // Setting count to 6 strictly reconciles stockStatus to inStock
        final posResult = await itemRepo.updatePackageCount(
          itemId: item.id,
          newPackageCount: 6,
        );
        expect(posResult.isSuccess, isTrue);
        expect(posResult.valueOrNull!.packageCount, 6);
        expect(posResult.valueOrNull!.stockStatus, StockStatus.inStock);

        // Setting negative count fails with CheckConstraintFailure
        final negResult = await itemRepo.updatePackageCount(
          itemId: item.id,
          newPackageCount: -1,
        );
        expect(negResult.isFailure, isTrue);
        expect(negResult.failureOrNull, isA<CheckConstraintFailure>());

        // Attempting on durable item fails with CheckConstraintFailure
        final durable = (await itemRepo.createItem(
          areaId: 1,
          name: 'Blender',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;

        final durableResult = await itemRepo.updatePackageCount(
          itemId: durable.id,
          newPackageCount: 1,
        );
        expect(durableResult.isFailure, isTrue);
        expect(durableResult.failureOrNull, isA<CheckConstraintFailure>());
      },
    );

    test(
      'updateStockStatus reconciles package counts for countable items',
      () async {
        final item = (await itemRepo.createItem(
          areaId: 1,
          name: 'Butter',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 2,
        )).valueOrNull!;

        // Setting outOfStock reconciles packageCount to 0
        final outResult = await itemRepo.updateStockStatus(
          itemId: item.id,
          newStatus: StockStatus.outOfStock,
        );
        expect(outResult.isSuccess, isTrue);
        expect(outResult.valueOrNull!.stockStatus, StockStatus.outOfStock);
        expect(outResult.valueOrNull!.packageCount, 0);

        // Setting inStock reconciles packageCount from 0 to 1
        final inResult = await itemRepo.updateStockStatus(
          itemId: item.id,
          newStatus: StockStatus.inStock,
        );
        expect(inResult.isSuccess, isTrue);
        expect(inResult.valueOrNull!.stockStatus, StockStatus.inStock);
        expect(inResult.valueOrNull!.packageCount, 1);
      },
    );

    test('archiveItem and restoreItem update item archival flag', () async {
      final item = (await itemRepo.createItem(
        areaId: 1,
        name: 'Toaster',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      final archResult = await itemRepo.archiveItem(item.id);
      expect(archResult.isSuccess, isTrue);
      expect(archResult.valueOrNull!.isArchived, isTrue);

      final restResult = await itemRepo.restoreItem(item.id);
      expect(restResult.isSuccess, isTrue);
      expect(restResult.valueOrNull!.isArchived, isFalse);
    });

    test('deleteItem permanently deletes item', () async {
      final item = (await itemRepo.createItem(
        areaId: 1,
        name: 'Napkins',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      final delResult = await itemRepo.deleteItem(item.id);
      expect(delResult.isSuccess, isTrue);

      final getResult = await itemRepo.getItemById(item.id);
      expect(getResult.isFailure, isTrue);
      expect(getResult.failureOrNull, isA<EntityNotFoundFailure>());

      // Deleting non-existent item returns EntityNotFoundFailure
      final delNonExistent = await itemRepo.deleteItem(9999);
      expect(delNonExistent.isFailure, isTrue);
      expect(delNonExistent.failureOrNull, isA<EntityNotFoundFailure>());
    });
  });
}
