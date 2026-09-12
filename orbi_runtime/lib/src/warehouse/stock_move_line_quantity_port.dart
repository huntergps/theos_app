import 'package:theos_pos_core/theos_pos_core.dart';

import '../session/session_runtime.dart';

enum StockMoveLineWriteState { confirmed, rejected }

/// Result of writing one `stock.move.line`'s counted quantity. Deliberately
/// shaped like `WarehouseValidationResult` in `warehouse_operation_port.dart`
/// — including the rule that made that file correct: [confirmedQuantity] and
/// [confirmedPicked] come from re-reading the line after the write, never
/// from echoing back what the caller asked for. A `write` RPC returning
/// `true` only means Odoo accepted the request; it is not proof of what the
/// line now holds.
final class StockMoveLineQuantityResult {
  const StockMoveLineQuantityResult({
    required this.state,
    required this.message,
    this.confirmedQuantity,
    this.confirmedPicked,
  });

  final StockMoveLineWriteState state;
  final String message;
  final double? confirmedQuantity;
  final bool? confirmedPicked;

  bool get accepted => state == StockMoveLineWriteState.confirmed;
}

/// Runtime-owned boundary for editing a picking's counted quantity line by
/// line — the BOD-03 transport gap the CAJA/BODEGA study calls out ("hoy
/// solo se valida con las cantidades que YA trae el picking"). Widgets never
/// write to `stock.move.line` directly.
///
/// Both written fields were verified against the Odoo 20 source at
/// `/Users/elmers/Documents/dev_odoo20`:
/// - `quantity` (`Float`, `store=True`, `readonly=False` despite being a
///   compute — Odoo's "editable compute" pattern, writable through its
///   inverse) — `odoo/addons/stock/models/stock_move_line.py:37-40`.
/// - `picked` (`Boolean`, `store=True`, `readonly=False`,
///   `@api.depends('state')` only forces it `True` once the move is
///   `'done'` — writing it beforehand to mark a partial count is exactly
///   the pattern the field supports, not a misuse of it) —
///   same file, `:43` and `:120-125`.
/// - ACL: `access_stock_move_line_all` grants `base.group_user` `crud` —
///   `odoo/addons/stock/security/ir.access.csv:43`.
///
/// After the picking's lines are edited, completion still goes through
/// `WarehouseOperationPort.validatePicking`/`resolveBackorder` in this same
/// directory — that boundary already re-reads `stock.picking.state` instead
/// of trusting `button_validate`'s return value, so it is reused as-is here
/// rather than duplicated.
abstract interface class StockMoveLineQuantityPort {
  Future<StockMoveLineQuantityResult> setQuantity({
    required int lineId,
    required double quantity,
    bool? picked,
  });
}

final class RuntimeStockMoveLineQuantityPort
    implements StockMoveLineQuantityPort {
  const RuntimeStockMoveLineQuantityPort({
    required this.runtime,
    required this.capabilities,
  });

  final SessionRuntime runtime;
  final CapabilitySnapshot capabilities;

  static const _model = 'stock.move.line';

  @override
  Future<StockMoveLineQuantityResult> setQuantity({
    required int lineId,
    required double quantity,
    bool? picked,
  }) async {
    if (lineId <= 0) {
      return const StockMoveLineQuantityResult(
        state: StockMoveLineWriteState.rejected,
        message: 'Línea de movimiento inválida.',
      );
    }
    if (!quantity.isFinite || quantity < 0) {
      return const StockMoveLineQuantityResult(
        state: StockMoveLineWriteState.rejected,
        message: 'Cantidad inválida.',
      );
    }
    if (!capabilities.permissions.contains('warehouse')) {
      return const StockMoveLineQuantityResult(
        state: StockMoveLineWriteState.rejected,
        message: 'Autoridad insuficiente para bodega.',
      );
    }
    final client = runtime.active?.client;
    if (client == null) {
      return const StockMoveLineQuantityResult(
        state: StockMoveLineWriteState.rejected,
        message: 'Sesión Odoo no disponible.',
      );
    }
    try {
      final written = await client.call(
        model: _model,
        method: 'write',
        ids: [lineId],
        kwargs: {
          'vals': {'quantity': quantity, 'picked': ?picked},
        },
      );
      return await interpretStockMoveLineWriteResponse(
        written,
        readState: () => client.call(
          model: _model,
          method: 'search_read',
          kwargs: {
            'domain': [
              ['id', '=', lineId],
            ],
            'fields': ['id', 'quantity', 'picked'],
            'limit': 1,
          },
        ),
      );
    } catch (error) {
      return StockMoveLineQuantityResult(
        state: StockMoveLineWriteState.rejected,
        message: 'No se pudo editar la línea: $error',
      );
    }
  }
}

/// Interprets `stock.move.line.write`'s result without ever treating the
/// boolean acknowledgement as proof of the persisted value — the exact bug
/// class found in the envases assistant, where a validation RPC's return was
/// trusted instead of the document's real, re-read state.
Future<StockMoveLineQuantityResult> interpretStockMoveLineWriteResponse(
  dynamic writeResult, {
  required Future<dynamic> Function() readState,
}) async {
  if (writeResult != true) {
    return const StockMoveLineQuantityResult(
      state: StockMoveLineWriteState.rejected,
      message: 'Odoo rechazó la edición de la línea.',
    );
  }
  final rows = await readState();
  if (rows is! List || rows.isEmpty || rows.first is! Map) {
    return const StockMoveLineQuantityResult(
      state: StockMoveLineWriteState.rejected,
      message: 'No se pudo confirmar la línea tras escribirla.',
    );
  }
  final confirmed = rows.first as Map;
  final confirmedQuantity = confirmed['quantity'];
  final confirmedPicked = confirmed['picked'];
  if (confirmedQuantity is! num) {
    return const StockMoveLineQuantityResult(
      state: StockMoveLineWriteState.rejected,
      message: 'La línea confirmada no trae una cantidad válida.',
    );
  }
  return StockMoveLineQuantityResult(
    state: StockMoveLineWriteState.confirmed,
    message: 'Línea actualizada.',
    confirmedQuantity: confirmedQuantity.toDouble(),
    confirmedPicked: confirmedPicked == true,
  );
}
