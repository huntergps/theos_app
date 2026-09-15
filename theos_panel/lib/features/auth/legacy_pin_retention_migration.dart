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
/// Clave del "una sola vez" — deliberadamente SIN servidor/base/usuario,
/// igual que `NativeAuthService._rememberedMigrationKey` (la migración
/// equivalente para «recordada»): un dispositivo Orbi está atado en la
/// práctica a un único servidor+base durante toda su vida.
const String kLegacyPinRetentionMigrationKey =
    'orbi/auth/pin_retained_migration/theos_panel/v1';

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
/// Corre como mucho una vez por instalación
/// ([kLegacyPinRetentionMigrationKey], en las mismas [SharedPreferences]
/// que [PinCredentialStore]). Nunca lanza: si algo falla a mitad de camino,
/// la bandera de "ya corrió" igual se deja puesta en el `finally` — un
/// reintento indefinido de una migración que ya tropezó una vez no vale la
/// pena frente al costo de quedarse reintentando en cada apertura de la
/// pantalla de PIN; el peor caso es el mismo de siempre, "vuelve a entrar
/// con tu clave una vez".
Future<void> migrateLegacyPinRetention({
  required SharedPreferences preferences,
  required AuthNotifier notifier,
  required PinCredentialStore pinCredentialStore,
  required String serverUrl,
  required String database,
}) async {
  if (preferences.getBool(kLegacyPinRetentionMigrationKey) == true) return;
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
  } finally {
    await preferences.setBool(kLegacyPinRetentionMigrationKey, true);
  }
}
