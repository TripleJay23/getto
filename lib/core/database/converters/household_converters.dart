import 'package:drift/drift.dart';

import '../../../features/household/domain/behavior_profile.dart';
import '../../../features/household/domain/stock_status.dart';

/// Drift TypeConverter mapping [BehaviorProfile] to/from SQLite string text.
class BehaviorProfileConverter extends TypeConverter<BehaviorProfile, String> {
  const BehaviorProfileConverter();

  @override
  BehaviorProfile fromSql(String fromDb) =>
      BehaviorProfile.fromWireName(fromDb);

  @override
  String toSql(BehaviorProfile value) => value.wireName;
}

/// Drift TypeConverter mapping [StockStatus] to/from SQLite string text.
class StockStatusConverter extends TypeConverter<StockStatus, String> {
  const StockStatusConverter();

  @override
  StockStatus fromSql(String fromDb) => StockStatus.fromWireName(fromDb);

  @override
  String toSql(StockStatus value) => value.wireName;
}
