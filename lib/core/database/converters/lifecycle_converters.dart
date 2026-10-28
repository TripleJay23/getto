import 'package:drift/drift.dart';

import '../../domain/local_date/local_date.dart';
import '../../../features/household/domain/lifecycle_checkpoint.dart';

/// Calendar facts remain canonical text; no instant or timezone conversion.
class LocalDateConverter extends TypeConverter<LocalDate, String> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(String fromDb) {
    final date = LocalDate.parse(fromDb);
    if (date.toString() != fromDb) {
      throw const FormatException('Noncanonical lifecycle date.');
    }
    return date;
  }

  @override
  String toSql(LocalDate value) => value.toString();
}

class LifecycleCheckpointKindConverter
    extends TypeConverter<LifecycleCheckpointKind, String> {
  const LifecycleCheckpointKindConverter();

  @override
  LifecycleCheckpointKind fromSql(String fromDb) =>
      LifecycleCheckpointKind.fromWireName(fromDb);

  @override
  String toSql(LifecycleCheckpointKind value) => value.wireName;
}
