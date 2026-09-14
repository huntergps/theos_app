import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:drift/native.dart';

import 'package:theos_panel/app/envases_composition.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/envases/envases_existencias_contracts.dart';

void main() {
  AppScope scope() => AppScope(
    appId: 'orbi',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 1,
  );
  Map<String, dynamic> datos() => {
    'columnas': [
      {'id': 'sede-1', 'nombre': 'Sede 1', 'location_id': 8, 'tipo': 'sede'},
    ],
    'filas': [
      {
        'id': 10,
        'nombre': 'Jaba',
        'uom': 'Unidad',
        'celdas': {'sede-1': 2.0},
        'total': 2.0,
      },
    ],
    'totales_columna': {'sede-1': 2.0},
    'total_general': 2.0,
    'pendientes': 0,
  };

  test('missing permission produces no repository', () {
    final container = ProviderContainer(
      overrides: [
        runtimeSessionProvider.overrideWithValue(null),
        capabilitySnapshotProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(envasesExistenciasRepositoryProvider), isNull);
  });

  test(
    'repository reads the cached snapshot and rejects a reader for another company',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      final db = await owner.open(s);
      addTearDown(owner.close);
      final company = CompanyContext.forScope(
        scope: s,
        companyId: 4,
        allowedCompanyIds: [4],
        capabilityRevision: 1,
      );
      final cache = EnvasesExistenciasCache(
        owner: owner,
        lease: db.lease,
        company: company,
      );
      final reader = EnvasesExistenciasReader(
        company: company,
        transport: ({
          required model,
          required method,
          required kwargs,
          required context,
        }) async => datos(),
      );
      await cache.refresh(reader);
      final repository = RuntimeEnvasesExistenciasRepository(
        cache: cache,
        readerFactory: () => reader,
      );
      final seen = repository.watch().first;
      expect((await seen)!.data.filas.single.nombre, 'Jaba');

      final wrongCompany = CompanyContext.forScope(
        scope: s,
        companyId: 5,
        allowedCompanyIds: [5],
        capabilityRevision: 1,
      );
      final mismatched = RuntimeEnvasesExistenciasRepository(
        cache: cache,
        readerFactory: () => EnvasesExistenciasReader(
          company: wrongCompany,
          transport: ({
            required model,
            required method,
            required kwargs,
            required context,
          }) async => datos(),
        ),
      );
      expect(mismatched.refresh(), throwsArgumentError);
    },
  );

  test(
    'readerFactory raises an explicit error offline instead of a silent null reader',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      final db = await owner.open(s);
      addTearDown(owner.close);
      final company = CompanyContext.forScope(
        scope: s,
        companyId: 4,
        allowedCompanyIds: [4],
        capabilityRevision: 1,
      );
      final repository = RuntimeEnvasesExistenciasRepository(
        cache: EnvasesExistenciasCache(
          owner: owner,
          lease: db.lease,
          company: company,
        ),
        readerFactory: () => throw StateError(
          'No hay conexión activa para actualizar existencias de envases',
        ),
      );
      expect(() => repository.refresh(), throwsStateError);
    },
  );

  group('envasesCanManageProvider', () {
    CapabilitySnapshot snapshot(List<String> permissions) => CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime.utc(2026, 9, 13),
      permissions: permissions,
    );

    test('true only with envases_manage', () {
      final container = ProviderContainer(
        overrides: [
          capabilitySnapshotProvider.overrideWithValue(
            snapshot(const ['envases_read', 'envases_manage']),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesCanManageProvider), isTrue);
    });

    test('false with only envases_read', () {
      final container = ProviderContainer(
        overrides: [
          capabilitySnapshotProvider.overrideWithValue(
            snapshot(const ['envases_read']),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesCanManageProvider), isFalse);
    });

    test('false without any capabilities snapshot yet', () {
      final container = ProviderContainer(
        overrides: [capabilitySnapshotProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesCanManageProvider), isFalse);
    });
  });

  group('envasesOperationsProvider', () {
    test('missing permission produces no port', () {
      final container = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(null),
          capabilitySnapshotProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesOperationsProvider), isNull);
    });

    test(
      'enviar() still saves locally and queues without a client — decision '
      'E01 "todo debe funcionar offline"',
      () async {
        final owner = RuntimeDatabaseOwner(
          factory: (_) => AppDatabase(NativeDatabase.memory()),
        );
        final s = scope();
        final db = await owner.open(s);
        addTearDown(owner.close);
        final company = CompanyContext.forScope(
          scope: s,
          companyId: 4,
          allowedCompanyIds: [4],
          capabilityRevision: 1,
        );
        final operations = DurableEnvasesOperations(
          owner: owner,
          lease: db.lease,
          company: company,
          actions: const _AlwaysFailingActions(),
        );
        final resultado = await operations.enviar(
          EnvasesEnviarCommand(
            operacionUuid: 'uuid-offline-1',
            origenId: 1,
            destinoId: 2,
            fechaSalida: DateTime.utc(2026, 9, 13),
            lineas: const [EnvasesEnvioLinea(productId: 10, cantidad: 5)],
          ),
        );
        expect(resultado.estado, EnvasesOperacionEstado.pendienteDeEnviar);
      },
    );
  });

  group('per-screen controller providers require envases_read', () {
    test('por recibir', () {
      final container = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(null),
          capabilitySnapshotProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesPorRecibirControllerProvider), isNull);
    });

    test('movimientos', () {
      final container = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(null),
          capabilitySnapshotProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesMovimientosControllerProvider), isNull);
    });

    test('sedes', () {
      final container = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(null),
          capabilitySnapshotProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesSedesControllerProvider), isNull);
    });

    test('productos', () {
      final container = ProviderContainer(
        overrides: [
          runtimeSessionProvider.overrideWithValue(null),
          capabilitySnapshotProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(envasesProductosControllerProvider), isNull);
    });
  });
}

final class _AlwaysFailingActions implements SaleOdooActions {
  const _AlwaysFailingActions();

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => Future.error(StateError('sin conexión'));
}
