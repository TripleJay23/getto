import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/household/application/move_item_use_case.dart';
import '../../features/household/application/reconcile_item_stock_use_case.dart';
import '../../features/household/application/remove_area_use_case.dart';
import '../../features/household/application/reorder_areas_use_case.dart';
import '../../features/household/data/drift_area_repository.dart';
import '../../features/household/data/drift_item_repository.dart';
import '../../features/household/domain/area.dart';
import '../../features/household/domain/area_repository.dart';
import '../../features/household/domain/item.dart';
import '../../features/household/domain/item_repository.dart';
import '../../features/household/presentation/item_entry_controller.dart';
import '../../features/household/presentation/home_search_query.dart';
import '../../features/household/presentation/area_management_controller.dart';
import 'database_providers.dart';

final homeSearchQueryProvider = NotifierProvider<HomeSearchQuery, String>(
  HomeSearchQuery.new,
);

final itemEntryControllerProvider = Provider<ItemEntryController>((ref) {
  final controller = ItemEntryController(
    ref.watch(areaRepositoryProvider),
    ref.watch(itemRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Repository Providers
final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftAreaRepository(db);
});

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftItemRepository(db);
});

/// Application Use Case Providers
final removeAreaUseCaseProvider = Provider<RemoveAreaUseCase>((ref) {
  return RemoveAreaUseCase(
    areaRepository: ref.watch(areaRepositoryProvider),
    itemRepository: ref.watch(itemRepositoryProvider),
  );
});

final reorderAreasUseCaseProvider = Provider<ReorderAreasUseCase>((ref) {
  return ReorderAreasUseCase(ref.watch(areaRepositoryProvider));
});

final reconcileItemStockUseCaseProvider = Provider<ReconcileItemStockUseCase>((
  ref,
) {
  return ReconcileItemStockUseCase(ref.watch(itemRepositoryProvider));
});

final moveItemUseCaseProvider = Provider<MoveItemUseCase>((ref) {
  return MoveItemUseCase(
    itemRepository: ref.watch(itemRepositoryProvider),
    areaRepository: ref.watch(areaRepositoryProvider),
  );
});

/// Reactive Stream Providers (Reflecting committed SQLite state)
final areasStreamProvider = StreamProvider.autoDispose<List<Area>>((ref) {
  final repository = ref.watch(areaRepositoryProvider);
  return repository.watchAreas();
});

final allAreasStreamProvider = StreamProvider.autoDispose<List<Area>>((ref) {
  final repository = ref.watch(areaRepositoryProvider);
  return repository.watchAreas(includeArchived: true);
});

final areaStreamProvider = StreamProvider.autoDispose.family<Area?, int>(
  (ref, id) => ref.watch(areaRepositoryProvider).watchAreaById(id),
);

final areaItemsIncludingArchivedProvider = StreamProvider.autoDispose
    .family<List<Item>, int>(
      (ref, id) => ref
          .watch(itemRepositoryProvider)
          .watchItemsByArea(id, includeArchived: true),
    );

final areaManagementControllerProvider =
    Provider.autoDispose<AreaManagementController>((ref) {
      final controller = AreaManagementController(
        ref.watch(areaRepositoryProvider),
        ref.watch(removeAreaUseCaseProvider),
        ref.watch(reorderAreasUseCaseProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final itemsByAreaStreamProvider = StreamProvider.autoDispose
    .family<List<Item>, int>((ref, areaId) {
      final repository = ref.watch(itemRepositoryProvider);
      return repository.watchItemsByArea(areaId);
    });

final allItemsStreamProvider = StreamProvider.autoDispose<List<Item>>((ref) {
  final repository = ref.watch(itemRepositoryProvider);
  return repository.watchAllItems();
});

final itemStreamProvider = StreamProvider.autoDispose.family<Item?, int>((
  ref,
  id,
) {
  return ref.watch(itemRepositoryProvider).watchItemById(id);
});

final archivedItemsStreamProvider = StreamProvider.autoDispose<List<Item>>((
  ref,
) {
  return ref
      .watch(itemRepositoryProvider)
      .watchAllItems(includeArchived: true)
      .map((items) => items.where((item) => item.isArchived).toList());
});
