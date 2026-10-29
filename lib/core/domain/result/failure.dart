/// Base sealed class for all typed failures across the application.
sealed class Failure {
  const Failure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';
}

/// Failures originating in the Domain layer due to business rule or invariant violations.
sealed class DomainFailure extends Failure {
  const DomainFailure(super.message, [super.cause]);
}

class ValidationError extends DomainFailure {
  const ValidationError(super.message, [super.cause]);
}

class InvariantViolation extends DomainFailure {
  const InvariantViolation(super.message, [super.cause]);
}

class AreaNotEmptyFailure extends DomainFailure {
  const AreaNotEmptyFailure(
    this.areaId,
    this.itemCount, [
    super.message =
        'Area contains items and cannot be deleted without relocation',
    super.cause,
  ]);

  final int areaId;
  final int itemCount;
}

/// Failures originating in the Persistence/Data layer.
sealed class DataFailure extends Failure {
  const DataFailure(super.message, [super.cause]);
}

class StorageIoFailure extends DataFailure {
  const StorageIoFailure(super.message, [super.cause]);
}

class DatabaseLockedFailure extends DataFailure {
  const DatabaseLockedFailure(super.message, [super.cause]);
}

class UniqueConflictFailure extends DataFailure {
  const UniqueConflictFailure(super.message, [super.cause]);
}

class ForeignConstraintFailure extends DataFailure {
  const ForeignConstraintFailure(super.message, [super.cause]);
}

class CheckConstraintFailure extends DataFailure {
  const CheckConstraintFailure(super.message, [super.cause]);
}

class DatabaseDiagnosticInfo {
  const DatabaseDiagnosticInfo({
    required this.resultCode,
    this.extendedResultCode,
  });

  final int resultCode;
  final int? extendedResultCode;

  @override
  String toString() =>
      'SQLite[code: $resultCode${extendedResultCode != null ? ', extended: $extendedResultCode' : ''}]';
}

class EntityNotFoundFailure extends DataFailure {
  const EntityNotFoundFailure(super.message, [super.cause]);
}

class StaleItemFailure extends DataFailure {
  const StaleItemFailure(super.message);
}

/// Saved area state changed since the user reviewed it. No write was applied.
class StaleAreaFailure extends DataFailure {
  const StaleAreaFailure(super.message);
}

/// An opt-in active-item command found an archived record at transaction time.
class ItemArchivedFailure extends DataFailure {
  const ItemArchivedFailure(super.message);
}

class DatabaseCorruptionFailure extends DataFailure {
  const DatabaseCorruptionFailure(super.message, [super.cause]);
}

class UnexpectedDataFailure extends DataFailure {
  const UnexpectedDataFailure(super.message, [super.cause]);
}

/// Pure lifecycle transition failures; no persistence or UI dependencies.
sealed class LifecycleFailure extends DomainFailure {
  const LifecycleFailure(super.message);
}

class InvalidLifecycleDateFailure extends LifecycleFailure {
  const InvalidLifecycleDateFailure(super.message);
}

class LifecycleProfileFailure extends LifecycleFailure {
  const LifecycleProfileFailure(super.message);
}

class LifecycleCountFailure extends LifecycleFailure {
  const LifecycleCountFailure(super.message);
}

class LifecycleTargetFailure extends LifecycleFailure {
  const LifecycleTargetFailure(super.message);
}

class LifecycleConflictFailure extends LifecycleFailure {
  const LifecycleConflictFailure(super.message, {this.cycleId});
  final int? cycleId;
}

class LifecycleCheckpointReconciliationFailure extends LifecycleFailure {
  LifecycleCheckpointReconciliationFailure(Iterable<int> checkpointIds)
    : checkpointIds = List.unmodifiable(checkpointIds),
      super('Explicitly reconcile observations outside the corrected cycle.');

  final List<int> checkpointIds;
}

/// Existing item-stock API requires an explicit lifecycle resolution before Out.
/// This DataFailure preserves the established M2 repository return contract.
class ActiveLifecycleResolutionFailure extends DataFailure {
  const ActiveLifecycleResolutionFailure(this.cycleId)
    : super(
        'Resolve the active cycle with Finish or erroneous-cycle removal before recording zero stock.',
      );
  final int cycleId;
}
