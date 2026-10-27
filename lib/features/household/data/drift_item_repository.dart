import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_exception_mapper.dart';
import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/behavior_profile.dart';
import '../domain/item.dart';
import '../domain/item_repository.dart';
import '../domain/stock_status.dart';

/// Drift implementation of [ItemRepository] with commit-first transaction semantics.
class DriftItemRepository implements ItemRepository {
  DriftItemRepository(this._db);

  final AppDatabase _db;

  Item _mapToDomain(ItemData data) => Item(
    id: data.id,
    areaId: data.areaId,
    name: data.name,
    behaviorProfile: data.behaviorProfile,
    stockStatus: data.stockStatus,
    unit: data.unit,
    packageCount: data.packageCount,
    isArchived: data.isArchived,
    notes: data.notes,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
  );

  @override
  Future<Result<Item, DataFailure>> getItemById(int id) async {
    try {
      final row = await (_db.select(
        _db.itemsTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return Result.failure(
          EntityNotFoundFailure('Item with ID $id was not found'),
        );
      }
      return Result.success(_mapToDomain(row));
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Stream<Item?> watchItemById(int id) {
    return (_db.select(_db.itemsTable)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapToDomain(row) : null);
  }

  @override
  Future<Result<List<Item>, DataFailure>> getItemsByArea(
    int areaId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _db.select(_db.itemsTable)
        ..where((t) => t.areaId.equals(areaId))
        ..orderBy([(t) => OrderingTerm(expression: t.name)]);
      if (!includeArchived) {
        query.where((t) => t.isArchived.equals(false));
      }
      final rows = await query.get();
      return Result.success(rows.map(_mapToDomain).toList());
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Stream<List<Item>> watchItemsByArea(
    int areaId, {
    bool includeArchived = false,
  }) {
    final query = _db.select(_db.itemsTable)
      ..where((t) => t.areaId.equals(areaId))
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<Result<List<Item>, DataFailure>> getAllItems({
    bool includeArchived = false,
  }) async {
    try {
      final query = _db.select(_db.itemsTable)
        ..orderBy([(t) => OrderingTerm(expression: t.name)]);
      if (!includeArchived) {
        query.where((t) => t.isArchived.equals(false));
      }
      final rows = await query.get();
      return Result.success(rows.map(_mapToDomain).toList());
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Stream<List<Item>> watchAllItems({bool includeArchived = false}) {
    final query = _db.select(_db.itemsTable)
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

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
    try {
      return await _db.transaction(() async {
        if (requireActiveArea) {
          final area = await (_db.select(
            _db.areasTable,
          )..where((t) => t.id.equals(areaId))).getSingleOrNull();
          if (area == null || area.isArchived) {
            return const Result.failure(
              ForeignConstraintFailure('Choose an existing active home area.'),
            );
          }
        }
        final now = DateTime.now().toUtc();
        final companion = ItemsTableCompanion.insert(
          areaId: areaId,
          name: name.trim(),
          behaviorProfile: behaviorProfile,
          stockStatus: stockStatus,
          unit: Value(unit?.trim()),
          packageCount: Value(packageCount),
          notes: Value(notes?.trim()),
          createdAt: Value(now),
          updatedAt: Value(now),
        );

        final id = await _db.into(_db.itemsTable).insert(companion);
        final created = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(id))).getSingle();
        return Result.success(_mapToDomain(created));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Item, DataFailure>> updateItem(Item item) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(item.id))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Item with ID ${item.id} was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        final companion = ItemsTableCompanion(
          areaId: Value(item.areaId),
          name: Value(item.name.trim()),
          behaviorProfile: Value(item.behaviorProfile),
          stockStatus: Value(item.stockStatus),
          unit: Value(item.unit?.trim()),
          packageCount: Value(item.packageCount),
          notes: Value(item.notes?.trim()),
          updatedAt: Value(now),
        );

        await (_db.update(
          _db.itemsTable,
        )..where((t) => t.id.equals(item.id))).write(companion);

        final updated = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(item.id))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Item, DataFailure>> updateMetadata({
    required Item expected,
    required String name,
    required int areaId,
    required String? unit,
    bool requireActive = false,
  }) async {
    final trimmedName = name.trim();
    final trimmedUnit = unit?.trim();
    if (trimmedName.isEmpty ||
        trimmedName.length > 100 ||
        (trimmedUnit != null && trimmedUnit.length > 20)) {
      return const Result.failure(
        CheckConstraintFailure(
          'Name must be 1 to 100 characters; package context at most 20.',
        ),
      );
    }
    try {
      return await _db.transaction(() async {
        final current = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(expected.id))).getSingleOrNull();
        if (current == null) {
          return const Result.failure(
            EntityNotFoundFailure('Item is unavailable'),
          );
        }
        if (requireActive && current.isArchived) {
          return const Result.failure(
            ItemArchivedFailure('Restore the item before editing.'),
          );
        }
        if (current.name != expected.name ||
            current.areaId != expected.areaId ||
            current.unit != expected.unit ||
            current.isArchived != expected.isArchived ||
            current.behaviorProfile != expected.behaviorProfile) {
          return const Result.failure(
            StaleItemFailure(
              'Item details changed. Review the latest saved details before retrying.',
            ),
          );
        }
        final target = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(areaId))).getSingleOrNull();
        if (target == null || (areaId != current.areaId && target.isArchived)) {
          return const Result.failure(
            ForeignConstraintFailure('Choose an existing active home area.'),
          );
        }
        await (_db.update(
          _db.itemsTable,
        )..where((t) => t.id.equals(expected.id))).write(
          ItemsTableCompanion(
            name: Value(trimmedName),
            areaId: Value(areaId),
            unit: Value(
              trimmedUnit == null || trimmedUnit.isEmpty ? null : trimmedUnit,
            ),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        final saved = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(expected.id))).getSingle();
        return Result.success(_mapToDomain(saved));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Item, DataFailure>> moveItem({
    required int itemId,
    required int targetAreaId,
  }) async {
    try {
      return await _db.transaction(() async {
        // Validate target area exists
        final targetArea = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(targetAreaId))).getSingleOrNull();
        if (targetArea == null) {
          return Result.failure(
            EntityNotFoundFailure(
              'Target area with ID $targetAreaId was not found',
            ),
          );
        }

        final existing = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Item with ID $itemId was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).write(
          ItemsTableCompanion(
            areaId: Value(targetAreaId),
            updatedAt: Value(now),
          ),
        );

        final updated = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<int, DataFailure>> moveItemsToArea({
    required int sourceAreaId,
    required int targetAreaId,
  }) async {
    try {
      return await _db.transaction(() async {
        final targetArea = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(targetAreaId))).getSingleOrNull();
        if (targetArea == null) {
          return Result.failure(
            EntityNotFoundFailure(
              'Target area with ID $targetAreaId was not found',
            ),
          );
        }

        final now = DateTime.now().toUtc();
        final rowsAffected =
            await (_db.update(
              _db.itemsTable,
            )..where((t) => t.areaId.equals(sourceAreaId))).write(
              ItemsTableCompanion(
                areaId: Value(targetAreaId),
                updatedAt: Value(now),
              ),
            );

        return Result.success(rowsAffected);
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Item, DataFailure>> updatePackageCount({
    required int itemId,
    required int newPackageCount,
    bool requireActive = false,
  }) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Item with ID $itemId was not found'),
          );
        }

        if (requireActive && existing.isArchived) {
          return const Result.failure(
            ItemArchivedFailure(
              'Restore the item before correcting availability.',
            ),
          );
        }
        if (existing.behaviorProfile == BehaviorProfile.durable) {
          return const Result.failure(
            CheckConstraintFailure('Durable items do not track package counts'),
          );
        }

        if (newPackageCount < 0) {
          return const Result.failure(
            CheckConstraintFailure('Package count cannot be negative'),
          );
        }

        // Reconcile factual stock status per M2-D07
        final reconciledStatus = newPackageCount > 0
            ? StockStatus.inStock
            : StockStatus.outOfStock;

        final now = DateTime.now().toUtc();
        await (_db.update(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).write(
          ItemsTableCompanion(
            packageCount: Value(newPackageCount),
            stockStatus: Value(reconciledStatus),
            updatedAt: Value(now),
          ),
        );

        final updated = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Item, DataFailure>> updateStockStatus({
    required int itemId,
    required StockStatus newStatus,
    bool requireActive = false,
  }) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Item with ID $itemId was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        if (requireActive && existing.isArchived) {
          return const Result.failure(
            ItemArchivedFailure(
              'Restore the item before correcting availability.',
            ),
          );
        }
        int? reconciledCount = existing.packageCount;

        if (existing.behaviorProfile ==
            BehaviorProfile.countableReplenishable) {
          if (newStatus == StockStatus.outOfStock) {
            reconciledCount = 0;
          } else if (newStatus == StockStatus.inStock) {
            // If previously zero or null, set to 1
            if (reconciledCount == null || reconciledCount == 0) {
              reconciledCount = 1;
            }
          }
        }

        await (_db.update(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).write(
          ItemsTableCompanion(
            stockStatus: Value(newStatus),
            packageCount: Value(reconciledCount),
            updatedAt: Value(now),
          ),
        );

        final updated = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(itemId))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Item, DataFailure>> archiveItem(int id) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Item with ID $id was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.itemsTable)..where((t) => t.id.equals(id))).write(
          ItemsTableCompanion(
            isArchived: const Value(true),
            updatedAt: Value(now),
          ),
        );

        final updated = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(id))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Item, DataFailure>> restoreItem(int id) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Item with ID $id was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.itemsTable)..where((t) => t.id.equals(id))).write(
          ItemsTableCompanion(
            isArchived: const Value(false),
            updatedAt: Value(now),
          ),
        );

        final updated = await (_db.select(
          _db.itemsTable,
        )..where((t) => t.id.equals(id))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<void, DataFailure>> deleteItem(int id) async {
    try {
      return await _db.transaction(() async {
        final rows = await (_db.delete(
          _db.itemsTable,
        )..where((t) => t.id.equals(id))).go();
        if (rows == 0) {
          return Result.failure(
            EntityNotFoundFailure('Item with ID $id was not found'),
          );
        }
        return const Result.success(null);
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }
}
