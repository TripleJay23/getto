// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AreasTableTable extends AreasTable
    with TableInfo<$AreasTableTable, AreaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AreasTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('general'),
  );
  static const VerificationMeta _displayOrderMeta = const VerificationMeta(
    'displayOrder',
  );
  @override
  late final GeneratedColumn<int> displayOrder = GeneratedColumn<int>(
    'display_order',
    aliasedName,
    false,
    check: () =>
        ComparableExpr(displayOrder).isBiggerOrEqual(const Constant(0)),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    iconName,
    displayOrder,
    isArchived,
    isSystem,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'areas';
  @override
  VerificationContext validateIntegrity(
    Insertable<AreaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    if (data.containsKey('display_order')) {
      context.handle(
        _displayOrderMeta,
        displayOrder.isAcceptableOrUnknown(
          data['display_order']!,
          _displayOrderMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AreaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AreaData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      displayOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}display_order'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AreasTableTable createAlias(String alias) {
    return $AreasTableTable(attachedDatabase, alias);
  }
}

class AreaData extends DataClass implements Insertable<AreaData> {
  final int id;
  final String name;
  final String iconName;
  final int displayOrder;
  final bool isArchived;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AreaData({
    required this.id,
    required this.name,
    required this.iconName,
    required this.displayOrder,
    required this.isArchived,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['icon_name'] = Variable<String>(iconName);
    map['display_order'] = Variable<int>(displayOrder);
    map['is_archived'] = Variable<bool>(isArchived);
    map['is_system'] = Variable<bool>(isSystem);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AreasTableCompanion toCompanion(bool nullToAbsent) {
    return AreasTableCompanion(
      id: Value(id),
      name: Value(name),
      iconName: Value(iconName),
      displayOrder: Value(displayOrder),
      isArchived: Value(isArchived),
      isSystem: Value(isSystem),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AreaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AreaData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String>(json['iconName']),
      displayOrder: serializer.fromJson<int>(json['displayOrder']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String>(iconName),
      'displayOrder': serializer.toJson<int>(displayOrder),
      'isArchived': serializer.toJson<bool>(isArchived),
      'isSystem': serializer.toJson<bool>(isSystem),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AreaData copyWith({
    int? id,
    String? name,
    String? iconName,
    int? displayOrder,
    bool? isArchived,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AreaData(
    id: id ?? this.id,
    name: name ?? this.name,
    iconName: iconName ?? this.iconName,
    displayOrder: displayOrder ?? this.displayOrder,
    isArchived: isArchived ?? this.isArchived,
    isSystem: isSystem ?? this.isSystem,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AreaData copyWithCompanion(AreasTableCompanion data) {
    return AreaData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      displayOrder: data.displayOrder.present
          ? data.displayOrder.value
          : this.displayOrder,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AreaData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('isArchived: $isArchived, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AreaData &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.displayOrder == this.displayOrder &&
          other.isArchived == this.isArchived &&
          other.isSystem == this.isSystem &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AreasTableCompanion extends UpdateCompanion<AreaData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> iconName;
  final Value<int> displayOrder;
  final Value<bool> isArchived;
  final Value<bool> isSystem;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AreasTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AreasTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.iconName = const Value.absent(),
    this.displayOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<AreaData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<int>? displayOrder,
    Expression<bool>? isArchived,
    Expression<bool>? isSystem,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (displayOrder != null) 'display_order': displayOrder,
      if (isArchived != null) 'is_archived': isArchived,
      if (isSystem != null) 'is_system': isSystem,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AreasTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? iconName,
    Value<int>? displayOrder,
    Value<bool>? isArchived,
    Value<bool>? isSystem,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AreasTableCompanion(
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
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (displayOrder.present) {
      map['display_order'] = Variable<int>(displayOrder.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AreasTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('displayOrder: $displayOrder, ')
          ..write('isArchived: $isArchived, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ItemsTableTable extends ItemsTable
    with TableInfo<$ItemsTableTable, ItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _areaIdMeta = const VerificationMeta('areaId');
  @override
  late final GeneratedColumn<int> areaId = GeneratedColumn<int>(
    'area_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES areas (id) ON UPDATE CASCADE ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BehaviorProfile, String>
  behaviorProfile = GeneratedColumn<String>(
    'behavior_profile',
    aliasedName,
    false,
    check: () => behaviorProfile.isIn(const [
      'replenishable',
      'countableReplenishable',
      'durable',
    ]),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<BehaviorProfile>($ItemsTableTable.$converterbehaviorProfile);
  @override
  late final GeneratedColumnWithTypeConverter<StockStatus, String> stockStatus =
      GeneratedColumn<String>(
        'stock_status',
        aliasedName,
        false,
        check: () => stockStatus.isIn(const ['inStock', 'outOfStock']),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<StockStatus>($ItemsTableTable.$converterstockStatus);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packageCountMeta = const VerificationMeta(
    'packageCount',
  );
  @override
  late final GeneratedColumn<int> packageCount = GeneratedColumn<int>(
    'package_count',
    aliasedName,
    true,
    check: () =>
        packageCount.isNull() |
        ComparableExpr(packageCount).isBiggerOrEqual(const Constant(0)),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
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
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('area_id')) {
      context.handle(
        _areaIdMeta,
        areaId.isAcceptableOrUnknown(data['area_id']!, _areaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_areaIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('package_count')) {
      context.handle(
        _packageCountMeta,
        packageCount.isAcceptableOrUnknown(
          data['package_count']!,
          _packageCountMeta,
        ),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      areaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}area_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      behaviorProfile: $ItemsTableTable.$converterbehaviorProfile.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}behavior_profile'],
        )!,
      ),
      stockStatus: $ItemsTableTable.$converterstockStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}stock_status'],
        )!,
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      packageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}package_count'],
      ),
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ItemsTableTable createAlias(String alias) {
    return $ItemsTableTable(attachedDatabase, alias);
  }

  static TypeConverter<BehaviorProfile, String> $converterbehaviorProfile =
      const BehaviorProfileConverter();
  static TypeConverter<StockStatus, String> $converterstockStatus =
      const StockStatusConverter();
}

class ItemData extends DataClass implements Insertable<ItemData> {
  final int id;
  final int areaId;
  final String name;
  final BehaviorProfile behaviorProfile;
  final StockStatus stockStatus;
  final String? unit;
  final int? packageCount;
  final bool isArchived;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ItemData({
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
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['area_id'] = Variable<int>(areaId);
    map['name'] = Variable<String>(name);
    {
      map['behavior_profile'] = Variable<String>(
        $ItemsTableTable.$converterbehaviorProfile.toSql(behaviorProfile),
      );
    }
    {
      map['stock_status'] = Variable<String>(
        $ItemsTableTable.$converterstockStatus.toSql(stockStatus),
      );
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || packageCount != null) {
      map['package_count'] = Variable<int>(packageCount);
    }
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ItemsTableCompanion toCompanion(bool nullToAbsent) {
    return ItemsTableCompanion(
      id: Value(id),
      areaId: Value(areaId),
      name: Value(name),
      behaviorProfile: Value(behaviorProfile),
      stockStatus: Value(stockStatus),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      packageCount: packageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(packageCount),
      isArchived: Value(isArchived),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ItemData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemData(
      id: serializer.fromJson<int>(json['id']),
      areaId: serializer.fromJson<int>(json['areaId']),
      name: serializer.fromJson<String>(json['name']),
      behaviorProfile: serializer.fromJson<BehaviorProfile>(
        json['behaviorProfile'],
      ),
      stockStatus: serializer.fromJson<StockStatus>(json['stockStatus']),
      unit: serializer.fromJson<String?>(json['unit']),
      packageCount: serializer.fromJson<int?>(json['packageCount']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'areaId': serializer.toJson<int>(areaId),
      'name': serializer.toJson<String>(name),
      'behaviorProfile': serializer.toJson<BehaviorProfile>(behaviorProfile),
      'stockStatus': serializer.toJson<StockStatus>(stockStatus),
      'unit': serializer.toJson<String?>(unit),
      'packageCount': serializer.toJson<int?>(packageCount),
      'isArchived': serializer.toJson<bool>(isArchived),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ItemData copyWith({
    int? id,
    int? areaId,
    String? name,
    BehaviorProfile? behaviorProfile,
    StockStatus? stockStatus,
    Value<String?> unit = const Value.absent(),
    Value<int?> packageCount = const Value.absent(),
    bool? isArchived,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ItemData(
    id: id ?? this.id,
    areaId: areaId ?? this.areaId,
    name: name ?? this.name,
    behaviorProfile: behaviorProfile ?? this.behaviorProfile,
    stockStatus: stockStatus ?? this.stockStatus,
    unit: unit.present ? unit.value : this.unit,
    packageCount: packageCount.present ? packageCount.value : this.packageCount,
    isArchived: isArchived ?? this.isArchived,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ItemData copyWithCompanion(ItemsTableCompanion data) {
    return ItemData(
      id: data.id.present ? data.id.value : this.id,
      areaId: data.areaId.present ? data.areaId.value : this.areaId,
      name: data.name.present ? data.name.value : this.name,
      behaviorProfile: data.behaviorProfile.present
          ? data.behaviorProfile.value
          : this.behaviorProfile,
      stockStatus: data.stockStatus.present
          ? data.stockStatus.value
          : this.stockStatus,
      unit: data.unit.present ? data.unit.value : this.unit,
      packageCount: data.packageCount.present
          ? data.packageCount.value
          : this.packageCount,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemData(')
          ..write('id: $id, ')
          ..write('areaId: $areaId, ')
          ..write('name: $name, ')
          ..write('behaviorProfile: $behaviorProfile, ')
          ..write('stockStatus: $stockStatus, ')
          ..write('unit: $unit, ')
          ..write('packageCount: $packageCount, ')
          ..write('isArchived: $isArchived, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemData &&
          other.id == this.id &&
          other.areaId == this.areaId &&
          other.name == this.name &&
          other.behaviorProfile == this.behaviorProfile &&
          other.stockStatus == this.stockStatus &&
          other.unit == this.unit &&
          other.packageCount == this.packageCount &&
          other.isArchived == this.isArchived &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ItemsTableCompanion extends UpdateCompanion<ItemData> {
  final Value<int> id;
  final Value<int> areaId;
  final Value<String> name;
  final Value<BehaviorProfile> behaviorProfile;
  final Value<StockStatus> stockStatus;
  final Value<String?> unit;
  final Value<int?> packageCount;
  final Value<bool> isArchived;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ItemsTableCompanion({
    this.id = const Value.absent(),
    this.areaId = const Value.absent(),
    this.name = const Value.absent(),
    this.behaviorProfile = const Value.absent(),
    this.stockStatus = const Value.absent(),
    this.unit = const Value.absent(),
    this.packageCount = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ItemsTableCompanion.insert({
    this.id = const Value.absent(),
    required int areaId,
    required String name,
    required BehaviorProfile behaviorProfile,
    required StockStatus stockStatus,
    this.unit = const Value.absent(),
    this.packageCount = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : areaId = Value(areaId),
       name = Value(name),
       behaviorProfile = Value(behaviorProfile),
       stockStatus = Value(stockStatus);
  static Insertable<ItemData> custom({
    Expression<int>? id,
    Expression<int>? areaId,
    Expression<String>? name,
    Expression<String>? behaviorProfile,
    Expression<String>? stockStatus,
    Expression<String>? unit,
    Expression<int>? packageCount,
    Expression<bool>? isArchived,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (areaId != null) 'area_id': areaId,
      if (name != null) 'name': name,
      if (behaviorProfile != null) 'behavior_profile': behaviorProfile,
      if (stockStatus != null) 'stock_status': stockStatus,
      if (unit != null) 'unit': unit,
      if (packageCount != null) 'package_count': packageCount,
      if (isArchived != null) 'is_archived': isArchived,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ItemsTableCompanion copyWith({
    Value<int>? id,
    Value<int>? areaId,
    Value<String>? name,
    Value<BehaviorProfile>? behaviorProfile,
    Value<StockStatus>? stockStatus,
    Value<String?>? unit,
    Value<int?>? packageCount,
    Value<bool>? isArchived,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ItemsTableCompanion(
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
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (areaId.present) {
      map['area_id'] = Variable<int>(areaId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (behaviorProfile.present) {
      map['behavior_profile'] = Variable<String>(
        $ItemsTableTable.$converterbehaviorProfile.toSql(behaviorProfile.value),
      );
    }
    if (stockStatus.present) {
      map['stock_status'] = Variable<String>(
        $ItemsTableTable.$converterstockStatus.toSql(stockStatus.value),
      );
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (packageCount.present) {
      map['package_count'] = Variable<int>(packageCount.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsTableCompanion(')
          ..write('id: $id, ')
          ..write('areaId: $areaId, ')
          ..write('name: $name, ')
          ..write('behaviorProfile: $behaviorProfile, ')
          ..write('stockStatus: $stockStatus, ')
          ..write('unit: $unit, ')
          ..write('packageCount: $packageCount, ')
          ..write('isArchived: $isArchived, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LifecycleCyclesTableTable extends LifecycleCyclesTable
    with TableInfo<$LifecycleCyclesTableTable, LifecycleCycleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LifecycleCyclesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<int> itemId = GeneratedColumn<int>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> startedOn =
      GeneratedColumn<String>(
        'started_on',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>(
        $LifecycleCyclesTableTable.$converterstartedOn,
      );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate?, String> finishedOn =
      GeneratedColumn<String>(
        'finished_on',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<LocalDate?>(
        $LifecycleCyclesTableTable.$converterfinishedOnn,
      );
  @override
  List<GeneratedColumn> get $columns => [id, itemId, startedOn, finishedOn];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lifecycle_cycles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LifecycleCycleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LifecycleCycleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LifecycleCycleData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_id'],
      )!,
      startedOn: $LifecycleCyclesTableTable.$converterstartedOn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}started_on'],
        )!,
      ),
      finishedOn: $LifecycleCyclesTableTable.$converterfinishedOnn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}finished_on'],
        ),
      ),
    );
  }

  @override
  $LifecycleCyclesTableTable createAlias(String alias) {
    return $LifecycleCyclesTableTable(attachedDatabase, alias);
  }

  static TypeConverter<LocalDate, String> $converterstartedOn =
      const LocalDateConverter();
  static TypeConverter<LocalDate, String> $converterfinishedOn =
      const LocalDateConverter();
  static TypeConverter<LocalDate?, String?> $converterfinishedOnn =
      NullAwareTypeConverter.wrap($converterfinishedOn);
}

class LifecycleCycleData extends DataClass
    implements Insertable<LifecycleCycleData> {
  final int id;
  final int itemId;
  final LocalDate startedOn;
  final LocalDate? finishedOn;
  const LifecycleCycleData({
    required this.id,
    required this.itemId,
    required this.startedOn,
    this.finishedOn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_id'] = Variable<int>(itemId);
    {
      map['started_on'] = Variable<String>(
        $LifecycleCyclesTableTable.$converterstartedOn.toSql(startedOn),
      );
    }
    if (!nullToAbsent || finishedOn != null) {
      map['finished_on'] = Variable<String>(
        $LifecycleCyclesTableTable.$converterfinishedOnn.toSql(finishedOn),
      );
    }
    return map;
  }

  LifecycleCyclesTableCompanion toCompanion(bool nullToAbsent) {
    return LifecycleCyclesTableCompanion(
      id: Value(id),
      itemId: Value(itemId),
      startedOn: Value(startedOn),
      finishedOn: finishedOn == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedOn),
    );
  }

  factory LifecycleCycleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LifecycleCycleData(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<int>(json['itemId']),
      startedOn: serializer.fromJson<LocalDate>(json['startedOn']),
      finishedOn: serializer.fromJson<LocalDate?>(json['finishedOn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<int>(itemId),
      'startedOn': serializer.toJson<LocalDate>(startedOn),
      'finishedOn': serializer.toJson<LocalDate?>(finishedOn),
    };
  }

  LifecycleCycleData copyWith({
    int? id,
    int? itemId,
    LocalDate? startedOn,
    Value<LocalDate?> finishedOn = const Value.absent(),
  }) => LifecycleCycleData(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    startedOn: startedOn ?? this.startedOn,
    finishedOn: finishedOn.present ? finishedOn.value : this.finishedOn,
  );
  LifecycleCycleData copyWithCompanion(LifecycleCyclesTableCompanion data) {
    return LifecycleCycleData(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      startedOn: data.startedOn.present ? data.startedOn.value : this.startedOn,
      finishedOn: data.finishedOn.present
          ? data.finishedOn.value
          : this.finishedOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LifecycleCycleData(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('startedOn: $startedOn, ')
          ..write('finishedOn: $finishedOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, startedOn, finishedOn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LifecycleCycleData &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.startedOn == this.startedOn &&
          other.finishedOn == this.finishedOn);
}

class LifecycleCyclesTableCompanion
    extends UpdateCompanion<LifecycleCycleData> {
  final Value<int> id;
  final Value<int> itemId;
  final Value<LocalDate> startedOn;
  final Value<LocalDate?> finishedOn;
  const LifecycleCyclesTableCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.startedOn = const Value.absent(),
    this.finishedOn = const Value.absent(),
  });
  LifecycleCyclesTableCompanion.insert({
    this.id = const Value.absent(),
    required int itemId,
    required LocalDate startedOn,
    this.finishedOn = const Value.absent(),
  }) : itemId = Value(itemId),
       startedOn = Value(startedOn);
  static Insertable<LifecycleCycleData> custom({
    Expression<int>? id,
    Expression<int>? itemId,
    Expression<String>? startedOn,
    Expression<String>? finishedOn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (startedOn != null) 'started_on': startedOn,
      if (finishedOn != null) 'finished_on': finishedOn,
    });
  }

  LifecycleCyclesTableCompanion copyWith({
    Value<int>? id,
    Value<int>? itemId,
    Value<LocalDate>? startedOn,
    Value<LocalDate?>? finishedOn,
  }) {
    return LifecycleCyclesTableCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      startedOn: startedOn ?? this.startedOn,
      finishedOn: finishedOn ?? this.finishedOn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<int>(itemId.value);
    }
    if (startedOn.present) {
      map['started_on'] = Variable<String>(
        $LifecycleCyclesTableTable.$converterstartedOn.toSql(startedOn.value),
      );
    }
    if (finishedOn.present) {
      map['finished_on'] = Variable<String>(
        $LifecycleCyclesTableTable.$converterfinishedOnn.toSql(
          finishedOn.value,
        ),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LifecycleCyclesTableCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('startedOn: $startedOn, ')
          ..write('finishedOn: $finishedOn')
          ..write(')'))
        .toString();
  }
}

class $LifecycleCheckpointsTableTable extends LifecycleCheckpointsTable
    with TableInfo<$LifecycleCheckpointsTableTable, LifecycleCheckpointData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LifecycleCheckpointsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cycleIdMeta = const VerificationMeta(
    'cycleId',
  );
  @override
  late final GeneratedColumn<int> cycleId = GeneratedColumn<int>(
    'cycle_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lifecycle_cycles (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LifecycleCheckpointKind, String>
  kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        check: () => kind.isIn(const ['aboutHalf', 'nearlyFinished']),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LifecycleCheckpointKind>(
        $LifecycleCheckpointsTableTable.$converterkind,
      );
  @override
  late final GeneratedColumnWithTypeConverter<LocalDate, String> observedOn =
      GeneratedColumn<String>(
        'observed_on',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocalDate>(
        $LifecycleCheckpointsTableTable.$converterobservedOn,
      );
  @override
  List<GeneratedColumn> get $columns => [id, cycleId, kind, observedOn];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lifecycle_checkpoints';
  @override
  VerificationContext validateIntegrity(
    Insertable<LifecycleCheckpointData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cycle_id')) {
      context.handle(
        _cycleIdMeta,
        cycleId.isAcceptableOrUnknown(data['cycle_id']!, _cycleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LifecycleCheckpointData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LifecycleCheckpointData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cycleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle_id'],
      )!,
      kind: $LifecycleCheckpointsTableTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      observedOn: $LifecycleCheckpointsTableTable.$converterobservedOn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}observed_on'],
        )!,
      ),
    );
  }

  @override
  $LifecycleCheckpointsTableTable createAlias(String alias) {
    return $LifecycleCheckpointsTableTable(attachedDatabase, alias);
  }

  static TypeConverter<LifecycleCheckpointKind, String> $converterkind =
      const LifecycleCheckpointKindConverter();
  static TypeConverter<LocalDate, String> $converterobservedOn =
      const LocalDateConverter();
}

class LifecycleCheckpointData extends DataClass
    implements Insertable<LifecycleCheckpointData> {
  final int id;
  final int cycleId;
  final LifecycleCheckpointKind kind;
  final LocalDate observedOn;
  const LifecycleCheckpointData({
    required this.id,
    required this.cycleId,
    required this.kind,
    required this.observedOn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cycle_id'] = Variable<int>(cycleId);
    {
      map['kind'] = Variable<String>(
        $LifecycleCheckpointsTableTable.$converterkind.toSql(kind),
      );
    }
    {
      map['observed_on'] = Variable<String>(
        $LifecycleCheckpointsTableTable.$converterobservedOn.toSql(observedOn),
      );
    }
    return map;
  }

  LifecycleCheckpointsTableCompanion toCompanion(bool nullToAbsent) {
    return LifecycleCheckpointsTableCompanion(
      id: Value(id),
      cycleId: Value(cycleId),
      kind: Value(kind),
      observedOn: Value(observedOn),
    );
  }

  factory LifecycleCheckpointData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LifecycleCheckpointData(
      id: serializer.fromJson<int>(json['id']),
      cycleId: serializer.fromJson<int>(json['cycleId']),
      kind: serializer.fromJson<LifecycleCheckpointKind>(json['kind']),
      observedOn: serializer.fromJson<LocalDate>(json['observedOn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cycleId': serializer.toJson<int>(cycleId),
      'kind': serializer.toJson<LifecycleCheckpointKind>(kind),
      'observedOn': serializer.toJson<LocalDate>(observedOn),
    };
  }

  LifecycleCheckpointData copyWith({
    int? id,
    int? cycleId,
    LifecycleCheckpointKind? kind,
    LocalDate? observedOn,
  }) => LifecycleCheckpointData(
    id: id ?? this.id,
    cycleId: cycleId ?? this.cycleId,
    kind: kind ?? this.kind,
    observedOn: observedOn ?? this.observedOn,
  );
  LifecycleCheckpointData copyWithCompanion(
    LifecycleCheckpointsTableCompanion data,
  ) {
    return LifecycleCheckpointData(
      id: data.id.present ? data.id.value : this.id,
      cycleId: data.cycleId.present ? data.cycleId.value : this.cycleId,
      kind: data.kind.present ? data.kind.value : this.kind,
      observedOn: data.observedOn.present
          ? data.observedOn.value
          : this.observedOn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LifecycleCheckpointData(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('kind: $kind, ')
          ..write('observedOn: $observedOn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, cycleId, kind, observedOn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LifecycleCheckpointData &&
          other.id == this.id &&
          other.cycleId == this.cycleId &&
          other.kind == this.kind &&
          other.observedOn == this.observedOn);
}

class LifecycleCheckpointsTableCompanion
    extends UpdateCompanion<LifecycleCheckpointData> {
  final Value<int> id;
  final Value<int> cycleId;
  final Value<LifecycleCheckpointKind> kind;
  final Value<LocalDate> observedOn;
  const LifecycleCheckpointsTableCompanion({
    this.id = const Value.absent(),
    this.cycleId = const Value.absent(),
    this.kind = const Value.absent(),
    this.observedOn = const Value.absent(),
  });
  LifecycleCheckpointsTableCompanion.insert({
    this.id = const Value.absent(),
    required int cycleId,
    required LifecycleCheckpointKind kind,
    required LocalDate observedOn,
  }) : cycleId = Value(cycleId),
       kind = Value(kind),
       observedOn = Value(observedOn);
  static Insertable<LifecycleCheckpointData> custom({
    Expression<int>? id,
    Expression<int>? cycleId,
    Expression<String>? kind,
    Expression<String>? observedOn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cycleId != null) 'cycle_id': cycleId,
      if (kind != null) 'kind': kind,
      if (observedOn != null) 'observed_on': observedOn,
    });
  }

  LifecycleCheckpointsTableCompanion copyWith({
    Value<int>? id,
    Value<int>? cycleId,
    Value<LifecycleCheckpointKind>? kind,
    Value<LocalDate>? observedOn,
  }) {
    return LifecycleCheckpointsTableCompanion(
      id: id ?? this.id,
      cycleId: cycleId ?? this.cycleId,
      kind: kind ?? this.kind,
      observedOn: observedOn ?? this.observedOn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cycleId.present) {
      map['cycle_id'] = Variable<int>(cycleId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $LifecycleCheckpointsTableTable.$converterkind.toSql(kind.value),
      );
    }
    if (observedOn.present) {
      map['observed_on'] = Variable<String>(
        $LifecycleCheckpointsTableTable.$converterobservedOn.toSql(
          observedOn.value,
        ),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LifecycleCheckpointsTableCompanion(')
          ..write('id: $id, ')
          ..write('cycleId: $cycleId, ')
          ..write('kind: $kind, ')
          ..write('observedOn: $observedOn')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AreasTableTable areasTable = $AreasTableTable(this);
  late final $ItemsTableTable itemsTable = $ItemsTableTable(this);
  late final $LifecycleCyclesTableTable lifecycleCyclesTable =
      $LifecycleCyclesTableTable(this);
  late final $LifecycleCheckpointsTableTable lifecycleCheckpointsTable =
      $LifecycleCheckpointsTableTable(this);
  late final Index idxAreasNameActive = Index(
    'idx_areas_name_active',
    'CREATE UNIQUE INDEX idx_areas_name_active ON areas (LOWER(name)) WHERE is_archived = 0',
  );
  late final Index idxAreasOrder = Index(
    'idx_areas_order',
    'CREATE INDEX idx_areas_order ON areas (display_order) WHERE is_archived = 0',
  );
  late final Index idxItemsArea = Index(
    'idx_items_area',
    'CREATE INDEX idx_items_area ON items (area_id, is_archived)',
  );
  late final Index idxItemsStatus = Index(
    'idx_items_status',
    'CREATE INDEX idx_items_status ON items (stock_status, is_archived)',
  );
  late final Index idxLifecycleCyclesActive = Index(
    'idx_lifecycle_cycles_active',
    'CREATE UNIQUE INDEX idx_lifecycle_cycles_active ON lifecycle_cycles (item_id) WHERE finished_on IS NULL',
  );
  late final Index idxLifecycleCyclesHistory = Index(
    'idx_lifecycle_cycles_history',
    'CREATE INDEX idx_lifecycle_cycles_history ON lifecycle_cycles (item_id, started_on, id)',
  );
  late final Index idxLifecycleCheckpointsKind = Index(
    'idx_lifecycle_checkpoints_kind',
    'CREATE UNIQUE INDEX idx_lifecycle_checkpoints_kind ON lifecycle_checkpoints (cycle_id, kind)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    areasTable,
    itemsTable,
    lifecycleCyclesTable,
    lifecycleCheckpointsTable,
    idxAreasNameActive,
    idxAreasOrder,
    idxItemsArea,
    idxItemsStatus,
    idxLifecycleCyclesActive,
    idxLifecycleCyclesHistory,
    idxLifecycleCheckpointsKind,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'areas',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lifecycle_cycles', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lifecycle_cycles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lifecycle_checkpoints', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AreasTableTableCreateCompanionBuilder = AreasTableCompanion Function({
  Value<int> id,
  required String name,
  Value<String> iconName,
  Value<int> displayOrder,
  Value<bool> isArchived,
  Value<bool> isSystem,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AreasTableTableUpdateCompanionBuilder = AreasTableCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> iconName,
  Value<int> displayOrder,
  Value<bool> isArchived,
  Value<bool> isSystem,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$AreasTableTableReferences
    extends BaseReferences<_$AppDatabase, $AreasTableTable, AreaData> {
  $$AreasTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemsTableTable, List<ItemData>>
  _itemsTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemsTable,
    aliasName: 'areas__id__items__area_id',
  );

  $$ItemsTableTableProcessedTableManager get itemsTableRefs {
    final manager = $$ItemsTableTableTableManager(
      $_db,
      $_db.itemsTable,
    ).filter((f) => f.areaId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemsTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AreasTableTableFilterComposer
    extends Composer<_$AppDatabase, $AreasTableTable> {
  $$AreasTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemsTableRefs(
    Expression<bool> Function($$ItemsTableTableFilterComposer f) f,
  ) {
    final $$ItemsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemsTable,
      getReferencedColumn: (t) => t.areaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableTableFilterComposer(
            $db: $db,
            $table: $db.itemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AreasTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AreasTableTable> {
  $$AreasTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AreasTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AreasTableTable> {
  $$AreasTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get displayOrder => $composableBuilder(
    column: $table.displayOrder,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> itemsTableRefs<T extends Object>(
    Expression<T> Function($$ItemsTableTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemsTable,
      getReferencedColumn: (t) => t.areaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.itemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AreasTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AreasTableTable,
          AreaData,
          $$AreasTableTableFilterComposer,
          $$AreasTableTableOrderingComposer,
          $$AreasTableTableAnnotationComposer,
          $$AreasTableTableCreateCompanionBuilder,
          $$AreasTableTableUpdateCompanionBuilder,
          (AreaData, $$AreasTableTableReferences),
          AreaData,
          PrefetchHooks Function({bool itemsTableRefs})
        > {
  $$AreasTableTableTableManager(_$AppDatabase db, $AreasTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AreasTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AreasTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AreasTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AreasTableCompanion(
                id: id,
                name: name,
                iconName: iconName,
                displayOrder: displayOrder,
                isArchived: isArchived,
                isSystem: isSystem,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> iconName = const Value.absent(),
                Value<int> displayOrder = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AreasTableCompanion.insert(
                id: id,
                name: name,
                iconName: iconName,
                displayOrder: displayOrder,
                isArchived: isArchived,
                isSystem: isSystem,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AreasTableTable, AreaData>(table),
                  $$AreasTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemsTableRefs) db.itemsTable],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemsTableRefs)
                    await $_getPrefetchedData<
                      AreaData,
                      $AreasTableTable,
                      ItemData
                    >(
                      currentTable: table,
                      referencedTable: $$AreasTableTableReferences
                          ._itemsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AreasTableTableReferences(
                            db,
                            table,
                            p0,
                          ).itemsTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.areaId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AreasTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AreasTableTable,
      AreaData,
      $$AreasTableTableFilterComposer,
      $$AreasTableTableOrderingComposer,
      $$AreasTableTableAnnotationComposer,
      $$AreasTableTableCreateCompanionBuilder,
      $$AreasTableTableUpdateCompanionBuilder,
      (AreaData, $$AreasTableTableReferences),
      AreaData,
      PrefetchHooks Function({bool itemsTableRefs})
    >;
typedef $$ItemsTableTableCreateCompanionBuilder = ItemsTableCompanion Function({
  Value<int> id,
  required int areaId,
  required String name,
  required BehaviorProfile behaviorProfile,
  required StockStatus stockStatus,
  Value<String?> unit,
  Value<int?> packageCount,
  Value<bool> isArchived,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$ItemsTableTableUpdateCompanionBuilder = ItemsTableCompanion Function({
  Value<int> id,
  Value<int> areaId,
  Value<String> name,
  Value<BehaviorProfile> behaviorProfile,
  Value<StockStatus> stockStatus,
  Value<String?> unit,
  Value<int?> packageCount,
  Value<bool> isArchived,
  Value<String?> notes,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$ItemsTableTableReferences
    extends BaseReferences<_$AppDatabase, $ItemsTableTable, ItemData> {
  $$ItemsTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AreasTableTable _areaIdTable(_$AppDatabase db) =>
      db.areasTable.createAlias('items__area_id__areas__id');

  $$AreasTableTableProcessedTableManager get areaId {
    final $_column = $_itemColumn<int>('area_id')!;

    final manager = $$AreasTableTableTableManager(
      $_db,
      $_db.areasTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_areaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $LifecycleCyclesTableTable,
    List<LifecycleCycleData>
  >
  _lifecycleCyclesTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.lifecycleCyclesTable,
        aliasName: 'items__id__lifecycle_cycles__item_id',
      );

  $$LifecycleCyclesTableTableProcessedTableManager
  get lifecycleCyclesTableRefs {
    final manager = $$LifecycleCyclesTableTableTableManager(
      $_db,
      $_db.lifecycleCyclesTable,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _lifecycleCyclesTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ItemsTableTable> {
  $$ItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BehaviorProfile, BehaviorProfile, String>
  get behaviorProfile => $composableBuilder(
    column: $table.behaviorProfile,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<StockStatus, StockStatus, String>
  get stockStatus => $composableBuilder(
    column: $table.stockStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get packageCount => $composableBuilder(
    column: $table.packageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AreasTableTableFilterComposer get areaId {
    final $$AreasTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.areaId,
      referencedTable: $db.areasTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AreasTableTableFilterComposer(
            $db: $db,
            $table: $db.areasTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> lifecycleCyclesTableRefs(
    Expression<bool> Function($$LifecycleCyclesTableTableFilterComposer f) f,
  ) {
    final $$LifecycleCyclesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lifecycleCyclesTable,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LifecycleCyclesTableTableFilterComposer(
            $db: $db,
            $table: $db.lifecycleCyclesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTableTable> {
  $$ItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get behaviorProfile => $composableBuilder(
    column: $table.behaviorProfile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stockStatus => $composableBuilder(
    column: $table.stockStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get packageCount => $composableBuilder(
    column: $table.packageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AreasTableTableOrderingComposer get areaId {
    final $$AreasTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.areaId,
      referencedTable: $db.areasTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AreasTableTableOrderingComposer(
            $db: $db,
            $table: $db.areasTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTableTable> {
  $$ItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BehaviorProfile, String>
  get behaviorProfile => $composableBuilder(
    column: $table.behaviorProfile,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<StockStatus, String> get stockStatus =>
      $composableBuilder(
        column: $table.stockStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get packageCount => $composableBuilder(
    column: $table.packageCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$AreasTableTableAnnotationComposer get areaId {
    final $$AreasTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.areaId,
      referencedTable: $db.areasTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AreasTableTableAnnotationComposer(
            $db: $db,
            $table: $db.areasTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> lifecycleCyclesTableRefs<T extends Object>(
    Expression<T> Function($$LifecycleCyclesTableTableAnnotationComposer a) f,
  ) {
    final $$LifecycleCyclesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.lifecycleCyclesTable,
          getReferencedColumn: (t) => t.itemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LifecycleCyclesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.lifecycleCyclesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ItemsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTableTable,
          ItemData,
          $$ItemsTableTableFilterComposer,
          $$ItemsTableTableOrderingComposer,
          $$ItemsTableTableAnnotationComposer,
          $$ItemsTableTableCreateCompanionBuilder,
          $$ItemsTableTableUpdateCompanionBuilder,
          (ItemData, $$ItemsTableTableReferences),
          ItemData,
          PrefetchHooks Function({bool areaId, bool lifecycleCyclesTableRefs})
        > {
  $$ItemsTableTableTableManager(_$AppDatabase db, $ItemsTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> areaId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<BehaviorProfile> behaviorProfile = const Value.absent(),
                Value<StockStatus> stockStatus = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<int?> packageCount = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ItemsTableCompanion(
                id: id,
                areaId: areaId,
                name: name,
                behaviorProfile: behaviorProfile,
                stockStatus: stockStatus,
                unit: unit,
                packageCount: packageCount,
                isArchived: isArchived,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int areaId,
                required String name,
                required BehaviorProfile behaviorProfile,
                required StockStatus stockStatus,
                Value<String?> unit = const Value.absent(),
                Value<int?> packageCount = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ItemsTableCompanion.insert(
                id: id,
                areaId: areaId,
                name: name,
                behaviorProfile: behaviorProfile,
                stockStatus: stockStatus,
                unit: unit,
                packageCount: packageCount,
                isArchived: isArchived,
                notes: notes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ItemsTableTable, ItemData>(table),
                  $$ItemsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({areaId = false, lifecycleCyclesTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (lifecycleCyclesTableRefs) db.lifecycleCyclesTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (areaId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.areaId,
                            referencedTable: $$ItemsTableTableReferences
                                ._areaIdTable(db),
                            referencedColumn: $$ItemsTableTableReferences
                                ._areaIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (lifecycleCyclesTableRefs)
                        await $_getPrefetchedData<
                          ItemData,
                          $ItemsTableTable,
                          LifecycleCycleData
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableTableReferences
                              ._lifecycleCyclesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableTableReferences(
                                db,
                                table,
                                p0,
                              ).lifecycleCyclesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ItemsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTableTable,
      ItemData,
      $$ItemsTableTableFilterComposer,
      $$ItemsTableTableOrderingComposer,
      $$ItemsTableTableAnnotationComposer,
      $$ItemsTableTableCreateCompanionBuilder,
      $$ItemsTableTableUpdateCompanionBuilder,
      (ItemData, $$ItemsTableTableReferences),
      ItemData,
      PrefetchHooks Function({bool areaId, bool lifecycleCyclesTableRefs})
    >;
typedef $$LifecycleCyclesTableTableCreateCompanionBuilder =
    LifecycleCyclesTableCompanion Function({
      Value<int> id,
      required int itemId,
      required LocalDate startedOn,
      Value<LocalDate?> finishedOn,
    });
typedef $$LifecycleCyclesTableTableUpdateCompanionBuilder =
    LifecycleCyclesTableCompanion Function({
      Value<int> id,
      Value<int> itemId,
      Value<LocalDate> startedOn,
      Value<LocalDate?> finishedOn,
    });

final class $$LifecycleCyclesTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LifecycleCyclesTableTable,
          LifecycleCycleData
        > {
  $$LifecycleCyclesTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ItemsTableTable _itemIdTable(_$AppDatabase db) =>
      db.itemsTable.createAlias('lifecycle_cycles__item_id__items__id');

  $$ItemsTableTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<int>('item_id')!;

    final manager = $$ItemsTableTableTableManager(
      $_db,
      $_db.itemsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $LifecycleCheckpointsTableTable,
    List<LifecycleCheckpointData>
  >
  _lifecycleCheckpointsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.lifecycleCheckpointsTable,
        aliasName: 'lifecycle_cycles__id__lifecycle_checkpoints__cycle_id',
      );

  $$LifecycleCheckpointsTableTableProcessedTableManager
  get lifecycleCheckpointsTableRefs {
    final manager = $$LifecycleCheckpointsTableTableTableManager(
      $_db,
      $_db.lifecycleCheckpointsTable,
    ).filter((f) => f.cycleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _lifecycleCheckpointsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LifecycleCyclesTableTableFilterComposer
    extends Composer<_$AppDatabase, $LifecycleCyclesTableTable> {
  $$LifecycleCyclesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get startedOn =>
      $composableBuilder(
        column: $table.startedOn,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<LocalDate?, LocalDate, String>
  get finishedOn => $composableBuilder(
    column: $table.finishedOn,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  $$ItemsTableTableFilterComposer get itemId {
    final $$ItemsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.itemsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableTableFilterComposer(
            $db: $db,
            $table: $db.itemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> lifecycleCheckpointsTableRefs(
    Expression<bool> Function($$LifecycleCheckpointsTableTableFilterComposer f)
    f,
  ) {
    final $$LifecycleCheckpointsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.lifecycleCheckpointsTable,
          getReferencedColumn: (t) => t.cycleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LifecycleCheckpointsTableTableFilterComposer(
                $db: $db,
                $table: $db.lifecycleCheckpointsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LifecycleCyclesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LifecycleCyclesTableTable> {
  $$LifecycleCyclesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedOn => $composableBuilder(
    column: $table.startedOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finishedOn => $composableBuilder(
    column: $table.finishedOn,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableTableOrderingComposer get itemId {
    final $$ItemsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.itemsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableTableOrderingComposer(
            $db: $db,
            $table: $db.itemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LifecycleCyclesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LifecycleCyclesTableTable> {
  $$LifecycleCyclesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get startedOn =>
      $composableBuilder(column: $table.startedOn, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate?, String> get finishedOn =>
      $composableBuilder(
        column: $table.finishedOn,
        builder: (column) => column,
      );

  $$ItemsTableTableAnnotationComposer get itemId {
    final $$ItemsTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.itemsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableTableAnnotationComposer(
            $db: $db,
            $table: $db.itemsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> lifecycleCheckpointsTableRefs<T extends Object>(
    Expression<T> Function($$LifecycleCheckpointsTableTableAnnotationComposer a)
    f,
  ) {
    final $$LifecycleCheckpointsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.lifecycleCheckpointsTable,
          getReferencedColumn: (t) => t.cycleId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LifecycleCheckpointsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.lifecycleCheckpointsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$LifecycleCyclesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LifecycleCyclesTableTable,
          LifecycleCycleData,
          $$LifecycleCyclesTableTableFilterComposer,
          $$LifecycleCyclesTableTableOrderingComposer,
          $$LifecycleCyclesTableTableAnnotationComposer,
          $$LifecycleCyclesTableTableCreateCompanionBuilder,
          $$LifecycleCyclesTableTableUpdateCompanionBuilder,
          (LifecycleCycleData, $$LifecycleCyclesTableTableReferences),
          LifecycleCycleData,
          PrefetchHooks Function({
            bool itemId,
            bool lifecycleCheckpointsTableRefs,
          })
        > {
  $$LifecycleCyclesTableTableTableManager(
    _$AppDatabase db,
    $LifecycleCyclesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LifecycleCyclesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LifecycleCyclesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LifecycleCyclesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> itemId = const Value.absent(),
                Value<LocalDate> startedOn = const Value.absent(),
                Value<LocalDate?> finishedOn = const Value.absent(),
              }) => LifecycleCyclesTableCompanion(
                id: id,
                itemId: itemId,
                startedOn: startedOn,
                finishedOn: finishedOn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int itemId,
                required LocalDate startedOn,
                Value<LocalDate?> finishedOn = const Value.absent(),
              }) => LifecycleCyclesTableCompanion.insert(
                id: id,
                itemId: itemId,
                startedOn: startedOn,
                finishedOn: finishedOn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LifecycleCyclesTableTable, LifecycleCycleData>(
                    table,
                  ),
                  $$LifecycleCyclesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({itemId = false, lifecycleCheckpointsTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (lifecycleCheckpointsTableRefs)
                      db.lifecycleCheckpointsTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (itemId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.itemId,
                            referencedTable:
                                $$LifecycleCyclesTableTableReferences
                                    ._itemIdTable(db),
                            referencedColumn:
                                $$LifecycleCyclesTableTableReferences
                                    ._itemIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (lifecycleCheckpointsTableRefs)
                        await $_getPrefetchedData<
                          LifecycleCycleData,
                          $LifecycleCyclesTableTable,
                          LifecycleCheckpointData
                        >(
                          currentTable: table,
                          referencedTable: $$LifecycleCyclesTableTableReferences
                              ._lifecycleCheckpointsTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LifecycleCyclesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).lifecycleCheckpointsTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cycleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LifecycleCyclesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LifecycleCyclesTableTable,
      LifecycleCycleData,
      $$LifecycleCyclesTableTableFilterComposer,
      $$LifecycleCyclesTableTableOrderingComposer,
      $$LifecycleCyclesTableTableAnnotationComposer,
      $$LifecycleCyclesTableTableCreateCompanionBuilder,
      $$LifecycleCyclesTableTableUpdateCompanionBuilder,
      (LifecycleCycleData, $$LifecycleCyclesTableTableReferences),
      LifecycleCycleData,
      PrefetchHooks Function({bool itemId, bool lifecycleCheckpointsTableRefs})
    >;
typedef $$LifecycleCheckpointsTableTableCreateCompanionBuilder =
    LifecycleCheckpointsTableCompanion Function({
      Value<int> id,
      required int cycleId,
      required LifecycleCheckpointKind kind,
      required LocalDate observedOn,
    });
typedef $$LifecycleCheckpointsTableTableUpdateCompanionBuilder =
    LifecycleCheckpointsTableCompanion Function({
      Value<int> id,
      Value<int> cycleId,
      Value<LifecycleCheckpointKind> kind,
      Value<LocalDate> observedOn,
    });

final class $$LifecycleCheckpointsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LifecycleCheckpointsTableTable,
          LifecycleCheckpointData
        > {
  $$LifecycleCheckpointsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $LifecycleCyclesTableTable _cycleIdTable(_$AppDatabase db) => db
      .lifecycleCyclesTable
      .createAlias('lifecycle_checkpoints__cycle_id__lifecycle_cycles__id');

  $$LifecycleCyclesTableTableProcessedTableManager get cycleId {
    final $_column = $_itemColumn<int>('cycle_id')!;

    final manager = $$LifecycleCyclesTableTableTableManager(
      $_db,
      $_db.lifecycleCyclesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cycleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LifecycleCheckpointsTableTableFilterComposer
    extends Composer<_$AppDatabase, $LifecycleCheckpointsTableTable> {
  $$LifecycleCheckpointsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    LifecycleCheckpointKind,
    LifecycleCheckpointKind,
    String
  >
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<LocalDate, LocalDate, String> get observedOn =>
      $composableBuilder(
        column: $table.observedOn,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$LifecycleCyclesTableTableFilterComposer get cycleId {
    final $$LifecycleCyclesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cycleId,
      referencedTable: $db.lifecycleCyclesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LifecycleCyclesTableTableFilterComposer(
            $db: $db,
            $table: $db.lifecycleCyclesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LifecycleCheckpointsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LifecycleCheckpointsTableTable> {
  $$LifecycleCheckpointsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observedOn => $composableBuilder(
    column: $table.observedOn,
    builder: (column) => ColumnOrderings(column),
  );

  $$LifecycleCyclesTableTableOrderingComposer get cycleId {
    final $$LifecycleCyclesTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cycleId,
          referencedTable: $db.lifecycleCyclesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LifecycleCyclesTableTableOrderingComposer(
                $db: $db,
                $table: $db.lifecycleCyclesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LifecycleCheckpointsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LifecycleCheckpointsTableTable> {
  $$LifecycleCheckpointsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LifecycleCheckpointKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocalDate, String> get observedOn =>
      $composableBuilder(
        column: $table.observedOn,
        builder: (column) => column,
      );

  $$LifecycleCyclesTableTableAnnotationComposer get cycleId {
    final $$LifecycleCyclesTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cycleId,
          referencedTable: $db.lifecycleCyclesTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LifecycleCyclesTableTableAnnotationComposer(
                $db: $db,
                $table: $db.lifecycleCyclesTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$LifecycleCheckpointsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LifecycleCheckpointsTableTable,
          LifecycleCheckpointData,
          $$LifecycleCheckpointsTableTableFilterComposer,
          $$LifecycleCheckpointsTableTableOrderingComposer,
          $$LifecycleCheckpointsTableTableAnnotationComposer,
          $$LifecycleCheckpointsTableTableCreateCompanionBuilder,
          $$LifecycleCheckpointsTableTableUpdateCompanionBuilder,
          (LifecycleCheckpointData, $$LifecycleCheckpointsTableTableReferences),
          LifecycleCheckpointData,
          PrefetchHooks Function({bool cycleId})
        > {
  $$LifecycleCheckpointsTableTableTableManager(
    _$AppDatabase db,
    $LifecycleCheckpointsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LifecycleCheckpointsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LifecycleCheckpointsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LifecycleCheckpointsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cycleId = const Value.absent(),
                Value<LifecycleCheckpointKind> kind = const Value.absent(),
                Value<LocalDate> observedOn = const Value.absent(),
              }) => LifecycleCheckpointsTableCompanion(
                id: id,
                cycleId: cycleId,
                kind: kind,
                observedOn: observedOn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cycleId,
                required LifecycleCheckpointKind kind,
                required LocalDate observedOn,
              }) => LifecycleCheckpointsTableCompanion.insert(
                id: id,
                cycleId: cycleId,
                kind: kind,
                observedOn: observedOn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LifecycleCheckpointsTableTable,
                    LifecycleCheckpointData
                  >(table),
                  $$LifecycleCheckpointsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cycleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cycleId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cycleId,
                        referencedTable:
                            $$LifecycleCheckpointsTableTableReferences
                                ._cycleIdTable(db),
                        referencedColumn:
                            $$LifecycleCheckpointsTableTableReferences
                                ._cycleIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LifecycleCheckpointsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LifecycleCheckpointsTableTable,
      LifecycleCheckpointData,
      $$LifecycleCheckpointsTableTableFilterComposer,
      $$LifecycleCheckpointsTableTableOrderingComposer,
      $$LifecycleCheckpointsTableTableAnnotationComposer,
      $$LifecycleCheckpointsTableTableCreateCompanionBuilder,
      $$LifecycleCheckpointsTableTableUpdateCompanionBuilder,
      (LifecycleCheckpointData, $$LifecycleCheckpointsTableTableReferences),
      LifecycleCheckpointData,
      PrefetchHooks Function({bool cycleId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AreasTableTableTableManager get areasTable =>
      $$AreasTableTableTableManager(_db, _db.areasTable);
  $$ItemsTableTableTableManager get itemsTable =>
      $$ItemsTableTableTableManager(_db, _db.itemsTable);
  $$LifecycleCyclesTableTableTableManager get lifecycleCyclesTable =>
      $$LifecycleCyclesTableTableTableManager(_db, _db.lifecycleCyclesTable);
  $$LifecycleCheckpointsTableTableTableManager get lifecycleCheckpointsTable =>
      $$LifecycleCheckpointsTableTableTableManager(
        _db,
        _db.lifecycleCheckpointsTable,
      );
}
