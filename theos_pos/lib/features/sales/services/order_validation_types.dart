/// Unified validation result for sale order operations
///
/// Used by SaleOrderLogicEngine to communicate validation results
/// across all validation types (SRI, credit, inventory, etc.)
library;

import '../../../shared/utils/formatting_utils.dart';

/// Types of validation errors
enum ValidationErrorType {
  // Partner validation
  partnerRequired,

  // Lines validation
  linesRequired,

  // SRI Ecuador validation
  finalConsumerLimitExceeded,
  finalConsumerNameRequired,
  invalidWithholdAuthorization,

  // Post-dated invoice validation
  postDatedInvoiceDateRequired,
  postDatedInvoiceDateInPast,
  postDatedInvoiceDateTooFar,

  // Product validation
  temporaryProductsFound,

  // Price and discount validation
  discountExceedsLimit,
  priceMarginTooLow,
  priceMarginTooHigh,

  // Credit validation
  creditLimitExceeded,
  overdueDebt,
  pendingApprovalExists,

  // Payment validation
  overpayment,
  missingPaymentInfo,
  invalidPaymentAmount,
  advanceNotFound,
  creditNoteNotFound,
  insufficientAdvanceBalance,
  insufficientCreditNoteBalance,

  // State validation
  invalidState,
  fieldNotEditable,

  // Generic
  custom,
}

/// Suggested action based on validation result
enum ValidationAction {
  /// Block the operation completely
  block,

  /// Requires manager approval
  requireApproval,

  /// Show warning but allow proceeding
  warn,

  /// Continue without issues
  proceed,
}

/// A validation error with details
class ValidationError {
  final ValidationErrorType type;
  final String message;
  final Map<String, dynamic>? details;

  const ValidationError({
    required this.type,
    required this.message,
    this.details,
  });

  // Factory constructors for common errors

  factory ValidationError.partnerRequired() => const ValidationError(
        type: ValidationErrorType.partnerRequired,
        message: 'Debe seleccionar un cliente antes de confirmar.',
      );

  factory ValidationError.linesRequired() => const ValidationError(
        type: ValidationErrorType.linesRequired,
        message: 'La orden debe tener al menos una línea de producto.',
      );

  factory ValidationError.finalConsumerLimitExceeded({
    required double total,
    required double limit,
  }) =>
      ValidationError(
        type: ValidationErrorType.finalConsumerLimitExceeded,
        message: '''NO se puede confirmar la orden.

El monto total (${total.toCurrency()}) excede el límite para consumidor final (${limit.toCurrency()}) según las regulaciones del SRI.

Opciones:
- Reducir el monto de la orden
- Cambiar el cliente por uno con identificación específica
- Dividir la orden en múltiples transacciones''',
        details: {'total': total, 'limit': limit, 'exceeded': total - limit},
      );

  factory ValidationError.finalConsumerNameRequired() => const ValidationError(
        type: ValidationErrorType.finalConsumerNameRequired,
        message:
            'El nombre del consumidor final es obligatorio cuando se marca como Consumidor Final.',
      );

  factory ValidationError.invalidWithholdAuthorization({
    required int actualLength,
  }) =>
      ValidationError(
        type: ValidationErrorType.invalidWithholdAuthorization,
        message:
            'La autorización de retención debe tener exactamente 49 dígitos. Tiene $actualLength dígitos.',
        details: {'actualLength': actualLength, 'requiredLength': 49},
      );

  factory ValidationError.postDatedDateRequired() => const ValidationError(
        type: ValidationErrorType.postDatedInvoiceDateRequired,
        message:
            "La fecha de facturación es obligatoria cuando se marca 'Emitir Factura en Fecha Posterior'.",
      );

  factory ValidationError.postDatedDateInPast() => const ValidationError(
        type: ValidationErrorType.postDatedInvoiceDateInPast,
        message: 'La fecha de facturación no puede ser anterior a hoy.',
      );

  factory ValidationError.postDatedDateTooFar({required int maxDays}) =>
      ValidationError(
        type: ValidationErrorType.postDatedInvoiceDateTooFar,
        message:
            'La fecha de facturación no puede ser mayor a $maxDays días desde hoy.',
        details: {'maxDays': maxDays},
      );

  factory ValidationError.temporaryProductsFound({
    required List<String> productNames,
  }) =>
      ValidationError(
        type: ValidationErrorType.temporaryProductsFound,
        message:
            'La orden contiene ${productNames.length} productos temporales que no permiten despacho:\n${productNames.map((n) => '- $n').join('\n')}\n\nDebe reemplazar estos productos antes de confirmar.',
        details: {'products': productNames, 'count': productNames.length},
      );

