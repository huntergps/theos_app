import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'unauthenticated direct access redirects to login and safe returnTo',
    (tester) async {
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(_Auth()), sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())],
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
      router.go('/collection');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      expect(router.state.uri.queryParameters['returnTo'], '/collection');
    },
  );

  testWidgets(
    'authenticated routes and menu policy deny unauthorized collection',
    (tester) async {
      final capabilities = CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime(2026),
        permissions: const ['seller'],
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth()),
          capabilitySnapshotProvider.overrideWithValue(capabilities),
          sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
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
            login: 'seller',
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
      authenticatedRouter.go('/collection');
      await tester.pumpAndSettle();
      expect(authenticatedRouter.state.uri.path, '/');
      authenticatedRouter.go('/sales');
      await tester.pumpAndSettle();
      expect(authenticatedRouter.state.uri.path, '/sales');
    },
  );

  testWidgets('approvals route requires effective approver capability', (tester) async {
    final capabilities = CapabilitySnapshot(scopeKey: 'scope', companyId: 1, revision: 1, fetchedAt: DateTime(2026), permissions: const ['approver']);
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(_Auth()),
      capabilitySnapshotProvider.overrideWithValue(capabilities),
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
    ]);
    addTearDown(container.dispose);
    final router = container.read(orbiRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router)));
    await container.read(authControllerProvider.notifier).login(serverUrl: 'https://erp.test', database: 'db', login: 'approver', password: 'secret');
    await tester.pumpAndSettle();
    final authenticatedRouter = container.read(orbiRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: authenticatedRouter)));
    await tester.pumpAndSettle();
    authenticatedRouter.go('/approvals');
    await tester.pumpAndSettle();
    expect(authenticatedRouter.state.uri.path, '/approvals');
    expect(find.text('No hay aprobaciones pendientes'), findsOneWidget);
  });
}
