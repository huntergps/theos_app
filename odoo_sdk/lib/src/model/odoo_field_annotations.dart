/// Odoo Field Annotations for Code Generation
///
/// These annotations are used to define how Dart fields map to Odoo fields,
/// enabling automatic code generation for:
/// - fromOdoo() conversion methods
/// - toOdoo() serialization methods
/// - Drift table column definitions
/// - Field validation
library;

import 'package:meta/meta.dart';

/// Base annotation for all Odoo model definitions.
///
/// Applied at the class level to specify the Odoo model name and
/// optional table name for local storage.
///
/// Example:
/// ```dart
/// @OdooModel('product.product')
/// @freezed
/// class Product with _$Product {
///   // ...
/// }
/// ```
@immutable
class OdooModel {
  /// The Odoo model name (e.g., 'product.product', 'res.partner')
  final String modelName;

  /// Optional table name for Drift. Defaults to snake_case of class name.
  final String? tableName;

  /// Optional list of fields to always fetch from Odoo
  final List<String>? defaultFields;

  /// Whether this model supports soft delete (active field)
  final bool supportsSoftDelete;

  /// Whether to track write_date for incremental sync
  final bool trackWriteDate;

  /// SQL constraints for the Drift table.
  /// Similar to Odoo's _sql_constraints.
  ///
  /// Example:
  /// ```dart
  /// @OdooModel(
  ///   'sale.order',
  ///   sqlConstraints: [
  ///     SqlConstraint('name_unique', 'UNIQUE(name, company_id)', 'Order name must be unique per company'),
  ///     SqlConstraint('amount_positive', 'CHECK(amount_total >= 0)', 'Amount cannot be negative'),
  ///   ],
  /// )
  /// ```
  final List<SqlConstraint>? sqlConstraints;

  const OdooModel(
    this.modelName, {
    this.tableName,
    this.defaultFields,
    this.supportsSoftDelete = true,
    this.trackWriteDate = true,
    this.sqlConstraints,
  });
}

/// SQL constraint definition similar to Odoo's _sql_constraints.
@immutable
class SqlConstraint {
  /// Constraint name (e.g., 'name_unique')
  final String name;

  /// SQL constraint expression (e.g., 'UNIQUE(name, company_id)')
  final String constraint;

  /// Error message when constraint is violated
  final String message;

  const SqlConstraint(this.name, this.constraint, this.message);
}

/// Base class for all Odoo field annotations.
///
/// Contains common properties shared by all field types.
@immutable
abstract class OdooField {
  /// The field name in Odoo if different from Dart property name.
  /// If null, uses the Dart property name converted to snake_case.
  final String? odooName;

  /// Whether this field is required (not nullable) in Odoo.
  final bool required;

  /// Whether this field should be included in create/write operations.
  final bool writable;

  /// Whether this field should be fetched from Odoo.
  final bool readable;

  /// Optional default value expression (as Dart code string).
  final String? defaultValue;

  /// Human-readable label for the field.
  final String? label;

  /// Help text for the field.
  final String? help;

  const OdooField({
    this.odooName,
    this.required = false,
    this.writable = true,
    this.readable = true,
    this.defaultValue,
    this.label,
    this.help,
  });
}

/// Annotation for the primary ID field.
///
/// Every Odoo model has an 'id' field. This annotation marks
/// the Dart field that maps to it.
///
/// Example:
/// ```dart
/// @OdooId()
/// required int id,
/// ```
@immutable
class OdooId extends OdooField {
  const OdooId()
      : super(
          odooName: 'id',
          required: true,
          writable: false,
          readable: true,
        );
}

/// Annotation for String fields (Char, Text in Odoo).
///
/// Example:
/// ```dart
/// @OdooString(maxLength: 100)
/// String? name,
///
/// @OdooString(odooName: 'default_code')
/// String? code,
/// ```
@immutable
class OdooString extends OdooField {
  /// Maximum length for Char fields. Null for Text fields.
  final int? maxLength;

  /// Whether to trim whitespace.
  final bool trim;

  /// Whether this is a translatable field.
  final bool translate;

  const OdooString({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.maxLength,
    this.trim = true,
    this.translate = false,
  });
}

/// Annotation for Integer fields.
///
/// Example:
/// ```dart
/// @OdooInteger()
/// int? sequence,
/// ```
@immutable
class OdooInteger extends OdooField {
  const OdooInteger({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
  });
}

