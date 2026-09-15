// Migración de una sola vez (decisión del dueño, 14-sep-2026): quien
// enroló su PIN ANTES de que existiera la retención por PIN nunca tiene la
// bandera de `NativeAuthService.retainCredentialForPin` puesta, y sin esta
// migración desaparecería para siempre del selector de `PinLoginScreen` —
// ver `legacy_pin_retention_migration.dart`.
//
// 🔴 Corregido el 14-sep-2026 (revisión del coordinador sobre 52dcb1a): la
// marca de "ya corrió" es por servidor+base, nunca una sola global — un
// dispositivo con PINs en dos servidores (ERP2 y Mepriga) debe migrar los
// dos. Y sólo se pone si la migración terminó sin excepción, para que un
// fallo transitorio se reintente la próxima vez.
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

// --- Un segundo servidor+base en el MISMO dispositivo (ERP2 vs. Mepriga),
// para la prueba que exige migrar los dos, no sólo el primero que se abre.
const _serverUrlB = 'https://mepriga.test';
const _databaseB = 'mepriga';

const _profileServerB = AuthProfile(
  serverUrl: _serverUrlB,
  database: _databaseB,
  login: 'legacy-server-b',
  userId: 31,
  installationId: 'device-1',
  credentialReference: 'api-key',
);

/// Sólo lo que la migración necesita: reporta perfiles con llave TODAVÍA
/// físicamente en el almacén (`profilesWithStoredKeyFor` — el "método de
/// lectura del servicio" que `legacy_pin_retention_migration.dart` usa),
/// simula opcionalmente un fallo transitorio en la PRIMERA lectura de un
/// servidor+base dado, y registra cada llamada a `retainCredentialForPin`
/// para que la prueba compruebe a quién se marcó de verdad.
final class _FakeMigrationAuthService
    implements AuthServicePort, SellerPinAuthServicePort {
  _FakeMigrationAuthService(
    Map<String, List<AuthProfile>> profilesByScope, {
    Set<String>? failFirstReadForScope,
  }) : _profilesByScope = profilesByScope,
       _failFirstReadForScope = {...?failFirstReadForScope};

  /// Clave: `'$serverUrl|$database'`.
  final Map<String, List<AuthProfile>> _profilesByScope;

  /// Claves de servidor+base cuya PRIMERA llamada a
  /// [profilesWithStoredKeyFor] debe lanzar — se quita del set nada más
  /// lanzar una vez, así que un segundo intento para el mismo servidor+base
  /// tiene éxito.
  final Set<String> _failFirstReadForScope;

  final retainedCalls = <AuthProfile>[];

  static String scopeKeyFor(String serverUrl, String database) =>
      '$serverUrl|$database';

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
  ) async {
    final key = scopeKeyFor(serverUrl, database);
    if (_failFirstReadForScope.remove(key)) {
      throw StateError('almacén no disponible (transitorio)');
    }
    return _profilesByScope[key] ?? const [];
  }
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

    final fake = _FakeMigrationAuthService({
      _FakeMigrationAuthService.scopeKeyFor(_serverUrl, _database): [
        _profileWithKey,
      ],
    });
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

    final fake = _FakeMigrationAuthService(const {});
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
    final fake = _FakeMigrationAuthService({
      _FakeMigrationAuthService.scopeKeyFor(_serverUrl, _database): [
        _profileWithKey,
      ],
    });
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

  // --- Defecto corregido sobre 52dcb1a: una marca global impedía migrar un
  // SEGUNDO servidor+base en el mismo dispositivo. -------------------------
  test('legacy pin migration runs once per server and database', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final pinStore = PinCredentialStore(preferences);

    final scopeKeyA = pinScopeKeyFor(
      _profileWithKey.serverUrl,
      _profileWithKey.database,
      _profileWithKey.login,
    );
    await pinStore.enroll(scopeKeyA, '1234');
    final scopeKeyB = pinScopeKeyFor(
      _profileServerB.serverUrl,
      _profileServerB.database,
      _profileServerB.login,
    );
    await pinStore.enroll(scopeKeyB, '5678');

    final fake = _FakeMigrationAuthService({
      _FakeMigrationAuthService.scopeKeyFor(_serverUrl, _database): [
        _profileWithKey,
      ],
      _FakeMigrationAuthService.scopeKeyFor(_serverUrlB, _databaseB): [
        _profileServerB,
      ],
    });
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authControllerProvider.notifier);

    // El servidor A se migra primero (como haría abrir la pantalla de PIN
    // ahí primero)...
    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrl,
      database: _database,
    );
    // ...y DESPUÉS el servidor B, en el mismo dispositivo. Con una marca
    // global (52dcb1a) esta segunda llamada nunca llegaría a leer ni a
    // retener nada de B.
    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrlB,
      database: _databaseB,
    );

    expect(fake.retainedCalls, unorderedEquals([_profileWithKey, _profileServerB]));
  });

  // --- Defecto corregido sobre 52dcb1a: el `finally` marcaba "ya corrió"
  // incluso cuando la lectura fallaba, así que un error transitorio nunca se
  // reintentaba. --------------------------------------------------------
  test('failed legacy pin migration is retried next time', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final pinStore = PinCredentialStore(preferences);
    final scopeKey = pinScopeKeyFor(
      _profileWithKey.serverUrl,
      _profileWithKey.database,
      _profileWithKey.login,
    );
    await pinStore.enroll(scopeKey, '1234');

    final fake = _FakeMigrationAuthService(
      {
        _FakeMigrationAuthService.scopeKeyFor(_serverUrl, _database): [
          _profileWithKey,
        ],
      },
      failFirstReadForScope: {
        _FakeMigrationAuthService.scopeKeyFor(_serverUrl, _database),
      },
    );
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(authControllerProvider.notifier);

    // Primer intento: la lectura falla — nunca lanza hacia afuera, y no
    // debe marcar nada como "ya corrió".
    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrl,
      database: _database,
    );
    expect(fake.retainedCalls, isEmpty);

    // Segundo intento: ya no falla — migra de verdad, porque la marca de
    // "ya corrió" nunca se puso.
    await migrateLegacyPinRetention(
      preferences: preferences,
      notifier: notifier,
      pinCredentialStore: pinStore,
      serverUrl: _serverUrl,
      database: _database,
    );
    expect(fake.retainedCalls, [_profileWithKey]);
  });
}
