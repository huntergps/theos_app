import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/collection_scope_composition.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/collection/collection_contracts.dart';
import 'package:theos_panel/features/collection/collection_session_hub_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// A minimal `AuthServicePort` fake, same shape as `test/app/router_auth_test.dart`.
final class _Auth implements AuthServicePort {
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => AuthServiceResult(
    status: AuthServiceStatus.authenticated,
    // A real profile matching (serverUrl, database), same fix as
    // `router_auth_test.dart`: `serverFeaturesProvider` (14-sep-2026) keys
    // its cache off the active profile, and the real app never
    // authenticates with a null one.
    profile: AuthProfile(
      serverUrl: serverUrl,
      database: database,
      login: login,
      userId: 1,
      installationId: 'collection-hub-route-test',
      credentialReference: 'api-key',
    ),
  );
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;
  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
    'the cash shift hub route is reachable with the cashier permission and '
    'records stays not-available without a destination',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      // `/collection*` now also asks `ServerFeatures` for `cashbox`
      // (14-sep-2026, «theos_panel debe ser universal»); this test is about
      // the CASHIER permission reaching the hub, not about server evidence.
      await preferences.setString(
        serverFeaturesPrefsKey('https://erp.test', 'db'),
        ServerFeatures.empty
            .withState(
              ServerFeature.cashbox,
              ServerFeatureState.available,
              DateTime.utc(2026),
            )
            .toJson(),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth()),
          capabilitySnapshotProvider.overrideWithValue(
            CapabilitySnapshot(
              scopeKey: 'scope',
              companyId: 1,
              revision: 1,
              fetchedAt: DateTime(2026),
              permissions: const ['cashier'],
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
          // The route composes real providers for shift/capabilities; a
          // fixed shift here stands in for the runtime session so the test
          // exercises routing and screen composition, not Drift/Odoo I/O
          // that R06's sibling tests already cover elsewhere.
          scopeCollectionShiftFutureProvider.overrideWith(
            (ref) async => const CollectionShiftSnapshot(
              id: 'shift-1',
              state: CollectionShiftState.opened,
              expectedVersion: 1,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(
            theme: OrbiFluentTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await container
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: 'https://erp.test',
            database: 'db',
            login: 'cashier',
            password: 'secret',
          );
      final authenticatedRouter = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(
            theme: OrbiFluentTheme.light,
            routerConfig: authenticatedRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      authenticatedRouter.go('/collection/hub');
      await tester.pumpAndSettle();

      expect(authenticatedRouter.state.uri.path, '/collection/hub');
      expect(find.byType(CollectionSessionHubScreen), findsOneWidget);

      // Records has no destination yet (CAJ-02 is not built): the screen
      // must show it as not-available rather than a fabricated route.
      expect(find.text('Registros del turno'), findsOneWidget);
      expect(find.text('No disponible todavía'), findsOneWidget);
    },
  );
}
