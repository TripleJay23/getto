import 'dart:async';

import 'package:getto/core/domain/local_date/local_date.dart';
import 'package:getto/core/domain/result/failure.dart';
import 'package:getto/core/domain/result/result.dart';
import 'package:getto/features/household/domain/behavior_profile.dart';
import 'package:getto/features/household/domain/item.dart';
import 'package:getto/features/household/domain/item_lifecycle.dart';
import 'package:getto/features/household/domain/lifecycle_checkpoint.dart';
import 'package:getto/features/household/domain/lifecycle_cycle.dart';
import 'package:getto/features/household/domain/lifecycle_repository.dart';
import 'package:getto/features/household/domain/stock_status.dart';

final testToday = LocalDate(2026, 10, 29);
LocalDate day(int day) => LocalDate(2026, 10, day);

ItemLifecycle lifecycleFixture({
  bool active = true,
  bool archived = false,
  BehaviorProfile profile = BehaviorProfile.countableReplenishable,
  int? count,
  bool history = false,
  bool notes = false,
}) => ItemLifecycle(
  item: Item(
    id: 1,
    areaId: 1,
    name: 'Coffee',
    behaviorProfile: profile,
    stockStatus: count == 0 ? StockStatus.outOfStock : StockStatus.inStock,
    packageCount: count,
    isArchived: archived,
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  ),
  cycles: [
    if (history)
      LifecycleCycle(id: 1, itemId: 1, startedOn: day(1), finishedOn: day(2)),
    if (active && profile != BehaviorProfile.durable)
      LifecycleCycle(id: 10, itemId: 1, startedOn: day(20)),
  ],
  checkpoints: [
    if (notes && active)
      LifecycleCheckpoint(
        id: 10,
        cycleId: 10,
        kind: LifecycleCheckpointKind.aboutHalf,
        observedOn: day(25),
      ),
    if (notes && history)
      LifecycleCheckpoint(
        id: 1,
        cycleId: 1,
        kind: LifecycleCheckpointKind.nearlyFinished,
        observedOn: day(2),
      ),
  ],
);

/// Isolated UI-state fake. Domain transitions validate facts; a gate controls
/// publication so tests can distinguish a pending write from a committed result.
class FakeLifecycleRepository implements LifecycleRepository {
  FakeLifecycleRepository(this.saved);
  ItemLifecycle saved;
  final changes = StreamController<Result<ItemLifecycle, Failure>>.broadcast(
    sync: true,
  );
  Completer<void>? gate;
  Failure? writeFailure, readFailure, historyFailure;
  bool throwWrite = false, emitInitial = true;
  final calls = <String>[];
  int reads = 0, watches = 0, historyReads = 0, checkpointReads = 0;
  int nextId = 100;
  ActiveCycleResolution? lastResolution;
  int? lastTotal;
  int? lastBefore;
  int? lastLimit;

  void publish(ItemLifecycle value) {
    saved = value;
    changes.add(Result.success(value));
  }

  void publishFailure(Failure failure) => changes.add(Result.failure(failure));
  Future<void> close() => changes.close();
  Future<Result<ItemLifecycle, Failure>> write(
    String name,
    Result<ItemLifecycle, Failure> Function() transition,
  ) async {
    calls.add(name);
    await gate?.future;
    if (throwWrite) throw StateError('injected write failure');
    if (writeFailure != null) return Result.failure(writeFailure!);
    if (readFailure != null) return Result.failure(readFailure!);
    final result = transition();
    if (result.isSuccess) publish(result.valueOrNull!);
    return result;
  }

  @override
  Future<Result<ItemLifecycle, Failure>> getLifecycle(int itemId) async {
    reads++;
    return readFailure == null
        ? Result.success(saved)
        : Result.failure(readFailure!);
  }

  @override
  Stream<Result<ItemLifecycle, Failure>> watchLifecycle(int itemId) async* {
    watches++;
    if (emitInitial) {
      yield readFailure == null
          ? Result.success(saved)
          : Result.failure(readFailure!);
    }
    yield* changes.stream;
  }

  @override
  Future<Result<List<LifecycleCycle>, Failure>> getCompletedCycles(
    int itemId, {
    int limit = 50,
    int? beforeCycleId,
  }) async {
    historyReads++;
    lastBefore = beforeCycleId;
    lastLimit = limit;
    if (historyFailure != null) return Result.failure(historyFailure!);
    final values =
        saved.completedCycles
            .where((c) => beforeCycleId == null || c.id < beforeCycleId)
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
    return Result.success(values.take(limit).toList());
  }

