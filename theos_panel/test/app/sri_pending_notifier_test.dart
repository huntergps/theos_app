import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// `sriPendingProvider` (`router.dart`) prueba directo con un
/// `ProviderContainer` mínimo — nunca montando el armazón completo
/// (`orbiRouterProvider`/`OperationalShell`): un cliente en línea de verdad
/// dispara `scopeSyncCoordinatorProvider`/`scopeRealtimeSyncCoordinatorProvider`
/// contra un servidor que no existe, exactamente lo que
/// `router_user_account_test.dart` advierte que cuelga `pumpAndSettle` (ver
/// su docstring). Como aquí sólo se lee `sriPendingProvider`, Riverpod nunca
/// construye esos otros providers — ninguno de ellos está en su árbol de
/// dependencias.
///
/// `sriPendingProvider` se hizo público (antes `_sriPendingProvider`)
/// exactamente para esto: sin eso, no hay forma de referenciarlo desde otro
/// archivo (mismo problema que documenta
/// `operational_shell_odoo_version_test.dart` sobre `_odooVersionProvider`).
///
/// El tiempo se avanza con `tester.pump(duration)`: `flutter_test` corre
/// cada `testWidgets` dentro de su propia zona de tiempo simulado, así que
/// cualquier `Timer` (el `Timer.periodic` de `SriPendingPoller` incluido)
/// avanza con el reloj falso, sin esperar minutos de verdad.
class _FakeOdooClient extends Mock implements OdooClient {}

