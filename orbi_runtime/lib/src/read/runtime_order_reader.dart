import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' as core;

import 'json2_read_adapters.dart';
import '../session/session_runtime.dart';

final class RuntimeLocalOrderReader {
  static final Expando<Future<void>> _remoteContractProbes =
      Expando<Future<void>>('orbi_runtime_order_contract_probes');
  // Cached independently from the base probe above: it must only ever run
  // for a client whose session actually holds the `cashier` capability, and
  // a client that started without it must still probe it the first time a
  // caller later passes `canReadCollectionPayments: true`.
  static final Expando<Future<void>> _collectionPaymentContractProbes =
      Expando<Future<void>>('orbi_runtime_collection_payment_contract_probes');

  RuntimeLocalOrderReader(this.sessions);
  final SessionRuntime sessions;

  Future<({List<Map<String, dynamic>> rows, int count})> read(
    core.OrderQuery query, {
    int limit = 50,
  }) async {
    final active = sessions.active;
    if (active == null) throw StateError('order scope is inactive');
    final lease = active.lease;
    final where = <String>['company_id = ?'];
    final variables = <Variable<Object>>[Variable<int>(query.companyId)];
    if (query.authorFilter != null &&
        query.workQueue != core.OrderWorkQueue.cashierPending) {
      where.add('user_id = ?');
      variables.add(Variable<int>(query.authorFilter!));
    }
    if (query.dateFrom != null) {
      where.add('date_order >= ?');
      variables.add(Variable<String>(query.dateFrom!.toIso8601String()));
    }
    if (query.dateTo != null) {
      where.add('date_order <= ?');
      variables.add(Variable<String>(query.dateTo!.toIso8601String()));
    }
    if (query.afterId != null) {
      where.add('odoo_id < ?');
      variables.add(Variable<int>(query.afterId!));
    }
    if (query.workQueue == core.OrderWorkQueue.cashierPending) {
      where.add('state = ?');
      variables.add(Variable<String>(core.SaleOrderState.sale.code));
      where.add(
        "(COALESCE(amount_unpaid, 0) > 0 OR "
        "payment_state IN ('not_paid', 'partial', 'in_payment') OR "
        "COALESCE(amount_to_invoice, 0) > 0 OR has_queued_invoice = 1)",
      );
    }
    if (query.states.isNotEmpty) {
      where.add(
        'state IN (${List.filled(query.states.length, '?').join(',')})',
      );
      variables.addAll(
        query.states.map((state) => Variable<String>(state.code)),
      );
    }
    if (query.text case final text? when text.trim().isNotEmpty) {
      where.add('(name LIKE ? OR client_order_ref LIKE ?)');
      final needle = '%${text.trim()}%';
      variables.add(Variable<String>(needle));
      variables.add(Variable<String>(needle));
    }
    final predicate = where.join(' AND ');
    final rows = await active.database.database
        .customSelect(
          'SELECT id, name, client_order_ref, state, user_id, user_name, company_id, '
          'partner_name, amount_total, amount_untaxed, amount_tax, date_order, '
          'currency_symbol, currency_id, invoice_status, '
          'payment_state, amount_unpaid, amount_to_invoice, has_queued_invoice, '
          'picking_ids, '
          'is_synced '
          'FROM sale_order WHERE $predicate ORDER BY date_order DESC, odoo_id DESC LIMIT $limit',
          variables: variables,
        )
        .get();
    if (!sessions.accepts(lease)) throw StateError('order scope changed');
    final countRows = await active.database.database
        .customSelect(
          'SELECT COUNT(*) AS count FROM sale_order WHERE $predicate',
          variables: variables,
        )
        .get();
    if (!sessions.accepts(lease)) throw StateError('order scope changed');
    return (
      rows: rows.map((row) => row.data).toList(growable: false),
      count: (countRows.single.data['count'] as int?) ?? 0,
    );
  }

