import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/area_repository.dart';
import '../domain/item.dart';
import '../domain/item_repository.dart';

/// Application use case for moving an item between physical household areas.
class MoveItemUseCase {
  const MoveItemUseCase({
    required this.itemRepository,
    required this.areaRepository,
  });

  final ItemRepository itemRepository;
  final AreaRepository areaRepository;

  Future<Result<Item, Failure>> execute({
    required int itemId,
    required int targetAreaId,
  }) async {
    // 1. Verify target area exists and is active
    final targetAreaResult = await areaRepository.getAreaById(targetAreaId);
    if (targetAreaResult.isFailure) {
      return Result.failure(targetAreaResult.failureOrNull!);
    }
    final targetArea = targetAreaResult.valueOrNull!;
    if (targetArea.isArchived) {
      return const Result.failure(
        ValidationError('Cannot move item to an archived area'),
      );
    }

    // 2. Perform atomic move
    return await itemRepository.moveItem(
      itemId: itemId,
      targetAreaId: targetAreaId,
    );
  }
}
