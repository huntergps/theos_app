import 'package:drift/drift.dart' show GeneratedDatabase, RawValuesInsertable, TableInfo, Value, Variable;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import '../../database/database.dart';

part 'fiscal_position.model.freezed.dart';
part 'fiscal_position.model.g.dart';

/// Fiscal Position model representing account.fiscal.position in Odoo
///
/// Fiscal positions are used to map taxes based on customer location or type.
///
/// **Computed fields:**
/// - [displayName] → formatted name with country
/// - [hasCountryFilter] → whether filtered by country
/// - [isAutoApply] → whether auto-apply is enabled
@OdooModel('account.fiscal.position', tableName: 'account_fiscal_position')
@freezed
abstract class FiscalPosition with _$FiscalPosition {
  const FiscalPosition._();

  const factory FiscalPosition({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooBoolean() @Default(true) bool active,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooInteger() @Default(10) int sequence,
    @OdooString() String? note,
    @OdooBoolean(odooName: 'auto_apply') @Default(false) bool autoApply,
    @OdooMany2One('res.country', odooName: 'country_id') int? countryId,
    @OdooMany2OneName(sourceField: 'country_id') String? countryName,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _FiscalPosition;

  // ============ Computed Fields ============

  /// Display name with country if applicable
  String get displayName {
    if (countryName != null && countryName!.isNotEmpty) {
      return '$name ($countryName)';
    }
    return name;
  }

  /// Check if has country filter
  bool get hasCountryFilter => countryId != null && countryId! > 0;

  /// Check if is auto-apply position
  bool get isAutoApply => autoApply;
}

/// Fiscal Position Tax Mapping model representing account.fiscal.position.tax
///
/// Maps source taxes to destination taxes for a fiscal position.
/// Used to change taxes based on customer location (e.g., IVA 12% -> IVA 0% for exports).
@freezed
abstract class FiscalPositionTax with _$FiscalPositionTax {
  const FiscalPositionTax._();

  const factory FiscalPositionTax({
    required int id,
    required int odooId,
    required int positionId,
    required int taxSrcId,
    String? taxSrcName,
    int? taxDestId,
    String? taxDestName,
    DateTime? writeDate,
  }) = _FiscalPositionTax;

  // ============ Computed Fields ============

  /// Check if this mapping exempts the tax (no destination tax)
  bool get isExemption => taxDestId == null;

  /// Display text for the mapping
  String get displayMapping {
    final src = taxSrcName ?? 'Tax $taxSrcId';
    if (isExemption) {
      return '$src → Exempt';
    }
    final dest = taxDestName ?? 'Tax $taxDestId';
    return '$src → $dest';
  }

  // ============ Factory Methods ============

  /// Create from Drift database row
  factory FiscalPositionTax.fromDatabase(dynamic data) {
    return FiscalPositionTax(
      id: data.id,
      odooId: data.odooId,
      positionId: data.positionId,
      taxSrcId: data.taxSrcId,
      taxSrcName: data.taxSrcName,
      taxDestId: data.taxDestId,
      taxDestName: data.taxDestName,
      writeDate: data.writeDate,
    );
  }

  /// Create from Odoo JSON response
  factory FiscalPositionTax.fromOdoo(Map<String, dynamic> json) {
    int? positionId;
    if (json['position_id'] is List &&
        (json['position_id'] as List).isNotEmpty) {
      positionId = json['position_id'][0] as int;
    } else if (json['position_id'] is int) {
      positionId = json['position_id'] as int;
    }

    int? taxSrcId;
    String? taxSrcName;
    if (json['tax_src_id'] is List && (json['tax_src_id'] as List).isNotEmpty) {
      taxSrcId = json['tax_src_id'][0] as int;
      taxSrcName =
          json['tax_src_id'].length > 1 ? json['tax_src_id'][1] as String : null;
    }

    int? taxDestId;
    String? taxDestName;
    if (json['tax_dest_id'] is List &&
        (json['tax_dest_id'] as List).isNotEmpty) {
      taxDestId = json['tax_dest_id'][0] as int;
      taxDestName = json['tax_dest_id'].length > 1
          ? json['tax_dest_id'][1] as String
          : null;
    }

    return FiscalPositionTax(
      id: 0, // Will be set by database
      odooId: json['id'] as int,
      positionId: positionId ?? 0,
      taxSrcId: taxSrcId ?? 0,
      taxSrcName: taxSrcName,
      taxDestId: taxDestId,
      taxDestName: taxDestName,
      writeDate: json['write_date'] != null && json['write_date'] != false
          ? DateTime.tryParse('${json['write_date']}Z')
          : null,
    );
  }

  /// Convert to Drift database companion for insert/update
  AccountFiscalPositionTaxCompanion toCompanion() {
    return AccountFiscalPositionTaxCompanion(
      odooId: Value(odooId),
      positionId: Value(positionId),
      taxSrcId: Value(taxSrcId),
      taxSrcName: Value(taxSrcName),
      taxDestId: Value(taxDestId ?? 0),
      taxDestName: Value(taxDestName),
      writeDate: Value(writeDate),
    );
  }

  /// Odoo model name
  static const String odooModel = 'account.fiscal.position.tax';

  /// Fields to fetch from Odoo
  static const List<String> odooFields = [
    'id',
    'position_id',
    'tax_src_id',
    'tax_dest_id',
    'write_date',
  ];
}