  /// Watches the same scoped local query used by [read]. No network refresh is
  /// started here; callers decide when remote synchronization is appropriate.
  /// A lease check is performed for every SQLite emission so an old scope
  /// cannot publish rows after activation changes.
  Stream<({List<Map<String, dynamic>> rows, int count})> watch(
    core.OrderQuery query, {
    int limit = 50,
  }) {
    final active = sessions.active;
    if (active == null) {
      return Stream.error(StateError('order scope is inactive'));
    }
    final lease = active.lease;
    final where = <String>['company_id = ?'];
    final variables = <Variable<Object>>[Variable<int>(query.companyId)];
    if (query.authorFilter != null &&
        query.workQueue != core.OrderWorkQueue.cashierPending) {
      where.add('user_id = ?');
      variables.add(Variable<int>(query.authorFilter!));
    }
    if (query.dateFrom != null) {
      where.add('date_order >= ?');
      variables.add(Variable<String>(query.dateFrom!.toIso8601String()));
    }
    if (query.dateTo != null) {
      where.add('date_order <= ?');
      variables.add(Variable<String>(query.dateTo!.toIso8601String()));
    }
    if (query.afterId != null) {
      where.add('odoo_id < ?');
      variables.add(Variable<int>(query.afterId!));
    }
    if (query.workQueue == core.OrderWorkQueue.cashierPending) {
      where.add('state = ?');
      variables.add(Variable<String>(core.SaleOrderState.sale.code));
      where.add(
        "(COALESCE(amount_unpaid, 0) > 0 OR "
        "payment_state IN ('not_paid', 'partial', 'in_payment') OR "
        "COALESCE(amount_to_invoice, 0) > 0 OR has_queued_invoice = 1)",
      );
    }
    if (query.states.isNotEmpty) {
      where.add(
        'state IN (${List.filled(query.states.length, '?').join(',')})',
      );
      variables.addAll(
        query.states.map((state) => Variable<String>(state.code)),
      );
    }
    if (query.text case final text? when text.trim().isNotEmpty) {
      where.add('(name LIKE ? OR client_order_ref LIKE ?)');
      final needle = '%${text.trim()}%';
      variables.add(Variable<String>(needle));
      variables.add(Variable<String>(needle));
    }
    final predicate = where.join(' AND ');
    final database = active.database.database;
    return database
        .customSelect(
          'SELECT id, name, client_order_ref, state, user_id, user_name, company_id, '
          'partner_name, amount_total, amount_untaxed, amount_tax, date_order, '
          'currency_symbol, currency_id, '
          'invoice_status, payment_state, amount_unpaid, amount_to_invoice, '
          'has_queued_invoice, picking_ids, is_synced '
          'FROM sale_order WHERE $predicate '
          'ORDER BY date_order DESC, odoo_id DESC LIMIT $limit',
          variables: variables,
          readsFrom: {database.saleOrder},
        )
        .watch()
        .asyncMap((result) async {
          if (!sessions.accepts(lease)) {
            throw StateError('order scope changed');
          }
          final countRows = await database
              .customSelect(
                'SELECT COUNT(*) AS count FROM sale_order WHERE $predicate',
                variables: variables,
              )
              .get();
          if (!sessions.accepts(lease)) {
            throw StateError('order scope changed');
          }
          return (
            rows: result.map((row) => row.data).toList(growable: false),
            count: (countRows.single.data['count'] as int?) ?? 0,
          );
        });
  }

