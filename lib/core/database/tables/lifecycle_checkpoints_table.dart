// ignore_for_file: recursive_getters
import 'package:drift/drift.dart';

import '../converters/lifecycle_converters.dart';
import 'lifecycle_cycles_table.dart';

@DataClassName('LifecycleCheckpointData')
@TableIndex.sql(
  'CREATE UNIQUE INDEX idx_lifecycle_checkpoints_kind ON lifecycle_checkpoints(cycle_id, kind)',
)
class LifecycleCheckpointsTable extends Table {
  @override
  String get tableName => 'lifecycle_checkpoints';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get cycleId => integer().references(
    LifecycleCyclesTable,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get kind => text()
      .map(const LifecycleCheckpointKindConverter())
      .check(kind.isIn(const ['aboutHalf', 'nearlyFinished']))();
  TextColumn get observedOn => text().map(const LocalDateConverter())();

  @override
  List<String> get customConstraints => [
    "CHECK (length(observed_on) = 10 AND observed_on GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' AND observed_on BETWEEN '1900-01-01' AND '2200-12-31' AND date(observed_on, '+0 days') IS observed_on)",
  ];
}
