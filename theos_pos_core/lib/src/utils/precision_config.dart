import 'package:odoo_sdk/odoo_sdk.dart' show MoneyRounding;
import '../database/database.dart';

enum TaxRoundingMethod {
  roundPerLine, // Redondear cada línea individualmente
  roundGlobally, // Redondear solo el total
}

/// Configuración de precisión - LEE DE DATOS SINCRONIZADOS DE ODOO
/// Usa decimal.precision para precisiones específicas por campo
class PrecisionConfig {
  /// Precisiones por uso (de decimal.precision)
  final Map<String, int> _precisions;

  /// Método de redondeo de impuestos
  final TaxRoundingMethod taxRoundingMethod;

  /// Símbolo de moneda
  final String currencySymbol;

  const PrecisionConfig._({
    required Map<String, int> precisions,
    required this.taxRoundingMethod,
    this.currencySymbol = '\$',
  }) : _precisions = precisions;

  /// Valores por defecto para Ecuador (USD)
  /// SOLO usar si no hay datos sincronizados
  factory PrecisionConfig.ecuadorDefaults() => const PrecisionConfig._(
    precisions: {
      'Product Unit': 3, // Cantidades
      'Product Price': 2, // Precios
      'Discount': 3, // Descuentos
      'Account': 2, // Montos contables (como currency)
    },
    taxRoundingMethod: TaxRoundingMethod.roundPerLine,
    currencySymbol: '\$',
  );

  /// Cargar desde base de datos local (datos sincronizados de Odoo)
  static Future<PrecisionConfig> fromDatabase(AppDatabase db) async {
    // 1. Cargar todas las precisiones de decimal.precision
    final precisionRecords = await db.select(db.decimalPrecision).get();
    final precisions = <String, int>{};

    for (final p in precisionRecords) {
      precisions[p.name] = p.digits;
    }

    // Si no hay datos, usar defaults
    if (precisions.isEmpty) {
      return PrecisionConfig.ecuadorDefaults();
    }

    // 2. Obtener compañía para método de redondeo
    // Asumimos un singleton de compañía activa o tomamos la primera
    final company = await db.select(db.resCompanyTable).getSingleOrNull();

    // Default method
    TaxRoundingMethod method = TaxRoundingMethod.roundPerLine;

    if (company != null) {
      if (company.taxCalculationRoundingMethod == 'round_globally') {
        method = TaxRoundingMethod.roundGlobally;
      }
    }

    // 3. Obtener símbolo de moneda
    String currencySymbol = '\$';
    if (company?.currencyId != null) {
      final currency =
          await (db.select(db.resCurrency)..where(
                (c) => (c as dynamic).odooId.equals(company!.currencyId!),
              ))
              .getSingleOrNull();
      currencySymbol = currency?.symbol ?? '\$';
    }

    return PrecisionConfig._(
      precisions: precisions,
      taxRoundingMethod: method,
      currencySymbol: currencySymbol,
    );
  }

  // ============================================================
  // GETTERS PARA CADA TIPO DE PRECISIÓN
  // ============================================================

  /// Precisión para cantidades (product_uom_qty)
  int get quantityDigits => _precisions['Product Unit'] ?? 3;

  /// Precisión para precios (price_unit)
  int get priceDigits => _precisions['Product Price'] ?? 2;

  /// Precisión para descuentos (discount)
  int get discountDigits => _precisions['Discount'] ?? 3;

  /// Precisión para montos totales (amount_total, etc.)
  int get accountDigits => _precisions['Account'] ?? 2;

  /// Obtener precisión por nombre (para casos especiales)
  int precisionFor(String usage) => _precisions[usage] ?? 2;

  // ============================================================
  // OBJETOS MoneyRounding PARA CADA USO
  // ============================================================

  /// Redondeo para cantidades
  MoneyRounding get quantityRounding =>
      MoneyRounding.fromDigits(quantityDigits);

  /// Redondeo para precios
  MoneyRounding get priceRounding => MoneyRounding.fromDigits(priceDigits);

  /// Redondeo para descuentos
  MoneyRounding get discountRounding =>
      MoneyRounding.fromDigits(discountDigits);

  /// Redondeo para montos totales (subtotal, tax, total)
  MoneyRounding get amountRounding => MoneyRounding.fromDigits(accountDigits);
}
