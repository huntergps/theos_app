import 'package:drift/drift.dart';
import 'package:theos_pos_core/theos_pos_core.dart' as core;

import '../session/session_runtime.dart';

final class RuntimeLocalOrderReader {
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
    if (query.authorFilter != null) {
      where.add('user_id = ?');
      variables.add(Variable<int>(query.authorFilter!));
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
      where.add('name LIKE ?');
      variables.add(Variable<String>('%${text.trim()}%'));
    }
    final predicate = where.join(' AND ');
    final rows = await active.database.database
        .customSelect(
          'SELECT id, name, state, user_id, company_id, invoice_status, '
          'payment_state, amount_unpaid, amount_to_invoice, has_queued_invoice, '
          'is_synced '
          'FROM sale_order WHERE $predicate ORDER BY date_order DESC, id DESC LIMIT $limit',
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

  /// Pulls the bounded remote page and commits only the canonical summary
  /// fields. Unsynced local work is never overwritten by this refresh.
  Future<void> refreshOnline(core.OrderQuery query, {int limit = 50}) async {
    final active = sessions.active;
    if (active == null || active.client == null) {
      throw StateError('online order refresh requires an active client');
    }
    final lease = active.lease;
    final rows = await active.client!.searchRead(
      model: 'sale.order',
      fields: const [
        'id',
        'name',
        'state',
        'user_id',
        'company_id',
        'invoice_status',
        'payment_state',
        'amount_unpaid',
        'amount_to_invoice',
        'has_queued_invoice',
      ],
      domain: [
        ['company_id', '=', query.companyId],
      ],
      limit: limit,
      order: 'date_order desc,id desc',
    );
    if (!sessions.accepts(lease)) throw StateError('order scope changed');
    await active.database.database.transaction(() async {
      for (final row in rows) {
        final id = row['id'];
        final company = _many2oneId(row['company_id']);
        final user = _many2oneId(row['user_id']);
        if (id is! int || id <= 0 || company != query.companyId) continue;
        await active.database.database.customStatement(
          'INSERT INTO sale_order '
          '(odoo_id,name,state,user_id,company_id,invoice_status,payment_state, '
          'amount_unpaid,amount_to_invoice,has_queued_invoice,is_synced) '
          'VALUES (?,?,?,?,?,?,?,?,?, ?,1) '
          'ON CONFLICT(odoo_id) DO UPDATE SET name=excluded.name, '
          'state=excluded.state, user_id=excluded.user_id, '
          'company_id=excluded.company_id, invoice_status=excluded.invoice_status, '
          'payment_state=excluded.payment_state, amount_unpaid=excluded.amount_unpaid, '
          'amount_to_invoice=excluded.amount_to_invoice, '
          'has_queued_invoice=excluded.has_queued_invoice '
          'WHERE sale_order.is_synced = 1',
          [
            id,
            row['name'] as String? ?? '$id',
            row['state'] as String? ?? 'draft',
            user,
            company,
            row['invoice_status'] as String? ?? 'no',
            row['payment_state'] as String?,
            (row['amount_unpaid'] as num?)?.toDouble() ?? 0,
            (row['amount_to_invoice'] as num?)?.toDouble() ?? 0,
            row['has_queued_invoice'] == true,
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
}
