import 'package:theos_pos_core/theos_pos_core.dart';
import 'client_validation_types.dart';
import 'client_calculator_service.dart';

/// Service for client validations
///
/// Implements validation patterns like Odoo's @api.constrains:
/// - Field validations (VAT, email, phone)
/// - Credit validations (limit, overdue debt)
/// - Required field validations
///
/// Validations are executed before save and return [ValidationResult]
/// or [CreditValidationResult] with error details.
///
/// Usage:
/// ```dart
/// final validator = ref.read(clientValidationProvider);
///
/// // Validate single field
/// final result = validator.validateVat(client);
/// if (result.isError) {
///   showError(result.message);
/// }
///
/// // Validate all for save
/// final errors = validator.validateForSave(client);
/// if (errors.isNotEmpty) {
///   showErrors(errors);
/// }
///
/// // Validate credit for order
/// final creditResult = await validator.validateCreditForOrder(
///   client: client,
///   orderAmount: 500.0,
///   isOnline: true,
/// );
/// ```
class ClientValidationService {
  final ClientCalculatorService _calculator;

  ClientValidationService(this._calculator);

  // ============ FIELD VALIDATIONS (like @api.constrains) ============

  /// Validate VAT/RUC field
  ///
  /// @api.constrains('vat')
  /// Validates Ecuadorian VAT format if provided.
  ValidationResult validateVat(Client client) {
    if (client.vat == null || client.vat!.isEmpty) {
      return ValidationResult.ok();
    }

    final vat = client.vat!.replaceAll(RegExp(r'[\s\-]'), '');

    // Basic length validation
    if (vat.length != 10 && vat.length != 13) {
      return ValidationResult.error(
        field: 'vat',
        message: 'RUC/Cédula debe tener 10 o 13 dígitos',
        code: 'INVALID_VAT_LENGTH',
      );
    }

    // Only digits
    if (!RegExp(r'^\d+$').hasMatch(vat)) {
      return ValidationResult.error(
        field: 'vat',
        message: 'RUC/Cédula solo debe contener números',
        code: 'INVALID_VAT_FORMAT',
      );
    }

    // Province code validation (first 2 digits)
    final province = int.tryParse(vat.substring(0, 2)) ?? 0;
    if (province < 1 || province > 24) {
      // 01-24 are valid provinces, some special codes exist
      if (province != 30) {
        // 30 is for some special cases
        return ValidationResult.warning(
          field: 'vat',
          message: 'Código de provincia puede ser inválido',
          code: 'INVALID_PROVINCE_CODE',
        );
      }
    }

    return ValidationResult.ok();
  }

  /// Validate email field
  ///
  /// @api.constrains('email')
  ValidationResult validateEmail(Client client) {
    if (client.email == null || client.email!.isEmpty) {
      return ValidationResult.ok();
    }

    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(client.email!)) {
      return ValidationResult.error(
        field: 'email',
        message: 'Formato de email inválido',
        code: 'INVALID_EMAIL',
      );
    }

