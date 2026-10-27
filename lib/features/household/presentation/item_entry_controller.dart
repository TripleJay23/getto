import 'package:flutter/foundation.dart';

import '../../../core/domain/result/failure.dart';
import '../domain/area.dart';
import '../domain/area_repository.dart';
import '../domain/behavior_profile.dart';
import '../domain/item.dart';
import '../domain/item_repository.dart';
import '../domain/stock_status.dart';

/// Session draft, deliberately independent of a modal's lifetime.
class ItemEntryController extends ChangeNotifier {
  ItemEntryController(this._areas, this._items);

  final AreaRepository _areas;
  final ItemRepository _items;
  String name = '';
  Area? area;
  BehaviorProfile? profile;
  StockStatus? presence;
  int step = 0;
  bool busy = false;
  String? error;
  Area? createdArea;
  bool get areaWasCreated => createdArea != null;

  bool get validName => name.trim().isNotEmpty && name.trim().length <= 100;
  bool get hasIdentity => validName && area != null;
  bool get hasChoices => profile != null && presence != null;

  void change({
    String? name,
    Area? area,
    BehaviorProfile? profile,
    StockStatus? presence,
    int? step,
  }) {
    if (busy) return;
    this.name = name ?? this.name;
    this.area = area ?? this.area;
    this.profile = profile ?? this.profile;
    this.presence = presence ?? this.presence;
    this.step = step ?? this.step;
    error = null;
    notifyListeners();
  }

  void keepEditing() {
    error = null;
    notifyListeners();
  }

  Future<Area?> createArea(String name) async {
    if (busy) return null;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 50) {
      error = 'Enter an area name from 1 to 50 characters.';
      notifyListeners();
      return null;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final result = await _areas.createArea(name: trimmed);
      final created = result.valueOrNull;
      if (created != null) {
        area = created;
        createdArea = created;
      } else {
        error = result.failureOrNull is UniqueConflictFailure
            ? 'An active area already has this name. Choose it or enter another name.'
            : "Couldn't create the area. Your entry is still here.";
      }
      return created;
    } catch (_) {
      error = "Couldn't create the area. Your entry is still here.";
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<Item?> save() async {
    if (busy) return null;
    if (!hasIdentity || !hasChoices) {
      error =
          'Enter a name and choose an area, item type and physical presence.';
      notifyListeners();
      return null;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      final eligible = await _areas.getAreaById(area!.id);
      if (eligible.valueOrNull == null || eligible.valueOrNull!.isArchived) {
        step = 0;
        error = 'This area is unavailable. Choose an active home area.';
        return null;
      }
      final result = await _items.createItem(
        areaId: area!.id,
        name: name.trim(),
        behaviorProfile: profile!,
        stockStatus: presence!,
        requireActiveArea: true,
      );
      final item = result.valueOrNull;
      if (item == null) {
        if (result.failureOrNull is ForeignConstraintFailure) {
          step = 0;
          error = 'This area is unavailable. Choose an active home area. Your entry is still here.';
          return null;
        }
        error =
            "Couldn't save this change. Your entry is still here."
            '${areaWasCreated ? ' Your new area is already saved.' : ''}';
      } else {
        name = '';
        area = null;
        profile = null;
        presence = null;
        step = 0;
        createdArea = null;
      }
      return item;
    } catch (_) {
      error =
          "Couldn't save this change. Your entry is still here."
          '${areaWasCreated ? ' Your new area is already saved.' : ''}';
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
