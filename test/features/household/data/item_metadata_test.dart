import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/stock_status.dart';

void main() {
  late AppDatabase db;
  late DriftItemRepository items;
  late DriftAreaRepository areas;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    items = DriftItemRepository(db);
    areas = DriftAreaRepository(db);
  });
  tearDown(() => db.close());
  for (final operation in ['metadata', 'count', 'presence']) {
    test(
      'opt-in active guard rejects archived $operation atomically and permits restored items',
      () async {
        final original = (await items.createItem(
          areaId: 1,
          name: 'Guarded item',
          behaviorProfile: BehaviorProfile.countableReplenishable,
          stockStatus: StockStatus.inStock,
        )).valueOrNull!;
        final archived = (await items.archiveItem(original.id)).valueOrNull!;
        Future<Result<Item, DataFailure>> command() => switch (operation) {
          'metadata' => items.updateMetadata(
            expected: original,
            name: 'Changed',
            areaId: 2,
            unit: 'bag',
            requireActive: true,
          ),
          'count' => items.updatePackageCount(
            itemId: original.id,
            newPackageCount: 0,
            requireActive: true,
          ),
          _ => items.updateStockStatus(
            itemId: original.id,
            newStatus: StockStatus.outOfStock,
            requireActive: true,
          ),
        };
        expect((await command()).failureOrNull, isA<ItemArchivedFailure>());
        expect((await items.getItemById(original.id)).valueOrNull, archived);
        await items.restoreItem(original.id);
        expect((await command()).isSuccess, isTrue);
      },
    );
  }
  Future<Item> seed({
    int? count,
    BehaviorProfile profile = BehaviorProfile.countableReplenishable,
  }) async => (await items.createItem(
    areaId: 1,
    name: 'Coffee',
    behaviorProfile: profile,
    stockStatus: count == 0 ? StockStatus.outOfStock : StockStatus.inStock,
    packageCount: count,
    unit: 'bags',
    notes: 'Keep this note',
  )).valueOrNull!;

  test('atomic metadata edits trim, move and explicitly clear context, preserving facts', () async {
    final before = await seed(count: 4);
    await items.archiveItem(before.id);
    final archived = (await items.getItemById(before.id)).valueOrNull!;
    final saved = (await items.updateMetadata(
      expected: archived,
      name: '  Beans  ',
      areaId: 2,
      unit: null,
    )).valueOrNull!;
    expect(saved.name, 'Beans');
    expect(saved.areaId, 2);
    expect(saved.unit, isNull);
    expect(saved.id, before.id);
    expect(saved.createdAt, before.createdAt);
    expect(saved.packageCount, 4);
    expect(saved.stockStatus, before.stockStatus);
    expect(saved.behaviorProfile, before.behaviorProfile);
    expect(saved.notes, before.notes);
    expect(saved.isArchived, isTrue);
  });
  test('duplicate names and trimmed context are legal', () async {
    final first = await seed();
    final second = await seed();
    final saved = await items.updateMetadata(
      expected: second,
      name: first.name,
      areaId: 1,
      unit: '  1 L  ',
    );
    expect(saved.valueOrNull!.unit, '1 L');
    expect((await items.getAllItems()).valueOrNull!.length, 2);
  });
  for (final name in ['', '   ', 'x' * 101]) {
    test(
      'invalid name of length ${name.length} leaves every field unchanged',
      () async {
        final before = await seed();
        expect(
          (await items.updateMetadata(
            expected: before,
            name: name,
            areaId: 2,
            unit: null,
          )).failureOrNull,
          isA<CheckConstraintFailure>(),
        );
        expect((await items.getItemById(before.id)).valueOrNull, before);
      },
    );
  }
  test(
    'unit validation permits exactly 20 characters and whitespace clearing',
    () async {
      final before = await seed();
      expect(
        (await items.updateMetadata(
          expected: before,
          name: 'Changed',
          areaId: 2,
          unit: 'x' * 21,
        )).isFailure,
        isTrue,
      );
      expect((await items.getItemById(before.id)).valueOrNull, before);
      final saved = (await items.updateMetadata(
        expected: before,
        name: 'Coffee',
        areaId: 1,
        unit: 'x' * 20,
      )).valueOrNull!;
      expect(saved.unit!.length, 20);
      expect(
        (await items.updateMetadata(
          expected: saved,
          name: 'Coffee',
          areaId: 1,
          unit: '  ',
        )).valueOrNull!.unit,
        isNull,
      );
    },
  );
  test(
    'concurrent stock correction survives editing from an older snapshot',
    () async {
      final before = await seed(count: 4);
      await items.updatePackageCount(itemId: before.id, newPackageCount: 0);
      final saved = (await items.updateMetadata(
        expected: before,
        name: 'Beans',
        areaId: 2,
        unit: null,
      )).valueOrNull!;
      expect(saved.packageCount, 0);
      expect(saved.stockStatus, StockStatus.outOfStock);
    },
  );
  for (final mutation in ['metadata', 'archive', 'move', 'behavior']) {
    test(
      'stale $mutation conflicts do not partly overwrite saved facts',
      () async {
        final before = await seed();
        switch (mutation) {
          case 'metadata':
            await items.updateMetadata(
              expected: before,
              name: 'Newer',
              areaId: 1,
              unit: 'box',
            );
          case 'archive':
            await items.archiveItem(before.id);
          case 'move':
            await items.moveItem(itemId: before.id, targetAreaId: 2);
          case 'behavior':
            await items.updateItem(
              before.copyWith(behaviorProfile: BehaviorProfile.replenishable),
            );
        }
        final latest = (await items.getItemById(before.id)).valueOrNull!;
        expect(
          (await items.updateMetadata(
            expected: before,
            name: 'Stale',
            areaId: 3,
            unit: null,
          )).failureOrNull,
          isA<StaleItemFailure>(),
        );
        expect((await items.getItemById(before.id)).valueOrNull, latest);
      },
    );
  }
  test('two concurrent edits from one snapshot have one winner', () async {
    final before = await seed();
    final results = await Future.wait([
      items.updateMetadata(
        expected: before,
        name: 'First',
        areaId: 2,
        unit: null,
      ),
      items.updateMetadata(
        expected: before,
        name: 'Second',
        areaId: 3,
        unit: 'box',
      ),
    ]);
    expect(results.where((r) => r.isSuccess).length, 1);
    expect(results.where((r) => r.failureOrNull is StaleItemFailure).length, 1);
    final saved = (await items.getItemById(before.id)).valueOrNull!;
    expect(
      saved.name == 'First'
          ? saved.areaId == 2 && saved.unit == null
          : saved.areaId == 3 && saved.unit == 'box',
      isTrue,
    );
  });
  test('missing or archived destination rolls back metadata; retained archived area is allowed', () async {
    final before = await seed();
    await areas.archiveArea(2);
    for (final area in [2, 999]) {
      expect(
        (await items.updateMetadata(
          expected: before,
          name: 'Changed',
          areaId: area,
          unit: null,
        )).failureOrNull,
        isA<ForeignConstraintFailure>(),
      );
      expect((await items.getItemById(before.id)).valueOrNull, before);
    }
    await areas.archiveArea(1);
    expect(
      (await items.updateMetadata(
        expected: before,
        name: 'Retained',
        areaId: 1,
        unit: null,
      )).isSuccess,
      isTrue,
    );
  });
  test('missing item fails without recreating a record', () async {
    final before = await seed();
    await items.deleteItem(before.id);
    expect(
      (await items.updateMetadata(
        expected: before,
        name: 'Ghost',
        areaId: 1,
        unit: null,
      )).failureOrNull,
      isA<EntityNotFoundFailure>(),
    );
    expect(
      (await items.getAllItems(includeArchived: true)).valueOrNull,
      isEmpty,
    );
  });
  test('unknown count survives edit, archive and restore', () async {
    final before = await seed();
    final edited = (await items.updateMetadata(
      expected: before,
      name: 'Beans',
      areaId: 2,
      unit: null,
    )).valueOrNull!;
    expect(edited.packageCount, isNull);
    await items.archiveItem(before.id);
    expect((await items.getAllItems()).valueOrNull, isEmpty);
    final restored = (await items.restoreItem(before.id)).valueOrNull!;
    expect(restored.packageCount, isNull);
    expect(restored.areaId, 2);
    expect(restored.id, before.id);
  });
  test('file restart retains edited, corrected, archived/restored and deleted states at schema v1', () async {
    await db.close();
    final directory = await Directory.systemTemp.createTemp('getto_m233_');
    final file = File('${directory.path}/test.sqlite');
    var fileDb = AppDatabase(NativeDatabase(file));
    try {
      var repo = DriftItemRepository(fileDb);
      final first = (await repo.createItem(
        areaId: 1,
        name: 'Coffee',
        behaviorProfile: BehaviorProfile.countableReplenishable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;
      final deleted = (await repo.createItem(
        areaId: 1,
        name: 'Delete me',
        behaviorProfile: BehaviorProfile.durable,
        stockStatus: StockStatus.inStock,
      )).valueOrNull!;
      await repo.updateMetadata(
        expected: first,
        name: 'Beans',
        areaId: 2,
        unit: null,
      );
      await repo.updatePackageCount(itemId: first.id, newPackageCount: 0);
      await repo.archiveItem(first.id);
      await repo.deleteItem(deleted.id);
      await fileDb.close();
      fileDb = AppDatabase(NativeDatabase(file));
      repo = DriftItemRepository(fileDb);
      final saved = (await repo.getItemById(first.id)).valueOrNull!;
      expect(saved.name, 'Beans');
      expect(saved.areaId, 2);
      expect(saved.unit, isNull);
      expect(saved.packageCount, 0);
      expect(saved.stockStatus, StockStatus.outOfStock);
      expect(saved.isArchived, isTrue);
      expect((await repo.getItemById(deleted.id)).isFailure, isTrue);
      expect(fileDb.schemaVersion, 1);
      expect(
        (await fileDb.customSelect('PRAGMA foreign_key_check').get()),
        isEmpty,
      );
      await repo.restoreItem(first.id);
      await fileDb.close();
      fileDb = AppDatabase(NativeDatabase(file));
      repo = DriftItemRepository(fileDb);
      expect((await repo.getAllItems()).valueOrNull!.single.id, first.id);
    } finally {
      await fileDb.close();
      await directory.delete(recursive: true);
    }
  });
}
