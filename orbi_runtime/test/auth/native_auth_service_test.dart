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

  /// Simulates a delete that never reaches the backend (offline, disk full,
  /// permission revoked mid-session) — used to prove an orphaned key is
  /// never offered as "remembered" just because `close()` could not scrub
  /// it (security review, 14-sep-2026).
  bool failCredentialDelete = false;

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
  Future<void> delete(String key) async {
    if (failCredentialDelete) throw StateError('delete failed');
    values.remove(key);
  }
}

class _Runtime implements SessionRuntimePort {
  bool failActivation = false;
  AppScope? active;

  /// The `apiKey` last handed to [activate] — `null` means the last
  /// activation was offline (see `SessionRuntime.activate`, whose real
  /// implementation only builds a client when this is non-null). A test
  /// resets this before the action under test to tell a fresh call apart
  /// from one made earlier in the same test.
  String? lastActivateApiKey;

  /// What `NativeAuthService` last handed to [applyUserLocale] — the seam it
  /// uses to push the authenticated user's own `lang`/`tz` onto the active
  /// session's real `OdooClient` (see `SessionRuntimeAdapter` in
  /// `native_auth_service.dart`, exercised for real in
  /// `session_runtime_test.dart`). `null` for either field means it was never
  /// called, or was called without that field — a test resets both before
  /// the action under test to tell the two apart.
  String? appliedLanguage;
  String? appliedTimezone;
  int applyUserLocaleCalls = 0;

  @override
  Future<void> activate(AppScope s, {String? apiKey}) async {
    if (failActivation) throw StateError('activation failed');
    active = s;
    lastActivateApiKey = apiKey;
  }

  @override
  Future<void> close() async => active = null;

  @override
  void applyUserLocale({String? language, String? timezone}) {
    applyUserLocaleCalls++;
    appliedLanguage = language;
    appliedTimezone = timezone;
  }
}

class _Bootstrap implements AuthBootstrapPort {
  /// The id `authenticateAndCreateApiKey` claims the server assigned to the
  /// issued key — mirrors `NativeAuthBootstrapResult.apiKeyId` so a test can
  /// force a real revoke attempt further down the login.
  int? apiKeyId = 99;
  bool failRevoke = false;
  final revokedApiKeyIds = <int>[];

  /// Whether the server accepts the password-free self-revoke RPC
  /// (`res.users.apikeys.revoke`) — mirrors `base.enable_programmatic_api_keys`
  /// being off by default in real Odoo, which is the common case a `close()`
  /// revoke attempt must survive.
  bool failOwnRevoke = false;
  final revokedOwnApiKeys = <String>[];

  /// Renovación proactiva (auditoría de sesión, 13-sep-2026). `null` ⇒
  /// `generateApiKey` responde normalmente con [renewedApiKey]/
  /// [renewedExpiresAt]; seteado ⇒ simula al servidor contestando que las
  /// claves programáticas están desactivadas.
  String? generateUnsupportedMessage;
  String renewedApiKey = 'renewed-secret';
  DateTime? renewedExpiresAt;
  Object? generateError;

  /// Registra, en orden, cada `currentApiKey` con la que se llamó
  /// `generateApiKey` — permite a un test comprobar que `generate` ocurrió
  /// ANTES que `revokeOwnApiKey` para esa misma clave.
  final generateCalls = <String>[];

  /// Orden real de las dos llamadas ("generate:" y "revoke:" seguido del
  /// secreto), para comprobar la secuencia exacta sin depender de comparar
  /// dos listas independientes.
  final callOrder = <String>[];

  @override
  Future<ApiKeyRenewalResult> generateApiKey({
    required String baseUrl,
    required String database,
    required String currentApiKey,
    required String name,
    required DateTime expirationDate,
  }) async {
    generateCalls.add(currentApiKey);
    callOrder.add('generate:$currentApiKey');
    final unsupported = generateUnsupportedMessage;
    if (unsupported != null) {
      throw ApiKeyRenewalUnsupportedException(unsupported);
    }
    final error = generateError;
    if (error != null) throw error;
    return ApiKeyRenewalResult(
      apiKey: renewedApiKey,
      expiresAt: renewedExpiresAt,
    );
  }

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

  @override
  Future<void> revokeOwnApiKey({
    required String baseUrl,
    required String database,
    required String apiKey,
  }) async {
    callOrder.add('revoke:$apiKey');
    if (failOwnRevoke) {
      throw StateError('Programmatic API keys are not enabled');
    }
    revokedOwnApiKeys.add(apiKey);
  }
}

class _Identity implements ActiveIdentityReader {
  bool invalid = false;

  /// `res.users.lang`/`res.users.tz` as the fake server would answer.
  /// `null` mirrors Odoo returning `false` for either field.
  String? lang = 'es_EC';
  String? tz = 'America/Guayaquil';

  /// How many times [read] was called — an offline restore must never call
  /// it (no identity RPC without connectivity).
  int readCalls = 0;