/// Annotation for Float/Decimal fields.
///
/// Example:
/// ```dart
/// @OdooFloat(precision: 2, odooName: 'list_price')
/// double price,
/// ```
@immutable
class OdooFloat extends OdooField {
  /// Number of decimal places for precision.
  final int precision;

  /// Digits specification as (total, decimal) tuple.
  final (int, int)? digits;

  const OdooFloat({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.precision = 2,
    this.digits,
  });
}

/// Annotation for Monetary fields (currency-aware floats).
///
/// Example:
/// ```dart
/// @OdooMonetary(currencyField: 'currency_id')
/// double amountTotal,
/// ```
@immutable
class OdooMonetary extends OdooFloat {
  /// The field name that contains the currency_id.
  final String currencyField;

  const OdooMonetary({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    super.precision = 2,
    this.currencyField = 'currency_id',
  });
}

/// Annotation for Boolean fields.
///
/// Example:
/// ```dart
/// @OdooBoolean()
/// @Default(true) bool active,
/// ```
@immutable
class OdooBoolean extends OdooField {
  const OdooBoolean({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
  });
}

/// Annotation for DateTime fields.
///
/// Example:
/// ```dart
/// @OdooDateTime(odooName: 'create_date')
/// DateTime? createdAt,
/// ```
@immutable
class OdooDateTime extends OdooField {
  /// Whether to store as UTC in local database.
  final bool storeAsUtc;

  const OdooDateTime({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.storeAsUtc = true,
  });
}

/// Annotation for Date fields (date without time).
///
/// Example:
/// ```dart
/// @OdooDate(odooName: 'date_order')
/// DateTime? orderDate,
/// ```
@immutable
class OdooDate extends OdooField {
  const OdooDate({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
  });
}

/// Annotation for Many2one relational fields.
///
/// Many2one fields in Odoo return [id, name] tuple or false.
/// This annotation generates code to extract both the ID and
/// optionally the display name.
///
/// Example:
/// ```dart
/// @OdooMany2One('res.partner', odooName: 'partner_id')
/// int? partnerId,
///
/// // The display name can be extracted to a separate field:
/// @OdooMany2OneName(sourceField: 'partner_id')
/// String? partnerName,
/// ```
@immutable
class OdooMany2One extends OdooField {
  /// The related Odoo model name.
  final String relatedModel;

  /// Whether to also store the display name.
  final bool storeDisplayName;

  /// Field name suffix for the display name field (e.g., 'Name' -> partnerName).
  final String displayNameSuffix;

  const OdooMany2One(
    this.relatedModel, {
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.storeDisplayName = true,
    this.displayNameSuffix = 'Name',
  });
}

/// Annotation for the display name extracted from a Many2one field.
///
/// This is a read-only computed field that extracts the name
/// portion of a Many2one field.
///
/// Example:
/// ```dart
/// @OdooMany2OneName(sourceField: 'partner_id')
/// String? partnerName,
/// ```
@immutable
class OdooMany2OneName extends OdooField {
  /// The source Many2one field this name comes from.
  final String sourceField;

  const OdooMany2OneName({
    required this.sourceField,
    super.label,
    super.help,
  }) : super(
          required: false,
          writable: false,
          readable: true,
        );
}

/// Annotation for One2many relational fields.
///
/// One2many fields return a list of IDs of related records.
/// The actual records must be fetched separately if needed.
///
/// Example:
/// ```dart
/// @OdooOne2Many('sale.order.line', inverseField: 'order_id')
/// List<int>? lineIds,
/// ```
@immutable
class OdooOne2Many extends OdooField {
  /// The related Odoo model name.
  final String relatedModel;

  /// The field in the related model that points back to this model.
  final String inverseField;

  /// Whether to cascade delete related records.
  final bool cascadeDelete;

  const OdooOne2Many(
    this.relatedModel, {
    required this.inverseField,
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.cascadeDelete = false,
  });
}

/// Annotation for Many2many relational fields.
///
/// Many2many fields return a list of IDs.
///
/// Example:
/// ```dart
/// @OdooMany2Many('product.tag', relationTable: 'product_tag_rel')
/// List<int>? tagIds,
/// ```
@immutable
class OdooMany2Many extends OdooField {
  /// The related Odoo model name.
  final String relatedModel;

  /// Optional relation table name.
  final String? relationTable;

  /// Column name in relation table for this model.
  final String? column1;

  /// Column name in relation table for related model.
  final String? column2;

  const OdooMany2Many(
    this.relatedModel, {
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.relationTable,
    this.column1,
    this.column2,
  });
}

