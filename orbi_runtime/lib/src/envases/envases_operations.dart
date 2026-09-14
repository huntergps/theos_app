/// Contrato entre las pantallas de envases y la escritura sin conexión.
///
/// Decisión E01 (`docs/orbi_panel/decisions/E01-envases-capa-sobre-odoo.md`): Orbi no
/// calcula ni valida existencias; cada operación se guarda en local, se encola y la
/// hace Odoo con sus asistentes (`l10n_ec.stock.envases.wizard.envio` /
/// `...wizard.recepcion`) o con `stock.picking.action_envases_dar_por_perdido`.
/// Si Odoo la rechaza al reenviarla (sin disponible, sede ajena), queda en la cola con
/// el mensaje de Odoo.
///
/// Idempotencia acordada con el lado Odoo (13-sep-2026): cada operación que el usuario
/// confirma lleva un `operacionUuid` NUEVO, y el MISMO en todos sus reintentos. Odoo lo
/// guarda en `envases_operacion_uuid`.
library;

/// Una línea de envío: producto y cantidad en la unidad del producto.
final class EnvasesEnvioLinea {
  const EnvasesEnvioLinea({required this.productId, required this.cantidad});

  final int productId;
  final double cantidad;
}

/// Enviar envases de una sede a otra. `origenId` y `destinoId` son `stock.warehouse`,
/// siempre de `res.users.envases_warehouse_ids` y distintos entre sí; Odoo lo vuelve a
/// comprobar.
final class EnvasesEnviarCommand {
  const EnvasesEnviarCommand({
    required this.operacionUuid,
    required this.origenId,
    required this.destinoId,
    required this.fechaSalida,
    required this.lineas,
  });

  final String operacionUuid;
  final int origenId;
  final int destinoId;
  final DateTime fechaSalida;
  final List<EnvasesEnvioLinea> lineas;
}

/// Lo recibido de una línea del traslado: `llegaron` incluye las dañadas; lo que no
/// llega queda pendiente en Odoo.
final class EnvasesRecepcionLinea {
  const EnvasesRecepcionLinea({
    required this.productId,
    required this.llegaron,
    required this.danadas,
  });

  final int productId;
  final double llegaron;
  final double danadas;
}

/// Recibir un traslado pendiente (`stock.picking` de `envases_por_recibir()`).
final class EnvasesRecibirCommand {
  const EnvasesRecibirCommand({
    required this.operacionUuid,
    required this.pickingId,
    required this.lineas,
  });

  final String operacionUuid;
  final int pickingId;
  final List<EnvasesRecepcionLinea> lineas;
}

/// Estado local de una operación encolada, para que la pantalla lo muestre sin inventar
/// cifras de Odoo.
enum EnvasesOperacionEstado { pendienteDeEnviar, enviada, rechazada, revisarAMano }

final class EnvasesOperacionLocal {
  const EnvasesOperacionLocal({
    required this.operacionUuid,
    required this.tipo,
    required this.estado,
    required this.creadaEn,
    this.mensajeOdoo,
    this.pickingId,
  });

  final String operacionUuid;

  /// `envio`, `recepcion` o `perdido`.
  final String tipo;
  final EnvasesOperacionEstado estado;
  final DateTime creadaEn;
  final String? mensajeOdoo;
  final int? pickingId;
}

/// Lo que las pantallas usan para operar. La implementación durable (Drift + cola
/// offline + dispatcher) vive aparte; las pantallas nunca llaman a Odoo directo.
abstract interface class EnvasesOperations {
  /// Guarda en local y encola el envío. Devuelve la operación local creada.
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command);

  /// Guarda en local y encola la recepción.
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command);

  /// Encola «dar por perdido» (solo con el permiso `envases_manage`).
  Future<EnvasesOperacionLocal> darPorPerdido({
    required String operacionUuid,
    required int pickingId,
  });

  /// Operaciones locales de la compañía activa, las más recientes primero.
  Stream<List<EnvasesOperacionLocal>> watchOperaciones();
}
