import 'package:flutter/material.dart';

abstract final class OrbiTheme {
  static const brand = Color(0xFF007E82);
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
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
      ),
    );
  }
}
