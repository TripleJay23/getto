import 'behavior_profile.dart';
import 'stock_status.dart';

/// Pure Dart entity representing a tracked household product or asset.
class Item {
  Item({
    required this.id,
    required this.areaId,
    required this.name,
    required this.behaviorProfile,
    required this.stockStatus,
    this.unit,
    this.packageCount,
    required this.isArchived,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError(
        'Item name must be 1..100 characters (got "${name.length}")',
      );
    }
    if (packageCount != null) {
      if (packageCount! < 0) {
        throw ArgumentError(
          'Package count cannot be negative (got $packageCount)',
        );
      }
      if (packageCount! > 0 && stockStatus != StockStatus.inStock) {
        throw ArgumentError(
          'Item with positive package count ($packageCount) must have inStock status (got $stockStatus)',
        );
      }
      if (packageCount == 0 && stockStatus != StockStatus.outOfStock) {
        throw ArgumentError(
          'Item with zero package count must have outOfStock status (got $stockStatus)',
        );
      }
    }
    if (behaviorProfile == BehaviorProfile.durable && packageCount != null) {
      throw ArgumentError('Durable items do not track package counts');
    }
  }

  final int id;
  final int areaId;
  final String name;
  final BehaviorProfile behaviorProfile;

  /// The factual availability and physical presence of the item.
  final StockStatus stockStatus;
  final String? unit;

  /// Total number of usable packages/units currently available in the household.
  /// Null for items not tracked by package count (durable assets, single-unit replenishables).
  /// When present, positive count strictly mandates [StockStatus.inStock],
  /// and zero count strictly mandates [StockStatus.outOfStock].
  final int? packageCount;
  final bool isArchived;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Item copyWith({
    int? id,
    int? areaId,
    String? name,
    BehaviorProfile? behaviorProfile,
    StockStatus? stockStatus,
    String? unit,
    int? packageCount,
    bool? isArchived,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      areaId: areaId ?? this.areaId,
      name: name ?? this.name,
      behaviorProfile: behaviorProfile ?? this.behaviorProfile,
      stockStatus: stockStatus ?? this.stockStatus,
      unit: unit ?? this.unit,
      packageCount: packageCount ?? this.packageCount,
      isArchived: isArchived ?? this.isArchived,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          areaId == other.areaId &&
          name == other.name &&
          behaviorProfile == other.behaviorProfile &&
          stockStatus == other.stockStatus &&
          unit == other.unit &&
          packageCount == other.packageCount &&
          isArchived == other.isArchived &&
          notes == other.notes &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    areaId,
    name,
    behaviorProfile,
    stockStatus,
    unit,
    packageCount,
    isArchived,
    notes,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Item(id: $id, areaId: $areaId, name: $name, profile: $behaviorProfile, status: $stockStatus, count: $packageCount, archived: $isArchived)';
}
