import 'dart:io';

import 'package:drift/native.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/account/user_preferences_dialog.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/settings/settings_screen.dart';

/// Enchufe de presencia y «Mis preferencias» al runtime real — sólo lo que
/// vive en `router.dart` (los puertos de `orbi_runtime/lib/src/account/`, la
/// caché en `SharedPreferences`, y qué recibe `OperationalShell`).
///
/// Deliberadamente ONLINE-OFF (`SessionRuntime.activate` sin `apiKey`): con
/// cliente, `scopeCatalogCompositionProvider` arranca el coordinador de sync
/// y el socket de tiempo real de verdad (`scopeSyncCoordinatorProvider`,
/// `scopeRealtimeSyncCoordinatorProvider`), y ninguno de los dos tiene
/// servidor real que contestar en esta prueba — exactamente lo que
/// `workspace_switch_user_router_test.dart` advierte que cuelga
/// `pumpAndSettle`. Sin `apiKey` los dos se quedan en `null`
/// («Sesión sin conexión: no hay socket que abrir»,
/// `router.dart:scopeRealtimeSyncCoordinatorProvider`), así que esta
/// suite SÍ puede montar el marco completo con seguridad. Las cuatro
/// pruebas son, además, escenarios legítimamente offline: preferencias
/// personales y presencia funcionan sin red por diseño.
AppScope _scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'account-router-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'orbi_demo',
  userId: 42,
);

AuthProfile _profile(AppScope scope) => AuthProfile(
  serverUrl: scope.normalizedServerUrl,
  database: scope.database,
  login: 'erik',
  userId: scope.userId,
  installationId: scope.installationId,
  credentialReference: 'ref-1',
  companyId: 1,
  companyName: 'Empresa Demo',
);

CapabilitySnapshot _capabilities(AppScope scope) => CapabilitySnapshot(
  scopeKey: scope.scopeKey,
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 13),
  permissions: const ['seller'],
);

final class _StubSaleActions implements SaleOdooActions {
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async => null;
}

String _presenceSupportedKey(AppScope scope) =>
    'orbi/presence_supported/${scope.normalizedServerUrl}|${scope.database}';

