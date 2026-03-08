import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'account_move_line.model.freezed.dart';
part 'account_move_line.model.g.dart';

/// Tipo de linea de factura (account.move.line)
enum InvoiceLineDisplayType {
  product, // Linea de producto normal (display_type = false/'')
  lineSection, // Seccion (display_type = 'line_section')
  lineNote, // Nota (display_type = 'line_note')
  tax, // Linea de impuesto (display_type = 'tax')
  paymentTerm, // Termino de pago (display_type = 'payment_term')
  cogs, // Costo de ventas (display_type = 'cogs') - no va en reporte
}

/// Odoo model: account.move.line (Lineas de Factura)
@OdooModel('account.move.line', tableName: 'account_move_line')
@freezed
abstract class AccountMoveLine with _$AccountMoveLine {
  const AccountMoveLine._();

  // ═══════════════════ Validation ═══════════════════

  Map<String, String> validate() => {}; // Read-only model

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();
    switch (action) {
      case 'invoice':
        // Las lineas de producto deben tener cantidad y precio
        if (isProductLine) {
          if (quantity <= 0) {
            errors['quantity'] = 'La cantidad debe ser mayor a cero';
          }
          if (priceUnit < 0) {
            errors['priceUnit'] = 'El precio no puede ser negativo';
          }
        }
        break;
    }
    return errors;
  }

  const factory AccountMoveLine({
    // ============ Identifiers ============
    @OdooId() @Default(0) int id,

    // ============ Relations ============
    @OdooMany2One('account.move', odooName: 'move_id') @Default(0) int moveId,

    // ============ Basic Data ============
    @OdooString() @Default('') String name,
    @OdooLocalOnly() @Default(InvoiceLineDisplayType.product) InvoiceLineDisplayType displayType,
    @OdooInteger() @Default(10) int sequence,

    // ============ Product ============
    @OdooMany2One('product.product', odooName: 'product_id') int? productId,
    @OdooMany2OneName(sourceField: 'product_id') String? productName,
    @OdooLocalOnly() String? productCode,
    @OdooLocalOnly() String? productBarcode,
    @OdooLocalOnly() String? productL10nEcAuxiliaryCode,
    @OdooLocalOnly() String? productType,

    // ============ Quantity and UoM ============
    @OdooFloat() @Default(1.0) double quantity,
    @OdooMany2One('uom.uom', odooName: 'product_uom_id') int? productUomId,
    @OdooMany2OneName(sourceField: 'product_uom_id') String? productUomName,

    // ============ Prices ============
    @OdooFloat(odooName: 'price_unit') @Default(0.0) double priceUnit,
    @OdooFloat() @Default(0.0) double discount,
    @OdooFloat(odooName: 'price_subtotal') @Default(0.0) double priceSubtotal,
    @OdooFloat(odooName: 'price_total') @Default(0.0) double priceTotal,

    // ============ Taxes ============
    @OdooLocalOnly() String? taxIds,
    @OdooLocalOnly() String? taxNames,
    @OdooMany2One('account.tax', odooName: 'tax_line_id') int? taxLineId,
    @OdooMany2OneName(sourceField: 'tax_line_id') String? taxLineName,

    // ============ Account ============
    @OdooMany2One('account.account', odooName: 'account_id') int? accountId,
    @OdooMany2OneName(sourceField: 'account_id') String? accountName,

    // ============ Display Fields for Reports ============
    @OdooBoolean(odooName: 'collapse_composition') @Default(false) bool collapseComposition,
    @OdooBoolean(odooName: 'collapse_prices') @Default(false) bool collapsePrices,
  }) = _AccountMoveLine;

  factory AccountMoveLine.fromJson(Map<String, dynamic> json) =>
      _$AccountMoveLineFromJson(json);

  // ═══════════════════ Static ═══════════════════

  static const List<String> reportDisplayTypes = [
    '', 'product', 'line_section', 'line_note', 'tax',
  ];

  // ═══════════════════ Computed Properties ═══════════════════

  /// Si es una linea de producto real
  bool get isProductLine => displayType == InvoiceLineDisplayType.product;

  /// Si es una seccion
  bool get isSection => displayType == InvoiceLineDisplayType.lineSection;

  /// Si es una nota
  bool get isNote => displayType == InvoiceLineDisplayType.lineNote;

  /// Si es una linea de impuesto
  bool get isTaxLine => displayType == InvoiceLineDisplayType.tax;

  /// Si debe aparecer en el reporte
  bool get isReportLine =>
      displayType != InvoiceLineDisplayType.cogs &&
      displayType != InvoiceLineDisplayType.paymentTerm;

  /// Get display type as string
  String get displayTypeString => _displayTypeToString(displayType);

  /// Parse display type from string
  static InvoiceLineDisplayType parseDisplayType(String? value) =>
      _parseDisplayType(value);

  // ═══════════════════ Report Methods ═══════════════════

  /// Crea una copia con datos de producto adicionales
  AccountMoveLine copyWithProductData({
    String? barcode,
    String? l10nEcAuxiliaryCode,
    String? type,
  }) {
    return copyWith(
      productBarcode: barcode ?? productBarcode,
      productL10nEcAuxiliaryCode: l10nEcAuxiliaryCode ?? productL10nEcAuxiliaryCode,
      productType: type ?? productType,
    );
  }

  /// Convierte a mapa para el reporte PDF
  Map<String, dynamic> toReportMap() {
    final priceTax = priceTotal - priceSubtotal;

    // Parse tax_ids string to list of tax objects
    final taxList = <Map<String, dynamic>>[];
    if (taxNames != null && taxNames!.isNotEmpty) {
      final names = taxNames!.split(', ');
      final ids = taxIds?.split(',') ?? [];
      for (var i = 0; i < names.length; i++) {
        taxList.add({
          'id': i < ids.length ? int.tryParse(ids[i].trim()) : null,
          'name': names[i].trim(),
          'tax_label': names[i].trim(),
        });
      }
    } else if (isProductLine && priceTax > 0.001) {
      taxList.add({'id': null, 'name': 'IVA', 'tax_label': 'IVA'});
    }

    final discountAmount = discount > 0 && quantity > 0
        ? priceUnit * quantity * discount / 100
        : 0.0;

    String formatCurrency(double value) {
      final parts = value.toFixed(2).split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
      return '\$ $intPart,${parts[1]}';
    }

    // Determine display name
    String displayName;
    if (name.contains('\n')) {
      final lines = name.split('\n');
      final customLines = lines.skip(1).map((l) => l.trim()).where((l) => l.isNotEmpty);
      displayName = customLines.join(', ');
      if (displayName.isEmpty) {
        displayName = productName ?? name.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
      }
    } else if (productName != null && productName!.isNotEmpty) {
      displayName = productName!;
    } else {
      displayName = name.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
    }

    final result = <String, dynamic>{
      'id': id,
      'name': displayName,
      'display_type': _displayTypeToString(displayType),
      'sequence': sequence,
      'product_id': productId != null
          ? {
              'id': productId,
              'name': productName,
              'default_code': productCode,
              'barcode': productBarcode ?? productCode ?? '',
              'l10n_ec_auxiliary_code': productL10nEcAuxiliaryCode ?? '',
            }
          : null,
      'quantity': quantity,
      'product_uom_qty': quantity,
      'product_uom_id': productUomId != null
          ? {'id': productUomId, 'name': productUomName}
          : null,
      'price_unit': priceUnit,
      'formatted_price_unit': formatCurrency(priceUnit),
      'discount': discount,
      'formatted_discount': discount.toFixed(2),
      'discount_amount': discountAmount,
      'formatted_discount_amount': formatCurrency(discountAmount),
      'price_subtotal': priceSubtotal,
      'formatted_price_subtotal': formatCurrency(priceSubtotal),
      'price_tax': priceTax,
      'tax_amount': priceTax,
      'formatted_price_tax': formatCurrency(priceTax),
      'formatted_tax_amount': formatCurrency(priceTax),
      'price_total': priceTotal,
      'formatted_price_total': formatCurrency(priceTotal),
      'tax_ids': taxList,
      'tax_names': taxNames,
      'tax_line_id': taxLineId != null
          ? {'id': taxLineId, 'name': taxLineName}
          : null,
      'account_id': accountId != null
          ? {'id': accountId, 'name': accountName}
          : null,
      'collapse_composition': collapseComposition,
      'collapse_prices': collapsePrices,
      'is_downpayment': false,
      'product_type': productType ?? 'consu',
      '_get_child_lines': () => <Map<String, dynamic>>[],
      'get_section_subtotal': () => priceSubtotal,
      '_has_taxes': () => taxList.isNotEmpty || priceTax > 0,
      'with_context': ([Map<String, dynamic>? ctx]) => toReportMap(),
      '_l10n_ec_prepare_edi_vals_to_export_USD': () => <String, dynamic>{
        'price_unit': priceUnit,
        'price_subtotal': priceSubtotal,
        'price_total': priceTotal,
        'price_tax': priceTax,
        'discount': discount,
        'discount_amount': discountAmount,
      },
    };

    return result;
  }
}

// ═══════════════════ Helper Functions ═══════════════════

InvoiceLineDisplayType _parseDisplayType(dynamic value) {
  if (value == null || value == false || value == '') {
    return InvoiceLineDisplayType.product;
  }
  switch (value.toString()) {
    case 'line_section':
      return InvoiceLineDisplayType.lineSection;
    case 'line_note':
      return InvoiceLineDisplayType.lineNote;
    case 'tax':
      return InvoiceLineDisplayType.tax;
    case 'payment_term':
      return InvoiceLineDisplayType.paymentTerm;
    case 'cogs':
      return InvoiceLineDisplayType.cogs;
    default:
      return InvoiceLineDisplayType.product;
  }
}

String _displayTypeToString(InvoiceLineDisplayType type) {
  switch (type) {
    case InvoiceLineDisplayType.product:
      return 'product';
    case InvoiceLineDisplayType.lineSection:
      return 'line_section';
    case InvoiceLineDisplayType.lineNote:
      return 'line_note';
    case InvoiceLineDisplayType.tax:
      return 'tax';
    case InvoiceLineDisplayType.paymentTerm:
      return 'payment_term';
    case InvoiceLineDisplayType.cogs:
      return 'cogs';
  }
}
