import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/application/move_item_use_case.dart';
import 'package:getto/features/household/application/reconcile_item_stock_use_case.dart';
import 'package:getto/features/household/application/remove_area_use_case.dart';
import 'package:getto/features/household/application/reorder_areas_use_case.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  late AppDatabase db;
  late DriftAreaRepository areaRepo;
  late DriftItemRepository itemRepo;
  late RemoveAreaUseCase removeAreaUseCase;
  late ReorderAreasUseCase reorderAreasUseCase;
  late ReconcileItemStockUseCase reconcileStockUseCase;
  late MoveItemUseCase moveItemUseCase;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    areaRepo = DriftAreaRepository(db);
    itemRepo = DriftItemRepository(db);

    removeAreaUseCase = RemoveAreaUseCase(
      areaRepository: areaRepo,
      itemRepository: itemRepo,
    );
    reorderAreasUseCase = ReorderAreasUseCase(areaRepo);
    reconcileStockUseCase = ReconcileItemStockUseCase(itemRepo);
    moveItemUseCase = MoveItemUseCase(
      itemRepository: itemRepo,
      areaRepository: areaRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('RemoveAreaUseCase', () {
    test('deleteIfEmpty succeeds on empty default area', () async {
      final res = await removeAreaUseCase.execute(
        areaId: 1, // Kitchen (isSystem = true, empty)
        mode: AreaRemovalMode.deleteIfEmpty,
      );
      expect(res.isSuccess, isTrue);

      final check = await areaRepo.getAreaById(1);
      expect(check.isFailure, isTrue);
      expect(check.failureOrNull, isA<EntityNotFoundFailure>());
    });

    test(
      'deleteIfEmpty fails on populated default area with AreaNotEmptyFailure',
      () async {
        await itemRepo.createItem(
          areaId: 2, // Bathroom (isSystem = true)
          name: 'Soap',
          behaviorProfile: BehaviorProfile.replenishable,
          stockStatus: StockStatus.inStock,
        );

        final res = await removeAreaUseCase.execute(
          areaId: 2,
          mode: AreaRemovalMode.deleteIfEmpty,
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<AreaNotEmptyFailure>());
        final failure = res.failureOrNull! as AreaNotEmptyFailure;
        expect(failure.areaId, 2);
        expect(failure.itemCount, 1);
      },
    );

    test('allows soft-archival of system areas', () async {
      final res = await removeAreaUseCase.execute(
        areaId: 1,
        mode: AreaRemovalMode.archive,
      );
      expect(res.isSuccess, isTrue);

      final kitchen = (await areaRepo.getAreaById(1)).valueOrNull!;
      expect(kitchen.isArchived, isTrue);
    });

    test('deleteIfEmpty deletes empty non-system area', () async {
      final yard = (await areaRepo.createArea(name: 'Yard')).valueOrNull!;

      final res = await removeAreaUseCase.execute(
        areaId: yard.id,
        mode: AreaRemovalMode.deleteIfEmpty,
      );
      expect(res.isSuccess, isTrue);

      final check = await areaRepo.getAreaById(yard.id);
      expect(check.isFailure, isTrue);
    });

    test(
      'deleteIfEmpty fails with AreaNotEmptyFailure if area contains items',
      () async {
        final garage = (await areaRepo.createArea(name: 'Garage')).valueOrNull!;
        await itemRepo.createItem(
          areaId: garage.id,
          name: 'Tire Pump',
          behaviorProfile: BehaviorProfile.durable,
          stockStatus: StockStatus.inStock,
        );

        final res = await removeAreaUseCase.execute(
          areaId: garage.id,
          mode: AreaRemovalMode.deleteIfEmpty,
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<AreaNotEmptyFailure>());

        final failure = res.failureOrNull! as AreaNotEmptyFailure;
        expect(failure.areaId, garage.id);
        expect(failure.itemCount, 1);
      },
    );

    test('relocateAndDelete requires valid targetAreaId', () async {
      final attic = (await areaRepo.createArea(name: 'Attic')).valueOrNull!;

      // No target area provided
      final noTarget = await removeAreaUseCase.execute(
        areaId: attic.id,
        mode: AreaRemovalMode.relocateAndDelete,
      );
      expect(noTarget.isFailure, isTrue);
      expect(noTarget.failureOrNull, isA<ValidationError>());

      // Same area provided
      final sameTarget = await removeAreaUseCase.execute(
        areaId: attic.id,
        mode: AreaRemovalMode.relocateAndDelete,
        targetAreaId: attic.id,
      );
      expect(sameTarget.isFailure, isTrue);
      expect(sameTarget.failureOrNull, isA<ValidationError>());
    });

    test(
      'relocateAndDelete moves all items to target then deletes source area',
      () async {
        final cellar = (await areaRepo.createArea(name: 'Cellar')).valueOrNull!;
        final livingRoom = (await areaRepo.getAreaById(4)).valueOrNull!;

        await itemRepo.createItem(
          areaId: cellar.id,
          name: 'Wine',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 6,
        );
        await itemRepo.createItem(
          areaId: cellar.id,
          name: 'Cider',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
          packageCount: 3,
        );

        final res = await removeAreaUseCase.execute(
          areaId: cellar.id,
          mode: AreaRemovalMode.relocateAndDelete,
          targetAreaId: livingRoom.id,
        );
        expect(res.isSuccess, isTrue);

        // Cellar is deleted
        final cellarCheck = await areaRepo.getAreaById(cellar.id);
        expect(cellarCheck.isFailure, isTrue);

        // Items now in Living Room
        final inLivingRoom = (await itemRepo.getItemsByArea(livingRoom.id))
            .valueOrNull!;
        expect(inLivingRoom.length, 2);
        expect(inLivingRoom.map((i) => i.name).toSet(), {'Wine', 'Cider'});
      },
    );

    test('failure injection: failure during relocateAndDelete preserves source area and original item locations', () async {
      final doomedCellar = (await areaRepo.createArea(name: 'DoomedCellar'))
          .valueOrNull!;
      final livingRoom = (await areaRepo.getAreaById(4)).valueOrNull!;

      final wine = (await itemRepo.createItem(
        areaId: doomedCellar.id,
        name: 'Vintage Wine',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      // Inject failure on delete of DoomedCellar
      await db.customStatement('''
          CREATE TRIGGER abort_doomed_cellar_delete
          BEFORE DELETE ON areas
          WHEN OLD.name = 'DoomedCellar'
          BEGIN
            SELECT RAISE(ABORT, 'Simulated delete failure');
          END;
        ''');

      final res = await removeAreaUseCase.execute(
        areaId: doomedCellar.id,
        mode: AreaRemovalMode.relocateAndDelete,
        targetAreaId: livingRoom.id,
      );
      expect(res.isFailure, isTrue);

      // Verification of atomicity: source area still exists
      final areaCheck = await areaRepo.getAreaById(doomedCellar.id);
      expect(areaCheck.isSuccess, isTrue);

      // Verification of atomicity: item was NOT moved to Living Room
      final wineCheck = (await itemRepo.getItemById(wine.id)).valueOrNull!;
      expect(wineCheck.areaId, doomedCellar.id);

      final livingRoomItems = (await itemRepo.getItemsByArea(livingRoom.id))
          .valueOrNull!;
      expect(livingRoomItems.any((i) => i.id == wine.id), isFalse);
    });
  });

  group('ReorderAreasUseCase', () {
    test('rejects empty list with ValidationError', () async {
      final res = await reorderAreasUseCase.execute([]);
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ValidationError>());
    });

    test('rejects duplicates with ValidationError', () async {
      final res = await reorderAreasUseCase.execute([1, 2, 1]);
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ValidationError>());
    });

    test('reorders areas successfully', () async {
      final res = await reorderAreasUseCase.execute([3, 2, 1]);
      expect(res.isSuccess, isTrue);

      final a3 = (await areaRepo.getAreaById(3)).valueOrNull!;
      final a2 = (await areaRepo.getAreaById(2)).valueOrNull!;
      final a1 = (await areaRepo.getAreaById(1)).valueOrNull!;

      expect(a3.displayOrder, 0);
      expect(a2.displayOrder, 1);
      expect(a1.displayOrder, 2);
    });
  });

  group('ReconcileItemStockUseCase', () {
    test(
      'updatePackageCount rejects negative counts with ValidationError',
      () async {
        final res = await reconcileStockUseCase.updatePackageCount(
          itemId: 1,
          newPackageCount: -5,
        );
        expect(res.isFailure, isTrue);
        expect(res.failureOrNull, isA<ValidationError>());
      },
    );

    test('updatePackageCount updates count and status consistently', () async {
      final item = (await itemRepo.createItem(
        areaId: 1,
        name: 'Pasta',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.inStock,
        packageCount: 4,
      )).valueOrNull!;

      final res = await reconcileStockUseCase.updatePackageCount(
        itemId: item.id,
        newPackageCount: 0,
      );
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull!.packageCount, 0);
      expect(res.valueOrNull!.stockStatus, StockStatus.outOfStock);
    });

    test('updateStockStatus updates status and reconciles count', () async {
      final item = (await itemRepo.createItem(
        areaId: 1,
        name: 'Rice',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.outOfStock,
        packageCount: 0,
      )).valueOrNull!;

      final res = await reconcileStockUseCase.updateStockStatus(
        itemId: item.id,
        newStatus: StockStatus.inStock,
      );
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull!.stockStatus, StockStatus.inStock);
      expect(res.valueOrNull!.packageCount, 1);
    });
  });

  group('MoveItemUseCase', () {
    test('rejects moving to non-existent area', () async {
      final item = (await itemRepo.createItem(
        areaId: 1,
        name: 'Sponge',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      final res = await moveItemUseCase.execute(
        itemId: item.id,
        targetAreaId: 9999,
      );
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<EntityNotFoundFailure>());
    });

    test('rejects moving to archived area with ValidationError', () async {
      final item = (await itemRepo.createItem(
        areaId: 1,
        name: 'Soap',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      final room = (await areaRepo.createArea(name: 'Guest Room')).valueOrNull!;
      await areaRepo.archiveArea(room.id);

      final res = await moveItemUseCase.execute(
        itemId: item.id,
        targetAreaId: room.id,
      );
      expect(res.isFailure, isTrue);
      expect(res.failureOrNull, isA<ValidationError>());
    });

    test('moves item to valid active area', () async {
      final item = (await itemRepo.createItem(
        areaId: 1, // Kitchen
        name: 'Mop',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      final res = await moveItemUseCase.execute(
        itemId: item.id,
        targetAreaId: 4, // Living Room
      );
      expect(res.isSuccess, isTrue);
      expect(res.valueOrNull!.areaId, 4);
    });
  });
}