/// Annotation for Selection fields.
///
/// Selection fields have a predefined list of options.
///
/// Example:
/// ```dart
/// @OdooSelection(options: {'draft': 'Draft', 'confirmed': 'Confirmed', 'done': 'Done'})
/// String? state,
/// ```
@immutable
class OdooSelection extends OdooField {
  /// Map of value -> display label.
  /// Optional - if not provided, use raw string value.
  final Map<String, String>? options;

  const OdooSelection({
    this.options,
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
  });
}

/// Annotation for Binary fields (base64 encoded).
///
/// Example:
/// ```dart
/// @OdooBinary(odooName: 'image_1920')
/// String? imageBase64,
/// ```
@immutable
class OdooBinary extends OdooField {
  /// Whether to fetch this field by default (large fields might be excluded).
  final bool fetchByDefault;

  const OdooBinary({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.fetchByDefault = false,
  });
}

/// Annotation for Html fields.
///
/// Example:
/// ```dart
/// @OdooHtml()
/// String? description,
/// ```
@immutable
class OdooHtml extends OdooField {
  /// Whether to sanitize HTML on read.
  final bool sanitize;

  const OdooHtml({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
    this.sanitize = true,
  });
}

/// Annotation for JSON/Dict fields.
///
/// Example:
/// ```dart
/// @OdooJson()
/// Map<String, dynamic>? metadata,
/// ```
@immutable
class OdooJson extends OdooField {
  const OdooJson({
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
  });
}

/// Annotation for computed/derived fields that exist only locally.
///
/// These fields are not synced to/from Odoo.
///
/// Example:
/// ```dart
/// @OdooComputed()
/// String? displayName,
///
/// @OdooComputed(compute: 'fullName')
/// String? get fullName => '$firstName $lastName';
/// ```
@immutable
class OdooComputed extends OdooField {
  /// Name of the compute method in the model.
  final String? compute;

  /// Fields this computed field depends on.
  final List<String>? depends;

  const OdooComputed({
    this.compute,
    this.depends,
    super.label,
    super.help,
  }) : super(
          required: false,
          writable: false,
          readable: false,
        );
}

/// Annotation for fields that exist only in local storage.
///
/// These fields are used for offline-first functionality:
/// - UUID for tracking records before they get an Odoo ID
/// - isSynced flag
/// - localCreatedAt timestamp
/// - etc.
///
/// Example:
/// ```dart
/// @OdooLocalOnly()
/// String? uuid,
///
/// @OdooLocalOnly()
/// bool isSynced,
/// ```
@immutable
class OdooLocalOnly extends OdooField {
  /// The Drift column type to use.
  final String? driftType;

  const OdooLocalOnly({
    super.defaultValue,
    super.label,
    this.driftType,
  }) : super(
          required: false,
          writable: false,
          readable: false,
        );
}

/// Annotation for Reference fields (polymorphic relations).
///
/// Reference fields can point to different models.
///
/// Example:
/// ```dart
/// @OdooReference(models: ['res.partner', 'res.users'])
/// String? reference,  // Format: "model,id"
/// ```
@immutable
class OdooReference extends OdooField {
  /// List of allowed models.
  final List<String> models;

  const OdooReference({
    required this.models,
    super.odooName,
    super.required,
    super.writable,
    super.readable,
    super.defaultValue,
    super.label,
    super.help,
  });
}

/// Annotation for field-level constraints (like @api.constrains in Odoo).
///
/// Marks a validation method that should be called when specific fields change.
///
/// Example:
/// ```dart
/// class SaleOrder with _$SaleOrder, OdooRecord<SaleOrder> {
///   // Fields with constraints
///   @OdooConstraint(
///     fields: ['partner_id', 'line_ids'],
///     method: '_checkPartnerAndLines',
///     message: 'Order must have a customer and at least one line',
///   )
///   int? partnerId,
///
///   // Validation method
///   String? _checkPartnerAndLines() {
///     if (partnerId == null) return 'Customer is required';
///     if (lineIds.isEmpty) return 'At least one line is required';
///     return null; // Valid
///   }
/// }
/// ```
@immutable
class OdooConstraint {
  /// Fields that trigger this constraint validation.
  final List<String> fields;

  /// Name of the validation method.
  final String method;

  /// Default error message if method returns true (error) without message.
  final String? message;

  const OdooConstraint({
    required this.fields,
    required this.method,
    this.message,
  });
}

