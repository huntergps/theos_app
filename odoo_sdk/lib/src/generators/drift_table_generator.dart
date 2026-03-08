/// Drift Table Generator for OdooModel annotated classes.
///
/// Generates Drift table definitions based on Odoo field annotations.
/// This enables automatic schema generation that matches the model definition.
///
/// The generated tables include:
/// - All Odoo fields with appropriate Drift column types
/// - Local-only fields (uuid, isSynced, etc.)
/// - Proper indexes for common queries
/// - Write date tracking for incremental sync
library;

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../model/odoo_field_annotations.dart';

/// Builder factory for Drift tables.
Builder driftTableBuilder(BuilderOptions options) =>
    SharedPartBuilder([DriftTableGenerator()], 'drift_table');

/// Generator for Drift table definitions.
class DriftTableGenerator extends GeneratorForAnnotation<OdooModel> {
  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@OdooModel can only be applied to classes',
        element: element,
      );
    }

    final classElement = element;
    final className = classElement.name;
    if (className == null || className.isEmpty) {
      throw InvalidGenerationSourceError(
        '@OdooModel class must have a name',
        element: element,
      );
    }
    final tableName = annotation.peek('tableName')?.stringValue ??
        _toSnakeCase(className);

    // Analyze fields
    final fields = _analyzeFields(classElement);

    return _generateDriftTable(
      className: className,
      tableName: tableName,
      fields: fields,
    );
  }

  /// Analyze fields from the class.
  List<_DriftFieldInfo> _analyzeFields(ClassElement classElement) {
    final fields = <_DriftFieldInfo>[];

    // Find unnamed factory constructor (Freezed pattern)
    ConstructorElement? constructor;
    for (final c in classElement.constructors) {
      if (c.isFactory && c.name == null) {
        constructor = c;
        break;
      }
    }

    // Fallback: any factory constructor
    if (constructor == null) {
      for (final c in classElement.constructors) {
        if (c.isFactory) {
          constructor = c;
          break;
        }
      }
    }

    // Fallback: first constructor with parameters
    constructor ??= classElement.constructors
        .where((c) => c.name != '_' && c.formalParameters.isNotEmpty)
        .firstOrNull;

    if (constructor == null) {
      return fields;
    }

    // Extract field info from each parameter
    for (final param in constructor.formalParameters) {
      final fieldInfo = _extractFieldInfo(param);
      if (fieldInfo != null) {
        fields.add(fieldInfo);
      }
    }

    return fields;
  }

  /// Extract field information for Drift table generation.
  _DriftFieldInfo? _extractFieldInfo(FormalParameterElement param) {
    final name = param.name;
    if (name == null || name.isEmpty) return null;

    final type = param.type;
    final isNullable = type.nullabilitySuffix == NullabilitySuffix.question;

    for (final annotation in param.metadata.annotations) {
      final annotationType = annotation.computeConstantValue()?.type;
      if (annotationType == null) continue;

      final typeName = annotationType.getDisplayString();
      final reader = ConstantReader(annotation.computeConstantValue());

      switch (typeName) {
        case 'OdooId':
          return _DriftFieldInfo(
            dartName: name,
            columnName: 'id',
            driftType: 'integer',
            isNullable: false,
            isPrimaryKey: true,
            autoIncrement: false,
          );

        case 'OdooString':
        case 'OdooHtml':
        case 'OdooSelection':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'text',
            isNullable: isNullable,
          );

        case 'OdooInteger':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'integer',
            isNullable: isNullable,
          );

        case 'OdooFloat':
        case 'OdooMonetary':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'real',
            isNullable: isNullable,
          );

        case 'OdooBoolean':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'boolean',
            isNullable: false,
            defaultValue: 'const Constant(false)',
          );

        case 'OdooDateTime':
        case 'OdooDate':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'dateTime',
            isNullable: isNullable,
          );

        case 'OdooMany2One':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'integer',
            isNullable: true,
            isIndex: true,
          );

        case 'OdooMany2OneName':
          // Store display name as text
          final sourceField = reader.read('sourceField').stringValue;
          return _DriftFieldInfo(
            dartName: name,
            columnName: '${sourceField}_name',
            driftType: 'text',
            isNullable: true,
          );

        case 'OdooOne2Many':
        case 'OdooMany2Many':
          // Store as JSON array of IDs
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'text', // JSON encoded list
            isNullable: true,
            customConverter: 'IntListConverter()',
          );

        case 'OdooBinary':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'blob',
            isNullable: true,
          );

        case 'OdooJson':
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'text', // JSON encoded
            isNullable: true,
            customConverter: 'JsonMapConverter()',
          );

        case 'OdooLocalOnly':
          // Determine type from Dart type
          final typeStr = type.getDisplayString();
          String driftType;
          String? defaultValue;

          if (typeStr == 'bool') {
            driftType = 'boolean';
            defaultValue = 'const Constant(false)';
          } else if (typeStr == 'int' || typeStr == 'int?') {
            driftType = 'integer';
          } else if (typeStr == 'double' || typeStr == 'double?') {
            driftType = 'real';
          } else if (typeStr == 'DateTime' || typeStr == 'DateTime?') {
            driftType = 'dateTime';
          } else {
            driftType = 'text';
          }

          return _DriftFieldInfo(
            dartName: name,
            columnName: _toSnakeCase(name),
            driftType: driftType,
            isNullable: isNullable,
            defaultValue: defaultValue,
            isIndex: name == 'uuid' || name == 'localUuid',
          );

        case 'OdooComputed':
          // Computed fields are not stored in database
          return null;

        case 'OdooStoredComputed':
          // Stored computed fields ARE synced from Odoo and need DB columns
          final driftType = _dartTypeToDrift(type);
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: driftType,
            isNullable: isNullable,
          );

        case 'OdooRelated':
          final storeValue = reader.peek('store')?.boolValue ?? true;
          if (!storeValue) return null;
          // Infer column type from Dart type
          final driftType = _dartTypeToDrift(type);
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: driftType,
            isNullable: isNullable,
          );

        case 'OdooReference':
          // Reference fields store "model,id" format as text
          return _DriftFieldInfo(
            dartName: name,
            columnName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
            driftType: 'text',
            isNullable: isNullable,
          );
      }
    }

    return null;
  }

  /// Map Dart type to Drift column type.
  String _dartTypeToDrift(DartType type) {
    final typeStr = type.getDisplayString();
    if (typeStr == 'int' || typeStr == 'int?') return 'integer';
    if (typeStr == 'double' || typeStr == 'double?') return 'real';
    if (typeStr == 'bool' || typeStr == 'bool?') return 'boolean';
    if (typeStr == 'DateTime' || typeStr == 'DateTime?') return 'dateTime';
    return 'text';
  }

  /// Generate the Drift table class.
  String _generateDriftTable({
    required String className,
    required String tableName,
    required List<_DriftFieldInfo> fields,
  }) {
    final buffer = StringBuffer();
    final tableClassName = '${className}Table';

    buffer.writeln('/// Generated Drift table for $className.');
    buffer.writeln('///');
    buffer.writeln('/// Table name: $tableName');
    buffer.writeln("@DataClassName('${className}Row')");
    buffer.writeln('class $tableClassName extends Table {');

    // Table name
    buffer.writeln('  @override');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Columns
    for (final field in fields) {
      buffer.writeln(_generateColumn(field));
    }

    // Add standard local fields if not present
    final hasUuid = fields.any((f) => f.dartName == 'uuid');
    final hasIsSynced = fields.any((f) => f.dartName == 'isSynced');
    final hasWriteDate = fields.any((f) => f.columnName == 'write_date');
    final hasLocalCreatedAt = fields.any((f) => f.dartName == 'localCreatedAt');

    if (!hasUuid) {
      buffer.writeln(
          '  /// Local UUID for offline-created records.');
      buffer.writeln(
          '  TextColumn get uuid => text().nullable()();');
      buffer.writeln();
    }

    if (!hasIsSynced) {
      buffer.writeln('  /// Whether this record is synced with Odoo.');
      buffer.writeln(
          '  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();');
      buffer.writeln();
    }

    if (!hasWriteDate) {
      buffer.writeln('  /// Last modification date from Odoo.');
      buffer.writeln('  DateTimeColumn get writeDate => dateTime().nullable()();');
      buffer.writeln();
    }

    if (!hasLocalCreatedAt) {
      buffer.writeln('  /// Local creation timestamp.');
      buffer.writeln(
          '  DateTimeColumn get localCreatedAt => dateTime().withDefault(currentDateAndTime)();');
      buffer.writeln();
    }

    // Primary key
    buffer.writeln('  @override');
    buffer.writeln('  Set<Column> get primaryKey => {id};');
    buffer.writeln();

    // Unique keys (uuid should be unique across records)
    if (!hasUuid) {
      buffer.writeln('  @override');
      buffer.writeln('  List<Set<Column>> get uniqueKeys => [');
      buffer.writeln('    {uuid},');
      buffer.writeln('  ];');
    }
    buffer.writeln();

    // Non-unique indexes for foreign key columns (Many2One).
    // Drift's Table class doesn't support non-unique indexes directly.
    // Override customConstraints or create indexes via migration SQL.
    final indexedFields = fields.where((f) => f.isIndex).toList();
    if (indexedFields.isNotEmpty) {
      buffer.writeln('  /// Columns that should be indexed for query performance.');
      buffer.writeln('  /// Create these indexes in your database migration:');
      for (final f in indexedFields) {
        buffer.writeln('  /// CREATE INDEX idx_${tableName}_${f.columnName} ON $tableName(${f.columnName});');
      }
    }

    buffer.writeln('}');

    // Generate type converters if needed
    final needsIntListConverter =
        fields.any((f) => f.customConverter == 'IntListConverter()');
    final needsJsonMapConverter =
        fields.any((f) => f.customConverter == 'JsonMapConverter()');

    if (needsIntListConverter) {
      buffer.writeln();
      buffer.writeln(_generateIntListConverter());
    }

    if (needsJsonMapConverter) {
      buffer.writeln();
      buffer.writeln(_generateJsonMapConverter());
    }

    return buffer.toString();
  }

  /// Generate a single column definition.
  String _generateColumn(_DriftFieldInfo field) {
    final buffer = StringBuffer();

    // Documentation
    buffer.writeln('  /// ${field.dartName} column.');

    // Column definition
    buffer.write('  ');

    switch (field.driftType) {
      case 'integer':
        buffer.write('IntColumn');
        break;
      case 'text':
        buffer.write('TextColumn');
        break;
      case 'real':
        buffer.write('RealColumn');
        break;
      case 'boolean':
        buffer.write('BoolColumn');
        break;
      case 'dateTime':
        buffer.write('DateTimeColumn');
        break;
      case 'blob':
        buffer.write('BlobColumn');
        break;
    }

    buffer.write(' get ${field.dartName} => ');

    // Column builder
    switch (field.driftType) {
      case 'integer':
        buffer.write('integer()');
        break;
      case 'text':
        buffer.write('text()');
        break;
      case 'real':
        buffer.write('real()');
        break;
      case 'boolean':
        buffer.write('boolean()');
        break;
      case 'dateTime':
        buffer.write('dateTime()');
        break;
      case 'blob':
        buffer.write('blob()');
        break;
    }

    // Modifiers
    if (field.isPrimaryKey && field.autoIncrement) {
      buffer.write('.autoIncrement()');
    }

    if (field.isNullable) {
      buffer.write('.nullable()');
    }

    if (field.defaultValue != null) {
      buffer.write('.withDefault(${field.defaultValue})');
    }

    if (field.customConverter != null) {
      buffer.write('.map(${field.customConverter})');
    }

    if (field.columnName != field.dartName) {
      buffer.write(".named('${field.columnName}')");
    }

    buffer.writeln('();');
    buffer.writeln();

    return buffer.toString();
  }

  /// Generate IntListConverter for Many2many fields.
  String _generateIntListConverter() {
    return '''
/// Converter for List<int> to/from JSON string.
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      final list = jsonDecode(fromDb) as List;
      return list.cast<int>();
    } on FormatException {
      // Invalid JSON - return empty list
      return [];
    } on TypeError {
      // Invalid type cast - return empty list
      return [];
    }
  }

  @override
  String toSql(List<int> value) {
    return jsonEncode(value);
  }
}
''';
  }

  /// Generate JsonMapConverter for JSON fields.
  String _generateJsonMapConverter() {
    return '''
/// Converter for Map<String, dynamic> to/from JSON string.
class JsonMapConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonMapConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    if (fromDb.isEmpty) return {};
    try {
      return jsonDecode(fromDb) as Map<String, dynamic>;
    } on FormatException {
      // Invalid JSON - return empty map
      return {};
    } on TypeError {
      // Invalid type cast - return empty map
      return {};
    }
  }

  @override
  String toSql(Map<String, dynamic> value) {
    return jsonEncode(value);
  }
}
''';
  }

  /// Convert PascalCase to snake_case.
  String _toSnakeCase(String input) {
    final result = input.replaceAllMapped(
      RegExp('([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    );
    return result.startsWith('_') ? result.substring(1) : result;
  }
}

/// Internal field information for Drift tables.
class _DriftFieldInfo {
  final String dartName;
  final String columnName;
  final String driftType;
  final bool isNullable;
  final bool isPrimaryKey;
  final bool autoIncrement;
  final bool isIndex;
  final String? defaultValue;
  final String? customConverter;

  _DriftFieldInfo({
    required this.dartName,
    required this.columnName,
    required this.driftType,
    required this.isNullable,
    this.isPrimaryKey = false,
    this.autoIncrement = false,
    this.isIndex = false,
    this.defaultValue,
    this.customConverter,
  });
}
