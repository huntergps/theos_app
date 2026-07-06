// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'generic_drift_operations_upsert_test.dart';

// ignore_for_file: type=lint
class $FakeThingsTable extends FakeThings
    with TableInfo<$FakeThingsTable, FakeThingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FakeThingsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _odooIdMeta = const VerificationMeta('odooId');
  @override
  late final GeneratedColumn<int> odooId = GeneratedColumn<int>(
    'odoo_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _lineUuidMeta = const VerificationMeta(
    'lineUuid',
  );
  @override
  late final GeneratedColumn<String> lineUuid = GeneratedColumn<String>(
    'line_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, odooId, lineUuid, name, price];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fake_things';
  @override
  VerificationContext validateIntegrity(
    Insertable<FakeThingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('odoo_id')) {
      context.handle(
        _odooIdMeta,
        odooId.isAcceptableOrUnknown(data['odoo_id']!, _odooIdMeta),
      );
    }
    if (data.containsKey('line_uuid')) {
      context.handle(
        _lineUuidMeta,
        lineUuid.isAcceptableOrUnknown(data['line_uuid']!, _lineUuidMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FakeThingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FakeThingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      odooId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}odoo_id'],
      ),
      lineUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_uuid'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price'],
      )!,
    );
  }

  @override
  $FakeThingsTable createAlias(String alias) {
    return $FakeThingsTable(attachedDatabase, alias);
  }
}

class FakeThingRow extends DataClass implements Insertable<FakeThingRow> {
  final int id;
  final int? odooId;
  final String? lineUuid;
  final String name;
  final double price;
  const FakeThingRow({
    required this.id,
    this.odooId,
    this.lineUuid,
    required this.name,
    required this.price,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || odooId != null) {
      map['odoo_id'] = Variable<int>(odooId);
    }
    if (!nullToAbsent || lineUuid != null) {
      map['line_uuid'] = Variable<String>(lineUuid);
    }
    map['name'] = Variable<String>(name);
    map['price'] = Variable<double>(price);
    return map;
  }

  FakeThingsCompanion toCompanion(bool nullToAbsent) {
    return FakeThingsCompanion(
      id: Value(id),
      odooId: odooId == null && nullToAbsent
          ? const Value.absent()
          : Value(odooId),
      lineUuid: lineUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(lineUuid),
      name: Value(name),
      price: Value(price),
    );
  }

  factory FakeThingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FakeThingRow(
      id: serializer.fromJson<int>(json['id']),
      odooId: serializer.fromJson<int?>(json['odooId']),
      lineUuid: serializer.fromJson<String?>(json['lineUuid']),
      name: serializer.fromJson<String>(json['name']),
      price: serializer.fromJson<double>(json['price']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'odooId': serializer.toJson<int?>(odooId),
      'lineUuid': serializer.toJson<String?>(lineUuid),
      'name': serializer.toJson<String>(name),
      'price': serializer.toJson<double>(price),
    };
  }

  FakeThingRow copyWith({
    int? id,
    Value<int?> odooId = const Value.absent(),
    Value<String?> lineUuid = const Value.absent(),
    String? name,
    double? price,
  }) => FakeThingRow(
    id: id ?? this.id,
    odooId: odooId.present ? odooId.value : this.odooId,
    lineUuid: lineUuid.present ? lineUuid.value : this.lineUuid,
    name: name ?? this.name,
    price: price ?? this.price,
  );
  FakeThingRow copyWithCompanion(FakeThingsCompanion data) {
    return FakeThingRow(
      id: data.id.present ? data.id.value : this.id,
      odooId: data.odooId.present ? data.odooId.value : this.odooId,
      lineUuid: data.lineUuid.present ? data.lineUuid.value : this.lineUuid,
      name: data.name.present ? data.name.value : this.name,
      price: data.price.present ? data.price.value : this.price,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FakeThingRow(')
          ..write('id: $id, ')
          ..write('odooId: $odooId, ')
          ..write('lineUuid: $lineUuid, ')
          ..write('name: $name, ')
          ..write('price: $price')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, odooId, lineUuid, name, price);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FakeThingRow &&
          other.id == this.id &&
          other.odooId == this.odooId &&
          other.lineUuid == this.lineUuid &&
          other.name == this.name &&
          other.price == this.price);
}

class FakeThingsCompanion extends UpdateCompanion<FakeThingRow> {
  final Value<int> id;
  final Value<int?> odooId;
  final Value<String?> lineUuid;
  final Value<String> name;
  final Value<double> price;
  const FakeThingsCompanion({
    this.id = const Value.absent(),
    this.odooId = const Value.absent(),
    this.lineUuid = const Value.absent(),
    this.name = const Value.absent(),
    this.price = const Value.absent(),
  });
  FakeThingsCompanion.insert({
    this.id = const Value.absent(),
    this.odooId = const Value.absent(),
    this.lineUuid = const Value.absent(),
    required String name,
    this.price = const Value.absent(),
  }) : name = Value(name);
  static Insertable<FakeThingRow> custom({
    Expression<int>? id,
    Expression<int>? odooId,
    Expression<String>? lineUuid,
    Expression<String>? name,
    Expression<double>? price,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (odooId != null) 'odoo_id': odooId,
      if (lineUuid != null) 'line_uuid': lineUuid,
      if (name != null) 'name': name,
      if (price != null) 'price': price,
    });
  }

