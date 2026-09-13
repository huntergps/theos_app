import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      // El formulario ahora trae dos campos más (Menú de navegación,
      // Indicador del menú): con el tamaño de prueba por defecto empujaban
      // "Categorías de notificaciones" fuera del viewport y ni se
      // construía dentro del `ListView`. Mismo viewport que ya usa la
      // prueba de las categorías, más abajo en este archivo — y por la
      // misma razón, ese viewport llega hasta `PinEnrollmentSection`, que
      // exige su propio `ProviderScope`.
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = await _controller();
      await tester.pumpWidget(ProviderScope(child: _host(controller)));
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

  testWidgets('elegir un tema distinto lo aplica de inmediato', (tester) async {
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

  testWidgets(
    'elegir "Compacto" en Menú de navegación llama al setter y persiste',
    (tester) async {
      final controller = await _controller();
      await tester.pumpWidget(_host(controller));
      await tester.pump();

      expect(
        controller.snapshot.navigationDisplayMode,
        PreferenceNavigationDisplayMode.auto,
      );
      await tester.tap(find.byType(ComboBox<PreferenceNavigationDisplayMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Compacto').last);
      await tester.pumpAndSettle();

      expect(
        controller.snapshot.navigationDisplayMode,
        PreferenceNavigationDisplayMode.compact,
      );
    },
  );

  testWidgets(
    'elegir "Al final" en Indicador del menú llama al setter y persiste',
    (tester) async {
      final controller = await _controller();
      await tester.pumpWidget(_host(controller));
      await tester.pump();

      expect(
        controller.snapshot.navigationIndicator,
        PreferenceNavigationIndicator.sticky,
      );
      await tester.tap(find.byType(ComboBox<PreferenceNavigationIndicator>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Al final').last);
      await tester.pumpAndSettle();

      expect(
        controller.snapshot.navigationIndicator,
        PreferenceNavigationIndicator.end,
      );
    },
  );

  // `_SwitchRow` ahora es un `ListTile` con `ToggleSwitch` de fábrica (no un
  // Row+Column+Padding a mano) — ver `settings_screen.dart`. Esta prueba mira
  // lo que la persona ve: la fila es un ListTile con su interruptor, y
  // tocarlo sigue cambiando la preferencia real, no sólo un widget interno.
  testWidgets(
    '"Modo Ruta" es un ListTile con ToggleSwitch, y tocarlo cambia la '
    'preferencia',
    (tester) async {
      // Igual que arriba: el formulario más largo empuja "Modo Ruta" fuera
      // del viewport de prueba por defecto, y el tap ni siquiera acierta.
      // Este viewport llega hasta `PinEnrollmentSection`, que exige su
      // propio `ProviderScope`.
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = await _controller();
      await tester.pumpWidget(ProviderScope(child: _host(controller)));
      await tester.pump();

      expect(controller.snapshot.routeMode, isFalse);

      final tile = find.ancestor(
        of: find.text('Modo Ruta'),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget);
      final toggle = find.descendant(
        of: tile,
        matching: find.byType(ToggleSwitch),
      );
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(controller.snapshot.routeMode, isTrue);
    },
  );

  testWidgets(
    'las categorías de notificaciones son ListTile con ToggleSwitch',
    (tester) async {
      // La pantalla vive en un `ListView`: sin esto, "caja" y "sistema"
      // quedan fuera del viewport de prueba y ni se construyen. Un viewport
      // así de alto llega hasta `PinEnrollmentSection`, que sí necesita un
      // `ProviderScope` (lo trae el árbol real vía `bootstrap.dart`).
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = await _controller();
      await tester.pumpWidget(ProviderScope(child: _host(controller)));
      await tester.pump();

      for (final category in const ['ventas', 'caja', 'sistema']) {
        final tile = find.ancestor(
          of: find.text(category),
          matching: find.byType(ListTile),
        );
        expect(tile, findsOneWidget, reason: 'falta la fila de $category');
        expect(
          find.descendant(of: tile, matching: find.byType(ToggleSwitch)),
          findsOneWidget,
          reason: '$category debe traer su interruptor',
        );
      }

      expect(
        controller.snapshot.notificationCategories['ventas'] ?? true,
        isTrue,
      );
      final ventasToggle = find.descendant(
        of: find.ancestor(
          of: find.text('ventas'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(ToggleSwitch),
      );
      await tester.tap(ventasToggle);
      await tester.pumpAndSettle();

      expect(controller.snapshot.notificationCategories['ventas'], isFalse);
    },
  );
}