  @override
  Future<Result<List<LifecycleCheckpoint>, Failure>> getCheckpoints({
    required int itemId,
    required int cycleId,
  }) async {
    checkpointReads++;
    return Result.success(
      saved.checkpoints.where((p) => p.cycleId == cycleId).toList(),
    );
  }

  Map<int, LocalDate> dates(CheckpointReconciliation? r) => {
    for (final e
        in r?.corrected.entries ?? <MapEntry<LifecycleCheckpoint, LocalDate>>[])
      e.key.id: e.value,
  };
  Set<int> removed(CheckpointReconciliation? r) => {
    for (final p in r?.removed ?? <LifecycleCheckpoint>{}) p.id,
  };
  @override
  Future<Result<ItemLifecycle, Failure>> start({
    required int itemId,
    required LocalDate startedOn,
    required LocalDate today,
  }) => write(
    'start',
    () => saved.start(cycleId: nextId++, startedOn: startedOn, today: today),
  );
  @override
  Future<Result<ItemLifecycle, Failure>> restock({
    required int itemId,
    required LocalDate startedOn,
    required LocalDate today,
    int? absolutePackageCount,
    ActiveCycleResolution? resolution,
  }) {
    lastResolution = resolution;
    lastTotal = absolutePackageCount;
    return write('restock', () {
      var current = saved;
      if (resolution != null) {
        final Result<ItemLifecycle, Failure> resolved = switch (resolution) {
          FinishActiveCycle(
            :final expected,
            :final finishedOn,
            :final reconciliation,
          ) =>
            current.finish(
              expected: expected,
              finishedOn: finishedOn,
              today: today,
              checkpointDates: dates(reconciliation),
              removedCheckpointIds: removed(reconciliation),
            ),
          RemoveErroneousActiveCycle(:final expected) => current.removeCycle(
            expected: expected,
          ),
        };
        if (resolved.isFailure) return resolved;
        current = resolved.valueOrNull!;
      }
      return current.restock(
        cycleId: nextId++,
        startedOn: startedOn,
        today: today,
        absolutePackageCount: absolutePackageCount,
      );
    });
  }

  @override
  Future<Result<ItemLifecycle, Failure>> finish({
    required LifecycleCycle expected,
    required LocalDate finishedOn,
    required LocalDate today,
    CheckpointReconciliation? reconciliation,
  }) => write(
    'finish',
    () => saved.finish(
      expected: expected,
      finishedOn: finishedOn,
      today: today,
      checkpointDates: dates(reconciliation),
      removedCheckpointIds: removed(reconciliation),
    ),
  );
  @override
  Future<Result<ItemLifecycle, Failure>> correctCycleDates({
    required LifecycleCycle expected,
    required LocalDate startedOn,
    required LocalDate? finishedOn,
    required LocalDate today,
    CheckpointReconciliation? reconciliation,
  }) => write(
    'dates',
    () => saved.correctCycleDates(
      expected: expected,
      startedOn: startedOn,
      finishedOn: finishedOn,
      today: today,
      checkpointDates: dates(reconciliation),
      removedCheckpointIds: removed(reconciliation),
    ),
  );
  @override
  Future<Result<ItemLifecycle, Failure>> removeCycle({
    required LifecycleCycle expected,
  }) => write('remove', () => saved.removeCycle(expected: expected));
  @override
  Future<Result<ItemLifecycle, Failure>> addCheckpoint({
    required LifecycleCycle expectedCycle,
    required LifecycleCheckpointKind kind,
    required LocalDate observedOn,
    required LocalDate today,
  }) => write(
    'checkpoint',
    () => saved.addCheckpoint(
      expectedCycle: expectedCycle,
      checkpoint: LifecycleCheckpoint(
        id: nextId++,
        cycleId: expectedCycle.id,
        kind: kind,
        observedOn: observedOn,
      ),
      today: today,
    ),
  );
  @override
  Future<Result<ItemLifecycle, Failure>> correctCheckpoint({
    required int itemId,
    required LifecycleCheckpoint expected,
    required LocalDate observedOn,
    required LocalDate today,
  }) => write(
    'checkpoint-date',
    () => saved.correctCheckpoint(
      expected: expected,
      observedOn: observedOn,
      today: today,
    ),
  );
  @override
  Future<Result<ItemLifecycle, Failure>> correctCount({
    required Item expected,
    required int absoluteCurrentTotal,
  }) => write('count', () {
    if (expected.stockStatus != saved.item.stockStatus ||
        expected.packageCount != saved.item.packageCount ||
        expected.behaviorProfile != saved.item.behaviorProfile) {
      return const Result.failure(StaleItemFailure('Changed count'));
    }
    return saved.correctCount(absoluteCurrentTotal: absoluteCurrentTotal);
  });
}
