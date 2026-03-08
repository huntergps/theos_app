import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import '../../services/taxes/taxes.dart';

part 'sale_order_line.model.freezed.dart';
part 'sale_order_line.model.g.dart';

/// Tipo de linea de orden de venta
enum LineDisplayType {
  @JsonValue('')
  product(''), // Linea de producto normal
  @JsonValue('line_section')
  lineSection('line_section'),
  @JsonValue('line_subsection')
  lineSubsection('line_subsection'),
  @JsonValue('line_note')
  lineNote('line_note');

  final String code;
  const LineDisplayType(this.code);
}

/// Estado de facturacion de la linea
enum LineInvoiceStatus {
  @JsonValue('no')
  no('no'),
  @JsonValue('to invoice')
  toInvoice('to invoice'),
  @JsonValue('invoiced')
  invoiced('invoiced'),
  @JsonValue('upselling')
  upselling('upselling');

  final String code;
  const LineInvoiceStatus(this.code);
}

/// Sale Order Line model using OdooModelManager annotations
@OdooModel('sale.order.line', tableName: 'sale_order_line')
@freezed
abstract class SaleOrderLine with _$SaleOrderLine {
  const SaleOrderLine._();

  const factory SaleOrderLine({
    @OdooId() required int id,
    @OdooLocalOnly() String? lineUuid, // UUID local para sincronizacion offline-first
    @OdooMany2One('sale.order', odooName: 'order_id') required int orderId,
    @OdooInteger() @Default(10) int sequence,

    // Tipo de linea
    @OdooSelection(odooName: 'display_type') @Default(LineDisplayType.product) LineDisplayType displayType,
    @OdooBoolean(odooName: 'is_downpayment') @Default(false) bool isDownpayment,

    // Producto
    @OdooMany2One('product.product', odooName: 'product_id') int? productId,
    @OdooMany2OneName(sourceField: 'product_id') String? productName,
    @OdooString(odooName: 'product_default_code') String? productCode, // default_code del producto
    @OdooMany2One('product.template', odooName: 'product_template_id') int? productTemplateId,
    @OdooMany2OneName(sourceField: 'product_template_id') String? productTemplateName,
    @OdooString(odooName: 'product_type') String? productType, // 'consu', 'service', 'product'
    @OdooMany2One('product.category', odooName: 'categ_id') int? categId,
    @OdooMany2OneName(sourceField: 'categ_id') String? categName,

    // Descripcion
    @OdooString() required String name, // Descripcion de la linea
    // Cantidad y UoM
    @OdooFloat(odooName: 'product_uom_qty') @Default(1.0) double productUomQty,
    @OdooMany2One('uom.uom', odooName: 'product_uom_id') int? productUomId,
    @OdooMany2OneName(sourceField: 'product_uom_id') String? productUomName,

    // Precios
    @OdooFloat(odooName: 'price_unit') @Default(0.0) double priceUnit,
    @OdooFloat() @Default(0.0) double discount,
    @OdooFloat(odooName: 'discount_amount') @Default(0.0)
    double discountAmount, // Monto de descuento (campo computado de Odoo)
    @OdooFloat(odooName: 'price_subtotal') @Default(0.0) double priceSubtotal,
    @OdooFloat(odooName: 'price_tax') @Default(0.0) double priceTax,
    @OdooFloat(odooName: 'price_total') @Default(0.0) double priceTotal,
    @OdooFloat(odooName: 'price_reduce_taxexcl') @Default(0.0) double priceReduce, // Precio con descuento
    // Impuestos (JSON array de IDs)
    @OdooString(odooName: 'tax_ids') String? taxIds,
    // Nombres de impuestos (para mostrar en UI)
    @OdooLocalOnly() String? taxNames,

    // Entrega
    @OdooFloat(odooName: 'qty_delivered') @Default(0.0) double qtyDelivered,
    @OdooFloat(odooName: 'customer_lead') @Default(0.0) double customerLead, // Lead time en dias
    // Facturacion
    @OdooFloat(odooName: 'qty_invoiced') @Default(0.0) double qtyInvoiced,
    @OdooFloat(odooName: 'qty_to_invoice') @Default(0.0) double qtyToInvoice,
    @OdooSelection(odooName: 'invoice_status') @Default(LineInvoiceStatus.no) LineInvoiceStatus invoiceStatus,

    // Estado de la orden (related)
    @OdooString(odooName: 'state') String? orderState,

    // Section settings (Odoo 19)
    @OdooBoolean(odooName: 'collapse_prices') @Default(false)
    bool collapsePrices, // Ocultar precios de lineas en esta seccion
    @OdooBoolean(odooName: 'collapse_composition') @Default(false)
    bool collapseComposition, // Ocultar lineas hijas (solo mostrar seccion)
    @OdooBoolean(odooName: 'is_optional') @Default(false)
    bool isOptional, // Linea opcional (cliente puede elegir en portal)
    // Sync
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? lastSyncDate,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,

    // Product flags from catalog (for display purposes)
    @OdooLocalOnly() @Default(true) bool isUnitProduct, // If true, quantity must be integer
  }) = _SaleOrderLine;

