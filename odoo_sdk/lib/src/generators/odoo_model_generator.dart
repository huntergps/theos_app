/// Code Generator for OdooModel annotated classes.
///
/// Generates:
/// - Concrete OdooModelManager implementation
/// - fromOdoo() conversion method
/// - toOdoo() serialization method
/// - List of Odoo field names
/// - Helper methods for ID/UUID management
///
/// Usage:
/// Run `dart run build_runner build` after annotating models.
library;

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../model/odoo_field_annotations.dart';

/// Builder factory for build_runner.
Builder odooModelBuilder(BuilderOptions options) =>
    SharedPartBuilder([OdooModelGenerator()], 'odoo_model');

/// Generator for @OdooModel annotated classes.
class OdooModelGenerator extends GeneratorForAnnotation<OdooModel> {
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
    final managerName = '${className}Manager';
    final tableName = annotation.peek('tableName')?.stringValue ??
        _toSnakeCase(className);
    final odooModel = annotation.read('modelName').stringValue;

    // Analyze fields
    final fields = _analyzeFields(classElement);

    // Extract SmartOdooModel annotations using shared constructor resolution
    final constructor = _resolveConstructor(classElement);

    final onchangeInfo =
        constructor != null ? _extractOnchangeInfo(constructor) : <_OnchangeInfo>[];
    final constraintInfo =
        constructor != null ? _extractConstraintInfo(constructor) : <_ConstraintInfo>[];
    final stateMachine = _extractStateMachine(classElement);
    final actionInfo = _extractActionInfo(classElement);
    final defaultInfo =
        constructor != null ? _extractDefaultInfo(constructor) : <_DefaultInfo>[];

    // Generate code
    final buffer = StringBuffer();

    // Generate Manager class
    buffer.writeln(_generateManagerClass(
      className: className,
      managerName: managerName,
      tableName: tableName,
      odooModel: odooModel,
      fields: fields,
      onchangeInfo: onchangeInfo,
      constraintInfo: constraintInfo,
      stateMachine: stateMachine,
      actionInfo: actionInfo,
      defaultInfo: defaultInfo,
    ));

    // Generate global instance
    buffer.writeln();
    buffer.writeln('/// Global instance of $managerName.');
    buffer.writeln('final ${_toCamelCase(managerName)} = $managerName();');

