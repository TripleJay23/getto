import 'package:drift/drift.dart';

import '../converters/lifecycle_converters.dart';
import 'items_table.dart';

@DataClassName('LifecycleCycleData')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_lifecycle_cycles_active ON lifecycle_cycles(item_id) WHERE finished_on IS NULL',
)
@TableIndex.sql(
  'CREATE INDEX idx_lifecycle_cycles_history ON lifecycle_cycles(item_id, started_on, id)',
)
class LifecycleCyclesTable extends Table {
  @override
  String get tableName => 'lifecycle_cycles';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId =>
      integer().references(ItemsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get startedOn => text().map(const LocalDateConverter())();
  TextColumn get finishedOn =>
      text().map(const LocalDateConverter()).nullable()();

  @override
  List<String> get customConstraints => [
    // '+0 days' normalizes impossible days (e.g. February 30). IS rejects NULL.
    "CHECK (length(started_on) = 10 AND started_on GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND started_on BETWEEN '1900-01-01' AND '2200-12-31' AND date(started_on, '+0 days') IS started_on)",
    "CHECK (finished_on IS NULL OR (length(finished_on) = 10 AND finished_on GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND finished_on BETWEEN '1900-01-01' AND '2200-12-31' AND date(finished_on, '+0 days') IS finished_on))",
    'CHECK (finished_on IS NULL OR finished_on >= started_on)',
  ];
}
