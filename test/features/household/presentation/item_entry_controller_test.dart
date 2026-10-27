import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/features/household/data/drift_area_repository.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/stock_status.dart';
import 'package:getto/features/household/presentation/item_entry_controller.dart';

import '../../../support/delayed_item_repository.dart';

void main() {
  late AppDatabase db;
  late DriftAreaRepository areas;
  late DriftItemRepository items;
  late ItemEntryController draft;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    areas = DriftAreaRepository(db);
    items = DriftItemRepository(db);
    draft = ItemEntryController(areas, items);
  });
  tearDown(() async {
    draft.dispose();
    await db.close();
  });

  for (final profile in BehaviorProfile.values) {
    for (final status in StockStatus.values) {
      test(
        'committed minimal creation: ${profile.name}/${status.name}',
        () async {
          final area = (await areas.getAreaById(1)).valueOrNull!;
          draft.change(
            name: '  Test item  ',
            area: area,
            profile: profile,
            presence: status,
          );
          final saved = await draft.save();
          expect(saved, isNotNull);
          expect(saved!.name, 'Test item');
          expect(saved.packageCount, isNull);
          final committed = (await items.getItemById(saved.id)).valueOrNull!;
          expect(committed.behaviorProfile, profile);
          expect(committed.stockStatus, status);
          expect(draft.name, isEmpty);
        },
      );
    }
  }

  test(
    'no silent defaults; invalid identity and partial choices do not write',
    () async {
      expect(draft.profile, isNull);
      expect(draft.presence, isNull);
      expect(draft.area, isNull);
      expect(await draft.save(), isNull);
      draft.change(name: '   ', area: (await areas.getAreaById(1)).valueOrNull);
      expect(await draft.save(), isNull);
      draft.change(name: 'Soap', profile: BehaviorProfile.replenishable);
      expect(await draft.save(), isNull);
      expect((await items.getAllItems()).valueOrNull, isEmpty);
      expect(draft.name, 'Soap');
    },
  );

  test('failed SQLite write preserves choices and independently committed area; Retry succeeds', () async {
    draft.change(
      name: 'Soap',
      profile: BehaviorProfile.replenishable,
      presence: StockStatus.outOfStock,
      step: 1,
    );
    final created = await draft.createArea('Utility');
    await db.customStatement(
      "CREATE TRIGGER reject_item BEFORE INSERT ON items BEGIN SELECT RAISE(FAIL, 'injected'); END",
    );
    expect(await draft.save(), isNull);
    expect(draft.error, contains('new area is already saved'));
    expect(draft.name, 'Soap');
    expect(draft.profile, BehaviorProfile.replenishable);
    expect(draft.presence, StockStatus.outOfStock);
    expect(draft.area, created);
    expect((await areas.getAreaById(created!.id)).isSuccess, isTrue);
    draft.change(step: 0);
    draft.change(step: 1);
    expect(draft.area, created);
    await db.customStatement('DROP TRIGGER reject_item');
    expect(await draft.save(), isNotNull);
    expect((await items.getAllItems()).valueOrNull, hasLength(1));
  });

  test('duplicate area retains original selection and item draft', () async {
    final area = (await areas.getAreaById(1)).valueOrNull!;
    draft.change(name: 'Soap', area: area);
    expect(await draft.createArea(' kitchen '), isNull);
    expect(draft.error, contains('already has this name'));
    expect(draft.area, area);
    expect(draft.name, 'Soap');
  });

  test('archived destination is revalidated before item creation', () async {
    draft.change(
      name: 'Soap',
      area: (await areas.getAreaById(1)).valueOrNull,
      profile: BehaviorProfile.durable,
      presence: StockStatus.inStock,
    );
    await areas.archiveArea(1);
    expect(await draft.save(), isNull);
    expect(draft.step, 0);
    expect(draft.name, 'Soap');
    expect((await items.getAllItems()).valueOrNull, isEmpty);
  });

  test('pending write guards duplicate submission and edits until repository commit', () async {
    final delayed = DelayedItems(db);
    final controller = ItemEntryController(areas, delayed);
    addTearDown(controller.dispose);
    controller.change(
      name: 'Lamp',
      area: (await areas.getAreaById(1)).valueOrNull,
      profile: BehaviorProfile.durable,
      presence: StockStatus.inStock,
    );
    final pending = controller.save();
    await Future<void>.delayed(Duration.zero);
    expect(controller.busy, isTrue);
    expect(await controller.save(), isNull);
    controller.change(name: 'Changed');
    expect(controller.name, 'Lamp');
    expect((await items.getAllItems()).valueOrNull, isEmpty);
    delayed.gate.complete();
    final result = await pending;
    expect(delayed.calls, 1);
    expect((await items.getItemById(result!.id)).isSuccess, isTrue);
    expect(controller.busy, isFalse);
  });
}
