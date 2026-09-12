import 'package:flutter/material.dart';

abstract final class OrbiTheme {
  /// El color de marca, **coordinado con Odoo y no elegido aquí**.
  ///
  /// Sale del propio módulo de tema de la instancia
  /// (`base_gpstech/static/src/scss/variables_backend.scss`), donde Odoo fija
  /// `$o-main-link-color: #017e84` como color de acción. Orbi venía con
  /// `#007E82`, a un tono de distancia: dos valores casi iguales para lo
  /// mismo es como dos productos empiezan a parecer distintos sin que nadie
  /// lo decida. Ahora es el mismo número.
  ///
  /// Odoo usa además `#0DAFC8` como marca. No se copia aquí: en Fluent el
  /// acento tiñe controles pequeños sobre fondo claro, y el tono claro no
  /// contrasta lo suficiente. Fluent deriva sus siete tonos de éste.
  static const brand = Color(0xFF017E84);
  static const compactBreakpoint = 600.0;
  static const mediumBreakpoint = 840.0;

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  static ThemeData get light => fromSeed(brand, Brightness.light);
  static ThemeData get dark => fromSeed(brand, Brightness.dark);

  static ThemeData fromSeed(
    Color seedColor,
    Brightness brightness, {
    VisualDensity visualDensity = VisualDensity.standard,
  }) => _build(brightness, seedColor, visualDensity);

  static ThemeData _build(
    Brightness brightness,
    Color seedColor,
    VisualDensity visualDensity,
  ) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: visualDensity,
      scaffoldBackgroundColor: scheme.surface,
      // Shared operational hierarchy: platform defaults must not center titles
      // on macOS while the approved desktop/tablet layout is left aligned.
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }
}
