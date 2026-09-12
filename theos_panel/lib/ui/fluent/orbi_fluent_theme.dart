import 'package:fluent_ui/fluent_ui.dart';

import '../../app/theme/orbi_theme.dart';

/// El tema Fluent de Orbi, derivado del MISMO color de marca que el tema
/// Material que sigue vivo mientras dura la migración.
///
/// Decisión del dueño (11-sep-2026): Orbi usa `fluent_ui`. Esto revoca la
/// recomendación contraria de
/// `docs/orbi_panel/reports/ESQUELETO_FLUENT_2026_09_12.md`, que sigue siendo
/// válida como registro de lo que se midió, no como decisión.
///
/// 🔴 **Un solo color de marca, no dos.** Se deriva del mismo
/// [OrbiTheme.brand] que ya usa el resto de la aplicación. Mientras convivan
/// las dos interfaces, dos semillas distintas darían dos productos distintos
/// en la misma ventana, y la diferencia se vería justo en los bordes, que es
/// donde peor se ve.
abstract final class OrbiFluentTheme {
  /// Fluent no deriva su paleta de un color suelto: necesita un [AccentColor]
  /// con sus siete tonos. `toAccentColor()` los calcula a partir de la marca,
  /// así que no hay que elegir a mano ni un tono más.
  static AccentColor get accent => OrbiTheme.brand.toAccentColor();

  static FluentThemeData get light => fromSeed(OrbiTheme.brand, Brightness.light);
  static FluentThemeData get dark => fromSeed(OrbiTheme.brand, Brightness.dark);

  /// El tema a partir del color que la persona haya elegido en Configuración.
  ///
  /// La densidad se respeta porque es una preferencia de accesibilidad: quien
  /// la puso compacta lo hizo para ver más filas de un vistazo, y devolvérsela
  /// a la estándar sin avisar le quita lo que había pedido.
  static FluentThemeData fromSeed(
    Color seed,
    Brightness brightness, {
    VisualDensity visualDensity = VisualDensity.standard,
  }) => FluentThemeData(
    brightness: brightness,
    accentColor: seed.toAccentColor(),
    visualDensity: visualDensity,
  );
}
