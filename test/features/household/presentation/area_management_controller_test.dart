import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/features/household/application/remove_area_use_case.dart';
import 'package:getto/features/household/application/reorder_areas_use_case.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/area.dart';
import 'package:getto/features/household/domain/area_repository.dart';
import 'package:getto/features/household/presentation/area_management_controller.dart';
import 'package:getto/features/household/presentation/item_entry_controller.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';

import '../../../support/delayed_item_repository.dart';

class ControlledAreas extends DriftAreaRepository {
  ControlledAreas(super.db);
  Completer<void>? gate;
  bool fail = false;
  int calls = 0;
  Future<void> before() async {
    calls++;
    await gate?.future;
  }

  @override
  Future<Result<Area, DataFailure>> createArea({
    required String name,
    String iconName = 'general',
    int? displayOrder,
  }) async {
    await before();
    if (fail) return const Result.failure(StorageIoFailure('injected'));
    return super.createArea(
      name: name,
      iconName: iconName,
      displayOrder: displayOrder,
    );
  }

  @override
  Future<Result<Area, DataFailure>> renameArea({
    required Area expected,
    required String name,
  }) async {
    await before();
    if (fail) return const Result.failure(StorageIoFailure('injected'));
    return super.renameArea(expected: expected, name: name);
  }

  @override
  Future<Result<void, DataFailure>> deleteArea(
    int id, {
    AreaRemovalSnapshot? expected,
  }) async {
    await before();
    if (fail) return const Result.failure(StorageIoFailure('injected'));
    return super.deleteArea(id, expected: expected);
  }

  @override
  Future<Result<void, DataFailure>> deleteAreaAndRelocateItems({
    required int areaId,
    required int targetAreaId,
    AreaRemovalSnapshot? expected,
  }) async {
    await before();
    if (fail) return const Result.failure(StorageIoFailure('injected'));
    return super.deleteAreaAndRelocateItems(
      areaId: areaId,
      targetAreaId: targetAreaId,
      expected: expected,
    );
  }
}

void main() {
  late AppDatabase db;
  late ControlledAreas areas;
  late DriftItemRepository items;
  late AreaManagementController controller;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    areas = ControlledAreas(db);
    items = DriftItemRepository(db);
    controller = AreaManagementController(
      areas,
      RemoveAreaUseCase(areaRepository: areas, itemRepository: items),
      ReorderAreasUseCase(areas),
    );
    await areas.getAreas();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  test('invalid trimmed name does not write', () async {
    controller.name = '  ';
    expect(await controller.saveName(), isFalse);
    expect(controller.error, contains('1 to 50'));
    expect((await areas.getAreas()).valueOrNull, hasLength(4));
  });

  test('delayed rename guards duplicate commands and retains failed draft for retry', () async {
    final expected = (await areas.getAreaById(1)).valueOrNull!;
    controller.name = 'Cook room';
    areas.gate = Completer<void>();
    areas.fail = true;
    final pending = controller.saveName(expected: expected);
    expect(controller.busy, isTrue);
    expect(await controller.saveName(expected: expected), isFalse);
    expect(await controller.restore(2), isFalse);
    expect(areas.calls, 1);
    areas.gate!.complete();
    expect(await pending, isFalse);
    expect(controller.name, 'Cook room');
    expect(controller.error, contains('Retry'));
    areas.fail = false;
    expect(await controller.saveName(expected: expected), isTrue);
    expect((await areas.getAreaById(1)).valueOrNull!.name, 'Cook room');
  });

  test('stale rename retains draft and reports review requirement', () async {
    final expected = (await areas.getAreaById(1)).valueOrNull!;
    await areas.renameArea(expected: expected, name: 'Saved winner');
    controller.name = 'Retained draft';
    expect(await controller.saveName(expected: expected), isFalse);
    expect(controller.conflict, isTrue);
    expect(controller.name, 'Retained draft');
  });

  test('stale destructive consent is discarded; refresh requires a separate confirm', () async {
    expect(await controller.reviewRemoval(1), isTrue);
    await areas.renameArea(
      expected: (await areas.getAreaById(1)).valueOrNull!,
      name: 'Updated kitchen',
    );
    expect(await controller.confirmRemoval(), isFalse);
    expect(controller.confirmation, isNull);
    expect(await controller.confirmRemoval(), isFalse);
    expect(await controller.reviewRemoval(1), isTrue);
    expect((await areas.getAreaById(1)).isSuccess, isTrue);
    expect(await controller.confirmRemoval(), isTrue);
  });

  test(
    'delayed deletion fails without dismissing context; retry commits once',
    () async {
      await controller.reviewRemoval(1);
      areas.gate = Completer<void>();
      areas.fail = true;
      final pending = controller.confirmRemoval();
      expect(await controller.confirmRemoval(), isFalse);
      expect(await controller.reviewRemoval(2), isFalse);
      areas.gate!.complete();
      expect(await pending, isFalse);
      expect(controller.confirmation!.source.id, 1);
      expect(areas.calls, 1);
      areas.fail = false;
      expect(await controller.confirmRemoval(), isTrue);
      expect(areas.calls, 2);
    },
  );

  test(
    'boundary reorder does not write; active swap preserves catalog',
    () async {
      final catalog = (await areas.getAreas(includeArchived: true))
          .valueOrNull!;
      expect(await controller.move(catalog, 1, -1), isFalse);
      expect(await controller.move(catalog, 4, 1), isFalse);
      expect(await controller.move(catalog, 1, 1), isTrue);
      expect((await areas.getAreas()).valueOrNull!.map((a) => a.id), [
        2,
        1,
        3,
        4,
      ]);
    },
  );

  test('restore conflict stays recoverable with archived rename', () async {
    await controller.archive(1);
    await areas.createArea(name: 'Kitchen');
    expect(await controller.restore(1), isFalse);
    expect(controller.error, contains('rename the archived area'));
    controller.name = 'Old kitchen';
    expect(
      await controller.saveName(
        expected: (await areas.getAreaById(1)).valueOrNull!,
      ),
      isTrue,
    );
    expect(await controller.restore(1), isTrue);
  });

  for (final archived in [true, false]) {
    test(
      'UI creation revalidates ${archived ? 'archived' : 'deleted'} destination after precheck',
      () async {
        final delayed = DelayedItems(db);
        final draft = ItemEntryController(areas, delayed);
        addTearDown(draft.dispose);
        draft.change(
          name: 'Retained item',
          area: (await areas.getAreaById(1)).valueOrNull,
          profile: BehaviorProfile.durable,
          presence: StockStatus.inStock,
        );
        final pending = draft.save();
        for (var i = 0; i < 100 && delayed.calls == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(delayed.calls, 1);
        if (archived) {
          await areas.archiveArea(1);
        } else {
          await areas.deleteArea(1);
        }
        delayed.gate.complete();
        expect(await pending, isNull);
        expect(draft.name, 'Retained item');
        expect(draft.step, 0);
        expect(draft.error, contains('Choose an active'));
        expect((await items.getAllItems()).valueOrNull, isEmpty);
      },
    );
  }
}
