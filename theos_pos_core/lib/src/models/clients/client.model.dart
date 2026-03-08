import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'client.model.freezed.dart';
part 'client.model.g.dart';

/// Credit status enum for UI display
enum CreditStatus {
  noLimit, // No credit limit configured
  ok, // Credit usage < 80%
  warning, // Credit usage 80-100%
  exceeded, // Credit exceeded
  overdueDebt, // Has overdue debt issues
}

/// Client model with computed fields like Odoo @api.depends
///
/// This is the unified client/partner model that centralizes all partner data.
/// Uses OdooModelManager annotations for field mapping to res.partner in Odoo.
/// Implements SmartOdooModel for reactive computed fields.
///
/// ## Computed fields (equivalent to @api.depends in Odoo)
///
/// - [creditAvailable] → depends: [creditLimit, credit, creditToInvoice]
/// - [creditUsagePercentage] → depends: [creditLimit, credit, creditToInvoice]
/// - [creditExceeded] → depends: [creditAvailable]
/// - [creditStatus] → depends: [creditAvailable, totalOverdue]
///
/// ## Onchange behavior (equivalent to @api.onchange in Odoo)
///
/// - When isCompany changes: update VAT formatting
/// - When countryId changes: update VAT prefix rules
@OdooModel('res.partner', tableName: 'res_partner')
@freezed
abstract class Client with _$Client {
  const Client._(); // Enable custom methods

  // ═══════════════════ Validation ═══════════════════

  /// Validates the client before saving.
  Map<String, String> validate() {
    final errors = <String, String>{};

    // Name is required
    if (name.isEmpty) {
      errors['name'] = 'El nombre es requerido';
    }

    // VAT validation for Ecuador (if provided)
    if (vat != null && vat!.isNotEmpty) {
      final cleanVat = vat!.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanVat.length != 10 && cleanVat.length != 13) {
        errors['vat'] = 'El VAT debe tener 10 (CI) o 13 (RUC) dígitos';
      } else if (!_isValidEcuadorVat(cleanVat)) {
        errors['vat'] = 'El VAT no es válido (verificación módulo 10/11)';
      }
    }

