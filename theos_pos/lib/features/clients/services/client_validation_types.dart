/// Types of credit check results
enum CreditCheckType {
  none, // No issues
  noLimit, // No credit limit configured
  creditLimitExceeded, // Order exceeds credit limit
  overdueDebt, // Partner has overdue debt issues
  staleData, // Credit data is too old
  warning, // Warning only (can proceed)
}

/// Result of a validation check (like @api.constrains in Odoo)
///
/// This class represents the result of validating a single field
/// or a group of related fields, following Odoo's validation pattern.
class ValidationResult {
  final String? field;
  final String? message;
  final String? code;
  final ValidationSeverity severity;

  const ValidationResult._({
    this.field,
    this.message,
    this.code,
    required this.severity,
  });

  /// No validation error
  factory ValidationResult.ok() => const ValidationResult._(
        severity: ValidationSeverity.ok,
      );

  /// Validation error (blocks save)
  factory ValidationResult.error({
    String? field,
    required String message,
    String? code,
  }) =>
      ValidationResult._(
        field: field,
        message: message,
        code: code,
        severity: ValidationSeverity.error,
      );

  /// Validation warning (doesn't block save)
  factory ValidationResult.warning({
    String? field,
    required String message,
    String? code,
  }) =>
      ValidationResult._(
        field: field,
        message: message,
        code: code,
        severity: ValidationSeverity.warning,
      );

  bool get isValid => severity == ValidationSeverity.ok;
  bool get isError => severity == ValidationSeverity.error;
  bool get isWarning => severity == ValidationSeverity.warning;
}

/// Severity level for validation results
enum ValidationSeverity {
  ok,
  warning,
  error,
}

/// Result of a credit validation check
///
/// This class represents the result of validating credit for an order,
/// including all relevant details for UI display.
class CreditValidationResult {
  final CreditCheckType type;
  final bool isValid;
  final String? message;
  final double? creditAvailable;
  final double? creditExceededAmount;
  final bool isDataStale;
  final bool isOffline;

  const CreditValidationResult({
    required this.type,
    required this.isValid,
    this.message,
    this.creditAvailable,
    this.creditExceededAmount,
    this.isDataStale = false,
    this.isOffline = false,
  });

  /// No issues found
  factory CreditValidationResult.ok() => const CreditValidationResult(
        type: CreditCheckType.none,
        isValid: true,
      );

  /// No credit limit configured
  factory CreditValidationResult.noLimit() => const CreditValidationResult(
        type: CreditCheckType.noLimit,
        isValid: true,
        message: 'Sin límite de crédito configurado',
      );

  /// Credit limit exceeded
  factory CreditValidationResult.creditExceeded({
    required double creditAvailable,
    required double exceededAmount,
    bool isOffline = false,
  }) =>
      CreditValidationResult(
        type: CreditCheckType.creditLimitExceeded,
        isValid: false,
        message: 'Límite de crédito excedido',
        creditAvailable: creditAvailable,
        creditExceededAmount: exceededAmount,
        isOffline: isOffline,
      );

  /// Overdue debt issues
  factory CreditValidationResult.overdueDebt({
    required String message,
    bool isOffline = false,
  }) =>
      CreditValidationResult(
        type: CreditCheckType.overdueDebt,
        isValid: false,
        message: message,
        isOffline: isOffline,
      );

  /// Data is stale (too old to trust)
  factory CreditValidationResult.staleData({
    required int hoursOld,
  }) =>
      CreditValidationResult(
        type: CreditCheckType.staleData,
        isValid: false,
        message: 'Datos de crédito desactualizados ($hoursOld horas)',
        isDataStale: true,
        isOffline: true,
      );

  /// Warning only (partner allowed to exceed)
  factory CreditValidationResult.warning({
    required String message,
    double? creditAvailable,
  }) =>
      CreditValidationResult(
        type: CreditCheckType.warning,
        isValid: true,
        message: message,
        creditAvailable: creditAvailable,
      );

  /// Check if this result requires user confirmation
  bool get requiresConfirmation =>
      type == CreditCheckType.creditLimitExceeded ||
      type == CreditCheckType.overdueDebt ||
      type == CreditCheckType.staleData;

  /// Check if this result is just a warning
  bool get isWarningOnly => type == CreditCheckType.warning;

  /// Check if this is a blocking error
  bool get isBlockingError => !isValid && !isWarningOnly;
}
