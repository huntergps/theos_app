import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, PartnerBank, CreditIssue;

import '../../../../../shared/providers/user_provider.dart' show userProvider;
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../clients/clients.dart'
    show
        Client,
        CreditCheckType,
        CreditControlDialog,
        CreditDialogAction,
        CreditValidationResult,
        clientRepositoryProvider;
import '../../../repositories/sales_repository.dart' show CreditIssue;
import '../../../services/credit_validation_ui_service.dart'
    show UnifiedCreditResult;
import '../fast_sale_providers.dart';

/// Lógica centralizada de confirmación de orden para Fast Sale.
///
/// Unifica el flujo completo de confirmación (validación de crédito +
/// diálogo de bypass + loading + éxito/error) para que los dos puntos
/// de entrada — el botón del panel de líneas y el botón del panel de
/// acciones — se comporten exactamente igual.
///
/// Uso:
/// ```dart
/// await confirmOrderWithCreditCheck(context, ref);
/// ```
///
/// Guard sincrónico contra doble-tap: como los dos puntos de entrada (panel
/// de líneas y panel de acciones) invocan esta misma función top-level, el
/// flag [_isConfirmingOrder] se activa en el primer frame del tap —antes de
/// cualquier `await`— y se libera siempre en el `finally` (mismo patrón que
/// `_isSaving` en "Guardar Pagos" de pos_payment_tab.dart).
bool _isConfirmingOrder = false;

Future<void> confirmOrderWithCreditCheck(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_isConfirmingOrder) {
    logger.w('[POS]', 'Confirmación de orden ya en curso, se ignora tap duplicado');
    return;
  }
  _isConfirmingOrder = true;

  try {
    final notifier = ref.read(fastSaleProvider.notifier);

    // Paso 1: Validar crédito antes de confirmar
    final creditResult = await notifier.validateCreditForConfirmation();

    if (creditResult.errorMessage != null) {
      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error de validación de crédito',
        message: creditResult.errorMessage!,
      );
      return;
    }

    // Paso 2: Si requiere diálogo, mostrar control de crédito
    if (creditResult.requiresDialog &&
        creditResult.client != null &&
        creditResult.validationResult != null) {
      if (!context.mounted) return;

      // Solo supervisores con el grupo bypass ven el botón "Continuar de todas formas"
      final user = ref.read(userProvider);
      final canBypassCredit =
          user?.permissions.contains(
            'l10n_ec_sale_credit.group_credit_bypass',
          ) ??
          false;

      final action = await CreditControlDialog.show(
        context: context,
        client: creditResult.client!,
        validationResult: creditResult.validationResult!,
        orderAmount: creditResult.orderAmount,
        isOnline: creditResult.isOnline,
        canBypass: canBypassCredit,
      );

      if (action == null || action == CreditDialogAction.cancel) {
        return;
      }

      if (action == CreditDialogAction.createApproval) {
        if (!context.mounted) return;
        await _createApprovalRequest(context, ref, creditResult);
        return;
      }

      // action == CreditDialogAction.proceedAnyway
      logger.i('[POS]', 'Usuario eligió continuar (bypass de crédito)');
    }

    // Paso 3: Confirmar la orden con indicador de carga
    if (!context.mounted) return;
    await _executeConfirmOrder(
      context,
      ref,
      skipCreditCheck: creditResult.requiresDialog,
    );
  } finally {
    _isConfirmingOrder = false;
  }
}

