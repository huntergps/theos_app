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

  /// El ancho a partir del cual `PaneDisplayMode.auto` de Fluent abre el
  /// panel completo con etiquetas —
  /// `NavigationViewState._resolveDisplayMode`
  /// (`fluent_ui-4.16.1/lib/src/controls/navigation/navigation_view/view.dart:543`,
  /// `else if (width >= 1008) { autoDisplayMode = PaneDisplayMode.expanded; }`).
  /// `OperationalShell` reutiliza este mismo número como su propio corte: en
  /// VERTICAL (alto > ancho), por debajo de este ancho, fuerza una barra de
  /// navegación inferior en vez de esperar a que Fluent abra el panel
  /// completo con etiquetas — orden del dueño, 15-sep-2026, comparando con
  /// las láminas aprobadas (`round-02/ENV-01.png`, `round-03/SHELL-01.png`).
  static const fullPaneBreakpoint = 1008.0;

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
