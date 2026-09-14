import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// Same integration shape as `router_access_denial_test.dart`: a rejected
/// navigation bounces to `/` with a visible reason, an allowed one lands and
/// stays. Covers the four Envases destinations wired in this change —
/// Existencias, Por recibir, Enviar and Movimientos — all gated by the same
/// `envases_read` prefix rule in `RouteAccessPolicy`.
void main() {
  const bodegaProfile = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'bodega-1',
    userId: 9,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
  );

  Future<GoRouter> routerWithPermissions(
    WidgetTester tester,
    List<String> permissions,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: AuthControllerStatus.authenticated,
            profile: bodegaProfile,
            capabilities: CapabilitySnapshot(
              scopeKey: 'scope',
              companyId: 1,
              revision: 1,
              fetchedAt: DateTime.utc(2026, 9, 13),
              permissions: permissions,
            ),
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
    return router;
  }

  for (final path in [
    '/envases',
    '/envases/por-recibir',
    '/envases/enviar',
    '/envases/movimientos',
  ]) {
    testWidgets(
      'envases_read reaches $path without a denial redirect',
      (tester) async {
        final router = await routerWithPermissions(tester, const [
          'envases_read',
        ]);
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, path);
        expect(find.textContaining('no está entre tus permisos'), findsNothing);
      },
    );

    testWidgets(
      'missing envases_read bounces $path to Inicio with a visible reason',
      (tester) async {
        final router = await routerWithPermissions(tester, const ['seller']);
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/');
        expect(
          find.text('Envases no está entre tus permisos'),
          findsOneWidget,
        );
      },
    );
  }
}
