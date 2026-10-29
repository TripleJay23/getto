import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_exception_mapper.dart';
import '../../../core/domain/local_date/local_date.dart';
import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../domain/item.dart';
import '../domain/item_lifecycle.dart';
import '../domain/lifecycle_checkpoint.dart';
import '../domain/lifecycle_cycle.dart';
import '../domain/lifecycle_repository.dart';

/// Implements commands with the accepted pure transitions and narrow row deltas.
class DriftLifecycleRepository implements LifecycleRepository {
  DriftLifecycleRepository(this._db, {this.clock = const Clock()});
  final AppDatabase _db;
  final Clock clock;

  // One statement gives reads/streams one SQLite snapshot across all three tables.
  Selectable<QueryRow> _aggregateQuery(int itemId) => _db.customSelect(
    'SELECT i.*, c.id AS cycle_id, c.item_id AS cycle_item_id, '
    'c.started_on AS cycle_start, c.finished_on AS cycle_finish, '
    'p.id AS checkpoint_id, p.cycle_id AS checkpoint_cycle_id, '
    'p.kind AS checkpoint_kind, p.observed_on AS checkpoint_date '
    'FROM items i LEFT JOIN lifecycle_cycles c ON c.item_id = i.id '
    'LEFT JOIN lifecycle_checkpoints p ON p.cycle_id = c.id '
    'WHERE i.id = ? ORDER BY c.id, p.id',
    variables: [Variable.withInt(itemId)],
    readsFrom: {
      _db.itemsTable,
      _db.lifecycleCyclesTable,
      _db.lifecycleCheckpointsTable,
    },
  );