  @override
  Future<
    ({
      int companyId,
      String? companyName,
      String? name,
      List<int> allowedCompanyIds,
      String? lang,
      String? tz,
    })
  >
  read(AppScope s) async {
    readCalls++;
    if (invalid) throw const FormatException('bad company');
    return (
      companyId: 7,
      companyName: 'Empresa de prueba',
      name: 'Erik Salazar',
      allowedCompanyIds: [7, 8],
      lang: lang,
      tz: tz,
    );
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
    OfflineAllowanceStore? offlineAllowance,
    DateTime Function()? deviceNow,
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
      offlineAllowance: offlineAllowance,
      deviceNow: deviceNow,
    );
  }

  // --- Helpers para T1-T6 (auditoría de sesión, 14-sep-2026): a diferencia
  // de `service()`, que siempre arranca de preferencias vacías, estos dos
  // simulan "cerrar la pestaña y volver a entrar" — una SEGUNDA instancia de
  // `NativeAuthService` sobre el MISMO `_Backend` (el almacén de llaves) y
  // las MISMAS `SharedPreferences` (donde vive el perfil y la marca de
  // sesión abierta), con un `_Runtime` nuevo — igual que un proceso nuevo,
  // que no hereda nada del anterior salvo lo que quedó persistido.
  Future<(NativeAuthService, SharedPreferences)> openSession(
    _Backend backend,
    _Identity identity,
    _Runtime runtime, [
    ApiKeyIdentityProbe? apiKeyIdentityProbe,
    _Bootstrap? bootstrap,
    DateTime Function()? deviceNow,
  ]) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = NativeAuthService(
      bootstrapPort: bootstrap ?? _Bootstrap(),
      credentialStore: CredentialStore(
        backend,
        durability: CredentialDurability.secureStore,
      ),
      preferences: prefs,
      runtimePort: runtime,
      installationIds: InstallationIdStore(backend, generator: () => 'install'),
      identityReader: identity,
      capabilityPort: _Capabilities(),
      apiKeyIdentityProbe: apiKeyIdentityProbe,
      deviceNow: deviceNow,
    );
    return (svc, prefs);
  }

  NativeAuthService reopen(
    _Backend backend,
    SharedPreferences prefs,
    _Identity identity,
    _Runtime runtime, [
    ApiKeyIdentityProbe? apiKeyIdentityProbe,
    _Bootstrap? bootstrap,
    DateTime Function()? deviceNow,
  ]) {
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
      capabilityPort: _Capabilities(),
      apiKeyIdentityProbe: apiKeyIdentityProbe,
      deviceNow: deviceNow,
    );
  }

  // --- Causa raíz corregida el 14-sep-2026: «si cierro la ventana o
  // pestaña de Orbi y vuelvo a entrar pide hacer login y se pierde todo»
  // (reporte del dueño). Decisión: la sesión sobrevive a cerrar la pestaña,
  // el navegador o la app, CON O SIN «Guardar clave», hasta que la persona
  // cierre sesión, el servidor rechace la llave o venza. «Guardar clave»
  // pasa a servir sólo para volver a entrar sin escribir la clave DESPUÉS
  // de cerrar sesión. -------------------------------------------------------
  group('session survives closing the tab/app (14-sep-2026)', () {
    test(
      'T1: session survives reopening without "Guardar clave" — the old '
      'service deleted the key right after login and this would come back '
      '"required"',
      () async {
        final b = _Backend();
        final i = _Identity();
        final (s1, prefs) = await openSession(b, i, _Runtime());
        final result = await s1.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        expect(result.status, AuthServiceStatus.authenticated);

        // "Cerrar la pestaña" = nada más que un proceso nuevo leyendo lo
        // mismo que quedó persistido — nunca se llama a `s1.close()`.
        final s2 = reopen(b, prefs, i, _Runtime());
        final restored = await s2.restore();

        expect(restored.status, AuthServiceStatus.restored);
      },
    );

    test(
      'T2: closing a remembered session does not auto-restore — "Guardar '
      'clave" only skips typing the password again, it is not a standing '
      'silent session',
      () async {
        final b = _Backend();
        final i = _Identity();
        final (s1, prefs) = await openSession(b, i, _Runtime());
        final result = await s1.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        ); // persistCredential: true por omisión.
        await s1.close();

        final s2 = reopen(b, prefs, i, _Runtime());
        final restored = await s2.restore();

        expect(restored.status, AuthServiceStatus.required);
        expect(await s2.hasStoredCredential(result.profile!), isTrue);
      },
    );

    test(
      'T3: closing a reopened non-remembered session still revokes the key '
      'exactly once — the in-memory bookkeeping the old fix relied on does '
      'not survive reopening the tab, reading it from storage does',
      () async {
        final b = _Backend();
        final i = _Identity();
        final bootstrap = _Bootstrap();
        final (s1, prefs) = await openSession(b, i, _Runtime(), null, bootstrap);
        await s1.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
          persistCredential: false,
        );

        final s2 = reopen(b, prefs, i, _Runtime(), null, bootstrap);
        final restored = await s2.restore();
        expect(restored.status, AuthServiceStatus.restored);

        await s2.close();

        expect(bootstrap.revokedOwnApiKeys, ['secret']);
        expect(b.values.values, isNot(contains('secret')));
      },
    );

    test(
      'T4: an open non-remembered session is never offered as a remembered '
      'login, before or after closing it',
      () async {
        final b = _Backend();
        final i = _Identity();
        final (s, _) = await openSession(b, i, _Runtime());
        final result = await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        expect(result.profile, isNotNull);

        expect(
          await s.findRememberedCredential('https://erp.test', 'db', 'u'),
          isNull,
        );

        await s.close();

        expect(
          await s.findRememberedCredential('https://erp.test', 'db', 'u'),
          isNull,
        );
      },
    );

    test(
      'T5: an expired key clears the open session too — a later restore '
      'from a reopened tab must not resurrect it',
      () async {
        final b = _Backend();
        final i = _Identity();
        final (s1, prefs) = await openSession(b, i, _Runtime());
        await s1.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );

        await s1.closeExpired();

        final s2 = reopen(b, prefs, i, _Runtime());
        expect((await s2.restore()).status, AuthServiceStatus.required);
      },
    );

    test(
      'T6: reopening an open session offline activates without ever '
      'building an online client',
      () async {
        final b = _Backend();
        final i = _Identity();
        final (s1, prefs) = await openSession(b, i, _Runtime());
        await s1.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );

        final r2 = _Runtime()..lastActivateApiKey = 'sentinel-not-cleared';
        final s2 = reopen(b, prefs, i, r2);

        final restored = await s2.restore(offline: true);

        expect(restored.status, AuthServiceStatus.restored);
        // El fake SÍ registra el `apiKey` recibido — la prueba comprueba
        // que sigue `null`, nunca que el fake lo ignoró.
        expect(r2.lastActivateApiKey, isNull);
      },
    );
  });

  // --- Segunda revisión (14-sep-2026, dos huecos de seguridad hallados
  // sobre 2a5c3f6): «recordada» dejó de deducirse de la marca de sesión
  // abierta — que sólo identifica UNA sesión por instalación y que `close()`
  // podía borrar antes que la llave, dejando una llave huérfana sin marca
  // que se ofrecía como si estuviera guardada — y pasó a vivir en una
  // bandera persistente POR CREDENCIAL (servidor+base+userId), separada de
  // la marca. La marca también pasó a identificar la sesión por sus tres
  // campos explícitos, nunca por un `profileKey` de sólo servidor+base, para
  // que la sesión abierta de un usuario nunca opine sobre la credencial
  // guardada de otro en la misma base. -----------------------------------
  group('recorded credential is independent from the open session '
      '(security review, 14-sep-2026)', () {
    test(
      'orphan non-remembered key is never offered, even when close() '
      'cannot scrub it from the backend',
      () async {
        final b = _Backend()..failCredentialDelete = true;
        final r = _Runtime();
        final i = _Identity();
        final s = await service(b, r, i);
        final result = await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
          persistCredential: false,
        );

        // close() tries to delete the orphaned key and fails — the secret
        // is still physically in the backend afterwards.
        await s.close();
        expect(b.values.values, contains('secret'));

        // It must still never be offered: the "remembered" flag was never
        // set for this login in the first place, independent of whatever
        // physically survives in the backend.
        expect(await s.hasStoredCredential(result.profile!), isFalse);
      },
    );

    test(
      "another user's open session does not hide a remembered key on the "
      'same database',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity();
        final s = await service(b, r, i, (client) async {
          return client.apiKey == 'secret-b'
              ? (userId: 22, login: 'userB')
              : (userId: 11, login: 'userA');
        });

        final resultB = await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'userB',
          apiKey: 'secret-b',
        );
        await s.close();

        // userA logs in without "Guardar clave" on the SAME server+database
        // and leaves the session open (never closes it).
        await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'userA',
          apiKey: 'secret-a',
          persistCredential: false,
        );

        expect(await s.hasStoredCredential(resultB.profile!), isTrue);
      },
    );

    test('legacy remembered key survives the upgrade', () async {
      final b = _Backend();
      final i = _Identity();
      final (legacy, prefs) = await openSession(b, i, _Runtime());
      final loggedIn = await legacy.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
      );
      final profile = loggedIn.profile!;

      // Strip everything this security review adds, to reproduce exactly
      // what an installation upgrading from the previously published
      // version has: a profile and its secret, no "remembered" flag, no
      // open-session marker, no migration guard.
      for (final key in Set<String>.from(prefs.getKeys())) {
        if (key.startsWith('orbi/auth/remembered/') ||
            key.startsWith('orbi/auth/open_session/') ||
            key.startsWith('orbi/auth/remembered_migration/')) {
          await prefs.remove(key);
        }
      }

      // A fresh service instance = the app reopening after the upgrade.
      final reopened = reopen(b, prefs, i, _Runtime());
      expect(await reopened.hasStoredCredential(profile), isTrue);
    });

    test('login without remember un-remembers a previous key', () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final s = await service(b, r, i);
      final first = await s.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
      );
      expect(await s.hasStoredCredential(first.profile!), isTrue);
      await s.close();

      // The same person logs in again, this time WITHOUT "Guardar clave" —
      // their new choice must win over the old one.
      final second = await s.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
        persistCredential: false,
      );

      expect(await s.hasStoredCredential(second.profile!), isFalse);
    });
  });

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
    expect(result.profile?.companyName, 'Empresa de prueba');
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

  // 🔴 Renombrada y reescrita el 14-sep-2026: esta prueba se llamaba
  // "non-persistent login keeps the secret out of storage" y afirmaba
  // justo el bug de causa raíz que este commit corrige — sin «Guardar
  // clave», la llave se borraba del almacén nada más emitirse, y por eso
  // `restore()` daba `required` incluso SIN cerrar la pestaña. Ahora la
  // llave se queda en el almacén mientras la sesión sigue abierta (así
  // sobrevive a cerrar la pestaña/app), y sólo `close()` la revoca y borra.
  test(
    'non-persistent login keeps the session open (and the secret in '
    'storage) until it is explicitly closed',
    () async {
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
      expect(b.values.values, contains('secret'));
      expect((await s.restore()).status, AuthServiceStatus.restored);

      await s.close();

      expect(b.values.values, isNot(contains('secret')));
      expect((await s.restore()).status, AuthServiceStatus.required);
    },
  );

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

  // --- «Recordar la llave tras salir» (decisión del dueño, 13-sep-2026,
  // ver W04-el-navegador-tambien-guarda.md): `close()` dejó de revocar y
  // borrar la llave — con «Guardar clave» activo (el caso por omisión de
  // `login()`/`loginWithApiKey()` en estos tests), cerrar sesión sólo
  // termina el runtime en memoria. Las dos pruebas que antes afirmaban lo
  // contrario ("close revokes...", "close never blocks logout when the
  // server refuses to revoke...") describían exactamente el comportamiento
  // que la decisión revocó; su garantía real — que un fallo de red al
  // revocar nunca bloquea la operación — sigue viva, sólo que ahora es
  // responsabilidad de `forgetStoredCredential` ("Olvidar la clave
  // guardada"), no de `close()`. Ver el grupo `forgetStoredCredential`. -----
  // 🔴 Renombrada y corregida el 14-sep-2026: hasta entonces afirmaba que
  // `restore()` volvía a autenticar SOLO por haber cerrado sesión con
  // «Guardar clave» activo, sin que el operador pidiera entrar de nuevo —
  // eso confundía «recordar la llave» con «seguir con la sesión abierta».
  // La decisión del dueño (14-sep-2026) es explícita: «Guardar clave» sólo
  // sirve para volver a entrar SIN escribir la contraseña DESPUÉS de cerrar
  // sesión — una acción explícita del operador
  // ([loginWithStoredCredential]) — nunca un restore silencioso. Un
  // `close()` explícito SIEMPRE borra la marca de sesión abierta, con o sin
  // «Guardar clave»; ver T2 más abajo, que cubre exactamente este contrato.
  test(
    'close preserves the profile and the bearer credential, but a '
    'subsequent silent restore still asks to log in again — only an '
    'explicit loginWithStoredCredential skips the password',
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

      expect(b.values.values, contains('secret'));
      final restored = await s.restore();
      expect(restored.status, AuthServiceStatus.required);
      final profile = await s.loadProfile();
      expect(profile?.serverUrl, 'https://erp.test');
      expect(profile?.database, 'db');
      expect(profile?.login, 'u');
      expect(await s.hasStoredCredential(profile!), isTrue);
    },
  );

  test(
    'close never revokes nor deletes the credential, even when the server '
    'would have refused a revoke attempt (there is none to make)',
    () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final bootstrap = _Bootstrap()..failOwnRevoke = true;
      final s = await service(b, r, i, null, null, bootstrap);
      await s.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
      );

      await s.close();

      expect(r.active, isNull);
      expect(bootstrap.revokedOwnApiKeys, isEmpty);
      expect(b.values.values, contains('secret'));
    },
  );

  test(
    'close on a password session that logged in WITHOUT "Guardar clave" '
    'revokes the key on the server: nothing survives, unlike a stored one, '
    'which close() must never touch',
    () async {
      // 🔴 Corregido el 13-sep-2026, y otra vez el 14-sep-2026: la primera
      // vez, sin «Guardar clave», `login()` borraba la llave del almacén
      // nada más emitirla, así que `close()` — que sólo sabía leerla del
      // almacén — nunca llegaba a revocarla: quedaba huérfana en el
      // servidor hasta vencer por su cuenta. Eso se arregló acordándose de
      // la llave EN MEMORIA — pero eso reintrodujo el bug de causa raíz que
      // este commit corrige: la memoria se pierde al cerrar la pestaña, así
      // que una sesión sin «Guardar clave» no sobrevivía ni un F5. Ahora la
      // llave se queda en el almacén mientras la sesión sigue abierta (por
      // eso YA NO desaparece nada más loguearse, a diferencia de la
      // aserción que tenía esta prueba antes de esta reescritura) y
      // `close()` la lee de ahí para revocarla y borrarla.
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final bootstrap = _Bootstrap();
      final s = await service(b, r, i, null, null, bootstrap);
      await s.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
        persistCredential: false,
      );
      // La llave sigue en el almacén MIENTRAS la sesión está abierta — es
      // justo lo que hace posible reabrir la pestaña sin perder la sesión.
      expect(b.values.values, contains('secret'));

      await s.close();

      expect(bootstrap.revokedOwnApiKeys, ['secret']);
      expect(b.values.values, isNot(contains('secret')));
      expect((await s.restore()).status, AuthServiceStatus.required);
    },
  );

  test(
    'close on a password session that logged in WITH "Guardar clave" never '
    'revokes: the whole point of the decision is that the key survives',
    () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final bootstrap = _Bootstrap();
      final s = await service(b, r, i, null, null, bootstrap);
      await s.login(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        password: 'p',
      );

      await s.close();

      expect(bootstrap.revokedOwnApiKeys, isEmpty);
      expect(b.values.values, contains('secret'));
    },
  );

  test(
    'close on a session that logged in with a pasted API key (not a '
    'password) never revokes it, even without "Guardar clave": that key is '
    'the operator\'s own, not one this service issued',
    () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final bootstrap = _Bootstrap();
      final s = await service(
        b,
        r,
        i,
        (_) async => (userId: 7, login: 'u'),
        null,
        bootstrap,
      );
      await s.loginWithApiKey(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        apiKey: 'pasted-by-operator',
        persistCredential: false,
      );

      await s.close();

      expect(bootstrap.revokedOwnApiKeys, isEmpty);
    },
  );

  test(
    'close on a loginWithApiKey(passwordDerived: true) session — the web '
    'path, which fetches the key from /orbi/auth/token before calling '
    'loginWithApiKey — revokes it too when it wasn\'t persisted, same as a '
    'native password login',
    () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final bootstrap = _Bootstrap();
      final s = await service(
        b,
        r,
        i,
        (_) async => (userId: 7, login: 'u'),
        null,
        bootstrap,
      );
      await s.loginWithApiKey(
        serverUrl: 'https://erp.test',
        database: 'db',
        login: 'u',
        apiKey: 'token-issued-secret',
        persistCredential: false,
        passwordDerived: true,
      );

      await s.close();

      expect(bootstrap.revokedOwnApiKeys, ['token-issued-secret']);
    },
  );

  // --- forgetStoredCredential («Olvidar la clave guardada»): el único
  // camino que revoca y borra una llave guardada ahora que `close()` ya no
  // lo hace. -----------------------------------------------------------
  group('forgetStoredCredential', () {
    test(
      'revokes this device\'s own key on the server before deleting the '
      'local copy',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap();
        final s = await service(b, r, i, null, null, bootstrap);
        final result = await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        expect(bootstrap.revokedOwnApiKeys, isEmpty);

        await s.forgetStoredCredential(result.profile!);

        // The exact bearer secret that was in local storage is the one
        // handed to the server-side self-revoke call — never a different
        // key, never every key the user owns.
        expect(bootstrap.revokedOwnApiKeys, ['secret']);
        expect(b.values.values, isNot(contains('secret')));
        expect(await s.hasStoredCredential(result.profile!), isFalse);
      },
    );

    test(
      'never blocks — and still deletes locally — when the server refuses '
      'to revoke the key (e.g. programmatic API keys disabled, or offline)',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap()..failOwnRevoke = true;
        final s = await service(b, r, i, null, null, bootstrap);
        final result = await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );

        final logs = <String>[];
        final previousOutput = logger.logOutput;
        logger.logOutput = (message) => logs.add(message.toString());
        addTearDown(() => logger.logOutput = previousOutput);

        // Must not throw: a cleanup failure must never prevent forgetting.
        await s.forgetStoredCredential(result.profile!);

        expect(b.values.values, isNot(contains('secret')));
        expect(
          logs.any(
            (line) => line.contains('revoc') && line.contains('login=u'),
          ),
          isTrue,
          reason: 'expected a revoke-failure log line, got: $logs',
        );
      },
    );
  });

  // --- Entrar de nuevo sin escribir la clave, y que convivan varios
  // usuarios en el mismo equipo (decisión del dueño, 13-sep-2026). --------
  group('findRememberedCredential / loginWithStoredCredential', () {
    test('no hay nada recordado antes de un primer login', () async {
      final b = _Backend(), r = _Runtime(), i = _Identity();
      final s = await service(b, r, i);
      expect(
        await s.findRememberedCredential('https://erp.test', 'db', 'u'),
        isNull,
      );
    });

    test(
      'tras un login con Guardar clave, findRememberedCredential encuentra '
      'la llave, y loginWithStoredCredential entra sin contraseña',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final s = await service(
          b,
          r,
          i,
          (_) async => (userId: 7, login: 'u'),
        );
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        await s.close();
        expect(r.active, isNull, reason: 'close() terminó el runtime');

        final remembered = await s.findRememberedCredential(
          'https://erp.test',
          'db',
          'u',
        );
        expect(remembered, isNotNull);
        expect(remembered!.login, 'u');

        final result = await s.loginWithStoredCredential(remembered);

        expect(result.status, AuthServiceStatus.authenticated);
        expect(r.active, isNotNull);
      },
    );

    test(
      'dos usuarios del mismo servidor+base: elegir a uno usa SU llave, '
      'nunca la del otro',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final s = await service(b, r, i, (client) async {
          // El identity probe distingue por la llave que el propio
          // OdooClient lleva configurada — cada usuario "trae" la suya, y
          // esto sigue siendo correcto en el RE-login vía
          // loginWithStoredCredential (misma llave, misma identidad).
          return client.apiKey == 'secret-erik'
              ? (userId: 11, login: 'erik')
              : (userId: 22, login: 'carlos');
        });

        // erik entra y guarda su llave.
        await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'erik',
          apiKey: 'secret-erik',
        );
        await s.close();

        // carlos entra después, en el MISMO servidor+base, y también guarda.
        await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'carlos',
          apiKey: 'secret-carlos',
        );
        await s.close();

        final erikRemembered = await s.findRememberedCredential(
          'https://erp.test',
          'db',
          'erik',
        );
        final carlosRemembered = await s.findRememberedCredential(
          'https://erp.test',
          'db',
          'carlos',
        );
        expect(erikRemembered, isNotNull);
        expect(carlosRemembered, isNotNull);
        expect(erikRemembered!.userId, 11);
        expect(carlosRemembered!.userId, 22);

        // Elegir a erik activa el runtime con SU scope (userId 11), nunca
        // con el de carlos.
        final result = await s.loginWithStoredCredential(erikRemembered);
        expect(result.status, AuthServiceStatus.authenticated);
        expect(r.active?.userId, 11);

        // Olvidar la llave de erik no toca la de carlos.
        await s.forgetStoredCredential(erikRemembered);
        expect(await s.hasStoredCredential(erikRemembered), isFalse);
        expect(await s.hasStoredCredential(carlosRemembered), isTrue);
      },
    );

    test(
      'una llave vencida/revocada (401 del servidor) se borra sola y ya no '
      'se vuelve a ofrecer',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        var rejectNext = false;
        final s = await service(b, r, i, (client) async {
          if (rejectNext) {
            throw const OdooAuthenticationException('llave vencida');
          }
          return (userId: 7, login: 'u');
        });
        await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          apiKey: 'secret',
        );
        await s.close();
        final remembered = await s.findRememberedCredential(
          'https://erp.test',
          'db',
          'u',
        );
        expect(remembered, isNotNull);

        rejectNext = true;
        await expectLater(
          s.loginWithStoredCredential(remembered!),
          throwsA(isA<OdooAuthenticationException>()),
        );

        expect(await s.hasStoredCredential(remembered), isFalse);
        expect(
          await s.findRememberedCredential('https://erp.test', 'db', 'u'),
          isNull,
        );
      },
    );

    test(
      'un fallo que NO es un rechazo del servidor (p. ej. sin red) '
      'conserva la llave intacta',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        var fail = false;
        final s = await service(b, r, i, (client) async {
          if (fail) throw const OdooConnectionException('sin red');
          return (userId: 7, login: 'u');
        });
        await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          apiKey: 'secret',
        );
        await s.close();
        final remembered = await s.findRememberedCredential(
          'https://erp.test',
          'db',
          'u',
        );

        fail = true;
        await expectLater(
          s.loginWithStoredCredential(remembered!),
          throwsA(isA<OdooConnectionException>()),
        );

        expect(await s.hasStoredCredential(remembered), isTrue);
      },
    );
  });

  // --- Renovación proactiva de la clave API (diseño del dueño,
  // 13-sep-2026): con la clave a menos del 25 % de su vida restante (o
  // menos de 6 horas, lo que ocurra primero), la app en línea pide una
  // clave nueva ANTES de que caduque la actual. ---------------------------
  group('renewApiKeyIfNeeded', () {
    test(
      'con la clave por debajo del umbral, genera la clave nueva y SÓLO '
      'DESPUÉS revoca la vieja, en ese orden',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap()
          ..renewedApiKey = 'fresh-secret'
          ..renewedExpiresAt = DateTime.utc(2026, 9, 14, 12);
        final s = await service(b, r, i, null, null, bootstrap);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        // Vida total de 24 horas; a las 19h ya quedan sólo 5h — por debajo
        // de los dos umbrales (6h absolutas y 25 % = 6h para esta vida
        // total), así que debe renovar.
        final issuedAt = DateTime.utc(2026, 9, 13, 0);
        final expiresAt = DateTime.utc(2026, 9, 14, 0);
        await s.recordApiKeyLifetime(issuedAt: issuedAt, expiresAt: expiresAt);

        await s.renewApiKeyIfNeeded(now: DateTime.utc(2026, 9, 13, 19));

        expect(
          bootstrap.callOrder,
          ['generate:secret', 'revoke:secret'],
          reason: 'generate debe ocurrir ANTES que revoke, sobre la MISMA '
              'clave vieja',
        );
        // El runtime sigue activo — nunca se cerró la sesión por renovar.
        expect(r.active, isNotNull);
        // La clave NUEVA quedó guardada; la vieja ya no está en el almacén.
        expect(b.values.values, contains('fresh-secret'));
        expect(b.values.values, isNot(contains('secret')));
        final profile = await s.loadProfile();
        expect(profile?.apiKeyExpiresAt, DateTime.utc(2026, 9, 14, 12));
      },
    );

    test(
      'si falla la revocación de la clave vieja tras renovar, la sesión '
      'sigue funcionando con la clave NUEVA',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap()
          ..renewedApiKey = 'fresh-secret'
          ..failOwnRevoke = true;
        final s = await service(b, r, i, null, null, bootstrap);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        await s.recordApiKeyLifetime(
          issuedAt: DateTime.utc(2026, 9, 13, 0),
          expiresAt: DateTime.utc(2026, 9, 14, 0),
        );

        // No debe lanzar: un `revoke` fallido tras un `generate` exitoso es
        // best-effort, nunca una razón para tumbar la sesión ya renovada.
        await s.renewApiKeyIfNeeded(now: DateTime.utc(2026, 9, 13, 19));

        expect(r.active, isNotNull);
        expect(b.values.values, contains('fresh-secret'));
        final profile = await s.loadProfile();
        expect(profile?.apiKeyIssuedAt, DateTime.utc(2026, 9, 13, 19));
      },
    );

    test(
      'si el servidor contesta que las claves programáticas están '
      'desactivadas, no se cierra la sesión: sigue con la clave actual',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap()
          ..generateUnsupportedMessage =
              'Programmatic API keys are not enabled';
        final s = await service(b, r, i, null, null, bootstrap);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        await s.recordApiKeyLifetime(
          issuedAt: DateTime.utc(2026, 9, 13, 0),
          expiresAt: DateTime.utc(2026, 9, 14, 0),
        );

        await s.renewApiKeyIfNeeded(now: DateTime.utc(2026, 9, 13, 19));

        // Nunca se intentó revocar nada, y la clave ACTUAL sigue siendo la
        // única en el almacén: esto es informativo, no un fallo de sesión.
        expect(bootstrap.revokedOwnApiKeys, isEmpty);
        expect(r.active, isNotNull);
        expect(b.values.values, contains('secret'));
        final profile = await s.loadProfile();
        expect(profile?.apiKeyExpiresAt, DateTime.utc(2026, 9, 14, 0));
      },
    );

    test(
      'por encima del umbral todavía no renueva: ni generate ni revoke se '
      'llaman',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap();
        final s = await service(b, r, i, null, null, bootstrap);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        await s.recordApiKeyLifetime(
          issuedAt: DateTime.utc(2026, 9, 13, 0),
          expiresAt: DateTime.utc(2026, 9, 14, 0),
        );

        // A las 10h de 24h de vida total quedan 14h restantes: muy por
        // encima de los 6h/25 % — no debe tocar nada todavía.
        await s.renewApiKeyIfNeeded(now: DateTime.utc(2026, 9, 13, 10));

        expect(bootstrap.generateCalls, isEmpty);
        expect(bootstrap.revokedOwnApiKeys, isEmpty);
        expect(b.values.values, contains('secret'));
      },
    );

    test(
      'sin vida de clave conocida (login con API key pegada), no evalúa '
      'nada: el respaldo reactivo ante un 401 sigue siendo el único camino',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap();
        final s = await service(b, r, i, null, null, bootstrap);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        // Nunca se llamó recordApiKeyLifetime/apiKeyIssuedAt/apiKeyExpiresAt
        // quedan en null para este perfil.
        await s.renewApiKeyIfNeeded(now: DateTime.utc(2026, 9, 13, 19));

        expect(bootstrap.generateCalls, isEmpty);
      },
    );
  });

  // fix/sdk/user-lang-tz: Odoo works in the operator's own language and
  // timezone (`res.users.lang`/`res.users.tz`), never a hardcoded
  // `es_EC`/`America/Guayaquil` and never the SDK's `en_US` default. This
  // group proves `NativeAuthService` reads both from the identity RPC (or,
  // offline, from the already-persisted profile) and pushes them onto the
  // active session's client through `SessionRuntimePort.applyUserLocale` —
  // never inventing a value of its own.
  group('user locale (lang/tz)', () {
    test(
      'login applies the identity\'s lang/tz to the active session client',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity()
          ..lang = 'es_EC'
          ..tz = 'America/Guayaquil';
        final s = await service(b, r, i);

        final result = await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );

        expect(result.profile?.lang, 'es_EC');
        expect(result.profile?.tz, 'America/Guayaquil');
        expect(r.appliedLanguage, 'es_EC');
        expect(r.appliedTimezone, 'America/Guayaquil');
      },
    );

    test(
      'loginWithApiKey applies the identity\'s lang/tz the same way',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity()
          ..lang = 'es_EC'
          ..tz = 'America/Guayaquil';
        final s = await service(
          b,
          r,
          i,
          (_) async => (userId: 7, login: 'u'),
        );

        final result = await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          apiKey: 'pasted-key',
        );

        expect(result.profile?.lang, 'es_EC');
        expect(result.profile?.tz, 'America/Guayaquil');
        expect(r.appliedLanguage, 'es_EC');
        expect(r.appliedTimezone, 'America/Guayaquil');
      },
    );

    test(
      'an online restore re-reads the identity and re-applies lang/tz',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity()
          ..lang = 'es_EC'
          ..tz = 'America/Guayaquil';
        final s = await service(b, r, i);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        // No se cierra sesión: la sesión sigue ABIERTA (la marca que
        // permite a `restore()` reactivar sola, auditoría de sesión,
        // 14-sep-2026) — sólo se limpian los valores aplicados por el
        // propio `login()` para probar que la siguiente aserción viene de
        // `restore()`, no de un resto de arriba.
        r.appliedLanguage = null;
        r.appliedTimezone = null;

        final restored = await s.restore();

        expect(restored.status, AuthServiceStatus.restored);
        expect(r.appliedLanguage, 'es_EC');
        expect(r.appliedTimezone, 'America/Guayaquil');
      },
    );

    // Contrato real (revisado el 14-sep-2026, tras comprobar que la primera
    // versión de esta prueba pasaba con un fake que ignoraba `apiKey` y por
    // tanto no probaba nada): un restore sin conexión NUNCA activa con una
    // llave ni llama al lector de identidad — `client == null` es la señal
    // de "sin sesión en línea" que usan `warehouse_operation_port.dart`,
    // `json2_read_adapters.dart` y `runtime_catalog_composition.dart` para
    // rechazar en local sin tocar la red, y crear un cliente aquí rompería
    // esa señal. El `lang`/`tz` que ya trae el perfil persistido llegan al
    // cliente en la SIGUIENTE activación en línea (login o restore en
    // línea), nunca durante el restore sin conexión mismo.
    test(
      'an offline restore neither reads identity nor applies any locale — '
      'lang/tz only reach the client on a later online login/restore',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity()
          ..lang = 'es_EC'
          ..tz = 'America/Guayaquil';
        final s = await service(b, r, i);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        // La sesión sigue ABIERTA (no se llama a `close()`): un restore sin
        // conexión de una sesión abierta es justo el caso real que arregla
        // la auditoría del 14-sep-2026 (arrancar sin red mientras la sesión
        // sigue abierta), y el que aquí interesa probar.
        r.appliedLanguage = null;
        r.appliedTimezone = null;
        r.lastActivateApiKey = 'sentinel-not-cleared';
        final readCallsBeforeOfflineRestore = i.readCalls;

        final restored = await s.restore(offline: true);

        expect(restored.status, AuthServiceStatus.restored);
        // No client, no identity RPC, no locale applied while offline.
        expect(r.lastActivateApiKey, isNull);
        expect(i.readCalls, readCallsBeforeOfflineRestore);
        expect(r.appliedLanguage, isNull);
        expect(r.appliedTimezone, isNull);

        // The next ONLINE restore is what actually re-applies the user's
        // lang/tz — already covered by 'an online restore re-reads the
        // identity and re-applies lang/tz' above, exercised here too so
        // this test documents the full, real lifecycle in one place.
        final onlineRestored = await s.restore();
        expect(onlineRestored.status, AuthServiceStatus.restored);
        expect(r.appliedLanguage, 'es_EC');
        expect(r.appliedTimezone, 'America/Guayaquil');
      },
    );

    // Contrato real (revisado tras el hallazgo del 14-sep-2026): `client ==
    // null` es la señal de "sin sesión en línea" que usan
    // `warehouse_operation_port.dart:57-62`, `json2_read_adapters.dart:140-141`
    // y `runtime_catalog_composition.dart:43-45` para rechazar en local, sin
    // tocar la red. Un restore sin conexión JAMÁS debe activar con una llave
    // — eso construiría un cliente real y rompería esa señal para esos tres
    // puertos. Esta prueba corre en ROJO contra 41ee000 (que sí pasaba
    // `apiKey: secret` ahí) antes de revertir ese código.
    test(
      'an offline restore activates the session WITHOUT a key: no online '
      'client is created',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity()
          ..lang = 'es_EC'
          ..tz = 'America/Guayaquil';
        final s = await service(b, r, i);
        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );
        // La sesión sigue ABIERTA: sin marca (borrada por un `close()`) este
        // restore ni siquiera llegaría a activar nada, así que dejarla
        // abierta es lo que hace que esta prueba examine lo que dice probar.
        r.lastActivateApiKey = 'sentinel-not-cleared';

        await s.restore(offline: true);

        expect(r.lastActivateApiKey, isNull);
      },
    );

    test(
      'when res.users has no lang/tz (Odoo returning false), nothing is '
      'applied and nothing is invented',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity()
          ..lang = null
          ..tz = null;
        final s = await service(b, r, i);

        await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
        );

        expect(r.applyUserLocaleCalls, greaterThan(0));
        expect(r.appliedLanguage, isNull);
        expect(r.appliedTimezone, isNull);
      },
    );

    test(
      'a profile saved before lang/tz existed loads without error, as null',
      () {
        final json = {
          'serverUrl': 'https://erp.test',
          'database': 'db',
          'login': 'u',
          'userId': 7,
          'installationId': 'install',
          'credentialReference': 'api-key',
        };

        final profile = AuthProfile.fromJson(json);

        expect(profile.lang, isNull);
        expect(profile.tz, isNull);
      },
    );
  });

  // --- Límite de sesión sin conexión (decisión del dueño, 14-sep-2026):
  // máximo 3 días sin hablar con Odoo, parametrizable en el servidor
  // (`offline_max_days`). `OfflineAllowanceStore` (unidad, en
  // `offline_allowance_test.dart`) decide el "sí/no"; este grupo comprueba
  // cómo `NativeAuthService.restore(offline: true)` lo aplica de verdad,
  // sin activar la sesión ni tocar nada local cuando se rechaza. --------
  group('offline session limit (14-sep-2026)', () {
    const serverUrl = 'https://erp.test';
    const database = 'db';

    test(
      'offline restore is refused after max days',
      () async {
        final backend = _Backend();
        final identity = _Identity();
        final (svc, prefs) = await openSession(backend, identity, _Runtime());
        final loginResult = await svc.login(
          serverUrl: serverUrl,
          database: database,
          login: 'u',
          password: 'p',
        );
        expect(loginResult.status, AuthServiceStatus.authenticated);
        final scope = loginResult.scope!;

        // Fuerza "la última conexión buena fue hace 4 días" — pasa el
        // máximo por omisión de 3.
        await OfflineAllowanceStore(prefs).recordOnline(
          serverUrl: scope.normalizedServerUrl,
          database: scope.database,
          userId: scope.userId,
          nowUtc: DateTime.now().toUtc().subtract(const Duration(days: 4)),
        );

        final readCallsAfterLogin = identity.readCalls;
        final freshRuntime = _Runtime();
        final s2 = reopen(backend, prefs, identity, freshRuntime);
        final restored = await s2.restore(offline: true);

        expect(restored.status, AuthServiceStatus.offlineExpired);
        expect(
          restored.offlineAllowance?.status,
          OfflineAllowanceStatus.expired,
        );
        // Nunca se activó el runtime — la sesión sigue sin abrirse.
        expect(freshRuntime.active, isNull);
        // Sin ningún RPC de identidad nuevo — nunca se tocó la red.
        expect(identity.readCalls, readCallsAfterLogin);
      },
    );

    test(
      'offline restore within the limit still works',
      () async {
        final backend = _Backend();
        final identity = _Identity();
        final (svc, prefs) = await openSession(backend, identity, _Runtime());
        final loginResult = await svc.login(
          serverUrl: serverUrl,
          database: database,
          login: 'u',
          password: 'p',
        );
        final scope = loginResult.scope!;
        await OfflineAllowanceStore(prefs).recordOnline(
          serverUrl: scope.normalizedServerUrl,
          database: scope.database,
          userId: scope.userId,
          nowUtc: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        );

        final freshRuntime = _Runtime();
        final s2 = reopen(backend, prefs, identity, freshRuntime);
        final restored = await s2.restore(offline: true);

        expect(restored.status, AuthServiceStatus.restored);
        expect(freshRuntime.active, isNotNull);
        // Activación sin conexión: nunca se manda la llave — el fake
        // registra `null` cuando `activate` se llamó sin `apiKey`.
        expect(freshRuntime.lastActivateApiKey, isNull);
      },
    );

    test('device clock rollback refuses offline restore', () async {
      final backend = _Backend();
      final identity = _Identity();
      final (svc, prefs) = await openSession(backend, identity, _Runtime());
      final loginResult = await svc.login(
        serverUrl: serverUrl,
        database: database,
        login: 'u',
        password: 'p',
      );
      final scope = loginResult.scope!;
      final allowanceStore = OfflineAllowanceStore(prefs);
      final farFuture = DateTime.now().toUtc().add(const Duration(days: 1));
      // "Se vio" el reloj del equipo en el futuro (una sesión anterior, sin
      // retroceder todavía) — evaluar ahora con la hora real (mucho antes)
      // debe leerse como un retroceso, nunca como un vencimiento normal.
      await allowanceStore.evaluate(
        serverUrl: scope.normalizedServerUrl,
        database: scope.database,
        userId: scope.userId,
        deviceNowUtc: farFuture,
      );

      final freshRuntime = _Runtime();
      final s2 = reopen(backend, prefs, identity, freshRuntime);
      final restored = await s2.restore(offline: true);

      expect(restored.status, AuthServiceStatus.offlineExpired);
      expect(
        restored.offlineAllowance?.status,
        OfflineAllowanceStatus.clockRollback,
      );
      expect(freshRuntime.active, isNull);
    });

    test(
      'online restore records last online and is never blocked',
      () async {
        final backend = _Backend();
        final identity = _Identity();
        final (svc, prefs) = await openSession(backend, identity, _Runtime());
        final loginResult = await svc.login(
          serverUrl: serverUrl,
          database: database,
          login: 'u',
          password: 'p',
        );
        final scope = loginResult.scope!;
        // Se fuerza "hace 10 días" para comprobar que un restore EN LÍNEA
        // jamás lo mira — sólo lo hace `restore(offline: true)`.
        await OfflineAllowanceStore(prefs).recordOnline(
          serverUrl: scope.normalizedServerUrl,
          database: scope.database,
          userId: scope.userId,
          nowUtc: DateTime.now().toUtc().subtract(const Duration(days: 10)),
        );

        final freshRuntime = _Runtime();
        final s2 = reopen(backend, prefs, identity, freshRuntime);
        final restored = await s2.restore();

        expect(restored.status, AuthServiceStatus.restored);
        expect(freshRuntime.lastActivateApiKey, isNotNull);

        // Y quedó registrada una conexión buena reciente — un futuro
        // `restore(offline: true)` ya no debe verla vencida.
        final allowance = await OfflineAllowanceStore(prefs).evaluate(
          serverUrl: scope.normalizedServerUrl,
          database: scope.database,
          userId: scope.userId,
          deviceNowUtc: DateTime.now().toUtc(),
        );
        expect(allowance.isAllowed, isTrue);
      },
    );

    test('expired offline keeps key, marker and queue', () async {
      final backend = _Backend();
      final identity = _Identity();
      final (svc, prefs) = await openSession(backend, identity, _Runtime());
      final loginResult = await svc.login(
        serverUrl: serverUrl,
        database: database,
        login: 'u',
        password: 'p',
      );
      final scope = loginResult.scope!;
      await OfflineAllowanceStore(prefs).recordOnline(
        serverUrl: scope.normalizedServerUrl,
        database: scope.database,
        userId: scope.userId,
        nowUtc: DateTime.now().toUtc().subtract(const Duration(days: 4)),
      );
      final credentialCountBefore = backend.values.length;

      final freshRuntime = _Runtime();
      final s2 = reopen(backend, prefs, identity, freshRuntime);
      final restored = await s2.restore(offline: true);
      expect(restored.status, AuthServiceStatus.offlineExpired);

      // La llave, el perfil y la marca de sesión abierta siguen intactos —
      // no se borró nada por vencer el plazo (decisión del dueño: nunca se
      // borran datos locales ni la cola offline).
      expect(backend.values.length, credentialCountBefore);
      final profile = await s2.loadProfile();
      expect(profile, isNotNull);
      expect(await s2.hasStoredCredential(profile!), isTrue);
      // La MARCA de sesión abierta también sigue ahí: un restore EN LÍNEA
      // posterior (cuando vuelva la red) reactiva la MISMA sesión sin pedir
      // nada de nuevo — nunca cayó a "required".
      final onlineRestore = await reopen(
        backend,
        prefs,
        identity,
        _Runtime(),
      ).restore();
      expect(onlineRestore.status, AuthServiceStatus.restored);
    });
  });

  // --- PIN de vendedor: la llave sobrevive a cerrar sesión mientras esté
  // retenida para el PIN (decisión del dueño, 14-sep-2026: «el PIN mantiene
  // el tope de vendedor al entrar o cambiar de usuario»; regresión del
  // commit 6becdca que dejó a `close()` borrando cualquier llave sin
  // «Guardar clave», incluida la que el PIN necesitaba reutilizar). --------
  group('PIN de vendedor retiene la llave entre sesiones (14-sep-2026)', () {
    test(
      'pin login works after closing the session',
      () async {
        final b = _Backend();
        final i = _Identity();
        final bootstrap = _Bootstrap();
        // `loginWithPinCredential` reactiva vía `loginWithApiKey`, que
        // sondea la identidad de la llave contra el servidor — el mismo
        // sondeo falso que ya usan las pruebas de `loginWithStoredCredential`
        // más arriba, para no hacer una llamada de red real en la prueba.
        Future<({int userId, String login})> probe(OdooClient client) async =>
            (userId: 7, login: 'u');
        final (s1, prefs) = await openSession(b, i, _Runtime(), probe, bootstrap);
        final result = await s1.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        expect(result.status, AuthServiceStatus.authenticated);
        await s1.retainCredentialForPin(result.profile!, true);

        await s1.close();

        final s2 = reopen(b, prefs, i, _Runtime(), probe, bootstrap);
        final pinResult = await s2.loginWithPinCredential(result.profile!);

        expect(pinResult.status, AuthServiceStatus.authenticated);
        expect(bootstrap.revokedOwnApiKeys, isEmpty);
      },
    );

    test(
      'pin-retained key is never offered as remembered',
      () async {
        final b = _Backend();
        final i = _Identity();
        final bootstrap = _Bootstrap();
        final (s1, prefs) = await openSession(b, i, _Runtime(), null, bootstrap);
        final result = await s1.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        await s1.retainCredentialForPin(result.profile!, true);
        await s1.close();

        final s2 = reopen(b, prefs, i, _Runtime(), null, bootstrap);

        expect(await s2.hasStoredCredential(result.profile!), isFalse);
        expect(
          await s2.findRememberedCredential('https://erp.test', 'db', 'u'),
          isNull,
        );
      },
    );

    test(
      'removing the pin deletes a non-remembered key',
      () async {
        final b = _Backend(), r = _Runtime(), i = _Identity();
        final bootstrap = _Bootstrap();
        final s = await service(b, r, i, null, null, bootstrap);
        final result = await s.login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        await s.retainCredentialForPin(result.profile!, true);
        await s.close();
        // Retenida por PIN: close() no la tocó, sigue físicamente en el
        // almacén aunque la marca de sesión abierta ya se borró.
        expect(b.values.values, contains('secret'));

        await s.retainCredentialForPin(result.profile!, false);

        expect(bootstrap.revokedOwnApiKeys, ['secret']);
        expect(b.values.values, isNot(contains('secret')));
        expect(await s.hasStoredCredential(result.profile!), isFalse);
      },
    );

    test(
      'pin login for another user of the same database',
      () async {
        final b = _Backend(), r = _Runtime();
        final i = _Identity();
        final bootstrap = _Bootstrap();
        final s = await service(b, r, i, (client) async {
          return client.apiKey == 'secret-b'
              ? (userId: 22, login: 'userB')
              : (userId: 11, login: 'userA');
        }, null, bootstrap);

        final resultA = await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'userA',
          apiKey: 'secret-a',
          persistCredential: false,
        );
        await s.retainCredentialForPin(resultA.profile!, true);
        await s.close();

        final resultB = await s.loginWithApiKey(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'userB',
          apiKey: 'secret-b',
          persistCredential: false,
        );
        await s.retainCredentialForPin(resultB.profile!, true);
        await s.close();

        final profiles = await s.pinRetainedProfilesFor(
          'https://erp.test',
          'db',
        );
        expect(profiles.map((p) => p.userId).toSet(), {11, 22});

        final profileB = await s.loadProfileForLogin(
          'https://erp.test',
          'db',
          'userB',
        );
        final loginResult = await s.loginWithPinCredential(profileB!);

        expect(loginResult.status, AuthServiceStatus.authenticated);
        expect(loginResult.profile!.userId, 22);
        expect(r.active?.userId, 22);
      },
    );
  });

  // --- «Orbi debe funcionar offline: el cambio de usuario con PIN también»
  // (decisión del dueño, 14-sep-2026) — `loginWithPinCredential(profile,
  // offline: true)` reactiva sin red, sujeto al MISMO límite de días que
  // `restore(offline: true)` ya aplica a la sesión que estaba abierta. -----
  group('PIN de vendedor sin conexión (14-sep-2026)', () {
    const serverUrl = 'https://erp.test';
    const database = 'db';

    test(
      'pin login works offline within the limit',
      () async {
        final b = _Backend();
        final i = _Identity();
        final bootstrap = _Bootstrap();
        final (s1, prefs) = await openSession(b, i, _Runtime(), null, bootstrap);
        final result = await s1.login(
          serverUrl: serverUrl,
          database: database,
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        expect(result.status, AuthServiceStatus.authenticated);
        await s1.retainCredentialForPin(result.profile!, true);
        await s1.close();

        final r2 = _Runtime()..lastActivateApiKey = 'sentinel-not-cleared';
        final s2 = reopen(b, prefs, i, r2, null, bootstrap);

        final pinResult = await s2.loginWithPinCredential(
          result.profile!,
          offline: true,
        );

        expect(pinResult.status, AuthServiceStatus.restored);
        // Sin conexión no se crea cliente: el fake SÍ registra el `apiKey`
        // que recibió — la prueba comprueba que sigue `null`, nunca que el
        // fake lo ignoró.
        expect(r2.lastActivateApiKey, isNull);
        expect(pinResult.profile!.userId, result.profile!.userId);

        // La marca de sesión abierta quedó escrita para ESTE usuario: un
        // restore posterior (sin volver a pasar por PIN) reconoce la misma
        // sesión — nunca "required".
        final s3 = reopen(b, prefs, i, _Runtime(), null, bootstrap);
        final restored = await s3.restore(offline: true);
        expect(restored.status, AuthServiceStatus.restored);
        expect(restored.profile!.userId, result.profile!.userId);
      },
    );

    test(
      'offline pin login refused after max days',
      () async {
        final b = _Backend();
        final i = _Identity();
        final bootstrap = _Bootstrap();
        final (s1, prefs) = await openSession(b, i, _Runtime(), null, bootstrap);
        final result = await s1.login(
          serverUrl: serverUrl,
          database: database,
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        await s1.retainCredentialForPin(result.profile!, true);
        final scope = result.scope!;
        // Fuerza "la última conexión buena fue hace 4 días" — pasa el
        // máximo por omisión de 3.
        await OfflineAllowanceStore(prefs).recordOnline(
          serverUrl: scope.normalizedServerUrl,
          database: scope.database,
          userId: scope.userId,
          nowUtc: DateTime.now().toUtc().subtract(const Duration(days: 4)),
        );
        await s1.close();

        final freshRuntime = _Runtime();
        final s2 = reopen(b, prefs, i, freshRuntime, null, bootstrap);
        final pinResult = await s2.loginWithPinCredential(
          result.profile!,
          offline: true,
        );

        expect(pinResult.status, AuthServiceStatus.offlineExpired);
        expect(
          pinResult.offlineAllowance?.status,
          OfflineAllowanceStatus.expired,
        );
        // Nunca se activó el runtime — la sesión sigue sin abrirse.
        expect(freshRuntime.active, isNull);
      },
    );

    test(
      'offline pin login requires pin retention',
      () async {
        final b = _Backend();
        final i = _Identity();
        final bootstrap = _Bootstrap();
        final (s1, prefs) = await openSession(b, i, _Runtime(), null, bootstrap);
        final result = await s1.login(
          serverUrl: serverUrl,
          database: database,
          login: 'u',
          password: 'p',
          persistCredential: false,
        );
        // Nunca se llama a retainCredentialForPin: la bandera de retención
        // por PIN nunca se puso para este usuario.
        await s1.close();

        final s2 = reopen(b, prefs, i, _Runtime(), null, bootstrap);
        final pinResult = await s2.loginWithPinCredential(
          result.profile!,
          offline: true,
        );

        expect(pinResult.status, AuthServiceStatus.required);
      },
    );
  });
}