/// Ejecuta la confirmación real mostrando un diálogo de carga.
Future<void> _executeConfirmOrder(
  BuildContext context,
  WidgetRef ref, {
  bool skipCreditCheck = false,
}) async {
  final notifier = ref.read(fastSaleProvider.notifier);

  // Mostrar indicador de carga (usando showDialog de Fluent UI)
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const ContentDialog(
      content: SizedBox(
        height: 80,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressRing(),
              SizedBox(height: 16),
              Text('Confirmando orden...'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final success = await notifier.confirmActiveOrder(
      skipCreditCheck: skipCreditCheck,
    );

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!context.mounted) return;

    if (success) {
      final confirmedTab = ref.read(fastSaleProvider).activeTab;
      final orderRef = confirmedTab?.orderName ?? '';
      final orderTotal = confirmedTab?.total ?? 0.0;
      CopyableInfoBar.showSuccess(
        context,
        title: 'Venta registrada${orderRef.isNotEmpty ? ' — $orderRef' : ''}',
        message: 'Total: ${orderTotal.toCurrency()}. La orden está lista para facturar.',
        durationSeconds: 5,
      );
    } else {
      // Verificar si hay un problema de crédito devuelto por Odoo
      final currentState = ref.read(fastSaleProvider);
      final creditIssue = currentState.lastCreditIssue;

      if (creditIssue != null && !skipCreditCheck) {
        final validationResult = _creditIssueToValidationResult(creditIssue);
        final client = currentState.activeTab?.order?.partnerId != null
            ? await _getClientForCreditDialog(
                ref,
                creditIssue.partnerId,
                creditIssue,
              )
            : null;

        if (!context.mounted) return;

        if (client != null) {
          final user = ref.read(userProvider);
          final canBypassCredit =
              user?.permissions.contains(
                'l10n_ec_sale_credit.group_credit_bypass',
              ) ??
              false;

          final action = await CreditControlDialog.show(
            context: context,
            client: client,
            validationResult: validationResult,
            orderAmount:
                creditIssue.orderAmount ?? currentState.activeTab?.total ?? 0,
            isOnline: true,
            canBypass: canBypassCredit,
          );

          notifier.clearCreditIssue();

          if (action == CreditDialogAction.proceedAnyway) {
            if (!context.mounted) return;
            await _executeConfirmOrder(context, ref, skipCreditCheck: true);
            return;
          }

          if (action == CreditDialogAction.createApproval) {
            if (!context.mounted) return;
            await _createApprovalRequestFromCreditIssue(context, ref, creditIssue);
            return;
          }

          return;
        }
      }

      final errorMsg = currentState.error ?? 'No se pudo confirmar la orden';
      CopyableInfoBar.showError(
        context,
        title: 'Error al confirmar',
        message: errorMsg,
      );
    }
  } catch (e) {
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }

    if (!context.mounted) return;
    CopyableInfoBar.showError(
      context,
      title: 'Error al confirmar',
      message: 'No se pudo confirmar la orden. Intenta nuevamente.',
    );
  }
}

