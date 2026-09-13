/// Contratos de datos reales para los indicadores de Inicio.
///
/// Cada lector habla contra la base local (Drift) del scope activo — el
/// mismo patrón que ya usan `u08_scope_adapters.dart` y
/// `collection_scope_composition.dart` — para que un indicador nunca se
/// rellene con un cero fabricado cuando en realidad no hay de dónde leerlo.
library;

class HomeSalesSummary {
  const HomeSalesSummary({
    this.totalAmount = 0,
    this.totalOrders = 0,
    this.draftCount = 0,
    this.confirmedCount = 0,
    this.doneCount = 0,
  });

  final double totalAmount;
  final int totalOrders;
  final int draftCount;
  final int confirmedCount;
  final int doneCount;
}

/// Ventas del día en curso, agrupadas por estado. `viewAll` decide si se
/// cuenta la empresa completa (supervisor) o sólo lo propio (vendedor raso) —
/// la misma distinción que ya aplica `OrderFilterPolicy`.
abstract interface class HomeSalesMetricsReader {
  Future<HomeSalesSummary> loadToday({
    required int companyId,
    required int userId,
    required bool viewAll,
  });
}

class HomeCashSession {
  const HomeCashSession({
    required this.id,
    required this.name,
    required this.cashierUserId,
    required this.stateCode,
    this.configName,
    this.cashierName,
    this.startAt,
    this.paymentCount = 0,
    this.totalPaymentsAmount = 0,
  });

  final String id;
  final String name;
  final String? configName;
  final int cashierUserId;
  final String? cashierName;
  final DateTime? startAt;

  /// Código crudo de `collection.session.state` ('opened', 'paused', ...).
  final String stateCode;
  final int paymentCount;
  final double totalPaymentsAmount;
}

/// Sesiones de caja no cerradas visibles para la empresa activa. Es «el
/// lector de pagos»: un vendedor sin capacidad `cashier` nunca debe hacer que
/// se invoque.
abstract interface class HomeCashSessionsReader {
  Future<List<HomeCashSession>> loadActive({required int companyId});
}

// Nota (2026-09-13): no hay un indicador de bodega todavía. `sale_order.state
// = 'sale'` con `picking_ids` no vacío es un proxy que nunca deja de contar
// un pedido ya entregado — `sale_order.delivery_status` (que sí distinguiría
// pending/started/partial/full) no forma parte de los campos que
// `orbi_runtime/lib/src/read/runtime_order_reader.dart` sincroniza a local, y
// tampoco existe una tabla local de `stock.picking`. Sin uno de esos dos
// datos sincronizados, el indicador se omite en vez de mostrar un proxy que
// crece para siempre.
