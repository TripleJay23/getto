import 'package:flutter/foundation.dart';

import '../../../core/domain/result/failure.dart';
import '../../../core/domain/result/result.dart';
import '../application/remove_area_use_case.dart';
import '../application/reorder_areas_use_case.dart';
import '../domain/area.dart';
import '../domain/area_repository.dart';

/// Session drafts and single-flight commands. Committed streams own saved truth.
class AreaManagementController extends ChangeNotifier {
  AreaManagementController(this.areas, this.remove, this.reorder);
  final AreaRepository areas;
  final RemoveAreaUseCase remove;
  final ReorderAreasUseCase reorder;
  String name = '';
  String? error;
  bool busy = false;
  bool conflict = false;
  bool _disposed = false;
  AreaRemovalSnapshot? confirmation;

  bool get validName => name.trim().isNotEmpty && name.trim().length <= 50;

  Future<bool> _run(Future<Result<Object?, Failure>> Function() command) async {
    if (busy) return false;
    busy = true;
    error = null;
    conflict = false;
    notifyListeners();
    try {
      final result = await command();
      if (result.isSuccess) return true;
      final failure = result.failureOrNull;
      conflict = failure is StaleAreaFailure;
      if (conflict) confirmation = null;
      error = switch (failure) {
        StaleAreaFailure() => 'Saved areas or contained items changed. Your entry is retained. Review the latest state before confirming again.',
        UniqueConflictFailure() => 'An active area already has this name. Enter another name, or rename the archived area before restoring it.',
        AreaNotEmptyFailure() || ForeignConstraintFailure() => 'This area contains saved items. Refresh to review safe removal options.',
        EntityNotFoundFailure() =>
          'This area is unavailable. Return to Manage areas.',
        CheckConstraintFailure() || ValidationError() =>
          'Check the name or choose an existing active destination.',
        _ => "Couldn't save this change. Your entry is retained. Retry or keep editing.",
      };
      return false;
    } catch (_) {
      error = "Couldn't save this change. Your entry is retained. Retry or keep editing.";
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> saveName({Area? expected}) async {
    if (busy) return false;
    if (!validName) {
      error = 'Enter an area name from 1 to 50 characters.';
      notifyListeners();
      return false;
    }
    return _run(
      () => expected == null
          ? areas.createArea(name: name.trim())
          : areas.renameArea(expected: expected, name: name.trim()),
    );
  }

  Future<bool> move(List<Area> catalog, int id, int offset) async {
    if (busy) return false;
    final active = catalog
        .where((a) => !a.isArchived)
        .map((a) => a.id)
        .toList();
    final index = active.indexOf(id);
    final target = index + offset;
    if (index < 0 || target < 0 || target >= active.length) return false;
    active[index] = active[target];
    active[target] = id;
    return _run(() => reorder.execute(active, expectedCatalog: catalog));
  }

  Future<bool> archive(int id) =>
      _run(() => remove.execute(areaId: id, mode: AreaRemovalMode.archive));
  Future<bool> restore(int id) => _run(() => areas.restoreArea(id));

  Future<bool> reviewRemoval(int id, {int? targetAreaId}) async {
    if (busy) return false;
    confirmation = null;
    return _run(() async {
      final result = await areas.getRemovalSnapshot(
        id,
        targetAreaId: targetAreaId,
      );
      confirmation = result.valueOrNull;
      return result;
    });
  }

  Future<bool> confirmRemoval() async {
    if (busy) return false;
    final reviewed = confirmation;
    if (reviewed == null) return false;
    return _run(
      () => remove.execute(
        areaId: reviewed.source.id,
        mode: reviewed.destination == null
            ? AreaRemovalMode.deleteIfEmpty
            : AreaRemovalMode.relocateAndDelete,
        targetAreaId: reviewed.destination?.id,
        expected: reviewed,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
