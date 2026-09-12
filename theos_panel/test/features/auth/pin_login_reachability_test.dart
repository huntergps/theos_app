import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/features/auth/pin_credential_store.dart';
import 'package:theos_panel/features/auth/pin_login_screen.dart';

/// The bug this guards: ACC-02 (the seller PIN door) existed, had its own
/// tests, and enrollment could create a PIN in Settings — but nothing in the
/// router or the login screen ever opened it. A seller who enrolled a PIN had
/// no way back in except typing username/password again. This test drives
/// the app exactly like a person would: land on the login screen, tap
/// whatever the interface offers, never call a route by name.
///
/// The account behind [_profile] is deliberately multirole (seller AND
/// cashier) — restoreForSellerPin/pin_capability_limiter.dart must clamp it
/// down to seller-only even though the credentialed session would carry
/// both. If PIN ever leaked `cashier`, `/collection` would stop being denied
/// below.
const _profile = AuthProfile(
  serverUrl: 'https://erp.test',
  database: 'demo',
  login: 'multirole-seller',
  userId: 9,
  installationId: 'device-1',
  credentialReference: 'api-key',
);

/// Simulates a device that already went through a real Workspace login once:
/// `loadProfile()`/`loadProfileFor()` return the stored profile, and
/// `restore()` (the ONLY entry point `restoreForSellerPin` is allowed to use)
/// answers with the full multirole snapshot. `login()` is intentionally never
/// exercised by this test — PIN must never call it.
final class _RestorableMultiroleAuth implements AuthServicePort {
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      AuthServiceResult(
        status: AuthServiceStatus.restored,
        profile: _profile,
        capabilities: CapabilitySnapshot(
          scopeKey: 'scope',
          companyId: 1,
          revision: 1,
          fetchedAt: DateTime.utc(2026, 9, 12),
          permissions: const ['seller', 'cashier'],
        ),
      );

  @override
  Future<AuthProfile?> loadProfile() async => _profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => _profile;

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
    'a seller with an enrolled PIN reaches ACC-02 through the interface and '
    'stays capped to sales',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final pinStore = PinCredentialStore(preferences);
      final scopeKey = pinScopeKeyFor(
        _profile.serverUrl,
        _profile.database,
        _profile.login,
      );
      await pinStore.enroll(scopeKey, '1234');

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_RestorableMultiroleAuth()),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(PinLoginScreen), findsNothing);

      // Reach the PIN door the way a person does: tap something the login
      // screen itself offers. No context.go, no router.go('/...pin...').
      final pinEntry = find.byKey(const Key('login-pin-mode-button'));
      expect(
        pinEntry,
        findsOneWidget,
        reason:
            'The login screen must offer a tappable way into ACC-02. '
            'Without it, an enrolled PIN can never be used — only typed '
            'as a URL nobody would guess.',
      );
      await tester.tap(pinEntry);
      await tester.pumpAndSettle();

      expect(find.byType(PinLoginScreen), findsOneWidget);

      for (final digit in '1234'.split('')) {
        await tester.tap(find.byKey(Key('pin-key-$digit')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Mirrors how orbi_app.dart reacts in production: it watches
      // orbiRouterProvider, so an auth-state change swaps in a freshly built
      // GoRouter. Tests without that Consumer must do the swap by hand.
      final authenticatedRouter = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: authenticatedRouter),
        ),
      );
      await tester.pumpAndSettle();

      expect(authenticatedRouter.state.uri.path, '/');
      expect(
        container.read(authControllerProvider).capabilities?.permissions,
        {'seller'},
        reason:
            'PIN must clamp a multirole account down to seller-only, even '
            'though the credentialed account also holds cashier.',
      );

      authenticatedRouter.go('/collection');
      await tester.pumpAndSettle();
      expect(
        authenticatedRouter.state.uri.path,
        '/',
        reason:
            'Entering through PIN must never reach Caja, even for an '
            'account that holds the cashier permission on Workspace.',
      );
    },
  );
}
