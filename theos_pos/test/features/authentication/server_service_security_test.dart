import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show CredentialKeys;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_pos/core/security/ephemeral_credential_store.dart';
import 'package:theos_pos/core/session/session_scope.dart';
import 'package:theos_pos/features/authentication/services/server_service.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

final class _ControlledPreferences {
  _ControlledPreferences([Map<String, Object>? initial])
    : values = <String, Object>{...?initial} {
    when(() => instance.getString(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments.single as String;
      return values[key] as String?;
    });
    when(() => instance.setString(any(), any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1] as String;
      if (failingSetKeys.contains(key)) return false;
      values[key] = value;
      return true;
    });
    when(() => instance.remove(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments.single as String;
      if (failingRemoveKeys.contains(key)) return false;
      values.remove(key);
      return true;
    });
  }

  final SharedPreferences instance = _MockSharedPreferences();
  final Map<String, Object> values;
  final Set<String> failingSetKeys = <String>{};
  final Set<String> failingRemoveKeys = <String>{};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('server metadata never serializes credentials', () {
    final config = ServerConfig(
      name: 'ERP2',
      url: 'https://erp2.example.com',
      database: 'erp2',
      apiKey: 'secret-api-key',
      imStatusAccessToken: 'secret-token',
      partnerId: 7,
    );

    final json = config.toJson();

    expect(json, {
      'name': 'ERP2',
      'url': 'https://erp2.example.com',
      'database': 'erp2',
      'partnerId': 7,
    });
    expect(json.values, isNot(contains('secret-api-key')));
    expect(json.values, isNot(contains('secret-token')));
  });

  test('clean install exposes only ERP2 as the built-in server', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(serverServiceProvider);
    await pumpEventQueue();

    final servers = container.read(serverServiceProvider);
    expect(servers, hasLength(1));
    expect(servers.single.url, 'https://erp2.tecnosmart.com.ec');
    expect(servers.single.database, 'erp2_tecnosmart_com_ec');
    expect(servers.single.name, contains('ERP2'));
  });

  test('last-server lookup waits until the saved catalog is loaded', () async {
    final savedServer = ServerConfig(
      name: 'Saved ERP',
      url: 'https://saved.example.com',
      database: 'saved_db',
    );
    SharedPreferences.setMockInitialValues({
      'saved_servers': jsonEncode([savedServer.toJson()]),
      'last_server_url': savedServer.url,
      'last_server_db': savedServer.database,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final result = await container
        .read(serverServiceProvider.notifier)
        .loadLastServer();

    expect(result?.name, savedServer.name);
    expect(result?.url, savedServer.url);
    expect(result?.database, savedServer.database);
  });

  test('removes only the requested remembered credential scope', () async {
    final store = EphemeralCredentialStore();
    final container = ProviderContainer(
      overrides: [secureCredentialStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    final service = container.read(serverServiceProvider.notifier);
    const serverUrl = 'https://erp.example.com/';
    const database = 'erp_db';

    await service.storeCredential(
      serverUrl: serverUrl,
      database: database,
      apiKey: 'user-seven-key',
      userId: 7,
    );
    await service.storeCredential(
      serverUrl: serverUrl,
      database: database,
      apiKey: 'user-eight-key',
      userId: 8,
    );

    final userSevenScope = SessionScope(
      serverUrl: serverUrl,
      database: database,
      userId: 7,
    );
    final userEightScope = SessionScope(
      serverUrl: serverUrl,
      database: database,
      userId: 8,
    );
    final userSevenKey = CredentialKeys.scoped(
      userSevenScope.storageIdentifier,
      CredentialKeys.apiKey,
    );
    final userEightKey = CredentialKeys.scoped(
      userEightScope.storageIdentifier,
      CredentialKeys.apiKey,
    );
    expect(await store.retrieve(userSevenKey), 'user-seven-key');
    expect(await store.retrieve(userEightKey), 'user-eight-key');

    await service.removeStoredCredential(
      serverUrl: serverUrl,
      database: database,
      userId: 7,
    );

    expect(await store.retrieve(userSevenKey), isNull);
    expect(await store.retrieve(userEightKey), 'user-eight-key');
    expect(
      await service.findCredentialAsync(
        serverUrl: serverUrl,
        database: database,
        apiKey: 'user-seven-key',
      ),
      isNull,
    );
    expect(
      await service.findCredentialAsync(
        serverUrl: serverUrl,
        database: database,
        apiKey: 'user-eight-key',
      ),
      isNotNull,
    );
  });

  test('offline credentials expire at the 30 day boundary', () {
    final now = DateTime.utc(2026, 8, 26, 12);
    final valid = StoredCredential(
      serverUrl: 'https://erp.example.com',
      database: 'erp',
      apiKey: 'not-logged',
      userId: 7,
      lastLoginAt: now.subtract(const Duration(days: 29, hours: 23)),
    );
    final expired = StoredCredential(
      serverUrl: 'https://erp.example.com',
      database: 'erp',
      apiKey: 'not-logged',
      userId: 7,
      lastLoginAt: now.subtract(const Duration(days: 30)),
    );

    expect(valid.isValidAt(now), isTrue);
    expect(expired.isValidAt(now), isFalse);
  });

  test(
    'expired offline metadata and vault secret are pruned on load',
    () async {
      final now = DateTime.utc(2026, 8, 26, 12);
      const serverUrl = 'https://erp.example.com';
      const database = 'erp';
      const userId = 7;
      final scope = SessionScope(
        serverUrl: serverUrl,
        database: database,
        userId: userId,
      );
      final secretKey = CredentialKeys.scoped(
        scope.storageIdentifier,
        CredentialKeys.apiKey,
      );
      final store = EphemeralCredentialStore();
      await store.store(secretKey, 'expired-test-value');
      SharedPreferences.setMockInitialValues({
        'stored_credentials': jsonEncode([
          {
            'serverUrl': serverUrl,
            'database': database,
            'userId': userId,
            'lastLoginAt': now
                .subtract(const Duration(days: 31))
                .toIso8601String(),
            'credentialRef': scope.storageIdentifier,
          },
        ]),
      });
      final container = ProviderContainer(
        overrides: [
          secureCredentialStoreProvider.overrideWithValue(store),
          serverClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container
            .read(serverServiceProvider.notifier)
            .findCredentialAsync(
              serverUrl: serverUrl,
              database: database,
              apiKey: 'expired-test-value',
            ),
        isNull,
      );
      expect(await store.retrieve(secretKey), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('stored_credentials')!), isEmpty);
    },
  );

  test('credential and session survive a close/reopen within TTL', () async {
    final now = DateTime.utc(2026, 8, 26, 12);
    final store = EphemeralCredentialStore();
    final config = ServerConfig(
      name: 'ERP',
      url: 'https://erp.example.com',
      database: 'erp',
      apiKey: 'reopen-test-value',
    );
    final first = ProviderContainer(
      overrides: [
        secureCredentialStoreProvider.overrideWithValue(store),
        serverClockProvider.overrideWithValue(() => now),
      ],
    );
    await first.read(serverServiceProvider.notifier).saveLastServer(config);
    await first
        .read(serverServiceProvider.notifier)
        .commitAuthenticatedSession(config: config, userId: 7);
    first.dispose();

    final reopened = ProviderContainer(
      overrides: [
        secureCredentialStoreProvider.overrideWithValue(store),
        serverClockProvider.overrideWithValue(
          () => now.add(const Duration(days: 1)),
        ),
      ],
    );
    addTearDown(reopened.dispose);

    final restored = await reopened
        .read(serverServiceProvider.notifier)
        .loadLastServer();
    final offline = await reopened
        .read(serverServiceProvider.notifier)
        .findCredentialAsync(
          serverUrl: config.url,
          database: config.database,
          apiKey: 'reopen-test-value',
        );

    expect(restored?.apiKey, 'reopen-test-value');
    expect(offline?.userId, 7);
  });

  test(
    'storage failure propagates and restores a newly written secret',
    () async {
      final preferences = _ControlledPreferences();
      final store = EphemeralCredentialStore();
      final container = ProviderContainer(
        overrides: [
          secureCredentialStoreProvider.overrideWithValue(store),
          serverPreferencesProvider.overrideWithValue(
            Future<SharedPreferences>.value(preferences.instance),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = container.read(serverServiceProvider.notifier);
      await pumpEventQueue();
      preferences.failingSetKeys.add('stored_credentials');

      await expectLater(
        service.storeCredential(
          serverUrl: 'https://erp.example.com',
          database: 'erp',
          apiKey: 'rollback-test-value',
          userId: 7,
        ),
        throwsA(isA<SessionPersistenceException>()),
      );
      final scope = SessionScope(
        serverUrl: 'https://erp.example.com',
        database: 'erp',
        userId: 7,
      );
      expect(
        await store.retrieve(
          CredentialKeys.scoped(scope.storageIdentifier, CredentialKeys.apiKey),
        ),
        isNull,
      );
      expect(preferences.values['stored_credentials'], isNull);
    },
  );

  test(
    'session commit failure withdraws the newly stored offline credential',
    () async {
      final preferences = _ControlledPreferences();
      final store = EphemeralCredentialStore();
      final container = ProviderContainer(
        overrides: [
          secureCredentialStoreProvider.overrideWithValue(store),
          serverPreferencesProvider.overrideWithValue(
            Future<SharedPreferences>.value(preferences.instance),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = container.read(serverServiceProvider.notifier);
      await pumpEventQueue();
      preferences.failingSetKeys.add('current_session');
      final config = ServerConfig(
        name: 'ERP',
        url: 'https://erp.example.com',
        database: 'erp',
        apiKey: 'atomic-test-value',
      );

      await expectLater(
        service.commitAuthenticatedSession(config: config, userId: 7),
        throwsA(isA<SessionPersistenceException>()),
      );

      expect(service.currentSession, isNull);
      expect(
        await service.findCredentialAsync(
          serverUrl: config.url,
          database: config.database,
          apiKey: 'atomic-test-value',
        ),
        isNull,
      );
      final scope = SessionScope(
        serverUrl: config.url,
        database: config.database,
        userId: 7,
      );
      expect(
        await store.retrieve(
          CredentialKeys.scoped(scope.storageIdentifier, CredentialKeys.apiKey),
        ),
        isNull,
      );
      expect(preferences.values['stored_credentials'], isNull);
      expect(preferences.values['current_session'], isNull);
    },
  );

  test('corrupt credential metadata is surfaced to the caller', () async {
    SharedPreferences.setMockInitialValues({'stored_credentials': '{not-json'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(serverServiceProvider.notifier)
          .findCredentialAsync(
            serverUrl: 'https://erp.example.com',
            database: 'erp',
            apiKey: 'test-value',
          ),
      throwsFormatException,
    );
  });
}
