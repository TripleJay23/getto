import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('getto_repo_durability_');
    dbFile = File('${tempDir.path}/durability_test.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Repository operations persist correctly across database close and reopen',
    () async {
      // 1. Initial connection & repository instances
      var db = AppDatabase(NativeDatabase(dbFile));
      var areaRepo = DriftAreaRepository(db);
      var itemRepo = DriftItemRepository(db);

      // Verify default seeded areas
      final seeded = (await areaRepo.getAreas()).valueOrNull!;
      expect(seeded.length, 4);

      // Create a custom area
      final customArea = (await areaRepo.createArea(
        name: 'Attic',
        iconName: 'attic',
      )).valueOrNull!;
      expect(customArea.name, 'Attic');

      // Create items of different behavior profiles
      final coffee = (await itemRepo.createItem(
        areaId: 1, // Kitchen
        name: 'Espresso Beans',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.inStock,
        packageCount: 3,
        unit: 'bags',
        notes: 'Dark roast',
      )).valueOrNull!;

      final toaster = (await itemRepo.createItem(
        areaId: 1, // Kitchen
        name: 'Toaster',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;

      final trashBags = (await itemRepo.createItem(
        areaId: customArea.id,
        name: 'Trash Bags',
        behaviorProfile: BehaviorProfile.replenishable,
        stockStatus: StockStatus.outOfStock,
      )).valueOrNull!;

      // Archive one item
      await itemRepo.archiveItem(toaster.id);

      // Update package count on coffee
      await itemRepo.updatePackageCount(itemId: coffee.id, newPackageCount: 1);

      // Reorder areas
      await areaRepo.reorderAreas([customArea.id, 1, 2, 3, 4]);

      // 2. Close database connection
      await db.close();

      // Ensure file exists and has content
      expect(await dbFile.exists(), isTrue);
      expect(await dbFile.length(), isPositive);

      // 3. Re-open connection with fresh repository instances
      db = AppDatabase(NativeDatabase(dbFile));
      areaRepo = DriftAreaRepository(db);
      itemRepo = DriftItemRepository(db);

      // 4. Verify all persisted state survived restart
      final reopenedAreas = (await areaRepo.getAreas()).valueOrNull!;
      expect(reopenedAreas.length, 5);
      expect(reopenedAreas.first.name, 'Attic');
      expect(reopenedAreas.first.displayOrder, 0);

      final reopenedCoffee = (await itemRepo.getItemById(coffee.id))
          .valueOrNull!;
      expect(reopenedCoffee.name, 'Espresso Beans');
      expect(reopenedCoffee.packageCount, 1);
      expect(reopenedCoffee.stockStatus, StockStatus.inStock);
      expect(reopenedCoffee.unit, 'bags');
      expect(reopenedCoffee.notes, 'Dark roast');
      expect(reopenedCoffee.isArchived, isFalse);

      final reopenedToaster = (await itemRepo.getItemById(toaster.id))
          .valueOrNull!;
      expect(reopenedToaster.name, 'Toaster');
      expect(reopenedToaster.isArchived, isTrue);
      expect(reopenedToaster.packageCount, isNull);

      final reopenedTrashBags = (await itemRepo.getItemById(trashBags.id))
          .valueOrNull!;
      expect(reopenedTrashBags.name, 'Trash Bags');
      expect(reopenedTrashBags.areaId, customArea.id);
      expect(reopenedTrashBags.stockStatus, StockStatus.outOfStock);

      await db.close();
    },
  );

  test(
    'Deleted default area does not reappear after database close and reopen',
    () async {
      // 1. Initial connection
      var db = AppDatabase(NativeDatabase(dbFile));
      var areaRepo = DriftAreaRepository(db);

      // Verify default seeded areas (4 areas)
      final initialAreas = (await areaRepo.getAreas()).valueOrNull!;
      expect(initialAreas.length, 4);
      expect(initialAreas.any((a) => a.name == 'Living Room'), isTrue);
      final livingRoomArea = initialAreas.firstWhere(
        (a) => a.name == 'Living Room',
      );

      // Delete the empty default area 'Living Room'
      final deleteResult = await areaRepo.deleteArea(livingRoomArea.id);
      expect(deleteResult.isSuccess, isTrue);

      final remainingAreas = (await areaRepo.getAreas()).valueOrNull!;
      expect(remainingAreas.length, 3);
      expect(remainingAreas.any((a) => a.name == 'Living Room'), isFalse);

      // 2. Close database connection
      await db.close();

      // 3. Reopen database connection
      db = AppDatabase(NativeDatabase(dbFile));
      areaRepo = DriftAreaRepository(db);

      // 4. Verify deleted default area did NOT reappear
      final reopenedAreas = (await areaRepo.getAreas()).valueOrNull!;
      expect(reopenedAreas.length, 3);
      expect(reopenedAreas.any((a) => a.name == 'Living Room'), isFalse);

      await db.close();
    },
  );
}
