// Auditoría de sesión (13-sep-2026) — el arreglo completo tiene dos mitades:
// la señal estructurada que detecta la clave rechazada (ver
// sync_coordinator_impl.dart y session_expiry_signal_test.dart en
// theos_panel) y ESTA garantía, que es la que de verdad protege el trabajo
// del operador: cerrar la sesión porque el servidor rechazó la clave
// (`NativeAuthService.closeExpired`) nunca debe borrar lo que ya había en el
// dispositivo.
//
// La prueba no monta `NativeAuthService` completo — eso exigiría todo el
// árbol de Riverpod/Odoo de theos_panel para algo que la garantía real vive
// un nivel más abajo, en `RuntimeDatabaseOwner`/`SessionRuntime.close()`:
// ese método SÓLO cierra la conexión Drift (`database.close()`), nunca borra
// el archivo — confirmado leyendo `runtime_database_owner.dart`. Esta prueba
// mide exactamente esa garantía contra un archivo SQLite real (no en
// memoria, que se perdería igual al cerrar): abre el MISMO scope dos veces,
// con un cierre real en medio, y comprueba que lo que se escribió antes
// sigue ahí después — tanto en la tabla de borradores editables
// (`orbi_editable_draft`, la que usa el editor de ventas) como en la cola
// offline real (`offline_queue`, de `theos_pos_core`, la que encola
// operaciones pendientes de sincronizar).
import 'dart:io';

// El test deliberadamente usa el executor real de Drift sobre un archivo,
// no en memoria: una base en memoria se pierde al cerrar la conexión, que es
// justo lo que este archivo existe para demostrar que NO pasa.
// ignore: depend_on_referenced_packages
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

AppScope _scope() => AppScope(
  appId: 'theos_panel',
  installationId: 'audit-install',
  normalizedServerUrl: 'https://erp2.tecnosmart.com.ec',
  database: 'erp2_tecnosmart_com_ec',
  userId: 9,
);

void main() {
  test(
    'cerrar la sesión por clave rechazada y volver a abrir el MISMO scope '
    'conserva el borrador editable que ya existía',
    () async {
      final dir = Directory.systemTemp.createTempSync(
        'orbi-session-expiry-draft-',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbFile = File('${dir.path}/orbi.sqlite');
      AppDatabase openFile(String _) => AppDatabase(NativeDatabase(dbFile));

      final owner = RuntimeDatabaseOwner(factory: openFile);
      final scope = _scope();

      final beforeExpiry = await owner.open(scope);
      await beforeExpiry.database.customStatement('''
        INSERT INTO orbi_editable_draft
          (scope_key, company_id, draft_id, payload, revision)
        VALUES ('scope-1', 1, 'draft-antes-de-caducar', '{"lines":[]}', 1)
      ''');

      // Exactamente lo que hace `NativeAuthService.closeExpired`:
      // `SessionRuntime.close()` → `RuntimeDatabaseOwner.close()`, que sólo
      // cierra la conexión — nunca borra el archivo.
      await owner.close();
      expect(owner.active, isNull);

      // Reingreso con el MISMO usuario en el MISMO servidor: mismo `AppScope`,
      // por lo tanto el mismo nombre de base
      // (`RuntimeDatabaseOwner.databaseNameFor`), por lo tanto el mismo
      // archivo físico.
      final afterReLogin = await owner.open(scope);
      final rows = await afterReLogin.database
          .customSelect(
            'SELECT draft_id, payload FROM orbi_editable_draft '
            "WHERE draft_id = 'draft-antes-de-caducar'",
          )
          .get();

      expect(
        rows,
        hasLength(1),
        reason:
            'el borrador escrito ANTES de que la clave caducara debe seguir '
            'ahí después de cerrar y volver a entrar con el mismo usuario '
            'en el mismo servidor — cerrar por expiración nunca borra la '
            'base local.',
      );
      expect(rows.single.data['payload'], '{"lines":[]}');

      await owner.close();
    },
  );

  test(
    'lo mismo, pero para la cola offline real (offline_queue de '
    'theos_pos_core): una operación encolada antes de caducar sigue '
    'pendiente después de reingresar',
    () async {
      final dir = Directory.systemTemp.createTempSync(
        'orbi-session-expiry-queue-',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      final dbFile = File('${dir.path}/orbi.sqlite');
      AppDatabase openFile(String _) => AppDatabase(NativeDatabase(dbFile));

      final owner = RuntimeDatabaseOwner(factory: openFile);
      final scope = _scope();

      final beforeExpiry = await owner.open(scope);
      // `offline_queue` es una tabla real del esquema compartido de
      // `theos_pos_core` (no una creada ad-hoc por este owner, a diferencia
      // de `orbi_editable_draft`) — ya existe apenas se abre la base, igual
      // que en producción.
      final columns = await beforeExpiry.database
          .customSelect("PRAGMA table_info('offline_queue')")
          .get();
      expect(
        columns,
        isNotEmpty,
        reason: 'offline_queue debe existir ya en el esquema compartido',
      );

      await beforeExpiry.database.customStatement('''
        INSERT INTO offline_queue
          (operation, model, "values", created_at, status, operation_key)
        VALUES (
          'write', 'sale.order', '{}', '2026-09-13T00:00:00.000Z', 'pending',
          'venta-pendiente-antes-de-caducar'
        )
      ''');

      await owner.close();
      final afterReLogin = await owner.open(scope);
      final rows = await afterReLogin.database
          .customSelect(
            "SELECT operation_key, status FROM offline_queue "
            "WHERE operation_key = 'venta-pendiente-antes-de-caducar'",
          )
          .get();

      expect(
        rows,
        hasLength(1),
        reason:
            'la operación que ya estaba encolada antes de caducar la clave '
            'debe seguir pendiente tras reingresar — cerrar por expiración '
            'nunca toca la cola offline.',
      );
      expect(rows.single.data['status'], 'pending');

      await owner.close();
    },
  );
}
