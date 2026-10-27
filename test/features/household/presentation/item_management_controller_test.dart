import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:getto/features/household/presentation/item_management_controller.dart';

class ControlledManagementItems extends DriftItemRepository {
  ControlledManagementItems(super.db);
  Completer<void>? gate;
  bool fail = false;
  bool throwFailure = false;
  int calls = 0;
  Future<bool> delay() async {
    calls++;
    await gate?.future;
    if (throwFailure) throw StateError('injected');
    return fail;
  }

  @override
  Future<Result<Item, DataFailure>> updateMetadata({
    required Item expected,
    required String name,
    required int areaId,
    required String? unit,
    bool requireActive = false,
  }) async {
    if (await delay()) {
      return const Result.failure(StorageIoFailure('injected'));
    }
    return super.updateMetadata(
      expected: expected,
      name: name,
      areaId: areaId,
      unit: unit,
      requireActive: requireActive,
    );
  }

  @override
  Future<Result<Item, DataFailure>> archiveItem(int id) async {
    if (await delay()) {
      return const Result.failure(StorageIoFailure('injected'));
    }
    return super.archiveItem(id);
  }

  @override
  Future<Result<Item, DataFailure>> restoreItem(int id) async {
    if (await delay()) {
      return const Result.failure(StorageIoFailure('injected'));
    }
    return super.restoreItem(id);
  }

  @override
  Future<Result<void, DataFailure>> deleteItem(int id) async {
    if (await delay()) {
      return const Result.failure(StorageIoFailure('injected'));
    }
    return super.deleteItem(id);
  }

  @override
  Future<Result<Item, DataFailure>> updatePackageCount({
    required int itemId,
    required int newPackageCount,
    bool requireActive = false,
  }) async {
    if (await delay()) {
      return const Result.failure(StorageIoFailure('injected'));
    }
    return super.updatePackageCount(
      itemId: itemId,
      newPackageCount: newPackageCount,
      requireActive: requireActive,
    );
  }

  @override
  Future<Result<Item, DataFailure>> updateStockStatus({
    required int itemId,
    required StockStatus newStatus,
    bool requireActive = false,
  }) async {
    if (await delay()) {
      return const Result.failure(StorageIoFailure('injected'));
    }
    return super.updateStockStatus(
      itemId: itemId,
      newStatus: newStatus,
      requireActive: requireActive,
    );
  }
}

void main() {
  late AppDatabase db;
  late ControlledManagementItems items;
  late ItemManagementController controller;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    items = ControlledManagementItems(db);
    final item = (await items.createItem(
      areaId: 1,
      name: 'Coffee',
      behaviorProfile: BehaviorProfile.countableReplenishable,
      stockStatus: StockStatus.inStock,
    )).valueOrNull!;
    controller = ItemManagementController(items, item);
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
  });
  for (final operation in ['metadata', 'count', 'presence']) {
    test(
      'external archival while $operation waits rejects write, keeps draft and allows retry after restore',
      () async {
        controller.name = 'Retained draft';
        controller.unit = 'bags';
        Future<bool> command() => switch (operation) {
          'metadata' => controller.saveMetadata(),
          'count' => controller.correctCount(0),
          _ => controller.correctPresence(StockStatus.outOfStock),
        };
        items.gate = Completer<void>();
        final pending = command();
        final archived = (await DriftItemRepository(
          db,
        ).archiveItem(controller.expected.id)).valueOrNull!;
        items.gate!.complete();
        expect(await pending, isFalse);
        expect(controller.error, contains('Restore'));
        expect(controller.name, 'Retained draft');
        expect(controller.unit, 'bags');
        expect((await items.getItemById(archived.id)).valueOrNull, archived);
        await items.restoreItem(archived.id);
        expect(await command(), isTrue);
      },
    );
  }
  for (final operation in [
    'edit',
    'archive',
    'restore',
    'delete',
    'count',
    'presence',
  ]) {
    Future<bool> run() => switch (operation) {
      'edit' => controller.saveMetadata(),
      'archive' => controller.archive(),
      'restore' => controller.restore(),
      'delete' => controller.delete(),
      'count' => controller.correctCount(0),
      _ => controller.correctPresence(StockStatus.outOfStock),
    };
    test(
      '$operation is single-flight and acknowledges only committed success',
      () async {
        items.gate = Completer<void>();
        final first = run();
        expect(controller.busy, isTrue);
        expect(await run(), isFalse);
        expect(items.calls, 1);
        expect(
          (await items.getItemById(controller.expected.id)).isSuccess,
          isTrue,
        );
        items.gate!.complete();
        expect(await first, isTrue);
        expect(controller.busy, isFalse);
      },
    );
    test(
      '$operation storage failure preserves record and draft; retry succeeds',
      () async {
        controller.name = 'My edited name';
        controller.areaId = 2;
        controller.unit = '1 L';
        items.fail = true;
        expect(await run(), isFalse);
        expect(controller.error, contains('Retry'));
        expect(controller.name, 'My edited name');
        expect(controller.areaId, 2);
        expect(controller.unit, '1 L');
        expect(
          (await items.getItemById(controller.expected.id)).valueOrNull,
          controller.expected,
        );
        items.fail = false;
        expect(await run(), isTrue);
      },
    );
  }
  test('invalid metadata does not send commands', () async {
    controller.name = '   ';
    expect(await controller.saveMetadata(), isFalse);
    controller.name = 'Coffee';
    controller.unit = 'x' * 21;
    expect(await controller.saveMetadata(), isFalse);
    expect(items.calls, 0);
  });
  test('conflict requires explicit acknowledgment and retains draft', () async {
    final saved = (await items.updateMetadata(
      expected: controller.expected,
      name: 'Newer',
      areaId: 3,
      unit: null,
    )).valueOrNull!;
    controller.name = 'My draft';
    expect(await controller.saveMetadata(), isFalse);
    expect(controller.conflict, isTrue);
    controller.acknowledge(saved);
    expect(controller.name, 'My draft');
    expect(await controller.saveMetadata(), isTrue);
  });
  test('unexpected failure releases busy state and permits retry', () async {
    items.throwFailure = true;
    expect(await controller.saveMetadata(), isFalse);
    expect(controller.busy, isFalse);
    items.throwFailure = false;
    expect(await controller.saveMetadata(), isTrue);
  });
}
