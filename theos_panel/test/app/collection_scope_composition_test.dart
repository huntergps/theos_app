import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/collection_scope_composition.dart';
import 'package:theos_panel/app/notification_scope_adapter.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/collection/collection_contracts.dart'
    show CollectionShiftState;
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSessionCompanion;

/// Encargo del dueño: un supervisor de caja (`collection_supervisor` ⇐
/// `l10n_ec_collection_box.group_collection_manager`, "Supervisor de Caja",
/// `l10n_ec_collection_box/security/collection_box_groups.xml:96-101`) puede
/// abrir el turno de CUALQUIER cajero de su empresa; un cajero raso, sólo el
/// suyo. `scopeCollectionSessionByIdFutureProvider` es el lector por id —
/// estas pruebas comprueban que la compuerta real vive AHÍ (no sólo en si
/// Inicio dibujó la fila tocable) y que nunca depende de una llamada RPC.
AppScope _scope({int userId = 9}) => AppScope(
  appId: 'orbi-panel',
  installationId: 'provider-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'erp',
  userId: userId,
);

CapabilitySnapshot _capabilities(
  AppScope scope, {
  Set<String> permissions = const {},
}) => CapabilitySnapshot(
  scopeKey: scope.scopeKey,
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 13),
  permissions: permissions,
);

AuthProfile _profile(AppScope scope, {String login = 'usuario'}) =>
    AuthProfile(
      serverUrl: scope.normalizedServerUrl,
      database: scope.database,
      login: login,
      userId: scope.userId,
      installationId: scope.installationId,
      credentialReference: 'ref-1',
    );

RuntimeDatabaseOwner _owner(File file) =>
    RuntimeDatabaseOwner(factory: (_) => AppDatabase(NativeDatabase(file)));

ProviderContainer _container({
  required SessionRuntime runtime,
  required CapabilitySnapshot? capabilities,
  required AuthProfile? profile,
}) => ProviderContainer(
  overrides: [
    runtimeSessionProvider.overrideWithValue(runtime),
    capabilitySnapshotProvider.overrideWithValue(capabilities),
    authInitialStateProvider.overrideWithValue(AuthViewState(profile: profile)),
  ],
);

void main() {
  group('canOpenCollectionSessionById (compuerta pura)', () {
    test('el dueño del turno siempre puede, sin permiso alguno', () {
      expect(
        canOpenCollectionSessionById(
          ownerUserId: 9,
          viewerUserId: 9,
          permissions: const {},
        ),
        isTrue,
      );
    });

    test('un supervisor puede abrir el turno de otro cajero', () {
      expect(
        canOpenCollectionSessionById(
          ownerUserId: 42,
          viewerUserId: 9,
          permissions: const {'collection_supervisor'},
        ),
        isTrue,
      );
    });

    test('un cajero sin el permiso de supervisor NO puede abrir un turno ajeno', () {
      expect(
        canOpenCollectionSessionById(
          ownerUserId: 42,
          viewerUserId: 9,
          permissions: const {'cashier'},
        ),
        isFalse,
      );
      expect(
        canOpenCollectionSessionById(
          ownerUserId: 42,
          viewerUserId: 9,
          permissions: const {},
        ),
        isFalse,
      );
    });
  });

  group('scopeCollectionSessionByIdFutureProvider', () {
    late Directory directory;
    late File file;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'orbi-collection-by-id-',
      );
      file = File('${directory.path}/runtime.sqlite');
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    Future<SessionRuntime> seedRuntime(AppScope scope) async {
      final owner = _owner(file);
      final runtime = SessionRuntime(databaseOwner: owner);
      final activation = await runtime.activate(scope);
      // Ninguna prueba de este grupo pasa un `OdooClient`: la lectura por id
      // es local por construcción, así que un `403` de pagos ("un 403 es un
      // defecto") es estructuralmente imposible aquí, nunca sólo evitado en
      // tiempo de ejecución.
      expect(
        activation.client,
        isNull,
        reason:
            'SessionActivation.activate() sin apiKey no crea OdooClient; '
            'esta prueba depende de que la lectura por id nunca necesite uno.',
      );
      await activation.database.database
          .into(activation.database.database.collectionSession)
          .insert(
            CollectionSessionCompanion.insert(
              odooId: 11,
              sessionUuid: 'uuid-11',
              name: 'CS/006/2026/0011',
              configId: 6,
              configName: const Value('006 SUCURSAL NORTE'),
              companyId: 1,
              userId: 42,
              userName: const Value('Erik Aldas'),
              currencyId: 1,
              startAt: DateTime.utc(2026, 9, 12, 8),
              state: const Value('opened'),
              orderCount: const Value(4),
              invoiceCount: const Value(3),
              paymentCount: const Value(2),
            ),
          );
      return runtime;
    }

    test(
      'un supervisor lee el turno de OTRO cajero, con SUS datos (no los '
      'del supervisor)',
      () async {
        final scope = _scope(userId: 9);
        final runtime = await seedRuntime(scope);
        final container = _container(
          runtime: runtime,
          capabilities: _capabilities(
            scope,
            permissions: const {'cashier', 'collection_supervisor'},
          ),
          profile: _profile(scope, login: 'supervisor1'),
        );
        addTearDown(container.dispose);

        final view = await container.read(
          scopeCollectionSessionByIdFutureProvider(11).future,
        );

        expect(view.ownerUserId, 42);
        expect(view.point.pointLabel, '006 SUCURSAL NORTE');
        expect(view.point.cashierLabel, 'Erik Aldas');
        expect(view.shift.id, '11');
        expect(view.shift.state, CollectionShiftState.opened);
        expect(
          view.rawState,
          'opened',
          reason:
              'la compuerta de supervisión (pausar/reanudar) necesita el '
              'estado crudo: CollectionShiftState.opened confunde "opened" '
              'con "paused"',
        );
        expect(view.counts.orderCount, 4);
        expect(view.counts.invoiceCount, 3);
        expect(view.counts.paymentCount, 2);
      },
    );

    test(
      'el dueño del turno lo lee sin necesitar el permiso de supervisor',
      () async {
        final scope = _scope(userId: 42);
        final runtime = await seedRuntime(scope);
        final container = _container(
          runtime: runtime,
          capabilities: _capabilities(
            scope,
            permissions: const {'cashier'},
          ),
          profile: _profile(scope, login: 'erik.aldas'),
        );
        addTearDown(container.dispose);

        final view = await container.read(
          scopeCollectionSessionByIdFutureProvider(11).future,
        );

        expect(view.ownerUserId, 42);
      },
    );

    test(
      'un cajero SIN permiso de supervisor no puede leer el turno ajeno: '
      'la compuerta real vive en el lector, no sólo en la fila de Inicio',
      () async {
        final scope = _scope(userId: 9);
        final runtime = await seedRuntime(scope);
        final container = _container(
          runtime: runtime,
          capabilities: _capabilities(scope, permissions: const {'cashier'}),
          profile: _profile(scope, login: 'cajero1'),
        );
        addTearDown(container.dispose);

        await expectLater(
          container.read(scopeCollectionSessionByIdFutureProvider(11).future),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('un turno que no está en el catálogo local no se inventa', () async {
      final scope = _scope(userId: 9);
      final runtime = await seedRuntime(scope);
      final container = _container(
        runtime: runtime,
        capabilities: _capabilities(
          scope,
          permissions: const {'cashier', 'collection_supervisor'},
        ),
        profile: _profile(scope, login: 'supervisor1'),
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(
          scopeCollectionSessionByIdFutureProvider(999999).future,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
