/// Etiquetas en español para los enums de terceros (`fluent_ui`,
/// `flutter_acrylic`) que se muestran en los combos de Configuración.
///
/// Un identificador interno como `acrylic`, `mica` o `minimal` nunca debe
/// llegar a la pantalla: quien elige un modo de ventana no sabe qué es
/// "mica" en inglés. Este archivo es el único lugar que traduce esos tres
/// enums; si `settings_screen.dart` necesita mostrar uno de sus valores,
/// pasa por aquí.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_acrylic/flutter_acrylic.dart' show WindowEffect;
import 'package:fluent_ui/fluent_ui.dart' show PaneDisplayMode;

/// Etiqueta del modo de tema (claro/oscuro/automático).
String themeModeLabel(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => 'Automático (según el sistema)',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
  };
}

/// Etiqueta del modo de visualización del panel de navegación.
String paneDisplayModeLabel(PaneDisplayMode mode) {
  return switch (mode) {
    PaneDisplayMode.top => 'Arriba',
    PaneDisplayMode.expanded => 'Expandido',
    PaneDisplayMode.compact => 'Compacto (solo iconos)',
    PaneDisplayMode.minimal => 'Oculto (menú hamburguesa)',
    PaneDisplayMode.auto => 'Automático (según el ancho)',
  };
}

/// Etiqueta del efecto visual de la ventana.
String windowEffectLabel(WindowEffect effect) {
  return switch (effect) {
    WindowEffect.disabled => 'Ninguno',
    WindowEffect.solid => 'Sólido',
    WindowEffect.transparent => 'Transparente',
    WindowEffect.aero => 'Aero (vidrio esmerilado)',
    WindowEffect.acrylic => 'Acrílico',
    WindowEffect.mica => 'Mica',
    WindowEffect.tabbed => 'Mica con pestañas',
    WindowEffect.titlebar => 'Barra de título (macOS)',
    WindowEffect.selection => 'Selección (macOS)',
    WindowEffect.menu => 'Menú (macOS)',
    WindowEffect.popover => 'Ventana emergente (macOS)',
    WindowEffect.sidebar => 'Barra lateral (macOS)',
    WindowEffect.headerView => 'Encabezado/pie (macOS)',
    WindowEffect.sheet => 'Hoja modal (macOS)',
    WindowEffect.windowBackground => 'Fondo de ventana (macOS)',
    WindowEffect.hudWindow => 'Panel flotante (macOS)',
    WindowEffect.fullScreenUI => 'Pantalla completa (macOS)',
    WindowEffect.toolTip => 'Información sobre herramientas (macOS)',
    WindowEffect.contentBackground => 'Fondo de contenido (macOS)',
    WindowEffect.underWindowBackground => 'Bajo la ventana (macOS)',
    WindowEffect.underPageBackground => 'Bajo la página (macOS)',
  };
}
