import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/item.dart';
import '../domain/item_repository.dart';
import '../domain/stock_status.dart';

/// Application use case enforcing approved factual stock status and package count reconciliation rules (M2-D07).
class ReconcileItemStockUseCase {
  const ReconcileItemStockUseCase(this._itemRepository);

  final ItemRepository _itemRepository;

  /// Reconciles stock status based on explicit package count updates:
  /// - `newPackageCount > 0` => strictly [StockStatus.inStock].
  /// - `newPackageCount == 0` => strictly [StockStatus.outOfStock].
  Future<Result<Item, Failure>> updatePackageCount({
    required int itemId,
    required int newPackageCount,
    bool requireActive = false,
  }) async {
    if (newPackageCount < 0) {
      return const Result.failure(
        ValidationError('Package count cannot be negative'),
      );
    }

    return await _itemRepository.updatePackageCount(
      itemId: itemId,
      newPackageCount: newPackageCount,
      requireActive: requireActive,
    );
  }

  /// Reconciles natural package count based on explicit stock status updates:
  /// - For countable items, setting [StockStatus.outOfStock] reconciles package count to 0.
  /// - For countable items, setting [StockStatus.inStock] reconciles package count to >= 1.
  Future<Result<Item, Failure>> updateStockStatus({
    required int itemId,
    required StockStatus newStatus,
    bool requireActive = false,
  }) async {
    return await _itemRepository.updateStockStatus(
      itemId: itemId,
      newStatus: newStatus,
      requireActive: requireActive,
    );
  }
}
