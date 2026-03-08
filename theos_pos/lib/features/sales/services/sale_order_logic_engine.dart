import '../../clients/clients.dart' show CreditValidationResult, ClientCreditService;
import '../../products/repositories/product_repository.dart';
import '../../../shared/providers/company_config_provider.dart' show SalesConfig;
import 'package:theos_pos_core/theos_pos_core.dart';
import 'order_validation_types.dart';

/// Actions that can be validated by the engine
enum OrderAction {
  save, // Save changes
  confirm, // Confirm order
  cancel, // Cancel order
  approve, // Approve order (manager)
  invoice, // Generate invoice
  editLine, // Edit a line
  deleteLine, // Delete a line
}

/// Product info needed for validation (from local database)
class ProductValidationInfo {
  final int productId;
  final String name;
  final bool temporalNoDespachar;
  final double cost;

  ProductValidationInfo({
    required this.productId,
    required this.name,
    required this.temporalNoDespachar,
    required this.cost,
  });
}

/// Central logic engine for sale order business rules
///
/// This engine is the single source of truth for determining what
/// operations are allowed on a sale order based on:
/// - Current state
/// - Company configuration
/// - Partner credit status
/// - SRI Ecuador regulations
/// - Product constraints
///
/// Usage:
/// ```dart
/// final engine = ref.read(saleOrderLogicEngineProvider);
/// final result = await engine.validateAction(
///   order: order,
///   lines: lines,
///   action: OrderAction.confirm,
/// );
/// if (!result.isValid) {
///   // Show error or handle appropriately
/// }
/// ```
class SaleOrderLogicEngine {
  final Future<Company?> Function() _getCompany;
  final SalesConfig Function() _getSalesConfig;
  final ProductRepository? _productRepo;
  final ClientCreditService? _creditService;

  SaleOrderLogicEngine({
    required Future<Company?> Function() getCompany,
    required SalesConfig Function() getSalesConfig,
    ProductRepository? productRepo,
    ClientCreditService? creditService,
  })  : _getCompany = getCompany,
        _getSalesConfig = getSalesConfig,
        _productRepo = productRepo,
        _creditService = creditService;

  // ============ Main Validation Method ============

