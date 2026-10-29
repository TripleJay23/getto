import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/database/app_database.dart';
import 'package:getto/core/domain/local_date/local_date.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/data/drift_lifecycle_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/stock_status.dart';

LocalDate date(int day) => LocalDate(2026, 10, day);
final currentDate = date(29);
final commitInstant = DateTime.utc(2026, 10, 29, 12, 34, 56);

T saved<T>(Result<T, Failure> result) {
  expect(result.isSuccess, isTrue, reason: '${result.failureOrNull}');
  return result.valueOrNull as T;
}

class LifecycleFixture {
  LifecycleFixture([AppDatabase? database])
    : db = database ?? AppDatabase(NativeDatabase.memory()) {
    items = DriftItemRepository(db);
    lifecycle = DriftLifecycleRepository(db, clock: Clock.fixed(commitInstant));
  }
  final AppDatabase db;
  late final DriftItemRepository items;
  late final DriftLifecycleRepository lifecycle;

  Future<Item> item({
    BehaviorProfile profile = BehaviorProfile.replenishable,
    int? count,
    String name = 'Synthetic lifecycle item',
  }) async {
    final created = saved(
      await items.createItem(
        areaId: 1,
        name: name,
        behaviorProfile: profile,
        stockStatus: count == 0 ? StockStatus.outOfStock : StockStatus.inStock,
        packageCount: count,
        unit: 'fixture package',
        notes: 'Synthetic retained note',
      ),
    );
    await (db.update(
      db.itemsTable,
    )..where((t) => t.id.equals(created.id))).write(
      ItemsTableCompanion(
        createdAt: Value(DateTime.utc(2026, 1, 1)),
        updatedAt: Value(DateTime.utc(2026, 10, 1)),
      ),
    );
    return saved(await items.getItemById(created.id));
  }

  Future<ItemLifecycle> snapshot(int itemId) async =>
      saved(await lifecycle.getLifecycle(itemId));
  Future<ItemLifecycle> start(Item item, {int day = 10}) async => saved(
    await lifecycle.start(
      itemId: item.id,
      startedOn: date(day),
      today: currentDate,
    ),
  );
}

Future<Map<String, List<Map<String, Object?>>>> databaseFacts(
  AppDatabase db,
) async => {
  for (final table in [
    'items',
    'lifecycle_cycles',
    'lifecycle_checkpoints',
    'sqlite_sequence',
  ])
    table: [
      for (final row
          in await db.customSelect('SELECT * FROM $table ORDER BY 1').get())
        Map<String, Object?>.from(row.data),
    ],
};
