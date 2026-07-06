part of '../notification_provider.dart';

// ============================================================
// ADVANCE / CREDIT NOTE / INVOICE / TAX — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

mixin _FinanceNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle advance update notification from Odoo WebSocket
  /// Updates advance in local database
  Future<void> _handleAdvanceUpdated(
    int advanceId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete advance from local DB
        await (db.delete(db.accountAdvance)
              ..where((t) => t.odooId.equals(advanceId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Advance $advanceId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert advance
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final name = values['name'] is String ? values['name'] as String : '';
      final state = values['state'] is String ? values['state'] as String : 'draft';
      final advanceType = values['advance_type'] is String ? values['advance_type'] as String : 'advance';
      final partnerType = values['partner_type'] is String ? values['partner_type'] as String : 'customer';
      final partnerId = values['partner_id'] is List
          ? (values['partner_id'] as List).first as int
          : values['partner_id'] is int ? values['partner_id'] as int : 0;
      final partnerName = values['partner_id'] is List && (values['partner_id'] as List).length > 1
          ? (values['partner_id'] as List)[1] as String?
          : values['partner_name'] is String ? values['partner_name'] as String : null;
      final partnerVat = values['partner_vat'] is String ? values['partner_vat'] as String : null;
      final companyId = values['company_id'] is List
          ? (values['company_id'] as List).first as int
          : values['company_id'] is int ? values['company_id'] as int : 1;
      final currencyId = values['currency_id'] is List
          ? (values['currency_id'] as List).first as int?
          : values['currency_id'] is int ? values['currency_id'] as int : null;
      final cashierId = values['cashier_id'] is List
          ? (values['cashier_id'] as List).first as int?
          : values['cashier_id'] is int ? values['cashier_id'] as int : null;
      final cashierName = values['cashier_id'] is List && (values['cashier_id'] as List).length > 1
          ? (values['cashier_id'] as List)[1] as String?
          : null;
      final reference = values['reference'] is String ? values['reference'] as String : null;
      final dateStr = values['date'] is String ? values['date'] as String : null;
      final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
      final dateEstimatedStr = values['date_estimated'] is String ? values['date_estimated'] as String : null;
      final dateEstimated = dateEstimatedStr != null ? DateTime.tryParse(dateEstimatedStr) : null;
      final dateDueStr = values['date_due'] is String ? values['date_due'] as String : null;
      final dateDue = dateDueStr != null ? DateTime.tryParse(dateDueStr) : null;
      final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;
      final amountUsed = (values['amount_used'] as num?)?.toDouble() ?? 0.0;
      final amountAvailable = (values['amount_available'] as num?)?.toDouble() ?? 0.0;
      final amountReturned = (values['amount_returned'] as num?)?.toDouble() ?? 0.0;
      final isExpired = values['is_expired'] as bool? ?? false;
      final collectionSessionId = values['collection_session_id'] is List
          ? (values['collection_session_id'] as List).first as int?
          : values['collection_session_id'] is int ? values['collection_session_id'] as int : null;
      final collectionConfigId = values['collection_config_id'] is List
          ? (values['collection_config_id'] as List).first as int?
          : values['collection_config_id'] is int ? values['collection_config_id'] as int : null;
      final saleOrderId = values['sale_order_id'] is List
          ? (values['sale_order_id'] as List).first as int?
          : values['sale_order_id'] is int ? values['sale_order_id'] as int : null;

      final advanceCompanion = AccountAdvanceCompanion.insert(
        odooId: advanceId,
        name: Value(name),
        state: Value(state),
        advanceType: advanceType,
        partnerType: Value(partnerType),
        partnerId: partnerId,
        partnerName: Value(partnerName),
        partnerVat: Value(partnerVat),
        companyId: Value(companyId),
        currencyId: Value(currencyId),
        cashierId: Value(cashierId),
        cashierName: Value(cashierName),
        reference: Value(reference),
        date: date,
        dateEstimated: Value(dateEstimated),
        dateDue: Value(dateDue),
        amount: Value(amount),
        amountUsed: Value(amountUsed),
        amountAvailable: Value(amountAvailable),
        amountReturned: Value(amountReturned),
        isExpired: Value(isExpired),
        collectionSessionId: Value(collectionSessionId),
        collectionConfigId: Value(collectionConfigId),
        saleOrderId: Value(saleOrderId),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountAdvance).insert(
        advanceCompanion,
        onConflict: DoUpdate(
          (old) => advanceCompanion,
          target: [db.accountAdvance.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ Advance $advanceId upserted: $name (available: $amountAvailable)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling advance update: $e');
    }
  }

  /// Handle credit note update notification from Odoo WebSocket
  /// Updates credit note in local database
  Future<void> _handleCreditNoteUpdated(
    int moveId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete credit note from local DB
        await (db.delete(db.accountCreditNote)
              ..where((t) => t.odooId.equals(moveId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ CreditNote $moveId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert credit note
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final name = values['name'] is String ? values['name'] as String : '';
      final ref = values['ref'] is String ? values['ref'] as String : null;
      final state = values['state'] is String ? values['state'] as String : 'draft';
      final partnerId = values['partner_id'] is List
          ? (values['partner_id'] as List).first as int
          : values['partner_id'] is int ? values['partner_id'] as int : 0;
      final partnerName = values['partner_id'] is List && (values['partner_id'] as List).length > 1
          ? (values['partner_id'] as List)[1] as String?
          : values['partner_name'] is String ? values['partner_name'] as String : null;
      final companyId = values['company_id'] is List
          ? (values['company_id'] as List).first as int
          : values['company_id'] is int ? values['company_id'] as int : 1;
      final dateStr = values['date'] is String ? values['date'] as String : null;
      final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
      final invoiceDateDueStr = values['invoice_date_due'] is String ? values['invoice_date_due'] as String : null;
      final invoiceDateDue = invoiceDateDueStr != null ? DateTime.tryParse(invoiceDateDueStr) : null;
      final amountTotal = (values['amount_total'] as num?)?.toDouble() ?? 0.0;
      final amountResidual = (values['amount_residual'] as num?)?.toDouble() ?? 0.0;

      final noteCompanion = AccountCreditNoteCompanion.insert(
        odooId: moveId,
        name: name,
        reference: Value(ref),
        partnerId: partnerId,
        partnerName: Value(partnerName),
        amount: Value(amountTotal),
        date: date,
        dateDue: Value(invoiceDateDue),
        state: Value(state),
        origin: Value(null), // Can be set if available
        companyId: companyId,
        companyName: Value(null), // Can be set if available
        active: const Value(true),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountCreditNote).insert(
        noteCompanion,
        onConflict: DoUpdate(
          (old) => noteCompanion,
          target: [db.accountCreditNote.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ CreditNote $moveId upserted: $name (residual: $amountResidual)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling credit note update: $e');
    }
  }

  /// Handle invoice update notification from Odoo WebSocket
  /// Updates invoice (account.move) in local database
  Future<void> _handleInvoiceUpdated(
    int moveId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete invoice from local DB
        await (db.delete(db.accountMove)
              ..where((t) => t.odooId.equals(moveId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Invoice $moveId deleted locally');
        return;
      }

      if (values == null) return;

      // Extract values from payload
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final name = values['name'] is String ? values['name'] as String : null;
      final ref = values['ref'] is String ? values['ref'] as String : null;
      final invoiceOrigin = values['invoice_origin'] is String ? values['invoice_origin'] as String : null;
      final saleOrderId = values['sale_order_id'] is List
          ? (values['sale_order_id'] as List).first as int?
          : values['sale_order_id'] is int ? values['sale_order_id'] as int : null;
      final moveType = values['move_type'] is String ? values['move_type'] as String : 'out_invoice';
      final state = values['state'] is String ? values['state'] as String : 'draft';
      final partnerId = values['partner_id'] is List
          ? (values['partner_id'] as List).first as int?
          : values['partner_id'] is int ? values['partner_id'] as int : null;
      final partnerName = values['partner_id'] is List && (values['partner_id'] as List).length > 1
          ? (values['partner_id'] as List)[1] as String?
          : values['partner_name'] is String ? values['partner_name'] as String : null;
      final partnerVat = values['partner_vat'] is String ? values['partner_vat'] as String : null;
      final journalId = values['journal_id'] is List
          ? (values['journal_id'] as List).first as int?
          : values['journal_id'] is int ? values['journal_id'] as int : null;
      final journalName = values['journal_id'] is List && (values['journal_id'] as List).length > 1
          ? (values['journal_id'] as List)[1] as String?
          : values['journal_name'] is String ? values['journal_name'] as String : null;
      final companyId = values['company_id'] is List
          ? (values['company_id'] as List).first as int?
          : values['company_id'] is int ? values['company_id'] as int : null;
      final companyName = values['company_id'] is List && (values['company_id'] as List).length > 1
          ? (values['company_id'] as List)[1] as String?
          : values['company_name'] is String ? values['company_name'] as String : null;
      final currencyId = values['currency_id'] is List
          ? (values['currency_id'] as List).first as int?
          : values['currency_id'] is int ? values['currency_id'] as int : null;
      final currencyName = values['currency_id'] is List && (values['currency_id'] as List).length > 1
          ? (values['currency_id'] as List)[1] as String?
          : values['currency_name'] is String ? values['currency_name'] as String : null;
      final amountUntaxed = (values['amount_untaxed'] as num?)?.toDouble() ?? 0.0;
      final amountTax = (values['amount_tax'] as num?)?.toDouble() ?? 0.0;
      final amountTotal = (values['amount_total'] as num?)?.toDouble() ?? 0.0;
      final amountResidual = (values['amount_residual'] as num?)?.toDouble() ?? 0.0;
      final paymentState = values['payment_state'] is String ? values['payment_state'] as String : 'not_paid';

      // Partner contact fields
      final partnerStreet = values['partner_street'] is String ? values['partner_street'] as String : null;
      final partnerCity = values['partner_city'] is String ? values['partner_city'] as String : null;
      final partnerPhone = values['partner_phone'] is String ? values['partner_phone'] as String : null;
      final partnerEmail = values['partner_email'] is String ? values['partner_email'] as String : null;
      final currencySymbol = values['currency_symbol'] is String ? values['currency_symbol'] as String : null;

      // Ecuador localization fields
      final l10nEcAuthorizationDateStr = values['l10n_ec_authorization_date'] is String ? values['l10n_ec_authorization_date'] as String : null;
      final l10nEcAuthorizationDate = l10nEcAuthorizationDateStr != null
          ? DateTime.tryParse(l10nEcAuthorizationDateStr) : null;
      final l10nEcAuthorizationNumber = values['l10n_ec_authorization_number'] is String ? values['l10n_ec_authorization_number'] as String : null;
      final l10nLatamDocumentNumber = values['l10n_latam_document_number'] is String ? values['l10n_latam_document_number'] as String : null;
      final l10nLatamDocumentTypeId = values['l10n_latam_document_type_id'] is List
          ? (values['l10n_latam_document_type_id'] as List).first as int?
          : values['l10n_latam_document_type_id'] is int ? values['l10n_latam_document_type_id'] as int : null;
      final l10nLatamDocumentTypeName = values['l10n_latam_document_type_id'] is List &&
              (values['l10n_latam_document_type_id'] as List).length > 1
          ? (values['l10n_latam_document_type_id'] as List)[1] as String?
          : values['l10n_latam_document_type_name'] is String ? values['l10n_latam_document_type_name'] as String : null;
      final l10nEcSriPaymentName = values['l10n_ec_sri_payment_name'] is String ? values['l10n_ec_sri_payment_name'] as String : null;

      // Parse dates
      DateTime? date;
      if (values['date'] is String) {
        date = DateTime.tryParse(values['date'] as String);
      }
      DateTime? invoiceDate;
      if (values['invoice_date'] is String) {
        invoiceDate = DateTime.tryParse(values['invoice_date'] as String);
      }
      DateTime? invoiceDateDue;
      if (values['invoice_date_due'] is String) {
        invoiceDateDue = DateTime.tryParse(values['invoice_date_due'] as String);
      }

      final companion = AccountMoveCompanion.insert(
        odooId: moveId,
        moveType: moveType,
        name: Value(name),
        ref: Value(ref),
        invoiceOrigin: Value(invoiceOrigin),
        saleOrderId: Value(saleOrderId),
        state: Value(state),
        date: Value(date),
        invoiceDate: Value(invoiceDate),
        invoiceDateDue: Value(invoiceDateDue),
        partnerId: Value(partnerId),
        partnerName: Value(partnerName),
        partnerVat: Value(partnerVat),
        journalId: Value(journalId),
        journalName: Value(journalName),
        companyId: Value(companyId),
        companyName: Value(companyName),
        currencyId: Value(currencyId),
        currencyName: Value(currencyName),
        amountUntaxed: Value(amountUntaxed),
        amountTax: Value(amountTax),
        amountTotal: Value(amountTotal),
        amountResidual: Value(amountResidual),
        paymentState: Value(paymentState),
        partnerStreet: Value(partnerStreet),
        partnerCity: Value(partnerCity),
        partnerPhone: Value(partnerPhone),
        partnerEmail: Value(partnerEmail),
        currencySymbol: Value(currencySymbol),
        l10nEcAuthorizationDate: Value(l10nEcAuthorizationDate),
        l10nEcAuthorizationNumber: Value(l10nEcAuthorizationNumber),
        l10nLatamDocumentNumber: Value(l10nLatamDocumentNumber),
        l10nLatamDocumentTypeId: Value(l10nLatamDocumentTypeId),
        l10nLatamDocumentTypeName: Value(l10nLatamDocumentTypeName),
        l10nEcSriPaymentName: Value(l10nEcSriPaymentName),
        isSynced: const Value(true),
        lastSyncDate: Value(DateTime.now()),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountMove).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountMove.odooId],
        ),
      );

      logger.d(
        '[NotificationProvider] ✅ Invoice $moveId upserted: $name '
        '(type=$moveType, state=$state, total=$amountTotal)',
      );
    } catch (e) {
      logger.e('[NotificationProvider] Error handling invoice update: $e');
    }
  }

  /// Handle tax update notification from Odoo WebSocket
  /// Updates tax in local database and invalidates tax calculator
  Future<void> _handleTaxUpdated(
    int taxId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete tax from local DB
        await (db.delete(db.accountTax)
              ..where((t) => t.odooId.equals(taxId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Tax $taxId deleted locally');
        // Invalidate tax calculator so prices recalculate
        ref.invalidate(taxCalculatorProvider);
        return;
      }

      if (values == null) return;

      // Extract values from payload
      // Note: Odoo sends `false` (not `null`) for empty Many2one fields,
      // so we use `is Type` checks instead of direct `as Type?` casts.
      final name = values['name'] is String ? values['name'] as String : '';
      final description = values['description'] is String ? values['description'] as String : null;
      final typeTaxUse = values['type_tax_use'] is String ? values['type_tax_use'] as String : 'sale';
      final amountType = values['amount_type'] is String ? values['amount_type'] as String : 'percent';
      final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;
      final active = values['active'] as bool? ?? true;
      final priceInclude = values['price_include'] as bool? ?? false;
      final includeBaseAmount = values['include_base_amount'] as bool? ?? false;
      final sequence = values['sequence'] as int? ?? 1;
      final companyId = values['company_id'] is List
          ? (values['company_id'] as List).first as int?
          : values['company_id'] is int ? values['company_id'] as int : null;
      final companyName = values['company_id'] is List && (values['company_id'] as List).length > 1
          ? (values['company_id'] as List)[1] as String?
          : values['company_name'] is String ? values['company_name'] as String : null;
      final taxGroupId = values['tax_group_id'] is List
          ? (values['tax_group_id'] as List).first as int?
          : values['tax_group_id'] is int ? values['tax_group_id'] as int : null;
      final taxGroupName = values['tax_group_id'] is List && (values['tax_group_id'] as List).length > 1
          ? (values['tax_group_id'] as List)[1] as String?
          : values['tax_group_name'] is String ? values['tax_group_name'] as String : null;
      final taxGroupL10nEcType = values['tax_group_l10n_ec_type'] is String ? values['tax_group_l10n_ec_type'] as String : null;

      final companion = AccountTaxCompanion.insert(
        odooId: taxId,
        name: name,
        description: Value(description),
        typeTaxUse: Value(typeTaxUse),
        amountType: Value(amountType),
        amount: Value(amount),
        active: Value(active),
        priceInclude: Value(priceInclude),
        includeBaseAmount: Value(includeBaseAmount),
        sequence: Value(sequence),
        companyId: Value(companyId),
        companyName: Value(companyName),
        taxGroupId: Value(taxGroupId),
        taxGroupName: Value(taxGroupName),
        taxGroupL10nEcType: Value(taxGroupL10nEcType),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountTax).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountTax.odooId],
        ),
      );

      // Invalidate tax calculator so prices recalculate with new tax data
      ref.invalidate(taxCalculatorProvider);

      logger.d(
        '[NotificationProvider] ✅ Tax $taxId upserted: $name '
        '($amountType: $amount%, priceInclude=$priceInclude)',
      );
    } catch (e) {
      logger.e('[NotificationProvider] Error handling tax update: $e');
    }
  }
}