void main() {
  final scope = AppScope(
    appId: 'orbi-panel',
    installationId: 'sri-pending-test',
    normalizedServerUrl: 'https://erp.test',
    database: 'orbi_demo',
    userId: 7,
  );

  final profile = AuthProfile(
    serverUrl: scope.normalizedServerUrl,
    database: scope.database,
    login: 'erik',
    userId: scope.userId,
    installationId: scope.installationId,
    credentialReference: 'ref-1',
  );

  CapabilitySnapshot capabilities() => CapabilitySnapshot(
    scopeKey: scope.scopeKey,
    companyId: 1,
    revision: 1,
    fetchedAt: DateTime.utc(2026, 9, 14),
    permissions: const [],
  );

  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sri-pending-test-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  /// Sesión EN LÍNEA: `SessionRuntime.activate` con `apiKey` para que
  /// `activation.client` sea exactamente [client] (mismo patrón que
  /// `SessionRuntime._defaultClient`, pero con una `clientFactory` que
  /// devuelve el falso en vez de un `OdooClient` real).
  Future<SessionRuntime> onlineRuntime(OdooClient client) async {
    final dbFile = File('${directory.path}/runtime-online.sqlite');
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(dbFile)),
    );
    final runtime = SessionRuntime(
      databaseOwner: owner,
      clientFactory: (_, _) => client,
      // No es del interés de esta prueba (huella de la base de Odoo,
      // 14-sep-2026): sin este lector falso, `activate()` le pide
      // `res.users.create_date` al cliente simulado, que no lo responde.
      identityReader: (client, scope) async => 'fixed-identity',
    );
    final activation = await runtime.activate(scope, apiKey: 'test-key');
    expect(activation.client, same(client));
    return runtime;
  }

  /// Sesión SIN CONEXIÓN: `activate` sin `apiKey` nunca crea `OdooClient`
  /// (`SessionRuntime.activate`, `session_runtime.dart`), igual que
  /// `router_user_account_test.dart:offlineRuntime`.
  Future<SessionRuntime> offlineRuntime() async {
    final dbFile = File('${directory.path}/runtime-offline.sqlite');
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(dbFile)),
    );
    final runtime = SessionRuntime(databaseOwner: owner);
    final activation = await runtime.activate(scope);
    expect(activation.client, isNull);
    return runtime;
  }

  Future<ProviderContainer> buildContainer(
    WidgetTester tester,
    SessionRuntime runtime,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: AuthControllerStatus.authenticated,
            profile: profile,
            capabilities: capabilities(),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        runtimeSessionProvider.overrideWithValue(runtime),
      ],
    );
    // Deliberadamente SIN `addTearDown(container.dispose)`: el chequeo de
    // `flutter_test` de "ningún `Timer` pendiente" corre DENTRO de
    // `_runTestBody`, antes de que el `tearDown` de `package:test` tenga
    // ocasión de ejecutarse — medido corriendo esta misma prueba: con sólo
    // `addTearDown` el `Timer.periodic` de `SriPendingPoller` seguía "vivo"
    // en ese chequeo aunque el contenedor SÍ se desechaba después. Cada
    // prueba desecha el contenedor a mano, al final de su propio cuerpo.
    //
    // Un `Container` cualquiera basta para montarlo: `AppForegroundSignal`
    // necesita un `WidgetsBinding` vivo (`AppLifecycleListener`), no una
    // pantalla real — `testWidgets` ya lo inicializa, esto sólo evita
    // depender de un detalle no documentado de `pump()` sin ningún widget
    // montado antes.
    await tester.pumpWidget(const SizedBox.shrink());
    return container;
  }

  /// Deja correr los microtask/`Future` encadenados de un sondeo
  /// (`hasField` → `SharedPreferences.setBool` → `searchCount` →
  /// `SharedPreferences.setInt` → el callback de estado) sin adelantar el
  /// reloj lo bastante como para disparar el propio temporizador de 5
  /// minutos por accidente.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets(
    'sri count refreshes every five minutes while the session is stable',
    (tester) async {
      final client = _FakeOdooClient();
      when(
        () => client.hasField('account.move', 'edi_state'),
      ).thenAnswer((_) async => true);
      var searchCountCalls = 0;
      when(
        () => client.searchCount(
          model: any(named: 'model'),
          domain: any(named: 'domain'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenAnswer((_) async {
        searchCountCalls++;
        return searchCountCalls == 1 ? 3 : 5;
      });

      final runtime = await onlineRuntime(client);
      final container = await buildContainer(tester, runtime);

      // Sondeo inmediato al construirse el `SriPendingPoller`.
      container.read(sriPendingProvider);
      await settle(tester);
      expect(container.read(sriPendingProvider)?.count, 3);
      verify(
        () => client.searchCount(
          model: 'account.move',
          domain: any(named: 'domain'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);

      // Con b31b3b9 esto NUNCA vuelve a sondear: `_SriPendingNotifier.build()`
      // sólo sondeaba cuando el propio provider se reconstruía por un cambio
      // de `authControllerProvider`/`runtimeSessionProvider` — con la sesión
      // estable, ninguno de los dos cambia, así que la cifra se quedaba
      // congelada en 3 para siempre.
      await tester.pump(const Duration(minutes: 5, seconds: 1));
      await settle(tester);

      expect(
        container.read(sriPendingProvider)?.count,
        5,
        reason:
            'el temporizador de 5 minutos debe haber disparado un segundo '
            'sondeo aunque la sesión no cambió',
      );
      verify(
        () => client.searchCount(
          model: 'account.move',
          domain: any(named: 'domain'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);

      container.dispose();
    },
  );

  testWidgets('no timer without an active client', (tester) async {
    final client = _FakeOdooClient();
    when(
      () => client.hasField('account.move', 'edi_state'),
    ).thenAnswer((_) async => true);
    when(
      () => client.searchCount(
        model: any(named: 'model'),
        domain: any(named: 'domain'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => 3);

    // El cliente falso se pasa como `clientFactory`, pero `activate()` sin
    // `apiKey` nunca lo invoca (`SessionRuntime.activate`): la sesión queda
    // sin cliente, igual que una restauración sin conexión.
    final runtime = await offlineRuntime();
    final container = await buildContainer(tester, runtime);

    expect(container.read(sriPendingProvider), isNull);
    await settle(tester);
    expect(container.read(sriPendingProvider), isNull);

    // Diez minutos de reloj falso: si `SriPendingNotifier.build()` hubiera
    // armado un `SriPendingPoller` (y por tanto su `Timer.periodic`) sin
    // cliente, esto dispararía al menos un sondeo.
    await tester.pump(const Duration(minutes: 10));
    await settle(tester);

    verifyNever(() => client.hasField(any(), any()));
    verifyNever(
      () => client.searchCount(
        model: any(named: 'model'),
        domain: any(named: 'domain'),
        cancelToken: any(named: 'cancelToken'),
      ),
    );
    expect(container.read(sriPendingProvider), isNull);

    container.dispose();
  });

  testWidgets(
    'access denied turns the signal off without retrying',
    (tester) async {
      final client = _FakeOdooClient();
      when(
        () => client.hasField('account.move', 'edi_state'),
      ).thenAnswer((_) async => true);
      when(
        () => client.searchCount(
          model: any(named: 'model'),
          domain: any(named: 'domain'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).thenThrow(const OdooAccessDeniedException('no access on account.move'));

      final runtime = await onlineRuntime(client);
      final container = await buildContainer(tester, runtime);

      container.read(sriPendingProvider);
      await settle(tester);
      expect(container.read(sriPendingProvider), isNull);
      verify(
        () => client.searchCount(
          model: 'account.move',
          domain: any(named: 'domain'),
          cancelToken: any(named: 'cancelToken'),
        ),
      ).called(1);

      // Dos vueltas completas del temporizador: si el acceso denegado no
      // apagara el sondeo (y su `Timer.periodic`), habría llamadas nuevas
      // acá. `verify(...).called(n)` sólo cuenta invocaciones NO marcadas
      // por una verificación anterior — el `.called(1)` de arriba ya marcó
      // la única llamada real, así que lo correcto para "no hubo ninguna
      // más" es `verifyNever`, no repetir `.called(1)`.
      await tester.pump(const Duration(minutes: 5, seconds: 1));
      await settle(tester);
      await tester.pump(const Duration(minutes: 5, seconds: 1));
      await settle(tester);

      verifyNever(
        () => client.searchCount(
          model: 'account.move',
          domain: any(named: 'domain'),
          cancelToken: any(named: 'cancelToken'),
        ),
      );
      expect(container.read(sriPendingProvider), isNull);

      container.dispose();
    },
  );

  testWidgets('timer is cancelled on dispose', (tester) async {
    final client = _FakeOdooClient();
    when(
      () => client.hasField('account.move', 'edi_state'),
    ).thenAnswer((_) async => true);
    when(
      () => client.searchCount(
        model: any(named: 'model'),
        domain: any(named: 'domain'),
        cancelToken: any(named: 'cancelToken'),
      ),
    ).thenAnswer((_) async => 2);

    final runtime = await onlineRuntime(client);
    final container = await buildContainer(tester, runtime);

    container.read(sriPendingProvider);
    await settle(tester);
    expect(container.read(sriPendingProvider)?.count, 2);

    // `container.dispose()` dispara `ref.onDispose` de `SriPendingNotifier`
    // (`_disposePoller`), que llama `SriPendingPoller.dispose()` y cancela
    // el `Timer.periodic`. Si no lo cancelara, esta prueba fallaría sola —
    // `flutter_test` revisa que no quede ningún `Timer` pendiente al
    // terminar — con «A Timer is still pending even after the widget tree
    // was disposed»; no hace falta comprobarlo a mano.
    container.dispose();
  });
}