  /// Validate if an action is allowed on the given order
  ///
  /// Returns [ValidationResult] with:
  /// - `isValid`: Whether the action can proceed
  /// - `errors`: List of blocking errors
  /// - `warnings`: List of non-blocking warnings
  /// - `suggestedAction`: Recommended action (block, requireApproval, warn, proceed)
  Future<ValidationResult> validateAction({
    required SaleOrder order,
    required List<SaleOrderLine> lines,
    required OrderAction action,
    Map<String, dynamic>? context,
  }) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];

    // Get configuration
    final company = await _getCompany();
    final salesConfig = _getSalesConfig();

    switch (action) {
      case OrderAction.confirm:
        errors.addAll(
          await _validateForConfirmation(
            order: order,
            lines: lines,
            company: company,
            salesConfig: salesConfig,
            skipCreditCheck: context?['skipCreditCheck'] == true,
          ),
        );
        break;

      case OrderAction.save:
        errors.addAll(_validateForSave(order: order, lines: lines));
        break;

      case OrderAction.editLine:
        final lineId = context?['lineId'] as int?;
        final field = context?['field'] as String?;
        if (lineId != null && field != null) {
          final lineError = _validateLineEdit(
            order: order,
            lineId: lineId,
            field: field,
          );
          if (lineError != null) errors.add(lineError);
        }
        break;

      case OrderAction.cancel:
      case OrderAction.approve:
      case OrderAction.invoice:
      case OrderAction.deleteLine:
        // State validation only
        final stateError = _validateStateForAction(order.state, action);
        if (stateError != null) errors.add(stateError);
        break;
    }

    if (errors.isEmpty) {
      return warnings.isEmpty
          ? ValidationResult.success()
          : ValidationResult.successWithWarnings(warnings);
    }

    return ValidationResult.failed(errors);
  }

  // ============ State-Based Field Editability ============

  /// Check if a field can be edited given the current order state
  bool canEditField(SaleOrder order, String fieldName) {
    final editableInState = _editableFieldsByState[order.state] ?? {};
    return editableInState.contains(fieldName) ||
        editableInState.contains('*'); // * means all fields
  }

  /// Fields editable in each state
  static const Map<SaleOrderState, Set<String>> _editableFieldsByState = {
    SaleOrderState.draft: {'*'}, // All fields editable
    SaleOrderState.sent: {'*'}, // All fields editable
    SaleOrderState.waitingApproval: {
      'note',
    }, // Only notes editable while waiting
    SaleOrderState.approved: {'note'}, // Only notes editable when approved
    SaleOrderState.sale: {'note'}, // Only notes after confirmation
    SaleOrderState.done: {}, // Nothing editable
    SaleOrderState.cancel: {}, // Nothing editable
  };

  /// Get allowed state transitions from current state
  List<SaleOrderState> getAllowedTransitions(SaleOrderState current) {
    return _allowedTransitions[current] ?? [];
  }

  /// Allowed state transitions
  ///
  /// Nota: draft/sent → waitingApproval ocurre cuando:
  /// - Falla validación de crédito y se crea solicitud de aprobación
  /// - El flujo requiere aprobación de gerente antes de confirmar
  static const Map<SaleOrderState, List<SaleOrderState>> _allowedTransitions = {
    SaleOrderState.draft: [
      SaleOrderState.sent,
      SaleOrderState
          .waitingApproval, // Cuando falla crédito → solicitud aprobación
      SaleOrderState.sale,
      SaleOrderState.cancel,
    ],
    SaleOrderState.sent: [
      SaleOrderState
          .waitingApproval, // Cuando falla crédito → solicitud aprobación
      SaleOrderState.sale,
      SaleOrderState.cancel,
    ],
    SaleOrderState.waitingApproval: [
      SaleOrderState.approved,
      SaleOrderState.cancel,
    ],
    SaleOrderState.approved: [
      SaleOrderState.sale,
      SaleOrderState.cancel,
      SaleOrderState.draft,
    ],
    SaleOrderState.sale: [
      SaleOrderState.done,
      SaleOrderState.cancel,
      SaleOrderState.draft,
    ],
    SaleOrderState.done: [], // Terminal state
    SaleOrderState.cancel: [SaleOrderState.draft], // Can reset to draft
  };

  // ============ Confirmation Validation ============

  Future<List<ValidationError>> _validateForConfirmation({
    required SaleOrder order,
    required List<SaleOrderLine> lines,
    required Company? company,
    required SalesConfig salesConfig,
    required bool skipCreditCheck,
  }) async {
    final errors = <ValidationError>[];

    // 1. Partner required
    if (order.partnerId == null) {
      errors.add(ValidationError.partnerRequired());
    }

    // 2. Lines required
    final productLines = lines.where((l) => l.isProductLine).toList();
    if (productLines.isEmpty) {
      errors.add(ValidationError.linesRequired());
    }

    // 3. State validation
    final validStates = [
      SaleOrderState.draft,
      SaleOrderState.sent,
      SaleOrderState.waitingApproval,
      SaleOrderState.approved,
    ];
    if (!validStates.contains(order.state)) {
      errors.add(
        ValidationError.invalidState(
          currentState: order.state.label,
          validStates: validStates.map((s) => s.label).toList(),
        ),
      );
    }

    // 4. Final consumer limit (SRI Ecuador)
    final fcError = _validateFinalConsumerLimit(
      order: order,
      lines: lines,
      limit: salesConfig.saleCustomerInvoiceLimitSri ?? 50.0,
    );
    if (fcError != null) errors.add(fcError);

    // 5. Final consumer name required
    // Odoo SIEMPRE requiere end_customer_name cuando is_final_consumer=True
    // (constraint en l10n_ec_edi). No depende de pedirEndCustomerData.
    if (order.isFinalConsumer &&
        (order.endCustomerName == null || order.endCustomerName!.trim().isEmpty)) {
      errors.add(ValidationError.finalConsumerNameRequired());
    }

    // 6. Post-dated invoice validation
    final pdError = await _validatePostDatedInvoice(order);
    if (pdError != null) errors.add(pdError);

    // 7. Temporary products check
    final tempError = await _validateTemporaryProducts(productLines);
    if (tempError != null) errors.add(tempError);

    // 8. Maximum discount validation
    final discountErrors = _validateMaxDiscount(
      lines: productLines,
      maxDiscount: company?.maxDiscountPercentage ?? 100.0,
    );
    errors.addAll(discountErrors);

    // 9. Withhold authorization validation (49 digits)
    // Note: This is validated when a withhold is specifically registered
    // See WithholdService for the actual validation

    return errors;
  }

  // ============ Individual Validations ============

  ValidationError? _validateFinalConsumerLimit({
    required SaleOrder order,
    required List<SaleOrderLine> lines,
    required double limit,
  }) {
    if (!order.isFinalConsumer) return null;
    if (limit <= 0) return null;

    final total = lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTotal);

    if (total > limit) {
      return ValidationError.finalConsumerLimitExceeded(
        total: total,
        limit: limit,
      );
    }
    return null;
  }

  Future<ValidationError?> _validatePostDatedInvoice(SaleOrder order) async {
    if (!order.emitirFacturaFechaPosterior) return null;

    if (order.fechaFacturar == null) {
      return ValidationError.postDatedDateRequired();
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final invoiceDate = DateTime(
      order.fechaFacturar!.year,
      order.fechaFacturar!.month,
      order.fechaFacturar!.day,
    );

    if (invoiceDate.isBefore(todayDate)) {
      return ValidationError.postDatedDateInPast();
    }

    // Get max days from partner (default 7)
    int maxDays = 7;
    if (order.partnerId != null) {
      final partner = await clientManager.getPartner(order.partnerId!);
      maxDays = partner?.diasMaxFacturaPosterior ?? 7;
    }

    final maxDate = todayDate.add(Duration(days: maxDays));
    if (invoiceDate.isAfter(maxDate)) {
      return ValidationError.postDatedDateTooFar(maxDays: maxDays);
    }

    return null;
  }

  Future<ValidationError?> _validateTemporaryProducts(
    List<SaleOrderLine> lines,
  ) async {
    final tempProducts = <String>[];

    for (final line in lines) {
      if (!line.isProductLine || line.productId == null) continue;

      // Get product from local database
      final product = await _productRepo?.getById(line.productId!);
      if (product?.temporalNoDespachar == true) {
        tempProducts.add(line.productName ?? 'Producto ${line.productId}');
      }
    }

    if (tempProducts.isEmpty) return null;

    return ValidationError.temporaryProductsFound(productNames: tempProducts);
  }

  List<ValidationError> _validateMaxDiscount({
    required List<SaleOrderLine> lines,
    required double maxDiscount,
  }) {
    if (maxDiscount >= 100) return []; // No limit configured

    final errors = <ValidationError>[];
    for (final line in lines) {
      if (line.discount > maxDiscount) {
        errors.add(
          ValidationError.discountExceedsLimit(
            discount: line.discount,
            maxDiscount: maxDiscount,
            productName: line.productName,
          ),
        );
      }
    }
    return errors;
  }

  // ============ Save Validation ============

  List<ValidationError> _validateForSave({
    required SaleOrder order,
    required List<SaleOrderLine> lines,
  }) {
    final errors = <ValidationError>[];

    // Check if order is in editable state
    if (!order.isEditable) {
      errors.add(
        ValidationError(
          type: ValidationErrorType.invalidState,
          message:
              'No se pueden guardar cambios en una orden en estado "${order.state.label}".',
        ),
      );
    }

    return errors;
  }

  // ============ Line Edit Validation ============

  ValidationError? _validateLineEdit({
    required SaleOrder order,
    required int lineId,
    required String field,
  }) {
    // Check if lines can be edited in current state
    if (!order.isEditable) {
      return ValidationError.fieldNotEditable(
        fieldName: field,
        state: order.state.label,
      );
    }

    // Approved state: lines cannot be modified
    if (order.state == SaleOrderState.approved) {
      return ValidationError(
        type: ValidationErrorType.fieldNotEditable,
        message:
            'Las líneas no pueden ser modificadas en una orden aprobada. Solo se permite confirmar o cancelar.',
      );
    }

    return null;
  }

  // ============ State Validation ============

  ValidationError? _validateStateForAction(
    SaleOrderState state,
    OrderAction action,
  ) {
    switch (action) {
      case OrderAction.cancel:
        if (state == SaleOrderState.done) {
          return ValidationError(
            type: ValidationErrorType.invalidState,
            message: 'No se puede cancelar una orden completada.',
          );
        }
        break;

      case OrderAction.approve:
        if (state != SaleOrderState.waitingApproval) {
          return ValidationError(
            type: ValidationErrorType.invalidState,
            message:
                'Solo se pueden aprobar órdenes en estado "Espera Aprobación".',
          );
        }
        break;

      case OrderAction.invoice:
        // Según Odoo 19.0: permite facturar en 'approved' y 'sale'
        // - approved: Facturar sin confirmar (flujo directo)
        // - sale: Estado principal después de confirmación
        // - done: NO permitido (ya completada/entregada)
        if (state != SaleOrderState.approved && state != SaleOrderState.sale) {
          return ValidationError(
            type: ValidationErrorType.invalidState,
            message:
                'Solo se puede facturar órdenes en estado Aprobado o Confirmado.',
          );
        }
        break;

      default:
        break;
    }
    return null;
  }

  // ============ Credit Validation ============

  /// Validate credit for confirmation
  /// Returns null if validation passes, or CreditValidationResult if there's an issue
  Future<CreditValidationResult?> validateCredit({
    required SaleOrder order,
    required List<SaleOrderLine> lines,
  }) async {
    if (order.partnerId == null) return null;
    if (_creditService == null) return null;

    final orderAmount = lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTotal);

    final result = await _creditService.validateOrderCredit(
      clientId: order.partnerId!,
      orderAmount: orderAmount,
      bypassCheck: false,
    );

    return result.isValid ? null : result;
  }
}

// Provider moved to providers/service_providers.dart
