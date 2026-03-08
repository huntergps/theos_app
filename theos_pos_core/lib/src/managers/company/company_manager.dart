/// CompanyManager extensions - Business methods beyond generated CRUD
///
/// The base CompanyManager is generated in company.model.g.dart.
/// This file adds business-specific query methods via extension.
library;

import '../../models/company/company.model.dart';

/// Extension methods for CompanyManager (generated)
extension CompanyManagerBusiness on CompanyManager {
  /// Get a company by Odoo ID (alias for readLocal)
  Future<Company?> getById(int odooId) => readLocal(odooId);

  /// Get the first (main) company
  Future<Company?> getMain() async {
    final companies = await searchLocal(limit: 1);
    return companies.firstOrNull;
  }

  /// Get all companies
  Future<List<Company>> getAllCompanies() async {
    return searchLocal();
  }

  /// Search companies by name
  Future<List<Company>> searchCompanies(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    return searchLocal(
      domain: [
        ['name', 'ilike', query],
      ],
      limit: limit,
    );
  }

  /// Update company configuration from WebSocket payload
  ///
  /// This only updates the specific fields that were changed in the WebSocket event.
  Future<void> updateCompanyConfigFromWebSocket(
    int companyId,
    Map<String, dynamic> values,
  ) async {
    // Helper to safely cast numeric values
    double? toDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is num) return value.toDouble();
      return null;
    }

    int? toInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is num) return value.toInt();
      return null;
    }

    // Map WebSocket field names (snake_case) to SQLite column names
    final fieldToColumn = <String, String>{
      'name': 'name',
      'max_discount_percentage': 'max_discount_percentage',
      'credit_overdue_days_threshold': 'credit_overdue_days_threshold',
      'credit_overdue_invoices_threshold': 'credit_overdue_invoices_threshold',
      'pedir_end_customer_data': 'pedir_end_customer_data',
      'pedir_sale_referrer': 'pedir_sale_referrer',
      'pedir_tipo_canal_cliente': 'pedir_tipo_canal_cliente',
      'reservation_expiry_days': 'reservation_expiry_days',
      'reservation_warehouse_id': 'reservation_warehouse_id',
      'reservation_warehouse_name': 'reservation_warehouse_name',
      'reservation_location_id': 'reservation_location_id',
      'reservation_location_name': 'reservation_location_name',
      'reserve_from_quotation': 'reserve_from_quotation',
      'quotation_validity_days': 'quotation_validity_days',
      'portal_confirmation_sign': 'portal_confirmation_sign',
      'portal_confirmation_pay': 'portal_confirmation_pay',
      'prepayment_percent': 'prepayment_percent',
      'sale_discount_product_id': 'sale_discount_product_id',
      'sale_discount_product_name': 'sale_discount_product_name',
      'sale_customer_invoice_limit_sri': 'sale_customer_invoice_limit_sri',
      'l10n_ec_legal_name': 'l10n_ec_legal_name',
      'l10n_ec_production_env': 'l10n_ec_production_env',
      'write_date': 'write_date',
    };

    // Build SET clause parts and values
    final setParts = <String>[];
    final sqlValues = <dynamic>[];

    for (final entry in fieldToColumn.entries) {
      final fieldName = entry.key;
      final columnName = entry.value;

      if (!values.containsKey(fieldName)) continue;

      final value = values[fieldName];

      // Convert value based on field type
      dynamic convertedValue;
      if (fieldName == 'write_date' && value is String) {
        try {
          final dt = DateTime.parse(value);
          convertedValue = dt.millisecondsSinceEpoch ~/ 1000;
        } catch (e) {
          continue;
        }
      } else if (fieldName.endsWith('_id') && !fieldName.contains('name')) {
        convertedValue = toInt(value);
      } else if (fieldName.contains('percentage') ||
          fieldName.contains('percent') ||
          fieldName.contains('limit_sri')) {
        convertedValue = toDouble(value);
      } else if (fieldName.endsWith('_days') ||
          fieldName.endsWith('_threshold')) {
        convertedValue = toInt(value);
      } else if (value is bool) {
        convertedValue = value ? 1 : 0;
      } else {
        convertedValue = value;
      }

      setParts.add('$columnName = ?');
      sqlValues.add(convertedValue);
    }

    if (setParts.isEmpty) {
      return;
    }

    sqlValues.add(companyId);

    final sql = '''
      UPDATE res_company
      SET ${setParts.join(', ')}
      WHERE odoo_id = ?
    ''';

    await database.customStatement(sql, sqlValues);
  }
}
