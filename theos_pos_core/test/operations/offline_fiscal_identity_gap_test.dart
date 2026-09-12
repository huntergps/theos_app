/// DEMOSTRACIÓN DE HUECOS — paridad fiscal offline (tarea `B01`).
///
/// Estas pruebas NO son de regresión: documentan y fijan el comportamiento
/// INSEGURO que hoy tiene la cola offline, para que una corrección posterior
/// las rompa a propósito. Cada `test` empieza por `GAP:` y su expectativa
/// describe lo que el sistema hace HOY, no lo que debería hacer.
///
/// Documento que las explica y propone la decisión:
/// `docs/orbi_panel/decisions/B01-identidad-fiscal-offline.md`.
///
/// Se usan la fuente de datos real (`OfflineQueueDataSource` sobre Drift en
/// memoria) y el procesador real (`OfflineQueueProcessor`), no dobles: un
/// hueco demostrado con mocks no prueba nada del código vivo.
library;

import 'package:drift/native.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late AppDatabase db;
  late OfflineQueueStore queue;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------
  // HUECO 1 — `operationKey` es identidad LOCAL, no identidad extremo a extremo
  // ---------------------------------------------------------------------

  test(
    'GAP: operationKey nunca viaja al servidor; solo colapsa el doble encolado local',
    () async {
      final first = await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.invoiceCreateWithPayments,
        values: {
          'sale_id': 41,
          'order_uuid': 'order-uuid-1',
          'offline_access_key': '0' * 49,
          'client_op_uuid': 'cmd-uuid-1',
        },
        parentOrderId: 41,
      );
      // Mismo comando, mismo pago, segundo encolado en el MISMO dispositivo.
      final second = await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.invoiceCreateWithPayments,
        values: {
          'sale_id': 41,
          'order_uuid': 'order-uuid-1',
          'offline_access_key': '0' * 49,
          'client_op_uuid': 'cmd-uuid-1',
        },
        parentOrderId: 41,
      );
      expect(
        second,
        first,
        reason: 'en el mismo dispositivo el índice único local sí colapsa',
      );

      final op = await queue.getOperationById(first);
      expect(op, isNotNull);
      expect(op!.operationKey, isNotNull);

      // Lo que de verdad importa: el identificador que deduplica NO forma parte
      // de la carga que se envía a Odoo. Solo lo que el productor haya puesto
      // DENTRO de `values` llega al servidor. Si un productor olvida el marcador,
      // el servidor no recibe identidad alguna y la cola no se entera.
      expect(op.values.containsKey('operation_key'), isFalse);
      expect(op.values.containsKey('_operation_key'), isFalse);
    },
  );

  test(
    'GAP: la deduplicación es por base local, no por operación; dos bases producen dos comandos',
    () async {
      final otherDb = AppDatabase(NativeDatabase.memory());
      final OfflineQueueStore otherQueue = OfflineQueueDataSource(otherDb);
      addTearDown(otherDb.close);

      Map<String, dynamic> payload() => {
        'sale_id': 41,
        'order_uuid': 'order-uuid-shared',
        'offline_access_key': '1' * 49,
        'client_op_uuid': 'cmd-uuid-shared',
      };

      await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.invoiceCreateWithPayments,
        values: payload(),
      );
      await otherQueue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.invoiceCreateWithPayments,
        values: payload(),
      );

      // Dos instalaciones con el MISMO `client_op_uuid` mantienen cada una su
      // propia fila pendiente. El índice único de `operation_key` es por base
      // SQLite; no hay exclusión entre dispositivos. La única defensa real está
      // en Odoo, y para `account.move.l10n_ec_pos_client_op_uuid` es una
      // búsqueda previa, no una restricción única de PostgreSQL.
      expect((await queue.getPendingOperations()).length, 1);
      expect((await otherQueue.getPendingOperations()).length, 1);
    },
  );

  // ---------------------------------------------------------------------
  // HUECO 2 — comandos sin marcador que igual se clasifican `retry_safe`
  // ---------------------------------------------------------------------

  test(
    'GAP: order_confirm queda retry_safe aunque no lleve ningún marcador de identidad',
    () async {
      final id = await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.orderConfirm,
        values: {'sale_id': 77},
        recordId: 77,
      );
      final op = await queue.getOperationById(id);

      // Todo el resto de comandos exige un marcador para ganarse `retry_safe`
      // (ver `_deriveReplayPolicy`). `order_confirm`, `session_open`,
      // `session_closing_control` y `session_close` lo obtienen sin condición.
      expect(op!.replayPolicy, OfflineReplayPolicy.retrySafe);
      // Y sin marcador tampoco hay clave de deduplicación local.
      expect(op.operationKey, isNull);
    },
  );

  test(
    'GAP: sin marcador no hay clave, así que dos encolados idénticos crean dos comandos',
    () async {
      final first = await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.orderConfirm,
        values: {'sale_id': 77},
        recordId: 77,
      );
      final second = await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.orderConfirm,
        values: {'sale_id': 77},
        recordId: 77,
      );
      expect(second, isNot(first));
      expect((await queue.getPendingOperations()).length, 2);
    },
  );

  // ---------------------------------------------------------------------
  // HUECO 3 — respuesta incierta: la protección depende SOLO de la etiqueta
  // ---------------------------------------------------------------------

  test(
    'GAP: tras una respuesta incierta, retry_safe reenvía el comando sin consultar nada',
    () async {
      final id = await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.orderConfirm,
        values: {'sale_id': 77},
        recordId: 77,
      );
      final stored = (await queue.getOperationById(id))!;
      expect(stored.replayPolicy, OfflineReplayPolicy.retrySafe);

      var handlerCalls = 0;
      final processor = OfflineQueueProcessor(
        queue: queue,
        handler: (op) async {
          handlerCalls++;
          return null; // éxito
        },
      );
      addTearDown(processor.shutdown);

      // Estado en el que deja la recuperación de arranque a una operación que
      // se estaba enviando cuando el proceso murió: el cliente NO sabe si Odoo
      // la aplicó (`database.dart`: processing → recovery_pending).
      await processor.processQueue(
        operations: [
          stored.copyWith(status: OfflineOperationStatus.recoveryPending),
        ],
      );

      // El procesador la reenvía tal cual. No existe paso de consulta previa:
      // la única garantía es que el handler concreto "busque antes de crear".
      expect(handlerCalls, 1);
    },
  );

  test(
    'manual_after_ambiguous sí detiene el reenvío tras una respuesta incierta',
    () async {
      // Contraparte sana del caso anterior: es la política por defecto y la que
      // protege los documentos financieros. Se fija aquí para que una futura
      // reclasificación de comandos no la debilite sin que nadie lo note.
      final id = await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.paymentWizardApply,
        values: {'sale_id': 77},
        recordId: 77,
      );
      final stored = (await queue.getOperationById(id))!;
      expect(stored.replayPolicy, OfflineReplayPolicy.manualAfterAmbiguous);

      var handlerCalls = 0;
      final processor = OfflineQueueProcessor(
        queue: queue,
        handler: (op) async {
          handlerCalls++;
          return null;
        },
      );
      addTearDown(processor.shutdown);

      final result = await processor.processQueue(
        operations: [
          stored.copyWith(status: OfflineOperationStatus.recoveryPending),
        ],
      );

      expect(handlerCalls, 0);
      expect(result.failed, 1);
      final after = await queue.getOperationById(id);
      expect(after!.status, OfflineOperationStatus.deadLetter);
    },
  );

  // ---------------------------------------------------------------------
  // HUECO 4 — el secuencial fiscal se deriva de datos locales borrables
  // ---------------------------------------------------------------------

  test(
    'GAP: last_invoice_sequence es una columna solo local; nada la siembra desde Odoo',
    () async {
      // `AccountJournal.lastInvoiceSequence` no tiene contraparte en el backend
      // (`grep last_invoice_sequence` en el checkout de Odoo 20 no devuelve
      // nada) y `SalesRepository._getNextInvoiceSequence` calcula el siguiente
      // secuencial como max(esa columna, máximo local) + 1. Si la base local se
      // recrea — la estrategia de migración borra y recrea tablas — el contador
      // vuelve al valor por defecto y el secuencial fiscal reinicia.
      final journal = await db.into(db.accountJournal).insertReturning(
        AccountJournalCompanion.insert(
          odooId: 5,
          name: 'Ventas POS',
          code: 'POS',
          type: 'sale',
        ),
      );
      expect(
        journal.lastInvoiceSequence,
        0,
        reason: 'un diario recién sincronizado no trae el último secuencial '
            'emitido; el contador nace en cero',
      );
    },
  );
}