    return ValidationResult.ok();
  }

  /// Validate phone field
  ///
  /// @api.constrains('phone', 'mobile')
  ValidationResult validatePhone(Client client) {
    final phone = client.phone ?? client.mobile;
    if (phone == null || phone.isEmpty) {
      return ValidationResult.ok();
    }

    // Remove spaces and dashes
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Validate Ecuadorian phone format
    // Mobile: 09XXXXXXXX (10 digits)
    // Landline: 0XXXXXXXXX (9-10 digits)
    if (cleaned.length < 9 || cleaned.length > 10) {
      return ValidationResult.warning(
        field: 'phone',
        message: 'Formato de teléfono puede ser incorrecto',
        code: 'PHONE_FORMAT_WARNING',
      );
    }

    if (!RegExp(r'^0[1-9]\d{7,8}$').hasMatch(cleaned)) {
      return ValidationResult.warning(
        field: 'phone',
        message: 'Formato de teléfono puede ser incorrecto',
        code: 'PHONE_FORMAT_WARNING',
      );
    }

    return ValidationResult.ok();
  }

  /// Validate required fields
  ///
  /// @api.constrains('name')
  ValidationResult _validateRequiredFields(Client client) {
    if (client.name.isEmpty) {
      return ValidationResult.error(
        field: 'name',
        message: 'El nombre es obligatorio',
        code: 'REQUIRED_NAME',
      );
    }
    return ValidationResult.ok();
  }

  // ============ CREDIT VALIDATIONS ============

  /// Validate credit for an order
  ///
  /// This is the main entry point for credit validation.
  /// Implements the complete flow:
  /// 1. Check if partner has credit limit configured
  /// 2. Check data staleness (if offline)
  /// 3. Apply safety margin (if offline)
  /// 4. Check overdue debt issues
  /// 5. Check credit limit
  Future<CreditValidationResult> validateCreditForOrder({
    required Client client,
    required double orderAmount,
    required bool isOnline,
    Company? company,
    bool bypassCheck = false,
  }) async {
    // Skip validation if bypass flag is set
    if (bypassCheck) {
      return CreditValidationResult.ok();
    }

    // Check if partner has credit limit configured
    if (!client.hasCreditLimit) {
      return CreditValidationResult.noLimit();
    }

    // Check data staleness when offline
    if (!isOnline) {
      final isStale = await _calculator.isCreditDataStale(client);
      if (isStale) {
        return CreditValidationResult.staleData(
          hoursOld: client.hoursSinceLastCreditSync,
        );
      }
    }

    // Get effective limit (with safety margin if offline)
    final effectiveLimit = await _calculator.computeEffectiveOfflineLimit(
      client,
      isOffline: !isOnline,
    );

    // Create client with effective limit for calculations
    final effectiveClient = client.copyWith(creditLimit: effectiveLimit);

    // Check overdue debt issues
    if (effectiveClient.hasOverdueDebt) {
      final result = _validateOverdueDebt(effectiveClient, company);
      if (!result.isValid) {
        return result;
      }
    }

    // Check credit limit
    return _validateCreditLimit(effectiveClient, orderAmount, isOnline);
  }

  /// Validate overdue debt
  CreditValidationResult _validateOverdueDebt(
    Client client,
    Company? company,
  ) {
    final daysThreshold = company?.creditOverdueDaysThreshold ?? 30;
    final invoicesThreshold = company?.creditOverdueInvoicesThreshold ?? 3;

    final oldestDays = client.oldestOverdueDays ?? 0;
    final overdueCount = client.overdueInvoicesCount ?? 0;

    // Check if exceeds thresholds
    if (oldestDays >= daysThreshold || overdueCount >= invoicesThreshold) {
      final message = _buildOverdueMessage(
        client,
        daysThreshold: daysThreshold,
        invoicesThreshold: invoicesThreshold,
      );
      return CreditValidationResult.overdueDebt(message: message);
    }

    // Has overdue but under thresholds
    return CreditValidationResult.warning(
      message: 'Cliente con deudas pendientes',
      creditAvailable: client.creditAvailable,
    );
  }

  /// Validate credit limit for order
  CreditValidationResult _validateCreditLimit(
    Client client,
    double orderAmount,
    bool isOnline,
  ) {
    final creditAvailable = ClientCalculatorService.computeCreditAvailable(client);
    final exceeded = ClientCalculatorService.computeExceededAmount(client, orderAmount);

    if (exceeded != null) {
      // Partner is allowed to exceed?
      if (client.allowOverCredit) {
        return CreditValidationResult.warning(
          message: 'Crédito excedido en \$${exceeded.toStringAsFixed(2)} (permitido)',
          creditAvailable: creditAvailable,
        );
      }

      return CreditValidationResult.creditExceeded(
        creditAvailable: creditAvailable ?? 0,
        exceededAmount: exceeded,
        isOffline: !isOnline,
      );
    }

    // Check usage percentage for warning
    final usagePercentage = ClientCalculatorService.computeCreditUsagePercentage(client);
    if (usagePercentage != null && usagePercentage >= 80) {
      return CreditValidationResult.warning(
        message: 'Uso de crédito: ${usagePercentage.toStringAsFixed(1)}%',
        creditAvailable: creditAvailable,
      );
    }

    return CreditValidationResult.ok();
  }

  /// Build overdue debt message for display
  String _buildOverdueMessage(
    Client client, {
    required int daysThreshold,
    required int invoicesThreshold,
  }) {
    final messages = <String>[];

    final totalOverdue = client.totalOverdue ?? 0;
    if (totalOverdue > 0) {
      messages.add('Total vencido: \$${totalOverdue.toStringAsFixed(2)}');
    }

    final overdueCount = client.overdueInvoicesCount ?? 0;
    if (overdueCount >= invoicesThreshold) {
      messages.add('$overdueCount facturas vencidas');
    }

    final oldestDays = client.oldestOverdueDays ?? 0;
    if (oldestDays >= daysThreshold) {
      messages.add('$oldestDays días de mora');
    }

    return messages.isEmpty
        ? 'Cliente con deudas atrasadas'
        : messages.join(' • ');
  }

  // ============ FULL VALIDATION ============

  /// Execute all validations for saving a client
  ///
  /// Returns list of validation errors (empty if all valid).
  List<ValidationResult> validateForSave(Client client) {
    return [
      _validateRequiredFields(client),
      validateVat(client),
      validateEmail(client),
      validatePhone(client),
    ].where((r) => r.isError).toList();
  }

  /// Execute all validations including warnings
  ///
  /// Returns list of all validation results (errors and warnings).
  List<ValidationResult> validateWithWarnings(Client client) {
    return [
      _validateRequiredFields(client),
      validateVat(client),
      validateEmail(client),
      validatePhone(client),
    ].where((r) => !r.isValid || r.isWarning).toList();
  }
}