  /// Pulls the remote query pages and commits only canonical summary fields.
  /// Unsynced local work is never overwritten by this refresh.
  Future<void> refreshOnline(
    core.OrderQuery query, {
    int limit = 50,
    // `l10n_ec_collection_box.sale.order.payment` is only readable by the
    // Cajero/Supervisor de Caja groups. Callers must pass the session's own
    // `cashier` capability here; the default is "no", never "try and see" —
    // Odoo already answers a plain seller's request with a 403, and this
    // reader must not ask for what the session cannot read.
    bool canReadCollectionPayments = false,
    // Sólo para pruebas: sustituye la lectura remota real (que exige un
    // `OdooClient` autenticado y hace una llamada JSON-2 de verdad) por un
    // `Json2ReadPort` de prueba, el mismo patrón que ya usan
    // `runtime_catalog_composition_test.dart` y `json2_read_adapters_test.dart`
    // para `Json2ReadPort`. Se salta las comprobaciones de contrato (no tienen
    // sentido contra un lector fabricado a mano) pero corre exactamente la
    // misma guarda y el mismo INSERT que la ruta real.
    Json2ReadPort? testReader,
  }) async {
    final active = sessions.active;
    if (active == null) throw StateError('order scope is inactive');
    final lease = active.lease;
    final List<Map<String, dynamic>> rows;
    if (testReader != null) {
      rows = await RuntimeOrderReader(testReader).read(
        _withLimit(query, limit),
        canReadCollectionPayments: canReadCollectionPayments,
      );
    } else {
      if (active.client == null) {
        throw StateError('online order refresh requires an active client');
      }
      final client = active.client!;
      final cachedProbe = _remoteContractProbes[client];
      if (cachedProbe != null) {
        await cachedProbe;
      } else {
        final probe = RuntimeOrderReader(OdooJson2ReadPort(client))
            .validateRemoteContract();
        _remoteContractProbes[client] = probe;
        try {
          await probe;
        } catch (_) {
          // A failed contract probe must not poison future retries.
          _remoteContractProbes[client] = null;
          rethrow;
        }
      }
      if (canReadCollectionPayments) {
        final cachedPaymentProbe = _collectionPaymentContractProbes[client];
        if (cachedPaymentProbe != null) {
          await cachedPaymentProbe;
        } else {
          final probe = RuntimeOrderReader(OdooJson2ReadPort(client))
              .validateCollectionPaymentContract();
          _collectionPaymentContractProbes[client] = probe;
          try {
            await probe;
          } catch (_) {
            _collectionPaymentContractProbes[client] = null;
            rethrow;
          }
        }
      }
      rows = await RuntimeOrderReader(OdooJson2ReadPort(client)).read(
        _withLimit(query, limit),
        canReadCollectionPayments: canReadCollectionPayments,
      );
    }
    if (!sessions.accepts(lease)) throw StateError('order scope changed');
    final db = active.database.database;
    await db.transaction(() async {
      // 🔴 Causa raíz de que un `refreshOnline` pudiera revertir en pantalla
      // una confirmación que el usuario ya hizo sin conexión: la única
      // guarda que había (`is_synced = 1`, más abajo) sólo protege el tramo
      // entre crear localmente y que `_persistCreate` conozca el id remoto —
      // nunca se toca al encolar `action_pos_confirm` sobre una orden que YA
      // estaba sincronizada (`DriftSaleCommandStore.commitAndEnqueueIfAbsent`,
      // sale_runtime_adapters.dart:56-58), así que esa orden seguía con
      // `is_synced=1` mientras la confirmación esperaba en la cola. Aquí se
      // añade la misma guarda que ya usan los catálogos
      // (`local_catalog_adapters.dart:_pendingRecordIds`): mirar
      // `offline_queue` por el id LOCAL de la fila antes de escribir, dentro
      // de la MISMA transacción para que no quede hueco entre comprobar y
      // escribir.
      final pendingLocalIds = await _pendingLocalOrderIds(db);
      for (final row in rows) {
        final id = row['id'];
        final company = _many2oneId(row['company_id']);
        final user = _many2oneId(row['user_id']);
        if (id is! int || id <= 0 || company != query.companyId) continue;
        if (pendingLocalIds.isNotEmpty) {
          final existing = await db
              .customSelect(
                'SELECT id FROM sale_order WHERE odoo_id = ?',
                variables: [Variable<int>(id)],
              )
              .getSingleOrNull();
          final localId = existing?.data['id'] as int?;
          if (localId != null && pendingLocalIds.contains(localId)) {
            // Operación sin resolver en `offline_queue` para esta fila: se
            // salta este ciclo, igual que un conflicto implícito. El próximo
            // refresco (cuando la operación termine o se descarte) sí escribe.
            continue;
          }
        }
        await db.customStatement(
          'INSERT INTO sale_order '
          '(odoo_id,name,client_order_ref,state,user_id,user_name,company_id,partner_id,partner_name, '
          'amount_total,amount_untaxed,amount_tax,date_order,currency_id,invoice_status,payment_state,'
          'amount_unpaid,amount_to_invoice,has_queued_invoice,picking_ids,is_synced) '
          'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,1) '
          'ON CONFLICT(odoo_id) DO UPDATE SET name=excluded.name, '
          'state=excluded.state, client_order_ref=excluded.client_order_ref, user_id=excluded.user_id, '
          'user_name=excluded.user_name, '
          'company_id=excluded.company_id, partner_id=excluded.partner_id, '
          'partner_name=excluded.partner_name, amount_total=excluded.amount_total, '
          'amount_untaxed=excluded.amount_untaxed, amount_tax=excluded.amount_tax, '
          'date_order=excluded.date_order, currency_id=excluded.currency_id, '
          'invoice_status=excluded.invoice_status, '
          'payment_state=excluded.payment_state, amount_unpaid=excluded.amount_unpaid, '
          'amount_to_invoice=excluded.amount_to_invoice, '
          // has_queued_invoice is @OdooLocalOnly: preserve the existing
          // offline queue marker when refreshing a known local order.
          'picking_ids=excluded.picking_ids '
          'WHERE sale_order.is_synced = 1',
          [
            id,
            row['name'] as String? ?? '$id',
            row['client_order_ref'] as String?,
            row['state'] as String? ?? 'draft',
            user,
            _many2oneName(row['user_id']),
            company,
            _many2oneId(row['partner_id']),
            _many2oneName(row['partner_id']),
            (row['amount_total'] as num?)?.toDouble(),
            // `amountUntaxed`/`amountTax` en la tabla Drift no son nullable
            // (`.withDefault(Constant(0.0))`, sale_order_table.dart:32-33):
            // una orden que Odoo aún no ha totalizado guarda 0.0 real, no
            // NULL. No se migra la columna — la fila se corrige sola en el
            // siguiente refresco en cuanto Odoo devuelva el importe real.
            (row['amount_untaxed'] as num?)?.toDouble() ?? 0,
            (row['amount_tax'] as num?)?.toDouble() ?? 0,
            row['date_order'],
            _many2oneId(row['currency_id']),
            row['invoice_status'] as String? ?? 'no',
            row['payment_state'] as String?,
            (row['amount_unpaid'] as num?)?.toDouble() ?? 0,
            (row['amount_to_invoice'] as num?)?.toDouble() ?? 0,
            row['has_queued_invoice'] == true,
            _many2manyJson(row['picking_ids']),
          ],
        );
      }
    });
  }

