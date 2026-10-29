import '../../../core/domain/local_date/local_date.dart';
import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import 'item.dart';
import 'item_lifecycle.dart';
import 'lifecycle_checkpoint.dart';
import 'lifecycle_cycle.dart';

/// Explicit reconciliation includes the exact observations reviewed by the user.
/// Immutable copies prevent input mutation while a command waits for its transaction.
final class CheckpointReconciliation {
  CheckpointReconciliation({
    Map<LifecycleCheckpoint, LocalDate> corrected = const {},
    Set<LifecycleCheckpoint> removed = const {},
  }) : corrected = Map.unmodifiable(corrected),
       removed = Set.unmodifiable(removed);

  final Map<LifecycleCheckpoint, LocalDate> corrected;
  final Set<LifecycleCheckpoint> removed;
}

sealed class ActiveCycleResolution {
  const ActiveCycleResolution(this.expected);
  final LifecycleCycle expected;
}

final class FinishActiveCycle extends ActiveCycleResolution {
  const FinishActiveCycle({
    required LifecycleCycle expected,
    required this.finishedOn,
    this.reconciliation,
  }) : super(expected);

  final LocalDate finishedOn;
  final CheckpointReconciliation? reconciliation;
}

final class RemoveErroneousActiveCycle extends ActiveCycleResolution {
  const RemoveErroneousActiveCycle({required LifecycleCycle expected})
    : super(expected);
}

/// Pure contract for factual lifecycle persistence. Every mutation re-reads and
/// validates inside one transaction; success means the complete write committed.
/// Domain failures and persistence failures remain distinct Result values.
abstract interface class LifecycleRepository {
  /// One item's complete factual aggregate, including completed and checkpoint history.
  Future<Result<ItemLifecycle, Failure>> getLifecycle(int itemId);

  /// Each value is a consistent committed aggregate; missing/deleted items are typed failures.
  Stream<Result<ItemLifecycle, Failure>> watchLifecycle(int itemId);

  /// Stable ID cursor, newest first; limit must be 1..100. No global history scan.
  Future<Result<List<LifecycleCycle>, Failure>> getCompletedCycles(
    int itemId, {
    int limit = 50,
    int? beforeCycleId,
  });

  /// At most one observation of each kind for the selected item-owned cycle.
  Future<Result<List<LifecycleCheckpoint>, Failure>> getCheckpoints({
    required int itemId,
    required int cycleId,
  });

  Future<Result<ItemLifecycle, Failure>> start({
    required int itemId,
    required LocalDate startedOn,
    required LocalDate today,
  });

  /// Optional explicit active resolution and replacement are one atomic command.
  Future<Result<ItemLifecycle, Failure>> restock({
    required int itemId,
    required LocalDate startedOn,
    required LocalDate today,
    int? absolutePackageCount,
    ActiveCycleResolution? resolution,
  });

  Future<Result<ItemLifecycle, Failure>> finish({
    required LifecycleCycle expected,
    required LocalDate finishedOn,
    required LocalDate today,
    CheckpointReconciliation? reconciliation,
  });

  Future<Result<ItemLifecycle, Failure>> correctCycleDates({
    required LifecycleCycle expected,
    required LocalDate startedOn,
    required LocalDate? finishedOn,
    required LocalDate today,
    CheckpointReconciliation? reconciliation,
  });

  Future<Result<ItemLifecycle, Failure>> removeCycle({
    required LifecycleCycle expected,
  });

  Future<Result<ItemLifecycle, Failure>> addCheckpoint({
    required LifecycleCycle expectedCycle,
    required LifecycleCheckpointKind kind,
    required LocalDate observedOn,
    required LocalDate today,
  });

  Future<Result<ItemLifecycle, Failure>> correctCheckpoint({
    required int itemId,
    required LifecycleCheckpoint expected,
    required LocalDate observedOn,
    required LocalDate today,
  });

  /// Compares reviewed availability/count/profile, preserving unrelated metadata.
  Future<Result<ItemLifecycle, Failure>> correctCount({
    required Item expected,
    required int absoluteCurrentTotal,
  });
}
