import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/features/household/application/remove_area_use_case.dart';
import 'package:getto/features/household/application/reorder_areas_use_case.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  late AppDatabase db;
  late DriftAreaRepository areas;
  late DriftItemRepository items;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    areas = DriftAreaRepository(db);
    items = DriftItemRepository(db);
    await areas.getAreas();
  });
  tearDown(() => db.close());
  Future<int> seed({bool archived = false}) async {
    final item = (await items.createItem(
      areaId: 1,
      name: 'Saved item',
      behaviorProfile: BehaviorProfile.countableReplenishable,
      stockStatus: StockStatus.inStock,
      packageCount: 7,
      unit: 'boxes',
      notes: 'Retain facts',
    )).valueOrNull!;
    if (archived) await items.archiveItem(item.id);
    return item.id;
  }

  test(
    'focused rename preserves concurrent order, icon, origin and references',
    () async {
      final id = await seed();
      final expected = (await areas.getAreaById(1)).valueOrNull!;
      await areas.updateArea(
        expected.copyWith(iconName: 'changed', displayOrder: 20),
      );
      final saved = (await areas.renameArea(
        expected: expected,
        name: '  Cook room  ',
      )).valueOrNull!;
      expect(saved.name, 'Cook room');
      expect(saved.iconName, 'changed');
      expect(saved.displayOrder, 20);
      expect(saved.isSystem, isTrue);
      expect((await items.getItemById(id)).valueOrNull!.areaId, 1);
    },
  );

  test(
    'concurrent rename has one winner; stale/archive changes cannot overwrite',
    () async {
      final expected = (await areas.getAreaById(1)).valueOrNull!;
      final results = await Future.wait([
        areas.renameArea(expected: expected, name: 'First'),
        areas.renameArea(expected: expected, name: 'Second'),
      ]);
      expect(results.where((r) => r.isSuccess), hasLength(1));
      expect(
        results.where((r) => r.failureOrNull is StaleAreaFailure),
        hasLength(1),
      );
      final fresh = (await areas.getAreaById(1)).valueOrNull!;
      await areas.archiveArea(1);
      expect(
        (await areas.renameArea(
          expected: fresh,
          name: 'Old draft',
        )).failureOrNull,
        isA<StaleAreaFailure>(),
      );
    },
  );

  test(
    'name validation and normalized active conflicts retain saved name',
    () async {
      final expected = (await areas.getAreaById(1)).valueOrNull!;
      for (final name in ['', '   ', 'x' * 51]) {
        expect(
          (await areas.renameArea(
            expected: expected,
            name: name,
          )).failureOrNull,
          isA<CheckConstraintFailure>(),
        );
      }
      expect(
        (await areas.renameArea(
          expected: expected,
          name: ' bathroom ',
        )).failureOrNull,
        isA<UniqueConflictFailure>(),
      );
      expect((await areas.getAreaById(1)).valueOrNull!.name, 'Kitchen');
    },
  );

  test(
    'active reorder preserves archived slots and restore placement',
    () async {
      await areas.archiveArea(2);
      final catalog = (await areas.getAreas(includeArchived: true))
          .valueOrNull!;
      expect(
        (await ReorderAreasUseCase(
          areas,
        ).execute([4, 3, 1], expectedCatalog: catalog)).isSuccess,
        isTrue,
      );
      var all = (await areas.getAreas(includeArchived: true)).valueOrNull!;
      expect(all.map((a) => a.id), [4, 2, 3, 1]);
      expect(all.map((a) => a.displayOrder), [0, 1, 2, 3]);
      await areas.restoreArea(2);
      all = (await areas.getAreas()).valueOrNull!;
      expect(all.map((a) => a.id), [4, 2, 3, 1]);
    },
  );

  for (final mutation in ['create', 'archive', 'delete', 'reorder']) {
    test('catalog $mutation invalidates reorder before any write', () async {
      final expected = (await areas.getAreas(includeArchived: true))
          .valueOrNull!;
      switch (mutation) {
        case 'create':
          await areas.createArea(name: 'Studio');
        case 'archive':
          await areas.archiveArea(2);
        case 'delete':
          await areas.deleteArea(2);
        case 'reorder':
          await areas.reorderAreas([4, 3, 2, 1]);
      }
      final before = (await areas.getAreas(includeArchived: true)).valueOrNull!;
      expect(
        (await areas.reorderAreas([
          4,
          3,
          2,
          1,
        ], expectedCatalog: expected)).failureOrNull,
        isA<StaleAreaFailure>(),
      );
      expect((await areas.getAreas(includeArchived: true)).valueOrNull, before);
    });
  }

  test('incomplete membership rejected; pre-existing order ties resolved deterministically', () async {
    final first = (await areas.getAreaById(1)).valueOrNull!;
    await areas.updateArea(first.copyWith(displayOrder: 1));
    final catalog = (await areas.getAreas(includeArchived: true)).valueOrNull!;
    expect(catalog.take(2).map((a) => a.id), [1, 2]);
    expect(
      (await areas.reorderAreas([
        1,
        2,
      ], expectedCatalog: catalog)).failureOrNull,
      isA<StaleAreaFailure>(),
    );
    expect(
      (await areas.reorderAreas([
        4,
        3,
        2,
        1,
      ], expectedCatalog: catalog)).isSuccess,
      isTrue,
    );
    expect((await areas.getAreas()).valueOrNull!.map((a) => a.displayOrder), [
      0,
      1,
      2,
      3,
    ]);
  });

  test('restore conflict is recoverable by archived rename without losing placement', () async {
    await areas.archiveArea(2);
    final archived = (await areas.getAreaById(2)).valueOrNull!;
    await areas.createArea(name: ' bathroom ');
    expect(
      (await areas.restoreArea(2)).failureOrNull,
      isA<UniqueConflictFailure>(),
    );
    expect((await areas.getAreaById(2)).valueOrNull!.isArchived, isTrue);
    await areas.renameArea(expected: archived, name: 'Guest bathroom');
    final restored = (await areas.restoreArea(2)).valueOrNull!;
    expect(restored.displayOrder, archived.displayOrder);
    expect(restored.isArchived, isFalse);
  });

  test(
    'equal count with different item IDs invalidates destructive consent',
    () async {
      final original = await seed();
      final expected = (await areas.getRemovalSnapshot(
        1,
        targetAreaId: 2,
      )).valueOrNull!;
      await items.deleteItem(original);
      final replacement = await seed();
      final result =
          await RemoveAreaUseCase(
            areaRepository: areas,
            itemRepository: items,
          ).execute(
            areaId: 1,
            targetAreaId: 2,
            mode: AreaRemovalMode.relocateAndDelete,
            expected: expected,
          );
      expect(result.failureOrNull, isA<StaleAreaFailure>());
      expect((await items.getItemById(replacement)).valueOrNull!.areaId, 1);
      expect((await areas.getAreaById(1)).isSuccess, isTrue);
    },
  );

  for (final mutation in [
    'archive item',
    'rename source',
    'archive target',
    'delete target',
    'rename target',
  ]) {
    test('$mutation invalidates removal without mutation', () async {
      final id = await seed();
      final expected = (await areas.getRemovalSnapshot(
        1,
        targetAreaId: 2,
      )).valueOrNull!;
      switch (mutation) {
        case 'archive item':
          await items.archiveItem(id);
        case 'rename source':
          await areas.renameArea(expected: expected.source, name: 'New name');
        case 'archive target':
          await areas.archiveArea(2);
        case 'delete target':
          await areas.deleteArea(2);
        case 'rename target':
          await areas.renameArea(
            expected: expected.destination!,
            name: 'New destination',
          );
      }
      expect(
        (await areas.deleteAreaAndRelocateItems(
          areaId: 1,
          targetAreaId: 2,
          expected: expected,
        )).failureOrNull,
        isA<StaleAreaFailure>(),
      );
      expect((await items.getItemById(id)).valueOrNull!.areaId, 1);
      expect((await areas.getAreaById(1)).isSuccess, isTrue);
    });
  }

  test(
    'archived-only area is populated; archive retains references and flags',
    () async {
      final id = await seed(archived: true);
      final remove = RemoveAreaUseCase(
        areaRepository: areas,
        itemRepository: items,
      );
      expect(
        (await remove.execute(areaId: 1)).failureOrNull,
        isA<AreaNotEmptyFailure>(),
      );
      final before = (await items.getItemById(id)).valueOrNull!;
      await remove.execute(areaId: 1, mode: AreaRemovalMode.archive);
      final after = (await items.getItemById(id)).valueOrNull!;
      expect(after.areaId, before.areaId);
      expect(after.isArchived, isTrue);
      expect(after.packageCount, before.packageCount);
    },
  );

  test('empty confirmation rejects a new archived reference', () async {
    final expected = (await areas.getRemovalSnapshot(1)).valueOrNull!;
    await seed(archived: true);
    expect(
      (await areas.deleteArea(1, expected: expected)).failureOrNull,
      isA<StaleAreaFailure>(),
    );
    expect((await areas.getAreaById(1)).isSuccess, isTrue);
  });

  test('fresh bulk consent preserves current facts and archived restoration destination', () async {
    final active = await seed();
    final archived = await seed(archived: true);
    final expected = (await areas.getRemovalSnapshot(
      1,
      targetAreaId: 2,
    )).valueOrNull!;
    await items.updatePackageCount(itemId: active, newPackageCount: 9);
    expect(
      (await areas.deleteAreaAndRelocateItems(
        areaId: 1,
        targetAreaId: 2,
        expected: expected,
      )).isSuccess,
      isTrue,
    );
    final moved = (await items.getItemById(active)).valueOrNull!;
    expect(moved.areaId, 2);
    expect(moved.packageCount, 9);
    expect(moved.unit, 'boxes');
    expect(moved.notes, 'Retain facts');
    expect((await items.getItemById(archived)).valueOrNull!.isArchived, isTrue);
    expect((await items.restoreItem(archived)).valueOrNull!.areaId, 2);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  for (final trigger in ['ABORT', 'IGNORE']) {
    test('post-relocation deletion $trigger rolls back all item writes', () async {
      final active = await seed();
      final archived = await seed(archived: true);
      final before = (await items.getAllItems(includeArchived: true))
          .valueOrNull!;
      final expected = (await areas.getRemovalSnapshot(
        1,
        targetAreaId: 2,
      )).valueOrNull!;
      await db.customStatement(
        'CREATE TRIGGER stop_delete BEFORE DELETE ON areas WHEN OLD.id = 1 BEGIN SELECT RAISE($trigger${trigger == 'ABORT' ? ", 'injected'" : ''}); END',
      );
      expect(
        (await areas.deleteAreaAndRelocateItems(
          areaId: 1,
          targetAreaId: 2,
          expected: expected,
        )).isFailure,
        isTrue,
      );
      final after = (await items.getAllItems(includeArchived: true))
          .valueOrNull!;
      for (final id in [active, archived]) {
        final old = before.singleWhere((i) => i.id == id);
        final saved = after.singleWhere((i) => i.id == id);
        expect(saved.areaId, old.areaId);
        expect(saved.updatedAt, old.updatedAt);
        expect(saved.packageCount, old.packageCount);
        expect(saved.isArchived, old.isArchived);
      }
      expect((await areas.getAreaById(1)).isSuccess, isTrue);
    });
  }

  test('opt-in creation rejects archived/deleted areas; general semantics remain permissive', () async {
    await areas.archiveArea(1);
    for (final id in [1, 9999]) {
      final result = await items.createItem(
        areaId: id,
        name: 'No write',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
        requireActiveArea: true,
      );
      expect(result.failureOrNull, isA<ForeignConstraintFailure>());
    }
    expect((await items.getAllItems()).valueOrNull, isEmpty);
    expect(
      (await items.createItem(
        areaId: 1,
        name: 'General operation',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).isSuccess,
      isTrue,
    );
  });

  test('file reopen preserves renamed/reordered/archived/relocated areas without reseeding', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp('getto_m234_');
    final file = File('${directory.path}/household.sqlite');
    var disk = AppDatabase(NativeDatabase(file));
    try {
      var repository = DriftAreaRepository(disk);
      var itemRepository = DriftItemRepository(disk);
      final original = (await repository.getAreaById(1)).valueOrNull!;
      await repository.renameArea(expected: original, name: 'Cook room');
      await repository.archiveArea(2);
      final catalog = (await repository.getAreas(includeArchived: true))
          .valueOrNull!;
      await repository.reorderAreas([4, 1, 3], expectedCatalog: catalog);
      final item = (await itemRepository.createItem(
        areaId: 3,
        name: 'Archived saved item',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;
      await itemRepository.archiveItem(item.id);
      final snapshot = (await repository.getRemovalSnapshot(
        3,
        targetAreaId: 1,
      )).valueOrNull!;
      await repository.deleteAreaAndRelocateItems(
        areaId: 3,
        targetAreaId: 1,
        expected: snapshot,
      );
      final before = (await repository.getAreas(includeArchived: true))
          .valueOrNull!;
      await disk.close();
      disk = AppDatabase(NativeDatabase(file));
      repository = DriftAreaRepository(disk);
      itemRepository = DriftItemRepository(disk);
      expect(
        (await repository.getAreas(includeArchived: true)).valueOrNull,
        before,
      );
      expect(
        (await itemRepository.getItemById(item.id)).valueOrNull!.areaId,
        1,
      );
      expect(
        (await itemRepository.getItemById(item.id)).valueOrNull!.isArchived,
        isTrue,
      );
      expect((await repository.restoreArea(2)).valueOrNull!.displayOrder, 1);
      expect((await repository.getAreaById(3)).isFailure, isTrue);
      expect(disk.schemaVersion, 2);
      expect(
        await disk.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await disk.close();
      await directory.delete(recursive: true);
      db = AppDatabase(NativeDatabase.memory());
    }
  });
}
