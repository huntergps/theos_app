import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../contracts.dart';

abstract interface class CredentialBackend {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// A [CredentialBackend] whose key is derived from a password it cannot
/// know at construction time — the composition root builds its backend at
/// bootstrap, before any operator has typed anything, so the password can
/// only ever be set later, right when a login call already has it in scope.
///
/// Implemented by [EncryptedFileCredentialBackend] (macOS) and
/// [LinuxSecretServiceFallbackCredentialBackend] (Linux, only used the
/// moment its fallback actually fires). A caller that has a `CredentialStore`
/// backed by one of these — and does not otherwise care which one — can set
/// the password through this one shared interface:
///
/// ```dart
/// final backend = credentialStore.backend;
/// if (backend is LatePasswordCredentialBackend) backend.password = typed;
/// ```
abstract interface class LatePasswordCredentialBackend
    implements CredentialBackend {
  set password(String? value);
}

abstract interface class InstallationIdBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// SharedPreferences-backed installation IDs. The preferences instance is
/// injected (or created asynchronously) so runtime composition owns lifetime
/// and tests can use the plugin's mock store without a mutable singleton.
final class SharedPreferencesInstallationIdBackend
    implements InstallationIdBackend {
  SharedPreferencesInstallationIdBackend(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesInstallationIdBackend> create() async {
    return SharedPreferencesInstallationIdBackend(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }
}

/// Persists one installation ID per app namespace without using a global
/// singleton. The generator is injected so tests never depend on a plugin.
final class InstallationIdStore {
  InstallationIdStore(this._backend, {this.generator = _defaultGenerator});

  final InstallationIdBackend _backend;
  final String Function() generator;

  Future<String> loadOrCreate(String appId) async {
    final id = _validate(await _backend.read(_installationKey(appId)));
    if (id != null) return id;
    final created = _validate(generator());
    if (created == null) {
      throw StateError('Installation ID generator returned empty value');
    }
    await _backend.write(_installationKey(appId), created);
    return created;
  }

  String _installationKey(String appId) {
    final value = appId.trim();
    if (value.isEmpty) throw ArgumentError.value(appId, 'appId');
    final encoded = base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    return 'orbi/installation/$encoded';
  }

  static String? _validate(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _defaultGenerator() => throw UnsupportedError(
    'Inject an installation ID generator from the platform composition root',
  );
}

final class FlutterSecureCredentialBackend implements CredentialBackend {
  // macOS: NO se pasa `MacOsOptions(usesDataProtectionKeychain: false)` a
  // propósito. Se probó exactamente esa opción (flutter_secure_storage
  // ^11.0.0, macos_options.dart línea 24) creyendo que el llavero clásico de
  // archivo evita la entitlement de grupo de acceso que el llavero protegido
  // exige. Verificado 2026-09-11 compilando y ejecutando theos_panel en
  // macOS, con logs del propio `secd` del sistema: el rechazo -34018 ocurre
  // IDÉNTICO con el flag en true o en false, y también con o sin
  // `com.apple.security.app-sandbox`. El mensaje exacto de secd es "Client
  // has neither com.apple.application-identifier nor
  // com.apple.security.application-groups nor keychain-access-groups
  // entitlements": en esta versión de macOS, secd exige esa entitlement para
  // CUALQUIER acceso a Keychain Services desde un binario firmado ad-hoc
  // (CODE_SIGN_IDENTITY = "-", sin DEVELOPMENT_TEAM), sea llavero protegido o
  // clásico, sandboxed o no. Apagar el flag sólo perdería la protección de
  // llavero de datos sin arreglar nada — ver
  // theos_panel/macos/Runner/DebugProfile.entitlements para el estado real.
  FlutterSecureCredentialBackend({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

enum CredentialDurability { secureStore, webSessionOnly }

/// Namespaced secret references. The secret itself never enters logs or keys.
final class CredentialStore {
  CredentialStore(this._backend, {required this.durability});

  final CredentialBackend _backend;
  final CredentialDurability durability;

  /// The backend underneath, exposed read-only so a caller can check for a
  /// capability like [LatePasswordCredentialBackend] without this class
  /// needing to know that capability exists.
  CredentialBackend get backend => _backend;

  Future<void> write(AppScope scope, String reference, String secret) =>
      _backend.write(_key(scope, reference), secret);

  Future<String?> read(AppScope scope, String reference) =>
      _backend.read(_key(scope, reference));

  Future<void> delete(AppScope scope, String reference) =>
      _backend.delete(_key(scope, reference));

  String _key(AppScope scope, String reference) {
    final ref = reference.trim();
    if (ref.isEmpty) throw ArgumentError.value(reference, 'reference');
    final scopePart = base64Url
        .encode(utf8.encode(scope.scopeKey))
        .replaceAll('=', '');
    final appPart = base64Url
        .encode(utf8.encode(scope.appId))
        .replaceAll('=', '');
    final referencePart = base64Url
        .encode(utf8.encode(ref))
        .replaceAll('=', '');
    return 'orbi/$appPart/$scopePart/$referencePart';
  }
}
