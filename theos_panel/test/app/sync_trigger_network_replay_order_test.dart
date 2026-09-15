import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/sync/network_signal_provider.dart';

/// Defecto medido el 14-sep-2026 en los tres bloques aislados de
/// `router.dart` que puentean `networkSignalProvider` a un
/// `StreamController<bool>.broadcast()`: un `add()` hecho ANTES de que haya
/// oyentes se pierde para siempre en un `broadcast()` (no lo bufferea para
/// el próximo `listen()`). Los tres bloques creaban el controlador, llamaban
/// a `ref.listen(networkSignalProvider, ..., fireImmediately: true)` —que
/// invoca su callback de forma SÍNCRONA y hace ese `add()` ANTES de que
/// existiera ningún oyente— y RECIÉN DESPUÉS construían el disparador
/// (que es quien se suscribe, en su propio constructor). Si la señal de red
/// ya tenía un valor conocido al activar el scope (lo normal en
/// producción), ese valor inicial se perdía y el disparador arrancaba
/// creyendo "sin red" hasta el próximo cambio real de conectividad.
///
/// Estas pruebas activan la sesión, dejan que `networkSignalProvider` YA
/// resuelva un valor (`awaitFirstNetworkSignal`, más abajo) y RECIÉN
/// DESPUÉS leen el provider del disparador — exactamente la
/// secuencia que dispara el hueco. Sirven tanto para
/// `scopeSyncQueuedOperationTriggerProvider` (a) como para
/// `scopeSyncPeriodicBackupTriggerProvider` (b): el segundo tiene, además,
/// el mismo hueco en `realtimeStatusController` (el estado del tiempo real
/// también se pierde), así que (b) no necesita ni depende de que la red
/// llegue a tiempo — el `.add(RealtimeStatus.offline)` perdido ya basta
/// para desarmar el respaldo para siempre.
///
/// `SyncCoordinatorImpl` es `final class` (no se puede sustituir por un
/// doble genérico que implemente `SyncCoordinator`): se usa el coordinador
/// REAL con un `SyncJob` que sólo cuenta cuántas veces corrió, en vez de un
/// "coordinador falso" — así se comprueba el camino de verdad
/// (`requestSync` → `_drainOnce` → `job.run`), no una sustitución.
final class _RecordingJob implements SyncJob {
  _RecordingJob(this.id);

  @override
  final String id;
  int runs = 0;

  @override
  Future<SyncJobResult> run(AppScope scope) async {
    runs++;
    return const SyncJobResult.committed();
  }
}

