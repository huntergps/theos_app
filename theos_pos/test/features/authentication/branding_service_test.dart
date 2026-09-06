import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart' show Brightness, Color, Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/features/authentication/services/branding_cache_store.dart';
import 'package:theos_pos/features/authentication/services/branding_service.dart';

class _MemoryStore implements BrandingCacheStore {
  final bytes = <String, Uint8List>{};
  final text = <String, String>{};

  @override
  Future<Uint8List?> readBytes(String key) async => bytes[key];

  @override
  Future<String?> readText(String key) async => text[key];

  @override
  Future<void> writeBytes(String key, Uint8List value) async {
    bytes[key] = Uint8List.fromList(value);
  }

  @override
  Future<void> writeText(String key, String value) async => text[key] = value;
}

class _Fetcher implements BrandingAssetFetcher {
  _Fetcher(this.answer);

  final Future<Uint8List> Function(Uri uri, bool jpegOnly) answer;
  final calls = <Uri>[];

  @override
  Future<Uint8List> fetch(Uri uri, {bool jpegOnly = false}) {
    calls.add(uri);
    return answer(uri, jpegOnly);
  }
}

class _MockOdooClient extends Mock implements OdooClient {}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, {this.headers = const {}});

  final Uint8List body;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(body, 200, headers: headers);

  @override
  void close({bool force = false}) {}
}

final _jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
final _png = Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
]);

