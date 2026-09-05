import '../../../core/services/odoo_service.dart';
import '../../../shared/utils/error_utils.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import 'payment_service_models.dart';

/// Servicio de crédito del cliente, registro de retenciones y aprobación de
/// crédito.
///
/// Extraído tal cual de `payment_service.dart` como parte de la
/// descomposición sin cambio de comportamiento (Fase E2, sección 3 del plan
/// de descomposición). `PaymentService` delega aquí (facade).
///
/// [getPartnerCreditInfo] también es usado por `PaymentValidationService`
/// (inyectado como dependencia) para `validateCreditSale`.
class CreditWithholdingService {
  final OdooService _odoo;

  CreditWithholdingService(this._odoo);

  // ============================================================
  // CRÉDITO - Información de crédito del cliente
  // ============================================================

  /// Obtiene la información de crédito del cliente
  Future<PartnerCreditInfo?> getPartnerCreditInfo(int partnerId) async {
    try {
      // Usar search_read en lugar de read para evitar problemas con la API JSON2
      final result = await _odoo.call(
        model: 'res.partner',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', '=', partnerId],
          ],
          'fields': [
            'credit_limit',
            'credit',
            'credit_to_invoice',
            'total_overdue',
            'credit_available',
            'allow_over_credit',
          ],
          'limit': 1,
        },
      );

      if (result == null || result is! List || result.isEmpty) {
        return null;
      }

      final data = result[0] as Map<String, dynamic>;