AppScope _scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'sync-trigger-order-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'orbi_demo',
  userId: 9,
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
  fetchedAt: DateTime.utc(2026, 9, 14),
  permissions: const ['seller'],
);

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('orbi-sync-order-');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  /// Sesión SIN CONEXIÓN (`activate` sin `apiKey`): igual que
  /// `router_user_account_test.dart:offlineRuntime`. `active.database` sí
  /// existe (hace falta para `_sessionQueueProvider` en (a)); `active.client`
  /// es `null`, así que `scopeRealtimeSyncCoordinatorProvider` devuelve
  /// `null` sin abrir ningún socket real — necesario para (b).
  Future<SessionRuntime> offlineRuntime(AppScope scope) async {
    final dbFile = File('${directory.path}/runtime.sqlite');
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(dbFile)),
    );
    final runtime = SessionRuntime(databaseOwner: owner);
    final activation = await runtime.activate(scope);
    expect(activation.client, isNull);
    return runtime;
  }

  Future<ProviderContainer> buildContainer(
    WidgetTester tester, {
    required AppScope scope,
    required SessionRuntime runtime,
    required _RecordingJob operationsJob,
  }) async {
    SharedPreferences.setMockInitialValues({});
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
        // La red YA tiene un valor conocido: una sola emisión, para poder
        // esperar a que `networkSignalProvider` resuelva ANTES de leer el
        // provider del disparador (ver el docstring del archivo).
        networkSignalProvider.overrideWith(
          (ref) => Stream<NetworkSignal>.value(
            NetworkSignal(transports: const [NetworkTransport.wifi]),
          ),
        ),
        // `SyncCoordinatorImpl` real (es `final class`, no se puede fingir)
        // con un único `SyncJob` que sólo cuenta cuántas veces corrió.
        // `unawaited(coordinator.start(scope))` reproduce exactamente lo
        // que hace `scopeSyncCoordinatorProvider` en producción.
        scopeSyncCoordinatorProvider.overrideWith((ref) {
          final coordinator = SyncCoordinatorImpl(jobs: [operationsJob]);
          unawaited(coordinator.start(scope));
          ref.onDispose(coordinator.dispose);
          return coordinator;
        }),
      ],
    );
    // `AppForegroundSignal` necesita un `WidgetsBinding` vivo
    // (`AppLifecycleListener`) — `testWidgets` ya lo inicializa; esto sólo
    // evita depender de un detalle no documentado de `pump()` sin ningún
    // widget montado antes (mismo comentario que
    // `sri_pending_notifier_test.dart:buildContainer`).
    await tester.pumpWidget(const SizedBox.shrink());
    return container;
  }

  /// Deja que `networkSignalProvider` resuelva su primer (y único) valor
  /// ANTES de que la prueba lea el provider del disparador — exactamente la
  /// secuencia que dispara el hueco medido (ver el docstring del archivo).
  ///
  /// `container.read(networkSignalProvider.future)` se probó primero y se
  /// quedó COLGADO indefinidamente (medido: cuelga incluso con
  /// `Timeout(seconds: 20)`, con la única pista `_RawReceivePort` en la
  /// pila) — no se investigó más a fondo por qué esa combinación puntual no
  /// resuelve nunca dentro de la zona de tiempo simulado de `testWidgets`;
  /// `container.listen` + `tester.pump()` es el mecanismo que YA usa
  /// `router.dart` para leer este mismo `StreamProvider` en producción
  /// (`ref.listen(networkSignalProvider, ...)`), así que es la vía
  /// establecida, no un rodeo improvisado.
  Future<void> awaitFirstNetworkSignal(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    final received = <NetworkSignal>[];
    container.listen<AsyncValue<NetworkSignal>>(networkSignalProvider, (
      previous,
      next,
    ) {
      final value = next.value;
      if (value != null) received.add(value);
    }, fireImmediately: true);
    await tester.pump();
    expect(
      received,
      isNotEmpty,
      reason: 'networkSignalProvider no emitió ningún valor todavía.',
    );
  }

  testWidgets(
    '(a) con la red ya emitida antes de leer el provider, encolar en línea '
    'drena la cola sola',
    (tester) async {
      final scope = _scope();
      final runtime = await offlineRuntime(scope);
      final operationsJob = _RecordingJob('operations');
      final container = await buildContainer(
        tester,
        scope: scope,
        runtime: runtime,
        operationsJob: operationsJob,
      );

      // La red YA emitió: se espera su primer (y único) valor ANTES de leer
      // el provider del disparador — exactamente la secuencia que dispara
      // el hueco medido.
      await awaitFirstNetworkSignal(tester, container);

      final trigger = container.read(scopeSyncQueuedOperationTriggerProvider);
      expect(trigger, isNotNull);

      // Deja asentarse el drenaje inicial de `coordinator.start(scope)`
      // (corre todos los trabajos una vez, sin relación con esta prueba).
      await tester.pump();
      final baseline = operationsJob.runs;
      expect(baseline, 1);

      // Encola una operación en la cola REAL del scope activo.
      final queue = OfflineQueueDataSource(runtime.active!.database.database);
      await queue.queueOperation(
        model: 'sale.order',
        method: 'write',
        recordId: 7,
        values: const {'note': 'x'},
      );

      // Debounce de `SyncQueuedOperationTrigger` (300ms) + margen.
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        operationsJob.runs,
        baseline + 1,
        reason:
            'Encolar en línea, con la red ya conocida al activar el scope, '
            'debe drenar la cola sola. Si esto se queda en $baseline, '
            '_online nunca llegó a `true` en SyncQueuedOperationTrigger — '
            'el `add(true)` de `ref.listen(..., fireImmediately: true)` se '
            'perdió por construirse el disparador DESPUÉS de ese `listen`.',
      );

      container.dispose();
    },
  );

  testWidgets(
    '(b) mismo arranque (red ya presente, tiempo real no vivo): a los 5 '
    'minutos se pide un respaldo periódico',
    (tester) async {
      final scope = _scope();
      final runtime = await offlineRuntime(scope);
      final operationsJob = _RecordingJob('operations');
      final container = await buildContainer(
        tester,
        scope: scope,
        runtime: runtime,
        operationsJob: operationsJob,
      );

      await awaitFirstNetworkSignal(tester, container);

      final trigger = container.read(scopeSyncPeriodicBackupTriggerProvider);
      expect(trigger, isNotNull);

      await tester.pump();
      final baseline = operationsJob.runs;
      expect(baseline, 1);

      // Cinco minutos de reloj falso (el mismo mecanismo que
      // `sri_pending_notifier_test.dart`: `testWidgets` corre dentro de su
      // propia zona de tiempo simulado, así que `Timer.periodic` avanza sin
      // esperar minutos de verdad).
      await tester.pump(const Duration(minutes: 5, seconds: 1));

      expect(
        operationsJob.runs,
        baseline + 1,
        reason:
            'Con red ya presente y tiempo real no vivo (sesión sin '
            'conexión: `scopeRealtimeSyncCoordinatorProvider` es `null`), '
            'el respaldo periódico debe armarse solo. Si esto se queda en '
            '$baseline, el `Timer.periodic` nunca se armó — el '
            '`add(RealtimeStatus.offline)` (y el `add(true)` de la red) se '
            'perdieron por construirse el disparador DESPUÉS de emitirlos.',
      );

      container.dispose();
    },
  );
}
