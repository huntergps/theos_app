import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/app/orbi_app.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
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

final class _ProfileDuringLoginAuth implements AuthServicePort {
  static const profile = AuthProfile(
    serverUrl: 'https://saved.test',
    database: 'saved_db',
    login: 'saved_user',
    userId: 7,
    installationId: 'installation',
    credentialReference: 'api-key',
  );
  final profileReady = Completer<AuthProfile?>();

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() => profileReady.future;
  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) async => null;
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

  testWidgets('bootstrap router keeps login stable while profile loads', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authService = _ProfileDuringLoginAuth();
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          authInitialStateProvider.overrideWithValue(
            const AuthViewState(status: AuthControllerStatus.required),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const OrbiApp(),
      ),
    );
    await tester.pump();
    final loginElement = find.byType(LoginScreen).evaluate().single;
    final fields = find.byType(TextField);
    final serverController = tester.widget<TextField>(fields.at(0)).controller;
    await tester.tap(fields.at(0));
    await tester.enterText(fields.at(0), 'https://erp.test');
    await tester.tap(fields.at(1));
    await tester.enterText(fields.at(1), 'db');
    authService.profileReady.complete(_ProfileDuringLoginAuth.profile);
    await tester.pump();
    expect(identical(find.byType(LoginScreen).evaluate().single, loginElement), isTrue);
    expect(identical(tester.widget<TextField>(fields.at(0)).controller, serverController), isTrue);
    for (final entry in <({int index, String value})>[
      (index: 2, value: 'user'),
      (index: 3, value: 'password'),
    ]) {
      await tester.ensureVisible(fields.at(entry.index));
      await tester.tap(fields.at(entry.index));
      await tester.enterText(fields.at(entry.index), entry.value);
    }
    expect(tester.widget<TextField>(fields.at(3)).focusNode?.hasFocus, isTrue);
    expect(tester.widget<TextField>(fields.at(3)).controller?.text, 'password');
  });

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

  testWidgets('sync route requires synchronized administrator capability', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(_Auth()),
      capabilitySnapshotProvider.overrideWithValue(
        CapabilitySnapshot(
          scopeKey: 'scope',
          companyId: 1,
          revision: 1,
          fetchedAt: DateTime(2026),
          permissions: const ['seller'],
        ),
      ),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ]);
    addTearDown(container.dispose);
    final router = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await container.read(authControllerProvider.notifier).login(
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
    authenticatedRouter.go('/sync');
    await tester.pumpAndSettle();
    expect(authenticatedRouter.state.uri.path, '/');
  });

  testWidgets('synchronized administrator can enter sync route', (tester) async {
    final container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(_Auth()),
      capabilitySnapshotProvider.overrideWithValue(
        CapabilitySnapshot(
          scopeKey: 'scope',
          companyId: 1,
          revision: 1,
          fetchedAt: DateTime(2026),
          permissions: const ['administrator', 'sync'],
        ),
      ),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
    ]);
    addTearDown(container.dispose);
    final router = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await container.read(authControllerProvider.notifier).login(
      serverUrl: 'https://erp.test',
      database: 'db',
      login: 'administrator',
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
    authenticatedRouter.go('/sync');
    await tester.pumpAndSettle();
    expect(authenticatedRouter.state.uri.path, '/sync');
  });
}
