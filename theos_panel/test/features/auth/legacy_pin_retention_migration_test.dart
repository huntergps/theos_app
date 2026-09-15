// Migración de una sola vez (decisión del dueño, 14-sep-2026): quien
// enroló su PIN ANTES de que existiera la retención por PIN nunca tiene la
// bandera de `NativeAuthService.retainCredentialForPin` puesta, y sin esta
// migración desaparecería para siempre del selector de `PinLoginScreen` —
// ver `legacy_pin_retention_migration.dart`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/legacy_pin_retention_migration.dart';
import 'package:theos_panel/features/auth/pin_credential_store.dart';

const _serverUrl = 'https://erp.test';
const _database = 'demo';

const _profileWithKey = AuthProfile(
  serverUrl: _serverUrl,
  database: _database,
  login: 'legacy-with-key',
  userId: 11,
  installationId: 'device-1',
  credentialReference: 'api-key',
);

const _profileWithoutKey = AuthProfile(
  serverUrl: _serverUrl,
  database: _database,
  login: 'legacy-without-key',
  userId: 12,
  installationId: 'device-1',
  credentialReference: 'api-key',
);

/// Sólo lo que la migración necesita: reporta perfiles con llave TODAVÍA
/// físicamente en el almacén (`profilesWithStoredKeyFor` — el "método de
/// lectura del servicio" que `legacy_pin_retention_migration.dart` usa) y
/// registra cada llamada a `retainCredentialForPin` para que la prueba
/// compruebe a quién se marcó de verdad.
final class _FakeMigrationAuthService
    implements AuthServicePort, SellerPinAuthServicePort {
  _FakeMigrationAuthService(this._profilesWithKey);
  final List<AuthProfile> _profilesWithKey;
  final retainedCalls = <AuthProfile>[];

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthProfile?> loadProfile() async => null;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;

  @override
  Future<void> close() async {}

  @override
  Future<AuthServiceResult> loginWithPinCredential(
    AuthProfile profile, {
    bool offline = false,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<void> retainCredentialForPin(
    AuthProfile profile,
    bool retained,
  ) async {
    if (retained) retainedCalls.add(profile);
  }

  @override
  Future<List<AuthProfile>> pinRetainedProfilesFor(
    String serverUrl,
    String database,
  ) async => const [];

  @override
  Future<List<AuthProfile>> profilesWithStoredKeyFor(
    String serverUrl,
    String database,
  ) async =>
      serverUrl == _serverUrl && database == _database
      ? _profilesWithKey
      : const [];
}

void main() {
  test('legacy enrolled pin with stored key is migrated to retained', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final pinStore = PinCredentialStore(preferences);
    final scopeKey = pinScopeKeyFor(
      _profileWithKey.serverUrl,
      _profileWithKey.database,
      _profileWithKey.login,
    );
    await pinStore.enroll(scopeKey, '1234');

    final fake = _FakeMigrationAuthService([_profileWithKey]);
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authControllerProvider.notifier);

    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrl,
      database: _database,
    );

    expect(fake.retainedCalls, [_profileWithKey]);
  });

  test('legacy pin without key is not migrated', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final pinStore = PinCredentialStore(preferences);
    // El PIN SÍ está enrolado, pero `profilesWithStoredKeyFor` (el fake, tal
    // como haría el real `NativeAuthService` para una cuenta sin llave en el
    // almacén) nunca reporta a `_profileWithoutKey` — así que no hay nada
    // que retener todavía.
    final scopeKey = pinScopeKeyFor(
      _profileWithoutKey.serverUrl,
      _profileWithoutKey.database,
      _profileWithoutKey.login,
    );
    await pinStore.enroll(scopeKey, '5678');

    final fake = _FakeMigrationAuthService(const []);
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authControllerProvider.notifier);

    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrl,
      database: _database,
    );

    expect(fake.retainedCalls, isEmpty);
  });

  test('migration runs only once per installation', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final pinStore = PinCredentialStore(preferences);
    final scopeKey = pinScopeKeyFor(
      _profileWithKey.serverUrl,
      _profileWithKey.database,
      _profileWithKey.login,
    );
    await pinStore.enroll(scopeKey, '1234');
    final fake = _FakeMigrationAuthService([_profileWithKey]);
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authControllerProvider.notifier);

    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrl,
      database: _database,
    );
    expect(fake.retainedCalls.length, 1);

    // Segunda vez: el fake seguiría reportando el mismo perfil, pero la
    // bandera de "ya corrió" evita repetir la llamada.
    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrl,
      database: _database,
    );
    expect(fake.retainedCalls.length, 1);
  });
}
