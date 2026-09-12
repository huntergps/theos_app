import 'package:flutter/material.dart';
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

/// A minimal `AuthServicePort` fake, same shape as `test/app/router_auth_test.dart`.
final class _Auth implements AuthServicePort {
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.authenticated);
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
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
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
          child: MaterialApp.router(routerConfig: router),
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
          child: MaterialApp.router(routerConfig: authenticatedRouter),
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
