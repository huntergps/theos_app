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
    'lo que va después del formulario (tamaño de texto, PIN) sigue '
    'viéndose — el formulario no se come su espacio',
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
      expect(find.text('Categorías de notificaciones'), findsOneWidget);
      // Modo Ruta se trasladó a la pantalla de Sincronización (orden del
      // dueño, 13-sep-2026): Configuración ya no lo muestra.
      expect(find.text('Modo Ruta'), findsNothing);
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
      // La sección "Navegación" quedó abajo de "Apariencia" al agrupar la
      // pantalla en secciones plegables — con el viewport de prueba por
      // omisión su ComboBox queda fuera de vista y el tap ni acierta. Un
      // viewport así de alto llega hasta `PinEnrollmentSection`, que exige
      // su propio `ProviderScope` (lo trae el árbol real vía
      // `bootstrap.dart`).
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = await _controller();
      await tester.pumpWidget(ProviderScope(child: _host(controller)));
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
      // Mismo motivo que la prueba anterior: sin ampliar el viewport, el
      // ComboBox de "Navegación" queda fuera del área visible de prueba —
      // y ese viewport llega hasta `PinEnrollmentSection`, que necesita su
      // propio `ProviderScope`.
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = await _controller();
      await tester.pumpWidget(ProviderScope(child: _host(controller)));
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

  // La prueba dedicada de "Modo Ruta" se trasladó a
  // sync_data_screen_test.dart junto con el propio interruptor (orden del
  // dueño, 13-sep-2026): Configuración ya no lo conoce.

  testWidgets(
    // Las categorías se muestran con su nombre en mayúscula inicial (orden
    // del dueño, 12-sep-2026: "ventas / caja / sistema" en minúscula parecía
    // texto de depuración, no producto) — la clave interna que persiste la
    // preferencia sigue en minúscula, sólo cambia lo que se lee en pantalla.
    'las categorías de notificaciones son ListTile con ToggleSwitch, con su '
    'nombre en mayúscula inicial',
    (tester) async {
      // La pantalla vive en un `ListView`: sin esto, "Caja" y "Sistema"
      // quedan fuera del viewport de prueba y ni se construyen. Un viewport
      // así de alto llega hasta `PinEnrollmentSection`, que sí necesita un
      // `ProviderScope` (lo trae el árbol real vía `bootstrap.dart`).
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = await _controller();
      await tester.pumpWidget(ProviderScope(child: _host(controller)));
      await tester.pump();

      for (final label in const ['Ventas', 'Caja', 'Sistema']) {
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(ListTile),
        );
        expect(tile, findsOneWidget, reason: 'falta la fila de $label');
        expect(
          find.descendant(of: tile, matching: find.byType(ToggleSwitch)),
          findsOneWidget,
          reason: '$label debe traer su interruptor',
        );
      }
      // La forma en minúscula ya no aparece como texto de pantalla — sólo
      // sobrevive como clave interna de `notificationCategories`.
      for (final raw in const ['ventas', 'caja', 'sistema']) {
        expect(find.text(raw), findsNothing);
      }

      expect(
        controller.snapshot.notificationCategories['ventas'] ?? true,
        isTrue,
      );
      final ventasToggle = find.descendant(
        of: find.ancestor(
          of: find.text('Ventas'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(ToggleSwitch),
      );
      await tester.tap(ventasToggle);
      await tester.pumpAndSettle();

      expect(controller.snapshot.notificationCategories['ventas'], isFalse);
    },
  );

  testWidgets(
    'la jerga de permisos ("acción consciente", "no se convierte en éxito") '
    'ya no aparece en pantalla',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = await _controller();
      await tester.pumpWidget(ProviderScope(child: _host(controller)));
      await tester.pump();

      expect(find.textContaining('acción consciente'), findsNothing);
      expect(find.textContaining('no se convierte en éxito'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tocar una muestra de acento cambia y persiste la preferencia, sin '
    'tocar el color por omisión',
    (tester) async {
      final controller = await _controller();
      // El valor por omisión no cambia (orden del dueño): sigue siendo el
      // teal de Orbi antes de tocar nada.
      expect(controller.snapshot.accentSeed, 0xFF007E82);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      await tester.tap(find.byKey(const Key('accent-swatch-azul')));
      await tester.pump();
      // Fluent's Button/HoverButton machinery schedules a 100ms Timer on
      // tap-up to reset its own pressed visual state; flush it so the test
      // does not end with a pending Timer.
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.snapshot.accentSeed, 0xFF1565C0);

      // Persistida de verdad: un store nuevo sobre el mismo
      // SharedPreferences (no el mismo controller) la lee igual.
      final reloaded = await AppPreferencesStore(
        preferences: await SharedPreferences.getInstance(),
        scope: _scope,
      ).load();
      expect(reloaded.accentSeed, 0xFF1565C0);
      expect(tester.takeException(), isNull);
    },
  );
}
