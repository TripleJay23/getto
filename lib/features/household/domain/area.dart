/// Pure Dart entity representing a contextual physical household zone/area.
class Area {
  Area({
    required this.id,
    required this.name,
    required this.iconName,
    required this.displayOrder,
    required this.isArchived,
    this.isSystem = false,
    required this.createdAt,
    required this.updatedAt,
  }) {
    if (name.isEmpty || name.length > 50) {
      throw ArgumentError(
        'Area name must be 1..50 characters (got "${name.length}")',
      );
    }
    if (displayOrder < 0) {
      throw ArgumentError(
        'Display order must be non-negative (got $displayOrder)',
      );
    }
  }

  final int id;
  final String name;
  final String iconName;
  final int displayOrder;
  final bool isArchived;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  Area copyWith({
    int? id,
    String? name,
    String? iconName,
    int? displayOrder,
    bool? isArchived,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Area(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      displayOrder: displayOrder ?? this.displayOrder,
      isArchived: isArchived ?? this.isArchived,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Area &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          iconName == other.iconName &&
          displayOrder == other.displayOrder &&
          isArchived == other.isArchived &&
          isSystem == other.isSystem &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    iconName,
    displayOrder,
    isArchived,
    isSystem,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'Area(id: $id, name: $name, icon: $iconName, order: $displayOrder, archived: $isArchived, system: $isSystem)';
}
