import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/local_date/local_date.dart';
import '../../core/domain/result/failure.dart';
import '../../core/domain/result/result.dart';
import '../../features/household/application/restock_item_use_case.dart';
import '../../features/household/data/drift_lifecycle_repository.dart';
import '../../features/household/domain/item_lifecycle.dart';
import '../../features/household/domain/lifecycle_cycle.dart';
import '../../features/household/domain/lifecycle_repository.dart';
import 'database_providers.dart';

final lifecycleClockProvider = Provider<Clock>((ref) => const Clock());
final localTodayProvider = Provider<LocalDate Function()>((ref) {
  final clock = ref.watch(lifecycleClockProvider);
  return () => LocalDate.fromDateTime(clock.now());
});
final lifecycleRepositoryProvider = Provider<LifecycleRepository>(
  (ref) => DriftLifecycleRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(lifecycleClockProvider),
  ),
);
final restockItemUseCaseProvider = Provider<RestockItemUseCase>(
  (ref) => RestockItemUseCase(
    ref.watch(lifecycleRepositoryProvider),
    today: ref.watch(localTodayProvider),
  ),
);
final lifecycleAggregateProvider = StreamProvider.autoDispose
    .family<Result<ItemLifecycle, Failure>, int>(
      (ref, id) => ref.watch(lifecycleRepositoryProvider).watchLifecycle(id),
    );

// Only completed-cycle changes and explicit page changes reload this bounded query.
// Checkpoint/metadata emissions reuse the existing history request.
typedef LifecycleHistoryKey = ({int itemId, String evidenceKey, int? beforeId});
final lifecycleHistoryProvider = FutureProvider.autoDispose
    .family<Result<List<LifecycleCycle>, Failure>, LifecycleHistoryKey>(
      (ref, key) => ref
          .watch(lifecycleRepositoryProvider)
          .getCompletedCycles(
            key.itemId,
            limit: 5,
            beforeCycleId: key.beforeId,
          ),
    );