  factory SaleOrderLine.fromJson(Map<String, dynamic> json) =>
      _$SaleOrderLineFromJson(json);

  /// Convierte a Map para enviar a Odoo (crear/actualizar linea)
  Map<String, dynamic> toOdoo() {
    final map = <String, dynamic>{
      'order_id': orderId,
      'sequence': sequence,
      'name': name,
      'product_uom_qty': productUomQty,
      'price_unit': priceUnit,
      'discount': discount,
    };

    if (productId != null) map['product_id'] = productId;
    if (productUomId != null) map['product_uom_id'] = productUomId; // Odoo 19
    if (displayType != LineDisplayType.product) {
      map['display_type'] = displayType.toOdooString();
    }

    // Tax IDs - convertir string CSV a lista de IDs para Odoo
    if (taxIds != null && taxIds!.isNotEmpty) {
      final taxIdList = taxIds!
          .split(',')
          .map((id) => int.tryParse(id.trim()))
          .where((id) => id != null)
          .toList();
      if (taxIdList.isNotEmpty) {
        // Odoo espera formato [(6, 0, [ids])] para Many2many
        map['tax_ids'] = [
          [6, 0, taxIdList],
        ];
      }
    }

    // Section settings (only for sections/subsections)
    if (isSection || isSubsection) {
      map['collapse_prices'] = collapsePrices;
      map['collapse_composition'] = collapseComposition;
      map['is_optional'] = isOptional;
    }

    return map;
  }

  /// Comando para crear linea en Odoo (0, 0, vals)
  List<dynamic> toOdooCreate() {
    return [0, 0, toOdoo()..remove('order_id')];
  }

  /// Comando para actualizar linea en Odoo (1, id, vals)
  List<dynamic> toOdooUpdate() {
    return [1, id, toOdoo()..remove('order_id')];
  }

  /// Comando para eliminar linea en Odoo (2, id, 0)
  List<dynamic> toOdooDelete() {
    return [2, id, 0];
  }

  /// Indica si es una linea de producto real
  bool get isProductLine => displayType == LineDisplayType.product;

  /// Indica si es una seccion
  bool get isSection => displayType == LineDisplayType.lineSection;

  /// Indica si es una subseccion
  bool get isSubsection => displayType == LineDisplayType.lineSubsection;

  /// Indica si es una nota
  bool get isNote => displayType == LineDisplayType.lineNote;

  /// Indica si es una linea informativa (seccion, subseccion, nota)
  bool get isInfoLine =>
      displayType == LineDisplayType.lineSection ||
      displayType == LineDisplayType.lineSubsection ||
      displayType == LineDisplayType.lineNote;

  /// Calcula el subtotal localmente (para modo offline)
  double calculateSubtotal() {
    final discountedPrice = priceUnit * (1 - discount / 100);
    return discountedPrice * productUomQty;
  }

  /// Cantidad pendiente de entregar
  double get qtyPendingDelivery => productUomQty - qtyDelivered;

  /// Cantidad pendiente de facturar
  double get qtyPendingInvoice => productUomQty - qtyInvoiced;

  // ============ Business Logic (from SaleOrderLineEntity) ============

  /// Alias for compatibility: quantity returns productUomQty
  double get quantity => productUomQty;

  /// Get display name (custom description or product name)
  String get displayName =>
      name.isNotEmpty ? name : (productName ?? 'Producto');

  /// Check if line has discount
  bool get hasDiscount => discount > 0;

  /// Calculate line total with discount (alias for calculateSubtotal)
  double get calculatedTotal => calculateSubtotal();

  /// Check if line is fully delivered
  bool get isFullyDelivered => qtyDelivered >= productUomQty;

  /// Check if line is fully invoiced
  bool get isFullyInvoiced => qtyInvoiced >= productUomQty;

