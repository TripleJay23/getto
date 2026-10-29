import '../../../core/domain/local_date/local_date.dart';
import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/item_lifecycle.dart';
import '../domain/lifecycle_repository.dart';

/// Supplies a fakeable current calendar date and submits one atomic Restock.
/// Resolution is never committed in a separate application/repository call.
class RestockItemUseCase {
  const RestockItemUseCase(this._repository, {required this.today});

  final LifecycleRepository _repository;
  final LocalDate Function() today;

  Future<Result<ItemLifecycle, Failure>> execute({
    required int itemId,
    required LocalDate startedOn,
    int? absolutePackageCount,
    ActiveCycleResolution? resolution,
  }) => _repository.restock(
    itemId: itemId,
    startedOn: startedOn,
    today: today(),
    absolutePackageCount: absolutePackageCount,
    resolution: resolution,
  );
}
