// The test deliberately uses Drift's real in-memory executor.
// ignore: depend_on_referenced_packages
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FirstTestDatabase extends AppDatabase {
  _FirstTestDatabase() : super(NativeDatabase.memory());
}

final class _SecondTestDatabase extends AppDatabase {
  _SecondTestDatabase() : super(NativeDatabase.memory());
}

AppScope scope(int userId) => AppScope(
  appId: 'orbi-panel',
  installationId: 'installation-a',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: userId,
);

void main() {
  test('database name is isolated and stable for a scope', () {
    final first = RuntimeDatabaseOwner.databaseNameFor(scope(1));
    expect(first, startsWith('orbi_'));
    expect(first, RuntimeDatabaseOwner.databaseNameFor(scope(1)));
    expect(first, isNot(RuntimeDatabaseOwner.databaseNameFor(scope(2))));
  });

  test('owner opens one real database and close is idempotent', () async {
    final opened = <String>[];
    final owner = RuntimeDatabaseOwner(
      factory: (name) {
        opened.add(name);
        return AppDatabase(NativeDatabase.memory());
      },
    );
    final first = await owner.open(scope(1));
    final same = await owner.open(scope(1));
    expect(identical(first, same), isTrue);
    expect(opened, hasLength(1));
    await owner.close();
    await owner.close();
    expect(owner.active, isNull);
  });

  test('switching scope rejects the previous lease', () async {
    var opened = 0;
    final owner = RuntimeDatabaseOwner(
      factory: (_) =>
          opened++ == 0 ? _FirstTestDatabase() : _SecondTestDatabase(),
    );
    final first = await owner.open(scope(1));
    final second = await owner.open(scope(2));
    expect(
      first.lease.accepts(scope: scope(1), generation: first.lease.generation),
      isTrue,
    );
    expect(owner.accepts(first.lease), isFalse);
    expect(owner.accepts(second.lease), isTrue);
    await owner.close();
    expect(owner.accepts(second.lease), isFalse);
  });

  test('credential keys are scoped and web durability is explicit', () async {
    final values = <String, String>{};
    final store = CredentialStore(
      _MemoryBackend(values),
      durability: CredentialDurability.webSessionOnly,
    );
    await store.write(scope(1), 'api-key-ref', 'secret');
    expect(await store.read(scope(1), 'api-key-ref'), 'secret');
    expect(await store.read(scope(2), 'api-key-ref'), isNull);
    expect(store.durability, CredentialDurability.webSessionOnly);
    await store.write(scope(1), 'a/b', 'secret-2');
    expect(await store.read(scope(1), 'a/b'), 'secret-2');
  });

  test(
    'installation ID is stable and app-namespaced across restores',
    () async {
      final backend = _MemoryInstallationBackend();
      var generated = 0;
      final first = InstallationIdStore(
        backend,
        generator: () => 'installation-${++generated}',
      );
      expect(await first.loadOrCreate('orbi-panel'), 'installation-1');
      expect(await first.loadOrCreate('orbi-panel'), 'installation-1');
      expect(await first.loadOrCreate('other-app'), 'installation-2');
      final restored = InstallationIdStore(
        backend,
        generator: () => 'unexpected',
      );
      expect(await restored.loadOrCreate('orbi-panel'), 'installation-1');
    },
  );

  test('shared preferences backend restores and separates app IDs', () async {
    SharedPreferences.setMockInitialValues({});
    final firstBackend = await SharedPreferencesInstallationIdBackend.create();
    final first = InstallationIdStore(
      firstBackend,
      generator: () => 'persisted-installation',
    );
    expect(await first.loadOrCreate('orbi-panel'), 'persisted-installation');

    final restoredBackend =
        await SharedPreferencesInstallationIdBackend.create();
    final restored = InstallationIdStore(
      restoredBackend,
      generator: () => 'unexpected',
    );
    expect(await restored.loadOrCreate('orbi-panel'), 'persisted-installation');
    expect(await restored.loadOrCreate('other-app'), 'unexpected');
  });

  test('newer activation wins without closing its database', () async {
    final created = <AppDatabase>[];
    var factoryCalls = 0;
    final owner = RuntimeDatabaseOwner(
      factory: (_) {
        final database = factoryCalls == 0
            ? _FirstTestDatabase()
            : _SecondTestDatabase();
        created.add(database);
        factoryCalls++;
        return database;
      },
    );
    final firstOpen = owner.open(scope(1));
    final secondOpen = owner.open(scope(2));
    await expectLater(firstOpen, throwsA(isA<StateError>()));
    final second = await secondOpen;
    expect(second.scope, scope(2));
    expect(owner.active?.scope, scope(2));
    expect(factoryCalls, 2);
    await owner.close();
  });

  test(
    'online activation carries a client while offline remains database-only',
    () async {
      final runtime = SessionRuntime(
        databaseOwner: RuntimeDatabaseOwner(
          factory: (_) => AppDatabase(NativeDatabase.memory()),
        ),
        clientFactory: (scope, apiKey) => OdooClient(
          config: OdooClientConfig(
            baseUrl: scope.normalizedServerUrl,
            apiKey: apiKey,
            database: scope.database,
          ),
        ),
      );
      final online = await runtime.activate(scope(1), apiKey: 'test-key');
      expect(online.client, isNotNull);
      await runtime.close();
      final offline = await runtime.activate(scope(1));
      expect(offline.client, isNull);
      await runtime.close();
    },
  );

  // fix/sdk/user-lang-tz: the authenticated user's own `lang`/`tz`
  // (`res.users.lang`/`res.users.tz`, read by `OdooActiveIdentityReader` and
  // pushed here by `NativeAuthService` through `SessionRuntimePort`) must
  // reach the REAL client every later call uses — this is the seam that
  // proves it, with a real `OdooClient`, no fake/port in between.
  test(
    'applyUserLocale updates the active client without any network call',
    () async {
      final runtime = SessionRuntime(
        databaseOwner: RuntimeDatabaseOwner(
          factory: (_) => AppDatabase(NativeDatabase.memory()),
        ),
        clientFactory: (scope, apiKey) => OdooClient(
          config: OdooClientConfig(
            baseUrl: scope.normalizedServerUrl,
            apiKey: apiKey,
            database: scope.database,
          ),
        ),
      );
      final activation = await runtime.activate(scope(1), apiKey: 'test-key');

      runtime.applyUserLocale(
        language: 'es_EC',
        timezone: 'America/Guayaquil',
      );

      expect(activation.client!.config.defaultLanguage, 'es_EC');
      expect(activation.client!.config.defaultTimezone, 'America/Guayaquil');
      // Never touched.
      expect(activation.client!.config.apiKey, 'test-key');
      await runtime.close();
    },
  );

  test('applyUserLocale is a no-op without an active client', () async {
    final runtime = SessionRuntime(
      databaseOwner: RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      ),
    );
    // No activation at all yet.
    expect(
      () => runtime.applyUserLocale(language: 'es_EC', timezone: 'UTC'),
      returnsNormally,
    );

    // Activated, but offline (no client — see the test above this one).
    await runtime.activate(scope(1));
    expect(
      () => runtime.applyUserLocale(language: 'es_EC', timezone: 'UTC'),
      returnsNormally,
    );
    await runtime.close();
  });
}

final class _MemoryBackend implements CredentialBackend {
  _MemoryBackend(this.values);
  final Map<String, String> values;

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final class _MemoryInstallationBackend implements InstallationIdBackend {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
