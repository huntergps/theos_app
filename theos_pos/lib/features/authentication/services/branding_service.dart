import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OdooClient;

import '../../../core/constants/app_colors.dart';
import 'branding_cache_store.dart';

const _loginBackgroundPath = '/base_gpstech/static/src/img/login_bg.jpg';
const _maxBrandingAssetBytes = 5 * 1024 * 1024;

final class BrandingScope {
  BrandingScope({required String serverUrl, required String database})
    : serverUri = _normalizeServer(serverUrl),
      database = database.trim();

  final Uri serverUri;
  final String database;

  String get identity => '${serverUri.toString()}\u0000$database';

  Uri get publicLoginBackground => Uri(
    scheme: serverUri.scheme,
    host: serverUri.host,
    port: serverUri.hasPort ? serverUri.port : null,
    path: _loginBackgroundPath,
  );

  static Uri _normalizeServer(String value) {
    final uri = Uri.parse(value.trim());
    if (!uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('Servidor de branding no válido');
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path.replaceAll(RegExp(r'/+$'), ''),
    );
  }
}

final class BrandingThemeTokens {
  const BrandingThemeTokens({
    this.accentColor,
    this.brandColor,
    this.darkTintPercent = 0,
    this.textScale = 1,
    this.cornerRadius,
  });

  final Color? accentColor;
  final Color? brandColor;
  final double darkTintPercent;
  final double textScale;
  final double? cornerRadius;

  /// Traduce el color libre de Odoo a la familia Fluent más cercana.
  ///
  /// Se compara contra todas las variantes de cada familia para que colores
  /// corporativos oscuros (por ejemplo un naranja quemado) conserven su matiz
  /// sin perder los estados hover/pressed que Fluent necesita.
  AccentColor? get fluentAccentColor {
    final target = accentColor;
    if (target == null) return null;

    AccentColor? closest;
    var closestDistance = 1 << 62;
    for (final candidate in AppColors.fluentAccentColors) {
      for (final shade in candidate.swatch.values) {
        final distance = _colorDistance(target, shade);
        if (distance < closestDistance) {
          closestDistance = distance;
          closest = candidate;
        }
      }
    }
    return closest;
  }

  Color? get darkSurfaceColor {
    final color = brandColor;
    if (color == null) return null;
    final mixed = Color.lerp(
      const Color(0xff1c1c20),
      color,
      darkTintPercent / 100,
    )!;
    return _ensureDarkContrast(mixed);
  }

  factory BrandingThemeTokens.fromJson(Map<String, dynamic> json) {
    final actionColor = _parseColor(json['action_color']);
    return BrandingThemeTokens(
      accentColor: actionColor != null && _contrastWithWhite(actionColor) >= 3
          ? actionColor
          : null,
      brandColor: _parseColor(json['brand_color']),
      darkTintPercent: _percentage(json['dark_tint']),
      textScale: _baseFontScale(json['base_font_size']),
      cornerRadius: _optionalRadius(json['border_radius']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (accentColor case final color?)
      'action_color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
    if (brandColor case final color?)
      'brand_color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
    'dark_tint': darkTintPercent,
    'base_font_size': 14 * textScale,
    'border_radius': ?cornerRadius,
  };

  static Color? _parseColor(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(normalized)) {
      return null;
    }
    final parsed = int.parse(normalized, radix: 16);
    return Color(normalized.length == 6 ? 0xff000000 | parsed : parsed);
  }

  static double _contrastWithWhite(Color color) =>
      1.05 / (color.computeLuminance() + .05);

  static int _colorDistance(Color first, Color second) {
    final red = (first.r * 255).round() - (second.r * 255).round();
    final green = (first.g * 255).round() - (second.g * 255).round();
    final blue = (first.b * 255).round() - (second.b * 255).round();
    return red * red + green * green + blue * blue;
  }

  static Color _ensureDarkContrast(Color color) {
    var safe = color;
    for (var step = 0; step < 16 && safe.computeLuminance() > .18; step++) {
      safe = Color.lerp(safe, const Color(0xff000000), .12)!;
    }
    return safe;
  }

  static double _baseFontScale(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || !parsed.isFinite || parsed <= 0) return 1;
    return parsed.clamp(12.6, 16.1) / 14;
  }

  static double? _optionalRadius(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed.clamp(0, 12);
  }

  static double _percentage(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || !parsed.isFinite) return 0;
    return parsed.clamp(0, 100);
  }
}

final class AppBranding {
  const AppBranding({
    this.backgroundBytes,
    this.darkBackgroundBytes,
    this.logoBytes,
    this.theme = const BrandingThemeTokens(),
    this.companyId,
    this.title,
  });

