import 'package:flutter/widgets.dart';

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

  /// El ancho MÁXIMO, en VERTICAL (alto > ancho), en el que `OperationalShell`
  /// usa una barra de navegación inferior en vez del carril lateral de
  /// Fluent. Corregido el 15-sep-2026: la primera versión reutilizaba el
  /// corte propio de `PaneDisplayMode.auto`
  /// (`NavigationViewState._resolveDisplayMode`,
  /// `fluent_ui-4.16.1/lib/.../navigation_view/view.dart:543`, 1008), pero
  /// eso dejaba FUERA al iPad vertical de la lámina aprobada
  /// `round-03/SHELL-01.png` — rotulada ahí mismo «iPad Vertical
  /// (1024 × 1366)», y con barra inferior dibujada — porque 1024 ≥ 1008. El
  /// dueño exigió aplicar la lámina completa: el corte es el ANCHO de ESE
  /// iPad, 1024, no el de Fluent.
  static const bottomNavigationMaxPortraitWidth = 1024.0;

  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  // 🔴 Aquí vivía el tema de Material entero: unas cien líneas construyendo
  // `ThemeData` con su esquema de color, su densidad y sus estilos de barra y
  // de tarjeta. **Ya no lo usa nadie**: la raíz es `FluentApp` y el tema lo
  // arma `OrbiFluentTheme` a partir de esta misma marca. Se borra en vez de
  // dejarlo por si acaso, que es como se acumula el código muerto que el
  // dueño no quiere volver a tener.
}
