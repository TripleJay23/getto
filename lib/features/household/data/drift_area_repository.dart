import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_exception_mapper.dart';
import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/area.dart';
import '../domain/area_repository.dart';
import 'drift_item_repository.dart';

/// Drift implementation of [AreaRepository] with commit-first transaction semantics.
class DriftAreaRepository implements AreaRepository {
  DriftAreaRepository(this._db);

  final AppDatabase _db;

  Area _mapToDomain(AreaData data) => Area(
    id: data.id,
    name: data.name,
    iconName: data.iconName,
    displayOrder: data.displayOrder,
    isArchived: data.isArchived,
    isSystem: data.isSystem,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
  );

  @override
  Future<Result<List<Area>, DataFailure>> getAreas({
    bool includeArchived = false,
  }) async {
    try {
      final query = _db.select(_db.areasTable)
        ..orderBy([
          (t) => OrderingTerm(expression: t.displayOrder),
          (t) => OrderingTerm(expression: t.id),
        ]);
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
  Stream<List<Area>> watchAreas({bool includeArchived = false}) {
    final query = _db.select(_db.areasTable)
      ..orderBy([
        (t) => OrderingTerm(expression: t.displayOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    return query.watch().map((rows) => rows.map(_mapToDomain).toList());
  }

  @override
  Future<Result<Area, DataFailure>> getAreaById(int id) async {
    try {
      final row = await (_db.select(
        _db.areasTable,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return Result.failure(
          EntityNotFoundFailure('Area with ID $id was not found'),
        );
      }
      return Result.success(_mapToDomain(row));
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Stream<Area?> watchAreaById(int id) {
    return (_db.select(_db.areasTable)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _mapToDomain(row) : null);
  }

  @override
  Future<Result<Area, DataFailure>> createArea({
    required String name,
    String iconName = 'general',
    int? displayOrder,
  }) async {
    try {
      return await _db.transaction(() async {
        int order;
        if (displayOrder != null) {
          order = displayOrder;
        } else {
          final maxOrderQuery = _db.selectOnly(_db.areasTable)
            ..addColumns([_db.areasTable.displayOrder.max()]);
          final maxOrder = await maxOrderQuery
              .map((row) => row.read(_db.areasTable.displayOrder.max()))
              .getSingleOrNull();
          order = (maxOrder ?? -1) + 1;
        }

        final now = DateTime.now().toUtc();
        final companion = AreasTableCompanion.insert(
          name: name.trim(),
          iconName: Value(iconName),
          displayOrder: Value(order),
          isSystem: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        );

        final id = await _db.into(_db.areasTable).insert(companion);
        final created = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(id))).getSingle();
        return Result.success(_mapToDomain(created));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Area, DataFailure>> updateArea(Area area) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(area.id))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Area with ID ${area.id} was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        final companion = AreasTableCompanion(
          name: Value(area.name.trim()),
          iconName: Value(area.iconName),
          displayOrder: Value(area.displayOrder),
          // Canonical system area status is preserved from existing database record
          isSystem: Value(existing.isSystem),
          updatedAt: Value(now),
        );

        await (_db.update(
          _db.areasTable,
        )..where((t) => t.id.equals(area.id))).write(companion);

        final updated = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(area.id))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Area, DataFailure>> renameArea({
    required Area expected,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      return const Result.failure(
        CheckConstraintFailure('Enter an area name from 1 to 50 characters.'),
      );
    }
    try {
      return await _db.transaction(() async {
        final row = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(expected.id))).getSingleOrNull();
        if (row == null) {
          return const Result.failure(
            EntityNotFoundFailure('Area unavailable.'),
          );
        }
        if (row.name != expected.name ||
            row.isArchived != expected.isArchived ||
            row.createdAt != expected.createdAt) {
          return const Result.failure(
            StaleAreaFailure(
              'Area changed. Review the saved name before retrying.',
            ),
          );
        }
        await (_db.update(
          _db.areasTable,
        )..where((t) => t.id.equals(expected.id))).write(
          AreasTableCompanion(
            name: Value(trimmed),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        // A read failure here must escape the transaction and roll back the write.
        final saved = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(expected.id))).getSingle();
        return Result.success(_mapToDomain(saved));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  Future<AreaRemovalSnapshot> _readRemoval(int id, int? destinationId) async {
    final source = await getAreaById(id);
    if (source.isFailure) throw source.failureOrNull!;
    Area? destination;
    if (destinationId != null) {
      final target = await getAreaById(destinationId);
      if (target.isFailure) throw target.failureOrNull!;
      destination = target.valueOrNull!;
    }
    final items = await DriftItemRepository(_db)
        .getItemsByArea(id, includeArchived: true);
    if (items.isFailure) throw items.failureOrNull!;
    return AreaRemovalSnapshot(
      source: source.valueOrNull!,
      destination: destination,
      items: items.valueOrNull!,
    );
  }

  @override
  Future<Result<AreaRemovalSnapshot, DataFailure>> getRemovalSnapshot(
    int areaId, {
    int? targetAreaId,
  }) async {
    try {
      return await _db.transaction(() async {
        final snapshot = await _readRemoval(areaId, targetAreaId);
        if (snapshot.destination != null &&
            (snapshot.destination!.id == areaId ||
                snapshot.destination!.isArchived)) {
          return const Result.failure(
            CheckConstraintFailure('Choose a different active destination.'),
          );
        }
        return Result.success(snapshot);
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  Future<void> _validateRemoval(
    int id,
    int? destinationId,
    AreaRemovalSnapshot? expected,
  ) async {
    if (expected == null) return;
    AreaRemovalSnapshot current;
    try {
      current = await _readRemoval(id, destinationId);
    } on EntityNotFoundFailure {
      throw const StaleAreaFailure(
        'Area or destination is unavailable. Refresh and confirm again.',
      );
    }
    bool sameArea(Area? a, Area? b) => a == null
        ? b == null
        : b != null &&
              a.id == b.id &&
              a.name == b.name &&
              a.isArchived == b.isArchived &&
              a.createdAt == b.createdAt;
    final saved = {for (final item in expected.items) item.id: item.isArchived};
    if (!sameArea(expected.source, current.source) ||
        !sameArea(expected.destination, current.destination) ||
        saved.length != current.items.length ||
        current.items.any((item) => saved[item.id] != item.isArchived)) {
      throw const StaleAreaFailure(
        'Area or contained items changed. Refresh and confirm again.',
      );
    }
  }

  @override
  Future<Result<void, DataFailure>> reorderAreas(
    List<int> orderedAreaIds, {
    List<Area>? expectedCatalog,
  }) async {
    try {
      return await _db.transaction(() async {
        var completeOrder = orderedAreaIds;
        if (expectedCatalog != null) {
          final rows =
              await (_db.select(_db.areasTable)..orderBy([
                    (t) => OrderingTerm(expression: t.displayOrder),
                    (t) => OrderingTerm(expression: t.id),
                  ]))
                  .get();
          final current = rows.map(_mapToDomain).toList();
          final reviewed = expectedCatalog;
          final active = current
              .where((a) => !a.isArchived)
              .map((a) => a.id)
              .toSet();
          if (current.length != reviewed.length ||
              List.generate(current.length, (i) => i).any(
                (i) =>
                    current[i].id != reviewed[i].id ||
                    current[i].isArchived != reviewed[i].isArchived ||
                    current[i].displayOrder != reviewed[i].displayOrder ||
                    current[i].createdAt != reviewed[i].createdAt,
              ) ||
              active.length != orderedAreaIds.length ||
              orderedAreaIds.toSet().length != orderedAreaIds.length ||
              !active.containsAll(orderedAreaIds)) {
            return const Result.failure(
              StaleAreaFailure(
                'Area order changed. Review the refreshed list and try again.',
              ),
            );
          }
          var next = 0;
          completeOrder = [
            for (final area in current)
              if (area.isArchived) area.id else orderedAreaIds[next++],
          ];
        }
        final now = DateTime.now().toUtc();
        for (var i = 0; i < completeOrder.length; i++) {
          final id = completeOrder[i];
          final rows =
              await (_db.update(
                _db.areasTable,
              )..where((t) => t.id.equals(id))).write(
                AreasTableCompanion(
                  displayOrder: Value(i),
                  updatedAt: Value(now),
                ),
              );
          if (rows == 0) {
            throw EntityNotFoundFailure(
              'Area with ID $id was not found during reorder',
            );
          }
        }
        return const Result.success(null);
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Area, DataFailure>> archiveArea(int id) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Area with ID $id was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.areasTable)..where((t) => t.id.equals(id))).write(
          AreasTableCompanion(
            isArchived: const Value(true),
            updatedAt: Value(now),
          ),
        );

        final updated = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(id))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<Area, DataFailure>> restoreArea(int id) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return Result.failure(
            EntityNotFoundFailure('Area with ID $id was not found'),
          );
        }

        final now = DateTime.now().toUtc();
        await (_db.update(_db.areasTable)..where((t) => t.id.equals(id))).write(
          AreasTableCompanion(
            isArchived: const Value(false),
            updatedAt: Value(now),
          ),
        );

        final updated = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(id))).getSingle();
        return Result.success(_mapToDomain(updated));
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<void, DataFailure>> deleteArea(
    int id, {
    AreaRemovalSnapshot? expected,
  }) async {
    try {
      return await _db.transaction(() async {
        await _validateRemoval(id, null, expected);
        final existing = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return const Result.failure(
            EntityNotFoundFailure('Area unavailable.'),
          );
        }

        final rows = await (_db.delete(
          _db.areasTable,
        )..where((t) => t.id.equals(id))).go();
        if (rows == 0) {
          throw const EntityNotFoundFailure('Area unavailable after deletion.');
        }
        return const Result.success(null);
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<void, DataFailure>> deleteAreaAndRelocateItems({
    required int areaId,
    required int targetAreaId,
    AreaRemovalSnapshot? expected,
  }) async {
    try {
      return await _db.transaction(() async {
        await _validateRemoval(areaId, targetAreaId, expected);
        if (areaId == targetAreaId) {
          return const Result.failure(
            CheckConstraintFailure('Choose a different destination area.'),
          );
        }
        final source = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(areaId))).getSingleOrNull();
        if (source == null) {
          return Result.failure(
            EntityNotFoundFailure('Area with ID $areaId was not found'),
          );
        }

        final target = await (_db.select(
          _db.areasTable,
        )..where((t) => t.id.equals(targetAreaId))).getSingleOrNull();
        if (target == null) {
          return Result.failure(
            EntityNotFoundFailure(
              'Target area with ID $targetAreaId was not found',
            ),
          );
        }

        if (target.isArchived) {
          return const Result.failure(
            CheckConstraintFailure('Cannot relocate items to an archived area'),
          );
        }

        final now = DateTime.now().toUtc();
        // 1. Relocate all items from source to target area
        await (_db.update(
          _db.itemsTable,
        )..where((t) => t.areaId.equals(areaId))).write(
          ItemsTableCompanion(
            areaId: Value(targetAreaId),
            updatedAt: Value(now),
          ),
        );

        // 2. Delete source area in the same transaction
        final rows = await (_db.delete(
          _db.areasTable,
        )..where((t) => t.id.equals(areaId))).go();
        if (rows == 0) {
          throw EntityNotFoundFailure(
            'Area with ID $areaId was not found during deletion',
          );
        }

        return const Result.success(null);
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<int, DataFailure>> getItemCountForArea(int id) async {
    try {
      final countExpr = _db.itemsTable.id.count();
      final countQuery = _db.selectOnly(_db.itemsTable)
        ..addColumns([countExpr])
        ..where(_db.itemsTable.areaId.equals(id));
      final count = await countQuery
          .map((row) => row.read(countExpr))
          .getSingle();
      return Result.success(count ?? 0);
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }
}
