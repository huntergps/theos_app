import 'package:theos_pos_core/theos_pos_core.dart';

import '../session/session_runtime.dart';

enum WarehouseValidationState { completed, backorderRequired, rejected }

final class WarehouseValidationResult {
  const WarehouseValidationResult({
    required this.state,
    required this.message,
    this.action,
  });

  final WarehouseValidationState state;
  final String message;
  final Map<String, dynamic>? action;

  bool get accepted => state == WarehouseValidationState.completed;
}

/// Runtime-owned boundary for the warehouse mutation. Widgets never construct
/// an Odoo client or invoke `button_validate` themselves.
abstract interface class WarehouseOperationPort {
  Future<WarehouseValidationResult> validatePicking({required int pickingId});

  Future<WarehouseValidationResult> resolveBackorder({
    required WarehouseValidationResult pending,
    required bool confirm,
  });
}

final class RuntimeWarehouseOperationPort implements WarehouseOperationPort {
  const RuntimeWarehouseOperationPort({
    required this.runtime,
    required this.capabilities,
  });

  final SessionRuntime runtime;
  final CapabilitySnapshot capabilities;

  @override
  Future<WarehouseValidationResult> validatePicking({
    required int pickingId,
  }) async {
    if (pickingId <= 0) {
      return const WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'Picking inválido.',
      );
    }
    if (!capabilities.permissions.contains('warehouse')) {
      return const WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'Autoridad insuficiente para bodega.',
      );
    }
    final client = runtime.active?.client;
    if (client == null) {
      return const WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'Sesión Odoo no disponible.',
      );
    }
    try {
      final result = await client.call(
        model: 'stock.picking',
        method: 'button_validate',
        ids: [pickingId],
      );
      return await interpretWarehouseValidationResponse(
        result,
        readState: () => client.call(
          model: 'stock.picking',
          method: 'search_read',
          kwargs: {
            'domain': [
              ['id', '=', pickingId],
            ],
            'fields': ['id', 'state'],
            'limit': 1,
          },
        ),
      );
    } catch (error) {
      return WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'No se pudo validar la entrega: $error',
      );
    }
  }

  @override
  Future<WarehouseValidationResult> resolveBackorder({
    required WarehouseValidationResult pending,
    required bool confirm,
  }) async {
    if (!capabilities.permissions.contains('warehouse')) {
      return const WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'Autoridad insuficiente para bodega.',
      );
    }
    final action = pending.action;
    final wizardId = action?['res_id'];
    if (wizardId is! int || wizardId <= 0) {
      return const WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'El wizard de backorder no tiene un ID válido.',
      );
    }
    final client = runtime.active?.client;
    if (client == null) {
      return const WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'Sesión Odoo no disponible.',
      );
    }
    try {
      await client.call(
        model: 'stock.backorder.confirmation',
        method: confirm ? 'process' : 'process_cancel_backorder',
        ids: [wizardId],
        kwargs: {
          if (action?['context'] is Map)
            'context': Map<String, dynamic>.from(action!['context'] as Map),
        },
      );
      return WarehouseValidationResult(
        state: WarehouseValidationState.completed,
        message: confirm
            ? 'Backorder confirmado; entrega parcial validada.'
            : 'Backorder cancelado; entrega parcial validada.',
      );
    } catch (error) {
      return WarehouseValidationResult(
        state: WarehouseValidationState.rejected,
        message: 'No se pudo resolver el backorder: $error',
      );
    }
  }
}

/// Interprets the public `stock.picking.button_validate` result without
/// treating an acknowledgement or an unknown action as delivery completion.
/// Odoo's backorder wizard is the only action this boundary accepts.
Future<WarehouseValidationResult> interpretWarehouseValidationResponse(
  dynamic result, {
  required Future<dynamic> Function() readState,
}) async {
  if (result is Map<String, dynamic> &&
      result['res_model'] == 'stock.backorder.confirmation') {
    return WarehouseValidationResult(
      state: WarehouseValidationState.backorderRequired,
      message: 'El picking requiere confirmar el backorder.',
      action: result,
    );
  }
  if (result == false ||
      (result is Map<String, dynamic> &&
          (result['warning'] != null || result['error'] != null))) {
    return const WarehouseValidationResult(
      state: WarehouseValidationState.rejected,
      message: 'Odoo rechazó la validación de la entrega.',
    );
  }
  if (result != true) {
    return const WarehouseValidationResult(
      state: WarehouseValidationState.rejected,
      message: 'Resultado de validación de entrega no reconocido.',
    );
  }
  final rows = await readState();
  final state = rows is List && rows.isNotEmpty && rows.first is Map
      ? (rows.first as Map)['state']
      : null;
  if (state == 'done') {
    return const WarehouseValidationResult(
      state: WarehouseValidationState.completed,
      message: 'Entrega validada.',
    );
  }
  return WarehouseValidationResult(
    state: WarehouseValidationState.rejected,
    message: state == null
        ? 'No se pudo confirmar el estado final del picking.'
        : 'El picking quedó en estado $state; entrega no confirmada.',
  );
}
