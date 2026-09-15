import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// Orden del dueño, 14-sep-2026: «theos_panel debe ser universal, no sólo
/// funcionar con los módulos custom que tiene newerp» (Mepriga, por
/// ejemplo, no tiene ventas). Complementa `router_access_denial_test.dart`
/// (permiso ausente) con el caso de un MÓDULO ausente: el permiso SÍ está,
/// pero el servidor confirmó (`ServerFeatureStore`, sondeo `fields_get`) que
/// `sale.order` no existe.
void main() {
  const sellerProfile = AuthProfile(
    serverUrl: 'https://mepriga.test',
    database: 'mepriga',
    login: 'seller-1',
    userId: 9,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
  );

  Future<SharedPreferences> preferencesWithSalesUnavailable() async {
    final unavailableSales = ServerFeatures.empty.withState(
      ServerFeature.sales,
      ServerFeatureState.unavailable,
      DateTime.utc(2026, 9, 14),
    );
    SharedPreferences.setMockInitialValues({
      serverFeaturesPrefsKey(sellerProfile.serverUrl, sellerProfile.database):
          unavailableSales.toJson(),
    });
    return SharedPreferences.getInstance();
  }

  testWidgets(
    'a seller WITH the seller permission still cannot reach /sales when the '
    'server has confirmed it has no sale.order, and the notice names the '
    'MODULE, not a missing permission',
    (tester) async {
      final preferences = await preferencesWithSalesUnavailable();
      final container = ProviderContainer(
        overrides: [
          authInitialStateProvider.overrideWithValue(
            AuthViewState(
              status: AuthControllerStatus.authenticated,
              profile: sellerProfile,
              capabilities: CapabilitySnapshot(
                scopeKey: 'scope',
                companyId: 1,
                revision: 1,
                fetchedAt: DateTime.utc(2026, 9, 14),
                permissions: const ['seller'],
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

      router.go('/sales');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/');
      expect(
        find.text('Este servidor no tiene el módulo de Ventas.'),
        findsOneWidget,
      );
      // Not the permission-denied wording — this is not about who this
      // person is, it is about what this Odoo has installed.
      expect(find.textContaining('no está entre tus permisos'), findsNothing);
    },
  );

  testWidgets(
    'returnTo an unavailable module falls back home instead of honoring the '
    'deep link',
    (tester) async {
      final preferences = await preferencesWithSalesUnavailable();
      final container = ProviderContainer(
        overrides: [
          authInitialStateProvider.overrideWithValue(
            AuthViewState(
              status: AuthControllerStatus.authenticated,
              profile: sellerProfile,
              capabilities: CapabilitySnapshot(
                scopeKey: 'scope',
                companyId: 1,
                revision: 1,
                fetchedAt: DateTime.utc(2026, 9, 14),
                permissions: const ['seller'],
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

      router.go('/login?returnTo=%2Fsales');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/');
    },
  );
}