  final Uint8List? backgroundBytes;
  final Uint8List? darkBackgroundBytes;
  final Uint8List? logoBytes;
  final BrandingThemeTokens theme;
  final int? companyId;
  final String? title;

  AppBranding copyWith({
    Uint8List? backgroundBytes,
    Uint8List? darkBackgroundBytes,
    Uint8List? logoBytes,
    BrandingThemeTokens? theme,
    int? companyId,
    String? title,
  }) => AppBranding(
    backgroundBytes: backgroundBytes ?? this.backgroundBytes,
    darkBackgroundBytes: darkBackgroundBytes ?? this.darkBackgroundBytes,
    logoBytes: logoBytes ?? this.logoBytes,
    theme: theme ?? this.theme,
    companyId: companyId ?? this.companyId,
    title: title ?? this.title,
  );
}

final class _ResolvedAsset {
  const _ResolvedAsset(this.bytes, this.metadata);

  final Uint8List? bytes;
  final Map<String, dynamic>? metadata;
}

abstract interface class BrandingAssetFetcher {
  Future<Uint8List> fetch(Uri uri, {bool jpegOnly = false});
}

final class DioBrandingAssetFetcher implements BrandingAssetFetcher {
  DioBrandingAssetFetcher({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<Uint8List> fetch(Uri uri, {bool jpegOnly = false}) async {
    final response = await _dio.get<List<int>>(
      uri.toString(),
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
        receiveDataWhenStatusError: false,
        sendTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (status) => status == 200,
      ),
    );
    final contentLength = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    if (contentLength != null && contentLength > _maxBrandingAssetBytes) {
      throw const FormatException('Imagen de branding demasiado grande');
    }
    final data = Uint8List.fromList(response.data ?? const <int>[]);
    if (data.length > _maxBrandingAssetBytes ||
        (jpegOnly ? !_isJpeg(data) : !_isRasterImage(data))) {
      throw const FormatException('Imagen de branding no válida');
    }
    final contentType = response.headers.value(Headers.contentTypeHeader);
    if (contentType != null &&
        !(jpegOnly
            ? contentType.toLowerCase().startsWith('image/jpeg')
            : contentType.toLowerCase().startsWith('image/'))) {
      throw const FormatException('Formato de branding no permitido');
    }
    return data;
  }
}

final class BrandingService {
  BrandingService({required this.store, required this.assetFetcher});

  final BrandingCacheStore store;
  final BrandingAssetFetcher assetFetcher;

  Future<AppBranding> loadAndRefreshPublic(BrandingScope scope) async {
    final cached = await load(scope);
    if (cached.backgroundBytes != null) return cached;
    try {
      final bytes = await assetFetcher.fetch(
        scope.publicLoginBackground,
        jpegOnly: true,
      );
      await store.writeBytes('${_scopeKey(scope)}_background.jpg', bytes);
      return cached.copyWith(backgroundBytes: bytes);
    } catch (_) {
      return cached;
    }
  }

