import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import 'account_move_line.model.dart';

// Re-export AccountMoveLine and related types for backwards compatibility
export 'account_move_line.model.dart';

part 'account_move.model.freezed.dart';
part 'account_move.model.g.dart';

/// Odoo model: account.move (Facturas)
///
/// ## State Machine
/// - draft -> posted (action_post)
/// - posted -> cancel (button_cancel)
/// - cancel -> draft (button_draft)
@OdooModel('account.move', tableName: 'account_move')
@freezed
abstract class AccountMove with _$AccountMove {
  const AccountMove._();

  // ═══════════════════ Validation ═══════════════════

  Map<String, String> validate() {
    final errors = <String, String>{};
    // Facturas son mayormente read-only, validacion minima
    return errors;
  }

  /// Validates for specific actions.
  Map<String, String> validateFor(String action) {
    final errors = validate();
    switch (action) {
      case 'post':
        if (!canPost) {
          errors['state'] = 'No se puede publicar la factura en estado: $state';
        }
        if (partnerId == null || partnerId == 0) {
          errors['partnerId'] = 'El cliente es requerido';
        }
        if (amountTotal <= 0 && lines.isEmpty) {
          errors['amountTotal'] = 'La factura debe tener lineas';
        }
        // Validar cada linea de producto
        for (final line in lines.where((l) => l.isProductLine)) {
          final lineErrors = line.validateFor('invoice');
          errors.addAll(lineErrors);
        }
        break;

      case 'cancel':
        if (!canCancel) {
          errors['state'] = 'No se puede cancelar la factura';
        }
        if (isPaid) {
          errors['paymentState'] = 'No se puede cancelar una factura pagada';
        }
        break;

      case 'draft':
        if (!isCancelled) {
          errors['state'] = 'Solo se puede pasar a borrador desde cancelado';
        }
        break;

      case 'send':
        if (!isPosted) {
          errors['state'] = 'Solo se pueden enviar facturas publicadas';
        }
        break;

      case 'register_payment':
        if (!isPosted) {
          errors['state'] = 'Solo se puede registrar pago en facturas publicadas';
        }
        if (!hasResidual) {
          errors['amountResidual'] = 'La factura no tiene saldo pendiente';
        }
        break;

      case 'credit_note':
        if (!isPosted) {
          errors['state'] = 'Solo se puede crear nota de credito de facturas publicadas';
        }
        break;

      case 'print':
        if (!canPrint) {
          errors['state'] = 'Solo se pueden imprimir facturas publicadas';
        }
        break;
    }
    return errors;
  }