    return buffer.toString();
  }

  /// Resolve the best constructor for annotation scanning.
  ///
  /// Prefers: unnamed factory (Freezed) > any factory > first non-private with params.
  ConstructorElement? _resolveConstructor(ClassElement classElement) {
    // First, try to find the unnamed factory constructor (preferred for Freezed)
    for (final c in classElement.constructors) {
      if (c.isFactory && c.name == null) {
        return c;
      }
    }

    // Fallback: any factory constructor
    for (final c in classElement.constructors) {
      if (c.isFactory) {
        return c;
      }
    }

    // Fallback: first constructor with parameters (not the private one)
    for (final c in classElement.constructors) {
      if (c.name != '_' && c.formalParameters.isNotEmpty) {
        return c;
      }
    }

    return null;
  }

  /// Analyze fields from the class to extract Odoo field information.
  List<_FieldInfo> _analyzeFields(ClassElement classElement) {
    final fields = <_FieldInfo>[];
    final constructor = _resolveConstructor(classElement);

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

  /// Extract field information from a parameter.
  _FieldInfo? _extractFieldInfo(FormalParameterElement param) {
    final name = param.name;
    if (name == null || name.isEmpty) return null; // Skip unnamed parameters
    final type = param.type;

    for (final annotation in param.metadata.annotations) {
      final annotationType = annotation.computeConstantValue()?.type;
      if (annotationType == null) continue;

      final typeName = annotationType.getDisplayString();

      if (typeName == 'OdooId') {
        return _FieldInfo(
          dartName: name,
          odooName: 'id',
          dartType: type,
          fieldType: _OdooFieldType.id,
          isRequired: true,
          isWritable: false,
        );
      }

      if (typeName == 'OdooString') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.string,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooInteger') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.integer,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooFloat' || typeName == 'OdooMonetary') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.float,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooBoolean') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.boolean,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooDateTime') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.datetime,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooDate') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.date,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooMany2One') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.many2one,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
          relatedModel: reader.read('relatedModel').stringValue,
          storeDisplayName: reader.peek('storeDisplayName')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooMany2OneName') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.read('sourceField').stringValue,
          dartType: type,
          fieldType: _OdooFieldType.many2oneName,
          isRequired: false,
          isWritable: false,
        );
      }

      if (typeName == 'OdooOne2Many') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.one2many,
          isRequired: false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
          relatedModel: reader.read('relatedModel').stringValue,
        );
      }

      if (typeName == 'OdooMany2Many') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.many2many,
          isRequired: false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
          relatedModel: reader.read('relatedModel').stringValue,
        );
      }

      if (typeName == 'OdooSelection') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.selection,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooBinary') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.binary,
          isRequired: false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooHtml') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.html,
          isRequired: false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooJson') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.json,
          isRequired: false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooComputed') {
        final reader = ConstantReader(annotation.computeConstantValue());
        final dependsList = reader.peek('depends')?.listValue;
        final depends = dependsList
            ?.map((e) => e.toStringValue())
            .whereType<String>()
            .toList();
        return _FieldInfo(
          dartName: name,
          odooName: name,
          dartType: type,
          fieldType: _OdooFieldType.computed,
          isRequired: false,
          isWritable: false,
          isReadable: false,
          computeMethod: reader.peek('compute')?.stringValue,
          depends: depends,
        );
      }

      if (typeName == 'OdooStoredComputed') {
        final reader = ConstantReader(annotation.computeConstantValue());
        final dependsList = reader.peek('depends')?.listValue;
        final depends = dependsList
            ?.map((e) => e.toStringValue())
            .whereType<String>()
            .toList();
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.storedComputed,
          isRequired: false,
          isWritable: false,
          isReadable: true, // Synced from Odoo
          computeMethod: reader.read('compute').stringValue,
          depends: depends ?? [],
          precompute: reader.peek('precompute')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooRelated') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.related,
          isRequired: false,
          isWritable: false,
          isReadable: true,
          relatedPath: reader.read('related').stringValue,
        );
      }

      if (typeName == 'OdooReference') {
        final reader = ConstantReader(annotation.computeConstantValue());
        return _FieldInfo(
          dartName: name,
          odooName: reader.peek('odooName')?.stringValue ?? _toSnakeCase(name),
          dartType: type,
          fieldType: _OdooFieldType.reference,
          isRequired: reader.peek('required')?.boolValue ?? false,
          isWritable: reader.peek('writable')?.boolValue ?? true,
        );
      }

      if (typeName == 'OdooLocalOnly') {
        final reader = ConstantReader(annotation.computeConstantValue());
        final explicitDriftName = reader.peek('driftName')?.stringValue;
        return _FieldInfo(
          dartName: name,
          odooName: name,
          dartType: type,
          fieldType: _OdooFieldType.localOnly,
          isRequired: false,
          isWritable: false,
          isReadable: false,
          driftName: explicitDriftName,
        );
      }
    }

    return null;
  }

  /// Extract @OdooOnchange annotations from constructor parameters.
  List<_OnchangeInfo> _extractOnchangeInfo(ConstructorElement constructor) {
    final results = <_OnchangeInfo>[];
    for (final param in constructor.formalParameters) {
      for (final annotation in param.metadata.annotations) {
        final value = annotation.computeConstantValue();
        if (value == null) continue;
        final typeName = value.type?.getDisplayString();
        if (typeName != 'OdooOnchange') continue;

        final reader = ConstantReader(value);
        final fieldsList = reader
            .read('fields')
            .listValue
            .map((e) => e.toStringValue())
            .whereType<String>()
            .toList();
        final method = reader.read('method').stringValue;
        results.add(_OnchangeInfo(fields: fieldsList, method: method));
      }
    }
    return results;
  }

  /// Extract @OdooConstraint annotations from constructor parameters.
  List<_ConstraintInfo> _extractConstraintInfo(ConstructorElement constructor) {
    final results = <_ConstraintInfo>[];
    for (final param in constructor.formalParameters) {
      for (final annotation in param.metadata.annotations) {
        final value = annotation.computeConstantValue();
        if (value == null) continue;
        final typeName = value.type?.getDisplayString();
        if (typeName != 'OdooConstraint') continue;

        final reader = ConstantReader(value);
        final fieldsList = reader
            .read('fields')
            .listValue
            .map((e) => e.toStringValue())
            .whereType<String>()
            .toList();
        final method = reader.read('method').stringValue;
        final message = reader.peek('message')?.stringValue;
        results.add(_ConstraintInfo(
          fields: fieldsList,
          method: method,
          message: message,
        ));
      }
    }
    return results;
  }

  /// Extract @OdooStateMachine annotation from the class itself.
  _StateMachineInfo? _extractStateMachine(ClassElement classElement) {
    for (final annotation in classElement.metadata.annotations) {
      final value = annotation.computeConstantValue();
      if (value == null) continue;
      final typeName = value.type?.getDisplayString();
      if (typeName != 'OdooStateMachine') continue;

      final reader = ConstantReader(value);
      final stateField = reader.read('stateField').stringValue;
      final transitionsMap = reader.read('transitions').mapValue;

      final transitions = <String, List<String>>{};
      for (final entry in transitionsMap.entries) {
        final key = entry.key?.toStringValue();
        if (key == null) continue;
        final values = entry.value
                ?.toListValue()
                ?.map((e) => e.toStringValue())
                .whereType<String>()
                .toList() ??
            [];
        transitions[key] = values;
      }

      return _StateMachineInfo(
        stateField: stateField,
        transitions: transitions,
      );
    }
    return null;
  }

  /// Extract @OdooAction annotations from class methods.
  List<_ActionInfo> _extractActionInfo(ClassElement classElement) {
    final results = <_ActionInfo>[];
    for (final method in classElement.methods) {
      for (final annotation in method.metadata.annotations) {
        final value = annotation.computeConstantValue();
        if (value == null) continue;
        final typeName = value.type?.getDisplayString();
        if (typeName != 'OdooAction') continue;

        final reader = ConstantReader(value);
        final requiresStateList = reader.peek('requiresState')?.listValue;
        final requiresState = requiresStateList
            ?.map((e) => e.toStringValue())
            .whereType<String>()
            .toList();
        results.add(_ActionInfo(
          name: reader.read('name').stringValue,
          odooMethod: reader.peek('odooMethod')?.stringValue,
          validateFor: reader.peek('validateFor')?.stringValue,
          requiresState: requiresState,
          refreshAfter: reader.peek('refreshAfter')?.boolValue ?? true,
          queueOffline: reader.peek('queueOffline')?.boolValue ?? true,
        ));
      }
    }
    return results;
  }

  /// Extract @OdooDefault annotations from constructor parameters.
  List<_DefaultInfo> _extractDefaultInfo(ConstructorElement constructor) {
    final results = <_DefaultInfo>[];
    for (final param in constructor.formalParameters) {
      final name = param.name;
      if (name == null || name.isEmpty) continue;

      for (final annotation in param.metadata.annotations) {
        final value = annotation.computeConstantValue();
        if (value == null) continue;
        final typeName = value.type?.getDisplayString();
        if (typeName != 'OdooDefault') continue;

        final reader = ConstantReader(value);
        results.add(_DefaultInfo(
          dartName: name,
          method: reader.read('method').stringValue,
        ));
      }
    }
    return results;
  }

  /// Generate the Manager class.
  String _generateManagerClass({
    required String className,
    required String managerName,
    required String tableName,
    required String odooModel,
    required List<_FieldInfo> fields,
    List<_OnchangeInfo> onchangeInfo = const [],
    List<_ConstraintInfo> constraintInfo = const [],
    _StateMachineInfo? stateMachine,
    List<_ActionInfo> actionInfo = const [],
    List<_DefaultInfo> defaultInfo = const [],
  }) {
    final buffer = StringBuffer();

    buffer.writeln('/// Generated manager for $className.');
    buffer.writeln('///');
    buffer.writeln('/// Provides offline-first CRUD operations and sync');
    buffer.writeln('/// with Odoo model: $odooModel');
    buffer.writeln(
        'class $managerName extends OdooModelManager<$className> with GenericDriftOperations<$className> {');

    // Model metadata
    buffer.writeln('  @override');
    buffer.writeln("  String get odooModel => '$odooModel';");
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln("  String get tableName => '$tableName';");
    buffer.writeln();

    // Odoo fields list
    buffer.writeln('  @override');
    buffer.writeln('  List<String> get odooFields => [');
    for (final field in fields.where((f) => f.isReadable && !f.isLocalOnly)) {
      if (field.fieldType != _OdooFieldType.many2oneName) {
        buffer.writeln("    '${field.odooName}',");
      }
    }
    buffer.writeln('  ];');
    buffer.writeln();

    // fromOdoo conversion - fully generated
    buffer.writeln('  @override');
    buffer.writeln('  $className fromOdoo(Map<String, dynamic> data) {');
    buffer.writeln('    return $className(');
    buffer.write(_generateFromOdooBody(fields, className));
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // toOdoo conversion - fully generated
    buffer.writeln('  @override');
    buffer.writeln('  Map<String, dynamic> toOdoo($className record) {');
    buffer.writeln('    return {');
    buffer.write(_generateToOdooBody(fields));
    buffer.writeln('    };');
    buffer.writeln('  }');
    buffer.writeln();

    // fromDrift conversion - generated using field metadata
    buffer.writeln('  @override');
    buffer.writeln('  $className fromDrift(dynamic row) {');
    buffer.writeln('    return $className(');
    buffer.write(_generateFromDriftBody(fields));
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // getId - use odooId field for remote operations, fallback to id
    final idField = fields.firstWhere(
      (f) => f.fieldType == _OdooFieldType.id || f.dartName == 'odooId',
      orElse: () => fields.firstWhere(
        (f) => f.dartName == 'id',
        orElse: () => _FieldInfo(
          dartName: 'id',
          odooName: 'id',
          dartType: null,
          fieldType: _OdooFieldType.id,
          isRequired: true,
          isWritable: false,
        ),
      ),
    );
    buffer.writeln('  @override');
    buffer.writeln('  int getId($className record) => record.${idField.dartName};');
    buffer.writeln();

    // getUuid
    final uuidField = fields.firstWhere(
      (f) => f.dartName == 'uuid' || f.dartName == 'localUuid',
      orElse: () => _FieldInfo(
        dartName: 'id',
        odooName: 'id',
        dartType: null,
        fieldType: _OdooFieldType.id,
        isRequired: true,
        isWritable: false,
      ),
    );
    buffer.writeln('  @override');
    if (uuidField.dartName == 'uuid' || uuidField.dartName == 'localUuid') {
      buffer.writeln(
          '  String? getUuid($className record) => record.${uuidField.dartName};');
    } else {
      buffer.writeln('  String? getUuid($className record) => null;');
    }
    buffer.writeln();

    // withIdAndUuid
    buffer.writeln('  @override');
    buffer.writeln(
        '  $className withIdAndUuid($className record, int id, String uuid) {');
    buffer.writeln('    return record.copyWith(');
    buffer.writeln('      id: id,');
    if (uuidField.dartName == 'uuid' || uuidField.dartName == 'localUuid') {
      buffer.writeln('      ${uuidField.dartName}: uuid,');
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
    buffer.writeln();

    // withSyncStatus
    final isSyncedField = fields.firstWhere(
      (f) => f.dartName == 'isSynced' || f.dartName == 'synced',
      orElse: () => _FieldInfo(
        dartName: '',
        odooName: '',
        dartType: null,
        fieldType: _OdooFieldType.localOnly,
        isRequired: false,
        isWritable: false,
      ),
    );
    buffer.writeln('  @override');
    buffer.writeln(
        '  $className withSyncStatus($className record, bool isSynced) {');
    if (isSyncedField.dartName.isNotEmpty) {
      buffer.writeln('    return record.copyWith(');
      buffer.writeln('      ${isSyncedField.dartName}: isSynced,');
      buffer.writeln('    );');
    } else {
      buffer.writeln('    return record; // No sync status field');
    }
    buffer.writeln('  }');
    buffer.writeln();

    // Field mappings for WebSocket sync
    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln('  // Field Mappings for Sync');
    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  /// Map of Odoo field names to Dart field names.');
    buffer.writeln('  /// Used for WebSocket sync field-level updates.');
    buffer.writeln('  static const Map<String, String> fieldMappings = {');
    for (final field in fields.where((f) => f.isReadable && !f.isLocalOnly)) {
      if (field.fieldType != _OdooFieldType.many2oneName) {
        buffer.writeln("    '${field.odooName}': '${field.dartName}',");
      }
    }
    buffer.writeln('  };');
    buffer.writeln();
    buffer.writeln('  /// Get Dart field name from Odoo field name.');
    buffer.writeln('  String? getDartFieldName(String odooField) => fieldMappings[odooField];');
    buffer.writeln();
    buffer.writeln('  /// Get Odoo field name from Dart field name.');
    buffer.writeln('  String? getOdooFieldName(String dartField) {');
    buffer.writeln('    for (final entry in fieldMappings.entries) {');
    buffer.writeln('      if (entry.value == dartField) return entry.key;');
    buffer.writeln('    }');
    buffer.writeln('    return null;');
    buffer.writeln('  }');
    buffer.writeln();

    // GenericDriftOperations mixin overrides
    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln('  // GenericDriftOperations — Database & Table');
    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  GeneratedDatabase get database {');
    buffer.writeln('    final db = this.db;');
    buffer.writeln('    if (db == null) {');
    buffer.writeln("      throw StateError('Database not initialized. Call initialize() first.');");
    buffer.writeln('    }');
    buffer.writeln('    return db;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  TableInfo get table {');
    buffer.writeln('    final resolved = resolveTable();');
    buffer.writeln('    if (resolved == null) {');
    buffer.writeln("      throw StateError('Table \\'$tableName\\' not found in database.');");
    buffer.writeln('    }');
    buffer.writeln('    return resolved;');
    buffer.writeln('  }');
    buffer.writeln();

    // createDriftCompanion — returns a RawValuesInsertable map
    // Column keys must match SQL column names from the manual Drift tables:
    // - OdooId: 'odoo_id' (manual tables use id=autoIncrement + odoo_id=unique)
    // - OdooMany2OneName: '${sourceField}_name'
    // - OdooLocalOnly: _toSnakeCase(dartName)
    // - All others: field.odooName (matches drift table .named() or default)
    buffer.writeln('  @override');
    buffer.writeln('  dynamic createDriftCompanion($className record) {');
    buffer.writeln('    return RawValuesInsertable({');
    for (final field in fields.where((f) => !f.isLocalOnly)) {
      // Compute drift column name matching manual Drift table conventions
      final String driftColumn;
      if (field.fieldType == _OdooFieldType.id) {
        // Manual tables use 'odoo_id' column for the Odoo record ID
        // (the 'id' column is autoIncrement and managed by SQLite)
        driftColumn = 'odoo_id';
      } else if (field.fieldType == _OdooFieldType.many2oneName) {
        driftColumn = '${field.odooName}_name';
      } else {
        driftColumn = field.odooName;
      }
      // Map Dart types to Drift Value expressions.
      // Non-nullable fields use Variable<T>(value).
      // Nullable fields use driftVar<T>(value) helper which handles null→SQL NULL.
      final dn = field.dartName;
      switch (field.fieldType) {
        case _OdooFieldType.id:
          buffer.writeln("      '$driftColumn': Variable<int>(record.$dn),");
          break;
        case _OdooFieldType.string:
        case _OdooFieldType.html:
        case _OdooFieldType.binary:
          if (field.isNonNullable) {
            buffer.writeln("      '$driftColumn': Variable<String>(record.$dn),");
          } else {
            buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn),");
          }
          break;
        case _OdooFieldType.selection:
          if (field.isEnumType) {
            final acc = field.enumAccessor;
            if (field.isNonNullable) {
              buffer.writeln("      '$driftColumn': Variable<String>(record.$dn.$acc),");
            } else {
              buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn?.$acc),");
            }
          } else {
            if (field.isNonNullable) {
              buffer.writeln("      '$driftColumn': Variable<String>(record.$dn),");
            } else {
              buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn),");
            }
          }
          break;
        case _OdooFieldType.integer:
        case _OdooFieldType.many2one:
          if (field.isNonNullable) {
            buffer.writeln("      '$driftColumn': Variable<int>(record.$dn),");
          } else {
            buffer.writeln("      '$driftColumn': driftVar<int>(record.$dn),");
          }
          break;
        case _OdooFieldType.float:
          if (field.isNonNullable) {
            buffer.writeln("      '$driftColumn': Variable<double>(record.$dn),");
          } else {
            buffer.writeln("      '$driftColumn': driftVar<double>(record.$dn),");
          }
          break;
        case _OdooFieldType.boolean:
          buffer.writeln("      '$driftColumn': Variable<bool>(record.$dn),");
          break;
        case _OdooFieldType.datetime:
        case _OdooFieldType.date:
          if (field.isNonNullable) {
            buffer.writeln("      '$driftColumn': Variable<DateTime>(record.$dn),");
          } else {
            buffer.writeln("      '$driftColumn': driftVar<DateTime>(record.$dn),");
          }
          break;
        case _OdooFieldType.many2oneName:
          buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn),");
          break;
        case _OdooFieldType.json:
          final jsonTypeName = field.dartType?.getDisplayString() ?? 'dynamic';
          if (jsonTypeName.startsWith('Map')) {
            buffer.writeln("      '$driftColumn': driftVar<String>(toJsonString(record.$dn)),");
          } else {
            buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn),");
          }
          break;
        case _OdooFieldType.reference:
          if (field.isNonNullable) {
            buffer.writeln("      '$driftColumn': Variable<String>(record.$dn),");
          } else {
            buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn),");
          }
          break;
        case _OdooFieldType.storedComputed:
        case _OdooFieldType.related:
          buffer.writeln("      '$driftColumn': driftVar(record.$dn),");
          break;
        default:
          break;
      }
    }
    // Add local-only fields stored in Drift
    for (final field in fields.where((f) => f.isLocalOnly)) {
      final driftColumn = _toSnakeCase(field.driftAccessorName);
      final dn2 = field.dartName;
      final typeName = field.dartType?.getDisplayString() ?? 'dynamic';
      if (field.isEnumType) {
        final acc = field.enumAccessor;
        if (field.isNonNullable) {
          buffer.writeln("      '$driftColumn': Variable<String>(record.$dn2.$acc),");
        } else {
          buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn2?.$acc),");
        }
      } else if (typeName.startsWith('bool')) {
        if (field.isNonNullable) {
          buffer.writeln("      '$driftColumn': Variable<bool>(record.$dn2),");
        } else {
          buffer.writeln("      '$driftColumn': driftVar<bool>(record.$dn2),");
        }
      } else if (typeName.startsWith('int')) {
        if (field.isNonNullable) {
          buffer.writeln("      '$driftColumn': Variable<int>(record.$dn2),");
        } else {
          buffer.writeln("      '$driftColumn': driftVar<int>(record.$dn2),");
        }
      } else if (typeName.startsWith('double')) {
        if (field.isNonNullable) {
          buffer.writeln("      '$driftColumn': Variable<double>(record.$dn2),");
        } else {
          buffer.writeln("      '$driftColumn': driftVar<double>(record.$dn2),");
        }
      } else if (typeName.startsWith('String')) {
        if (field.isNonNullable) {
          buffer.writeln("      '$driftColumn': Variable<String>(record.$dn2),");
        } else {
          buffer.writeln("      '$driftColumn': driftVar<String>(record.$dn2),");
        }
      } else if (typeName.startsWith('DateTime')) {
        if (field.isNonNullable) {
          buffer.writeln("      '$driftColumn': Variable<DateTime>(record.$dn2),");
        } else {
          buffer.writeln("      '$driftColumn': driftVar<DateTime>(record.$dn2),");
        }
      }
      // Skip List and other complex types not stored in Drift
    }
    buffer.writeln('    });');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  /// List of writable fields for partial updates.');
    buffer.writeln('  static const List<String> writableFields = [');
    for (final field in fields.where((f) => f.isWritable)) {
      buffer.writeln("    '${field.dartName}',");
    }
    buffer.writeln('  ];');
    buffer.writeln();
    buffer.writeln('  /// List of required fields for validation.');
    buffer.writeln('  static const List<String> requiredFields = [');
    for (final field in fields.where((f) => f.isRequired)) {
      buffer.writeln("    '${field.dartName}',");
    }
    buffer.writeln('  ];');
    buffer.writeln();

    // Generate field labels for validation messages
    buffer.writeln('  /// Field labels for validation error messages.');
    buffer.writeln('  static const Map<String, String> fieldLabels = {');
    for (final field in fields) {
      final label = _toTitleCase(field.dartName);
      buffer.writeln("    '${field.dartName}': '$label',");
    }
    buffer.writeln('  };');
    buffer.writeln();

    // Generate automatic validation method
    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln('  // Automatic Validation');
    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('  /// Validate a record automatically based on field annotations.');
    buffer.writeln('  ///');
    buffer.writeln('  /// Returns a map of field -> error message for invalid fields.');
    buffer.writeln('  /// Empty map means the record is valid.');
    buffer.writeln('  Map<String, String> validateRecord($className record) {');
    buffer.writeln('    final errors = <String, String>{};');
    buffer.writeln();
    buffer.write(_generateValidationBody(fields, className));
    buffer.writeln('    return errors;');
    buffer.writeln('  }');
    buffer.writeln();
    buffer.writeln('  /// Check if a record is valid.');
    buffer.writeln('  bool isValid($className record) => validateRecord(record).isEmpty;');
    buffer.writeln();
    buffer.writeln('  /// Validate and throw if invalid.');
    buffer.writeln('  void ensureValid($className record) {');
    buffer.writeln('    final errors = validateRecord(record);');
    buffer.writeln('    if (errors.isNotEmpty) {');
    buffer.writeln('      throw ValidationException(errors);');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate computed field dependency graph
    final computedFields =
        fields.where((f) => f.isComputed && f.depends != null && f.depends!.isNotEmpty);
    if (computedFields.isNotEmpty) {
      buffer.writeln('  // ═══════════════════════════════════════════════════');
      buffer.writeln('  // Computed Field Dependencies (SmartOdooModel)');
      buffer.writeln('  // ═══════════════════════════════════════════════════');
      buffer.writeln();

      // Build reverse dependency graph: field -> [computed fields that depend on it]
      buffer.writeln('  /// Dependency graph: field -> list of computed fields that depend on it.');
      buffer.writeln('  /// Used by SmartOdooModel.recompute() to know what to recalculate.');
      buffer.writeln('  static const Map<String, List<String>> dependencyGraph = {');

      // Build the reverse graph
      final reverseGraph = <String, Set<String>>{};
      for (final field in computedFields) {
        for (final dep in field.depends!) {
          // Handle dot notation (e.g., 'orderLines.priceSubtotal' -> 'orderLines')
          final baseDep = dep.contains('.') ? dep.split('.').first : dep;
          reverseGraph.putIfAbsent(baseDep, () => <String>{});
          reverseGraph[baseDep]!.add(field.dartName);
        }
      }

      for (final entry in reverseGraph.entries) {
        final deps = entry.value.map((d) => "'$d'").join(', ');
        buffer.writeln("    '${entry.key}': [$deps],");
      }
      buffer.writeln('  };');
      buffer.writeln();

      // Generate list of computed fields with their compute methods
      buffer.writeln('  /// Map of computed field -> compute method name.');
      buffer.writeln('  static const Map<String, String> computeMethods = {');
      for (final field in computedFields) {
        if (field.computeMethod != null) {
          buffer.writeln("    '${field.dartName}': '${field.computeMethod}',");
        }
      }
      buffer.writeln('  };');
      buffer.writeln();

      // Generate list of fields that should be precomputed before save
      final precomputeFields = computedFields.where((f) => f.precompute);
      if (precomputeFields.isNotEmpty) {
        buffer.writeln('  /// Fields that should be computed before saving.');
        buffer.writeln('  static const List<String> precomputeFields = [');
        for (final field in precomputeFields) {
          buffer.writeln("    '${field.dartName}',");
        }
        buffer.writeln('  ];');
        buffer.writeln();
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // SmartOdooModel Override Generation
    // ═══════════════════════════════════════════════════════════════════════

    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln('  // SmartOdooModel Support Overrides');
    buffer.writeln('  // ═══════════════════════════════════════════════════');
    buffer.writeln();

    // --- getRecordFieldValue (always generated) ---
    buffer.writeln('  @override');
    buffer.writeln('  dynamic getRecordFieldValue($className record, String fieldName) {');
    buffer.writeln('    switch (fieldName) {');
    for (final field in fields) {
      buffer.writeln("      case '${field.dartName}': return record.${field.dartName};");
    }
    buffer.writeln('      default: return null;');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();

    // --- applyWebSocketChangesToRecord (always generated) ---
    buffer.writeln('  @override');
    buffer.writeln(
        '  $className applyWebSocketChangesToRecord($className record, Map<String, dynamic> changes) {');
    buffer.writeln('    final current = toOdoo(record);');
    buffer.writeln('    current.addAll(changes);');
    buffer.writeln('    current[\'id\'] = getId(record);');
    buffer.writeln('    var updated = fromOdoo(current);');
    // Preserve local-only fields that are lost by toOdoo/fromOdoo round-trip
    final localFields = fields.where((f) => f.fieldType == _OdooFieldType.localOnly);
    if (localFields.isNotEmpty) {
      buffer.writeln('    // Preserve local-only fields from original record');
      buffer.writeln('    updated = updated.copyWith(');
      for (final field in localFields) {
        buffer.writeln('      ${field.dartName}: record.${field.dartName},');
      }
      buffer.writeln('    );');
    }
    buffer.writeln('    return updated;');
    buffer.writeln('  }');
    buffer.writeln();

    // --- dispatchOnchange (only if onchangeInfo is not empty) ---
    if (onchangeInfo.isNotEmpty) {
      buffer.writeln('  @override');
      buffer.writeln(
          '  $className dispatchOnchange($className record, String field, dynamic value) {');
      buffer.writeln('    switch (field) {');
      for (final info in onchangeInfo) {
        for (final f in info.fields) {
          buffer.writeln("      case '$f': return record.${info.method}();");
        }
      }
      buffer.writeln('      default: return record;');
      buffer.writeln('    }');
      buffer.writeln('  }');
      buffer.writeln();
    }

    // --- validateConstraintsFor (only if constraintInfo is not empty) ---
    if (constraintInfo.isNotEmpty) {
      buffer.writeln('  @override');
      buffer.writeln(
          '  Map<String, String> validateConstraintsFor($className record, Set<String> changedFields) {');
      buffer.writeln('    final errors = <String, String>{};');
      for (final info in constraintInfo) {
        final fieldsList = info.fields.map((f) => "'$f'").join(', ');
        buffer.writeln(
            '    if (changedFields.any((f) => const [$fieldsList].contains(f))) {');
        buffer.writeln('      final error = record.${info.method}();');
        buffer.writeln('      if (error != null) errors[\'${info.method}\'] = error;');
        buffer.writeln('    }');
      }
      buffer.writeln('    return errors;');
      buffer.writeln('  }');
      buffer.writeln();
    }

    // --- State machine (only if stateMachine is not null) ---
    if (stateMachine != null) {
      buffer.writeln('  @override');
      buffer.writeln("  String? get stateField => '${stateMachine.stateField}';");
      buffer.writeln();
      buffer.writeln('  @override');
      buffer.writeln('  Map<String, List<String>> get stateTransitionMap => const {');
      for (final entry in stateMachine.transitions.entries) {
        final values = entry.value.map((v) => "'$v'").join(', ');
        buffer.writeln("    '${entry.key}': [$values],");
      }
      buffer.writeln('  };');
      buffer.writeln();
    }

    // --- onchangeHandlerMap (only if onchangeInfo is not empty) ---
    if (onchangeInfo.isNotEmpty) {
      buffer.writeln('  @override');
      buffer.writeln('  Map<String, String> get onchangeHandlerMap => const {');
      for (final info in onchangeInfo) {
        for (final f in info.fields) {
          buffer.writeln("    '$f': '${info.method}',");
        }
      }
      buffer.writeln('  };');
      buffer.writeln();
    }

    // --- constraintFieldsMap (only if constraintInfo is not empty) ---
    if (constraintInfo.isNotEmpty) {
      buffer.writeln('  @override');
      buffer.writeln(
          '  Map<String, List<String>> get constraintFieldsMap => const {');
      for (final info in constraintInfo) {
        final fieldsList = info.fields.map((f) => "'$f'").join(', ');
        buffer.writeln("    '${info.method}': [$fieldsList],");
      }
      buffer.writeln('  };');
      buffer.writeln();
    }

    // --- accessProperty override (for domain filtering on any field) ---
    buffer.writeln('  @override');
    buffer.writeln('  dynamic accessProperty(dynamic obj, String name) {');
    buffer.writeln('    switch (name) {');
    for (final field in fields) {
      // Case key uses the name passed as parameter (Dart field name or 'odooId')
      final caseName = field.fieldType == _OdooFieldType.id ? 'odooId' : field.dartName;
      // Accessor uses the Drift column name (may differ from Dart field name)
      final driftAccessor = field.fieldType == _OdooFieldType.id ? 'odooId' : field.driftAccessorName;
      buffer.writeln("      case '$caseName': return (obj as dynamic).$driftAccessor;");
    }
    // Also add standard local fields that might not be in the model fields list
    final knownNames = fields.map((f) => f.fieldType == _OdooFieldType.id ? 'odooId' : f.dartName).toSet();
    for (final standard in ['odooId', 'writeDate', 'isSynced', 'uuid', 'localCreatedAt']) {
      if (!knownNames.contains(standard)) {
        buffer.writeln("      case '$standard': return (obj as dynamic).$standard;");
      }
    }
    buffer.writeln('      default: return super.accessProperty(obj, name);');
    buffer.writeln('    }');
    buffer.writeln('  }');
    buffer.writeln();

    // --- computedFieldNames (always generated) ---
    final computedFieldsForList = fields.where((f) => f.isComputed);
    buffer.writeln('  @override');
    buffer.writeln('  List<String> get computedFieldNames => const [');
    for (final field in computedFieldsForList) {
      buffer.writeln("    '${field.dartName}',");
    }
    buffer.writeln('  ];');
    buffer.writeln();

    // --- storedFieldNames (always generated) ---
    // All fields except non-stored computed fields
    final storedFieldsForList = fields.where(
        (f) => f.fieldType != _OdooFieldType.computed);
    buffer.writeln('  @override');
    buffer.writeln('  List<String> get storedFieldNames => const [');
    for (final field in storedFieldsForList) {
      buffer.writeln("    '${field.dartName}',");
    }
    buffer.writeln('  ];');
    buffer.writeln();

    // --- writableFieldNames (always generated) ---
    buffer.writeln('  @override');
    buffer.writeln('  List<String> get writableFieldNames => const [');
    for (final field in fields.where((f) => f.isWritable)) {
      buffer.writeln("    '${field.dartName}',");
    }
    buffer.writeln('  ];');
    buffer.writeln();

    // --- Typed action methods (Item 12: @OdooAction) ---
    if (actionInfo.isNotEmpty) {
      buffer.writeln('  // ═══════════════════════════════════════════════════');
      buffer.writeln('  // Typed Action Methods');
      buffer.writeln('  // ═══════════════════════════════════════════════════');
      buffer.writeln();

      for (final action in actionInfo) {
        buffer.writeln('  /// Execute ${action.name} action on a record.');
        buffer.writeln('  Future<$className?> action${action.pascalName}($className record) async {');

        // State guard
        if (action.requiresState != null && action.requiresState!.isNotEmpty) {
          final states = action.requiresState!.map((s) => "'$s'").join(', ');
          buffer.writeln('    final currentState = getRecordFieldValue(record, stateField ?? \'state\') as String?;');
          buffer.writeln('    if (currentState != null && !const [$states].contains(currentState)) {');
          buffer.writeln("      throw StateError('Cannot execute ${action.name} from state \$currentState');");
          buffer.writeln('    }');
        }

        // Validation
        if (action.validateFor != null) {
          buffer.writeln('    final errors = validateRecord(record);');
          buffer.writeln('    if (errors.isNotEmpty) {');
          buffer.writeln('      throw ValidationException(errors);');
          buffer.writeln('    }');
        }

        buffer.writeln('    final id = getId(record);');
        buffer.writeln("    await callOdooAction(id, '${action.effectiveOdooMethod}');");

        if (action.refreshAfter) {
          buffer.writeln('    return readLocal(id);');
        } else {
          buffer.writeln('    return record;');
        }

        buffer.writeln('  }');
        buffer.writeln();
      }
    }

    // --- applyDefaults (Item 13: @OdooDefault) ---
    if (defaultInfo.isNotEmpty) {
      buffer.writeln('  // ═══════════════════════════════════════════════════');
      buffer.writeln('  // Default Values');
      buffer.writeln('  // ═══════════════════════════════════════════════════');
      buffer.writeln();
      buffer.writeln('  /// Apply default values to a record.');
      buffer.writeln('  ///');
      buffer.writeln('  /// Call before create() to fill in fields with @OdooDefault annotations.');
      buffer.writeln('  $className applyDefaults($className record) {');
      buffer.writeln('    return record.copyWith(');
      for (final def in defaultInfo) {
        buffer.writeln('      ${def.dartName}: record.${def.dartName} ?? $className.${def.method}(),');
      }
      buffer.writeln('    );');
      buffer.writeln('  }');
      buffer.writeln();
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Convert PascalCase to snake_case.
  String _toSnakeCase(String input) {
    final result = input.replaceAllMapped(
      RegExp('([A-Z])'),
      (match) => '_${match.group(1)!.toLowerCase()}',
    );
    return result.startsWith('_') ? result.substring(1) : result;
  }

  /// Convert PascalCase to camelCase.
  String _toCamelCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toLowerCase() + input.substring(1);
  }

  /// Convert camelCase to Title Case with spaces.
  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    final withSpaces = input.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }

  /// Generate the validation body.
  String _generateValidationBody(List<_FieldInfo> fields, String className) {
    final buffer = StringBuffer();

    // Validate required fields
    final requiredFields = fields.where((f) => f.isRequired && f.fieldType != _OdooFieldType.id);
    for (final field in requiredFields) {
      final dartName = field.dartName;
      final label = _toTitleCase(dartName);

      switch (field.fieldType) {
        case _OdooFieldType.string:
        case _OdooFieldType.html:
        case _OdooFieldType.selection:
          buffer.writeln("    if (record.$dartName == null || record.$dartName!.isEmpty) {");
          buffer.writeln("      errors['$dartName'] = '$label is required';");
          buffer.writeln('    }');
          break;

        case _OdooFieldType.integer:
        case _OdooFieldType.float:
        case _OdooFieldType.many2one:
          buffer.writeln("    if (record.$dartName == null || record.$dartName == 0) {");
          buffer.writeln("      errors['$dartName'] = '$label is required';");
          buffer.writeln('    }');
          break;

        case _OdooFieldType.datetime:
        case _OdooFieldType.date:
        case _OdooFieldType.binary:
        case _OdooFieldType.json:
          buffer.writeln("    if (record.$dartName == null) {");
          buffer.writeln("      errors['$dartName'] = '$label is required';");
          buffer.writeln('    }');
          break;

        case _OdooFieldType.reference:
          buffer.writeln("    if (record.$dartName == null || record.$dartName!.isEmpty) {");
          buffer.writeln("      errors['$dartName'] = '$label is required';");
          buffer.writeln('    }');
          break;

        case _OdooFieldType.one2many:
        case _OdooFieldType.many2many:
          buffer.writeln("    if (record.$dartName == null || record.$dartName!.isEmpty) {");
          buffer.writeln("      errors['$dartName'] = '$label requires at least one item';");
          buffer.writeln('    }');
          break;

        default:
          // Skip boolean, id, computed, etc.
          break;
      }
    }

    return buffer.toString();
  }

  /// Generate the body of fromDrift method.
  ///
  /// Uses dynamic access to read columns from the Drift row object.
  /// Column names follow the snake_case convention from the Drift table.
  String _generateFromDriftBody(List<_FieldInfo> fields) {
    final buffer = StringBuffer();

    for (final field in fields) {
      final dartName = field.dartName;
      // Drift column accessor: uses driftAccessorName which resolves
      // explicit driftName > camelCase(odooName) > dartName
      // For the 'id' field annotated with @OdooId, the Drift column is 'odooId'
      final driftAccessor =
          field.fieldType == _OdooFieldType.id ? 'odooId' : field.driftAccessorName;

      String conversion;

      switch (field.fieldType) {
        case _OdooFieldType.id:
          conversion = 'row.$driftAccessor as int';
          break;
        case _OdooFieldType.string:
        case _OdooFieldType.html:
        case _OdooFieldType.binary:
          if (field.isNonNullable) {
            conversion = 'row.$driftAccessor as String';
          } else {
            conversion = 'row.$driftAccessor as String?';
          }
          break;
        case _OdooFieldType.selection:
          if (field.isEnumType) {
            final enumName = field.enumTypeName!;
            final acc = field.enumAccessor;
            if (field.isNonNullable) {
              conversion =
                  "$enumName.values.firstWhere((e) => e.$acc == (row.$driftAccessor as String?), orElse: () => $enumName.values.first)";
            } else {
              conversion =
                  "(row.$driftAccessor as String?) != null ? $enumName.values.firstWhere((e) => e.$acc == (row.$driftAccessor as String?), orElse: () => $enumName.values.first) : null";
            }
          } else {
            if (field.isNonNullable) {
              conversion = 'row.$driftAccessor as String';
            } else {
              conversion = 'row.$driftAccessor as String?';
            }
          }
          break;
        case _OdooFieldType.integer:
        case _OdooFieldType.many2one:
          if (field.isNonNullable) {
            conversion = 'row.$driftAccessor as int';
          } else {
            conversion = 'row.$driftAccessor as int?';
          }
          break;
        case _OdooFieldType.float:
          if (field.isNonNullable) {
            conversion = 'row.$driftAccessor as double';
          } else {
            conversion = 'row.$driftAccessor as double?';
          }
          break;
        case _OdooFieldType.boolean:
          conversion = 'row.$driftAccessor as bool';
          break;
        case _OdooFieldType.datetime:
        case _OdooFieldType.date:
          if (field.isNonNullable) {
            conversion = 'row.$driftAccessor as DateTime';
          } else {
            conversion = 'row.$driftAccessor as DateTime?';
          }
          break;
        case _OdooFieldType.many2oneName:
          conversion = 'row.$driftAccessor as String?';
          break;
        case _OdooFieldType.localOnly:
          // Read local-only fields from Drift based on their Dart type
          if (field.isEnumType) {
            final enumName = field.enumTypeName!;
            final acc = field.enumAccessor;
            if (field.isNonNullable) {
              conversion =
                  "(row.$driftAccessor as String?) != null ? $enumName.values.firstWhere((e) => e.$acc == (row.$driftAccessor as String?), orElse: () => $enumName.values.first) : $enumName.values.first";
            } else {
              conversion =
                  "(row.$driftAccessor as String?) != null ? $enumName.values.firstWhere((e) => e.$acc == (row.$driftAccessor as String?), orElse: () => $enumName.values.first) : null";
            }
          } else {
            final typeName = field.dartType?.getDisplayString() ?? 'dynamic';
            if (typeName.startsWith('bool')) {
              conversion = field.isNonNullable
                  ? 'row.$driftAccessor as bool? ?? false'
                  : 'row.$driftAccessor as bool?';
            } else if (typeName.startsWith('int')) {
              conversion = field.isNonNullable
                  ? 'row.$driftAccessor as int? ?? 0'
                  : 'row.$driftAccessor as int?';
            } else if (typeName.startsWith('double')) {
              conversion = field.isNonNullable
                  ? 'row.$driftAccessor as double? ?? 0.0'
                  : 'row.$driftAccessor as double?';
            } else if (typeName.startsWith('String')) {
              conversion = field.isNonNullable
                  ? "row.$driftAccessor as String? ?? ''"
                  : 'row.$driftAccessor as String?';
            } else if (typeName.startsWith('DateTime')) {
              conversion = field.isNonNullable
                  ? 'row.$driftAccessor as DateTime? ?? DateTime.now()'
                  : 'row.$driftAccessor as DateTime?';
            } else if (typeName.startsWith('List')) {
              continue; // Lists not stored in Drift
            } else {
              conversion = 'row.$driftAccessor';
            }
          }
          break;
        case _OdooFieldType.storedComputed:
        case _OdooFieldType.related:
          // These are stored in Drift, try to read them
          conversion = 'row.$driftAccessor';
          break;
        case _OdooFieldType.reference:
          if (field.isNonNullable) {
            conversion = 'row.$driftAccessor as String';
          } else {
            conversion = 'row.$driftAccessor as String?';
          }
          break;
        case _OdooFieldType.one2many:
        case _OdooFieldType.many2many:
        case _OdooFieldType.computed:
          // Not stored in Drift
          continue;
        case _OdooFieldType.json:
          final jsonTypeName = field.dartType?.getDisplayString() ?? 'dynamic';
          if (jsonTypeName.startsWith('Map')) {
            // Stored as JSON string in Drift, parse back to Map
            conversion = 'parseOdooJson(row.$driftAccessor)';
          } else {
            conversion = 'row.$driftAccessor as String?';
          }
          break;
      }

      buffer.writeln('      $dartName: $conversion,');
    }

    return buffer.toString();
  }

  /// Generate the body of fromOdoo method.
  String _generateFromOdooBody(List<_FieldInfo> fields, String className) {
    final buffer = StringBuffer();

    for (final field in fields) {
      // Skip pure computed fields (no Odoo source)
      if (field.fieldType == _OdooFieldType.computed) continue;

      // Local-only fields: provide defaults for required ones, skip nullable
      if (field.fieldType == _OdooFieldType.localOnly) {
        if (field.isNonNullable) {
          final defaultVal = _getLocalOnlyDefault(field);
          buffer.writeln("      ${field.dartName}: $defaultVal,");
        }
        continue;
      }

      final dartName = field.dartName;
      final odooName = field.odooName;
      String conversion;

      switch (field.fieldType) {
        case _OdooFieldType.id:
          conversion = "data['$odooName'] as int? ?? 0";
          break;

        case _OdooFieldType.string:
        case _OdooFieldType.html:
        case _OdooFieldType.binary:
          if (field.isNonNullable) {
            conversion = "parseOdooStringRequired(data['$odooName'])";
          } else {
            conversion = "parseOdooString(data['$odooName'])";
          }
          break;

        case _OdooFieldType.integer:
          if (field.isNonNullable) {
            conversion = "parseOdooInt(data['$odooName']) ?? 0";
          } else {
            conversion = "parseOdooInt(data['$odooName'])";
          }
          break;

        case _OdooFieldType.float:
          if (field.isNonNullable) {
            conversion = "parseOdooDouble(data['$odooName']) ?? 0.0";
          } else {
            conversion = "parseOdooDouble(data['$odooName'])";
          }
          break;

        case _OdooFieldType.boolean:
          conversion = "parseOdooBool(data['$odooName'])";
          break;

        case _OdooFieldType.datetime:
          if (field.isNonNullable) {
            conversion =
                "parseOdooDateTime(data['$odooName']) ?? DateTime(1970)";
          } else {
            conversion = "parseOdooDateTime(data['$odooName'])";
          }
          break;

        case _OdooFieldType.date:
          if (field.isNonNullable) {
            conversion =
                "parseOdooDate(data['$odooName']) ?? DateTime(1970)";
          } else {
            conversion = "parseOdooDate(data['$odooName'])";
          }
          break;

        case _OdooFieldType.many2one:
          if (field.isNonNullable) {
            conversion = "extractMany2oneId(data['$odooName']) ?? 0";
          } else {
            conversion = "extractMany2oneId(data['$odooName'])";
          }
          break;

        case _OdooFieldType.many2oneName:
          // For display name, extract from the source field (which is a tuple)
          conversion = "extractMany2oneName(data['$odooName'])";
          break;

        case _OdooFieldType.one2many:
        case _OdooFieldType.many2many:
          conversion = "extractMany2manyIds(data['$odooName'])";
          break;

        case _OdooFieldType.selection:
          if (field.isEnumType) {
            final enumName = field.enumTypeName!;
            final acc = field.enumAccessor;
            final selVal = "parseOdooSelection(data['$odooName'])";
            if (field.isNonNullable) {
              conversion =
                  "$enumName.values.firstWhere((e) => e.$acc == $selVal, orElse: () => $enumName.values.first)";
            } else {
              conversion =
                  "$selVal != null ? $enumName.values.firstWhere((e) => e.$acc == $selVal, orElse: () => $enumName.values.first) : null";
            }
          } else {
            if (field.isNonNullable) {
              conversion = "parseOdooSelection(data['$odooName']) ?? ''";
            } else {
              conversion = "parseOdooSelection(data['$odooName'])";
            }
          }
          break;

        case _OdooFieldType.json:
          // Check actual Dart type to decide conversion
          final jsonTypeName = field.dartType?.getDisplayString() ?? 'dynamic';
          if (jsonTypeName.startsWith('String')) {
            // JSON stored as String — serialize the raw value
            conversion = "data['$odooName']?.toString()";
          } else {
            conversion = "parseOdooJson(data['$odooName'])";
          }
          break;

        case _OdooFieldType.storedComputed:
          // Stored computed fields are read from Odoo
          conversion = _getConversionForDartType(field, odooName);
          break;

        case _OdooFieldType.related:
          // Related fields are read from Odoo
          conversion = _getConversionForDartType(field, odooName);
          break;

        case _OdooFieldType.reference:
          // Reference fields store "model,id" format as String
          conversion = "parseOdooString(data['$odooName'])";
          break;

        case _OdooFieldType.localOnly:
        case _OdooFieldType.computed:
          // Already skipped above
          continue;
      }

      buffer.writeln("      $dartName: $conversion,");
    }

    return buffer.toString();
  }

  /// Get default value expression for a required local-only field in fromOdoo.
  String _getLocalOnlyDefault(_FieldInfo field) {
    if (field.isEnumType) {
      return '${field.enumTypeName}.values.first';
    }
    final typeName = field.dartType?.getDisplayString() ?? 'String';
    if (typeName.startsWith('String')) return "''";
    if (typeName.startsWith('int')) return '0';
    if (typeName.startsWith('double')) return '0.0';
    if (typeName.startsWith('bool')) return 'false';
    if (typeName.startsWith('DateTime')) return 'DateTime.now()';
    if (typeName.startsWith('List')) return 'const []';
    return "''";
  }

  /// Get conversion expression based on Dart type (for stored computed/related).
  String _getConversionForDartType(_FieldInfo field, String odooName) {
    final dartType = field.dartType;
    if (dartType == null) return "data['$odooName']";

    final typeName = dartType.getDisplayString();

    if (typeName == 'int' || typeName == 'int?') {
      return "parseOdooInt(data['$odooName'])";
    }
    if (typeName == 'double' || typeName == 'double?') {
      return "parseOdooDouble(data['$odooName'])";
    }
    if (typeName == 'bool' || typeName == 'bool?') {
      return "parseOdooBool(data['$odooName'])";
    }
    if (typeName == 'String' || typeName == 'String?') {
      return "parseOdooString(data['$odooName'])";
    }
    if (typeName == 'DateTime' || typeName == 'DateTime?') {
      return "parseOdooDateTime(data['$odooName'])";
    }
    if (typeName.startsWith('List<int>')) {
      return "extractMany2manyIds(data['$odooName'])";
    }
    if (typeName.startsWith('Map<')) {
      return "parseOdooJson(data['$odooName'])";
    }

    // Default: cast as-is
    return "data['$odooName'] as $typeName";
  }

  /// Generate the body of toOdoo method.
  String _generateToOdooBody(List<_FieldInfo> fields) {
    final buffer = StringBuffer();

    for (final field in fields) {
      // Skip non-writable fields
      if (!field.isWritable) continue;
      // Skip local-only fields
      if (field.fieldType == _OdooFieldType.localOnly) continue;
      // Skip computed fields (they're not sent to Odoo)
      if (field.fieldType == _OdooFieldType.computed) continue;
      if (field.fieldType == _OdooFieldType.storedComputed) continue;
      // Skip id field (not sent on create/write)
      if (field.fieldType == _OdooFieldType.id) continue;
      // Skip many2oneName (display name, not writable)
      if (field.fieldType == _OdooFieldType.many2oneName) continue;

      final dartName = field.dartName;
      final odooName = field.odooName;
      String conversion;

      switch (field.fieldType) {
        case _OdooFieldType.string:
        case _OdooFieldType.integer:
        case _OdooFieldType.float:
        case _OdooFieldType.boolean:
        case _OdooFieldType.binary:
        case _OdooFieldType.html:
          // Direct assignment
          conversion = "record.$dartName";
          break;

        case _OdooFieldType.selection:
          if (field.isEnumType) {
            final acc = field.enumAccessor;
            final nullDot = field.isNonNullable ? '.' : '?.';
            conversion = "record.$dartName$nullDot$acc";
          } else {
            conversion = "record.$dartName";
          }
          break;

        case _OdooFieldType.json:
          final jsonTypeName = field.dartType?.getDisplayString() ?? 'dynamic';
          if (jsonTypeName.startsWith('Map')) {
            conversion = "toJsonString(record.$dartName)";
          } else {
            conversion = "record.$dartName";
          }
          break;

        case _OdooFieldType.datetime:
          conversion = "formatOdooDateTime(record.$dartName)";
          break;

        case _OdooFieldType.date:
          conversion = "formatOdooDate(record.$dartName)";
          break;

        case _OdooFieldType.many2one:
          // Send just the ID
          conversion = "record.$dartName";
          break;

        case _OdooFieldType.one2many:
          // One2many requires command format for modifications
          // For simple sync, we skip or use replace command
          conversion = "record.$dartName";
          break;

        case _OdooFieldType.many2many:
          // Use replace command format: [[6, 0, ids]]
          conversion = "buildMany2manyReplace(record.$dartName ?? [])";
          break;

        case _OdooFieldType.related:
          // Related fields are typically readonly
          continue;

        case _OdooFieldType.reference:
          // Reference fields: "model,id" string
          conversion = "record.$dartName";
          break;

        case _OdooFieldType.id:
        case _OdooFieldType.many2oneName:
        case _OdooFieldType.computed:
        case _OdooFieldType.storedComputed:
        case _OdooFieldType.localOnly:
          // Already filtered above
          continue;
      }

      buffer.writeln("      '$odooName': $conversion,");
    }

    return buffer.toString();
  }
}

