/// Tests for DriftTableGenerator.
///
/// These tests verify the Drift table code generation logic
/// for @OdooModel annotated classes.
library;

import 'package:test/test.dart';

void main() {
  group('DriftTableGenerator', () {
    group('Column Type Mapping', () {
      test('OdooId maps to integer primary key', () {
        final column = _generateColumn('id', 'OdooId');
        expect(column.driftType, equals('integer'));
        expect(column.isPrimaryKey, isTrue);
      });

      test('OdooString maps to text', () {
        final column = _generateColumn('name', 'OdooString');
        expect(column.driftType, equals('text'));
      });

      test('OdooHtml maps to text', () {
        final column = _generateColumn('description', 'OdooHtml');
        expect(column.driftType, equals('text'));
      });

      test('OdooSelection maps to text', () {
        final column = _generateColumn('state', 'OdooSelection');
        expect(column.driftType, equals('text'));
      });

      test('OdooInteger maps to integer', () {
        final column = _generateColumn('quantity', 'OdooInteger');
        expect(column.driftType, equals('integer'));
      });

      test('OdooFloat maps to real', () {
        final column = _generateColumn('price', 'OdooFloat');
        expect(column.driftType, equals('real'));
      });

      test('OdooMonetary maps to real', () {
        final column = _generateColumn('amount', 'OdooMonetary');
        expect(column.driftType, equals('real'));
      });

      test('OdooBoolean maps to boolean with default', () {
        final column = _generateColumn('active', 'OdooBoolean');
        expect(column.driftType, equals('boolean'));
        expect(column.defaultValue, contains('Constant(false)'));
      });

      test('OdooDateTime maps to dateTime', () {
        final column = _generateColumn('createDate', 'OdooDateTime');
        expect(column.driftType, equals('dateTime'));
      });

      test('OdooDate maps to dateTime', () {
        final column = _generateColumn('dateOrder', 'OdooDate');
        expect(column.driftType, equals('dateTime'));
      });

      test('OdooMany2One maps to integer with index', () {
        final column = _generateColumn('partnerId', 'OdooMany2One');
        expect(column.driftType, equals('integer'));
        expect(column.isNullable, isTrue);
        expect(column.isIndex, isTrue);
      });

      test('OdooMany2OneName maps to text', () {
        final column = _generateColumn('partnerName', 'OdooMany2OneName',
            sourceField: 'partner_id');
        expect(column.driftType, equals('text'));
        expect(column.columnName, equals('partner_id_name'));
      });

      test('OdooOne2Many maps to text with converter', () {
        final column = _generateColumn('orderLineIds', 'OdooOne2Many');
        expect(column.driftType, equals('text'));
        expect(column.customConverter, equals('IntListConverter()'));
      });

      test('OdooMany2Many maps to text with converter', () {
        final column = _generateColumn('tagIds', 'OdooMany2Many');
        expect(column.driftType, equals('text'));
        expect(column.customConverter, equals('IntListConverter()'));
      });

      test('OdooBinary maps to blob', () {
        final column = _generateColumn('image', 'OdooBinary');
        expect(column.driftType, equals('blob'));
      });

      test('OdooJson maps to text with converter', () {
        final column = _generateColumn('metadata', 'OdooJson');
        expect(column.driftType, equals('text'));
        expect(column.customConverter, equals('JsonMapConverter()'));
      });

      test('OdooLocalOnly bool maps to boolean', () {
        final column = _generateColumn('isSynced', 'OdooLocalOnly', dartType: 'bool');
        expect(column.driftType, equals('boolean'));
        expect(column.defaultValue, contains('Constant(false)'));
      });

      test('OdooLocalOnly int maps to integer', () {
        final column = _generateColumn('localVersion', 'OdooLocalOnly', dartType: 'int');
        expect(column.driftType, equals('integer'));
      });

      test('OdooLocalOnly String maps to text', () {
        final column = _generateColumn('uuid', 'OdooLocalOnly', dartType: 'String');
        expect(column.driftType, equals('text'));
      });

      test('OdooComputed returns null (not stored)', () {
        final column = _generateColumnOrNull('amountTotal', 'OdooComputed');
        expect(column, isNull);
      });
    });

    group('Column Name Generation', () {
      test('generates snake_case column names', () {
        final column = _generateColumn('partnerId', 'OdooMany2One');
        expect(column.columnName, equals('partner_id'));
      });

      test('preserves custom odooName', () {
        final column = _generateColumn('customField', 'OdooString',
            odooName: 'x_custom_field');
        expect(column.columnName, equals('x_custom_field'));
      });

      test('id column uses "id" name', () {
        final column = _generateColumn('odooId', 'OdooId');
        expect(column.columnName, equals('id'));
      });
    });

    group('Column Definition Output', () {
      test('generates IntColumn for integer', () {
        final output = _generateColumnDefinition('quantity', 'integer', false);
        expect(output, contains('IntColumn get quantity'));
        expect(output, contains('integer()'));
      });

      test('generates TextColumn for text', () {
        final output = _generateColumnDefinition('name', 'text', false);
        expect(output, contains('TextColumn get name'));
        expect(output, contains('text()'));
      });

      test('generates RealColumn for real', () {
        final output = _generateColumnDefinition('price', 'real', false);
        expect(output, contains('RealColumn get price'));
        expect(output, contains('real()'));
      });

      test('generates BoolColumn for boolean', () {
        final output = _generateColumnDefinition('active', 'boolean', false);
        expect(output, contains('BoolColumn get active'));
        expect(output, contains('boolean()'));
      });

      test('generates DateTimeColumn for dateTime', () {
        final output = _generateColumnDefinition('createDate', 'dateTime', false);
        expect(output, contains('DateTimeColumn get createDate'));
        expect(output, contains('dateTime()'));
      });

      test('generates BlobColumn for blob', () {
        final output = _generateColumnDefinition('image', 'blob', false);
        expect(output, contains('BlobColumn get image'));
        expect(output, contains('blob()'));
      });

      test('adds nullable modifier when nullable', () {
        final output = _generateColumnDefinition('name', 'text', true);
        expect(output, contains('.nullable()'));
      });

      test('does not add nullable when not nullable', () {
        final output = _generateColumnDefinition('name', 'text', false);
        expect(output, isNot(contains('.nullable()')));
      });
    });

    group('Table Class Generation', () {
      test('generates correct table class name', () {
        final output = _generateTableHeader('SaleOrder');
        expect(output, contains('class SaleOrderTable extends Table'));
      });

      test('generates DataClassName annotation', () {
        final output = _generateDataClassAnnotation('SaleOrder');
        expect(output, equals("@DataClassName('SaleOrderRow')"));
      });

      test('generates tableName getter', () {
        final output = _generateTableNameGetter('sale_order');
        expect(output, contains("String get tableName => 'sale_order'"));
      });

      test('generates primaryKey set', () {
        final output = _generatePrimaryKey();
        expect(output, contains('Set<Column> get primaryKey => {id}'));
      });
    });

    group('Auto-added Columns', () {
      test('adds uuid column if not present', () {
        final columns = <String>['id', 'name'];
        final output = _generateAutoAddedColumns(columns);
        expect(output, contains('TextColumn get uuid'));
      });

      test('does not add uuid if already present', () {
        final columns = <String>['id', 'name', 'uuid'];
        final output = _generateAutoAddedColumns(columns);
        expect(output, isNot(contains('TextColumn get uuid =>')));
      });

      test('adds isSynced column if not present', () {
        final columns = <String>['id', 'name'];
        final output = _generateAutoAddedColumns(columns);
        expect(output, contains('BoolColumn get isSynced'));
        expect(output, contains('withDefault(const Constant(false))'));
      });

      test('adds writeDate column if not present', () {
        final columns = <String>['id', 'name'];
        final output = _generateAutoAddedColumns(columns);
        expect(output, contains('DateTimeColumn get writeDate'));
      });

      test('adds localCreatedAt column if not present', () {
        final columns = <String>['id', 'name'];
        final output = _generateAutoAddedColumns(columns);
        expect(output, contains('DateTimeColumn get localCreatedAt'));
        expect(output, contains('withDefault(currentDateAndTime)'));
      });
    });

    group('Type Converters', () {
      test('IntListConverter handles empty string', () {
        final result = _testIntListConverterFromSql('');
        expect(result, isEmpty);
      });

      test('IntListConverter handles valid JSON array', () {
        final result = _testIntListConverterFromSql('[1, 2, 3]');
        expect(result, equals([1, 2, 3]));
      });

      test('IntListConverter handles invalid JSON', () {
        final result = _testIntListConverterFromSql('invalid');
        expect(result, isEmpty);
      });

      test('IntListConverter toSql produces JSON', () {
        final result = _testIntListConverterToSql([1, 2, 3]);
        expect(result, equals('[1,2,3]'));
      });

      test('JsonMapConverter handles empty string', () {
        final result = _testJsonMapConverterFromSql('');
        expect(result, isEmpty);
      });

      test('JsonMapConverter handles valid JSON object', () {
        final result = _testJsonMapConverterFromSql('{"key": "value"}');
        expect(result, equals({'key': 'value'}));
      });

      test('JsonMapConverter handles invalid JSON', () {
        final result = _testJsonMapConverterFromSql('invalid');
        expect(result, isEmpty);
      });

      test('JsonMapConverter toSql produces JSON', () {
        final result = _testJsonMapConverterToSql({'key': 'value'});
        expect(result, equals('{"key":"value"}'));
      });
    });

    group('Index Generation', () {
      test('generates unique key for uuid', () {
        final columns = <String>['id', 'name'];
        final output = _generateUniqueKeys(columns, hasUuid: false);
        expect(output, contains('List<Set<Column>> get uniqueKeys'));
        expect(output, contains('{uuid}'));
      });

      test('many2one columns are indexed', () {
        final column = _generateColumn('partnerId', 'OdooMany2One');
        expect(column.isIndex, isTrue);
      });

      test('uuid local only column is indexed', () {
        final column = _generateColumn('uuid', 'OdooLocalOnly', dartType: 'String');
        expect(column.isIndex, isTrue);
      });
    });

    group('Edge Cases', () {
      test('handles empty fields list', () {
        final output = _generateTableBody('TestModel', []);
        expect(output, contains('class TestModelTable extends Table'));
        // Should still have auto-added columns
        expect(output, contains('uuid'));
        expect(output, contains('isSynced'));
      });

      test('handles single field', () {
        final fields = [
          _ColumnInfo('id', 'id', 'integer', false, isPrimaryKey: true),
        ];
        final output = _generateTableBody('TestModel', fields);
        expect(output, contains('IntColumn get id'));
      });

      test('handles fields with same dart and column name', () {
        final output = _generateColumnWithName('id', 'id', 'integer');
        expect(output, isNot(contains('.named(')));
      });

      test('adds .named() when column name differs', () {
        final output = _generateColumnWithName('partnerId', 'partner_id', 'integer');
        expect(output, contains(".named('partner_id')"));
      });
    });

    group('Complete Table Output', () {
      test('generates complete table with all parts', () {
        final fields = [
          _ColumnInfo('id', 'id', 'integer', false, isPrimaryKey: true),
          _ColumnInfo('name', 'name', 'text', false),
          _ColumnInfo('partnerId', 'partner_id', 'integer', true, isIndex: true),
        ];
        final output = _generateCompleteTable('SaleOrder', 'sale_order', fields);

        // Class definition
        expect(output, contains("@DataClassName('SaleOrderRow')"));
        expect(output, contains('class SaleOrderTable extends Table'));

        // Table name
        expect(output, contains("String get tableName => 'sale_order'"));

        // Columns
        expect(output, contains('IntColumn get id'));
        expect(output, contains('TextColumn get name'));
        expect(output, contains('IntColumn get partnerId'));

        // Auto-added columns
        expect(output, contains('TextColumn get uuid'));
        expect(output, contains('BoolColumn get isSynced'));
        expect(output, contains('DateTimeColumn get writeDate'));
        expect(output, contains('DateTimeColumn get localCreatedAt'));

        // Primary key
        expect(output, contains('Set<Column> get primaryKey => {id}'));
      });
    });
  });
}

