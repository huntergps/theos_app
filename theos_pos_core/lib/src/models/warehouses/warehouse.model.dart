import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'warehouse.model.freezed.dart';
part 'warehouse.model.g.dart';

/// Warehouse model representing stock.warehouse in Odoo
@OdooModel('stock.warehouse', tableName: 'stock_warehouse')
@freezed
abstract class Warehouse with _$Warehouse {
  const Warehouse._();

  const factory Warehouse({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooString() String? code,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Warehouse;

  // ============ Computed Fields ============

  /// Display name with code if available
  String get displayName => code != null ? '[$code] $name' : name;

  /// Short code for display (uses code or first 3 chars of name)
  String get shortCode => code ?? (name.length >= 3 ? name.substring(0, 3) : name);
}