  FakeThingsCompanion copyWith({
    Value<int>? id,
    Value<int?>? odooId,
    Value<String?>? lineUuid,
    Value<String>? name,
    Value<double>? price,
  }) {
    return FakeThingsCompanion(
      id: id ?? this.id,
      odooId: odooId ?? this.odooId,
      lineUuid: lineUuid ?? this.lineUuid,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (odooId.present) {
      map['odoo_id'] = Variable<int>(odooId.value);
    }
    if (lineUuid.present) {
      map['line_uuid'] = Variable<String>(lineUuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FakeThingsCompanion(')
          ..write('id: $id, ')
          ..write('odooId: $odooId, ')
          ..write('lineUuid: $lineUuid, ')
          ..write('name: $name, ')
          ..write('price: $price')
          ..write(')'))
        .toString();
  }
}

abstract class _$FakeThingsDb extends GeneratedDatabase {
  _$FakeThingsDb(QueryExecutor e) : super(e);
  $FakeThingsDbManager get managers => $FakeThingsDbManager(this);
  late final $FakeThingsTable fakeThings = $FakeThingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [fakeThings];
}

typedef $$FakeThingsTableCreateCompanionBuilder =
    FakeThingsCompanion Function({
      Value<int> id,
      Value<int?> odooId,
      Value<String?> lineUuid,
      required String name,
      Value<double> price,
    });
typedef $$FakeThingsTableUpdateCompanionBuilder =
    FakeThingsCompanion Function({
      Value<int> id,
      Value<int?> odooId,
      Value<String?> lineUuid,
      Value<String> name,
      Value<double> price,
    });

class $$FakeThingsTableFilterComposer
    extends Composer<_$FakeThingsDb, $FakeThingsTable> {
  $$FakeThingsTableFilterComposer({
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

  ColumnFilters<int> get odooId => $composableBuilder(
    column: $table.odooId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineUuid => $composableBuilder(
    column: $table.lineUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FakeThingsTableOrderingComposer
    extends Composer<_$FakeThingsDb, $FakeThingsTable> {
  $$FakeThingsTableOrderingComposer({
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

  ColumnOrderings<int> get odooId => $composableBuilder(
    column: $table.odooId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineUuid => $composableBuilder(
    column: $table.lineUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FakeThingsTableAnnotationComposer
    extends Composer<_$FakeThingsDb, $FakeThingsTable> {
  $$FakeThingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get odooId =>
      $composableBuilder(column: $table.odooId, builder: (column) => column);

  GeneratedColumn<String> get lineUuid =>
      $composableBuilder(column: $table.lineUuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);
}

class $$FakeThingsTableTableManager
    extends
        RootTableManager<
          _$FakeThingsDb,
          $FakeThingsTable,
          FakeThingRow,
          $$FakeThingsTableFilterComposer,
          $$FakeThingsTableOrderingComposer,
          $$FakeThingsTableAnnotationComposer,
          $$FakeThingsTableCreateCompanionBuilder,
          $$FakeThingsTableUpdateCompanionBuilder,
          (
            FakeThingRow,
            BaseReferences<_$FakeThingsDb, $FakeThingsTable, FakeThingRow>,
          ),
          FakeThingRow,
          PrefetchHooks Function()
        > {
  $$FakeThingsTableTableManager(_$FakeThingsDb db, $FakeThingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FakeThingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FakeThingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FakeThingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> odooId = const Value.absent(),
                Value<String?> lineUuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> price = const Value.absent(),
              }) => FakeThingsCompanion(
                id: id,
                odooId: odooId,
                lineUuid: lineUuid,
                name: name,
                price: price,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> odooId = const Value.absent(),
                Value<String?> lineUuid = const Value.absent(),
                required String name,
                Value<double> price = const Value.absent(),
              }) => FakeThingsCompanion.insert(
                id: id,
                odooId: odooId,
                lineUuid: lineUuid,
                name: name,
                price: price,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FakeThingsTableProcessedTableManager =
    ProcessedTableManager<
      _$FakeThingsDb,
      $FakeThingsTable,
      FakeThingRow,
      $$FakeThingsTableFilterComposer,
      $$FakeThingsTableOrderingComposer,
      $$FakeThingsTableAnnotationComposer,
      $$FakeThingsTableCreateCompanionBuilder,
      $$FakeThingsTableUpdateCompanionBuilder,
      (
        FakeThingRow,
        BaseReferences<_$FakeThingsDb, $FakeThingsTable, FakeThingRow>,
      ),
      FakeThingRow,
      PrefetchHooks Function()
    >;

class $FakeThingsDbManager {
  final _$FakeThingsDb _db;
  $FakeThingsDbManager(this._db);
  $$FakeThingsTableTableManager get fakeThings =>
      $$FakeThingsTableTableManager(_db, _db.fakeThings);
}
