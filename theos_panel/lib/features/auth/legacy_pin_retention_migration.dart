import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;
import 'package:orbi_runtime/orbi_runtime.dart' show AppScope;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller.dart';
import 'pin_credential_store.dart';

/// Migración de una sola vez (decisión del dueño, 14-sep-2026: «el PIN
/// mantiene el tope de vendedor al entrar o cambiar de usuario», también
/// sin conexión). El selector de `PinLoginScreen` sólo ofrece perfiles cuya
/// llave esté RETENIDA para el PIN
/// (`AuthNotifier.pinRetainedProfilesFor`/`NativeAuthService
/// .retainCredentialForPin`), pero esa bandera es más nueva que el propio
/// enrolamiento de PIN: quien enroló un PIN ANTES de que existiera la
/// retención nunca la tiene marcada y, sin esta migración, desaparecería
/// para siempre del selector aunque su PIN siga enrolado en
/// [PinCredentialStore] y su llave siga en el almacén.
///
/// 🔴 Corregido el 14-sep-2026 (revisión del coordinador sobre 52dcb1a): la
/// primera versión usaba UNA marca global para "ya corrió" — con PINs en dos
/// servidores (p. ej. ERP2 y Mepriga) en el MISMO dispositivo, migrar el
/// primero dejaba la marca puesta y el segundo servidor nunca se migraba.
/// Ahora la marca es POR servidor+base, con el mismo patrón base64url que ya
/// usan `NativeAuthService._profileKeyFor`/`_pinRetainedKeyFor` para sus
/// propias claves por credencial — ver [legacyPinRetentionMigrationKeyFor].
const String kLegacyPinRetentionMigrationKeyPrefix =
    'orbi/auth/pin_retained_migration/theos_panel/v1';

/// La clave de "ya migré [serverUrl]/[database]" — un dispositivo con PINs en
/// varios servidores necesita una marca por cada uno, nunca una sola global.
String legacyPinRetentionMigrationKeyFor(String serverUrl, String database) {
  final normalizedServerUrl = AppScope(
    appId: 'theos_panel',
    installationId: 'pin_retained_migration',
    normalizedServerUrl: serverUrl,
    database: database,
    userId: 1,
  ).normalizedServerUrl;
  final encoded = base64Url
      .encode(utf8.encode('$normalizedServerUrl|$database'))
      .replaceAll('=', '');
  return '$kLegacyPinRetentionMigrationKeyPrefix/$encoded';
}

/// Recorre, para [serverUrl]/[database], los perfiles que
/// [AuthNotifier.profilesWithStoredKeyFor] (el "método de lectura del
/// servicio" que este archivo usa en vez de mover [PinCredentialStore] a
/// `orbi_runtime` — frontera de paquetes, 14-sep-2026) reporta con una
/// llave TODAVÍA físicamente en el almacén, y marca la retención
/// ([AuthNotifier.retainCredentialForPin]) para cada uno que además tenga
/// un PIN de 4 dígitos enrolado ([PinCredentialStore.isEnrolled] contra
/// [pinScopeKeyFor]).
///
/// Un perfil SIN llave en el almacén no se marca — ese usuario tiene que
/// volver a entrar con su clave una vez para que `login()`/
/// `loginWithApiKey()` la deje ahí de nuevo; no hay nada que retener
/// todavía.
///
/// Corre como mucho una vez por servidor+base
/// ([legacyPinRetentionMigrationKeyFor], en las mismas [SharedPreferences]
/// que [PinCredentialStore]). Nunca lanza: si la lectura o la retención
/// fallan a mitad de camino, el error se registra con `logger.w` y la
/// marca de "ya corrió" NUNCA se pone — un fallo transitorio (almacén
/// caído, etc.) se reintenta la próxima vez que se abra la pantalla de
/// PIN para este mismo servidor+base, en vez de quedar huérfano para
/// siempre.
Future<void> migrateLegacyPinRetention({
  required SharedPreferences preferences,
  required AuthNotifier notifier,
  required PinCredentialStore pinCredentialStore,
  required String serverUrl,
  required String database,
}) async {
  final migrationKey = legacyPinRetentionMigrationKeyFor(serverUrl, database);
  if (preferences.getBool(migrationKey) == true) return;
  try {
    final profiles = await notifier.profilesWithStoredKeyFor(
      serverUrl,
      database,
    );
    for (final profile in profiles) {
      final scopeKey = pinScopeKeyFor(
        profile.serverUrl,
        profile.database,
        profile.login,
      );
      if (!pinCredentialStore.isEnrolled(scopeKey)) continue;
      await notifier.retainCredentialForPin(profile, true);
    }
    // La marca de "ya corrió" se pone SÓLO si el recorrido de arriba
    // terminó sin excepción — ver el `catch` de abajo.
    await preferences.setBool(migrationKey, true);
  } catch (error) {
    logger.w(
      '[LegacyPinRetentionMigration]',
      'La migración de retención de PIN para server=$serverUrl '
          'db=$database falló y se reintentará la próxima vez que se abra '
          'la pantalla de PIN: $error',
    );
  }
}
