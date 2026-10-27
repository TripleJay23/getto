// ignore_for_file: recursive_getters
import 'package:drift/drift.dart';

import '../converters/household_converters.dart';
import 'areas_table.dart';

/// Drift table definition for household items.
@DataClassName('ItemData')
@TableIndex.sql('CREATE INDEX idx_items_area ON items(area_id, is_archived)')
@TableIndex.sql(
  'CREATE INDEX idx_items_status ON items(stock_status, is_archived)',
)
class ItemsTable extends Table {
  @override
  String get tableName => 'items';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get areaId => integer().references(
    AreasTable,
    #id,
    onDelete: KeyAction.restrict,
    onUpdate: KeyAction.cascade,
  )();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get behaviorProfile => text()
      .map(const BehaviorProfileConverter())
      .check(
        behaviorProfile.isIn(const [
          'replenishable',
          'countableReplenishable',
          'durable',
        ]),
      )();
  TextColumn get stockStatus => text()
      .map(const StockStatusConverter())
      .check(stockStatus.isIn(const ['inStock', 'outOfStock']))();
  TextColumn get unit => text().nullable().withLength(min: 1, max: 20)();
  IntColumn get packageCount => integer().nullable().check(
    packageCount.isNull() | packageCount.isBiggerOrEqual(const Constant(0)),
  )();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'CHECK (package_count IS NULL OR (package_count > 0 AND stock_status = \'inStock\') OR (package_count = 0 AND stock_status = \'outOfStock\'))',
    'CHECK (behavior_profile != \'durable\' OR package_count IS NULL)',
  ];
}