/// Annotation for onchange behavior (like @api.onchange in Odoo).
///
/// Marks a method that should be called when specific fields change
/// to update other fields.
///
/// Example:
/// ```dart
/// class SaleOrder with _$SaleOrder {
///   @OdooOnchange(
///     fields: ['partner_id'],
///     method: '_onchangePartnerId',
///   )
///   int? partnerId,
///
///   // Onchange method - returns copy with updated fields
///   SaleOrder _onchangePartnerId() {
///     if (partnerId == null) return this;
///     // Update payment term from partner
///     return copyWith(
///       paymentTermId: partner?.propertyPaymentTermId,
///     );
///   }
/// }
/// ```
@immutable
class OdooOnchange {
  /// Fields that trigger this onchange.
  final List<String> fields;

  /// Name of the onchange method.
  final String method;

  const OdooOnchange({
    required this.fields,
    required this.method,
  });
}

/// Annotation for stored computed fields that are synced from Odoo.
///
/// Unlike [OdooComputed], stored computed fields have a database column
/// and are read from Odoo during sync. They are not writable.
///
/// Example:
/// ```dart
/// @OdooStoredComputed(
///   compute: '_computeAmountTotal',
///   depends: ['line_ids.price_subtotal', 'line_ids.price_tax'],
///   odooName: 'amount_total',
/// )
/// double? amountTotal,
/// ```
@immutable
class OdooStoredComputed extends OdooField {
  /// Name of the compute method in Odoo.
  final String compute;

  /// Fields this computed field depends on.
  final List<String> depends;

  /// Whether to compute before saving (client-side precompute).
  final bool precompute;

  const OdooStoredComputed({
    required this.compute,
    this.depends = const [],
    this.precompute = true,
    super.odooName,
    super.label,
    super.help,
  }) : super(
          required: false,
          writable: false,
          readable: true,
        );
}

/// Annotation for related fields that delegate to a field on a related model.
///
/// Example:
/// ```dart
/// @OdooRelated(related: 'partner_id.email', odooName: 'partner_email')
/// String? partnerEmail,
/// ```
@immutable
class OdooRelated extends OdooField {
  /// The related field path (e.g., 'partner_id.email').
  final String related;

  /// Whether this field is stored in the database.
  final bool store;

  const OdooRelated({
    required this.related,
    this.store = true,
    super.odooName,
    super.label,
    super.help,
  }) : super(
          required: false,
          writable: false,
          readable: true,
        );
}

/// Annotation for state machine configuration on a model class.
///
/// Applied at the class level to define valid state transitions.
///
/// Example:
/// ```dart
/// @OdooStateMachine(
///   stateField: 'state',
///   transitions: {
///     'draft': ['confirmed', 'cancelled'],
///     'confirmed': ['done', 'cancelled'],
///     'cancelled': ['draft'],
///   },
/// )
/// @OdooModel('sale.order')
/// class SaleOrder { ... }
/// ```
@immutable
class OdooStateMachine {
  /// The field that holds the state value.
  final String stateField;

  /// Map of state -> list of allowed target states.
  final Map<String, List<String>> transitions;

  const OdooStateMachine({
    required this.stateField,
    required this.transitions,
  });
}

/// Annotation for Odoo action methods.
///
/// Applied to model methods that map to Odoo server actions.
///
/// Example:
/// ```dart
/// @OdooAction(
///   name: 'confirm',
///   requiresState: ['draft'],
///   refreshAfter: true,
/// )
/// Future<void> actionConfirm() async { ... }
/// ```
@immutable
class OdooAction {
  /// Action name (used to generate the method name).
  final String name;

  /// Odoo method to call. Defaults to 'action_$name'.
  final String? odooMethod;

  /// Action name for validation (calls validateFor).
  final String? validateFor;

  /// States in which this action is allowed.
  final List<String>? requiresState;

  /// Whether to refresh the record after the action.
  final bool refreshAfter;

  /// Whether to queue this action when offline.
  final bool queueOffline;

  const OdooAction({
    required this.name,
    this.odooMethod,
    this.validateFor,
    this.requiresState,
    this.refreshAfter = true,
    this.queueOffline = true,
  });
}

/// Annotation for fields with default value methods.
///
/// Example:
/// ```dart
/// @OdooDefault(method: 'defaultCurrency')
/// int? currencyId,
///
/// static int defaultCurrency() => 1; // USD
/// ```
@immutable
class OdooDefault {
  /// Name of the static method that provides the default value.
  final String method;

  const OdooDefault({
    required this.method,
  });
}