void main() {
  test(
    'uses exact public path once and then works from cache offline',
    () async {
      final store = _MemoryStore();
      final online = _Fetcher((_, jpegOnly) async {
        expect(jpegOnly, isTrue);
        return _jpeg;
      });
      final scope = BrandingScope(
        serverUrl: 'https://erp.example.com/web?ignored=yes',
        database: 'erp2',
      );

      final first = await BrandingService(
        store: store,
        assetFetcher: online,
      ).loadAndRefreshPublic(scope);
      expect(first.backgroundBytes, _jpeg);
      expect(
        online.calls.single.toString(),
        'https://erp.example.com/base_gpstech/static/src/img/login_bg.jpg',
      );

      final offline = _Fetcher((_, _) => throw StateError('offline'));
      final cached = await BrandingService(
        store: store,
        assetFetcher: offline,
      ).loadAndRefreshPublic(scope);
      expect(cached.backgroundBytes, _jpeg);
      expect(offline.calls, isEmpty);
    },
  );

  test('cache is isolated by server and database', () async {
    final store = _MemoryStore();
    var marker = 0xd0;
    final fetcher = _Fetcher(
      (_, _) async => Uint8List.fromList([0xff, 0xd8, 0xff, marker++]),
    );
    final service = BrandingService(store: store, assetFetcher: fetcher);

    final a = await service.loadAndRefreshPublic(
      BrandingScope(serverUrl: 'https://a.example', database: 'one'),
    );
    final b = await service.loadAndRefreshPublic(
      BrandingScope(serverUrl: 'https://a.example', database: 'two'),
    );
    final c = await service.loadAndRefreshPublic(
      BrandingScope(serverUrl: 'https://b.example', database: 'one'),
    );

    expect(
      {
        a.backgroundBytes!.last,
        b.backgroundBytes!.last,
        c.backgroundBytes!.last,
      }.length,
      3,
    );
  });

  test('network timeout keeps the solid-background fallback', () async {
    final fetcher = _Fetcher(
      (uri, _) => throw DioException(
        requestOptions: RequestOptions(path: uri.toString()),
        type: DioExceptionType.connectionTimeout,
      ),
    );
    final result =
        await BrandingService(
          store: _MemoryStore(),
          assetFetcher: fetcher,
        ).loadAndRefreshPublic(
          BrandingScope(serverUrl: 'https://erp.example', database: 'erp2'),
        );
    expect(result.backgroundBytes, isNull);
  });

  test('Dio fetcher rejects invalid format and oversized response', () async {
    final invalidDio = Dio()..httpClientAdapter = _Adapter(Uint8List(12));
    await expectLater(
      DioBrandingAssetFetcher(dio: invalidDio)
          .fetch(Uri.parse('https://erp.example/login_bg.jpg'), jpegOnly: true),
      throwsFormatException,
    );

    final oversizedDio = Dio()
      ..httpClientAdapter = _Adapter(
        _jpeg,
        headers: {
          Headers.contentLengthHeader: ['6000000'],
          Headers.contentTypeHeader: ['image/jpeg'],
        },
      );
    await expectLater(
      DioBrandingAssetFetcher(dio: oversizedDio)
          .fetch(Uri.parse('https://erp.example/login_bg.jpg'), jpegOnly: true),
      throwsFormatException,
    );
  });

  test(
    'authenticated contract caches exact company branding by company',
    () async {
      final client = _MockOdooClient();
      var responseCompanyId = 7;
      var failAssets = false;
      when(
        () => client.call(
          model: 'res.company',
          method: 'pos_app_branding',
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer(
        (_) async => {
          'version': 1,
          'company_id': responseCompanyId,
          'theme': {
            'brand_color': '#224466',
            'action_color': '#0067c0',
            'dark_tint': 55,
            'base_font_size': 30,
            'border_radius': 99,
          },
          'login': {
            'title': 'Compañía Norte',
            'logo': {'url': '/web/image/company-logo', 'sha256': false},
            'background': {
              'light': {'url': '/web/image/light', 'sha256': false},
              'dark': {'url': 'https://other.example/dark', 'sha256': false},
            },
          },
        },
      );
      final fetcher = _Fetcher((uri, _) async {
        if (failAssets) throw StateError('offline');
        return uri.path.contains('company-logo') ? _png : _jpeg;
      });
      final store = _MemoryStore();
      final service = BrandingService(store: store, assetFetcher: fetcher);
      final scope = BrandingScope(
        serverUrl: 'https://erp.example',
        database: 'erp2',
      );

      final branding = await service.fetchAndSaveAuthenticated(
        scope: scope,
        client: client,
        companyId: 7,
      );
      expect(branding.title, 'Compañía Norte');
      expect(branding.logoBytes, _png);
      expect(branding.backgroundBytes, _jpeg);
      expect(branding.darkBackgroundBytes, _jpeg);
      expect(branding.theme.textScale, closeTo(1.15, .001));
      expect(branding.theme.cornerRadius, 12);
      expect(fetcher.calls.every((uri) => uri.host == 'erp.example'), isTrue);
      expect((await service.load(scope)).companyId, 7);

      responseCompanyId = 8;
      failAssets = true;
      final secondCompany = await service.fetchAndSaveAuthenticated(
        scope: scope,
        client: client,
        companyId: 8,
      );
      expect(secondCompany.logoBytes, isNull);
      expect(secondCompany.backgroundBytes, isNull);
      expect((await service.load(scope)).companyId, 8);
      expect(
        store.bytes.keys.any((key) => key.contains('_company_7_')),
        isTrue,
      );
      expect(
        store.bytes.keys.any((key) => key.contains('_company_8_')),
        isFalse,
      );
      final persistedMetadata = store.text.values.join('\n');
      expect(persistedMetadata, isNot(contains('api_key')));
      expect(persistedMetadata, isNot(contains('password')));
      verify(
        () => client.call(
          model: 'res.company',
          method: 'pos_app_branding',
          ids: any(named: 'ids'),
          kwargs: const {'known_checksums': <String, dynamic>{}},
        ),
      ).called(2);
    },
  );

  test('theme parser ignores malformed colors and clamps sizes', () {
    final tokens = BrandingThemeTokens.fromJson({
      'action_color': 'javascript:red',
      'brand_color': '#123456',
      'base_font_size': 2,
      'border_radius': -4,
    });
    expect(tokens.accentColor, isNull);
    expect(tokens.brandColor?.toARGB32(), 0xff123456);
    expect(tokens.textScale, .9);
    expect(tokens.cornerRadius, isNull);

    final inaccessible = BrandingThemeTokens.fromJson({
      'action_color': '#ffffff',
    });
    expect(inaccessible.accentColor, isNull);

    final sentinels = BrandingThemeTokens.fromJson({
      'base_font_size': 0,
      'border_radius': -1,
      'dark_tint': 140,
      'control_scale': 9,
    });
    expect(sentinels.textScale, 1);
    expect(sentinels.cornerRadius, isNull);
    expect(sentinels.darkTintPercent, 100);

    final darkTheme = BrandingThemeTokens.fromJson({
      'brand_color': '#336699',
      'action_color': '#0067c0',
      'dark_tint': 12,
    });
    expect(
      darkTheme.darkSurfaceColor?.toARGB32(),
      Color.lerp(
        const Color(0xff1c1c20),
        const Color(0xff336699),
        .12,
      )!.toARGB32(),
    );
    expect(darkTheme.fluentAccentColor, Colors.blue);

    final erp2Theme = BrandingThemeTokens.fromJson({'action_color': '#9c4413'});
    expect(erp2Theme.fluentAccentColor, Colors.orange);
  });

  test(
    'sends record ids and checksums, skips same URL and rejects wrong hash',
    () async {
      final client = _MockOdooClient();
      final checksum = sha256.convert(_png).toString();
      final wrongChecksum = List.filled(64, '0').join();
      var invocation = 0;
      when(
        () => client.call(
          model: 'res.company',
          method: 'pos_app_branding',
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer((_) async {
        invocation++;
        return {
          'company_id': 7,
          'theme': <String, dynamic>{},
          'login': {
            'logo': invocation == 1
                ? {'url': '/web/image/logo', 'sha256': checksum}
                : invocation == 2
                ? {'url': '/web/image/logo', 'sha256': false}
                : {'url': '/web/image/logo-new', 'sha256': wrongChecksum},
            'background': <String, dynamic>{},
          },
        };
      });
      final fetcher = _Fetcher((_, _) async => invocation == 3 ? _jpeg : _png);
      final service = BrandingService(
        store: _MemoryStore(),
        assetFetcher: fetcher,
      );
      final scope = BrandingScope(
        serverUrl: 'https://erp.example',
        database: 'erp2',
      );

      for (var attempt = 0; attempt < 3; attempt++) {
        final branding = await service.fetchAndSaveAuthenticated(
          scope: scope,
          client: client,
          companyId: 7,
        );
        expect(branding.logoBytes, _png);
        expect(fetcher.calls, hasLength(attempt == 0 ? 1 : attempt));
      }

      final calls = verify(
        () => client.call(
          model: 'res.company',
          method: 'pos_app_branding',
          ids: captureAny(named: 'ids'),
          kwargs: captureAny(named: 'kwargs'),
        ),
      ).captured;
      expect(calls[0], [7]);
      expect(calls[2], [7]);
      expect(calls[3], {
        'known_checksums': {'7:gpst_login_logo': checksum},
      });
    },
  );
}