  factory ValidationError.discountExceedsLimit({
    required double discount,
    required double maxDiscount,
    String? productName,
  }) =>
      ValidationError(
        type: ValidationErrorType.discountExceedsLimit,
        message: productName != null
            ? 'El descuento ${discount.toFixed(1)}% en "$productName" excede el máximo permitido (${maxDiscount.toFixed(1)}%).'
            : 'El descuento ${discount.toFixed(1)}% excede el máximo permitido (${maxDiscount.toFixed(1)}%).',
        details: {
          'discount': discount,
          'maxDiscount': maxDiscount,
          if (productName != null) 'productName': productName,
        },
      );

  factory ValidationError.priceMarginTooLow({
    required double margin,
    required double minMargin,
    String? productName,
  }) =>
      ValidationError(
        type: ValidationErrorType.priceMarginTooLow,
        message: productName != null
            ? 'El margen ${margin.toFixed(1)}% en "$productName" es menor al mínimo permitido (${minMargin.toFixed(1)}%).'
            : 'El margen ${margin.toFixed(1)}% es menor al mínimo permitido (${minMargin.toFixed(1)}%).',
        details: {
          'margin': margin,
          'minMargin': minMargin,
          if (productName != null) 'productName': productName,
        },
      );

  factory ValidationError.priceMarginTooHigh({
    required double margin,
    required double maxMargin,
    String? productName,
  }) =>
      ValidationError(
        type: ValidationErrorType.priceMarginTooHigh,
        message: productName != null
            ? 'El margen ${margin.toFixed(1)}% en "$productName" excede el máximo permitido (${maxMargin.toFixed(1)}%).'
            : 'El margen ${margin.toFixed(1)}% excede el máximo permitido (${maxMargin.toFixed(1)}%).',
        details: {
          'margin': margin,
          'maxMargin': maxMargin,
          if (productName != null) 'productName': productName,
        },
      );

  factory ValidationError.pendingApprovalExists({
    required int count,
    String? latestReference,
  }) =>
      ValidationError(
        type: ValidationErrorType.pendingApprovalExists,
        message: count == 1
            ? 'Ya existe una solicitud de aprobación de crédito pendiente${latestReference != null ? ': $latestReference' : ''}. Debe esperar la aprobación o cancelar la solicitud existente.'
            : 'Existen $count solicitudes de aprobación de crédito pendientes. Debe esperar la aprobación o cancelar las solicitudes existentes.',
        details: {
          'count': count,
          if (latestReference != null) 'latestReference': latestReference,
        },
      );

  factory ValidationError.overpayment({
    required double totalPayments,
    required double orderTotal,
  }) =>
      ValidationError(
        type: ValidationErrorType.overpayment,
        message:
            'El total de pagos (${totalPayments.toCurrency()}) excede el monto de la orden (${orderTotal.toCurrency()}).\n\nEl sobrepago de ${(totalPayments - orderTotal).toCurrency()} generará un anticipo.',
        details: {
          'totalPayments': totalPayments,
          'orderTotal': orderTotal,
          'overpaymentAmount': totalPayments - orderTotal,
        },
      );

  factory ValidationError.invalidPaymentAmount() => const ValidationError(
        type: ValidationErrorType.invalidPaymentAmount,
        message: 'El monto del pago debe ser mayor a cero.',
      );

  factory ValidationError.missingPaymentInfo({required String field}) =>
      ValidationError(
        type: ValidationErrorType.missingPaymentInfo,
        message: 'Falta información requerida para el pago: $field.',
        details: {'field': field},
      );

  factory ValidationError.advanceNotFound({required int advanceId}) =>
      ValidationError(
        type: ValidationErrorType.advanceNotFound,
        message: 'El anticipo seleccionado no existe o ya no está disponible.',
        details: {'advanceId': advanceId},
      );

  factory ValidationError.creditNoteNotFound({required int creditNoteId}) =>
      ValidationError(
        type: ValidationErrorType.creditNoteNotFound,
        message: 'La nota de crédito seleccionada no existe o ya fue aplicada.',
        details: {'creditNoteId': creditNoteId},
      );

  factory ValidationError.insufficientAdvanceBalance({
    required String advanceName,
    required double available,
    required double requested,
  }) =>
      ValidationError(
        type: ValidationErrorType.insufficientAdvanceBalance,
        message:
            'El anticipo $advanceName tiene saldo insuficiente.\nDisponible: ${available.toCurrency()}\nSolicitado: ${requested.toCurrency()}',
        details: {
          'advanceName': advanceName,
          'available': available,
          'requested': requested,
        },
      );