/// Crea solicitud de aprobación de crédito a partir de [UnifiedCreditResult].
Future<void> _createApprovalRequest(
  BuildContext context,
  WidgetRef ref,
  UnifiedCreditResult creditResult,
) async {
  final notifier = ref.read(fastSaleProvider.notifier);

  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const ContentDialog(
      content: SizedBox(
        height: 80,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressRing(),
              SizedBox(height: 16),
              Text('Creando solicitud de aprobación...'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final checkType = creditResult.validationResult!.type;
    final approvalId = await notifier.createCreditApprovalRequest(
      checkType: checkType.name,
      reason: checkType == CreditCheckType.creditLimitExceeded
          ? 'Límite de crédito excedido'
          : 'Deuda vencida',
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (approvalId != null) {
      logger.i('[POS]', 'Solicitud de aprobación creada: ID $approvalId');
      CopyableInfoBar.showSuccess(
        context,
        title: 'Solicitud creada',
        message: 'La solicitud de aprobación ha sido enviada.\n'
            'La orden quedará en estado "Esperando aprobación".',
      );
    } else {
      CopyableInfoBar.showError(
        context,
        title: 'Error de aprobación',
        message: 'No se pudo crear la solicitud de aprobación',
      );
    }
  } catch (e) {
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
    if (!context.mounted) return;
    CopyableInfoBar.showError(
      context,
      title: 'Error de aprobación',
      message: 'No se pudo crear la solicitud. Intenta nuevamente.',
    );
  }
}

/// Crea solicitud de aprobación a partir de [CreditIssue] devuelto por Odoo.
Future<void> _createApprovalRequestFromCreditIssue(
  BuildContext context,
  WidgetRef ref,
  CreditIssue issue,
) async {
  final notifier = ref.read(fastSaleProvider.notifier);

  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const ContentDialog(
      content: SizedBox(
        height: 80,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProgressRing(),
              SizedBox(height: 16),
              Text('Creando solicitud de aprobación...'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    final checkType =
        issue.isOverdueDebt ? 'overdue_debt' : 'credit_limit_exceeded';
    final approvalId = await notifier.createCreditApprovalRequest(
      checkType: checkType,
      reason: issue.isOverdueDebt
          ? 'Deuda vencida'
          : 'Límite de crédito excedido',
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (approvalId != null) {
      logger.i('[POS]', 'Solicitud de aprobación creada: ID $approvalId');
      CopyableInfoBar.showSuccess(
        context,
        title: 'Solicitud creada',
        message: 'La solicitud de aprobación ha sido enviada.\n'
            'La orden quedará en estado "Esperando aprobación".',
      );
    } else {
      CopyableInfoBar.showError(
        context,
        title: 'Error de aprobación',
        message: 'No se pudo crear la solicitud de aprobación',
      );
    }
  } catch (e) {
    if (context.mounted) {
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (_) {}
    }
    if (!context.mounted) return;
    CopyableInfoBar.showError(
      context,
      title: 'Error de aprobación',
      message: 'No se pudo crear la solicitud. Intenta nuevamente.',
    );
  }
}

/// Convierte un [CreditIssue] (de Odoo) en [CreditValidationResult] del módulo clients.
CreditValidationResult _creditIssueToValidationResult(CreditIssue issue) {
  switch (issue.type) {
    case 'overdue_debt':
      return CreditValidationResult.overdueDebt(
        message: issue.message,
        isOffline: false,
      );
    case 'credit_limit_exceeded':
      return CreditValidationResult.creditExceeded(
        creditAvailable: issue.creditAvailable ?? 0,
        exceededAmount: issue.excessAmount ?? 0,
        isOffline: false,
      );
    case 'pending_requests':
      return CreditValidationResult(
        type: CreditCheckType.warning,
        isValid: false,
        message: issue.message,
      );
    default:
      return CreditValidationResult(
        type: CreditCheckType.warning,
        isValid: false,
        message: issue.message,
      );
  }
}

/// Obtiene datos del cliente para el diálogo de crédito.
Future<Client?> _getClientForCreditDialog(
  WidgetRef ref,
  int partnerId,
  CreditIssue issue,
) async {
  try {
    final clientRepo = ref.read(clientRepositoryProvider);
    if (clientRepo == null) return null;

    final localClient = await clientRepo.getById(partnerId);

    if (localClient != null) {
      return localClient.copyWith(
        creditLimit: issue.creditLimit ?? localClient.creditLimit,
        credit: issue.creditUsed ?? localClient.credit,
        totalOverdue: issue.totalOverdue ?? localClient.totalOverdue,
        overdueInvoicesCount:
            issue.overdueInvoicesCount ?? localClient.overdueInvoicesCount,
        oldestOverdueDays:
            issue.oldestOverdueDays ?? localClient.oldestOverdueDays,
      );
    }

    return Client(
      id: partnerId,
      name: issue.partnerName,
      creditLimit: issue.creditLimit ?? 0,
      credit: issue.creditUsed ?? 0,
      totalOverdue: issue.totalOverdue,
      overdueInvoicesCount: issue.overdueInvoicesCount,
      oldestOverdueDays: issue.oldestOverdueDays,
    );
  } catch (e) {
    return null;
  }
}
