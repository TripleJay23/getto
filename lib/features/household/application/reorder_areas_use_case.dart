import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/area_repository.dart';
import '../domain/area.dart';

/// Application use case for atomically reordering household areas.
class ReorderAreasUseCase {
  const ReorderAreasUseCase(this._areaRepository);

  final AreaRepository _areaRepository;

  Future<Result<void, Failure>> execute(
    List<int> orderedAreaIds, {
    List<Area>? expectedCatalog,
  }) async {
    if (orderedAreaIds.isEmpty) {
      return const Result.failure(
        ValidationError('Ordered area ID list cannot be empty'),
      );
    }

    final uniqueIds = orderedAreaIds.toSet();
    if (uniqueIds.length != orderedAreaIds.length) {
      return const Result.failure(
        ValidationError('Ordered area ID list must not contain duplicates'),
      );
    }

    return await _areaRepository.reorderAreas(
      orderedAreaIds,
      expectedCatalog: expectedCatalog,
    );
  }
}