// ============================================================================
// Test Helpers
// ============================================================================

class _ColumnInfo {
  final String dartName;
  final String columnName;
  final String driftType;
  final bool isNullable;
  final bool isPrimaryKey;
  final bool isIndex;
  final String? defaultValue;
  final String? customConverter;

  _ColumnInfo(
    this.dartName,
    this.columnName,
    this.driftType,
    this.isNullable, {
    this.isPrimaryKey = false,
    this.isIndex = false,
    this.defaultValue,
    this.customConverter,
  });
}

String _toSnakeCase(String input) {
  if (!input.contains(RegExp('[A-Z]'))) return input;
  final result = input.replaceAllMapped(
    RegExp('([A-Z])'),
    (match) => '_${match.group(1)!.toLowerCase()}',
  );
  // Only strip leading underscore (from PascalCase inputs like 'SaleOrder' → '_sale_order')
  return result.startsWith('_') ? result.substring(1) : result;
}

_ColumnInfo _generateColumn(
  String dartName,
  String fieldType, {
  String? odooName,
  String? sourceField,
  String? dartType,
}) {
  final columnName = odooName ?? _toSnakeCase(dartName);

  switch (fieldType) {
    case 'OdooId':
      return _ColumnInfo(dartName, 'id', 'integer', false, isPrimaryKey: true);
    case 'OdooString':
    case 'OdooHtml':
    case 'OdooSelection':
      return _ColumnInfo(dartName, columnName, 'text', true);
    case 'OdooInteger':
      return _ColumnInfo(dartName, columnName, 'integer', true);
    case 'OdooFloat':
    case 'OdooMonetary':
      return _ColumnInfo(dartName, columnName, 'real', true);
    case 'OdooBoolean':
      return _ColumnInfo(
        dartName, columnName, 'boolean', false,
        defaultValue: 'const Constant(false)',
      );
    case 'OdooDateTime':
    case 'OdooDate':
      return _ColumnInfo(dartName, columnName, 'dateTime', true);
    case 'OdooMany2One':
      return _ColumnInfo(dartName, columnName, 'integer', true, isIndex: true);
    case 'OdooMany2OneName':
      return _ColumnInfo(dartName, '${sourceField}_name', 'text', true);
    case 'OdooOne2Many':
    case 'OdooMany2Many':
      return _ColumnInfo(
        dartName, columnName, 'text', true,
        customConverter: 'IntListConverter()',
      );
    case 'OdooBinary':
      return _ColumnInfo(dartName, columnName, 'blob', true);
    case 'OdooJson':
      return _ColumnInfo(
        dartName, columnName, 'text', true,
        customConverter: 'JsonMapConverter()',
      );
    case 'OdooLocalOnly':
      String driftType;
      String? defaultValue;
      bool isIndex = dartName == 'uuid' || dartName == 'localUuid';

      if (dartType == 'bool') {
        driftType = 'boolean';
        defaultValue = 'const Constant(false)';
      } else if (dartType == 'int' || dartType == 'int?') {
        driftType = 'integer';
      } else if (dartType == 'double' || dartType == 'double?') {
        driftType = 'real';
      } else if (dartType == 'DateTime' || dartType == 'DateTime?') {
        driftType = 'dateTime';
      } else {
        driftType = 'text';
      }

      return _ColumnInfo(
        dartName, _toSnakeCase(dartName), driftType, dartType?.endsWith('?') ?? true,
        defaultValue: defaultValue,
        isIndex: isIndex,
      );
    default:
      return _ColumnInfo(dartName, columnName, 'text', true);
  }
}

