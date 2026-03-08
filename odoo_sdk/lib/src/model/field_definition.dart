/// Field Definition System for Model Management
///
/// Provides runtime introspection of model fields, similar to Odoo's fields.*
/// Used for:
/// - Automatic form generation
/// - Validation
/// - Serialization/deserialization
/// - Computed field dependency tracking
/// - WebSocket field mapping
library;

import 'package:meta/meta.dart';

/// Types of fields available in the system.
///
/// Maps to Odoo field types.
enum FieldType {
  /// String field (Odoo: Char)
  char,

  /// Long text field (Odoo: Text)
  text,

  /// HTML content (Odoo: Html)
  html,

  /// Integer field (Odoo: Integer)
  integer,

  /// Floating point field (Odoo: Float)
  float,

  /// Currency-aware field (Odoo: Monetary)
  monetary,

  /// Boolean field (Odoo: Boolean)
  boolean,

  /// Date only (Odoo: Date)
  date,

  /// Date and time (Odoo: Datetime)
  datetime,

  /// Enumeration (Odoo: Selection)
  selection,

  /// Binary/base64 (Odoo: Binary)
  binary,

  /// JSON/Dict (Odoo: Json)
  json,

  /// Many-to-one relation (Odoo: Many2one)
  many2one,

  /// One-to-many relation (Odoo: One2many)
  one2many,

  /// Many-to-many relation (Odoo: Many2many)
  many2many,

  /// Reference to multiple models (Odoo: Reference)
  reference,

  /// Computed field (virtual, not stored)
  computed,

  /// Related field (delegated from relation)
  related,
}

/// Definition of a model field with all metadata.
///
/// Similar to Odoo's field definition, contains all information
/// needed for:
/// - UI rendering (label, help, widget)
/// - Validation (required, domain)
/// - Serialization (odooName, type)
/// - Computation (compute, depends)
@immutable
class FieldDefinition {
  /// The Dart property name.
  final String name;

  /// The Odoo field name (if different from [name]).
  final String? odooName;

  /// The field type.
  final FieldType type;

  /// Human-readable label.
  final String? label;

  /// Help text for tooltips.
  final String? help;

  /// Whether the field is required.
  final bool required;

  /// Whether the field is read-only.
  final bool readonly;

  /// Whether the field is stored in database.
  final bool store;

  /// Whether to sync this field from Odoo.
  final bool syncFromOdoo;

  /// Whether to sync this field to Odoo.
  final bool syncToOdoo;

  /// Default value (as Dart expression or literal).
  final dynamic defaultValue;

  /// For [FieldType.selection]: map of value -> label.
  final Map<String, String>? selectionOptions;

  /// For relations: the related model name.
  final String? relatedModel;

  /// For [FieldType.one2many]: the inverse field name.
  final String? inverseField;

  /// For [FieldType.related]: the path to the related field.
  final String? relatedPath;

  /// For [FieldType.computed]: the compute method name.
  final String? compute;

  /// For computed fields: list of field names this depends on.
  final List<String> depends;

  /// For [FieldType.monetary]: the currency field name.
  final String? currencyField;

  /// For [FieldType.float]/[FieldType.monetary]: decimal precision.
  final int precision;

  /// For [FieldType.char]: maximum length.
  final int? maxLength;

  /// Domain filter for relations.
  final String? domain;

  /// Whether this field triggers onchange.
  final bool hasOnchange;

  /// The onchange method name (if [hasOnchange] is true).
  final String? onchangeMethod;

  /// Whether changes to this field are tracked (for chatter).
  final bool tracking;

  /// Widget type hint for UI rendering.
  final String? widget;

  /// Index in field ordering.
  final int sequence;

  /// Whether this is a local-only field (not in Odoo).
  final bool localOnly;

  const FieldDefinition({
    required this.name,
    required this.type,
    this.odooName,
    this.label,
    this.help,
    this.required = false,
    this.readonly = false,
    this.store = true,
    this.syncFromOdoo = true,
    this.syncToOdoo = true,
    this.defaultValue,
    this.selectionOptions,
    this.relatedModel,
    this.inverseField,
    this.relatedPath,
    this.compute,
    this.depends = const [],
    this.currencyField,
    this.precision = 2,
    this.maxLength,
    this.domain,
    this.hasOnchange = false,
    this.onchangeMethod,
    this.tracking = false,
    this.widget,
    this.sequence = 100,
    this.localOnly = false,
  });

