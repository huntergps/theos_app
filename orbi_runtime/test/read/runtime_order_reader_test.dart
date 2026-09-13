import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// El mismo patrón de doble que ya usan `runtime_catalog_composition_test.dart`
/// y `json2_read_adapters_test.dart`: implementa `Json2ReadPort` directo, sin
/// pasar por un `OdooClient` real ni por HTTP. Siempre devuelve las mismas
/// filas, sin mirar el modelo pedido — las pruebas de aquí sólo fabrican
/// filas de `sale.order` sin `invoice_ids`, así que `RuntimeOrderRemoteState`
/// nunca pide `account.move` ni líneas de cobro.
final class _FakeOrderReadPort implements Json2ReadPort {
  _FakeOrderReadPort(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async => rows;
}

AppScope _scope() => AppScope(
  appId: 'test',
  installationId: 'installation',
  normalizedServerUrl: 'https://example.test',
  database: 'db',
  userId: 1,
);

void main() {
  test('reads real local summary fields and observes SQLite changes', () async {
    final file = File(
      '${Directory.systemTemp.path}/runtime-order-reader-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(file)),
    );
    final sessions = SessionRuntime(databaseOwner: owner);
    addTearDown(() async {
      await sessions.close();
      if (file.existsSync()) await file.delete();
    });
    final activation = await sessions.activate(
      AppScope(
        appId: 'test',
        installationId: 'installation',
        normalizedServerUrl: 'https://example.test',
        database: 'db',
        userId: 1,
      ),
    );
    final db = activation.database.database;
    await db
        .into(db.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: 10,
            name: 'SO10',
            companyId: const Value(1),
            userId: const Value(7),
            userName: const Value('Vendedor Conocido'),
            partnerName: const Value('Cliente real'),
            amountTotal: const Value(42.5),
            amountUntaxed: const Value(100),
            amountTax: const Value(15),
            dateOrder: Value(DateTime.utc(2026, 1, 2)),
            currencyId: const Value(2),
            currencySymbol: const Value('€'),
          ),
        );
    final reader = RuntimeLocalOrderReader(sessions);
    final query = OrderQuery(companyId: 1);
    final first = await reader.read(query);
    expect(first.rows.single['partner_name'], 'Cliente real');
    expect(first.rows.single['amount_total'], 42.5);
    expect(first.rows.single['currency_id'], 2);
    expect(first.rows.single['currency_symbol'], '€');
    // 🔴 Estos tres ya los calculó Odoo y ya viven en la tabla Drift; antes
    // el SELECT local ni los pedía, así que se perdían camino a la pantalla.
    expect(first.rows.single['user_name'], 'Vendedor Conocido');
    expect(first.rows.single['amount_untaxed'], 100);
    expect(first.rows.single['amount_tax'], 15);

    final events = StreamIterator(reader.watch(query));
    expect(await events.moveNext(), isTrue);
    await (db.update(db.saleOrder)..where((row) => row.odooId.equals(10)))
        .write(const SaleOrderCompanion(amountTotal: Value(50.0)));
    expect(await events.moveNext(), isTrue);
    expect(events.current.rows.single['amount_total'], 50.0);
    await events.cancel();
  });

