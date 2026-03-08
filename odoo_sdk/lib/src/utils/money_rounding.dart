import 'dart:math';

/// Implementación del redondeo HALF-UP de Odoo con corrección epsilon
/// Compatible con: odoo/tools/float_utils.py -> float_round()
class MoneyRounding {
  /// Precisión de redondeo (0.01 para 2 decimales, 0.001 para 3, etc.)
  final double precision;

  /// Lugares decimales (para visualización)
  final int decimalPlaces;

  const MoneyRounding({this.precision = 0.01, this.decimalPlaces = 2});

  /// Constructor para dígitos directos (e.g., 2 -> 0.01)
  factory MoneyRounding.fromDigits(int digits) {
    return MoneyRounding(
      precision: 1.0 / pow(10, digits),
      decimalPlaces: digits,
    );
  }

  /// Redondeo HALF-UP con corrección epsilon (como Odoo)
  double round(double value) {
    if (value == 0.0 || precision == 0.0) return 0.0;

    // Normalizar
    final normalized = value / precision;

    // Calcular epsilon (corrección IEEE-754)
    // Usamos un epsilon dinámico basado en la magnitud, similar a Odoo 18
    final absValue = normalized.abs();
    final epsilonMagnitude = absValue > 0 ? (log(absValue) / ln2) : 0;
    final epsilon = pow(2, epsilonMagnitude - 50).toDouble();

    // HALF-UP: añadir epsilon en dirección del signo
    // Esto asegura que 0.5 siempre redondee hacia arriba (lejos de cero)
    final adjusted = normalized + (value >= 0 ? epsilon : -epsilon);

    // Redondear al entero más cercano y desnormalizar
    return (adjusted.roundToDouble() * precision);
  }

  /// Compara dos valores con precisión de moneda
  /// Retorna: -1 si a < b, 0 si a == b, 1 si a > b
  int compare(double value1, double value2) {
    final rounded1 = round(value1);
    final rounded2 = round(value2);
    final delta = rounded1 - rounded2;

    if (delta.abs() < precision / 2) return 0;
    return delta < 0 ? -1 : 1;
  }

  /// Verifica si un valor es cero con precisión de moneda
  bool isZero(double value) {
    return round(value).abs() < precision / 2;
  }

  /// Formatea para mostrar
  String format(double value) {
    return round(value).toStringAsFixed(decimalPlaces);
  }

  /// Utility static method for quick rounding without instance
  static double roundTo(double value, int precision) {
    return MoneyRounding(precision: 1.0 / pow(10, precision)).round(value);
  }
}