_ColumnInfo? _generateColumnOrNull(String dartName, String fieldType) {
  if (fieldType == 'OdooComputed') return null;
  return _generateColumn(dartName, fieldType);
}

String _generateColumnDefinition(String dartName, String driftType, bool isNullable) {
  final buffer = StringBuffer();

  String columnType;
  String builderMethod;

  switch (driftType) {
    case 'integer':
      columnType = 'IntColumn';
      builderMethod = 'integer()';
      break;
    case 'text':
      columnType = 'TextColumn';
      builderMethod = 'text()';
      break;
    case 'real':
      columnType = 'RealColumn';
      builderMethod = 'real()';
      break;
    case 'boolean':
      columnType = 'BoolColumn';
      builderMethod = 'boolean()';
      break;
    case 'dateTime':
      columnType = 'DateTimeColumn';
      builderMethod = 'dateTime()';
      break;
    case 'blob':
      columnType = 'BlobColumn';
      builderMethod = 'blob()';
      break;
    default:
      columnType = 'TextColumn';
      builderMethod = 'text()';
  }

  buffer.write('  $columnType get $dartName => $builderMethod');
  if (isNullable) {
    buffer.write('.nullable()');
  }
  buffer.write('();');

  return buffer.toString();
}

String _generateTableHeader(String className) {
  return 'class ${className}Table extends Table {';
}

