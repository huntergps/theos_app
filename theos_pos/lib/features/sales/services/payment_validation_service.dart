import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../../shared/utils/formatting_utils.dart';
import 'order_validation_types.dart';
import 'credit_withholding_service.dart';

/// Servicio de validación de pagos: montos, anticipos, notas de crédito,
/// sobrepago y crédito del cliente.
///
/// Extraído tal cual de `payment_service.dart` como parte de la
/// descomposición sin cambio de comportamiento (Fase E2, sección 3 del plan
/// de descomposición). `PaymentService` delega aquí (facade).
///
/// [validateCreditSale] depende de [CreditWithholdingService.getPartnerCreditInfo]
/// — se inyecta como dependencia (composición) en vez de duplicar lógica.
class PaymentValidationService {
  final AppDatabase _db;
  final CreditWithholdingService _credit;

  PaymentValidationService(this._db, this._credit);

  /// Valida las líneas de pago antes de guardar
  ///
  /// Verifica:
  /// - Que cada línea tenga monto > 0
  /// - Que los anticipos tengan saldo suficiente
  /// - Que las notas de crédito tengan saldo residual suficiente
  /// - Detecta sobrepago (pagos > total de orden)
  ///
  /// [lines]: Lista de líneas de pago a validar
  /// [orderTotal]: Monto total de la orden
  /// [partnerId]: ID del cliente (para validar anticipos y NC)
  ///
  /// Retorna un ValidationResult con errores/advertencias
  Future<ValidationResult> validatePaymentLines({
    required List<PaymentLine> lines,
    required double orderTotal,
    int? partnerId,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    if (lines.isEmpty) {
      return ValidationResult.success();
    }

    double totalPayments = 0;

    for (final line in lines) {
      // Validar monto > 0
      if (line.amount <= 0) {
        errors.add(ValidationError.invalidPaymentAmount());
        continue;
      }

      totalPayments += line.amount;

      // Validar anticipo
      if (line.type == PaymentLineType.advance && line.advanceId != null) {
        final validationError = await _validateAdvance(
          line.advanceId!,
          line.amount,
        );
        if (validationError != null) {
          errors.add(validationError);
        }
      }

      // Validar nota de crédito
      if (line.type == PaymentLineType.creditNote &&
          line.creditNoteId != null) {
        final validationError = await _validateCreditNote(
          line.creditNoteId!,
          line.amount,
        );
        if (validationError != null) {
          errors.add(validationError);
        }
      }

      // Validar campos requeridos por tipo de pago
      if (line.type == PaymentLineType.payment) {
        final code = line.paymentMethodCode ?? '';

        // Validar campos para pagos con tarjeta
        if (code.contains('card')) {
          if (line.cardBrandId == null) {
            errors.add(
              ValidationError.missingPaymentInfo(field: 'Marca de tarjeta'),
            );
          }
          if (line.cardDeadlineId == null) {
            errors.add(
              ValidationError.missingPaymentInfo(field: 'Plazo de tarjeta'),
            );
          }
        }

        // Validar campos para pagos con cheque
        if (code.contains('cheque')) {
          if (line.reference == null || line.reference!.isEmpty) {
            errors.add(
              ValidationError.missingPaymentInfo(field: 'Número de cheque'),
            );
          }
          if (line.bankId == null) {
            errors.add(ValidationError.missingPaymentInfo(field: 'Banco'));
          }
        }

        // Validar campos para transferencias
        if (code.contains('transf')) {
          if (line.reference == null || line.reference!.isEmpty) {
            errors.add(
              ValidationError.missingPaymentInfo(
                field: 'Referencia de transferencia',
              ),
            );
          }
        }
      }
    }

    // Verificar sobrepago
    if (totalPayments > orderTotal) {
      final overpayment = totalPayments - orderTotal;
      if (overpayment > 0.01) {
        // Tolerancia de 1 centavo
        warnings.add(
          ValidationWarning(
            code: 'overpayment',
            message:
                'El sobrepago de ${overpayment.toCurrency()} generará un anticipo a favor del cliente.',
          ),
        );
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.failed(errors);
    }

    if (warnings.isNotEmpty) {
      return ValidationResult.successWithWarnings(warnings);
    }

    return ValidationResult.success();
  }

  /// Valida un anticipo antes de usarlo
  Future<ValidationError?> _validateAdvance(
    int advanceId,
    double requestedAmount,
  ) async {
    try {
      final advance = await (_db.select(
        _db.accountAdvance,
      )..where((t) => t.odooId.equals(advanceId))).getSingleOrNull();

      if (advance == null) {
        return ValidationError.advanceNotFound(advanceId: advanceId);
      }

      if (advance.amountAvailable < requestedAmount) {
        return ValidationError.insufficientAdvanceBalance(
          advanceName: advance.name ?? 'Anticipo sin sincronizar',
          available: advance.amountAvailable,
          requested: requestedAmount,
        );
      }

      return null;
    } catch (e) {
      logger.e('[PaymentService]', 'Error validating advance $advanceId', e);
      return ValidationError.advanceNotFound(advanceId: advanceId);
    }
  }

  /// Valida una nota de crédito antes de usarla
  Future<ValidationError?> _validateCreditNote(
    int creditNoteId,
    double requestedAmount,
  ) async {
    try {
      final creditNote =
          await (_db.select(_db.accountMove)
                ..where((t) => t.odooId.equals(creditNoteId))
                ..where((t) => t.moveType.equals('out_refund')))
              .getSingleOrNull();

      if (creditNote == null) {
        return ValidationError.creditNoteNotFound(creditNoteId: creditNoteId);
      }

      if (creditNote.amountResidual < requestedAmount) {
        return ValidationError.insufficientCreditNoteBalance(
          creditNoteName: creditNote.name ?? '',
          available: creditNote.amountResidual,
          requested: requestedAmount,
        );
      }

      return null;
    } catch (e) {
      logger.e(
        '[PaymentService]',
        'Error validating credit note $creditNoteId',
        e,
      );
      return ValidationError.creditNoteNotFound(creditNoteId: creditNoteId);
    }
  }

  /// Valida si el cliente puede hacer una venta a crédito
  ///
  /// Verifica:
  /// - Límite de crédito
  /// - Deuda vencida
  /// - Crédito disponible vs monto de la orden
  ///
  /// [partnerId]: ID del cliente
  /// [orderAmount]: Monto total de la orden (solo crédito, no pagos al contado)
  Future<ValidationResult> validateCreditSale({
    required int partnerId,
    required double orderAmount,
  }) async {
    try {
      final creditInfo = await _credit.getPartnerCreditInfo(partnerId);

      if (creditInfo == null) {
        // Sin información de crédito - permitir por defecto
        return ValidationResult.success();
      }

      final errors = <ValidationError>[];
      final warnings = <ValidationWarning>[];

      // Verificar deuda vencida
      if (creditInfo.hasOverdueDebt && !creditInfo.allowOverCredit) {
        errors.add(
          ValidationError.overdueDebtExists(
            overdueAmount: creditInfo.totalOverdue,
            overdueCount: creditInfo.unpaidInvoicesCount,
          ),
        );
      }

      // Verificar límite de crédito
      if (creditInfo.hasCreditLimit) {
        final totalCredit =
            creditInfo.creditUsed + creditInfo.creditToInvoice + orderAmount;
        if (totalCredit > creditInfo.creditLimit &&
            !creditInfo.allowOverCredit) {
          errors.add(
            ValidationError.creditLimitExceeded(
              creditUsed: creditInfo.creditUsed + creditInfo.creditToInvoice,
              creditLimit: creditInfo.creditLimit,
              orderAmount: orderAmount,
            ),
          );
        } else if (totalCredit > creditInfo.creditLimit * 0.9) {
          // Advertencia si está cerca del límite (90%)
          warnings.add(
            ValidationWarning(
              code: 'credit_near_limit',
              message:
                  'El cliente está cerca de su límite de crédito (${creditInfo.creditUsagePercentage.toFixed(0)}% usado).',
            ),
          );
        }
      }

      if (errors.isNotEmpty) {
        return ValidationResult.failed(errors);
      }

      if (warnings.isNotEmpty) {
        return ValidationResult.successWithWarnings(warnings);
      }

      return ValidationResult.success();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error validating credit sale', e, st);
      // En caso de error, permitir por defecto pero con advertencia
      return ValidationResult.successWithWarnings([
        ValidationWarning(
          code: 'credit_check_failed',
          message: 'No se pudo verificar el crédito del cliente. Proceda con precaución.',
        ),
      ]);
    }
  }

  /// Calcula el monto pendiente después de aplicar los pagos
  ///
  /// [orderTotal]: Monto total de la orden
  /// [lines]: Líneas de pago aplicadas
  ///
  /// Retorna el monto pendiente (positivo) o sobrepago (negativo)
  double calculateRemainingAmount(double orderTotal, List<PaymentLine> lines) {
    final totalPayments = lines.fold(0.0, (sum, line) => sum + line.amount);
    return orderTotal - totalPayments;
  }

  /// Indica si hay sobrepago
  bool hasOverpayment(double orderTotal, List<PaymentLine> lines) {
    return calculateRemainingAmount(orderTotal, lines) < -0.01;
  }

  /// Indica si el pago está completo
  bool isPaymentComplete(double orderTotal, List<PaymentLine> lines) {
    final remaining = calculateRemainingAmount(orderTotal, lines);
    return remaining <= 0.01; // Tolerancia de 1 centavo
  }
}
