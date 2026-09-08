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

class FakeBootstrap implements AuthBootstrapPort {
  @override
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
  }) async => const NativeAuthBootstrapResult(userId: 7, apiKey: 'secret-key');
}

class FakeRuntime implements SessionRuntimePort {
  AppScope? active;

  @override
  Future<void> activate(AppScope scope, {String? apiKey}) async =>
      active = scope;

  @override
  Future<void> close() async => active = null;
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
    expect(
      policy.destinationAfterLogin(
        '/sync',
        authenticated: true,
        capabilities: capabilities,
      ),
      '/',
    );
  });

  test(
    'native service stores only metadata in preferences and restores offline',
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
      final restored = await service.restore(offline: true);
      expect(restored.status, AuthServiceStatus.restored);
      expect(runtime.active?.installationId, 'install-1');
    },
  );

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