/// Internal field type enum.
enum _OdooFieldType {
  id,
  string,
  integer,
  float,
  boolean,
  datetime,
  date,
  many2one,
  many2oneName,
  one2many,
  many2many,
  selection,
  binary,
  html,
  json,
  computed,
  storedComputed,
  localOnly,
  related,
  reference,
}

/// Internal field information.
class _FieldInfo {
  final String dartName;
  final String odooName;
  final DartType? dartType;
  final _OdooFieldType fieldType;
  final bool isRequired;
  final bool isWritable;
  final bool isReadable;
  final String? relatedModel;
  final bool storeDisplayName;

  // For computed fields
  final String? computeMethod;
  final List<String>? depends;
  final bool precompute;

  // For related fields
  final String? relatedPath;

  // Override for Drift column accessor name (when it differs from dartName)
  final String? driftName;

  _FieldInfo({
    required this.dartName,
    required this.odooName,
    required this.dartType,
    required this.fieldType,
    required this.isRequired,
    required this.isWritable,
    this.isReadable = true,
    this.relatedModel,
    this.storeDisplayName = false,
    this.computeMethod,
    this.depends,
    this.precompute = true,
    this.relatedPath,
    this.driftName,
  });

  /// The Drift column accessor name to use in fromDrift/accessProperty.
  ///
  /// Priority: explicit driftName > camelCase(odooName) if different from dartName > dartName
  /// Exception: Many2OneName uses dartName (odooName is sourceField, not column name)
  /// Exception: localOnly uses dartName unless driftName is explicit
  String get driftAccessorName {
    if (driftName != null) return driftName!;
    // Many2OneName: odooName is the sourceField (e.g. 'country_id'), not the column name
    // The Drift column matches dartName (e.g. 'countryName')
    if (fieldType == _OdooFieldType.many2oneName) return dartName;
    // LocalOnly: odooName defaults to dartName, no Odoo mapping to derive from
    if (fieldType == _OdooFieldType.localOnly) return dartName;
    // For regular Odoo fields, the Drift column matches camelCase(odooName)
    final camelOdoo = _snakeToCamel(odooName);
    if (camelOdoo != dartName && fieldType != _OdooFieldType.id) {
      return camelOdoo;
    }
    return dartName;
  }

