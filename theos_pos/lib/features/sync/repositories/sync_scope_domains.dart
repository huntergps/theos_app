/// Canonical remote domains for caches that intentionally keep only a subset
/// of an Odoo model.
library;

const saleOrderLiveStates = ['draft', 'sent', 'sale'];

String _odooDate(DateTime value) {
  final date = value.toLocal();
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Orders remain cached while they are actionable or less than 90 days old.
List<dynamic> saleOrderSyncScope(DateTime now) => [
  '|',
  ['state', 'in', saleOrderLiveStates],
  ['date_order', '>=', _odooDate(now.subtract(const Duration(days: 90)))],
];

/// Only posted advances with a remaining usable balance belong in the cache.
List<dynamic> advanceSyncScope() => [
  ['state', '=', 'posted'],
  ['amount_available', '>', 0],
];

/// Closed card batches are historical server data and are not kept locally.
List<dynamic> cardLoteSyncScope() => [
  ['state', '=', 'open'],
];

/// Returns the canonical cache scope for models whose membership can change
/// without an unlink or an `active = false` transition.
List<dynamic>? scopedSyncDomainForModel(String model, DateTime now) {
  return switch (model) {
    'sale.order' => saleOrderSyncScope(now),
    'account.advance' => advanceSyncScope(),
    'account.card.lote' => cardLoteSyncScope(),
    _ => null,
  };
}