  /// Ids LOCALES (`sale_order.id`, no `odoo_id`) con una operación de
  /// `sale.order` en `offline_queue` que todavía no terminó ni se descartó.
  /// `DriftSaleCommandStore.commitAndEnqueueIfAbsent`
  /// (sale_runtime_adapters.dart) siempre encola con `record_id` = el id
  /// local, nunca el remoto — así identifica la fila la propia cola.
  static Future<Set<int>> _pendingLocalOrderIds(
    core.AppDatabase database,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT DISTINCT record_id FROM offline_queue '
          "WHERE model = ? AND status NOT IN ('completed', 'dead_letter') "
          'AND record_id IS NOT NULL',
          variables: [Variable<String>('sale.order')],
        )
        .get();
    return rows.map((row) => row.data['record_id']).whereType<int>().toSet();
  }

  static int? _many2oneId(Object? value) => switch (value) {
    int id => id,
    List<dynamic> pair when pair.isNotEmpty && pair.first is int =>
      pair.first as int,
    _ => null,
  };

  static String? _many2oneName(Object? value) => switch (value) {
    List<dynamic> pair when pair.length > 1 && pair[1] is String =>
      pair[1] as String,
    _ => null,
  };

  static String? _many2manyJson(Object? value) {
    if (value is! List) return null;
    final ids = value.whereType<int>().where((id) => id > 0).toList();
    return ids.isEmpty ? null : '[${ids.join(',')}]';
  }

  static core.OrderQuery _withLimit(core.OrderQuery query, int limit) {
    if (limit == query.limit) return query;
    return core.OrderQuery(
      companyId: query.companyId,
      authorFilter: query.authorFilter,
      text: query.text,
      states: query.states,
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
      limit: limit,
      afterId: query.afterId,
      workQueue: query.workQueue,
    );
  }
}
