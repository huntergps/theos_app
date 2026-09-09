import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' as core;

import 'json2_read_adapters.dart';
import '../session/session_runtime.dart';

final class RuntimeLocalOrderReader {
  static final Expando<Future<void>> _remoteContractProbes =
      Expando<Future<void>>('orbi_runtime_order_contract_probes');

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
          'SELECT id, name, client_order_ref, state, user_id, company_id, invoice_status, '
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

  /// Pulls the remote query pages and commits only canonical summary fields.
  /// Unsynced local work is never overwritten by this refresh.
  Future<void> refreshOnline(core.OrderQuery query, {int limit = 50}) async {
    final active = sessions.active;
    if (active == null || active.client == null) {
      throw StateError('online order refresh requires an active client');
    }
    final lease = active.lease;
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
    final effectiveQuery = _withLimit(query, limit);
    final rows = await RuntimeOrderReader(OdooJson2ReadPort(client))
        .read(effectiveQuery);
    if (!sessions.accepts(lease)) throw StateError('order scope changed');
    await active.database.database.transaction(() async {
      for (final row in rows) {
        final id = row['id'];
        final company = _many2oneId(row['company_id']);
        final user = _many2oneId(row['user_id']);
        if (id is! int || id <= 0 || company != query.companyId) continue;
        await active.database.database.customStatement(
          'INSERT INTO sale_order '
          '(odoo_id,name,client_order_ref,state,user_id,company_id,invoice_status,payment_state, '
          'amount_unpaid,amount_to_invoice,has_queued_invoice,picking_ids,is_synced) '
          'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,1) '
          'ON CONFLICT(odoo_id) DO UPDATE SET name=excluded.name, '
          'state=excluded.state, client_order_ref=excluded.client_order_ref, user_id=excluded.user_id, '
          'company_id=excluded.company_id, invoice_status=excluded.invoice_status, '
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
            company,
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

  static int? _many2oneId(Object? value) => switch (value) {
    int id => id,
    List<dynamic> pair when pair.isNotEmpty && pair.first is int =>
      pair.first as int,
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
