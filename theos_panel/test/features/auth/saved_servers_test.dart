import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/saved_servers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  SavedServer server(String id, {String url = 'HTTPS://Example.COM/orbi/'}) =>
      SavedServer(id: id, name: 'Orbi $id', url: url, database: 'demo');

  test('CRUD persists and reloads saved server metadata', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SavedServersStore(preferences);
    await store.upsert(server('one'));

    expect(store.load(), hasLength(1));
    expect(store.load().single.url, 'https://example.com/orbi');
    expect(SavedServersStore(preferences).load().single.id, 'one');

    await store.remove('one');
    expect(store.load(), isEmpty);
  });

  test(
    'keeps environment and reads old entries without the field as null',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final store = SavedServersStore(preferences);
      await store.upsert(
        SavedServer(
          id: 'test-server',
          name: 'Mepriga',
          url: 'https://mepriga.example.com',
          database: 'mepriga',
          environment: ServerEnvironment.test,
        ),
      );
      expect(
        store.load().single.environment,
        ServerEnvironment.test,
      );

      // Un acceso guardado ANTES de que existiera este campo no trae la
      // clave `environment` en absoluto — la versión sigue siendo 1, y debe
      // seguir cargando, sólo que sin ambiente («sin indicar»).
      final legacyPayload = jsonEncode({
        'version': 1,
        'servers': [
          {
            'id': 'legacy',
            'name': 'Servidor viejo',
            'url': 'https://legacy.example.com',
            'database': 'legacy',
          },
        ],
      });
      SharedPreferences.setMockInitialValues({
        SavedServersStore.key: legacyPayload,
      });
      final legacyPreferences = await SharedPreferences.getInstance();
      final legacyServer = SavedServersStore(legacyPreferences).load().single;
      expect(legacyServer.environment, isNull);

      // Al volver a guardar ese mismo acceso, el campo queda escrito de
      // forma explícita (aunque sea `null`), tal como pide el diseño.
      final legacyStore = SavedServersStore(legacyPreferences);
      await legacyStore.upsert(legacyServer);
      final rewritten = jsonDecode(
        legacyPreferences.getString(SavedServersStore.key)!,
      );
      expect(
        (rewritten['servers'] as List).single,
        containsPair('environment', isNull),
      );
    },
  );

  test('normalizes valid URLs and rejects unsafe URLs', () {
    expect(
      SavedServersStore.normalizeUrl('HTTP://EXAMPLE.COM/a///'),
      'http://example.com/a',
    );
    expect(
      SavedServersStore.normalizeUrl('https://EXAMPLE.COM/'),
      'https://example.com',
    );
    expect(
      SavedServersStore.normalizeUrl('https://example.com'),
      'https://example.com',
    );
    expect(SavedServersStore.validateUrl('https://example.com/a'), isNull);
    expect(
      SavedServersStore.validateUrl('https://user:pass@example.com'),
      isNotNull,
    );
    expect(SavedServersStore.validateUrl('https://example.com?a=1'), isNotNull);
    expect(
      SavedServersStore.validateUrl('https://example.com#part'),
      isNotNull,
    );
    expect(SavedServersStore.validateUrl('ftp://example.com'), isNotNull);
    expect(SavedServersStore.validateUrl('https://exa%20mple.com'), isNotNull);
    expect(SavedServersStore.validateUrl('https://example.com:0'), isNotNull);
    expect(
      SavedServersStore.validateUrl('https://example.com:65536'),
      isNotNull,
    );
    expect(
      () => SavedServersStore.normalizeUrl('not a URL'),
      throwsFormatException,
    );
  });

  test('rejects duplicate URL and database without clobbering', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SavedServersStore(preferences);
    await store.upsert(server('one'));

    await expectLater(store.upsert(server('two')), throwsFormatException);
    expect(store.load().map((item) => item.id), ['one']);
  });

  test('corrupt payload throws and remains untouched', () async {
    SharedPreferences.setMockInitialValues({SavedServersStore.key: '{broken'});
    final preferences = await SharedPreferences.getInstance();
    final store = SavedServersStore(preferences);

    expect(() => store.load(), throwsFormatException);
    expect(preferences.getString(SavedServersStore.key), '{broken');
  });

  test('corrupt payload with duplicate IDs throws', () async {
    final duplicate = jsonEncode({
      'version': 1,
      'servers': [
        server('same').toJson(),
        server('same', url: 'https://other.example.com').toJson(),
      ],
    });
    SharedPreferences.setMockInitialValues({SavedServersStore.key: duplicate});
    final preferences = await SharedPreferences.getInstance();

    expect(() => SavedServersStore(preferences).load(), throwsFormatException);
  });

  test('persisted metadata never includes credentials', () async {
    final preferences = await SharedPreferences.getInstance();
    await SavedServersStore(preferences).upsert(server('one'));
    final payload = preferences.getString(SavedServersStore.key)!;

    expect(jsonDecode(payload), isNot(contains('password')));
    expect(payload, isNot(contains('apiKey')));
    expect(payload, isNot(contains('token')));
  });

  test('overlapping mutations are serialized without lost updates', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SavedServersStore(preferences);
    await Future.wait([
      store.upsert(server('one')),
      store.upsert(server('two', url: 'https://second.example.com/')),
      store.upsert(server('three', url: 'https://third.example.com/')),
    ]);

    expect(store.load().map((item) => item.id).toSet(), {
      'one',
      'two',
      'three',
    });
  });
}
