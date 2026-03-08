import 'package:fluent_ui/fluent_ui.dart';

/// Colores de la aplicacion TheosPos
/// Centraliza los colores personalizados usados en la UI

abstract class AppColors {
  // === Colores principales de la marca ===

  /// Color primario de texto para referencias y links
  static const Color referenceText = Color(0xFF017E84);

  /// Color primario de fondo para tarjetas destacadas
  static const Color primaryBackground = Color(0xFF00A09D);

  /// Fondo claro para items seleccionados o destacados
  static Color get primaryBackgroundLight =>
      const Color(0xFF00A09D).withAlpha(20);

  /// Fondo muy claro para hover effects
  static Color get primaryBackgroundLighter =>
      const Color(0xFF00A09D).withAlpha(10);

  // === Colores de estado ===

  /// Verde de exito
  static const Color success = Color(0xFF28A745);

  /// Fondo verde de exito para botones
  static const Color successBackground = Color(0xFF06A77D);

  /// Amarillo de advertencia (Odoo o-yellow)
  static const Color warning = Color(0xFFFFC800);

  /// Rojo de error/peligro
  static const Color danger = Color(0xFFDC3545);

  // === Colores de login/splash ===

  /// Fondo oscuro para login screen
  static const Color loginBackground = Color(0xFF1A2B3C);

  // === Colores neutros ===

  /// Gris para texto secundario
  static const Color textSecondary = Color(0xFF888888);

  /// Gris claro para bordes
  static const Color borderLight = Color(0xFFE0E0E0);

  // === Variantes del color primario (para settings) ===

  static const Map<String, Color> primaryVariants = {
    'normal': Color(0xFF0DAFC8),
    'dark': Color(0xFF0B8FA5),
    'darker': Color(0xFF086F82),
    'darkest': Color(0xFF064F5F),
    'light': Color(0xFF1FC9E3),
    'lighter': Color(0xFF3DD9F0),
    'lightest': Color(0xFF5CE5F5),
  };

  // === Colores para stock/inventario ===

  /// Verde para stock disponible
  static const Color stockAvailable = Color(0xFF28A745);

  /// Naranja para stock bajo
  static const Color stockLow = Color(0xFFFF9800);

  /// Rojo para sin stock
  static const Color stockOut = Color(0xFFDC3545);
}