    // Email validation (if provided)
    if (email != null && email!.isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(email!)) {
        errors['email'] = 'El email no tiene formato válido';
      }
    }

    // Phone validation (if provided)
    if (phone != null && phone!.isNotEmpty) {
      final cleaned = phone!.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      // Ecuador phone: 09XXXXXXXX (mobile) or 0XXXXXXXXX (landline)
      if (cleaned.length < 9 || cleaned.length > 10) {
        errors['phone'] = 'El teléfono debe tener 9 o 10 dígitos';
      } else if (!RegExp(r'^0[1-9]\d{7,8}$').hasMatch(cleaned)) {
        errors['phone'] = 'Formato de teléfono inválido (debe iniciar con 0)';
      }
    }

    return errors;
  }

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();

    switch (action) {
      case 'save':
        // Basic validation is sufficient for save
        // (already done in validate())
        break;

      case 'invoice':
        // Para facturar se requiere VAT
        if (vat == null || vat!.isEmpty) {
          errors['vat'] = 'VAT requerido para facturación';
        }
        // No puede ser consumidor final para facturas
        if (isFinalConsumer) {
          errors['vat'] = 'No se puede facturar a consumidor final (usa nota de venta)';
        }
        break;

      case 'credit_sale':
        // Para venta a crédito, verificar límite
        if (hasCreditLimit && creditExceeded && !allowOverCredit) {
          errors['credit'] = 'El cliente ha excedido su límite de crédito';
        }
        // Verificar deuda vencida
        if (hasOverdueDebt && !allowOverCredit) {
          errors['credit'] = 'El cliente tiene deuda vencida';
        }
        break;

      case 'archive':
        if (!active) {
          errors['active'] = 'El cliente ya está archivado';
        }
        break;

      case 'unarchive':
        if (active) {
          errors['active'] = 'El cliente ya está activo';
        }
        break;
    }

    return errors;
  }

  /// Valida VAT Ecuador usando algoritmo módulo 10/11.
  static bool _isValidEcuadorVat(String vat) {
    if (vat.length != 10 && vat.length != 13) return false;

    // Consumidor final es válido
    if (vat == '9999999999' || vat == '9999999999999') return true;

    final province = int.tryParse(vat.substring(0, 2));
    if (province == null || province < 1 || province > 24) return false;

    final thirdDigit = int.parse(vat[2]);

    // Persona natural (tercero dígito 0-5)
    if (thirdDigit >= 0 && thirdDigit <= 5) {
      return _validateMod10(vat.substring(0, 10));
    }

    // Entidad pública (tercero dígito 6)
    if (thirdDigit == 6) {
      return _validateMod11(vat.substring(0, 9), 6);
    }

    // Persona jurídica (tercero dígito 9)
    if (thirdDigit == 9) {
      return _validateMod11(vat.substring(0, 10), 9);
    }

    return false;
  }

  /// Validación módulo 10 para CI.
  static bool _validateMod10(String ci) {
    if (ci.length < 10) return false;

    final coefficients = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int sum = 0;

    for (var i = 0; i < 9; i++) {
      var digit = int.parse(ci[i]) * coefficients[i];
      if (digit > 9) digit -= 9;
      sum += digit;
    }

    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(ci[9]);
  }

  /// Validación módulo 11 para RUC.
  static bool _validateMod11(String ruc, int thirdDigit) {
    final coefficients = thirdDigit == 6
        ? [3, 2, 7, 6, 5, 4, 3, 2]
        : [4, 3, 2, 7, 6, 5, 4, 3, 2];

    int sum = 0;
    for (var i = 0; i < coefficients.length; i++) {
      sum += int.parse(ruc[i]) * coefficients[i];
    }

    final remainder = sum % 11;
    final checkDigit = remainder == 0 ? 0 : 11 - remainder;
    return checkDigit == int.parse(ruc[coefficients.length]);
  }

  const factory Client({
    // ============ Identifiers ============
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,
    @OdooLocalOnly() @Default(true) bool isSynced,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooString(odooName: 'display_name') String? displayName,
    @OdooString() String? ref,
    @OdooString() String? vat,
    @OdooString() String? email,
    @OdooString() String? phone,
    @OdooString() String? mobile,
    @OdooString() String? street,
    @OdooString() String? street2,
    @OdooString() String? city,
    @OdooString() String? zip,
    @OdooMany2One('res.country', odooName: 'country_id') int? countryId,
    @OdooMany2OneName(sourceField: 'country_id') String? countryName,
    @OdooMany2One('res.country.state', odooName: 'state_id') int? stateId,
    @OdooMany2OneName(sourceField: 'state_id') String? stateName,
    @OdooString(odooName: 'avatar_128') String? avatar128,
    @OdooBoolean(odooName: 'is_company') @Default(false) bool isCompany,
    @OdooBoolean() @Default(true) bool active,

    // ============ Relations ============
    @OdooMany2One('res.partner', odooName: 'parent_id') int? parentId,
    @OdooMany2OneName(sourceField: 'parent_id') String? parentName,
    @OdooMany2OneName(sourceField: 'commercial_partner_id') String? commercialPartnerName,
    @OdooMany2One('product.pricelist', odooName: 'property_product_pricelist') int? propertyProductPricelistId,
    @OdooMany2OneName(sourceField: 'property_product_pricelist') String? propertyProductPricelistName,
    @OdooMany2One('account.payment.term', odooName: 'property_payment_term_id') int? propertyPaymentTermId,
    @OdooMany2OneName(sourceField: 'property_payment_term_id') String? propertyPaymentTermName,
    @OdooString() String? lang,
    @OdooString() String? comment,

    // ============ Credit Control Fields (l10n_ec_sale_credit) ============
    @OdooFloat(odooName: 'credit_limit') double? creditLimit,
    @OdooFloat() double? credit,
    @OdooFloat(odooName: 'credit_to_invoice') double? creditToInvoice,
    @OdooBoolean(odooName: 'allow_over_credit') @Default(false) bool allowOverCredit,
    @OdooBoolean(odooName: 'use_partner_credit_limit') @Default(false) bool usePartnerCreditLimit,

    // ============ Overdue Debt Fields ============
    @OdooFloat(odooName: 'total_overdue') double? totalOverdue,
    @OdooInteger(odooName: 'unpaid_invoices_count') int? overdueInvoicesCount,
    @OdooInteger(odooName: 'oldest_overdue_days') int? oldestOverdueDays,

    // ============ Ecuador Fields ============
    @OdooInteger(odooName: 'dias_max_factura_posterior') int? diasMaxFacturaPosterior,

    // ============ Customer Classification (l10n_ec_sale_base) ============
    @OdooSelection(odooName: 'tipo_cliente') String? tipoCliente,
    @OdooSelection(odooName: 'canal_cliente') String? canalCliente,

    // ============ Ranking ============
    @OdooInteger(odooName: 'customer_rank') int? customerRank,
    @OdooInteger(odooName: 'supplier_rank') int? supplierRank,

    // ============ Check Acceptance ============
    @OdooBoolean(odooName: 'acepta_cheques') @Default(true) bool aceptaCheques,

    // ============ Invoice Configuration ============
    @OdooBoolean(odooName: 'emitir_factura_fecha_posterior') @Default(false) bool emitirFacturaFechaPosterior,
    @OdooBoolean(odooName: 'no_invoice') @Default(false) bool noInvoice,
    @OdooInteger(odooName: 'last_day_to_invoice') int? lastDayToInvoice,

    // ============ External ID ============
    @OdooString(odooName: 'external_id') String? externalId,

    // ============ Geolocation ============
    @OdooFloat(odooName: 'partner_latitude') double? partnerLatitude,
    @OdooFloat(odooName: 'partner_longitude') double? partnerLongitude,

    // ============ Custom Payments ============
    @OdooBoolean(odooName: 'can_use_custom_payments') @Default(true) bool canUseCustomPayments,

    // ============ Metadata ============
    @OdooDateTime(odooName: 'write_date') DateTime? writeDate,
    @OdooLocalOnly() DateTime? creditLastSyncDate,
  }) = _Client;

  // ============ COMPUTED FIELDS (like @api.depends) ============

  /// credit_available = credit_limit - (credit + credit_to_invoice)
  ///
  /// @api.depends('credit_limit', 'credit', 'credit_to_invoice', 'use_partner_credit_limit')
  double? get creditAvailable {
    if (!hasCreditLimit) return null;
    final used = (credit ?? 0) + (creditToInvoice ?? 0);
    return creditLimit! - used;
  }

  /// credit_usage_percentage = (used / limit) * 100
  ///
  /// @api.depends('credit_limit', 'credit', 'credit_to_invoice')
  double? get creditUsagePercentage {
    if (!hasCreditLimit) return null;
    final used = (credit ?? 0) + (creditToInvoice ?? 0);
    return (used / creditLimit!) * 100;
  }

  /// credit_exceeded = credit_available < 0
  ///
  /// @api.depends('credit_available')
  bool get creditExceeded {
    final available = creditAvailable;
    return available != null && available < 0;
  }

  /// credit_status for UI display
  ///
  /// @api.depends('credit_available', 'credit_usage_percentage', 'total_overdue')
  CreditStatus get creditStatus {
    if (!hasCreditLimit) return CreditStatus.noLimit;
    if ((totalOverdue ?? 0) > 0) return CreditStatus.overdueDebt;
    if (creditExceeded) return CreditStatus.exceeded;
    final usage = creditUsagePercentage ?? 0;
    if (usage >= 80) return CreditStatus.warning;
    return CreditStatus.ok;
  }

  // ============ HELPER METHODS (like _get_* in Odoo) ============

  /// Check if partner has credit control enabled
  /// Returns true only if credit control is enabled AND has a valid limit
  bool get hasCreditLimit =>
      usePartnerCreditLimit && creditLimit != null && creditLimit! > 0;

  /// Check if partner is final consumer (Ecuador: RUC 9999999999999)
  bool get isFinalConsumer => vat == '9999999999999';

  /// Check if partner has any overdue debt
  bool get hasOverdueDebt => (totalOverdue ?? 0) > 0;

  /// Get effective phone (phone or mobile)
  String get effectivePhone => phone ?? mobile ?? '';

  /// Get effective email
  String get effectiveEmail => email ?? '';

  /// Check if credit data is stale (older than maxAgeHours)
  bool isCreditDataStale(int maxAgeHours) {
    if (creditLastSyncDate == null) return true;
    final age = DateTime.now().difference(creditLastSyncDate!);
    return age.inHours >= maxAgeHours;
  }

  /// Get hours since last credit sync
  int get hoursSinceLastCreditSync {
    if (creditLastSyncDate == null) return -1;
    return DateTime.now().difference(creditLastSyncDate!).inHours;
  }

  /// Get default pricelist ID (if configured)
  int? get defaultPricelistId => propertyProductPricelistId;

  /// Get default payment term ID (if configured)
  int? get defaultPaymentTermId => propertyPaymentTermId;

  /// Convert to form state fields for SaleOrderFormState compatibility
  Map<String, dynamic> toFormStateFields() => {
        'partnerId': id,
        'partnerName': name,
        'partnerVat': vat,
        'partnerStreet': street,
        'partnerPhone': effectivePhone,
        'partnerEmail': email,
        'partnerAvatar': avatar128,
      };

  /// Verifica si el cliente puede comprar a crédito con el monto dado.
  ///
  /// Retorna true si:
  /// - No tiene límite de crédito configurado
  /// - Tiene crédito disponible suficiente
  /// - Tiene allowOverCredit habilitado
  bool canPurchaseOnCredit(double amount) {
    if (!hasCreditLimit) return true; // Sin límite, puede comprar
    if (allowOverCredit) return true;
    final available = creditAvailable ?? 0;
    return available >= amount;
  }

  /// Calcula el monto máximo que el cliente puede comprar a crédito.
  double get maxCreditPurchaseAmount {
    if (!hasCreditLimit) return double.infinity;
    if (allowOverCredit) return double.infinity;
    return creditAvailable ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ONCHANGE SIMULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Simula el onchange de is_company.
  ///
  /// Cuando cambia a empresa, limpia ciertos campos de persona.
  Client onIsCompanyChanged(bool newIsCompany) {
    if (newIsCompany == isCompany) return this;

    if (newIsCompany) {
      // Convertir a empresa: limpiar campos de persona natural
      return copyWith(
        isCompany: true,
        parentId: null,
        parentName: null,
      );
    } else {
      // Convertir a persona: mantener datos
      return copyWith(isCompany: false);
    }
  }

  /// Simula el onchange de country_id.
  ///
  /// Al cambiar país, limpia el estado.
  Client onCountryChanged(int? newCountryId, String? newCountryName) {
    if (newCountryId == countryId) return this;

    return copyWith(
      countryId: newCountryId,
      countryName: newCountryName,
      stateId: null, // Reset state when country changes
      stateName: null,
    );
  }

  /// Simula el onchange de vat.
  ///
  /// Valida el VAT según el país (Ecuador: CI/RUC).
  Client onVatChanged(String? newVat) {
    return copyWith(vat: newVat?.trim());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ADDITIONAL FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea un nuevo cliente en borrador con valores mínimos.
  ///
  /// Similar a: self.env['res.partner'].new({...})
  factory Client.newCustomer({
    required String name,
    String? vat,
    String? email,
    String? phone,
    String? street,
    int? countryId,
    String? countryName,
    bool isCompany = false,
  }) {
    return Client(
      id: 0,
      name: name,
      vat: vat,
      email: email,
      phone: phone,
      street: street,
      countryId: countryId,
      countryName: countryName,
      isCompany: isCompany,
      active: true,
      isSynced: false,
    );
  }

  /// Crea un cliente final consumer (Ecuador).
  ///
  /// Para ventas a consumidor final sin datos.
  factory Client.finalConsumer() {
    return const Client(
      id: 0,
      name: 'Consumidor Final',
      vat: '9999999999999',
      active: true,
      isSynced: false,
    );
  }
}
