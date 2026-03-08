import '../../models/sales/sale_order_line.model.dart';
import '../taxes/tax_calculator_service.dart';

/// Thin wrapper that provides a simplified line calculation API.
///
/// Uses [LineAmountResult] from core as the return type (eliminating the
/// duplicate SaleOrderLineCalculation class). The calculation logic matches
/// core's [TaxCalculatorService.calculateLineAmounts] for the simple case
/// of a single percent-based tax without price_include.
///
/// All callers in features/sales/ use this wrapper for consistency.
class SaleOrderLineCalculator {
  const SaleOrderLineCalculator();

  /// Calcula los totales de una línea dado precio, cantidad, descuento y tasa de impuesto.
  ///
  /// [priceUnit] - Precio unitario (antes de descuento)
  /// [quantity] - Cantidad de unidades
  /// [discountPercent] - Porcentaje de descuento (0-100)
  /// [taxPercent] - Porcentaje de impuesto REAL del producto (ej: 15 para IVA 15%)
  ///                NUNCA calcular en reversa, siempre obtener de TaxCalculatorService
  LineAmountResult calculateLine({
    required double priceUnit,
    required double quantity,
    required double discountPercent,
    required double taxPercent,
  }) {
    // Subtotal before discount
    final subtotalBeforeDiscount = priceUnit * quantity;

    // Calculate discount amount
    final effectiveDiscountAmount = discountPercent > 0
        ? subtotalBeforeDiscount * (discountPercent / 100)
        : 0.0;

    // Subtotal after discount (base for taxes)
    final subtotal = subtotalBeforeDiscount - effectiveDiscountAmount;

    // Tax = subtotal * taxPercent%
    final tax = subtotal * (taxPercent / 100);

    // Total = subtotal + tax
    final total = subtotal + tax;

    return LineAmountResult(
      priceSubtotal: subtotal,
      priceTax: tax,
      priceTotal: total,
      discountAmount: effectiveDiscountAmount,
      taxDetails: const [],
    );
  }

  /// Aplica el cálculo a una línea existente y retorna una copia actualizada.
  ///
  /// [taxPercent] - REQUERIDO: Porcentaje de impuesto REAL del producto.
  ///                Obtener de TaxCalculatorService.getProductTaxInfo()
  ///                NUNCA calcular en reversa desde los montos existentes.
  SaleOrderLine updateLineCalculations(
    SaleOrderLine line, {
    double? newPriceUnit,
    double? newQuantity,
    double? newDiscount,
    required double taxPercent,
  }) {
    final priceUnit = newPriceUnit ?? line.priceUnit;
    final quantity = newQuantity ?? line.productUomQty;
    final discount = newDiscount ?? line.discount;

    final result = calculateLine(
      priceUnit: priceUnit,
      quantity: quantity,
      discountPercent: discount,
      taxPercent: taxPercent,
    );

    return line.copyWith(
      priceUnit: priceUnit,
      productUomQty: quantity,
      discount: discount,
      discountAmount: result.discountAmount,
      priceSubtotal: result.priceSubtotal,
      priceTax: result.priceTax,
      priceTotal: result.priceTotal,
    );
  }
}

/// Instancia global del calculador (stateless, puede ser const)
const saleOrderLineCalculator = SaleOrderLineCalculator();
