import 'package:odoo_sdk/odoo_sdk.dart' show OfflineReplayPolicy;
import 'package:theos_pos_core/theos_pos_core.dart';

/// Durable local command contract for a credit-approval request.
///
/// This is deliberately not an Odoo method name. The offline dispatcher
/// replays the complete JSON-2 wizard workflow and first reconciles an
/// existing pending request by sale order, making retries idempotent after an
/// indeterminate network response.
abstract final class CreditApprovalOfflineContract {
  static const String aggregateModel = 'sale.order';
  static const String method = 'credit_approval_create';
  static const int version = 1;

  static Map<String, dynamic> payload({
    required int orderId,
    required int partnerId,
    required double amount,
    required String checkType,
    int? paymentTermId,
    String? orderUuid,
  }) => {
    'order_id': orderId,
    'partner_id': partnerId,
    'amount': amount,
    'check_type': checkType,
    'payment_term_id': ?paymentTermId,
    'order_uuid': ?orderUuid,
  };

  static String operationKey({
    required int orderId,
    required String checkType,
    String? orderUuid,
  }) {
    final orderKey = orderUuid?.trim().isNotEmpty == true
        ? orderUuid!.trim()
        : orderId.toString();
    return 'v$version:$aggregateModel:$method:$orderKey:$checkType';
  }

  static Future<int> enqueue({
    required OfflineQueueDataSource queue,
    required int orderId,
    required int partnerId,
    required double amount,
    required String checkType,
    int? paymentTermId,
    String? orderUuid,
  }) {
    if (orderId == 0) {
      throw ArgumentError.value(orderId, 'orderId', 'Must not be zero');
    }
    if (partnerId <= 0) {
      throw ArgumentError.value(partnerId, 'partnerId', 'Must be positive');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Must be positive and finite',
      );
    }
    if (checkType.trim().isEmpty) {
      throw ArgumentError.value(checkType, 'checkType', 'Must not be empty');
    }

    return queue.queueOperation(
      model: aggregateModel,
      method: method,
      recordId: orderId,
      parentOrderId: orderId,
      values: payload(
        orderId: orderId,
        partnerId: partnerId,
        amount: amount,
        checkType: checkType.trim(),
        paymentTermId: paymentTermId,
        orderUuid: orderUuid,
      ),
      priority: OfflinePriority.high,
      operationKey: operationKey(
        orderId: orderId,
        checkType: checkType.trim(),
        orderUuid: orderUuid,
      ),
      commandVersion: version,
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
  }
}

/// Servicio para gestionar solicitudes de aprobación de crédito via Odoo API.
///
/// Utiliza el wizard `credit.limit.exceeded.wizard` del módulo
/// `l10n_ec_sale_credit` para crear solicitudes de aprobación, respetando
/// el flujo nativo de Odoo (categoría, confirmación, campos de auditoría).
///
/// ## Flujo online
/// 1. Crea instancia del wizard con los datos del problema de crédito
/// 2. Llama `action_create_approval_request()` en el wizard
/// 3. El wizard crea el `approval.request` y lo confirma internamente
/// 4. Odoo cambia el estado de la orden a `waiting`
/// 5. El sync HTTP actualiza Drift → `.watch()` refresca la UI
///
/// ## Flujo offline
/// - Si no hay conexión, crea el estado local `waiting` en Drift
/// - Encola la operación en `OfflineQueue` para sincronización posterior
///
/// Ver también: `SalesRepositoryCredit.createCreditApprovalRequest()` que
/// delega a este servicio cuando está disponible.
class CreditApprovalService {
  final OdooClient _client;
  final OfflineQueueDataSource? _offlineQueue;

  static const _tag = '[CreditApprovalService]';

  CreditApprovalService({required this._client, this._offlineQueue});

  /// Crear solicitud de aprobación de crédito usando el wizard de Odoo.
  ///
  /// Parámetros que corresponden a campos del wizard `credit.limit.exceeded.wizard`:
  /// - [saleOrderId]: ID de la orden con problema de crédito
  /// - [partnerId]: ID del cliente
  /// - [transactionAmount]: Monto de la transacción actual
  /// - [currentCreditLimit]: Límite de crédito del cliente
  /// - [creditAvailable]: Crédito disponible actual
  /// - [checkType]: Tipo de problema — `'overdue_debt'` o `'credit_limit_exceeded'`
  /// - [paymentTermId]: ID del plazo de pago de la orden
  ///
  /// Retorna el resultado del wizard (puede incluir `approval_request_id`).
  /// Lanza [StateError] si el wizard no puede crearse o ejecutarse.
  Future<Map<String, dynamic>> createApprovalViaWizard({
    required int saleOrderId,
    required int partnerId,
    required double transactionAmount,
    required double currentCreditLimit,
    required double creditAvailable,
    required String checkType,
    required int paymentTermId,
  }) async {
    logger.d(
      _tag,
      'createApprovalViaWizard: orderId=$saleOrderId, checkType=$checkType, '
      'amount=$transactionAmount, limit=$currentCreditLimit',
    );

    // 1. Crear la instancia del wizard con los datos del problema de crédito
    final wizardId = await _client.create(
      model: 'credit.limit.exceeded.wizard',
      values: {
        'partner_id': partnerId,
        'sale_order_id': saleOrderId,
        'transaction_amount': transactionAmount,
        'current_credit_limit': currentCreditLimit,
        'credit_available': creditAvailable,
        'authorization_type': checkType,
        'check_type': checkType,
        'payment_term_id': paymentTermId,
      },
    );

    if (wizardId == null) {
      throw StateError(
        'No se pudo crear el wizard de aprobación de crédito. '
        'Verifique que el módulo l10n_ec_sale_credit esté instalado en Odoo.',
      );
    }

    logger.d(
      _tag,
      'Wizard created: id=$wizardId, calling action_create_approval_request...',
    );

    // 2. Ejecutar la acción del wizard que crea el approval.request
    // El wizard internamente:
    //   - Busca o crea la categoría de aprobación de crédito
    //   - Crea el approval.request con todos los campos de auditoría
    //   - Llama action_confirm() en el request (pasa a estado 'pending')
    //   - Actualiza el estado de la orden a 'waiting'
    final result = await _client.call(
      model: 'credit.limit.exceeded.wizard',
      method: 'action_create_approval_request',
      ids: [wizardId],
    );

    logger.i(
      _tag,
      'action_create_approval_request returned: ${result.runtimeType}',
    );

    if (result is Map<String, dynamic>) {
      return result;
    }

    // El wizard puede retornar null o una acción de ventana (ir.actions.act_window)
    // En ambos casos el approval.request fue creado correctamente
    return {'success': true, 'wizard_id': wizardId};
  }

