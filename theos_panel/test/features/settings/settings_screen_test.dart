import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/features/settings/settings_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// El formulario estándar (orden del dueño, 12-sep-2026): sólo Tema,
/// Densidad y Acento son de verdad un formulario dentro de esta pantalla —
/// el resto (deslizador de tamaño de texto, interruptores, PIN) se queda
/// como está. Estas pruebas miran lo que la persona ve, no que el widget
/// exista: la etiqueta de cada campo, y que el resto de la pantalla sigue
/// visible después del formulario.
const _scope = PreferencesScope(appId: 'theos_panel', scopeKey: 'anonymous');

Future<AppPreferencesController> _controller() async {
  final preferences = await SharedPreferences.getInstance();
  final controller = AppPreferencesController(
    AppPreferencesStore(preferences: preferences, scope: _scope),
  );
  await controller.load();
  return controller;
}

Widget _host(AppPreferencesController controller) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: SettingsScreen(controller: controller),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('las tres etiquetas del formulario de apariencia se ven', (
    tester,
  ) async {
    final controller = await _controller();
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Densidad'), findsOneWidget);
    expect(find.text('Acento'), findsOneWidget);
  });

  testWidgets(
    'lo que va después del formulario (tamaño de texto, Modo Ruta, PIN) '
    'sigue viéndose — el formulario no se come su espacio',
    (tester) async {
      final controller = await _controller();
      await tester.pumpWidget(_host(controller));
      await tester.pump();

      expect(find.textContaining('Tamaño de texto'), findsOneWidget);
      expect(find.text('Modo Ruta'), findsOneWidget);
      expect(find.text('Categorías de notificaciones'), findsOneWidget);
      // Y en el orden correcto: el formulario queda ARRIBA de lo que sigue,
      // no lo tapa ni lo empuja fuera de la pantalla.
      final temaTop = tester.getTopLeft(find.text('Tema')).dy;
      final textScaleTop = tester
          .getTopLeft(find.textContaining('Tamaño de texto'))
          .dy;
      expect(temaTop, lessThan(textScaleTop));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('elegir un tema distinto lo aplica de inmediato', (
    tester,
  ) async {
    final controller = await _controller();
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(controller.snapshot.themeMode, PreferenceThemeMode.system);
    await tester.tap(find.byType(ComboBox<PreferenceThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro').last);
    await tester.pumpAndSettle();

    expect(controller.snapshot.themeMode, PreferenceThemeMode.dark);
  });
}
