// W02 unblocks the pasted-API-key path in the browser: `WebSessionAuthService`
// (bootstrap.dart) used to implement only `AuthServicePort` and its `login()`
// always returned `required`, so `auth_controller.dart`'s
// `service is! ApiKeyAuthServicePort` check tripped and the user saw "El modo
// API key no está configurado en esta plataforma." — even though the login
// screen already offers the API key toggle and theos_pos's own web build
// already works this way. These tests fail on the old code (it does not
// implement `ApiKeyAuthServicePort` at all, so this file would not compile)
// and pass once `WebSessionAuthService` forwards `loginWithApiKey` to an
// in-memory-backed `NativeAuthService`.
//
// This does not close web/native parity: username+password in the browser is
// still blocked on a same-origin CORS decision another workstream is
// resolving (see docs/orbi_panel/decisions/W02-web-clave-api-pegada.md).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/bootstrap.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

class _InstallationBackend implements InstallationIdBackend {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Identity implements ActiveIdentityReader {
  @override
  Future<({int companyId, String? companyName, List<int> allowedCompanyIds})>
  read(AppScope scope) async =>
      (companyId: 1, companyName: null, allowedCompanyIds: const [1]);
}

class _Capabilities implements CapabilitySnapshotPort {
  @override
  Future<CapabilitySnapshot?> refresh(AppScope scope, int companyId) async =>
      null;
  @override
  Future<CapabilitySnapshot?> offline(AppScope scope, int companyId) async =>
      null;
}

class _FakeSessionRuntimePort implements SessionRuntimePort {
  int activateCalls = 0;
  String? lastApiKey;
  bool closed = false;
  @override
  Future<void> activate(AppScope scope, {String? apiKey}) async {
    activateCalls++;
    lastApiKey = apiKey;
  }

  @override
  Future<void> close() async => closed = true;
}

WebSessionAuthService _buildService({
  required SharedPreferences preferences,
  ApiKeyIdentityProbe? probe,
  SessionRuntimePort? runtimePort,
}) => WebSessionAuthService(
  runtime: SessionRuntime(),
  installationIds: InstallationIdStore(
    _InstallationBackend(),
    generator: () => 'install-1',
  ),
  identityReader: _Identity(),
  capabilityPort: _Capabilities(),
  preferences: preferences,
  apiKeyIdentityProbe: probe,
  apiKeyRuntimePort: runtimePort,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('WebSessionAuthService now implements the API key port', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = _buildService(preferences: preferences);
    expect(service, isA<ApiKeyAuthServicePort>());
  });

  test('pasting an API key authenticates through the web bridge', () async {
    final preferences = await SharedPreferences.getInstance();
    final runtimePort = _FakeSessionRuntimePort();
    final service = _buildService(
      preferences: preferences,
      runtimePort: runtimePort,
      probe: (_) async => (userId: 42, login: 'demo'),
    );

    final result = await service.loginWithApiKey(
      serverUrl: 'https://erp2.tecnosmart.com.ec',
      database: 'erp2_tecnosmart_com_ec',
      login: 'demo',
      apiKey: 'super-secret-key',
    );

    expect(result.status, AuthServiceStatus.authenticated);
    expect(result.profile?.userId, 42);
    expect(runtimePort.activateCalls, 1);
    expect(runtimePort.lastApiKey, 'super-secret-key');
  });

  test(
    'the pasted key never reaches SharedPreferences (localStorage on web)',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final service = _buildService(
        preferences: preferences,
        runtimePort: _FakeSessionRuntimePort(),
        probe: (_) async => (userId: 42, login: 'demo'),
      );

      await service.loginWithApiKey(
        serverUrl: 'https://erp2.tecnosmart.com.ec',
        database: 'erp2_tecnosmart_com_ec',
        login: 'demo',
        apiKey: 'super-secret-key',
      );

      // Only non-secret profile metadata (server/db/login/userId/…) may be
      // persisted. The secret itself must never show up in any stored value.
      final persistedValues = preferences
          .getKeys()
          .map((key) => preferences.get(key).toString())
          .toList();
      expect(
        persistedValues.any((value) => value.contains('super-secret-key')),
        isFalse,
      );
    },
  );

  test('logging out clears the in-memory key immediately, without waiting for a reload', () async {
    final preferences = await SharedPreferences.getInstance();
    final service = _buildService(
      preferences: preferences,
      runtimePort: _FakeSessionRuntimePort(),
      probe: (_) async => (userId: 9, login: 'cashier'),
    );
    await service.loginWithApiKey(
      serverUrl: 'https://erp2.tecnosmart.com.ec',
      database: 'erp2_tecnosmart_com_ec',
      login: 'cashier',
      apiKey: 'the-key',
    );
    expect(service.debugStoredApiKeyValues.values, contains('the-key'));

    await service.close();

    expect(service.debugStoredApiKeyValues, isEmpty);
  });

  test(
    'auth_controller no longer reports the API key mode as unconfigured on web',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final service = _buildService(
        preferences: preferences,
        runtimePort: _FakeSessionRuntimePort(),
        probe: (_) async => (userId: 3, login: 'seller'),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(service),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .loginWithApiKey(
            serverUrl: 'https://erp2.tecnosmart.com.ec',
            database: 'erp2_tecnosmart_com_ec',
            login: 'seller',
            apiKey: 'pasted-key',
          );

      final state = container.read(authControllerProvider);
      expect(
        state.message,
        isNot('El modo API key no está configurado en esta plataforma.'),
      );
      expect(state.status, AuthControllerStatus.authenticated);
    },
  );
}