void main() {
  late Directory directory;
  late File dbFile;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-account-router-');
    dbFile = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<SessionRuntime> offlineRuntime(AppScope scope) async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(dbFile)),
    );
    final runtime = SessionRuntime(databaseOwner: owner);
    final activation = await runtime.activate(scope);
    expect(
      activation.client,
      isNull,
      reason:
          'esta suite depende de que activar sin apiKey no cree OdooClient '
          '— si eso cambiara, dejaría de ser seguro montar el router con '
          'pumpAndSettle (ver la nota de la clase).',
    );
    return runtime;
  }

  Future<ProviderContainer> buildContainer({
    required AppScope scope,
    required SessionRuntime runtime,
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: AuthControllerStatus.authenticated,
            profile: _profile(scope),
            capabilities: _capabilities(scope),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        runtimeSessionProvider.overrideWithValue(runtime),
      ],
    );
    return container;
  }

  Future<void> pumpRouter(WidgetTester tester, ProviderContainer container) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAvatarMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('shell-avatar-button')));
    await tester.pumpAndSettle();
  }

  Color dotColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.byKey(const Key('shell-presence-dot')),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets(
    '(a) tocar «Mis preferencias» abre UserPreferencesDialog, NO navega a '
    '/settings',
    (tester) async {
      final scope = _scope();
      final runtime = await offlineRuntime(scope);
      final container = await buildContainer(scope: scope, runtime: runtime);
      addTearDown(container.dispose);

      await pumpRouter(tester, container);
      await openAvatarMenu(tester);

      await tester.tap(find.byKey(const Key('shell-preferences-item')));
      await tester.pumpAndSettle();

      expect(find.byType(UserPreferencesDialog), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing);

      // Bloqueo por inactividad (14-sep-2026): con sesión de runtime real
      // (`runtimeSessionProvider` arriba), `_inactivityLockControllerProvider`
      // arma un `Timer.periodic` de verdad. `UncontrolledProviderScope` no es
      // dueño del contenedor, así que `flutter_test` no lo desecha al tirar
      // el árbol de widgets — y `_verifyInvariants()` corre ANTES de que el
      // `addTearDown(container.dispose)` de arriba llegue a ejecutarse (ver
      // `_runTestBody` en `flutter_test/binding.dart`). Desechar aquí, dentro
      // del cuerpo de la prueba, cancela el temporizador a tiempo; el
      // `addTearDown` sigue de respaldo (`dispose()` es seguro de llamar dos
      // veces) para cualquier salida anticipada por una aserción fallida.
      container.dispose();
    },
  );

  testWidgets(
    '(e) tocar «Configuración» en el carril o pie abre SettingsScreen, no '
    'el diálogo de preferencias',
    (tester) async {
      final scope = _scope();
      final runtime = await offlineRuntime(scope);
      final container = await buildContainer(scope: scope, runtime: runtime);
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      // «Configuración» vive en el pie del panel (`footerItems`,
      // `operational_shell.dart:_pane`), no en el menú del avatar — no hace
      // falta abrir nada antes de tocarla.
      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(UserPreferencesDialog), findsNothing);

      // Ver el comentario de la prueba (a) sobre por qué esto debe pasar
      // AQUÍ y no sólo en el `addTearDown` de arriba.
      container.dispose();
    },
  );

  testWidgets(
    '(b) con presence_supported=true y una presencia pendiente busy, el '
    'avatar muestra el punto de «No molestar»',
    (tester) async {
      final scope = _scope();
      final runtime = await offlineRuntime(scope);
      final queue = OfflineQueueDataSource(
        runtime.active!.database.database,
      );
      await UserPresencePort(
        actions: _StubSaleActions(),
        queue: queue,
      ).set(scope.userId, OdooPresence.busy);

      final container = await buildContainer(
        scope: scope,
        runtime: runtime,
        initialPrefs: {_presenceSupportedKey(scope): true},
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);

      final dot = find.byKey(const Key('shell-presence-dot'));
      expect(dot, findsOneWidget);
      final theme = FluentTheme.of(tester.element(dot));
      expect(dotColor(tester), theme.resources.systemFillColorCritical);

      // Ver el comentario de la prueba (a) sobre por qué esto debe pasar
      // AQUÍ y no sólo en el `addTearDown` de arriba.
      container.dispose();
    },
  );

  testWidgets(
    '(c) elegir «Ausente» deja una operación en cola con {status: away}, '
    'sin red',
    (tester) async {
      final scope = _scope();
      final runtime = await offlineRuntime(scope);
      final container = await buildContainer(
        scope: scope,
        runtime: runtime,
        initialPrefs: {_presenceSupportedKey(scope): true},
      );
      addTearDown(container.dispose);

      await pumpRouter(tester, container);
      await openAvatarMenu(tester);

      final submenu = find.byKey(const Key('shell-presence-submenu'));
      expect(submenu, findsOneWidget);
      await tester.tap(submenu);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('shell-presence-option-away')).first,
      );
      await tester.pumpAndSettle();

      final queue = OfflineQueueDataSource(
        runtime.active!.database.database,
      );
      final pending = await queue.getOperationsForModel('res.users');
      final presenceOps = pending.where(
        (op) => op.method == 'mobile_set_im_status',
      );
      expect(presenceOps, hasLength(1));
      expect(presenceOps.first.values, {'status': 'away'});

      // Ver el comentario de la prueba (a) sobre por qué esto debe pasar
      // AQUÍ y no sólo en el `addTearDown` de arriba.
      container.dispose();
    },
  );

  testWidgets('(d) con presence_supported=false, no aparece «Estado»', (
    tester,
  ) async {
    final scope = _scope();
    final runtime = await offlineRuntime(scope);
    final container = await buildContainer(
      scope: scope,
      runtime: runtime,
      initialPrefs: {_presenceSupportedKey(scope): false},
    );
    addTearDown(container.dispose);

    await pumpRouter(tester, container);
    await openAvatarMenu(tester);

    expect(
      find.byKey(const Key('shell-presence-submenu')),
      findsNothing,
    );
    expect(find.text('Estado'), findsNothing);

    // Ver el comentario de la prueba (a) sobre por qué esto debe pasar AQUÍ
    // y no sólo en el `addTearDown` de arriba.
    container.dispose();
  });
}
