import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// Orden del dueño (13-sep-2026): «todo debe ser offline». `fetchVersion()`
/// necesita red — sin ella, el pie no debe perder la versión que ya conocía
/// de una sesión anterior. Se prueba a través del router real (mismo patrón
/// que `router_company_label_test.dart`), no del `_odooVersionProvider`
/// privado de `router.dart`: no hay forma de referenciarlo desde otro
/// archivo, y el comportamiento que importa es el que se ve en el pie.
void main() {
  const profile = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'erik',
    userId: 7,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
    companyName: 'Empresa Demo',
  );

  CapabilitySnapshot capabilities() => CapabilitySnapshot(
    scopeKey: 'scope',
    companyId: 1,
    revision: 1,
    fetchedAt: DateTime.utc(2026, 9, 13),
    permissions: const [],
  );

  testWidgets(
    'sin cliente (sesión restaurada sin conexión), con versión guardada de '
    'una sesión anterior, el pie la muestra igual',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Sembrada como si `fetchVersion()` hubiera respondido en un arranque
      // anterior, con red. `runtimeSessionProvider` no se sobreescribe: por
      // omisión vale `null` (`notification_scope_adapter.dart:8`), así que
      // no hay `OdooClient` — el mismo caso que una sesión offline restaurada
      // sin API key (`SessionActivation.client`, `session_runtime.dart:85`).
      SharedPreferences.setMockInitialValues({
        'orbi/server_version/https://erp.test|demo': '20.0',
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authInitialStateProvider.overrideWithValue(
            AuthViewState(
              status: AuthControllerStatus.authenticated,
              profile: profile,
              capabilities: capabilities(),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Odoo 20.0'), findsOneWidget);
    },
  );

  testWidgets(
    'sin versión guardada y sin cliente, el pie no inventa una',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authInitialStateProvider.overrideWithValue(
            AuthViewState(
              status: AuthControllerStatus.authenticated,
              profile: profile,
              capabilities: capabilities(),
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Odoo'), findsNothing);
      expect(find.byIcon(FluentIcons.server_enviroment), findsNothing);
    },
  );
}
