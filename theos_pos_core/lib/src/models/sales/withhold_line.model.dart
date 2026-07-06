import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:uuid/uuid.dart';

part 'withhold_line.model.freezed.dart';
part 'withhold_line.model.g.dart';

/// Codigo de soporte tributario para retenciones
enum TaxSupportCode {
  @JsonValue('01')
  creditoTributario('01', 'Credito Tributario'),
  @JsonValue('02')
  costoGasto('02', 'Costo o Gasto'),
  @JsonValue('03')
  activo('03', 'Activo'),
  @JsonValue('04')
  dividendos('04', 'Dividendos'),
  @JsonValue('05')
  otros('05', 'Otros');

  final String code;
  final String label;

  const TaxSupportCode(this.code, this.label);

  static TaxSupportCode? fromCode(String? code) {
    if (code == null) return null;
    return TaxSupportCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => TaxSupportCode.otros,
    );
  }
}

/// Tipo de retencion
enum WithholdType {
  @JsonValue('withhold_vat_sale')
  vatSale('withhold_vat_sale', 'Retencion IVA Ventas'),
  @JsonValue('withhold_income_sale')
  incomeSale('withhold_income_sale', 'Retencion Renta Ventas');

  final String code;
  final String label;

  const WithholdType(this.code, this.label);

  static WithholdType? fromCode(String? code) {
    if (code == null) return null;
    return WithholdType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => WithholdType.incomeSale,
    );
  }
}

/// Modelo de linea de retencion para ordenes de venta
// Modelo custom l10n_ec_collection_box — requiere módulo instalado.
// F6 (julio 2026): corregido el nombre de modelo Odoo real — antes decía
// 'account.withhold.line' (nunca existió como tal), el modelo real es
// 'sale.order.withhold.line' (ver
// working/l10n_ec_collection_box/models/sale_order_withhold_line.py).
// Se trazó exhaustivamente (ModelRegistry, OfflineQueue, WebSocket
// dispatch, sync repositories) y NINGÚN flujo vivo dependía del string
// viejo — todos los call sites reales (offline queue, sync manual,
// withhold_service.dart) ya usaban el string correcto hardcodeado como
// workaround. tableName NO cambia (la tabla Drift sigue igual).
@OdooModel('sale.order.withhold.line', tableName: 'sale_order_withhold_line')
@freezed
abstract class WithholdLine with _$WithholdLine {
  const WithholdLine._();

  const factory WithholdLine({
    @OdooId() @Default(0) int id,
    @OdooLocalOnly() @Default('') String lineUuid,
    // FK a la orden dueña (sale_order.odooId). Igual que en PaymentLine —
    // el manager genérico (upsertLocal/fromDrift) necesita este campo para
    // poder poblar la columna real `order_id` (NOT NULL en la tabla Drift).
    // Antes no existía acá: WithholdLineManager.upsertLocal() fallaba
    // siempre con NOT NULL constraint failed (nunca se usa hoy en
    // producción — sales_repository_sync.dart/withhold_line_local_service
    // .dart construyen el Companion a mano con el orderId real). Encontrado
    // por el roundtrip test genérico — julio 2026.
    @OdooLocalOnly() int? orderId,
    @OdooMany2One('account.tax', odooName: 'tax_id') required int taxId,
    // Odoo 19.5 (erp1): tax_name/tax_percent/withhold_type ya NO existen en
    // sale.order.withhold.line del servidor (smoke fields_get, julio 2026)
    // — tax_id, base, amount, taxsupport_code y notes sí siguen existiendo.
    // Coincide con lo que ya hacía sales_repository_sync.dart en la
    // práctica: taxName/withholdType nunca venían de un campo real del
    // servidor, se derivaban del nombre del impuesto (tax_id) a mano
    // (ver syncWithholdLinesFromOdoo). withholdType es un enum con
    // @OdooSelection — el generador YA maneja enums LocalOnly escribiendo
    // `.code` en createDriftCompanion() y reconstruyendo con
    // `.firstWhere(code == valor, orElse: () => .values.first)` en
    // fromDrift() (mismo mapeo que tenía antes, ver
    // odoo_model_generator.dart _generateFromDriftBody/createDriftCompanion,
    // rama isLocalOnly + isEnumType) — el roundtrip local no cambia.
    @OdooLocalOnly() required String taxName,
    @OdooLocalOnly() required double taxPercent,
    @OdooLocalOnly() required WithholdType withholdType,
    @OdooSelection(odooName: 'taxsupport_code') TaxSupportCode? taxSupportCode,
    @OdooFloat() required double base,
    @OdooFloat() required double amount,
    @OdooString() String? notes,
  }) = _WithholdLine;

  factory WithholdLine.fromJson(Map<String, dynamic> json) =>
      _$WithholdLineFromJson(json);

  // ═══════════════════ Factory Methods ═══════════════════

  /// Crear nueva linea con UUID generado
  factory WithholdLine.create({
    required int taxId,
    required String taxName,
    required double taxPercent,
    required WithholdType withholdType,
    TaxSupportCode? taxSupportCode,
    required double base,
    required double amount,
    String? notes,
  }) {
    return WithholdLine(
      lineUuid: const Uuid().v4(),
      taxId: taxId,
      taxName: taxName,
      taxPercent: taxPercent,
      withholdType: withholdType,
      taxSupportCode: taxSupportCode,
      base: base,
      amount: amount,
      notes: notes,
    );
  }

  // ═══════════════════ Computed Properties ═══════════════════

  /// Calcular el monto de retencion basado en la base y el porcentaje
  static double calculateAmount(double base, double taxPercent) {
    return (base * taxPercent.abs()).abs();
  }

  /// Descripcion legible de la linea
  String get description {
    final parts = <String>[taxName];
    if (taxSupportCode != null) {
      parts.insert(0, taxSupportCode!.code);
    }
    return parts.join(' - ');
  }
}

/// Impuesto de retencion disponible
@freezed
abstract class AvailableWithholdTax with _$AvailableWithholdTax {
  const AvailableWithholdTax._();

  const factory AvailableWithholdTax({
    required int id,
    required String name,
    String? spanishName,
    required double amount,
    required WithholdType withholdType,
  }) = _AvailableWithholdTax;

  factory AvailableWithholdTax.fromJson(Map<String, dynamic> json) =>
      _$AvailableWithholdTaxFromJson(json);

  factory AvailableWithholdTax.fromOdoo(Map<String, dynamic> data) {
    final l10nEcType = data['tax_group_l10n_ec_type'] as String?;
    final withholdType = l10nEcType == 'withhold_vat_sale'
        ? WithholdType.vatSale
        : WithholdType.incomeSale;

    return AvailableWithholdTax(
      id: data['id'] as int,
      name: data['name'] as String,
      spanishName: data['spanish_name'] as String?,
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      withholdType: withholdType,
    );
  }

  // ═══════════════════ Computed Properties ═══════════════════

  /// Porcentaje como valor absoluto (0.30 para 30%)
  double get percent => (amount / 100).abs();

  /// Etiqueta formateada en espanol
  String get label => spanishName ?? name;
}