  const factory AccountMove({
    // ============ Identifiers ============
    @OdooId() @Default(0) int id,

    // ============ Basic Data ============
    @OdooString() @Default('') String name,
    @OdooSelection(odooName: 'move_type') @Default('out_invoice') String moveType,

    // ============ Ecuador SRI Fields ============
    @OdooString(odooName: 'l10n_ec_authorization_number') String? l10nEcAuthorizationNumber,
    @OdooDateTime(odooName: 'l10n_ec_authorization_date') DateTime? l10nEcAuthorizationDate,
    @OdooString(odooName: 'l10n_latam_document_number') String? l10nLatamDocumentNumber,
    @OdooMany2One('l10n_latam.document.type', odooName: 'l10n_latam_document_type_id') int? l10nLatamDocumentTypeId,
    @OdooMany2OneName(sourceField: 'l10n_latam_document_type_id') String? l10nLatamDocumentTypeName,
    @OdooMany2OneName(sourceField: 'l10n_ec_sri_payment_id') String? l10nEcSriPaymentName,

    // ============ State ============
    @OdooSelection() @Default('draft') String state,
    @OdooSelection(odooName: 'payment_state') String? paymentState,

    // ============ Dates ============
    @OdooDate(odooName: 'invoice_date') DateTime? invoiceDate,
    @OdooDate(odooName: 'invoice_date_due') DateTime? invoiceDateDue,
    @OdooDate() DateTime? date,

    // ============ Partner ============
    @OdooMany2One('res.partner', odooName: 'partner_id') int? partnerId,
    @OdooMany2OneName(sourceField: 'partner_id') String? partnerName,
    @OdooString(odooName: 'partner_vat') String? partnerVat,
    @OdooLocalOnly() String? partnerStreet,
    @OdooLocalOnly() String? partnerCity,
    @OdooLocalOnly() String? partnerPhone,
    @OdooLocalOnly() String? partnerEmail,

    // ============ Journal ============
    @OdooMany2One('account.journal', odooName: 'journal_id') int? journalId,
    @OdooMany2OneName(sourceField: 'journal_id') String? journalName,

    // ============ Amounts ============
    @OdooFloat(odooName: 'amount_untaxed') @Default(0.0) double amountUntaxed,
    @OdooFloat(odooName: 'amount_tax') @Default(0.0) double amountTax,
    @OdooFloat(odooName: 'amount_total') @Default(0.0) double amountTotal,
    @OdooFloat(odooName: 'amount_residual') @Default(0.0) double amountResidual,

    // ============ Company and Currency ============
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,
    @OdooMany2OneName(sourceField: 'currency_id') String? currencySymbol,

    // ============ Origin and Reference ============
    @OdooString(odooName: 'invoice_origin') String? invoiceOrigin,
    @OdooString() String? ref,
    @OdooLocalOnly() int? saleOrderId,

    // ============ Invoice Lines ============
    @OdooLocalOnly() @Default([]) List<AccountMoveLine> lines,

    // ============ Sync ============
    @OdooDateTime(odooName: 'write_date') DateTime? writeDate,
    @OdooLocalOnly() DateTime? lastSyncDate,
  }) = _AccountMove;

  factory AccountMove.fromJson(Map<String, dynamic> json) =>
      _$AccountMoveFromJson(json);

  // ═══════════════════ Computed Properties ═══════════════════

  /// Check if invoice is authorized by SRI
  bool get isSriAuthorized =>
      l10nEcAuthorizationNumber != null && l10nEcAuthorizationNumber!.length == 49;

  /// Check if invoice is posted
  bool get isPosted => state == 'posted';

  /// Check if invoice is paid
  bool get isPaid => paymentState == 'paid';

  /// Get display state for UI
  String get stateDisplay {
    switch (state) {
      case 'draft':
        return 'Borrador';
      case 'posted':
        return 'Publicada';
      case 'cancel':
        return 'Cancelada';
      default:
        return state;
    }
  }

  /// Get display payment state for UI
  String get paymentStateDisplay {
    switch (paymentState) {
      case 'not_paid':
        return 'No pagada';
      case 'in_payment':
        return 'En pago';
      case 'paid':
        return 'Pagada';
      case 'partial':
        return 'Parcial';
      case 'reversed':
        return 'Reversada';
      default:
        return paymentState ?? '-';
    }
  }

  /// Get document type display name
  String get documentTypeDisplay {
    switch (moveType) {
      case 'out_invoice':
        return 'Factura';
      case 'out_refund':
        return 'Nota de Credito';
      case 'in_invoice':
        return 'Factura Proveedor';
      case 'in_refund':
        return 'Nota de Credito Proveedor';
      default:
        return moveType;
    }
  }

  /// Indica si la factura esta en borrador
  bool get isDraft => state == 'draft';

  /// Indica si la factura esta cancelada
  bool get isCancelled => state == 'cancel';

  /// Indica si se puede confirmar
  bool get canPost => isDraft;

  /// Indica si se puede cancelar
  bool get canCancel => isPosted && !isPaid;

  /// Indica si se puede reimprimir
  bool get canPrint => isPosted;

  /// Indica si tiene saldo pendiente
  bool get hasResidual => amountResidual > 0;

  // ═══════════════════ Copy Methods ═══════════════════

