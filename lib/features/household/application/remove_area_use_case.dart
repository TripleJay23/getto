import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/area_repository.dart';
import '../domain/item_repository.dart';

/// Strategies for resolving area removal when items may be present.
enum AreaRemovalMode {
  /// Delete the area only if it is completely empty.
  /// If it contains any items (active or archived), fails with [AreaNotEmptyFailure].
  deleteIfEmpty,

  /// Relocate all items to [targetAreaId] first, then physically delete the area.
  relocateAndDelete,

  /// Soft-archive the area. Preserves all items within the archived area.
  archive,
}

/// Application use case providing safe, explicit resolution for area removal.
/// Enforces relational consistency and safe item resolution across all areas.
class RemoveAreaUseCase {
  const RemoveAreaUseCase({
    required this.areaRepository,
    required this.itemRepository,
  });

  final AreaRepository areaRepository;
  final ItemRepository itemRepository;

  Future<Result<void, Failure>> execute({
    required int areaId,
    AreaRemovalMode mode = AreaRemovalMode.deleteIfEmpty,
    int? targetAreaId,
    AreaRemovalSnapshot? expected,
  }) async {
    // Guarded UI removal is validated inside the same transaction as its writes.
    if (expected != null && mode == AreaRemovalMode.deleteIfEmpty) {
      return areaRepository.deleteArea(areaId, expected: expected);
    }
    if (expected != null && mode == AreaRemovalMode.relocateAndDelete) {
      if (targetAreaId == null || targetAreaId == areaId) {
        return const Result.failure(
          ValidationError('Choose a different active destination.'),
        );
      }
      return areaRepository.deleteAreaAndRelocateItems(
        areaId: areaId,
        targetAreaId: targetAreaId,
        expected: expected,
      );
    }
    // 1. Fetch the target area to verify existence
    final areaResult = await areaRepository.getAreaById(areaId);
    if (areaResult.isFailure) {
      return Result.failure(areaResult.failureOrNull!);
    }

    switch (mode) {
      case AreaRemovalMode.archive:
        final archiveResult = await areaRepository.archiveArea(areaId);
        return archiveResult.map((_) {});

      case AreaRemovalMode.deleteIfEmpty:
        final countResult = await areaRepository.getItemCountForArea(areaId);
        if (countResult.isFailure) {
          return Result.failure(countResult.failureOrNull!);
        }
        final count = countResult.valueOrNull!;
        if (count > 0) {
          return Result.failure(AreaNotEmptyFailure(areaId, count));
        }
        return await areaRepository.deleteArea(areaId);

      case AreaRemovalMode.relocateAndDelete:
        if (targetAreaId == null) {
          return const Result.failure(
            ValidationError(
              'A valid targetAreaId must be provided to relocate items',
            ),
          );
        }
        if (targetAreaId == areaId) {
          return const Result.failure(
            ValidationError(
              'Target area cannot be the same as the area being removed',
            ),
          );
        }

        // Verify target area exists and is active
        final targetAreaResult = await areaRepository.getAreaById(targetAreaId);
        if (targetAreaResult.isFailure) {
          return Result.failure(targetAreaResult.failureOrNull!);
        }
        final targetArea = targetAreaResult.valueOrNull!;
        if (targetArea.isArchived) {
          return const Result.failure(
            ValidationError('Cannot relocate items to an archived area'),
          );
        }

        // Atomically relocate all items and delete source area in one transaction
        return await areaRepository.deleteAreaAndRelocateItems(
          areaId: areaId,
          targetAreaId: targetAreaId,
          expected: expected,
        );
    }
  }
}