  static String _snakeToCamel(String snake) {
    final parts = snake.split('_');
    return parts.first + parts.skip(1).map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}').join();
  }

  /// Whether the Dart type is non-nullable (e.g., `String` vs `String?`).
  ///
  /// Used by fromOdoo/fromDrift generation to decide whether to add
  /// null-safety fallbacks (e.g., `?? DateTime(1970)`, `?? ''`).
  bool get isNonNullable =>
      dartType != null &&
      dartType!.nullabilitySuffix == NullabilitySuffix.none;

  /// Whether the Dart type is an enum (for @OdooSelection fields).
  bool get isEnumType {
    final dt = dartType;
    if (dt == null) return false;
    return dt.element is EnumElement;
  }

  /// The enum type name (e.g., 'AdvanceState') for code generation.
  String? get enumTypeName {
    if (!isEnumType) return null;
    return dartType!.element!.name;
  }

  /// Whether the enum has a `code` field (enhanced enum with String code property).
  bool get hasCodeField {
    if (!isEnumType) return false;
    final enumElement = dartType!.element as EnumElement;
    return enumElement.fields.any((f) => f.name == 'code' && !f.isEnumConstant);
  }

  /// The accessor to convert enum to/from String ('.code' or '.name').
  String get enumAccessor => hasCodeField ? 'code' : 'name';

  bool get isLocalOnly =>
      fieldType == _OdooFieldType.localOnly ||
      fieldType == _OdooFieldType.computed;

  bool get isComputed =>
      fieldType == _OdooFieldType.computed ||
      fieldType == _OdooFieldType.storedComputed;
}