  factory ValidationError.insufficientCreditNoteBalance({
    required String creditNoteName,
    required double available,
    required double requested,
  }) =>
      ValidationError(
        type: ValidationErrorType.insufficientCreditNoteBalance,
        message:
            'La nota de crédito $creditNoteName tiene saldo insuficiente.\nDisponible: ${available.toCurrency()}\nSolicitado: ${requested.toCurrency()}',
        details: {
          'creditNoteName': creditNoteName,
          'available': available,
          'requested': requested,
        },
      );

  factory ValidationError.creditLimitExceeded({
    required double creditUsed,
    required double creditLimit,
    required double orderAmount,
  }) =>
      ValidationError(
        type: ValidationErrorType.creditLimitExceeded,
        message:
            'El cliente ha excedido su límite de crédito.\n\nLímite: ${creditLimit.toCurrency()}\nUsado: ${creditUsed.toCurrency()}\nNueva orden: ${orderAmount.toCurrency()}\n\nDebe solicitar aprobación o seleccionar otro método de pago.',
        details: {
          'creditUsed': creditUsed,
          'creditLimit': creditLimit,
          'orderAmount': orderAmount,
          'availableCredit': creditLimit - creditUsed,
        },
      );

  factory ValidationError.overdueDebtExists({
    required double overdueAmount,
    required int overdueCount,
  }) =>
      ValidationError(
        type: ValidationErrorType.overdueDebt,
        message:
            'El cliente tiene deuda vencida.\n\nMonto vencido: ${overdueAmount.toCurrency()}\nFacturas vencidas: $overdueCount\n\nDebe solicitar aprobación para proceder con venta a crédito.',
        details: {
          'overdueAmount': overdueAmount,
          'overdueCount': overdueCount,
        },
      );

  factory ValidationError.invalidState({
    required String currentState,
    required List<String> validStates,
  }) =>
      ValidationError(
        type: ValidationErrorType.invalidState,
        message:
            'Solo se pueden confirmar órdenes en estado: ${validStates.join(", ")}. Estado actual: $currentState',
        details: {'currentState': currentState, 'validStates': validStates},
      );

  factory ValidationError.fieldNotEditable({
    required String fieldName,
    required String state,
  }) =>
      ValidationError(
        type: ValidationErrorType.fieldNotEditable,
        message: 'El campo "$fieldName" no se puede editar en estado "$state".',
        details: {'fieldName': fieldName, 'state': state},
      );

  factory ValidationError.custom(String message,
          {Map<String, dynamic>? details}) =>
      ValidationError(
        type: ValidationErrorType.custom,
        message: message,
        details: details,
      );

  @override
  String toString() => 'ValidationError(${type.name}): $message';
}

/// A validation warning (non-blocking)
class ValidationWarning {
  final String code;
  final String message;

  const ValidationWarning({
    required this.code,
    required this.message,
  });
}

/// Unified validation result
class ValidationResult {
  final bool isValid;
  final List<ValidationError> errors;
  final List<ValidationWarning> warnings;
  final ValidationAction suggestedAction;

  const ValidationResult._({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.suggestedAction = ValidationAction.proceed,
  });

  /// Validation passed - can proceed
  factory ValidationResult.success() => const ValidationResult._(
        isValid: true,
        suggestedAction: ValidationAction.proceed,
      );

  /// Validation passed with warnings
  factory ValidationResult.successWithWarnings(
          List<ValidationWarning> warnings) =>
      ValidationResult._(
        isValid: true,
        warnings: warnings,
        suggestedAction: ValidationAction.warn,
      );

  /// Validation failed - block operation
  factory ValidationResult.failed(List<ValidationError> errors) =>
      ValidationResult._(
        isValid: false,
        errors: errors,
        suggestedAction: ValidationAction.block,
      );

  /// Validation requires approval
  factory ValidationResult.requiresApproval({
    required String reason,
    List<ValidationWarning>? warnings,
  }) =>
      ValidationResult._(
        isValid: false,
        errors: [ValidationError.custom(reason)],
        warnings: warnings ?? [],
        suggestedAction: ValidationAction.requireApproval,
      );

  /// Get all error messages as a single string
  String get errorMessage => errors.map((e) => e.message).join('\n\n');

  /// Get the first error message
  String? get firstErrorMessage =>
      errors.isNotEmpty ? errors.first.message : null;

  /// Check if result has specific error type
  bool hasErrorType(ValidationErrorType type) =>
      errors.any((e) => e.type == type);

  /// Get errors of specific type
  List<ValidationError> getErrorsOfType(ValidationErrorType type) =>
      errors.where((e) => e.type == type).toList();

  @override
  String toString() => isValid
      ? 'ValidationResult.success(${warnings.length} warnings)'
      : 'ValidationResult.failed(${errors.length} errors)';
}
