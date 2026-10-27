import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import 'area.dart';
import 'item.dart';

/// Consistent, ephemeral consent evidence, never a second persistent store.
class AreaRemovalSnapshot {
  AreaRemovalSnapshot({
    required this.source,
    this.destination,
    required List<Item> items,
  }) : items = List.unmodifiable(items);

  final Area source;
  final Area? destination;
  final List<Item> items;
}

/// Pure Dart contract defining household area repository operations.
abstract interface class AreaRepository {
  /// Retrieves all areas, optionally including archived areas.
  /// Result is ordered by displayOrder ascending.
  Future<Result<List<Area>, DataFailure>> getAreas({
    bool includeArchived = false,
  });

  /// Observes active (or all) areas ordered by displayOrder ascending.
  Stream<List<Area>> watchAreas({bool includeArchived = false});

  /// Retrieves a single area by its primary key [id].
  Future<Result<Area, DataFailure>> getAreaById(int id);

  /// Observes a single area by its primary key [id].
  Stream<Area?> watchAreaById(int id);

  /// Creates a new area.
  /// If [displayOrder] is omitted, assigns the next sequential display order.
  /// Enforces active area name uniqueness (case-insensitive).
  Future<Result<Area, DataFailure>> createArea({
    required String name,
    String iconName = 'general',
    int? displayOrder,
  });

  /// Updates an existing area's details.
  /// Preserves the area's canonical `isSystem` identity.
  Future<Result<Area, DataFailure>> updateArea(Area area);

  /// Changes only the name, comparing the reviewed name and archival state.
  Future<Result<Area, DataFailure>> renameArea({
    required Area expected,
    required String name,
  });

  /// Reads source, optional destination and every item in one transaction.
  Future<Result<AreaRemovalSnapshot, DataFailure>> getRemovalSnapshot(
    int areaId, {
    int? targetAreaId,
  });

  /// Atomically updates display orders for the given ordered area IDs.
  Future<Result<void, DataFailure>> reorderAreas(
    List<int> orderedAreaIds, {
    List<Area>? expectedCatalog,
  });

  /// Soft-archives an area.
  Future<Result<Area, DataFailure>> archiveArea(int id);

  /// Restores an archived area.
  /// Fails with [UniqueConflictFailure] if an active area with the same name already exists.
  Future<Result<Area, DataFailure>> restoreArea(int id);

  /// Permanently deletes an empty area.
  /// Fails with [ForeignConstraintFailure] if the area contains referencing items.
  Future<Result<void, DataFailure>> deleteArea(
    int id, {
    AreaRemovalSnapshot? expected,
  });

  /// Atomically relocates all items from [areaId] to [targetAreaId] and deletes [areaId]
  /// in a single database transaction. If any failure occurs during relocation or deletion,
  /// all modifications are rolled back.
  Future<Result<void, DataFailure>> deleteAreaAndRelocateItems({
    required int areaId,
    required int targetAreaId,
    AreaRemovalSnapshot? expected,
  });

  /// Returns the total count of items (active and archived) residing in the area.
  Future<Result<int, DataFailure>> getItemCountForArea(int id);
}
