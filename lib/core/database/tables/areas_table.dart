// ignore_for_file: recursive_getters
import 'package:drift/drift.dart';

/// Drift table definition for household areas.
@DataClassName('AreaData')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_areas_name_active ON areas(LOWER(name)) WHERE is_archived = 0',
)
@TableIndex.sql(
  'CREATE INDEX idx_areas_order ON areas(display_order) WHERE is_archived = 0',
)
class AreasTable extends Table {
  @override
  String get tableName => 'areas';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get iconName => text()
      .withLength(min: 1, max: 50)
      .withDefault(const Constant('general'))();
  IntColumn get displayOrder => integer()
      .withDefault(const Constant(0))
      .check(displayOrder.isBiggerOrEqual(const Constant(0)))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