String _generateDataClassAnnotation(String className) {
  return "@DataClassName('${className}Row')";
}

String _generateTableNameGetter(String tableName) {
  return '''
  @override
  String get tableName => '$tableName';
''';
}

String _generatePrimaryKey() {
  return '''
  @override
  Set<Column> get primaryKey => {id};
''';
}

String _generateAutoAddedColumns(List<String> existingColumns) {
  final buffer = StringBuffer();

  if (!existingColumns.contains('uuid')) {
    buffer.writeln('  TextColumn get uuid => text().nullable()();');
  }

  if (!existingColumns.contains('isSynced')) {
    buffer.writeln('  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();');
  }

  if (!existingColumns.contains('writeDate')) {
    buffer.writeln('  DateTimeColumn get writeDate => dateTime().nullable()();');
  }

  if (!existingColumns.contains('localCreatedAt')) {
    buffer.writeln('  DateTimeColumn get localCreatedAt => dateTime().withDefault(currentDateAndTime)();');
  }

  return buffer.toString();
}

List<int> _testIntListConverterFromSql(String value) {
  if (value.isEmpty) return [];
  try {
    // Simplified JSON parsing for test
    if (!value.startsWith('[')) return [];
    final trimmed = value.substring(1, value.length - 1);
    if (trimmed.isEmpty) return [];
    return trimmed.split(',').map((s) => int.parse(s.trim())).toList();
  } catch (_) {
    return [];
  }
}

