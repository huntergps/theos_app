// Auditoría de "se pierde todo lo que estaba haciendo" (14-sep-2026), bloque
// A: Flutter web usa rutas con `#` y, al reabrir Orbi escribiendo el
// dominio (o desde un acceso directo / pestaña anclada), no llega el
// `#/ruta` — el redirect de `router.dart` siempre caía en Inicio.
//
// Estas pruebas fijan el contrato de la corrección: la última ubicación se
// guarda por identidad y se usa como destino tras un login sin `returnTo`
// explícito, siempre pasando por `RouteAccessPolicy` para no reabrir una
// pantalla que ya no está permitida.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/orbi_app.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

AuthProfile _profile({required String database, required int userId}) =>
    AuthProfile(
      serverUrl: 'https://erp.test',
      database: database,
      login: 'user-$userId',
      userId: userId,
      installationId: 'install-$userId',
      credentialReference: 'api-key',
      companyId: 1,
    );

CapabilitySnapshot _capabilities(List<String> permissions) =>
    CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 14),
      permissions: permissions,
    );

/// `RouteAccessPolicy` now also asks `ServerFeatures` for `/sales` and
/// `/envases` (14-sep-2026, «theos_panel debe ser universal»): with nothing
/// probed yet everything reads `unknown`, and `unknown` enables nothing.
/// This whole file is about LAST-LOCATION restoration, not server evidence,
/// so every profile it uses gets every feature seeded as already confirmed.
Future<void> _seedAllFeaturesAvailable(
  SharedPreferences preferences,
  AuthProfile profile,
) async {
  var features = ServerFeatures.empty;
  final checkedAt = DateTime.utc(2026, 9, 14);
  for (final feature in ServerFeature.values) {
    features = features.withState(feature, ServerFeatureState.available, checkedAt);
  }
  await preferences.setString(
    serverFeaturesPrefsKey(profile.serverUrl, profile.database),
    features.toJson(),
  );
}

ProviderContainer _containerFor({
  required AuthProfile profile,
  required List<String> permissions,
  required SharedPreferences preferences,
}) => ProviderContainer(
  overrides: [
    authInitialStateProvider.overrideWithValue(
      AuthViewState(
        status: AuthControllerStatus.authenticated,
        profile: profile,
        capabilities: _capabilities(permissions),
      ),
    ),
    sharedPreferencesProvider.overrideWithValue(preferences),
  ],
);

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const OrbiApp()),
  );
  await tester.pumpAndSettle();
}

/// Desmonta del todo el árbol actual y deja correr un par de frames extra —
/// Riverpod difiere la destrucción de providers que dejan de observarse un
/// par de microtareas (`ProviderScheduler._scheduleDisposeTask`), y
/// reemplazar un `ProviderContainer` por otro en el mismo test (para simular
/// "cerrar la pestaña y reabrir") necesita que esa destrucción termine antes
/// de construir el siguiente árbol, o el binding de pruebas se queja de un
/// `Timer` todavía pendiente al terminar la prueba.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'restores last location after reopening',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final profile = _profile(database: 'db1', userId: 5);
      await _seedAllFeaturesAvailable(preferences, profile);

      final container1 = _containerFor(
        profile: profile,
        permissions: const ['envases_read'],
        preferences: preferences,
      );
      addTearDown(container1.dispose);
      await _pump(tester, container1);
      container1.read(orbiRouterProvider).go('/envases');
      await tester.pumpAndSettle();
      expect(container1.read(orbiRouterProvider).state.uri.path, '/envases');

      // "Cerrar la pestaña y reabrir": un `ProviderContainer` completamente
      // nuevo, con las MISMAS preferencias (mismo `SharedPreferences`), que
      // arranca ya autenticado y sin `returnTo` — exactamente lo que ocurre
      // al escribir el dominio de nuevo o abrir un acceso directo.
      await _unmount(tester);
      final container2 = _containerFor(
        profile: profile,
        permissions: const ['envases_read'],
        preferences: preferences,
      );
      addTearDown(container2.dispose);
      await _pump(tester, container2);

      expect(
        container2.read(orbiRouterProvider).state.uri.path,
        '/envases',
        reason:
            'Reabrir la app debería volver a la última pantalla, no a Inicio.',
      );
    },
  );

  testWidgets(
    'last location is per user',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final profile1 = _profile(database: 'db1', userId: 5);
      final profile2 = _profile(database: 'db2', userId: 9);
      await _seedAllFeaturesAvailable(preferences, profile1);
      await _seedAllFeaturesAvailable(preferences, profile2);

      final container1 = _containerFor(
        profile: profile1,
        permissions: const ['envases_read'],
        preferences: preferences,
      );
      addTearDown(container1.dispose);
      await _pump(tester, container1);
      container1.read(orbiRouterProvider).go('/envases');
      await tester.pumpAndSettle();
      expect(container1.read(orbiRouterProvider).state.uri.path, '/envases');

      await _unmount(tester);
      final container2 = _containerFor(
        profile: profile2,
        permissions: const ['envases_read'],
        preferences: preferences,
      );
      addTearDown(container2.dispose);
      await _pump(tester, container2);

      expect(
        container2.read(orbiRouterProvider).state.uri.path,
        '/',
        reason:
            'La ubicación guardada por otra identidad no debe heredarse.',
      );
    },
  );

  testWidgets(
    'explicit returnTo wins over last location',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final profile = _profile(database: 'db1', userId: 5);
      await _seedAllFeaturesAvailable(preferences, profile);

      final container = _containerFor(
        profile: profile,
        permissions: const ['envases_read', 'seller'],
        preferences: preferences,
      );
      addTearDown(container.dispose);
      await _pump(tester, container);

      container.read(orbiRouterProvider).go('/envases');
      await tester.pumpAndSettle();
      expect(container.read(orbiRouterProvider).state.uri.path, '/envases');

      // Ya autenticado: aterrizar en `/login?returnTo=/sales` es exactamente
      // lo que produce el propio redirect cuando alguien sin sesión pulsa un
      // enlace a `/sales` — `returnTo` debe ganarle a la última ubicación
      // guardada (`/envases`), que en este momento es más vieja.
      container.read(orbiRouterProvider).go('/login?returnTo=%2Fsales');
      await tester.pumpAndSettle();

      expect(
        container.read(orbiRouterProvider).state.uri.path,
        '/sales',
        reason:
            'returnTo explícito debe ganarle a la última ubicación guardada.',
      );
    },
  );

  testWidgets(
    'rejected last location falls back to home',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final profile = _profile(database: 'db1', userId: 5);
      await _seedAllFeaturesAvailable(preferences, profile);

      final container1 = _containerFor(
        profile: profile,
        permissions: const ['envases_read'],
        preferences: preferences,
      );
      addTearDown(container1.dispose);
      await _pump(tester, container1);
      container1.read(orbiRouterProvider).go('/envases');
      await tester.pumpAndSettle();
      expect(container1.read(orbiRouterProvider).state.uri.path, '/envases');

      // Reabrir con capacidades que YA NO incluyen `envases_read` — el mismo
      // efecto que un cambio de permisos en el servidor entre una sesión y
      // la siguiente.
      await _unmount(tester);
      final container2 = _containerFor(
        profile: profile,
        permissions: const ['seller'],
        preferences: preferences,
      );
      addTearDown(container2.dispose);
      await _pump(tester, container2);

      expect(
        container2.read(orbiRouterProvider).state.uri.path,
        '/',
        reason:
            'Una última ubicación que ya no está permitida debe caer a Inicio.',
      );
    },
  );
}
