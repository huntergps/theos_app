import 'package:shared_preferences/shared_preferences.dart';

/// Si `product.product.image_128` existe en ESTE servidor+base —
/// [EnvasesExistenciasReader.probeImageFieldAvailable] es quien realmente
/// pregunta con `fields_get`; esto sólo persiste la respuesta para que se
/// pregunte UNA VEZ por servidor+base, nunca en cada refresco de
/// existencias.
///
/// Mismo principio que `ServerFeatureStore`
/// (`orbi_runtime/lib/src/read/server_features.dart`): `unknown` es
/// deliberadamente distinto de `unavailable` — sin evidencia todavía (o un
/// sondeo que falló por red/permiso) no borra lo ya sabido, y no se confunde
/// con un 404 real de campo.
enum EnvasesImageFieldState { available, unavailable, unknown }

/// Persiste por (`serverUrl`, `database`) — igual que
/// `serverFeaturesPrefsKey`: cambiar de servidor o de base es una sesión
/// distinta y vuelve a sondear.
final class EnvasesImageFieldCache {
  const EnvasesImageFieldCache({
    required this.preferences,
    required this.serverUrl,
    required this.database,
  });

  final SharedPreferences preferences;
  final String serverUrl;
  final String database;

  String get _key => 'orbi/envases_image_field/$serverUrl|$database';

  /// Lo guardado hasta ahora, sin red.
  EnvasesImageFieldState read() {
    return switch (preferences.getString(_key)) {
      'available' => EnvasesImageFieldState.available,
      'unavailable' => EnvasesImageFieldState.unavailable,
      _ => EnvasesImageFieldState.unknown,
    };
  }

  Future<void> write(EnvasesImageFieldState state) =>
      preferences.setString(_key, state.name);
}
