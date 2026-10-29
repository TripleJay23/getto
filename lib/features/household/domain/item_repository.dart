import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import 'behavior_profile.dart';
import 'item.dart';
import 'stock_status.dart';

/// Pure Dart contract defining household item repository operations.
abstract interface class ItemRepository {
  /// Retrieves a single item by its primary key [id].
  Future<Result<Item, DataFailure>> getItemById(int id);

  /// Observes a single item by its primary key [id].
  Stream<Item?> watchItemById(int id);

  /// Retrieves all items belonging to the specified [areaId].
  Future<Result<List<Item>, DataFailure>> getItemsByArea(
    int areaId, {
    bool includeArchived = false,
  });

  /// Observes items belonging to the specified [areaId].
  Stream<List<Item>> watchItemsByArea(
    int areaId, {
    bool includeArchived = false,
  });

  /// Retrieves all household items across all areas.
  Future<Result<List<Item>, DataFailure>> getAllItems({
    bool includeArchived = false,
  });

  /// Observes all household items across all areas.
  Stream<List<Item>> watchAllItems({bool includeArchived = false});

  /// Creates a new household item.
  /// Enforces foreign key constraint on [areaId] and factual consistency rules.
  /// Duplicate item names in the same area succeed.
  Future<Result<Item, DataFailure>> createItem({
    required int areaId,
    required String name,
    required BehaviorProfile behaviorProfile,
    required StockStatus stockStatus,
    String? unit,
    int? packageCount,
    String? notes,
    bool requireActiveArea = false,
  });

  /// Updates details of an existing item.
  /// Reconciles and validates factual stock status and package counts.
  Future<Result<Item, DataFailure>> updateItem(Item item);

  /// Atomically edits only name, area and optional package context.
  /// Rejects changed metadata, behavior or archival state relative to [expected].
  /// Concurrent factual stock/count changes are preserved. Null [unit] clears it.
  /// Moving requires an active destination; an unchanged archived area is retained.
  /// [requireActive] rejects archived items atomically for restore-first UI commands.
  /// Its default preserves the general repository's archived-item capabilities.
  Future<Result<Item, DataFailure>> updateMetadata({
    required Item expected,
    required String name,
    required int areaId,
    required String? unit,
    bool requireActive = false,
  });

  /// Moves a single item to a different [targetAreaId].
  Future<Result<Item, DataFailure>> moveItem({
    required int itemId,
    required int targetAreaId,
  });

  /// Moves all items from [sourceAreaId] to [targetAreaId].
  /// Returns the count of relocated items.
  Future<Result<int, DataFailure>> moveItemsToArea({
    required int sourceAreaId,
    required int targetAreaId,
  });

  /// Updates package count and reconciles factual stock status:
  /// - `newPackageCount > 0` strictly mandates [StockStatus.inStock].
  /// - `newPackageCount == 0` strictly mandates [StockStatus.outOfStock].
  /// - Durable items reject package counts.
  /// - Zero while a cycle is active returns [ActiveLifecycleResolutionFailure].
  /// [requireActive] checks archival state inside the write transaction.
  Future<Result<Item, DataFailure>> updatePackageCount({
    required int itemId,
    required int newPackageCount,
    bool requireActive = false,
  });

  /// Updates stock status:
  /// - Out while a cycle is active returns [ActiveLifecycleResolutionFailure].
  /// - For countable items, setting [StockStatus.outOfStock] reconciles package count to 0.
  /// - For countable items, setting [StockStatus.inStock] with 0 or null count reconciles package count to 1.
  /// [requireActive] checks archival state inside the write transaction.
  Future<Result<Item, DataFailure>> updateStockStatus({
    required int itemId,
    required StockStatus newStatus,
    bool requireActive = false,
  });

  /// Soft-archives an item.
  Future<Result<Item, DataFailure>> archiveItem(int id);

  /// Restores an archived item.
  Future<Result<Item, DataFailure>> restoreItem(int id);

  /// Permanently deletes an item from the database.
  Future<Result<void, DataFailure>> deleteItem(int id);
}
