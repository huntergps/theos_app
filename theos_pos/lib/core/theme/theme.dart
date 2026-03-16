/// Barrel file para theme constants
library;

export 'spacing.dart';

import 'package:fluent_ui/fluent_ui.dart';

import '../constants/app_colors.dart';

/// Configuracion centralizada del tema Fluent UI para Orbi ERP.
///
/// Uso:
/// ```dart
/// FluentApp(
///   theme: TheosTheme.light(),
///   darkTheme: TheosTheme.dark(),
/// )
/// ```
///
/// Tokens semanticos de color:
/// ```dart
/// color: TheosTheme.success(context)
/// color: TheosTheme.danger(context)
/// ```
abstract final class TheosTheme {
  // Color de acento predeterminado de la marca
  static final AccentColor _defaultAccent = AccentColor.swatch({
    'darkest': Color(0xFF064F5F),
    'darker': Color(0xFF086F82),
    'dark': Color(0xFF0B8FA5),
    'normal': Color(0xFF0DAFC8),
    'light': Color(0xFF1FC9E3),
    'lighter': Color(0xFF3DD9F0),
    'lightest': Color(0xFF5CE5F5),
  });

  /// Tema claro con el accent color de la marca.
  /// Pasar [accentColor] para sobreescribir el accent predeterminado.
  static FluentThemeData light({AccentColor? accentColor}) {
    return FluentThemeData(
      brightness: Brightness.light,
      accentColor: accentColor ?? _defaultAccent,
    );
  }

  /// Tema oscuro con el accent color de la marca.
  /// Pasar [accentColor] para sobreescribir el accent predeterminado.
  static FluentThemeData dark({AccentColor? accentColor}) {
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: accentColor ?? _defaultAccent,
    );
  }

  // ============================================================================
  // Tokens semanticos de color
  // ============================================================================

  /// Verde de exito — operaciones completadas, pagos confirmados, sincronizacion OK.
  static Color success(BuildContext context) => AppColors.success;

  /// Rojo de peligro/error — validaciones fallidas, errores criticos.
  static Color danger(BuildContext context) => AppColors.danger;

  /// Amarillo de advertencia — alertas, stock bajo, sesiones pendientes.
  static Color warning(BuildContext context) => AppColors.warning;

  /// Azul informativo — mensajes neutros, tooltips, hints.
  static Color info(BuildContext context) =>
      FluentTheme.of(context).accentColor;

  /// Color primario de la marca (teal).
  static Color primary(BuildContext context) => AppColors.primaryBackground;

  /// Color de texto para referencias y links.
  static Color referenceText(BuildContext context) => AppColors.referenceText;
}
