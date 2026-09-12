import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// Integration guard for the redirect-denial patch from `mensajes-acceso`:
/// `GoRouter.redirect` cannot say anything on its way out, so a rejected
/// navigation used to be silent — indistinguishable from the app being
/// broken. This confirms the whole path actually fires end to end: redirect
/// deposits the reason, the shell picks it up once and shows it.
void main() {
  const sellerProfile = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'seller-1',
    userId: 9,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
  );

  testWidgets(
    'a seller who follows a link to Caja lands on Inicio AND sees why, '
    'not silence',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
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
                fetchedAt: DateTime.utc(2026, 9, 12),
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

      router.go('/collection');
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/');
      expect(find.text('Caja no está entre tus permisos'), findsOneWidget);
    },
  );

  testWidgets('a route the seller IS allowed into never shows a denial toast', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
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
              fetchedAt: DateTime.utc(2026, 9, 12),
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

    expect(router.state.uri.path, '/sales');
    expect(find.textContaining('no está entre tus permisos'), findsNothing);
  });
}