  // 🔴 Causa raíz: la única guarda que había (`is_synced = 1`) no protege una
  // orden YA sincronizada que se confirma sin conexión —
  // `DriftSaleCommandStore.commitAndEnqueueIfAbsent`
  // (sale_runtime_adapters.dart:56-58) deja `is_synced` como estaba. La
  // guarda nueva mira `offline_queue` por el id LOCAL, dentro de la misma
  // transacción.
  test('refreshOnline no pisa una orden con action_pos_confirm pendiente en la cola, '
      'y sí la actualiza en cuanto la operación termina', () async {
    final file = File(
      '${Directory.systemTemp.path}/runtime-order-reader-guard-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(file)),
    );
    final sessions = SessionRuntime(databaseOwner: owner);
    addTearDown(() async {
      await sessions.close();
      if (file.existsSync()) await file.delete();
    });
    final activation = await sessions.activate(_scope());
    final db = activation.database.database;

    // Cotización ya sincronizada, confirmada sin conexión: `state='sale'`
    // local, `isSynced` todavía en verdadero (nadie lo cambia al confirmar).
    final localId = await db
        .into(db.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: 20,
            name: 'SO20',
            companyId: const Value(1),
            state: const Value('sale'),
            isSynced: const Value(true),
            amountTotal: const Value(0),
          ),
        );
    final queueId = await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'sale.order',
            method: const Value('action_pos_confirm'),
            recordId: Value(localId),
            values: '{}',
            createdAt: DateTime.now().toUtc(),
            // status y replayPolicy se quedan en sus valores por omisión:
            // 'pending' y 'manual_after_ambiguous' — exactamente lo que
            // encola `DriftSaleCommandStore.commitAndEnqueueIfAbsent`.
          ),
        );

    final reader = RuntimeLocalOrderReader(sessions);
    final query = OrderQuery(companyId: 1);

    // (a) El servidor todavía dice 'draft' (Odoo no ha visto el confirm) —
    // la fila local, con la confirmación pendiente en la cola, debe seguir
    // en 'sale'.
    await reader.refreshOnline(
      query,
      testReader: _FakeOrderReadPort([
        {
          'id': 20,
          'name': 'SO20',
          'state': 'draft',
          'company_id': 1,
          'amount_total': 0.0,
          'amount_untaxed': 0.0,
          'amount_tax': 0.0,
        },
      ]),
    );
    final stillPending = await reader.read(query);
    expect(stillPending.rows.single['state'], 'sale');

    // (b) La operación termina: ahora sí debe entrar el estado y los
    // importes del servidor.
    await (db.update(db.offlineQueue)..where((row) => row.id.equals(queueId)))
        .write(const OfflineQueueCompanion(status: Value('completed')));
    await reader.refreshOnline(
      query,
      testReader: _FakeOrderReadPort([
        {
          'id': 20,
          'name': 'SO20',
          'state': 'draft',
          'company_id': 1,
          'amount_total': 115.0,
          'amount_untaxed': 100.0,
          'amount_tax': 15.0,
        },
      ]),
    );
    final afterCompletion = await reader.read(query);
    expect(afterCompletion.rows.single['state'], 'draft');
    expect(afterCompletion.rows.single['amount_total'], 115.0);
  });

  test('refreshOnline guarda amount_untaxed y amount_tax para una orden sin operaciones pendientes', () async {
    final file = File(
      '${Directory.systemTemp.path}/runtime-order-reader-amounts-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(file)),
    );
    final sessions = SessionRuntime(databaseOwner: owner);
    addTearDown(() async {
      await sessions.close();
      if (file.existsSync()) await file.delete();
    });
    await sessions.activate(_scope());
    final reader = RuntimeLocalOrderReader(sessions);
    final query = OrderQuery(companyId: 1);

    await reader.refreshOnline(
      query,
      testReader: _FakeOrderReadPort([
        {
          'id': 30,
          'name': 'SO30',
          'state': 'sale',
          'company_id': 1,
          'amount_total': 115.0,
          'amount_untaxed': 100.0,
          'amount_tax': 15.0,
        },
      ]),
    );
    final result = await reader.read(query);
    expect(result.rows.single['amount_untaxed'], 100.0);
    expect(result.rows.single['amount_tax'], 15.0);
  });

  test('una operación manual_after_ambiguous sin resolver también protege la fila', () async {
    final file = File(
      '${Directory.systemTemp.path}/runtime-order-reader-ambiguous-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(file)),
    );
    final sessions = SessionRuntime(databaseOwner: owner);
    addTearDown(() async {
      await sessions.close();
      if (file.existsSync()) await file.delete();
    });
    final activation = await sessions.activate(_scope());
    final db = activation.database.database;
    final localId = await db
        .into(db.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: 40,
            name: 'SO40',
            companyId: const Value(1),
            state: const Value('sale'),
            isSynced: const Value(true),
            amountTotal: const Value(0),
          ),
        );
    await db
        .into(db.offlineQueue)
        .insert(
          OfflineQueueCompanion.insert(
            model: 'sale.order',
            method: const Value('action_pos_confirm'),
            recordId: Value(localId),
            values: '{}',
            createdAt: DateTime.now().toUtc(),
            // Una respuesta ambigua real deja la operación así: sin
            // resolver (no 'completed') y marcada para revisión manual.
            status: const Value('conflict'),
            replayPolicy: const Value('manual_after_ambiguous'),
          ),
        );

    final reader = RuntimeLocalOrderReader(sessions);
    final query = OrderQuery(companyId: 1);
    await reader.refreshOnline(
      query,
      testReader: _FakeOrderReadPort([
        {
          'id': 40,
          'name': 'SO40',
          'state': 'draft',
          'company_id': 1,
          'amount_total': 999.0,
          'amount_untaxed': 999.0,
          'amount_tax': 999.0,
        },
      ]),
    );
    final result = await reader.read(query);
    expect(result.rows.single['state'], 'sale');
    expect(result.rows.single['amount_total'], 0.0);
  });
}