  /// Verificar solicitudes de aprobación pendientes para una orden.
  ///
  /// Busca `approval.request` con tipo `credit` y estado `new` o `pending`
  /// asociadas a [saleOrderId]. Útil para evitar duplicados antes de crear.
  ///
  /// Retorna lista vacía si no hay pendientes o si ocurre un error.
  Future<List<Map<String, dynamic>>> getPendingApprovals(
    int saleOrderId,
  ) async {
    try {
      final results = await _client.searchRead(
        model: 'approval.request',
        domain: [
          ['sale_order_id', '=', saleOrderId],
          ['approval_type', '=', 'credit'],
          [
            'request_status',
            'in',
            ['new', 'pending'],
          ],
        ],
        fields: [
          'id',
          'name',
          'request_status',
          'request_owner_id',
          'create_date',
        ],
        order: 'create_date desc',
        limit: 5,
      );

      logger.d(
        _tag,
        'getPendingApprovals: found ${results.length} pending for order $saleOrderId',
      );
      return results;
    } catch (e) {
      logger.w(
        _tag,
        'Error checking pending approvals for order $saleOrderId: $e',
      );
      return [];
    }
  }

  /// Flujo completo: verificar duplicados + crear via wizard.
  ///
  /// Combina [getPendingApprovals] y [createApprovalViaWizard] en un paso:
  /// 1. Verifica si ya existe una solicitud pendiente (evita duplicados)
  /// 2. Si no hay duplicado, crea via wizard
  ///
  /// [skipDuplicateCheck] — si true, omite la verificación de duplicados.
  ///
  /// Retorna el resultado del wizard.
  /// Lanza [StateError] si hay duplicados o si falla la creación.
  Future<Map<String, dynamic>> createApprovalWithDuplicateCheck({
    required int saleOrderId,
    required int partnerId,
    required double transactionAmount,
    required double currentCreditLimit,
    required double creditAvailable,
    required String checkType,
    required int paymentTermId,
    bool skipDuplicateCheck = false,
  }) async {
    if (!skipDuplicateCheck) {
      final pending = await getPendingApprovals(saleOrderId);
      if (pending.isNotEmpty) {
        final latestRef = pending.first['name'] as String?;
        throw StateError(
          pending.length == 1
              ? 'Ya existe una solicitud de aprobación pendiente'
                    '${latestRef != null ? ": $latestRef" : ""}. '
                    'Espere la aprobación o cancele la solicitud existente.'
              : 'Existen ${pending.length} solicitudes de aprobación pendientes '
                    'para esta orden.',
        );
      }
    }

    return createApprovalViaWizard(
      saleOrderId: saleOrderId,
      partnerId: partnerId,
      transactionAmount: transactionAmount,
      currentCreditLimit: currentCreditLimit,
      creditAvailable: creditAvailable,
      checkType: checkType,
      paymentTermId: paymentTermId,
    );
  }

  /// Encolar solicitud de aprobación para procesamiento offline.
  ///
  /// Cuando no hay conexión, guarda la intención de crear el approval.request
  /// en la `OfflineQueue`. El procesador la enviará cuando haya conectividad.
  ///
  /// Retorna `true` si se encoló correctamente, `false` si no hay cola disponible.
  Future<bool> queueApprovalRequest({
    required int orderId,
    required int partnerId,
    required double amount,
    required String checkType,
    int? paymentTermId,
  }) async {
    if (_offlineQueue == null) {
      logger.w(_tag, 'queueApprovalRequest: OfflineQueue not available');
      return false;
    }

    await CreditApprovalOfflineContract.enqueue(
      queue: _offlineQueue,
      orderId: orderId,
      partnerId: partnerId,
      amount: amount,
      checkType: checkType,
      paymentTermId: paymentTermId,
    );

    logger.i(_tag, 'Approval request queued for order $orderId (offline)');
    return true;
  }
}
