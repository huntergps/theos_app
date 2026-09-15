import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/envases_composition.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

import 'package:fluent_ui/fluent_ui.dart';

/// Regresión de los dos errores tragados medidos en 90a37dc: un
/// `scheduleMicrotask(() => unawaited(...))` sin `try`/`catch` alrededor de
/// una llamada que lanza SÍNCRONO (`readerFactory()` sin cliente activo — sin
/// conexión no hay forma de construir el lector). El resultado en 90a37dc es
/// un `ProgressRing` que se queda ahí para siempre: el `setState` que
/// mostraría el error nunca llega a ejecutarse, y `_requestedRefresh` ya
/// quedó en `true`, así que tampoco se vuelve a intentar.
///
/// Ambas pruebas montan una `SessionRuntime` real, activada SIN api key (así
/// que `active.client` es `null`, exactamente la condición que hace que
/// `readerFactory()` lance) — mismo patrón que
/// `test/app/envases_composition_test.dart`.
void main() {
  AppScope scope() => AppScope(
    appId: 'orbi',
    installationId: 'i-1',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 1,
  );

  CapabilitySnapshot capabilities(String scopeKey) => CapabilitySnapshot(
    scopeKey: scopeKey,
    companyId: 4,
    revision: 1,
    fetchedAt: DateTime.utc(2026, 9, 14),
    permissions: const ['envases_read'],
  );

  Future<SessionRuntime> activatedRuntime() async {
    final runtime = SessionRuntime(
      databaseOwner: RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      ),
    );
    await runtime.activate(scope());
    return runtime;
  }

  testWidgets(
    'por recibir shows an error with retry instead of an endless spinner',
    (tester) async {
      final runtime = await activatedRuntime();
      addTearDown(runtime.close);
      final container = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(runtime),
          capabilitySnapshotProvider.overrideWithValue(
            capabilities(runtime.active!.scope.scopeKey),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FluentApp(
            home: EnvasesTrasladoDetalleRoute(pickingId: 11),
          ),
        ),
      );
      // Deja correr el microtask que dispara `controller.refresh()` y su
      // fallo síncrono.
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('envases-traslado-resolver-loading')),
        findsNothing,
        reason: '90a37dc se queda para siempre en el ProgressRing',
      );
      expect(
        find.byKey(const Key('envases-traslado-resolver-error')),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    },
  );

  testWidgets('send route shows catalog load error', (tester) async {
    final runtime = await activatedRuntime();
    addTearDown(runtime.close);
    final container = ProviderContainer(
      overrides: [
        runtimeSessionProvider.overrideWithValue(runtime),
        capabilitySnapshotProvider.overrideWithValue(
          capabilities(runtime.active!.scope.scopeKey),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const FluentApp(home: EnvasesEnviarRoute()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('envases-enviar-loading')),
      findsNothing,
      reason: '90a37dc se queda para siempre en el ProgressRing',
    );
    expect(
      find.byKey(const Key('envases-enviar-catalog-error')),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