  Future<AppBranding> load(BrandingScope scope) async {
    final key = _scopeKey(scope);
    final background = await store.readBytes('${key}_background.jpg');
    final metadataText = await store.readText('${key}_metadata.json');
    if (metadataText == null) return AppBranding(backgroundBytes: background);
    try {
      final metadata = jsonDecode(metadataText) as Map<String, dynamic>;
      if (metadata['identity'] != scope.identity) {
        return AppBranding(backgroundBytes: background);
      }
      final companyId = metadata['last_company_id'] as int?;
      final companyKey = companyId == null ? null : '${key}_company_$companyId';
      final companyText = companyKey == null
          ? null
          : await store.readText('${companyKey}_branding.json');
      final company = companyText == null
          ? const <String, dynamic>{}
          : jsonDecode(companyText) as Map<String, dynamic>;
      final companyLight = companyKey == null
          ? null
          : await store.readBytes('${companyKey}_background_light.bin');
      return AppBranding(
        backgroundBytes: companyLight ?? background,
        darkBackgroundBytes: companyKey == null
            ? null
            : await store.readBytes('${companyKey}_background_dark.bin'),
        logoBytes: companyKey == null
            ? null
            : await store.readBytes('${companyKey}_logo.bin'),
        theme: BrandingThemeTokens.fromJson(
          (metadata['theme'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        companyId: companyId,
        title: company['title'] as String?,
      );
    } catch (_) {
      return AppBranding(backgroundBytes: background);
    }
  }

  Future<AppBranding> fetchAndSaveAuthenticated({
    required BrandingScope scope,
    required OdooClient client,
    required int companyId,
  }) async {
    final key = _scopeKey(scope);
    final companyKey = '${key}_company_$companyId';
    final publicBackground = await store.readBytes('${key}_background.jpg');
    final companyMetadataText = await store.readText(
      '${companyKey}_branding.json',
    );
    final existingCompanyMetadata = _decodeMap(companyMetadataText);
    final existingAssets =
        (existingCompanyMetadata['assets'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final existingLogo = await store.readBytes('${companyKey}_logo.bin');
    final existingLight = await store.readBytes(
      '${companyKey}_background_light.bin',
    );
    final existingDark = await store.readBytes(
      '${companyKey}_background_dark.bin',
    );
    final knownChecksums = <String, dynamic>{};
    final logoChecksum = _assetChecksum(existingAssets['logo']);
    final backgroundChecksum =
        _assetChecksum(existingAssets['background_light']) ??
        _assetChecksum(existingAssets['background_dark']);
    if (logoChecksum != null && existingLogo != null) {
      knownChecksums['$companyId:gpst_login_logo'] = logoChecksum;
    }
    if (backgroundChecksum != null &&
        (existingLight != null || existingDark != null)) {
      knownChecksums['$companyId:gpst_login_background'] = backgroundChecksum;
    }
    final response = await client.call(
      model: 'res.company',
      method: 'pos_app_branding',
      ids: [companyId],
      kwargs: {'known_checksums': knownChecksums},
    );
    if (response is! Map) {
      throw const FormatException('Respuesta de branding no válida');
    }
    final payload = response.cast<String, dynamic>();
    if (payload['company_id'] != companyId) {
      throw const FormatException('Branding de otra compañía');
    }
    final globalTheme =
        (payload['theme'] as Map?)?.cast<String, dynamic>() ?? const {};
    final companyBranding =
        (payload['login'] as Map?)?.cast<String, dynamic>() ?? const {};
    final logo = await _resolveRemoteAsset(
      scope,
      companyBranding['logo'],
      existingBytes: existingLogo,
      existingMetadata: existingAssets['logo'],
    );
    final backgrounds =
        (companyBranding['background'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final lightBackground = await _resolveRemoteAsset(
      scope,
      backgrounds['light'],
      existingBytes: existingLight ?? publicBackground,
      existingMetadata: existingAssets['background_light'],
    );
    final darkBackground = await _resolveRemoteAsset(
      scope,
      backgrounds['dark'],
      existingBytes: existingDark ?? lightBackground.bytes ?? publicBackground,
      existingMetadata: existingAssets['background_dark'],
    );
    final rawTitle = companyBranding['title'];
    final normalizedTitle = rawTitle is String ? rawTitle.trim() : '';
    final title = normalizedTitle.isEmpty
        ? null
        : normalizedTitle.substring(0, normalizedTitle.length.clamp(0, 80));
    final metadata = <String, dynamic>{
      'identity': scope.identity,
      'last_company_id': companyId,
      'theme': globalTheme,
    };
    await store.writeText('${key}_metadata.json', jsonEncode(metadata));
    await store.writeText(
      '${companyKey}_branding.json',
      jsonEncode({
        'title': title,
        'assets': {
          if (logo.metadata != null) 'logo': logo.metadata,
          if (lightBackground.metadata != null)
            'background_light': lightBackground.metadata,
          if (darkBackground.metadata != null)
            'background_dark': darkBackground.metadata,
        },
      }),
    );
    if (logo.bytes != null) {
      await store.writeBytes('${companyKey}_logo.bin', logo.bytes!);
    }
    if (lightBackground.bytes != null) {
      await store.writeBytes(
        '${companyKey}_background_light.bin',
        lightBackground.bytes!,
      );
    }
    if (darkBackground.bytes != null) {
      await store.writeBytes(
        '${companyKey}_background_dark.bin',
        darkBackground.bytes!,
      );
    }
    return AppBranding(
      backgroundBytes: lightBackground.bytes,
      darkBackgroundBytes: darkBackground.bytes,
      logoBytes: logo.bytes,
      theme: BrandingThemeTokens.fromJson(globalTheme),
      companyId: companyId,
      title: title,
    );
  }

  Future<_ResolvedAsset> _resolveRemoteAsset(
    BrandingScope scope,
    Object? descriptor, {
    required Uint8List? existingBytes,
    required Object? existingMetadata,
  }) async {
    final oldMetadata = existingMetadata is Map
        ? existingMetadata.cast<String, dynamic>()
        : null;
    if (descriptor is! Map) {
      return _ResolvedAsset(existingBytes, oldMetadata);
    }
    final asset = descriptor.cast<Object?, Object?>();
    if (asset['unchanged'] == true) {
      return _ResolvedAsset(existingBytes, oldMetadata);
    }
    final url = asset['url'];
    if (url is! String || url.trim().isEmpty) {
      return _ResolvedAsset(existingBytes, oldMetadata);
    }
    final normalizedUrl = url.trim();
    final expectedChecksum = asset['sha256'];
    if (existingBytes != null &&
        (expectedChecksum == false || expectedChecksum == null) &&
        oldMetadata?['url'] == normalizedUrl) {
      return _ResolvedAsset(existingBytes, oldMetadata);
    }
    try {
      final uri = scope.serverUri.resolve(normalizedUrl);
      if (uri.scheme != scope.serverUri.scheme ||
          uri.host != scope.serverUri.host ||
          uri.port != scope.serverUri.port) {
        return _ResolvedAsset(existingBytes, oldMetadata);
      }
      final downloaded = await assetFetcher.fetch(uri);
      if (expectedChecksum is String &&
          expectedChecksum.isNotEmpty &&
          sha256.convert(downloaded).toString().toLowerCase() !=
              expectedChecksum.toLowerCase()) {
        return _ResolvedAsset(existingBytes, oldMetadata);
      }
      return _ResolvedAsset(downloaded, {
        'url': normalizedUrl,
        if (expectedChecksum is String && expectedChecksum.isNotEmpty)
          'sha256': expectedChecksum.toLowerCase(),
      });
    } catch (_) {
      return _ResolvedAsset(existingBytes, oldMetadata);
    }
  }

  static Map<String, dynamic> _decodeMap(String? value) {
    if (value == null) return const {};
    try {
      return (jsonDecode(value) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  static String? _assetChecksum(Object? value) {
    if (value is! Map) return null;
    final checksum = value['sha256'];
    return checksum is String && checksum.isNotEmpty ? checksum : null;
  }

  static String _scopeKey(BrandingScope scope) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(scope.identity)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

bool _isJpeg(Uint8List bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0xff &&
    bytes[1] == 0xd8 &&
    bytes[2] == 0xff;

bool _isRasterImage(Uint8List bytes) {
  final png =
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a;
  final webp =
      bytes.length >= 12 &&
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
  return _isJpeg(bytes) || png || webp;
}

final brandingCacheStoreProvider = Provider<BrandingCacheStore>(
  (ref) => createPlatformBrandingCacheStore(),
);

final brandingAssetFetcherProvider = Provider<BrandingAssetFetcher>(
  (ref) => DioBrandingAssetFetcher(),
);

final brandingServiceProvider = Provider<BrandingService>(
  (ref) => BrandingService(
    store: ref.watch(brandingCacheStoreProvider),
    assetFetcher: ref.watch(brandingAssetFetcherProvider),
  ),
);

final appBrandingProvider = NotifierProvider<BrandingController, AppBranding>(
  BrandingController.new,
);

final class BrandingController extends Notifier<AppBranding> {
  BrandingScope? _scope;
  int _selection = 0;

  @override
  AppBranding build() => const AppBranding();

  Future<void> selectServer({
    required String serverUrl,
    required String database,
  }) async {
    final selection = ++_selection;
    final previousScope = _scope;
    final previousBranding = state;
    try {
      final scope = BrandingScope(serverUrl: serverUrl, database: database);
      final isSameScope = previousScope?.identity == scope.identity;
      _scope = scope;
      // Keep the last valid image visible while the same server refreshes.
      // Clearing it here produced a flat panel whenever a refresh was slow.
      if (!isSameScope) state = const AppBranding();
      final loaded = await ref
          .read(brandingServiceProvider)
          .loadAndRefreshPublic(scope);
      if (selection == _selection && _scope?.identity == scope.identity) {
        state = loaded;
      }
    } catch (_) {
      if (selection == _selection) {
        state = previousScope?.identity == _scope?.identity
            ? previousBranding
            : const AppBranding();
      }
    }
  }

  Future<void> applyAuthenticated({
    required OdooClient client,
    required int companyId,
  }) async {
    final scope = _scope;
    if (scope == null) return;
    try {
      final loaded = await ref
          .read(brandingServiceProvider)
          .fetchAndSaveAuthenticated(
            scope: scope,
            client: client,
            companyId: companyId,
          );
      if (_scope?.identity == scope.identity) state = loaded;
    } catch (_) {
      // Branding is cosmetic and must never block an authenticated session.
    }
  }
}
