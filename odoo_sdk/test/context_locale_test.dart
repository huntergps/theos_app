/// Contract (fix/sdk/user-lang-tz): Odoo works in the operator's own
/// language and timezone (`res.users.lang` / `res.users.tz`), never a fixed
/// `en_US`/UTC. `OdooCrudApi._defaultContext` must therefore carry `lang`
/// from `OdooClientConfig.defaultLanguage` (already true) AND `tz` from a
/// new `OdooClientConfig.defaultTimezone` — but ONLY when it is actually
/// configured, since Odoo's `with_context` REPLACES the whole context, so a
/// missing `tz` here means the request has none at all, not a fallback.
@Tags(['unit'])
library;

import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

/// Records the exact body sent to `postJson2`, without any real HTTP.
class _CapturingHttpClient implements OdooHttpClient {
  _CapturingHttpClient(this._config);

  OdooClientConfig _config;
  Map<String, dynamic>? lastBody;

  @override
  OdooClientConfig get config => _config;

  /// Mirrors `OdooHttpClient.updateConfig`, used by `OdooClient.updateLocale`
  /// so tests can exercise that path without a real Dio instance.
  @override
  void updateConfig(OdooClientConfig config) => _config = config;

  @override
  Future<Response<dynamic>> postJson2(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    lastBody = data;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: <String, dynamic>{},
      statusCode: 200,
    );
  }

  @override
  bool get isConfigured => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('OdooClientConfig.defaultTimezone', () {
    test('defaults to null and copyWith preserves/overrides it', () {
      const config = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'test-key',
      );
      expect(config.defaultTimezone, isNull);

      final withTz = config.copyWith(defaultTimezone: 'America/Guayaquil');
      expect(withTz.defaultTimezone, 'America/Guayaquil');
      // copyWith with no argument must not clear an already-set value.
      expect(withTz.copyWith(apiKey: 'other-key').defaultTimezone,
          'America/Guayaquil');
    });
  });

  group('OdooCrudApi default context (lang/tz)', () {
    test('includes lang and tz when both are configured', () async {
      final httpClient = _CapturingHttpClient(
        const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
          defaultLanguage: 'es_EC',
          defaultTimezone: 'America/Guayaquil',
        ),
      );
      final crudApi = OdooCrudApi(httpClient: httpClient);

      await crudApi.call(model: 'res.partner', method: 'search_read');

      final context = httpClient.lastBody!['context'] as Map;
      expect(context['lang'], 'es_EC');
      expect(context['tz'], 'America/Guayaquil');
    });

    test('omits tz entirely when defaultTimezone is not configured', () async {
      final httpClient = _CapturingHttpClient(
        const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
          defaultLanguage: 'es_EC',
        ),
      );
      final crudApi = OdooCrudApi(httpClient: httpClient);

      await crudApi.call(model: 'res.partner', method: 'search_read');

      final context = httpClient.lastBody!['context'] as Map;
      expect(context['lang'], 'es_EC');
      expect(context.containsKey('tz'), isFalse);
    });

    test('a call-level context overrides the default lang and tz', () async {
      final httpClient = _CapturingHttpClient(
        const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
          defaultLanguage: 'es_EC',
          defaultTimezone: 'America/Guayaquil',
        ),
      );
      final crudApi = OdooCrudApi(httpClient: httpClient);

      await crudApi.call(
        model: 'res.partner',
        method: 'search_read',
        context: {'lang': 'en_US', 'tz': 'UTC'},
      );

      final context = httpClient.lastBody!['context'] as Map;
      expect(context['lang'], 'en_US');
      expect(context['tz'], 'UTC');
    });
  });

  group('OdooClient.updateLocale', () {
    test(
      'applies language and timezone, preserving everything else in the '
      'configuration (base URL, api key, database...)',
      () {
        final client = OdooClient(
          config: const OdooClientConfig(
            baseUrl: 'https://odoo.example.com',
            apiKey: 'test-key',
            database: 'test-db',
          ),
        );

        client.updateLocale(language: 'es_EC', timezone: 'America/Guayaquil');

        expect(client.config.defaultLanguage, 'es_EC');
        expect(client.config.defaultTimezone, 'America/Guayaquil');
        expect(client.config.baseUrl, 'https://odoo.example.com');
        expect(client.config.apiKey, 'test-key');
        expect(client.config.database, 'test-db');
      },
    );

    test('a null/empty argument never clears an already-configured value', () {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
          defaultLanguage: 'es_EC',
          defaultTimezone: 'America/Guayaquil',
        ),
      );

      client.updateLocale();

      expect(client.config.defaultLanguage, 'es_EC');
      expect(client.config.defaultTimezone, 'America/Guayaquil');
    });
  });
}
