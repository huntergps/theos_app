import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Backend implements CredentialBackend, InstallationIdBackend {
  final values = <String, String>{};

  /// Simulates the real-world failure this fake exists to reproduce: a
  /// secure-storage write that fails (e.g. the macOS keychain entitlement
  /// gap tracked in `docs/orbi_panel/PENDIENTES.md`) while installation-id
  /// bookkeeping — the same backend, a different key — keeps working.
  bool failCredentialWrite = false;

  @override
  Future<void> write(String key, String value) async {
    if (failCredentialWrite && !key.startsWith('orbi/installation/')) {
      throw StateError('disk full');
    }
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Runtime implements SessionRuntimePort {
  bool failActivation = false;
  AppScope? active;
  @override
  Future<void> activate(AppScope s, {String? apiKey}) async {
    if (failActivation) throw StateError('activation failed');
    active = s;
  }

  @override
  Future<void> close() async => active = null;
}

class _Bootstrap implements AuthBootstrapPort {
  /// The id `authenticateAndCreateApiKey` claims the server assigned to the
  /// issued key — mirrors `NativeAuthBootstrapResult.apiKeyId` so a test can
  /// force a real revoke attempt further down the login.
  int? apiKeyId = 99;
  bool failRevoke = false;
  final revokedApiKeyIds = <int>[];

  @override
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
  }) async =>
      NativeAuthBootstrapResult(userId: 7, apiKey: 'secret', apiKeyId: apiKeyId);

  @override
  Future<void> revokeApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
    required int apiKeyId,
  }) async {
    if (failRevoke) {
      throw const NativeAuthBootstrapRevocationException('revoke failed');
    }
    revokedApiKeyIds.add(apiKeyId);
  }
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
  bool failRefresh = false;
  @override
  Future<CapabilitySnapshot?> refresh(AppScope s, int company) async {
    if (failRefresh) throw StateError('capability refresh failed');
    return CapabilitySnapshot(
      scopeKey: s.scopeKey,
      companyId: company,
      revision: 2,
      fetchedAt: DateTime.utc(2026),
      permissions: ['seller'],
    );
  }

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
    _Identity identity, [
    ApiKeyIdentityProbe? apiKeyIdentityProbe,
    _Capabilities? capabilities,
    _Bootstrap? bootstrap,
  ]) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return NativeAuthService(
      bootstrapPort: bootstrap ?? _Bootstrap(),
      credentialStore: CredentialStore(
        backend,
        durability: CredentialDurability.secureStore,
      ),
      preferences: prefs,
      runtimePort: runtime,
      installationIds: InstallationIdStore(backend, generator: () => 'install'),
      identityReader: identity,
      capabilityPort: capabilities ?? _Capabilities(),
      apiKeyIdentityProbe: apiKeyIdentityProbe,
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

  test(
    'a failed local credential write revokes the just-issued API key',
    () async {
      final b = _Backend()..failCredentialWrite = true;
      final r = _Runtime();
      final i = _Identity();
      final bootstrap = _Bootstrap();
      final s = await service(b, r, i, null, null, bootstrap);

      await expectLater(
        s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        ),
        throwsStateError,
      );

      // The credential store write failed (`disk full`), but the server
      // already created the key for it — the point of this defect. Without
      // the fix, `revokedApiKeyIds` stays empty and that key is orphaned.
      expect(bootstrap.revokedApiKeyIds, [99]);
      expect(b.values.values, isNot(contains('secret')));
    },
  );

  test(
    'a failed revocation never replaces the original error, and is logged',
    () async {
      final b = _Backend()..failCredentialWrite = true;
      final r = _Runtime();
      final i = _Identity();
      final bootstrap = _Bootstrap()..failRevoke = true;
      final s = await service(b, r, i, null, null, bootstrap);

      final logs = <String>[];
      final previousOutput = logger.logOutput;
      logger.logOutput = (message) => logs.add(message.toString());
      addTearDown(() => logger.logOutput = previousOutput);

      Object? failure;
      try {
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
      } catch (error) {
        failure = error;
      }

      // The ugly case the coordinator asked about: revocation fails too
      // (typically the same connectivity problem that broke the local
      // write). The original error must still be exactly what a caller
      // sees — never replaced by the cleanup failure.
      expect(failure, isA<StateError>());
      expect((failure! as StateError).message, 'disk full');
      // And the now-permanently-orphaned credential must leave a trace,
      // naming the key and the user, never a secret.
      expect(
        logs.any(
          (line) =>
              line.contains('orphaned') &&
              line.contains('id=99') &&
              line.contains('login=u'),
        ),
        isTrue,
        reason: 'expected an orphaned-credential log line, got: $logs',
      );
      expect(logs.any((line) => line.contains('disk full')), isFalse);
    },
  );

  test('non-persistent login keeps the secret out of storage', () async {
    final b = _Backend(), r = _Runtime(), i = _Identity();
    final s = await service(b, r, i);
    final result = await s.login(
      serverUrl: 'https://erp.test',
      database: 'db',
      login: 'u',
      password: 'p',
      persistCredential: false,
    );
    expect(result.status, AuthServiceStatus.authenticated);
    expect(b.values.values, isNot(contains('secret')));
    expect((await s.restore()).status, AuthServiceStatus.required);
  });

  test('API key for another user is rejected before activation', () async {
    final b = _Backend(), r = _Runtime(), i = _Identity();
    final s = await service(
      b,
      r,
      i,
      (_) async => (userId: 8, login: 'erik@example.test'),
    );
    await expectLater(
      s.loginWithApiKey(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'carlos@example.test',
        apiKey: 'other-user-secret',
      ),
      throwsStateError,
    );
    expect(r.active, isNull);
    expect(b.values.values, isNot(contains('other-user-secret')));
  });

  for (final persistCredential in [true, false]) {
    test('API key failure restores prior profile and selection '
        '(persist=$persistCredential)', () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final s = await service(
        b,
        r,
        i,
        (_) async => (userId: 7, login: 'new-user'),
      );
      final old = await s.login(
        serverUrl: 'https://old.test',
        database: 'old_db',
        login: 'old-user',
        password: 'old-password',
      );
      expect(old.profile, isNotNull);
      i.invalid = true;

      await expectLater(
        s.loginWithApiKey(
          serverUrl: 'https://new.test',
          database: 'new_db',
          login: 'new-user',
          apiKey: 'new-secret',
          persistCredential: persistCredential,
        ),
        throwsFormatException,
      );

      final restored = await s.loadProfile();
      expect(restored?.serverUrl, 'https://old.test');
      expect(restored?.database, 'old_db');
      expect(restored?.login, 'old-user');
      expect(await s.loadProfileFor('https://new.test', 'new_db'), isNull);
      expect(b.values.values, isNot(contains('new-secret')));
      expect(b.values.values, contains('secret'));
      expect(r.active, isNull);
    });
  }

  test('API key activation failure restores prior profile', () async {
    final b = _Backend(), r = _Runtime(), i = _Identity();
    final s = await service(
      b,
      r,
      i,
      (_) async => (userId: 7, login: 'new-user'),
    );
    await s.login(
      serverUrl: 'https://old.test',
      database: 'old_db',
      login: 'old-user',
      password: 'old-password',
    );
    r.failActivation = true;
    await expectLater(
      s.loginWithApiKey(
        serverUrl: 'https://new.test',
        database: 'new_db',
        login: 'new-user',
        apiKey: 'new-secret',
      ),
      throwsStateError,
    );
    expect((await s.loadProfile())?.serverUrl, 'https://old.test');
    expect(await s.loadProfileFor('https://new.test', 'new_db'), isNull);
  });

  test('API key capability failure restores prior profile', () async {
    final b = _Backend(), r = _Runtime(), i = _Identity();
    final capabilities = _Capabilities();
    final s = await service(
      b,
      r,
      i,
      (_) async => (userId: 7, login: 'new-user'),
      capabilities,
    );
    await s.login(
      serverUrl: 'https://old.test',
      database: 'old_db',
      login: 'old-user',
      password: 'old-password',
    );
    capabilities.failRefresh = true;
    await expectLater(
      s.loginWithApiKey(
        serverUrl: 'https://new.test',
        database: 'new_db',
        login: 'new-user',
        apiKey: 'new-secret',
      ),
      throwsStateError,
    );
    expect((await s.loadProfile())?.serverUrl, 'https://old.test');
    expect(await s.loadProfileFor('https://new.test', 'new_db'), isNull);
  });

  test(
    'non-persistent API key refresh failure restores same-scope secret',
    () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final capabilities = _Capabilities();
      final s = await service(
        b,
        r,
        i,
        (_) async => (userId: 7, login: 'old-user'),
        capabilities,
      );
      await s.login(
        serverUrl: 'https://old.test',
        database: 'old_db',
        login: 'old-user',
        password: 'old-password',
      );
      capabilities.failRefresh = true;

      await expectLater(
        s.loginWithApiKey(
          serverUrl: 'https://old.test',
          database: 'old_db',
          login: 'old-user',
          apiKey: 'temporary-secret',
          persistCredential: false,
        ),
        throwsStateError,
      );

      expect(b.values.values, contains('secret'));
      expect(b.values.values, isNot(contains('temporary-secret')));
      expect((await s.loadProfile())?.login, 'old-user');
    },
  );
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

  test(
    'close deletes the bearer but preserves non-secret profile metadata',
    () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final s = await service(b, r, i);
      final result = await s.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
      );
      expect(result.profile, isNotNull);
      await s.close();

      final restored = await s.restore();
      expect(restored.status, AuthServiceStatus.required);
      final profile = await s.loadProfile();
      expect(profile?.serverUrl, 'https://erp.test');
      expect(profile?.database, 'db');
      expect(profile?.login, 'u');
    },
  );
}