  /// Check if line is delivered (any quantity)
  bool get isDelivered => qtyDelivered > 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // ONCHANGE SIMULATION (equivalente a @api.onchange)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Simula onchange de product_id.
  ///
  /// Al cambiar producto, actualiza nombre, precio, UoM, impuestos.
  /// Equivalente a: sale.order.line._onchange_product_id()
  SaleOrderLine onProductChanged({
    required int productId,
    required String productName,
    String? productCode,
    required double listPrice,
    int? uomId,
    String? uomName,
    String? taxIds,
    String? taxNames,
    String? productType,
    int? categId,
    String? categName,
    bool isUnitProduct = true,
  }) {
    return copyWith(
      productId: productId,
      productName: productName,
      productCode: productCode,
      name: productName, // Default description
      priceUnit: listPrice,
      productUomId: uomId,
      productUomName: uomName,
      taxIds: taxIds,
      taxNames: taxNames,
      productType: productType,
      categId: categId,
      categName: categName,
      isUnitProduct: isUnitProduct,
    );
  }

  /// Simula onchange de quantity/discount/price_unit.
  ///
  /// Recalcula subtotal, tax, total.
  /// Equivalente a: sale.order.line._compute_amount()
  SaleOrderLine onAmountsChanged({
    double? newQuantity,
    double? newPriceUnit,
    double? newDiscount,
    required double taxPercent, // Total tax percentage (e.g., 15.0 for 15%)
  }) {
    final qty = newQuantity ?? productUomQty;
    final price = newPriceUnit ?? priceUnit;
    final disc = newDiscount ?? discount;

    // Calculate amounts
    final discountedPrice = price * (1 - disc / 100);
    final subtotal = discountedPrice * qty;
    final taxAmount = subtotal * (taxPercent / 100);
    final total = subtotal + taxAmount;
    final discountAmt = price * qty * (disc / 100);

    return copyWith(
      productUomQty: qty,
      priceUnit: price,
      discount: disc,
      discountAmount: discountAmt,
      priceSubtotal: subtotal,
      priceTax: taxAmount,
      priceTotal: total,
      priceReduce: discountedPrice,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una linea de producto nueva.
  ///
  /// Similar a: sale.order.line.new({...})
  factory SaleOrderLine.newProductLine({
    required int orderId,
    required int productId,
    required String productName,
    String? productCode,
    required double priceUnit,
    double quantity = 1.0,
    double discount = 0.0,
    int? uomId,
    String? uomName,
    String? taxIds,
    String? taxNames,
    int sequence = 10,
  }) {
    return SaleOrderLine(
      id: 0,
      orderId: orderId,
      sequence: sequence,
      displayType: LineDisplayType.product,
      productId: productId,
      productName: productName,
      productCode: productCode,
      name: productName,
      productUomQty: quantity,
      priceUnit: priceUnit,
      discount: discount,
      productUomId: uomId,
      productUomName: uomName,
      taxIds: taxIds,
      taxNames: taxNames,
      isSynced: false,
    );
  }

  /// Crea una linea de seccion.
  factory SaleOrderLine.newSection({
    required int orderId,
    required String name,
    int sequence = 10,
  }) {
    return SaleOrderLine(
      id: 0,
      orderId: orderId,
      sequence: sequence,
      displayType: LineDisplayType.lineSection,
      name: name,
      isSynced: false,
    );
  }

  /// Crea una linea de nota.
  factory SaleOrderLine.newNote({
    required int orderId,
    required String name,
    int sequence = 10,
  }) {
    return SaleOrderLine(
      id: 0,
      orderId: orderId,
      sequence: sequence,
      displayType: LineDisplayType.lineNote,
      name: name,
      isSynced: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REPORT METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Convierte a mapa para el reporte PDF
  ///
  /// CRITICAL: Uses values STORED in the database (discountAmount, priceTax, etc.)
  /// instead of recalculating them. This ensures consistency with what is displayed
  /// in the UI and what was calculated by Odoo (or the local engine).
  ///
  /// [taxDataMap] Optional map of tax ID -> tax data for looking up tax names.
  ///              The map key is the Odoo ID of the tax.
  ///              Expected structure: {taxId: {'name': 'IVA 15%', 'amount': 15.0}}
  Map<String, dynamic> toReportMap({Map<int, Map<String, dynamic>>? taxDataMap}) {
    // Build tax list using centralized TaxUtils
    // Template expects: ', '.join(tax.tax_label for tax in line.tax_ids)
    final taxList = TaxCalculatorService.buildTaxListForReport(
      taxIds: taxIds,
      taxNames: taxNames,
      taxDataMap: taxDataMap,
    );

    // Determine product code/barcode
    // default_code is mapped to productCode
    final barcode = productCode ?? '';

    // Helper to format currency
    String formatCurrency(double amount) {
      return amount.toCurrency();
    }

    // Create result map using STORED values
    final result = <String, dynamic>{
      'id': id,
      'name': name,
      'display_type': displayType.toOdooString(),
      'sequence': sequence,
      'product_id': productId != null
          ? {
              'id': productId,
              'name': productName,
              'default_code': productCode,
              'barcode': barcode,
              'l10n_ec_auxiliary_code': '', // Not stored in SaleOrderLine yet
            }
          : null,
      'product_uom_qty': productUomQty,
      'quantity': productUomQty, // Alias for compatibility
      'product_uom_id': productUomId != null
          ? {'id': productUomId, 'name': productUomName}
          : null,
      'price_unit': priceUnit,
      'formatted_price_unit': formatCurrency(priceUnit),
      'discount': discount,
      'formatted_discount': discount.toFixed(2), // No $ for percentage
      'discount_amount': discountAmount, // STORED VALUE
      'formatted_discount_amount': formatCurrency(discountAmount),
      'price_subtotal': priceSubtotal, // STORED VALUE
      'formatted_price_subtotal': formatCurrency(priceSubtotal),
      'price_tax': priceTax, // STORED VALUE
      'formatted_price_tax': formatCurrency(priceTax),
      'tax_amount': priceTax, // Alias for ReportService compatibility
      'formatted_tax_amount': formatCurrency(priceTax),
      'price_total': priceTotal, // STORED VALUE
      'formatted_price_total': formatCurrency(priceTotal),
      // tax_ids as list of objects with tax_label (for template iteration)
      'tax_ids': taxList,
      'tax_names': taxNames,
      'qty_delivered': qtyDelivered,
      'qty_invoiced': qtyInvoiced,
      'qty_to_invoice': qtyToInvoice,
      'state': orderState,

      // Template compatibility fields
      'collapse_composition': collapseComposition,
      'collapse_prices': collapsePrices,
      'is_downpayment': isDownpayment,
      'product_type': productType ?? 'consu',
    };

    // Methods needed by templates
    result['_get_child_lines'] = () => <Map<String, dynamic>>[];
    result['get_section_subtotal'] = () => priceSubtotal;

    // Add _has_taxes method (used by ReportService to calculate display_taxes)
    result['_has_taxes'] = () {
      return TaxCalculatorService.hasTaxes(taxList: taxList, priceTax: priceTax);
    };

    // Add with_context method for template compatibility
    result['with_context'] = ([Map<String, dynamic>? ctx]) => result;

    return result;
  }
}

/// Extension para operaciones con listas de lineas (calculo de secciones)
extension SaleOrderLineListExtension on List<SaleOrderLine> {
  /// Obtiene las lineas ordenadas por secuencia
  List<SaleOrderLine> get sortedBySequence {
    final sorted = List<SaleOrderLine>.from(this);
    sorted.sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted;
  }

  /// Obtiene las lineas que pertenecen a una seccion especifica
  List<SaleOrderLine> getLinesInSection(SaleOrderLine section) {
    if (!section.isSection && !section.isSubsection) return [];

    final sorted = sortedBySequence;
    final sectionIndex = sorted.indexWhere((l) => l.id == section.id);
    if (sectionIndex == -1) return [];

    final lines = <SaleOrderLine>[];
    for (var i = sectionIndex + 1; i < sorted.length; i++) {
      final line = sorted[i];
      // Si encontramos otra seccion, paramos
      if (line.isSection) break;
      // Si es una subseccion y estamos en una seccion, paramos si encontramos otra subseccion
      if (section.isSection && line.isSubsection) {
        // Continuamos pero no agregamos la subseccion a las lineas de la seccion
        continue;
      }
      // Si estamos en una subseccion y encontramos otra subseccion, paramos
      if (section.isSubsection && line.isSubsection) break;
      // Agregamos lineas de producto y notas
      if (line.isProductLine || line.isNote) {
        lines.add(line);
      }
    }
    return lines;
  }

  /// Calcula el subtotal de una seccion (suma de price_subtotal de sus lineas)
  double getSectionSubtotal(SaleOrderLine section) {
    return getLinesInSection(section)
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceSubtotal);
  }

  /// Calcula el total de una seccion (suma de price_total de sus lineas)
  double getSectionTotal(SaleOrderLine section) {
    return getLinesInSection(section)
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTotal);
  }

  /// Calcula el impuesto total de una seccion
  double getSectionTax(SaleOrderLine section) {
    return getLinesInSection(section)
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTax);
  }

  /// Obtiene la seccion padre de una linea
  SaleOrderLine? getParentSection(SaleOrderLine line) {
    if (line.isSection) return null;

    final sorted = sortedBySequence;
    final lineIndex = sorted.indexWhere((l) => l.id == line.id);
    if (lineIndex == -1) return null;

    SaleOrderLine? lastSection;
    SaleOrderLine? lastSubsection;

    for (var i = 0; i < lineIndex; i++) {
      final current = sorted[i];
      if (current.isSection) {
        lastSection = current;
        lastSubsection = null;
      } else if (current.isSubsection) {
        lastSubsection = current;
      }
    }

    // Para una subseccion, retornar la seccion padre
    if (line.isSubsection) return lastSection;
    // Para lineas de producto/nota, retornar subseccion si existe, sino seccion
    return lastSubsection ?? lastSection;
  }

  /// Verifica si una linea debe mostrar su precio (basado en collapse_prices)
  bool shouldShowPrice(SaleOrderLine line) {
    if (line.isSection || line.isSubsection || line.isNote) return false;

    final parent = getParentSection(line);
    if (parent == null) return true;

    // Si el padre tiene collapse_prices, no mostrar
    if (parent.collapsePrices) return false;

    // Si el padre es una subseccion, verificar tambien la seccion padre
    if (parent.isSubsection) {
      final grandparent = getParentSection(parent);
      if (grandparent?.collapsePrices == true) return false;
    }

    return true;
  }

  /// Verifica si una linea debe mostrarse (basado en collapse_composition)
  bool shouldShowLine(SaleOrderLine line) {
    // Secciones siempre se muestran
    if (line.isSection) return true;

    final parent = getParentSection(line);
    if (parent == null) return true;

    // Si el padre tiene collapse_composition, no mostrar lineas hijas
    if (parent.collapseComposition) return false;

    // Si el padre es una subseccion, verificar tambien la seccion padre
    if (parent.isSubsection) {
      final grandparent = getParentSection(parent);
      if (grandparent?.collapseComposition == true) return false;
    }

    return true;
  }
}

// ============ Enum Extensions ============

/// Extension to convert LineDisplayType to/from Odoo string values
extension LineDisplayTypeExtension on LineDisplayType {
  /// Convert to Odoo string value
  String toOdooString() {
    switch (this) {
      case LineDisplayType.product:
        return '';
      case LineDisplayType.lineSection:
        return 'line_section';
      case LineDisplayType.lineSubsection:
        return 'line_subsection';
      case LineDisplayType.lineNote:
        return 'line_note';
    }
  }

