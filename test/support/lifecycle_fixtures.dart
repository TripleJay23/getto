import 'package:flutter_test/flutter_test.dart';
import 'package:getto/core/domain/local_date/local_date.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/lifecycle_cycle.dart';
import 'package:getto/features/household/domain/stock_status.dart';

LocalDate day(int value) => LocalDate(2026, 10, value);
final today = day(28);

Item householdItem({
  int id = 1,
  BehaviorProfile profile = BehaviorProfile.replenishable,
  int? count,
  bool archived = false,
  StockStatus? status,
}) => Item(
  id: id,
  areaId: 2,
  name: 'Household item',
  behaviorProfile: profile,
  stockStatus:
      status ?? (count == 0 ? StockStatus.outOfStock : StockStatus.inStock),
  packageCount: count,
  unit: 'package',
  notes: 'Retained context',
  isArchived: archived,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

LifecycleCycle cycle({
  int id = 10,
  int itemId = 1,
  int start = 10,
  int? finish,
}) => LifecycleCycle(
  id: id,
  itemId: itemId,
  startedOn: day(start),
  finishedOn: finish == null ? null : day(finish),
);

LifecycleCheckpoint checkpoint({
  int id = 100,
  int cycleId = 10,
  int observed = 15,
  LifecycleCheckpointKind kind = LifecycleCheckpointKind.aboutHalf,
}) => LifecycleCheckpoint(
  id: id,
  cycleId: cycleId,
  kind: kind,
  observedOn: day(observed),
);

ItemLifecycle success(Result<ItemLifecycle, LifecycleFailure> result) {
  expect(result.isSuccess, isTrue, reason: '${result.failureOrNull}');
  return result.valueOrNull!;
}

void failure<T extends LifecycleFailure>(
  Result<ItemLifecycle, LifecycleFailure> result,
) {
  expect(result.isFailure, isTrue);
  expect(result.failureOrNull, isA<T>());
  expect(result.valueOrNull, isNull);
}
