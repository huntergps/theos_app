import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

/// Hueco 3 del encargo del 14-sep-2026: "última sincronización" por
/// catálogo vivía en `_lastSyncedThisSession`, un `Map` en memoria de
/// `RuntimeSyncDataPort` (`theos_panel/lib/features/sync/sync_data_screen.dart`)
/// — se perdía al reabrir la app, aunque el CURSOR de ese mismo catálogo sí
/// sobrevive en `sync_metadata` (`local_catalog_adapters.dart`). Esta prueba
/// comprueba la raíz: que `DriftCatalogStore` guarde la marca de tiempo en la
/// misma fila persistente, y que una instancia NUEVA del store —sin ningún
/// mapa en memoria de la anterior, tal como pasa al reabrir la app— la lea.
void main() {
  AppScope scope() => AppScope(
    appId: 'panel',
    installationId: 'i',
    normalizedServerUrl: 'https://erp.test',
    database: 'db',
    userId: 2,
  );

  test(
    'la marca de la última sincronización exitosa persiste en sync_metadata '
    'y la lee una instancia NUEVA del store (simula reabrir la app)',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      await owner.open(s);
      addTearDown(owner.close);

      final fixedNow = DateTime.utc(2026, 9, 14, 10, 30);
      final firstSessionStore = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'partner',
        writeRows: (_, _, _) async {},
        clock: () => fixedNow,
      );
      await firstSessionStore.commit(
        s,
        const CatalogBatch(records: [], cursor: 'c-1'),
      );

      // Instancia NUEVA, sin el `clock` inyectado y sin ningún estado en
      // memoria compartido con la anterior — exactamente lo que "reabrir la
      // app" produce de verdad.
      final reopenedStore = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'partner',
        writeRows: (_, _, _) async {},
      );
      final state = await reopenedStore.read(s);

      expect(state.lastSyncedAt, fixedNow);
    },
  );

  test(
    'un catálogo nunca sincronizado no tiene marca (para que la pantalla '
    'pueda mostrar "Nunca")',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      await owner.open(s);
      addTearDown(owner.close);

      final store = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'product',
        writeRows: (_, _, _) async {},
      );
      final state = await store.read(s);
      expect(state.lastSyncedAt, isNull);
    },
  );

  test(
    'un lote confirmado como "no soportado en este servidor" (records '
    'vacíos, cursor null) también marca la fecha — es la misma llamada a '
    'commit() que usa un catálogo con datos reales',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      await owner.open(s);
      addTearDown(owner.close);

      final fixedNow = DateTime.utc(2026, 9, 14, 11, 0);
      final store = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'tax',
        writeRows: (_, _, _) async {},
        clock: () => fixedNow,
      );
      await store.commit(
        s,
        const CatalogBatch(records: [], cursor: null),
      );

      final state = await store.read(s);
      expect(state.lastSyncedAt, fixedNow);
    },
  );

  test(
    'un fallo (recordError) NO borra la marca de la última sincronización '
    'exitosa previa',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final s = scope();
      await owner.open(s);
      addTearDown(owner.close);

      final fixedNow = DateTime.utc(2026, 9, 14, 9, 0);
      final store = DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'uom',
        writeRows: (_, _, _) async {},
        clock: () => fixedNow,
      );
      await store.commit(s, const CatalogBatch(records: [], cursor: 'c-1'));
      await store.recordError(s, StateError('backend caído'));

      final state = await store.read(s);
      expect(state.lastSyncedAt, fixedNow);
      expect(state.error, contains('backend caído'));
    },
  );
}
