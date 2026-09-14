import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';

class FakeAuthService implements AuthServicePort {
  FakeAuthService(this.result);
  AuthServiceResult result;
  String? seenPassword;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async {
    seenPassword = password;
    return result;
  }

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async => result;

  @override
  Future<AuthProfile?> loadProfile() async => result.profile;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => result.profile;

  @override
  Future<void> close() async {}
}

final class _RestoreSequence implements AuthServicePort {
  var calls = <bool>[];
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async {
    calls.add(offline);
    if (!offline) throw StateError('offline');
    return const AuthServiceResult(status: AuthServiceStatus.restored);
  }

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) => throw UnimplementedError();
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

final class _BlockingAuthService implements AuthServicePort {
  final restoreCompleter = Completer<AuthServiceResult>();
  final profileCompleter = Completer<AuthProfile?>();
  final closeCompleter = Completer<void>();

  @override
  Future<AuthServiceResult> restore({bool offline = false}) =>
      restoreCompleter.future;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<AuthProfile?> loadProfile() => profileCompleter.future;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;

  @override
  Future<void> close() => closeCompleter.future;
}

class FakeBootstrap implements AuthBootstrapPort {
  @override
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
  }) async => const NativeAuthBootstrapResult(userId: 7, apiKey: 'secret-key');

  // Deliberately inert: nothing in this file exercises the rollback path that
  // revokes an already-issued key, so recording the call would be state no
  // test reads. See AuthBootstrapPort.revokeApiKey in orbi_runtime for when
  // it is actually invoked.
  @override
  Future<void> revokeApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
    required int apiKeyId,
  }) async {}

  // Deliberately inert: nothing in this file exercises NativeAuthService's
  // close(), which is the only caller. See AuthBootstrapPort.revokeOwnApiKey
  // in orbi_runtime for when it is actually invoked.
  @override
  Future<void> revokeOwnApiKey({
    required String baseUrl,
    required String database,
    required String apiKey,
  }) async {}

  // Deliberately inert: nothing in this file exercises the proactive
  // renewal cycle — see orbi_runtime/test/auth/native_auth_service_test.dart
  // for the fake that actually drives it.
  @override
  Future<ApiKeyRenewalResult> generateApiKey({
    required String baseUrl,
    required String database,
    required String currentApiKey,
    required String name,
    required DateTime expirationDate,
  }) async => throw UnimplementedError();
}

class FakeRuntime implements SessionRuntimePort {
  AppScope? active;

  @override
  Future<void> activate(AppScope scope, {String? apiKey}) async =>
      active = scope;

  @override
  Future<void> close() async => active = null;

  @override
  void applyUserLocale({String? language, String? timezone}) {}
}

