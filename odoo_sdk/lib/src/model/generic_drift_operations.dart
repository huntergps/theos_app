/// Generic Drift Operations Mixin
///
/// Provides generic implementations of OdooModelManager's abstract database
/// methods using Drift and dynamic typing. This eliminates the need to write
/// repetitive CRUD code in each manager.
///
/// ## Usage:
/// ```dart
/// class ProductManager extends OdooModelManager<Product>
///     with GenericDriftOperations<Product> {
///   final AppDatabase _db;
///
///   ProductManager(this._db);
///
///   @override
///   GeneratedDatabase get database => _db;
///
///   @override
///   TableInfo get table => _db.productProduct;
///
///   @override
///   dynamic createDriftCompanion(Product record) => record.toCompanion();
///
///   // ... model-specific methods only
/// }
/// ```
library;

import 'package:drift/drift.dart' as drift;

import 'odoo_model_manager.dart';

/// Mixin providing generic Drift-based implementations for OdooModelManager.
///
/// This mixin uses dynamic typing to work with any Drift table that has
/// standard columns (odooId, writeDate, etc.). While not as type-safe as
/// manual implementations, it significantly reduces boilerplate code.
mixin GenericDriftOperations<T> on OdooModelManager<T> {
  /// Database instance - must be provided by the implementing class.
  drift.GeneratedDatabase get database;

  /// Table accessor - must be provided by the implementing class.
  /// The table must have odooId and writeDate columns.
  drift.TableInfo get table;

  /// Default ordering for queries.
  List<drift.OrderingTerm Function(dynamic)> get defaultOrdering => [];

  /// Create a Drift companion from a record.
  /// Must be implemented by subclasses.
  dynamic createDriftCompanion(T record);

  /// Resolve the table by name from the database.
  ///
  /// Looks up the table using [OdooModelManager.tableName] against
  /// all tables registered in the database.
  drift.TableInfo? resolveTable() {
    final dbInstance = db;
    if (dbInstance == null) return null;
    for (final tbl in dbInstance.allTables) {
      if (tbl.actualTableName == tableName) {
        return tbl;
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OVERRIDE ABSTRACT METHODS WITH GENERIC IMPLEMENTATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Future<T?> readLocal(int id) async {
    final tbl = table;
    final query = database.select(tbl);

    final result = await (query
          ..where((tbl) {
            final column = (tbl as dynamic).odooId as drift.GeneratedColumn<int>;
            return column.equals(id);
          }))
        .getSingleOrNull();

    return result != null ? fromDrift(result) : null;
  }

  @override
  Future<List<T>> searchLocal({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  }) async {
    var query = database.select(table);

    if (domain != null) {
      query = applyDomainFilters(query, domain);
    }

    final ordering = orderBy != null ? parseOrderBy(orderBy) : defaultOrdering;
    if (ordering.isNotEmpty) {
      query = query..orderBy(ordering);
    }

    if (limit != null) {
      query = query..limit(limit, offset: offset ?? 0);
    }

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  @override
  Future<int> countLocal({List<dynamic>? domain}) async {
    var query = database.select(table);

    if (domain != null) {
      query = applyDomainFilters(query, domain);
    }

    final result = await query.get();
    return result.length;
  }

  @override
  Future<void> upsertLocal(T record) async {
    final companion = createDriftCompanion(record);
    final tbl = table;

    // The generated createDriftCompanion() returns RawValuesInsertable<dynamic>
    // whose column keys may not match the Drift table's actual column names.
    // We remap keys using the table's $columns metadata, then run raw SQL.
    final rawColumns = (companion as drift.Insertable).toColumns(false);
    final tblName = tbl.actualTableName;

    // Build a map of model-key → real SQL column name using Drift's $columns
    final driftColumns = tbl.$columns;
    final keyToSqlName = <String, String>{};
    for (final col in driftColumns) {
      keyToSqlName[col.$name] = col.$name;
    }

    // Filter only columns that exist in the actual table
    final validEntries = <String, Object?>{};
    for (final entry in rawColumns.entries) {
      if (keyToSqlName.containsKey(entry.key)) {
        final expr = entry.value;
        final rawValue = expr is drift.Variable ? expr.value : null;
        validEntries[entry.key] = _toSqliteValue(rawValue);
      }
    }

    if (validEntries.isEmpty) return;

    final colNames = validEntries.keys.toList();
    final placeholders = List.filled(colNames.length, '?').join(', ');
    final updateSet =
        colNames.map((c) => '"$c" = excluded."$c"').join(', ');
    final values = colNames.map((c) => validEntries[c]).toList();

    final sql =
        'INSERT INTO "$tblName" (${colNames.map((c) => '"$c"').join(', ')}) '
        'VALUES ($placeholders) '
        'ON CONFLICT ("odoo_id") DO UPDATE SET $updateSet';

    await database.customStatement(sql, values);
    database.markTablesUpdated({tbl});
  }

  /// Batch upsert for efficient multi-record writes.
  Future<void> upsertLocalBatch(List<T> records) async {
    if (records.isEmpty) return;

    final tbl = table;
    final tblName = tbl.actualTableName;

    // Pre-compute valid column names from table schema
    final validColNames = <String>{};
    for (final col in tbl.$columns) {
      validColNames.add(col.$name);
    }

    await database.batch((batch) {
      for (final record in records) {
        final companion = createDriftCompanion(record);
        final rawColumns = (companion as drift.Insertable).toColumns(false);

        // Filter only columns that exist in the actual table
        final validEntries = <String, Object?>{};
        for (final entry in rawColumns.entries) {
          if (validColNames.contains(entry.key)) {
            final expr = entry.value;
            final rawValue = expr is drift.Variable ? expr.value : null;
            validEntries[entry.key] = _toSqliteValue(rawValue);
          }
        }

        if (validEntries.isEmpty) continue;

        final colNames = validEntries.keys.toList();
        final placeholders = List.filled(colNames.length, '?').join(', ');
        final updateSet =
            colNames.map((c) => '"$c" = excluded."$c"').join(', ');
        final values = colNames.map((c) => validEntries[c]).toList();

        final sql =
            'INSERT INTO "$tblName" (${colNames.map((c) => '"$c"').join(', ')}) '
            'VALUES ($placeholders) '
            'ON CONFLICT ("odoo_id") DO UPDATE SET $updateSet';

        batch.customStatement(
            sql, values, [drift.TableUpdate.onTable(tbl)]);
      }
    });
  }

  @override
  Future<void> deleteLocal(int id) async {
    final tbl = table;
    await (database.delete(tbl)
          ..where((t) {
            final column = (t as dynamic).odooId as drift.GeneratedColumn<int>;
            return column.equals(id);
          }))
        .go();
  }

  /// Delete all records from the local table.
  Future<void> deleteAllLocal() async {
    await database.delete(table).go();
  }

  /// Batch read for efficient multi-record retrieval.
  Future<List<T>> readLocalBatch(List<int> ids) async {
    if (ids.isEmpty) return [];
    final tbl = table;
    final query = database.select(tbl)
      ..where((t) {
        final column = (t as dynamic).odooId as drift.GeneratedColumn<int>;
        return column.isIn(ids);
      });
    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  @override
  Future<T?> readLocalByUuid(String uuid) async {
    final tbl = table;
    try {
      final query = database.select(tbl);
      final result = await (query
            ..where((tbl) {
              final column =
                  (tbl as dynamic).uuid as drift.GeneratedColumn<String>;
              return column.equals(uuid);
            }))
          .getSingleOrNull();
      return result != null ? fromDrift(result) : null;
    } catch (_) {
      // Table may not have a uuid column
      return null;
    }
  }

  @override
  Future<List<T>> getUnsyncedRecords() async {
    final tbl = table;
    try {
      final query = database.select(tbl);
      final results = await (query
            ..where((tbl) {
              final column =
                  (tbl as dynamic).isSynced as drift.GeneratedColumn<bool>;
              return column.equals(false);
            }))
          .get();
      return results.map((row) => fromDrift(row)).toList();
    } catch (_) {
      // Table may not have an isSynced column
      return [];
    }
  }

  @override
  Future<DateTime?> getLastWriteDate() async {
    final tbl = table;
    try {
      final writeDateColumn =
          (tbl as dynamic).writeDate as drift.GeneratedColumn<DateTime>;
      final query = database.selectOnly(tbl)
        ..addColumns([writeDateColumn])
        ..orderBy([drift.OrderingTerm.desc(writeDateColumn)])
        ..limit(1);

      final result = await query.getSingleOrNull();
      return result?.read(writeDateColumn);
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REACTIVE WATCH - Drift .watch() for database-level reactivity
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Stream<T?> watchLocalRecord(int id) {
    final tbl = table;
    final query = database.select(tbl)
      ..where((tbl) {
        final column = (tbl as dynamic).odooId as drift.GeneratedColumn<int>;
        return column.equals(id);
      });
    return query
        .watchSingleOrNull()
        .map((row) => row != null ? fromDrift(row) : null);
  }

  @override
  Stream<List<T>> watchLocalSearch({
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? orderBy,
  }) {
    var query = database.select(table);

    if (domain != null) {
      query = applyDomainFilters(query, domain);
    }

    final ordering = orderBy != null ? parseOrderBy(orderBy) : defaultOrdering;
    if (ordering.isNotEmpty) {
      query = query..orderBy(ordering);
    }

    if (limit != null) {
      query = query..limit(limit, offset: offset ?? 0);
    }

    return query.watch().map(
          (rows) => rows.map((row) => fromDrift(row)).toList(),
        );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Apply domain filters to query using Odoo Polish notation.
  ///
  /// Supports `|` (OR) and `&` (AND) operators with proper precedence.
  /// Operators in Odoo domains use prefix (Polish) notation:
  /// - `['|', ['a','=',1], ['b','=',2]]` → a=1 OR b=2
  /// - `['&', ['a','=',1], ['b','=',2]]` → a=1 AND b=2
  /// - `['|', '&', ['a','=',1], ['b','=',2], ['c','=',3]]` → (a=1 AND b=2) OR c=3
  ///
  /// Leaf conditions without explicit operators are implicitly ANDed.
  dynamic applyDomainFilters(dynamic query, List<dynamic> domain) {
    if (domain.isEmpty) return query;

    final expr = _buildDomainExpression(domain);
    if (expr != null) {
      return query..where((t) => expr(t));
    }
    return query;
  }

  /// Build a combined domain expression from Odoo Polish notation domain.
  ///
  /// Returns a function that takes a table reference and produces an Expression<bool>.
  drift.Expression<bool> Function(dynamic)? _buildDomainExpression(List<dynamic> domain) {
    if (domain.isEmpty) return null;

    // Stack-based Polish notation parser
    final stack = <_DomainNode>[];

    for (int i = 0; i < domain.length; i++) {
      final item = domain[i];

      if (item == '|') {
        stack.add(_OperatorNode(_DomainOp.or));
      } else if (item == '&') {
        stack.add(_OperatorNode(_DomainOp.and));
      } else if (item is List && item.length >= 3) {
        // Leaf condition
        final field = item[0] as String;
        final op = item[1] as String;
        final value = item[2];
        stack.add(_LeafNode(field, op, value));
        // Try to reduce the stack
        _reduceStack(stack);
      }
    }

    // If multiple unreduced nodes remain, AND them together
    if (stack.isEmpty) return null;

    while (stack.length > 1) {
      final right = stack.removeLast();
      final left = stack.removeLast();
      stack.add(_CombinedNode(_DomainOp.and, left, right));
    }

    final root = stack.first;
    return (t) => _evaluateNode(t, root);
  }

  /// Reduce the stack: when an operator has enough operands, combine them.
  void _reduceStack(List<_DomainNode> stack) {
    while (stack.length >= 3) {
      final top = stack[stack.length - 1];
      final mid = stack[stack.length - 2];
      final bot = stack[stack.length - 3];

      // Check if bot is an operator and top/mid are resolved (non-operator) nodes
      if (bot is _OperatorNode && mid is! _OperatorNode && top is! _OperatorNode) {
        stack.removeRange(stack.length - 3, stack.length);
        stack.add(_CombinedNode(bot.op, mid, top));
      } else {
        break;
      }
    }
  }

  /// Evaluate a domain node against a table reference.
  drift.Expression<bool> _evaluateNode(dynamic t, _DomainNode node) {
    if (node is _LeafNode) {
      return _resolveLeafCondition(t, node.field, node.op, node.value);
    } else if (node is _CombinedNode) {
      final left = _evaluateNode(t, node.left);
      final right = _evaluateNode(t, node.right);
      return node.op == _DomainOp.or ? (left | right) : (left & right);
    }
    return const drift.CustomExpression<bool>('1=1');
  }

  /// Resolve a single leaf condition to a Drift expression.
  drift.Expression<bool> _resolveLeafCondition(
      dynamic t, String field, String op, dynamic value) {
    final columnName = field == 'id' ? 'odooId' : snakeToCamel(field);
    try {
      final column = getColumnDynamic(t, columnName);
      if (column == null) return const drift.CustomExpression<bool>('1=1');
      return applyOperator(column, op, value);
    } catch (_) {
      return const drift.CustomExpression<bool>('1=1');
    }
  }

  /// Apply single domain condition (legacy compatibility).
  dynamic applyDomainCondition(dynamic query, List<dynamic> condition) {
    final field = condition[0] as String;
    final op = condition[1] as String;
    final value = condition[2];
    return applyFieldCondition(query, field, op, value);
  }

  /// Apply field-specific condition.
  /// Override in subclasses for custom field handling.
  ///
  /// Uses dynamic access to get the column by field name from the table.
  /// Falls back to well-known fields for common cases.
  dynamic applyFieldCondition(
      dynamic query, String field, String op, dynamic value) {
    // Map common Odoo field names to Drift column names
    final columnName = field == 'id' ? 'odooId' : snakeToCamel(field);

    try {
      // Try dynamic access for any column
      return query
        ..where((t) {
          final column = getColumnDynamic(t, columnName);
          if (column == null) return const drift.CustomExpression<bool>('1=1');
          return applyOperator(column, op, value);
        });
    } catch (_) {
      // If dynamic access fails, return query unchanged
      return query;
    }
  }

  /// Get a column from a table row using dynamic access.
  drift.GeneratedColumn? getColumnDynamic(dynamic tbl, String columnName) {
    try {
      final column = accessProperty(tbl, columnName);
      if (column is drift.GeneratedColumn) return column;
    } catch (_) {
      // Column doesn't exist on this table
    }
    return null;
  }

  /// Access a property dynamically by name.
  ///
  /// Only includes Odoo magic fields (present on ALL models per ORM spec)
  /// and framework-local fields. Model-specific fields (name, active, state,
  /// sequence, etc.) are handled by the generated manager's override.
  ///
  /// Override this in generated managers to add model-specific columns.
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      // Odoo magic fields (present on ALL models)
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'createDate':
        return (obj as dynamic).createDate;
      case 'displayName':
        return (obj as dynamic).displayName;
      // Framework-local fields (added by drift_table_generator)
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'localCreatedAt':
        return (obj as dynamic).localCreatedAt;
      default:
        throw StateError(
          'Field "$name" not found in base accessProperty(). '
          'The generated manager should override this with all model fields. '
          'Run: dart run build_runner build --delete-conflicting-outputs',
        );
    }
  }

  /// Apply a comparison operator to a column.
  ///
  /// Supports all standard Odoo domain operators:
  /// `=`, `!=`, `>`, `>=`, `<`, `<=`, `like`, `ilike`, `=like`, `=ilike`,
  /// `in`, `not in`, `not like`, `not ilike`, `=?`, `child_of`, `parent_of`.
  ///
  /// Comparison operators (`>`, `<`, `>=`, `<=`) work with int, double,
  /// and DateTime columns.
  drift.Expression<bool> applyOperator(
      drift.GeneratedColumn column, String op, dynamic value) {
    switch (op) {
      case '=':
        if (value == false) {
          // Odoo '=' false means null or false
          return column.isNull() | column.equals(false);
        }
        return column.equals(value);
      case '!=':
        if (value == false) {
          return column.isNotNull() & column.equals(false).not();
        }
        return column.equals(value).not();
      case '=?':
        // "unset or equals": if value is null/false → always true, else field = value
        if (value == null || value == false) {
          return const drift.CustomExpression<bool>('1=1');
        }
        return column.equals(value);
      case 'child_of':
      case 'parent_of':
        // Full hierarchy resolution requires server-side parent_path.
        // Locally, match the direct value (single ID or list of IDs).
        if (value is List) {
          return column.isIn(value.cast<Object>());
        }
        return column.equals(value);
      case 'ilike':
      case 'like':
        if (column is drift.GeneratedColumn<String>) {
          return column.contains(value as String);
        }
        return column.equals(value);
      case '=like':
        // SQL LIKE with exact pattern (% and _ are wildcards)
        if (column is drift.GeneratedColumn<String>) {
          return column.like(value as String);
        }
        return column.equals(value);
      case '=ilike':
        // Case-insensitive SQL LIKE
        if (column is drift.GeneratedColumn<String>) {
          return column.lower().like((value as String).toLowerCase());
        }
        return column.equals(value);
      case 'not like':
      case 'not ilike':
        if (column is drift.GeneratedColumn<String>) {
          return column.contains(value as String).not();
        }
        return column.equals(value).not();
      case 'in':
        if (value is List) {
          return column.isIn(value.cast<Object>());
        }
        return column.equals(value);
      case 'not in':
        if (value is List) {
          return column.isIn(value.cast<Object>()).not();
        }
        return column.equals(value).not();
      case '>':
        return _applyComparison(column, value, _CompOp.gt);
      case '<':
        return _applyComparison(column, value, _CompOp.lt);
      case '>=':
        return _applyComparison(column, value, _CompOp.gte);
      case '<=':
        return _applyComparison(column, value, _CompOp.lte);
      default:
        return column.equals(value);
    }
  }

  /// Apply a comparison operator that supports int, double, and DateTime.
  drift.Expression<bool> _applyComparison(
      drift.GeneratedColumn column, dynamic value, _CompOp comp) {
    if (column is drift.GeneratedColumn<int>) {
      final v = value is int ? value : int.tryParse(value.toString()) ?? 0;
      return switch (comp) {
        _CompOp.gt => column.isBiggerThanValue(v),
        _CompOp.lt => column.isSmallerThanValue(v),
        _CompOp.gte => column.isBiggerOrEqualValue(v),
        _CompOp.lte => column.isSmallerOrEqualValue(v),
      };
    }
    if (column is drift.GeneratedColumn<double>) {
      final v = value is double
          ? value
          : double.tryParse(value.toString()) ?? 0.0;
      return switch (comp) {
        _CompOp.gt => column.isBiggerThanValue(v),
        _CompOp.lt => column.isSmallerThanValue(v),
        _CompOp.gte => column.isBiggerOrEqualValue(v),
        _CompOp.lte => column.isSmallerOrEqualValue(v),
      };
    }
    if (column is drift.GeneratedColumn<DateTime>) {
      final v = value is DateTime
          ? value
          : DateTime.tryParse(value.toString()) ?? DateTime(1970);
      return switch (comp) {
        _CompOp.gt => column.isBiggerThanValue(v),
        _CompOp.lt => column.isSmallerThanValue(v),
        _CompOp.gte => column.isBiggerOrEqualValue(v),
        _CompOp.lte => column.isSmallerOrEqualValue(v),
      };
    }
    return column.equals(value);
  }

  /// Convert snake_case to camelCase.
  String snakeToCamel(String input) {
    final parts = input.split('_');
    if (parts.length == 1) return input;
    return parts.first +
        parts.skip(1).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join();
  }

  /// Parse orderBy string into OrderingTerms.
  List<drift.OrderingTerm Function(dynamic)> parseOrderBy(String orderBy) {
    final parts = orderBy.split(',');
    return parts.map((part) {
      final trimmed = part.trim();
      if (trimmed.contains(' desc')) {
        final field = trimmed.replaceAll(' desc', '');
        return getOrderingTerm(field, ascending: false);
      } else {
        final field = trimmed.replaceAll(' asc', '');
        return getOrderingTerm(field, ascending: true);
      }
    }).toList();
  }

  /// Get ordering term for field.
  drift.OrderingTerm Function(dynamic) getOrderingTerm(String field,
      {required bool ascending}) {
    final columnName = field == 'id' ? 'odooId' : snakeToCamel(field);
    return (t) {
      try {
        final column = accessProperty(t, columnName) as drift.GeneratedColumn;
        return ascending
            ? drift.OrderingTerm.asc(column)
            : drift.OrderingTerm.desc(column);
      } catch (_) {
        // Fallback to odooId column (universal across all models)
        final fallback = (t as dynamic).odooId as drift.GeneratedColumn;
        return ascending
            ? drift.OrderingTerm.asc(fallback)
            : drift.OrderingTerm.desc(fallback);
      }
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SQLite Value Helpers
// ═══════════════════════════════════════════════════════════════════════════

/// Converts a Dart value to a SQLite-compatible raw value.
///
/// SQLite parameters only accept: null, bool, int, num, String, List<int>.
/// DateTime must be converted to unix timestamp (seconds since epoch),
/// which is how Drift stores DateTimeColumn values.
Object? _toSqliteValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.millisecondsSinceEpoch ~/ 1000;
  if (value is bool || value is int || value is num || value is String) {
    return value;
  }
  if (value is List<int>) return value;
  // Fallback: convert to string
  return value.toString();
}

// ═══════════════════════════════════════════════════════════════════════════
// Nullable Variable Helper
// ═══════════════════════════════════════════════════════════════════════════

/// Creates a drift [Expression] for a potentially null value.
///
/// Drift's [Variable] requires `T extends Object`, so nullable values
/// need special handling. This returns `Variable<T>(value!)` when non-null,
/// or a SQL NULL expression when null.
drift.Expression<Object> driftVar<T extends Object>(T? value) {
  if (value == null) return const drift.CustomExpression<Object>('NULL');
  return drift.Variable<T>(value);
}

// ═══════════════════════════════════════════════════════════════════════════
// Internal Types
// ═══════════════════════════════════════════════════════════════════════════

/// Comparison operations for numeric/date columns.
enum _CompOp { gt, lt, gte, lte }

// ═══════════════════════════════════════════════════════════════════════════
// Domain Expression Tree Types (for Polish notation OR/AND support)
// ═══════════════════════════════════════════════════════════════════════════

enum _DomainOp { or, and }

/// Base class for domain expression tree nodes.
sealed class _DomainNode {}

/// An operator node (| or &) waiting for operands.
class _OperatorNode extends _DomainNode {
  final _DomainOp op;
  _OperatorNode(this.op);
}

/// A leaf condition node (field, operator, value).
class _LeafNode extends _DomainNode {
  final String field;
  final String op;
  final dynamic value;
  _LeafNode(this.field, this.op, this.value);
}

/// A combined node with two children and an operator.
class _CombinedNode extends _DomainNode {
  final _DomainOp op;
  final _DomainNode left;
  final _DomainNode right;
  _CombinedNode(this.op, this.left, this.right);
}