  /// Create a copy with updated partner data
  AccountMove copyWithPartnerData({
    String? partnerStreet,
    String? partnerCity,
    String? partnerPhone,
    String? partnerEmail,
  }) {
    return copyWith(
      partnerStreet: partnerStreet ?? this.partnerStreet,
      partnerCity: partnerCity ?? this.partnerCity,
      partnerPhone: partnerPhone ?? this.partnerPhone,
      partnerEmail: partnerEmail ?? this.partnerEmail,
    );
  }

  // ═══════════════════ Report Methods ═══════════════════

  /// Convert invoice to report context map for PDF generation
  Map<String, dynamic> toReportMap({
    Map<String, dynamic>? company,
    Map<String, dynamic>? journal,
  }) {
    String formatCurrencyEc(double value, {String symbol = '\$'}) {
      final parts = value.toFixed(2).split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
      return '$symbol $intPart,${parts[1]}';
    }

    String? formatDateEc(DateTime? date) {
      if (date == null) return null;
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }

    String getCleanDocumentTypeName(String? rawName) {
      if (rawName == null || rawName.isEmpty) return 'Factura';
      final cleaned = rawName.replaceFirst(RegExp(r'^\(\d+\)\s*'), '');
      return cleaned.isEmpty ? 'Factura' : cleaned;
    }

    String getDocumentTypeReportName(String? mType, String? rawName) {
      switch (mType) {
        case 'out_invoice':
          return 'Factura';
        case 'out_refund':
          return 'Nota de Credito';
        case 'in_invoice':
          return 'Factura Proveedor';
        case 'in_refund':
          return 'Nota de Credito Proveedor';
        default:
          return getCleanDocumentTypeName(rawName);
      }
    }

    String buildPartnerAddress() {
      final parts = <String>[];
      if (partnerStreet != null && partnerStreet!.isNotEmpty) parts.add(partnerStreet!);
      if (partnerCity != null && partnerCity!.isNotEmpty) parts.add(partnerCity!);
      if (parts.isEmpty) return '';
      parts.add('Ecuador');
      return parts.join(', ');
    }

    final symbol = currencySymbol ?? '\$';
    const symbolMap = {
      'USD': '\$', 'EUR': '\u20AC', 'GBP': '\u00A3', 'PEN': 'S/', 'COP': '\$', 'MXN': '\$',
    };
    final actualSymbol = symbolMap[symbol] ?? symbol;

    // Build company_id structure
    final companyMap = company != null
        ? <String, dynamic>{
            'id': company['id'] ?? companyId,
            'name': company['name'] ?? '',
            'l10n_ec_legal_name': company['l10n_ec_legal_name'] ?? company['name'] ?? '',
            'l10n_ec_comercial_name': company['l10n_ec_comercial_name'] ?? company['name'] ?? '',
            'l10n_ec_forced_accounting': company['l10n_ec_forced_accounting'] ?? true,
            'l10n_ec_special_taxpayer_number': company['l10n_ec_special_taxpayer_number'],
            'l10n_ec_withhold_agent_number': company['l10n_ec_withhold_agent_number'],
            'l10n_ec_production_env': company['l10n_ec_production_env'] ?? true,
            'l10n_ec_regime': company['l10n_ec_regime'],
            'display_invoice_amount_total_words': false,
            'partner_id': {
              'id': company['partner_id'] ?? 1,
              'name': company['name'] ?? '',
              'vat': company['vat'] ?? '',
              'l10n_latam_identification_type_id': {'name': 'RUC'},
            },
            'account_fiscal_country_id': {'vat_label': 'RUC'},
          }
        : <String, dynamic>{
            'id': companyId,
            'name': '',
            'partner_id': {'vat': ''},
          };

    // Build journal_id structure
    final companyStreet = company?['street'] ?? '';
    final companyStreet2 = company?['street2'] ?? '';
    final companyCity = company?['city'] ?? '';
    final companyCountry = company?['country'] ?? 'Ecuador';

    final journalMap = journal != null && journal['l10n_ec_emission_address_id'] != null
        ? <String, dynamic>{
            'id': journal['id'] ?? journalId,
            'name': journal['name'] ?? journalName ?? '',
            'l10n_ec_emission': true,
            'l10n_ec_emission_address_id': {
              'street': journal['l10n_ec_emission_address_id']['street'] ?? '',
              'street2': journal['l10n_ec_emission_address_id']['street2'] ?? '',
              'city': journal['l10n_ec_emission_address_id']['city'] ?? '',
              'country_id': {'name': journal['l10n_ec_emission_address_id']['country'] ?? 'Ecuador'},
            },
          }
        : <String, dynamic>{
            'id': journalId,
            'name': journalName ?? '',
            'l10n_ec_emission': companyStreet.isNotEmpty,
            'l10n_ec_emission_address_id': companyStreet.isNotEmpty
                ? {
                    'street': companyStreet,
                    'street2': companyStreet2,
                    'city': companyCity,
                    'country_id': {'name': companyCountry},
                  }
                : null,
          };

    // Build lines_to_report
    final filteredLines = lines.where((l) => l.isProductLine || l.isSection || l.isNote).toList();
    final linesToReport = filteredLines.map((l) => l.toReportMap()).toList();

    // Calculate effective amounts
    double effectiveAmountUntaxed = amountUntaxed;
    double effectiveAmountTax = amountTax;
    double effectiveAmountTotal = amountTotal;

    if (lines.isNotEmpty && (amountTotal.abs() < 0.01 || id <= 0)) {
      double calcUntaxed = 0.0;
      double calcTax = 0.0;
      double calcTotal = 0.0;

      for (final line in lines) {
        if (line.isReportLine) {
          calcUntaxed += line.priceSubtotal;
          calcTax += (line.priceTotal - line.priceSubtotal);
          calcTotal += line.priceTotal;
        }
      }

      if (amountTotal.abs() < 0.01) {
        effectiveAmountUntaxed = calcUntaxed;
        effectiveAmountTax = calcTax;
        effectiveAmountTotal = calcTotal;
      }
    }

    final result = <String, dynamic>{
      'id': id,
      'name': name,
      'move_type': moveType,
      'state': state,
      'payment_state': paymentState,
      'l10n_ec_authorization_number': l10nEcAuthorizationNumber,
      'l10n_latam_document_number': l10nLatamDocumentNumber ?? name,
      'l10n_latam_document_type_id': l10nLatamDocumentTypeId != null
          ? {
              'id': l10nLatamDocumentTypeId,
              'name': getCleanDocumentTypeName(l10nLatamDocumentTypeName),
              'report_name': getDocumentTypeReportName(moveType, l10nLatamDocumentTypeName),
            }
          : {'name': 'Factura', 'report_name': 'Factura'},
      'l10n_ec_sri_payment_id': l10nEcSriPaymentName != null
          ? {'name': l10nEcSriPaymentName}
          : {'name': 'Sin utilizacion del sistema financiero'},
      'l10n_latam_internal_type': moveType == 'out_refund' ? 'credit_note' : 'invoice',
      'l10n_ec_authorization_date': l10nEcAuthorizationDate != null
          ? '${l10nEcAuthorizationDate!.day.toString().padLeft(2, '0')}/${l10nEcAuthorizationDate!.month.toString().padLeft(2, '0')}/${l10nEcAuthorizationDate!.year} ${l10nEcAuthorizationDate!.hour.toString().padLeft(2, '0')}:${l10nEcAuthorizationDate!.minute.toString().padLeft(2, '0')}:${l10nEcAuthorizationDate!.second.toString().padLeft(2, '0')}'
          : null,
      'company_id': companyMap,
      'journal_id': journalMap,
      'invoice_date': formatDateEc(invoiceDate),
      'invoice_date_due': formatDateEc(invoiceDateDue),
      'date': formatDateEc(date),
      'partner_id': {
        'id': partnerId,
        'name': partnerName ?? '',
        'vat': partnerVat ?? '',
        'street': partnerStreet ?? '',
        'city': partnerCity ?? '',
        'phone': partnerPhone ?? '',
        'email': partnerEmail ?? '',
        'ref': '',
        'l10n_latam_identification_type_id': {'name': 'RUC'},
        'display_address': buildPartnerAddress(),
        '_display_address': ([bool withoutCompany = false]) => buildPartnerAddress(),
      },
      'amount_untaxed': effectiveAmountUntaxed,
      'amount_tax': effectiveAmountTax,
      'amount_total': effectiveAmountTotal,
      'amount_residual': amountResidual,
      'formatted_amount_untaxed': formatCurrencyEc(effectiveAmountUntaxed, symbol: actualSymbol),
      'formatted_amount_tax': formatCurrencyEc(effectiveAmountTax, symbol: actualSymbol),
      'formatted_amount_total': formatCurrencyEc(effectiveAmountTotal, symbol: actualSymbol),
      'formatted_amount_residual': formatCurrencyEc(amountResidual, symbol: actualSymbol),
      'currency_id': {'id': currencyId ?? 1, 'name': symbol, 'symbol': actualSymbol},
      'invoice_origin': invoiceOrigin,
      'ref': ref ?? '',
      'tax_totals': {
        'amount_untaxed': effectiveAmountUntaxed,
        'amount_total': effectiveAmountTotal,
        'total_amount_currency': effectiveAmountTotal,
        'formatted_amount_untaxed': formatCurrencyEc(effectiveAmountUntaxed, symbol: actualSymbol),
        'formatted_amount_total': formatCurrencyEc(effectiveAmountTotal, symbol: actualSymbol),
        'subtotals': [
          {
            'name': 'Subtotal',
            'amount': effectiveAmountUntaxed,
            'base_amount_currency': effectiveAmountUntaxed,
            'formatted_amount': formatCurrencyEc(effectiveAmountUntaxed, symbol: actualSymbol),
            'tax_groups': effectiveAmountTax > 0
                ? [
                    {
                      'group_name': 'IVA 15%',
                      'tax_group_name': 'IVA 15%',
                      'tax_amount_currency': effectiveAmountTax,
                      'base_amount_currency': effectiveAmountUntaxed,
                      'formatted_tax_group_amount': formatCurrencyEc(effectiveAmountTax, symbol: actualSymbol),
                    },
                  ]
                : <Map<String, dynamic>>[],
          },
        ],
        'groups_by_subtotal': {
          'Subtotal': effectiveAmountTax > 0
              ? [
                  {
                    'group_name': 'IVA 15%',
                    'tax_group_name': 'IVA 15%',
                    'tax_group_amount': effectiveAmountTax,
                    'formatted_tax_group_amount': formatCurrencyEc(effectiveAmountTax, symbol: actualSymbol),
                  },
                ]
              : <Map<String, dynamic>>[],
        },
      },
      'display_taxes': effectiveAmountTax > 0,
      'display_discount': lines.any((l) => l.discount > 0),
      'proforma': false,
      'company_price_include': 'tax_excluded',
      'lines_to_report': linesToReport,
      'invoice_line_ids': linesToReport,
      'tax_line_ids': lines.where((l) => l.isTaxLine).map((l) => l.toReportMap()).toList(),
      'line_ids': lines.map((l) => l.toReportMap()).toList(),
      'with_context': (Map<String, dynamic>? ctx) => toReportMap(company: company, journal: journal),
      '_get_move_lines_to_report': () => linesToReport,
      '_l10n_ec_get_payment_data': () => [
        {
          'name': 'Sin utilizacion del sistema financiero',
          'payment_total': effectiveAmountTotal,
          'formatted_payment_total': formatCurrencyEc(effectiveAmountTotal, symbol: actualSymbol),
        },
      ],
      '_l10n_ec_get_invoice_additional_info': () => <String, dynamic>{
        'ID Interno': id.toString(),
        'Vendedor': 'Administrator',
        'E-mail': partnerEmail ?? '',
        'Vencimiento': formatDateEc(invoiceDateDue),
      },
      '_l10n_ec_is_withholding': () => false,
    };

    return result;
  }
}