  ItemLifecycle? _snapshot(List<QueryRow> rows) {
    if (rows.isEmpty) return null;
    try {
      final row = _db.itemsTable.map(rows.first.data);
      final item = Item(
        id: row.id,
        areaId: row.areaId,
        name: row.name,
        behaviorProfile: row.behaviorProfile,
        stockStatus: row.stockStatus,
        unit: row.unit,
        packageCount: row.packageCount,
        isArchived: row.isArchived,
        notes: row.notes,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
      final cycles = <int, LifecycleCycle>{};
      final checkpoints = <int, LifecycleCheckpoint>{};
      for (final row in rows) {
        final cycleId = row.readNullable<int>('cycle_id');
        if (cycleId != null) {
          cycles[cycleId] = LifecycleCycle(
            id: cycleId,
            itemId: row.read<int>('cycle_item_id'),
            startedOn: LocalDate.parse(row.read<String>('cycle_start')),
            finishedOn: row.readNullable<String>('cycle_finish') == null
                ? null
                : LocalDate.parse(row.read<String>('cycle_finish')),
          );
        }
        final checkpointId = row.readNullable<int>('checkpoint_id');
        if (checkpointId != null) {
          checkpoints[checkpointId] = LifecycleCheckpoint(
            id: checkpointId,
            cycleId: row.read<int>('checkpoint_cycle_id'),
            kind: LifecycleCheckpointKind.fromWireName(
              row.read<String>('checkpoint_kind'),
            ),
            observedOn: LocalDate.parse(row.read<String>('checkpoint_date')),
          );
        }
      }
      return ItemLifecycle(
        item: item,
        cycles: cycles.values,
        checkpoints: checkpoints.values,
      );
    } on ArgumentError {
      throw const DatabaseCorruptionFailure(
        'Saved lifecycle facts are invalid. Review stored evidence.',
      );
    } on FormatException {
      throw const DatabaseCorruptionFailure(
        'Saved lifecycle facts are invalid. Review stored evidence.',
      );
    }
  }

  Future<ItemLifecycle?> _load(int itemId) async =>
      _snapshot(await _aggregateQuery(itemId).get());

  Result<ItemLifecycle, Failure> _readResult(ItemLifecycle? snapshot) =>
      snapshot == null
      ? const Result.failure(EntityNotFoundFailure('Item is unavailable.'))
      : Result.success(snapshot);

  @override
  Future<Result<ItemLifecycle, Failure>> getLifecycle(int itemId) async {
    try {
      return _readResult(await _load(itemId));
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Stream<Result<ItemLifecycle, Failure>> watchLifecycle(int itemId) async* {
    ItemLifecycle? previous;
    try {
      await for (final rows in _aggregateQuery(itemId).watch()) {
        try {
          final current = _snapshot(rows);
          if (current != null &&
              previous != null &&
              current.item == previous.item &&
              _sameRecords(current.cycles, previous.cycles) &&
              _sameRecords(current.checkpoints, previous.checkpoints)) {
            continue;
          }
          previous = current;
          yield _readResult(current);
        } catch (e, st) {
          previous = null;
          yield Result.failure(mapDatabaseException(e, st));
        }
      }
    } catch (e, st) {
      yield Result.failure(mapDatabaseException(e, st));
    }
  }

  bool _sameRecords<T>(List<T> first, List<T> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }

  @override
  Future<Result<List<LifecycleCycle>, Failure>> getCompletedCycles(
    int itemId, {
    int limit = 50,
    int? beforeCycleId,
  }) async {
    if (limit < 1 || limit > 100) {
      return const Result.failure(
        ValidationError('History page size must be between 1 and 100.'),
      );
    }
    try {
      return await _db.transaction(() async {
        if (await (_db.select(
              _db.itemsTable,
            )..where((t) => t.id.equals(itemId))).getSingleOrNull() ==
            null) {
          return const Result.failure(
            EntityNotFoundFailure('Item is unavailable.'),
          );
        }
        final query = _db.select(_db.lifecycleCyclesTable)
          ..where((t) => t.itemId.equals(itemId) & t.finishedOn.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit);
        if (beforeCycleId != null) {
          query.where((t) => t.id.isSmallerThanValue(beforeCycleId));
        }
        final rows = await query.get();
        return Result.success(
          List<LifecycleCycle>.unmodifiable(
            rows.map(
              (r) => LifecycleCycle(
                id: r.id,
                itemId: r.itemId,
                startedOn: r.startedOn,
                finishedOn: r.finishedOn,
              ),
            ),
          ),
        );
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  @override
  Future<Result<List<LifecycleCheckpoint>, Failure>> getCheckpoints({
    required int itemId,
    required int cycleId,
  }) async {
    try {
      return await _db.transaction(() async {
        final owner =
            await (_db.select(
                  _db.lifecycleCyclesTable,
                )..where((t) => t.id.equals(cycleId) & t.itemId.equals(itemId)))
                .getSingleOrNull();
        if (owner == null) {
          return const Result.failure(
            LifecycleTargetFailure('The selected cycle is unavailable.'),
          );
        }
        final rows =
            await (_db.select(_db.lifecycleCheckpointsTable)
                  ..where((t) => t.cycleId.equals(cycleId))
                  ..orderBy([(t) => OrderingTerm.asc(t.id)]))
                .get();
        return Result.success(
          List<LifecycleCheckpoint>.unmodifiable(
            rows.map(
              (r) => LifecycleCheckpoint(
                id: r.id,
                cycleId: r.cycleId,
                kind: r.kind,
                observedOn: r.observedOn,
              ),
            ),
          ),
        );
      });
    } catch (e, st) {
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  // Temporary identities are only for pure transitions; inserts always omit IDs.
  int _temporaryId(Iterable<int> ids) =>
      ids.fold(0, (min, id) => id < min ? id : min) - 1;

  @override
  Future<Result<ItemLifecycle, Failure>> start({
    required int itemId,
    required LocalDate startedOn,
    required LocalDate today,
  }) => _mutate(
    itemId,
    (current) => current.start(
      cycleId: _temporaryId(current.cycles.map((c) => c.id)),
      startedOn: startedOn,
      today: today,
    ),
  );

  @override
  Future<Result<ItemLifecycle, Failure>> restock({
    required int itemId,
    required LocalDate startedOn,
    required LocalDate today,
    int? absolutePackageCount,
    ActiveCycleResolution? resolution,
  }) => _mutate(itemId, (current) {
    var resolved = current;
    if (resolution != null) {
      if (!resolution.expected.isActive) {
        return const Result.failure(
          LifecycleTargetFailure('Resolve the expected active cycle only.'),
        );
      }
      final Result<ItemLifecycle, LifecycleFailure> result;
      switch (resolution) {
        case FinishActiveCycle():
          final stale = _reconciliationFailure(
            current,
            resolution.expected,
            resolution.reconciliation,
          );
          if (stale != null) return Result.failure(stale);
          result = current.finish(
            expected: resolution.expected,
            finishedOn: resolution.finishedOn,
            today: today,
            checkpointDates: _dates(resolution.reconciliation),
            removedCheckpointIds: _removed(resolution.reconciliation),
          );
        case RemoveErroneousActiveCycle():
          result = current.removeCycle(expected: resolution.expected);
      }
      if (result.isFailure) return result;
      resolved = result.valueOrNull!;
    }
    return resolved.restock(
      cycleId: _temporaryId(current.cycles.map((c) => c.id)),
      startedOn: startedOn,
      today: today,
      absolutePackageCount: absolutePackageCount,
    );
  });

  Map<int, LocalDate> _dates(CheckpointReconciliation? reconciliation) => {
    for (final entry
        in reconciliation?.corrected.entries ??
            <MapEntry<LifecycleCheckpoint, LocalDate>>[])
      entry.key.id: entry.value,
  };
  Set<int> _removed(CheckpointReconciliation? reconciliation) => {
    for (final checkpoint in reconciliation?.removed ?? <LifecycleCheckpoint>{})
      checkpoint.id,
  };

  LifecycleTargetFailure? _reconciliationFailure(
    ItemLifecycle current,
    LifecycleCycle expected,
    CheckpointReconciliation? reconciliation,
  ) {
    final ids = <int>{};
    for (final checkpoint in [
      ...?reconciliation?.corrected.keys,
      ...?reconciliation?.removed,
    ]) {
      if (checkpoint.cycleId != expected.id ||
          !ids.add(checkpoint.id) ||
          !current.checkpoints.contains(checkpoint)) {
        return const LifecycleTargetFailure(
          'The selected observations are missing or changed. Review saved evidence.',
        );
      }
    }
    return null;
  }

  @override
  Future<Result<ItemLifecycle, Failure>> finish({
    required LifecycleCycle expected,
    required LocalDate finishedOn,
    required LocalDate today,
    CheckpointReconciliation? reconciliation,
  }) => _mutate(expected.itemId, (current) {
    final stale = _reconciliationFailure(current, expected, reconciliation);
    if (stale != null) return Result.failure(stale);
    return current.finish(
      expected: expected,
      finishedOn: finishedOn,
      today: today,
      checkpointDates: _dates(reconciliation),
      removedCheckpointIds: _removed(reconciliation),
    );
  });

  @override
  Future<Result<ItemLifecycle, Failure>> correctCycleDates({
    required LifecycleCycle expected,
    required LocalDate startedOn,
    required LocalDate? finishedOn,
    required LocalDate today,
    CheckpointReconciliation? reconciliation,
  }) => _mutate(expected.itemId, (current) {
    final stale = _reconciliationFailure(current, expected, reconciliation);
    if (stale != null) return Result.failure(stale);
    return current.correctCycleDates(
      expected: expected,
      startedOn: startedOn,
      finishedOn: finishedOn,
      today: today,
      checkpointDates: _dates(reconciliation),
      removedCheckpointIds: _removed(reconciliation),
    );
  });

  @override
  Future<Result<ItemLifecycle, Failure>> removeCycle({
    required LifecycleCycle expected,
  }) => _mutate(
    expected.itemId,
    (current) => current.removeCycle(expected: expected),
  );

  @override
  Future<Result<ItemLifecycle, Failure>> addCheckpoint({
    required LifecycleCycle expectedCycle,
    required LifecycleCheckpointKind kind,
    required LocalDate observedOn,
    required LocalDate today,
  }) => _mutate(
    expectedCycle.itemId,
    (current) => current.addCheckpoint(
      expectedCycle: expectedCycle,
      checkpoint: LifecycleCheckpoint(
        id: _temporaryId(current.checkpoints.map((p) => p.id)),
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
  }) => _mutate(
    itemId,
    (current) => current.correctCheckpoint(
      expected: expected,
      observedOn: observedOn,
      today: today,
    ),
  );

  @override
  Future<Result<ItemLifecycle, Failure>> correctCount({
    required Item expected,
    required int absoluteCurrentTotal,
  }) => _mutate(expected.id, (current) {
    final result = current.correctCount(
      absoluteCurrentTotal: absoluteCurrentTotal,
    );
    if (result.isFailure) return result;
    if (current.item.stockStatus != expected.stockStatus ||
        current.item.packageCount != expected.packageCount ||
        current.item.behaviorProfile != expected.behaviorProfile) {
      return const Result.failure(
        StaleItemFailure(
          'Availability changed. Review the saved current total.',
        ),
      );
    }
    return result;
  });

  Future<Result<ItemLifecycle, Failure>> _mutate(
    int itemId,
    Result<ItemLifecycle, Failure> Function(ItemLifecycle) transition,
  ) async {
    try {
      return await _db.transaction(() async {
        final current = await _load(itemId);
        if (current == null) {
          return const Result.failure(
            EntityNotFoundFailure('Item is unavailable.'),
          );
        }
        final next = transition(current);
        if (next.isFailure) return next;
        await _persist(current, next.valueOrNull!);
        final saved = await _load(itemId);
        if (saved == null) {
          // A post-write failure must throw, never return a failure and commit.
          throw const StaleItemFailure(
            'The item changed while saving. Review saved evidence.',
          );
        }
        return Result.success(saved);
      });
    } catch (e, st) {
      // Catch outside: a thrown write/commit error rolls back every prior write.
      return Result.failure(mapDatabaseException(e, st));
    }
  }

  void _requireOne(int affected) {
    if (affected != 1) {
      throw const StaleItemFailure(
        'Saved records changed. Review the latest evidence.',
      );
    }
  }

  Future<void> _persist(ItemLifecycle before, ItemLifecycle after) async {
    final oldCycles = {for (final c in before.cycles) c.id: c};
    final newCycles = {for (final c in after.cycles) c.id: c};
    final oldCheckpoints = {for (final p in before.checkpoints) p.id: p};
    final newCheckpoints = {for (final p in after.checkpoints) p.id: p};
    var changed = false;
    for (final old in before.cycles) {
      if (!newCycles.containsKey(old.id)) {
        _requireOne(
          await (_db.delete(_db.lifecycleCyclesTable)..where(
                (t) => t.id.equals(old.id) & t.itemId.equals(before.item.id),
              ))
              .go(),
        );
        changed = true;
      }
    }
    final assignedIds = <int, int>{};
    for (final cycle in after.cycles) {
      final old = oldCycles[cycle.id];
      if (old == cycle) continue;
      changed = true;
      if (old == null) {
        assignedIds[cycle.id] =
            (await _db
                    .into(_db.lifecycleCyclesTable)
                    .insertReturning(
                      LifecycleCyclesTableCompanion.insert(
                        itemId: before.item.id,
                        startedOn: cycle.startedOn,
                        finishedOn: Value(cycle.finishedOn),
                      ),
                    ))
                .id;
      } else {
        _requireOne(
          await (_db.update(_db.lifecycleCyclesTable)..where(
                (t) => t.id.equals(cycle.id) & t.itemId.equals(before.item.id),
              ))
              .write(
                LifecycleCyclesTableCompanion(
                  startedOn: Value(cycle.startedOn),
                  finishedOn: Value(cycle.finishedOn),
                ),
              ),
        );
      }
    }
    for (final old in before.checkpoints) {
      if (!newCheckpoints.containsKey(old.id) &&
          newCycles.containsKey(old.cycleId)) {
        _requireOne(
          await (_db.delete(_db.lifecycleCheckpointsTable)..where(
                (t) => t.id.equals(old.id) & t.cycleId.equals(old.cycleId),
              ))
              .go(),
        );
        changed = true;
      }
    }
    for (final checkpoint in after.checkpoints) {
      final old = oldCheckpoints[checkpoint.id];
      if (old == checkpoint) continue;
      changed = true;
      if (old == null) {
        await _db
            .into(_db.lifecycleCheckpointsTable)
            .insertReturning(
              LifecycleCheckpointsTableCompanion.insert(
                cycleId: assignedIds[checkpoint.cycleId] ?? checkpoint.cycleId,
                kind: checkpoint.kind,
                observedOn: checkpoint.observedOn,
              ),
            );
      } else {
        _requireOne(
          await (_db.update(_db.lifecycleCheckpointsTable)..where(
                (t) =>
                    t.id.equals(checkpoint.id) &
                    t.cycleId.equals(checkpoint.cycleId),
              ))
              .write(
                LifecycleCheckpointsTableCompanion(
                  observedOn: Value(checkpoint.observedOn),
                ),
              ),
        );
      }
    }
    final stockChanged =
        before.item.stockStatus != after.item.stockStatus ||
        before.item.packageCount != after.item.packageCount;
    if (changed || stockChanged) {
      _requireOne(
        await (_db.update(
          _db.itemsTable,
        )..where((t) => t.id.equals(before.item.id))).write(
          ItemsTableCompanion(
            stockStatus: stockChanged
                ? Value(after.item.stockStatus)
                : const Value.absent(),
            packageCount: stockChanged
                ? Value(after.item.packageCount)
                : const Value.absent(),
            updatedAt: Value(clock.now().toUtc()),
          ),
        ),
      );
    }
  }
}