  /// Get the effective Odoo field name.
  String get effectiveOdooName => odooName ?? _toSnakeCase(name);

  /// Get the effective label (or derive from name).
  String get effectiveLabel => label ?? _toTitleCase(name);

  /// Check if this is a relational field.
  bool get isRelational =>
      type == FieldType.many2one ||
      type == FieldType.one2many ||
      type == FieldType.many2many;

  /// Check if this is a numeric field.
  bool get isNumeric =>
      type == FieldType.integer ||
      type == FieldType.float ||
      type == FieldType.monetary;

  /// Check if this is a text field.
  bool get isText =>
      type == FieldType.char ||
      type == FieldType.text ||
      type == FieldType.html;

  /// Check if this is a computed field.
  bool get isComputed => compute != null || type == FieldType.computed;

  /// Check if this field should be sent to Odoo on write.
  bool get isWritable => !readonly && !isComputed && syncToOdoo && !localOnly;

  /// Check if this field should be fetched from Odoo on read.
  bool get isReadable => syncFromOdoo && !localOnly;

  /// Create a copy with modified values.
  FieldDefinition copyWith({
    String? name,
    String? odooName,
    FieldType? type,
    String? label,
    String? help,
    bool? required,
    bool? readonly,
    bool? store,
    bool? syncFromOdoo,
    bool? syncToOdoo,
    dynamic defaultValue,
    Map<String, String>? selectionOptions,
    String? relatedModel,
    String? inverseField,
    String? relatedPath,
    String? compute,
    List<String>? depends,
    String? currencyField,
    int? precision,
    int? maxLength,
    String? domain,
    bool? hasOnchange,
    String? onchangeMethod,
    bool? tracking,
    String? widget,
    int? sequence,
    bool? localOnly,
  }) {
    return FieldDefinition(
      name: name ?? this.name,
      odooName: odooName ?? this.odooName,
      type: type ?? this.type,
      label: label ?? this.label,
      help: help ?? this.help,
      required: required ?? this.required,
      readonly: readonly ?? this.readonly,
      store: store ?? this.store,
      syncFromOdoo: syncFromOdoo ?? this.syncFromOdoo,
      syncToOdoo: syncToOdoo ?? this.syncToOdoo,
      defaultValue: defaultValue ?? this.defaultValue,
      selectionOptions: selectionOptions ?? this.selectionOptions,
      relatedModel: relatedModel ?? this.relatedModel,
      inverseField: inverseField ?? this.inverseField,
      relatedPath: relatedPath ?? this.relatedPath,
      compute: compute ?? this.compute,
      depends: depends ?? this.depends,
      currencyField: currencyField ?? this.currencyField,
      precision: precision ?? this.precision,
      maxLength: maxLength ?? this.maxLength,
      domain: domain ?? this.domain,
      hasOnchange: hasOnchange ?? this.hasOnchange,
      onchangeMethod: onchangeMethod ?? this.onchangeMethod,
      tracking: tracking ?? this.tracking,
      widget: widget ?? this.widget,
      sequence: sequence ?? this.sequence,
      localOnly: localOnly ?? this.localOnly,
    );
  }

  @override
  String toString() =>
      'FieldDefinition($name, type: $type, odoo: $effectiveOdooName)';

  /// Convert camelCase to snake_case.
  static String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  /// Convert camelCase to Title Case.
  static String _toTitleCase(String input) {
    final withSpaces = input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => ' ${match.group(0)}',
    );
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }
}

/// Builder for creating field definitions fluently.
class FieldBuilder {
  String _name;
  FieldType _type;
  String? _odooName;
  String? _label;
  String? _help;
  bool _required = false;
  bool _readonly = false;
  bool _store = true;
  bool _syncFromOdoo = true;
  bool _syncToOdoo = true;
  dynamic _defaultValue;
  Map<String, String>? _selectionOptions;
  String? _relatedModel;
  String? _inverseField;
  String? _relatedPath;
  String? _compute;
  List<String> _depends = const [];
  String? _currencyField;
  int _precision = 2;
  int? _maxLength;
  String? _domain;
  bool _hasOnchange = false;
  String? _onchangeMethod;
  bool _tracking = false;
  String? _widget;
  int _sequence = 100;
  bool _localOnly = false;

  FieldBuilder(this._name, this._type);

  /// Create a Char field.
  factory FieldBuilder.char(String name, {int? maxLength}) {
    return FieldBuilder(name, FieldType.char).._maxLength = maxLength;
  }

