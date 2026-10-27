import 'dart:async';

import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/features/household/data/drift_item_repository.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/stock_status.dart';

class DelayedItems extends DriftItemRepository {
  DelayedItems(super.db);
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<Result<Item, DataFailure>> createItem({
    required int areaId,
    required String name,
    required BehaviorProfile behaviorProfile,
    required StockStatus stockStatus,
    String? unit,
    int? packageCount,
    String? notes,
    bool requireActiveArea = false,
  }) async {
    calls++;
    await gate.future;
    return super.createItem(
      areaId: areaId,
      name: name,
      behaviorProfile: behaviorProfile,
      stockStatus: stockStatus,
      unit: unit,
      packageCount: packageCount,
      notes: notes,
      requireActiveArea: requireActiveArea,
    );
  }
}
