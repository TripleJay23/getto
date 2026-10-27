import 'package:flutter/foundation.dart';

import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../application/reconcile_item_stock_use_case.dart';
import '../domain/item.dart';
import '../domain/item_repository.dart';
import '../domain/stock_status.dart';

/// Command state and recoverable draft only; committed facts stay in streams.
class ItemManagementController extends ChangeNotifier {
  ItemManagementController(this.items, this.expected)
    : name = expected.name,
      areaId = expected.areaId,
      unit = expected.unit ?? '';

  final ItemRepository items;
  Item expected;
  String name;
  int areaId;
  String unit;
  bool busy = false;
  bool conflict = false;
  String? error;
  bool _disposed = false;

  bool get validMetadata =>
      name.trim().isNotEmpty &&
      name.trim().length <= 100 &&
      unit.trim().length <= 20;

  Future<bool> _run(Future<Result<Object?, Failure>> Function() command) async {
    if (busy) return false;
    busy = true;
    error = null;
    conflict = false;
    notifyListeners();
    try {
      final result = await command();
      if (result.isFailure) {
        final failure = result.failureOrNull;
        conflict = failure is StaleItemFailure;
        error = switch (failure) {
          ItemArchivedFailure() => 'This item is archived. Restore it before editing or correcting availability. Your entry is still here.',
          StaleItemFailure() => 'Saved details changed. Your edits are still here. Review saved details before retrying.',
          EntityNotFoundFailure() =>
            'This item is no longer available. Return to Home.',
          ForeignConstraintFailure() =>
            'This area is unavailable. Choose an active home area.',
          _ => "Couldn't save this change. Your entry is still here. Retry or keep editing.",
        };
        return false;
      }
      return true;
    } catch (_) {
      error = "Couldn't save this change. Your entry is still here. Retry or keep editing.";
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> saveMetadata() async {
    if (busy) return false;
    if (!validMetadata) {
      error = 'Enter a name from 1 to 100 characters and package context up to 20 characters.';
      notifyListeners();
      return false;
    }
    return _run(
      () => items.updateMetadata(
        expected: expected,
        name: name,
        areaId: areaId,
        unit: unit.trim().isEmpty ? null : unit,
        requireActive: true,
      ),
    );
  }

  /// Explicitly acknowledge the displayed committed metadata, retaining the draft.
  void acknowledge(Item latest) {
    if (busy) return;
    expected = latest;
    conflict = false;
    error = 'Latest saved details reviewed. Your draft is retained; save when ready.';
    notifyListeners();
  }

  Future<bool> archive() => _run(() => items.archiveItem(expected.id));
  Future<bool> restore() => _run(() => items.restoreItem(expected.id));
  Future<bool> delete() => _run(() => items.deleteItem(expected.id));
  Future<bool> correctCount(int count) => _run(
    () => ReconcileItemStockUseCase(items).updatePackageCount(
      itemId: expected.id,
      newPackageCount: count,
      requireActive: true,
    ),
  );
  Future<bool> correctPresence(StockStatus status) => _run(
    () => ReconcileItemStockUseCase(items).updateStockStatus(
      itemId: expected.id,
      newStatus: status,
      requireActive: true,
    ),
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