  /// Create a Text field.
  factory FieldBuilder.text(String name) {
    return FieldBuilder(name, FieldType.text);
  }

  /// Create an Integer field.
  factory FieldBuilder.integer(String name) {
    return FieldBuilder(name, FieldType.integer);
  }

  /// Create a Float field.
  factory FieldBuilder.float(String name, {int precision = 2}) {
    return FieldBuilder(name, FieldType.float).._precision = precision;
  }

  /// Create a Monetary field.
  factory FieldBuilder.monetary(String name, {String currencyField = 'currencyId'}) {
    return FieldBuilder(name, FieldType.monetary).._currencyField = currencyField;
  }

  /// Create a Boolean field.
  factory FieldBuilder.boolean(String name) {
    return FieldBuilder(name, FieldType.boolean);
  }

  /// Create a Date field.
  factory FieldBuilder.date(String name) {
    return FieldBuilder(name, FieldType.date);
  }

  /// Create a Datetime field.
  factory FieldBuilder.datetime(String name) {
    return FieldBuilder(name, FieldType.datetime);
  }

  /// Create a Selection field.
  factory FieldBuilder.selection(String name, Map<String, String> options) {
    return FieldBuilder(name, FieldType.selection).._selectionOptions = options;
  }

  /// Create a Many2one field.
  factory FieldBuilder.many2one(String name, String relatedModel) {
    return FieldBuilder(name, FieldType.many2one).._relatedModel = relatedModel;
  }

  /// Create a One2many field.
  factory FieldBuilder.one2many(String name, String relatedModel, String inverseField) {
    return FieldBuilder(name, FieldType.one2many)
      .._relatedModel = relatedModel
      .._inverseField = inverseField;
  }

  /// Create a Many2many field.
  factory FieldBuilder.many2many(String name, String relatedModel) {
    return FieldBuilder(name, FieldType.many2many).._relatedModel = relatedModel;
  }

  /// Create a Computed field.
  factory FieldBuilder.computed(String name, String compute, List<String> depends) {
    return FieldBuilder(name, FieldType.computed)
      .._compute = compute
      .._depends = depends
      .._store = false
      .._syncToOdoo = false;
  }

  /// Create a Related field.
  factory FieldBuilder.related(String name, String path) {
    return FieldBuilder(name, FieldType.related)
      .._relatedPath = path
      .._readonly = true;
  }

  /// Set the Odoo field name.
  FieldBuilder odooName(String name) {
    _odooName = name;
    return this;
  }

  /// Set the label.
  FieldBuilder label(String label) {
    _label = label;
    return this;
  }

  /// Set the help text.
  FieldBuilder help(String help) {
    _help = help;
    return this;
  }

  /// Mark as required.
  FieldBuilder isRequired([bool required = true]) {
    _required = required;
    return this;
  }

  /// Mark as readonly.
  FieldBuilder isReadonly([bool readonly = true]) {
    _readonly = readonly;
    return this;
  }

  /// Set default value.
  FieldBuilder defaultTo(dynamic value) {
    _defaultValue = value;
    return this;
  }

  /// Set the domain filter.
  FieldBuilder withDomain(String domain) {
    _domain = domain;
    return this;
  }

  /// Add onchange handler.
  FieldBuilder onchange(String method) {
    _hasOnchange = true;
    _onchangeMethod = method;
    return this;
  }

  /// Enable tracking.
  FieldBuilder tracked([bool tracking = true]) {
    _tracking = tracking;
    return this;
  }

  /// Set widget type.
  FieldBuilder widget(String widget) {
    _widget = widget;
    return this;
  }

  /// Set sequence.
  FieldBuilder sequence(int seq) {
    _sequence = seq;
    return this;
  }

  /// Mark as local-only.
  FieldBuilder localOnly([bool local = true]) {
    _localOnly = local;
    _syncFromOdoo = !local;
    _syncToOdoo = !local;
    return this;
  }

  /// Mark as stored computed.
  FieldBuilder stored([bool store = true]) {
    _store = store;
    return this;
  }

  /// Build the field definition.
  FieldDefinition build() {
    return FieldDefinition(
      name: _name,
      type: _type,
      odooName: _odooName,
      label: _label,
      help: _help,
      required: _required,
      readonly: _readonly,
      store: _store,
      syncFromOdoo: _syncFromOdoo,
      syncToOdoo: _syncToOdoo,
      defaultValue: _defaultValue,
      selectionOptions: _selectionOptions,
      relatedModel: _relatedModel,
      inverseField: _inverseField,
      relatedPath: _relatedPath,
      compute: _compute,
      depends: _depends,
      currencyField: _currencyField,
      precision: _precision,
      maxLength: _maxLength,
      domain: _domain,
      hasOnchange: _hasOnchange,
      onchangeMethod: _onchangeMethod,
      tracking: _tracking,
      widget: _widget,
      sequence: _sequence,
      localOnly: _localOnly,
    );
  }
}