/// Onchange annotation info extracted from a field parameter.
class _OnchangeInfo {
  final List<String> fields;
  final String method;
  _OnchangeInfo({required this.fields, required this.method});
}

/// Constraint annotation info extracted from a field parameter.
class _ConstraintInfo {
  final List<String> fields;
  final String method;
  final String? message;
  _ConstraintInfo({required this.fields, required this.method, this.message});
}

/// State machine annotation info extracted from the class.
class _StateMachineInfo {
  final String stateField;
  final Map<String, List<String>> transitions;
  _StateMachineInfo({required this.stateField, required this.transitions});
}

/// Action annotation info extracted from methods.
class _ActionInfo {
  final String name;
  final String? odooMethod;
  final String? validateFor;
  final List<String>? requiresState;
  final bool refreshAfter;
  final bool queueOffline;
  _ActionInfo({
    required this.name,
    this.odooMethod,
    this.validateFor,
    this.requiresState,
    this.refreshAfter = true,
    this.queueOffline = true,
  });

  String get pascalName => name[0].toUpperCase() + name.substring(1);
  String get effectiveOdooMethod => odooMethod ?? 'action_$name';
}

/// Default annotation info extracted from constructor parameters.
class _DefaultInfo {
  final String dartName;
  final String method;
  _DefaultInfo({required this.dartName, required this.method});
}