      return PartnerCreditInfo(
        creditLimit: (data['credit_limit'] as num?)?.toDouble() ?? 0,
        creditUsed: (data['credit'] as num?)?.toDouble() ?? 0,
        creditToInvoice: (data['credit_to_invoice'] as num?)?.toDouble() ?? 0,
        totalOverdue: (data['total_overdue'] as num?)?.toDouble() ?? 0,
        // ERP2 does not expose an unpaid invoice counter on res.partner.
        // Keep the local/UI contract deterministic until it is calculated
        // from account.move data by a dedicated offline aggregate.
        unpaidInvoicesCount: 0,
        creditAvailable: (data['credit_available'] as num?)?.toDouble() ?? 0,
        allowOverCredit: data['allow_over_credit'] as bool? ?? false,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting partner credit info', e, st);
      return null;
    }
  }

  // ============================================================
  // RETENCIONES - Registro de retenciones del cliente
  // ============================================================

  /// Obtiene los tipos de retención disponibles
  Future<List<WithholdingType>> getWithholdingTypes() async {
    try {
      // Obtener impuestos de retención (grupo de retención)
      final taxes = await _odoo.call(
        model: 'account.tax',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['type_tax_use', '=', 'sale'],
            ['l10n_ec_code_applied', '!=', false],
            ['active', '=', true],
          ],
          'fields': ['id', 'name', 'amount', 'l10n_ec_code_applied'],
          'order': 'name',
        },
      );

      if (taxes == null || taxes is! List) {
        return [];
      }

      return taxes.map((t) {
        final tax = t as Map<String, dynamic>;
        return WithholdingType(
          id: tax['id'] as int,
          name: tax['name'] as String,
          percentage: (tax['amount'] as num).toDouble().abs(),
          code: tax['l10n_ec_code_applied'] as String? ?? '',
        );
      }).toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting withholding types', e, st);
      return [];
    }
  }

  /// Registra una retención del cliente en la orden de venta
  ///
  /// Crea un registro de retención (out_withhold) vinculado a la factura.
  ///
  /// El wizard l10n_ec.wizard.account.withhold usa context para recibir
  /// las facturas via active_ids/active_model, y el campo related_invoice_ids
  /// se computa automáticamente.
  ///
  /// [invoiceId]: ID de la factura (account.move)
  /// [lines]: Líneas de retención con tax_id, base y amount
  /// [authorizationNumber]: Número de autorización SRI (49 dígitos)
  /// [documentNumber]: Secuencia de la retención (ej: 001-001-000000001)
  Future<WithholdingResult> registerWithholding({
    required int invoiceId,
    required List<WithholdingLine> lines,
    String? authorizationNumber,
    String? documentNumber,
  }) async {
    try {
      if (lines.isEmpty) {
        return WithholdingResult(
          success: false,
          errorMessage: 'Debe agregar al menos una línea de retención',
        );
      }

      // Preparar valores del wizard
      // El wizard usa context para recibir las facturas (active_ids)
      final wizardVals = <String, dynamic>{};

      // Para retenciones de venta (out_withhold), se requiere número de autorización manual
      if (authorizationNumber != null && authorizationNumber.isNotEmpty) {
        wizardVals['manual_authorization_number'] = authorizationNumber;
      }

      // Número de documento/secuencia de la retención
      if (documentNumber != null && documentNumber.isNotEmpty) {
        wizardVals['document_number'] = documentNumber;
      }

      // Crear wizard con contexto de la factura activa
      // El wizard obtiene las facturas desde context['active_ids']
      final wizardId = await _odoo.call(
        model: 'l10n_ec.wizard.account.withhold',
        method: 'create',
        kwargs: {
          'vals_list': [wizardVals],
        },
        context: {
          'active_ids': [invoiceId],
          'active_model': 'account.move',
          'active_id': invoiceId,
        },
      );

      if (wizardId == null) {
        throw Exception('Failed to create withholding wizard');
      }

      final id = wizardId is List ? wizardId[0] as int : wizardId as int;
      logger.d(
        '[PaymentService]',
        'Created withhold wizard: $id for invoice $invoiceId',
      );

      // Agregar líneas de retención
      for (final line in lines) {
        await _odoo.call(
          model: 'l10n_ec.wizard.account.withhold.line',
          method: 'create',
          kwargs: {
            'vals_list': [
              {
                'wizard_id': id,
                'invoice_id':
                    invoiceId, // Link to invoice for taxsupport computation
                'tax_id': line.taxId,
                'base': line.base,
              },
            ],
          },
        );
      }
      logger.d('[PaymentService]', 'Added ${lines.length} withhold lines');

      // Crear y publicar la retención
      final result = await _odoo.call(
        model: 'l10n_ec.wizard.account.withhold',
        method: 'action_create_and_post_withhold',
        ids: [id],
      );

      // Obtener el ID de la retención creada
      int? withholdId;
      String? withholdName;

      if (result is Map && result.containsKey('res_id')) {
        withholdId = result['res_id'] as int?;
      }

      if (withholdId != null) {
        // Usar search_read para obtener el nombre de la retención
        final withhold = await _odoo.call(
          model: 'account.move',
          method: 'search_read',
          kwargs: {
            'domain': [
              ['id', '=', withholdId],
            ],
            'fields': ['name'],
            'limit': 1,
          },
        );
        if (withhold is List && withhold.isNotEmpty) {
          withholdName =
              (withhold[0] as Map<String, dynamic>)['name'] as String?;
        }
      }

      logger.i('[PaymentService]', 'Withholding registered: $withholdName');

      // Calcular total retenido de las líneas
      final totalWithheld = lines.fold(0.0, (sum, line) => sum + line.amount);

      return WithholdingResult(
        success: true,
        withholdId: withholdId,
        withholdName: withholdName,
        totalWithheld: totalWithheld,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error registering withholding', e, st);
      return WithholdingResult(
        success: false,
        errorMessage: friendlyErrorMessage(e),
      );
    }
  }

  // ============================================================
  // APROBACIÓN DE CRÉDITO
  // ============================================================

  /// Solicita aprobación de crédito para una orden de venta
  ///
  /// Crea una solicitud de aprobación cuando el cliente:
  /// - Excede su límite de crédito
  /// - Tiene deudas vencidas
  /// - Requiere crédito temporal
  Future<CreditApprovalResult> requestCreditApproval({
    required int partnerId,
    required double transactionAmount,
    required CreditAuthorizationType authorizationType,
    int? saleOrderId,
    int? invoiceId,
    int? paymentTermId,
    double? creditLimit,
  }) async {
    try {
      // Convertir tipo de autorización
      final authTypeStr = switch (authorizationType) {
        CreditAuthorizationType.overdueDebt => 'overdue_debt',
        CreditAuthorizationType.creditLimitExceeded => 'credit_limit_exceeded',
        CreditAuthorizationType.temporaryCredit => 'temporary_credit',
      };

      // Crear el wizard de crédito excedido
      final wizardVals = <String, dynamic>{
        'partner_id': partnerId,
        'transaction_amount': transactionAmount,
        'authorization_type': authTypeStr,
        'check_type': authTypeStr,
      };

      if (saleOrderId != null) {
        wizardVals['sale_order_id'] = saleOrderId;
      }
      if (invoiceId != null) {
        wizardVals['invoice_id'] = invoiceId;
      }
      if (paymentTermId != null) {
        wizardVals['payment_term_id'] = paymentTermId;
      }
      if (creditLimit != null) {
        wizardVals['current_credit_limit'] = creditLimit;
      }

      // Crear el wizard usando vals_list (requerido por Odoo 18 JSON2 API)
      final wizardId = await _odoo.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'create',
        kwargs: {
          'vals_list': [wizardVals],
        },
      );

      if (wizardId == null) {
        throw Exception('Failed to create credit approval wizard');
      }

      final id = wizardId is List ? wizardId[0] as int : wizardId as int;

      // Ejecutar action_create_approval_request
      await _odoo.call(
        model: 'credit.limit.exceeded.wizard',
        method: 'action_create_approval_request',
        ids: [id],
      );

      // La orden debe quedar en estado 'waiting'
      logger.i('[PaymentService]', 'Credit approval request created');

      // Obtener info de la solicitud creada
      // El resultado del wizard no devuelve directamente el ID
      // pero la orden queda en 'waiting' y se puede consultar
      int? approvalId;
      String? approvalName;

      if (saleOrderId != null) {
        // Buscar la solicitud de aprobación vinculada a la orden
        final approvals = await _odoo.call(
          model: 'approval.request',
          method: 'search_read',
          kwargs: {
            'domain': [
              ['sale_order_id', '=', saleOrderId],
              ['approval_type', '=', 'credit'],
            ],
            'fields': ['id', 'name'],
            'order': 'create_date desc',
            'limit': 1,
          },
        );

        if (approvals is List && approvals.isNotEmpty) {
          final approval = approvals[0] as Map<String, dynamic>;
          approvalId = approval['id'] as int;
          approvalName = approval['name'] as String?;
        }
      }

      return CreditApprovalResult(
        success: true,
        approvalId: approvalId,
        approvalName: approvalName,
      );
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error requesting credit approval', e, st);
      return CreditApprovalResult(
        success: false,
        errorMessage: friendlyErrorMessage(e),
      );
    }
  }

  /// Verifica si una orden tiene aprobación de crédito pendiente
  Future<bool> hasPendingCreditApproval(int saleOrderId) async {
    try {
      final approvals = await _odoo.call(
        model: 'approval.request',
        method: 'search_count',
        kwargs: {
          'domain': [
            ['sale_order_id', '=', saleOrderId],
            ['approval_type', '=', 'credit'],
            ['request_status', '=', 'pending'],
          ],
        },
      );

      return (approvals as int? ?? 0) > 0;
    } catch (e) {
      logger.e('[PaymentService]', 'Error checking pending credit approval', e);
      return false;
    }
  }

  /// Verifica si una orden tiene aprobación de crédito aprobada
  Future<bool> hasCreditApprovalApproved(int saleOrderId) async {
    try {
      final approvals = await _odoo.call(
        model: 'approval.request',
        method: 'search_count',
        kwargs: {
          'domain': [
            ['sale_order_id', '=', saleOrderId],
            ['approval_type', '=', 'credit'],
            ['request_status', '=', 'approved'],
          ],
        },
      );

      return (approvals as int? ?? 0) > 0;
    } catch (e) {
      logger.e('[PaymentService]', 'Error checking credit approval status', e);
      return false;
    }
  }
}