class FakeBackend implements CredentialBackend, InstallationIdBackend {
  final values = <String, String>{};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  final scope = AppScope(
    appId: 'theos_panel',
    installationId: 'i-1',
    normalizedServerUrl: 'https://erp.test',
    database: 'demo',
    userId: 7,
  );
  const profile = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'seller',
    userId: 7,
    installationId: 'i-1',
    credentialReference: 'api-key',
  );

  test('login state never exposes submitted password', () async {
    final fake = FakeAuthService(
      const AuthServiceResult(
        status: AuthServiceStatus.authenticated,
        scope: null,
        profile: profile,
      ),
    );
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final states = <AuthViewState>[];
    container.listen(
      authControllerProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );
    await container
        .read(authControllerProvider.notifier)
        .login(
          serverUrl: 'https://erp.test',
          database: 'demo',
          login: 'seller',
          password: 'secret',
        );
    expect(fake.seenPassword, 'secret');
    expect(container.read(authControllerProvider).profile, profile);
    expect(container.read(authControllerProvider).message, isNull);
    expect(
      container.read(authControllerProvider).toString(),
      isNot(contains('secret')),
    );
    expect(
      states.map((state) => state.status),
      containsAllInOrder([
        AuthControllerStatus.required,
        AuthControllerStatus.loading,
        AuthControllerStatus.authenticated,
      ]),
    );
  });

  test('unsupported web is visible and not success', () async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(
          FakeAuthService(
            const AuthServiceResult(status: AuthServiceStatus.unsupportedWeb),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authControllerProvider.notifier)
        .login(
          serverUrl: 'https://erp.test',
          database: 'demo',
          login: 'seller',
          password: 'secret',
        );
    expect(
      container.read(authControllerProvider).status,
      AuthControllerStatus.unsupportedWeb,
    );
    expect(container.read(authControllerProvider).isBusy, isFalse);
  });

  test('restore and offline preserve identity scope', () async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(
          FakeAuthService(
            AuthServiceResult(
              status: AuthServiceStatus.restored,
              scope: scope,
              profile: profile,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(authControllerProvider.notifier)
        .restore(offline: true);
    expect(
      container.read(authControllerProvider).status,
      AuthControllerStatus.restored,
    );
    expect(container.read(authControllerProvider).profile?.userId, 7);
  });

  test('cold start restore falls back offline once without looping', () async {
    final service = _RestoreSequence();
    final result = await restoreOnce(service);
    expect(result.status, AuthServiceStatus.restored);
    expect(service.calls, [false, true]);
  });

  test('restore does not publish after notifier disposal', () async {
    final service = _BlockingAuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    final states = <AuthViewState>[];
    container.listen(
      authControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    final pending = container.read(authControllerProvider.notifier).restore();
    container.dispose();
    service.restoreCompleter.complete(
      const AuthServiceResult(status: AuthServiceStatus.restored),
    );
    await pending;
    expect(states, hasLength(2));
    expect(states.last.status, AuthControllerStatus.loading);
  });

  test('close does not publish after notifier disposal', () async {
    final service = _BlockingAuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    final states = <AuthViewState>[];
    container.listen(
      authControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    final pending = container.read(authControllerProvider.notifier).close();
    container.dispose();
    service.closeCompleter.complete();
    await pending;
    expect(states, hasLength(1));
  });

  test('loadProfile does not publish after notifier disposal', () async {
    final service = _BlockingAuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    final states = <AuthViewState>[];
    container.listen(
      authControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    final pending = container
        .read(authControllerProvider.notifier)
        .loadProfile();
    container.dispose();
    service.profileCompleter.complete(profile);
    await pending;
    expect(states, hasLength(1));
  });

  test('route policy defaults to deny and honors capability snapshot', () {
    const policy = RouteAccessPolicy();
    final capabilities = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: {'seller'},
    );
    expect(
      policy.allows('/sales', authenticated: true, capabilities: null),
      isFalse,
    );
    expect(
      policy.allows('/sales', authenticated: true, capabilities: capabilities),
      isTrue,
    );
    expect(
      policy.allows(
        '/collection',
        authenticated: true,
        capabilities: capabilities,
      ),
      isFalse,
    );
    // Todo usuario autenticado entra al área de sincronización (Modo Ruta,
    // cola offline); sin sesión, no.
    expect(
      policy.destinationAfterLogin(
        '/sync',
        authenticated: true,
        capabilities: capabilities,
      ),
      '/sync',
    );
    expect(
      policy.allows(
        '/sync/queue',
        authenticated: true,
        capabilities: capabilities,
      ),
      isTrue,
    );
    final warehouseOnly = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: {'warehouse'},
    );
    expect(
      policy.destinationAfterLogin(
        '/sync',
        authenticated: true,
        capabilities: warehouseOnly,
      ),
      '/sync',
    );
    // Sin permisos cargados todavía (o sin conexión) también se ve la
    // sincronización; sin sesión, no.
    expect(
      policy.allows('/sync/queue', authenticated: true, capabilities: null),
      isTrue,
    );
    expect(
      policy.allows('/sync', authenticated: false, capabilities: warehouseOnly),
      isFalse,
    );
  });

  test(
    'native service stores metadata, and with "Guardar clave" (default) logout '
    'preserves the credential: a later offline restore succeeds without the '
    'password',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final backend = FakeBackend();
      final runtime = FakeRuntime();
      final service = NativeAuthService(
        bootstrapPort: FakeBootstrap(),
        credentialStore: CredentialStore(
          backend,
          durability: CredentialDurability.secureStore,
        ),
        preferences: preferences,
        runtimePort: runtime,
        installationIds: InstallationIdStore(
          backend,
          generator: () => 'install-1',
        ),
      );

      final loggedIn = await service.login(
        serverUrl: 'https://erp.test',
        database: 'demo',
        login: 'seller',
        password: 'secret',
      );
      expect(loggedIn.profile?.userId, 7);
      expect(
        await service.loadProfileFor('https://erp.test', 'demo'),
        isNotNull,
      );
      await service.close();
      expect(runtime.active, isNull);
      final restored = await service.restore(offline: true);
      expect(restored.status, AuthServiceStatus.restored);
      expect(
        (await service.loadProfileFor('https://erp.test', 'demo'))?.login,
        'seller',
      );
    },
  );

  test(
    'without "Guardar clave" (persistCredential: false), logout still deletes '
    'the credential: a later offline restore asks to log in again, unchanged',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final backend = FakeBackend();
      final runtime = FakeRuntime();
      final service = NativeAuthService(
        bootstrapPort: FakeBootstrap(),
        credentialStore: CredentialStore(
          backend,
          durability: CredentialDurability.secureStore,
        ),
        preferences: preferences,
        runtimePort: runtime,
        installationIds: InstallationIdStore(
          backend,
          generator: () => 'install-1',
        ),
      );

      final loggedIn = await service.login(
        serverUrl: 'https://erp.test',
        database: 'demo',
        login: 'seller',
        password: 'secret',
        persistCredential: false,
      );
      expect(loggedIn.profile?.userId, 7);
      await service.close();
      expect(runtime.active, isNull);
      final restored = await service.restore(offline: true);
      expect(restored.status, AuthServiceStatus.required);
    },
  );

  test('credential retention flag controls secure backend storage', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final service = NativeAuthService(
      bootstrapPort: FakeBootstrap(),
      credentialStore: CredentialStore(
        backend,
        durability: CredentialDurability.secureStore,
      ),
      preferences: preferences,
      runtimePort: FakeRuntime(),
      installationIds: InstallationIdStore(
        backend,
        generator: () => 'install-no-retain',
      ),
    );

    await service.login(
      serverUrl: 'https://erp.test',
      database: 'demo',
      login: 'seller',
      password: 'secret',
      persistCredential: false,
    );
    expect(backend.values.values, isNot(contains('secret-key')));
  });

  test('profiles are selected by server and database without mixing', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final service = NativeAuthService(
      bootstrapPort: FakeBootstrap(),
      credentialStore: CredentialStore(
        backend,
        durability: CredentialDurability.secureStore,
      ),
      preferences: preferences,
      runtimePort: FakeRuntime(),
      installationIds: InstallationIdStore(
        backend,
        generator: () => 'install-1',
      ),
    );
    await service.login(
      serverUrl: 'https://one.test',
      database: 'one',
      login: 'alice',
      password: 'a',
    );
    await service.login(
      serverUrl: 'https://two.test',
      database: 'two',
      login: 'bob',
      password: 'b',
    );
    expect(
      (await service.loadProfileFor('https://one.test', 'one'))?.login,
      'alice',
    );
    expect(
      (await service.loadProfileFor('https://two.test', 'two'))?.login,
      'bob',
    );
    expect((await service.loadProfile())?.serverUrl, 'https://two.test');
  });
}