  /// Parse from Odoo string value
  static LineDisplayType fromString(dynamic value) {
    if (value == null || value == false || value == '') {
      return LineDisplayType.product;
    }
    final strValue = value is String ? value : value.toString();
    switch (strValue) {
      case 'line_section':
        return LineDisplayType.lineSection;
      case 'line_subsection':
        return LineDisplayType.lineSubsection;
      case 'line_note':
        return LineDisplayType.lineNote;
      default:
        return LineDisplayType.product;
    }
  }
}

/// Extension to convert LineInvoiceStatus to/from Odoo string values
extension LineInvoiceStatusExtension on LineInvoiceStatus {
  /// Convert to Odoo string value
  String toOdooString() {
    switch (this) {
      case LineInvoiceStatus.no:
        return 'no';
      case LineInvoiceStatus.toInvoice:
        return 'to invoice';
      case LineInvoiceStatus.invoiced:
        return 'invoiced';
      case LineInvoiceStatus.upselling:
        return 'upselling';
    }
  }

  /// Parse from Odoo string value
  static LineInvoiceStatus fromString(dynamic value) {
    if (value == null || value == false) return LineInvoiceStatus.no;
    final strValue = value is String ? value : value.toString();
    switch (strValue) {
      case 'no':
        return LineInvoiceStatus.no;
      case 'to invoice':
        return LineInvoiceStatus.toInvoice;
      case 'invoiced':
        return LineInvoiceStatus.invoiced;
      case 'upselling':
        return LineInvoiceStatus.upselling;
      default:
        return LineInvoiceStatus.no;
    }
  }
}