/// Registry of field definitions for a model.
///
/// Provides runtime access to field metadata.
class FieldRegistry {
  final String modelName;
  final Map<String, FieldDefinition> _fields = {};
  final Map<String, List<String>> _dependencyGraph = {};

  FieldRegistry(this.modelName);

  /// Register a field.
  void register(FieldDefinition field) {
    _fields[field.name] = field;

    // Build dependency graph for computed fields
    for (final dep in field.depends) {
      _dependencyGraph[dep] ??= [];
      _dependencyGraph[dep]!.add(field.name);
    }
  }

  /// Register multiple fields.
  void registerAll(Iterable<FieldDefinition> fields) {
    for (final field in fields) {
      register(field);
    }
  }

  /// Get a field by name.
  FieldDefinition? operator [](String name) => _fields[name];

  /// Get all fields.
  Iterable<FieldDefinition> get all => _fields.values;

  /// Get field names.
  Iterable<String> get fieldNames => _fields.keys;

  /// Get writable fields.
  Iterable<FieldDefinition> get writable => _fields.values.where((f) => f.isWritable);

  /// Get readable fields.
  Iterable<FieldDefinition> get readable => _fields.values.where((f) => f.isReadable);

  /// Get required fields.
  Iterable<FieldDefinition> get required => _fields.values.where((f) => f.required);

  /// Get computed fields.
  Iterable<FieldDefinition> get computed => _fields.values.where((f) => f.isComputed);

  /// Get fields with onchange.
  Iterable<FieldDefinition> get withOnchange => _fields.values.where((f) => f.hasOnchange);

  /// Get relational fields.
  Iterable<FieldDefinition> get relational => _fields.values.where((f) => f.isRelational);

  /// Get fields sorted by sequence.
  List<FieldDefinition> get sorted {
    final list = _fields.values.toList();
    list.sort((a, b) => a.sequence.compareTo(b.sequence));
    return list;
  }

  /// Get computed fields that depend on a field.
  List<String> getDependents(String fieldName) {
    return _dependencyGraph[fieldName] ?? [];
  }

  /// Get the dependency graph.
  Map<String, List<String>> get dependencyGraph =>
      Map.unmodifiable(_dependencyGraph);

  /// Get Odoo field names to fetch.
  List<String> get odooFieldNames {
    return _fields.values
        .where((f) => f.isReadable && !f.isComputed && !f.localOnly)
        .map((f) => f.effectiveOdooName)
        .toList();
  }

  /// Get field by Odoo name.
  FieldDefinition? byOdooName(String odooName) {
    return _fields.values.cast<FieldDefinition?>().firstWhere(
          (f) => f!.effectiveOdooName == odooName,
          orElse: () => null,
        );
  }
}

/// Global registry of model field definitions.
class ModelFieldRegistry {
  static final Map<Type, FieldRegistry> _registries = {};
  static final Map<String, FieldRegistry> _registriesByModel = {};

  /// Register a field registry for a model type.
  static void register<T>(FieldRegistry registry) {
    _registries[T] = registry;
    _registriesByModel[registry.modelName] = registry;
  }

  /// Register a field registry by Type (for dynamic registration).
  static void registerByType(Type type, FieldRegistry registry) {
    _registries[type] = registry;
    _registriesByModel[registry.modelName] = registry;
  }

  /// Register a field registry by Odoo model name.
  static void registerByModel(String odooModel, FieldRegistry registry) {
    _registriesByModel[odooModel] = registry;
  }

  /// Get the field registry for a model type.
  static FieldRegistry? get<T>() {
    return _registries[T];
  }

  /// Get the field registry by Odoo model name.
  static FieldRegistry? getByModel(String odooModel) {
    return _registriesByModel[odooModel];
  }

  /// Check if a model has a registry.
  static bool has<T>() => _registries.containsKey(T);

  /// Check if a model has a registry by name.
  static bool hasModel(String odooModel) => _registriesByModel.containsKey(odooModel);

  /// Clear all registries.
  static void clear() {
    _registries.clear();
    _registriesByModel.clear();
  }
}