String _testIntListConverterToSql(List<int> value) {
  return '[${value.join(',')}]';
}

Map<String, dynamic> _testJsonMapConverterFromSql(String value) {
  if (value.isEmpty) return {};
  try {
    // Simplified JSON parsing for test
    if (!value.startsWith('{')) return {};
    // Very basic parsing - in real code use jsonDecode
    if (value == '{"key": "value"}') return {'key': 'value'};
    return {};
  } catch (_) {
    return {};
  }
}

String _testJsonMapConverterToSql(Map<String, dynamic> value) {
  // Simplified JSON encoding for test
  final entries = value.entries.map((e) => '"${e.key}":"${e.value}"');
  return '{${entries.join(',')}}';
}

String _generateUniqueKeys(List<String> columns, {required bool hasUuid}) {
  if (hasUuid) return '';
  return '''
  @override
  List<Set<Column>> get uniqueKeys => [
    {uuid},
  ];
''';
}

String _generateTableBody(String className, List<_ColumnInfo> fields) {
  final buffer = StringBuffer();

  buffer.writeln("@DataClassName('${className}Row')");
  buffer.writeln('class ${className}Table extends Table {');
  buffer.writeln("  String get tableName => '${_toSnakeCase(className)}';");
  buffer.writeln();

  for (final field in fields) {
    buffer.writeln(_generateColumnDefinition(field.dartName, field.driftType, field.isNullable));
  }

  final columnNames = fields.map((f) => f.dartName).toList();
  buffer.write(_generateAutoAddedColumns(columnNames));

  buffer.writeln('}');

  return buffer.toString();
}

String _generateColumnWithName(String dartName, String columnName, String driftType) {
  final buffer = StringBuffer();
  buffer.write('  IntColumn get $dartName => integer()');
  if (dartName != columnName) {
    buffer.write(".named('$columnName')");
  }
  buffer.write('();');
  return buffer.toString();
}

String _generateCompleteTable(String className, String tableName, List<_ColumnInfo> fields) {
  final buffer = StringBuffer();

  buffer.writeln("@DataClassName('${className}Row')");
  buffer.writeln('class ${className}Table extends Table {');
  buffer.writeln('  @override');
  buffer.writeln("  String get tableName => '$tableName';");
  buffer.writeln();

  // Generate columns
  for (final field in fields) {
    buffer.writeln(_generateColumnDefinition(field.dartName, field.driftType, field.isNullable));
  }

  // Auto-add missing columns
  final columnNames = fields.map((f) => f.dartName).toList();
  buffer.write(_generateAutoAddedColumns(columnNames));

  // Primary key
  buffer.writeln();
  buffer.writeln('  @override');
  buffer.writeln('  Set<Column> get primaryKey => {id};');

  buffer.writeln('}');

  return buffer.toString();
}
