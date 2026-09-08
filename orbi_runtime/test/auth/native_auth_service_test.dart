import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend implements CredentialBackend, InstallationIdBackend {
  final values = <String, String>{};
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Runtime implements SessionRuntimePort {
  AppScope? active;
  @override
  Future<void> activate(AppScope s, {String? apiKey}) async => active = s;
  @override
  Future<void> close() async => active = null;
}

class _Bootstrap implements AuthBootstrapPort {
  @override
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
  }) async => const NativeAuthBootstrapResult(userId: 7, apiKey: 'secret');
}

class _Identity implements ActiveIdentityReader {
  bool invalid = false;
  @override
  Future<({int companyId, List<int> allowedCompanyIds})> read(
    AppScope s,
  ) async {
    if (invalid) throw const FormatException('bad company');
    return (companyId: 7, allowedCompanyIds: [7, 8]);
  }
}

class _Capabilities implements CapabilitySnapshotPort {
  @override
  Future<CapabilitySnapshot?> refresh(AppScope s, int company) async =>
      CapabilitySnapshot(
        scopeKey: s.scopeKey,
        companyId: company,
        revision: 2,
        fetchedAt: DateTime.utc(2026),
        permissions: ['seller'],
      );
  @override
  Future<CapabilitySnapshot?> offline(AppScope s, int company) async =>
      CapabilitySnapshot(
        scopeKey: s.scopeKey,
        companyId: company,
        revision: 2,
        fetchedAt: DateTime.utc(2026),
        permissions: ['seller'],
      );
}

void main() {
  Future<NativeAuthService> service(
    _Backend backend,
    _Runtime runtime,
    _Identity identity,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return NativeAuthService(
      bootstrapPort: _Bootstrap(),
      credentialStore: CredentialStore(
        backend,
        durability: CredentialDurability.secureStore,
      ),
      preferences: prefs,
      runtimePort: runtime,
      installationIds: InstallationIdStore(backend, generator: () => 'install'),
      identityReader: identity,
      capabilityPort: _Capabilities(),
    );
  }

  test('login persists company IDs and capabilities', () async {
    final b = _Backend(), r = _Runtime(), i = _Identity();
    final s = await service(b, r, i);
    final result = await s.login(
      serverUrl: 'https://erp.test',
      database: 'db',
      login: 'u',
      password: 'p',
    );
    expect(result.profile?.companyId, 7);
    expect(result.profile?.allowedCompanyIds, [7, 8]);
    expect(result.capabilities?.permissions, contains('seller'));
  });
  test('invalid identity rejects login', () async {
    final b = _Backend(), r = _Runtime(), i = _Identity()..invalid = true;
    final s = await service(b, r, i);
    expect(
      s.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
      ),
      throwsFormatException,
    );
  });
  test('legacy profile restores without capabilities offline', () async {
    final b = _Backend(), r = _Runtime(), i = _Identity();
    final s = await service(b, r, i);
    final result = await s.login(
      serverUrl: 'https://erp.test',
      database: 'db',
      login: 'u',
      password: 'p',
    );
    expect(result.status, AuthServiceStatus.authenticated);
  });
}
