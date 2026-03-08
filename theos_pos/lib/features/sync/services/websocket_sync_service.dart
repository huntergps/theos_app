import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import '../../../core/services/websocket/odoo_websocket_service.dart';
import '../repositories/catalog_sync_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

// Field mappings are now centralized in OdooFieldRegistry (theos_pos_core).
// Use OdooFieldRegistry.getFieldMapping(model) instead of the old const map.

/// Result of a field-level sync attempt
enum SyncFieldResult {
  /// Field was synced successfully (no local modifications)
  synced,

  /// Field was skipped (locally modified, no conflict)
  skippedLocallyModified,

  /// Conflict detected (field modified locally AND server sent different value)
  conflict,

  /// Field not found in server payload
  notInPayload,
}

/// Result of processing a WebSocket update for a record
class SyncResult {
  final String model;
  final int recordId;
  final String? recordName;
  final String action; // 'created', 'updated', 'deleted'

  /// Fields that were successfully synced from server
  final List<String> syncedFields;

  /// Fields that were skipped because they are locally modified
  final List<String> skippedFields;

  /// Fields with conflicts (local and server both changed)
  final List<String> conflictFields;

  /// Whether any conflicts were detected
  bool get hasConflicts => conflictFields.isNotEmpty;

  /// Whether any fields were synced
  bool get hasSyncedFields => syncedFields.isNotEmpty;

  SyncResult({
    required this.model,
    required this.recordId,
    this.recordName,
    required this.action,
    this.syncedFields = const [],
    this.skippedFields = const [],
    this.conflictFields = const [],
  });

  @override
  String toString() {
    return 'SyncResult(model: $model, recordId: $recordId, action: $action, '
        'synced: ${syncedFields.length}, skipped: ${skippedFields.length}, '
        'conflicts: ${conflictFields.length})';
  }
}

/// Service that handles intelligent WebSocket synchronization with field-level
/// conflict detection.
///
/// This service:
/// 1. Tracks which fields have been modified locally (dirty fields)
/// 2. When WebSocket updates arrive, only syncs fields not modified locally
/// 3. Detects conflicts when server sends updates for locally modified fields
/// 4. Creates conflict records for user resolution
class WebSocketSyncService {
  final AppDatabase _db;
  final AppOdooWebSocketService _wsService;
  final CatalogSyncRepository? _catalogRepo;

  /// Callback to get current user (replaces _ref.read(userProvider))
  final User? Function()? getCurrentUser;

  /// Callback to refresh current user permissions (replaces _ref.read(userProvider.notifier).fetchUser())
  final Future<void> Function()? onRefreshCurrentUser;

  /// Callback to set withhold lines from server (replaces _ref.read(posWithholdLinesByOrderProvider.notifier).setLinesFromServer)
  final void Function(int orderId, List<WithholdLine> lines)? onWithholdLinesUpdate;

  /// Callback to invalidate sale order UI state (replaces _ref.invalidate(saleOrdersProvider) etc.)
  final void Function()? onSaleOrdersInvalidate;

  /// Callback to invalidate a specific sale order (replaces _ref.invalidate(saleOrderWithLinesProvider(id)))
  final void Function(int orderId)? onSaleOrderInvalidate;

  /// Callback to check if an order is open in FastSale and get update data
  /// Returns true if the order is open in a tab
  final bool Function(int orderId)? isOrderOpenInFastSale;

  /// Callback to update an order from WebSocket in FastSale
  final void Function(int orderId, Map<String, dynamic> updateData)? onFastSaleOrderUpdate;

  StreamSubscription<OdooWebSocketEvent>? _wsSubscription;

  /// In-memory tracking of records currently being edited
  final _editingRecords = <String>{};

  /// Callback for when conflicts are detected
  Function(SyncResult result)? onConflictDetected;

  /// Callback for successful sync (even partial)
  Function(SyncResult result)? onSyncCompleted;

  WebSocketSyncService({
    required AppDatabase db,
    required AppOdooWebSocketService wsService,
    CatalogSyncRepository? catalogRepo,
    this.getCurrentUser,
    this.onRefreshCurrentUser,
    this.onWithholdLinesUpdate,
    this.onSaleOrdersInvalidate,
    this.onSaleOrderInvalidate,
    this.isOrderOpenInFastSale,
    this.onFastSaleOrderUpdate,
  })  : _db = db,
        _wsService = wsService,
        _catalogRepo = catalogRepo;

  /// Initialize the service and start listening to WebSocket notifications
  void initialize() {
    // Subscribe to typed events
    _wsSubscription = _wsService.addEventListener((event) {
      if (event is OdooRawNotificationEvent) {
        _handleNotification({'type': event.type, 'payload': event.payload});
      }
    });

    logger.i('[WebSocketSync]', 'Service initialized');
  }

  /// Handle incoming WebSocket notification
  void _handleNotification(Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final payload = notification['payload'];

    logger.d('[WebSocketSync]', '📨 Received notification: type=$type');

    if (type == null || payload is! Map<String, dynamic>) {
      logger.w('[WebSocketSync]', 'Invalid notification format: type=$type, payload=${payload.runtimeType}');
      return;
    }

    // Route to appropriate handler based on type
    switch (type) {
      case 'sale_order_updated':
        _handleSaleOrderUpdate(payload);
        break;
      case 'partner_updated':
        _handlePartnerUpdate(payload);
        break;
      case 'company_updated':
        _handleCompanyUpdate(payload);
        break;
      case 'user_updated':
        _handleUserUpdate(payload);
        break;
      case 'product_updated':
        _handleProductUpdate(payload);
        break;
      case 'sale_order_withhold_updated':
        _handleWithholdUpdate(payload);
        break;
      case 'invoice_updated':
        _handleInvoiceUpdate(payload);
        break;
    }
  }

  /// Handle sale order updates
  Future<void> _handleSaleOrderUpdate(Map<String, dynamic> payload) async {
    final orderId = payload['order_id'] as int?;
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;
    final changedFields = (payload['changed_fields'] as List?)?.cast<String>();

    if (orderId == null || action == null) {
      logger.w('[WebSocketSync]', 'Invalid sale order update payload: orderId=$orderId, action=$action');
      return;
    }

    logger.i('[WebSocketSync]', '🔄 Processing sale.order $action: id=$orderId, changedFields=$changedFields');
    if (values != null && values.containsKey('state')) {
      logger.i('[WebSocketSync]', '📌 State change detected: ${values['state']}');
    }

    if (action == 'deleted') {
      // For deletes, we don't need conflict detection
      // Just mark the local record if it exists
      await _handleRecordDeleted('sale.order', orderId, payload['order_name']);
      return;
    }

    if (values == null) return;

    final result = await _processUpdate(
      model: 'sale.order',
      recordId: orderId,
      recordName: payload['order_name'] as String?,
      serverValues: values,
      changedFields: changedFields ?? values.keys.toList(),
      action: action,
    );

    _notifyResult(result);
  }

  /// Handle partner/customer updates
  Future<void> _handlePartnerUpdate(Map<String, dynamic> payload) async {
    final partnerId = payload['partner_id'] as int?;
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;
    final changedFields = (payload['changed_fields'] as List?)?.cast<String>();

    if (partnerId == null || action == null) return;

    logger.d(
      '[WebSocketSync]',
      'Processing res.partner $action: id=$partnerId',
    );

    if (action == 'deleted') {
      await _handleRecordDeleted(
        'res.partner',
        partnerId,
        payload['partner_name'],
      );
      return;
    }

    if (values == null) return;

    // When image_1920 changes, we need to also update avatar_128
    // because image_1920 is the source field but avatar_128 is what we store
    var fieldsToSync = changedFields ?? values.keys.toList();
    logger.d(
      '[WebSocketSync]',
      'Partner $partnerId original changedFields: $changedFields',
    );
    logger.d(
      '[WebSocketSync]',
      'Partner $partnerId has avatar_128 in values: ${values.containsKey('avatar_128')}',
    );
    if (fieldsToSync.contains('image_1920') && values.containsKey('avatar_128')) {
      fieldsToSync = [...fieldsToSync, 'avatar_128'];
      final avatarPreview = values['avatar_128']?.toString().substring(0, 50);
      logger.d(
        '[WebSocketSync]',
        'Added avatar_128 to fieldsToSync. Preview: $avatarPreview...',
      );
    }

    // When any credit field changes, sync ALL related credit fields
    // because Odoo only sends 'credit_limit' or 'allow_over_credit' in changed_fields
    // but the computed fields (credit, total_overdue, etc.) come in values
    const creditTriggerFields = [
      'credit_limit',
      'allow_over_credit',
      'use_partner_credit_limit',
    ];
    const allCreditFields = [
      'credit_limit',
      'credit',
      'credit_to_invoice',
      'allow_over_credit',
      'use_partner_credit_limit',
      'total_overdue',
      'unpaid_invoices_count',
    ];
    if (fieldsToSync.any((f) => creditTriggerFields.contains(f))) {
      final additionalFields = <String>[];
      for (final field in allCreditFields) {
        if (values.containsKey(field) && !fieldsToSync.contains(field)) {
          additionalFields.add(field);
        }
      }
      if (additionalFields.isNotEmpty) {
        fieldsToSync = [...fieldsToSync, ...additionalFields];
        logger.d(
          '[WebSocketSync]',
          'Added credit fields to fieldsToSync: $additionalFields',
        );
      }
    }

    logger.d('[WebSocketSync]', 'Partner $partnerId fieldsToSync: $fieldsToSync');

    final result = await _processUpdate(
      model: 'res.partner',
      recordId: partnerId,
      recordName: payload['partner_name'] as String?,
      serverValues: values,
      changedFields: fieldsToSync,
      action: action,
    );

    _notifyResult(result);
  }

  /// Handle company updates
  Future<void> _handleCompanyUpdate(Map<String, dynamic> payload) async {
    final companyId = payload['company_id'] as int?;
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;
    final changedFields = (payload['changed_fields'] as List?)?.cast<String>();

    if (companyId == null || action == null) return;

    logger.d(
      '[WebSocketSync]',
      'Processing res.company $action: id=$companyId',
    );

    if (action == 'deleted') {
      await _handleRecordDeleted(
        'res.company',
        companyId,
        payload['company_name'],
      );
      return;
    }

    if (values == null) return;

    final result = await _processUpdate(
      model: 'res.company',
      recordId: companyId,
      recordName: payload['company_name'] as String?,
      serverValues: values,
      changedFields: changedFields ?? values.keys.toList(),
      action: action,
    );

    _notifyResult(result);
  }

  /// Handle user updates
  Future<void> _handleUserUpdate(Map<String, dynamic> payload) async {
    final userId = payload['user_id'] as int?;
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;
    final changedFields = (payload['changed_fields'] as List?)?.cast<String>();

    if (userId == null || action == null) return;

    logger.d('[WebSocketSync]', 'Processing res.users $action: id=$userId');

    // Check if permissions (group_ids) changed - sync from Odoo
    final groupsChanged = changedFields != null &&
        (changedFields.contains('group_ids') ||
            changedFields.contains('groups_id') ||
            changedFields.contains('all_group_ids'));

    if (groupsChanged) {
      try {
        // Sync user's group memberships from Odoo to local database
        if (_catalogRepo != null) {
          await _catalogRepo.syncUserGroups(userId);
          logger.i(
            '[WebSocketSync]',
            'Synced group memberships for user $userId',
          );
        }

        // Refresh current user's permissions if it's them
        // IMPORTANT: User.id is the Odoo ID - userId from WebSocket is Odoo ID
        final currentUser = getCurrentUser?.call();
        if (currentUser != null && currentUser.id == userId) {
          logger.i(
            '[WebSocketSync]',
            'Permissions changed for current user - Refreshing...',
          );
          await onRefreshCurrentUser?.call();
        }
      } catch (e) {
        logger.e('[WebSocketSync]', 'Error syncing user groups: $e');
      }
    }

    if (action == 'deleted') {
      await _handleRecordDeleted('res.users', userId, payload['user_name']);
      return;
    }

    if (values == null) return;

    final result = await _processUpdate(
      model: 'res.users',
      recordId: userId,
      recordName: payload['user_name'] as String?,
      serverValues: values,
      changedFields: changedFields ?? values.keys.toList(),
      action: action,
    );

    _notifyResult(result);
  }

  /// Handle product updates
  Future<void> _handleProductUpdate(Map<String, dynamic> payload) async {
    final productId = payload['product_id'] as int?;
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;
    final changedFields = (payload['changed_fields'] as List?)?.cast<String>();

    if (productId == null || action == null) return;

    logger.d(
      '[WebSocketSync]',
      'Processing product.product $action: id=$productId',
    );

    if (action == 'deleted') {
      await _handleRecordDeleted(
        'product.product',
        productId,
        payload['product_name'],
      );
      return;
    }

    if (values == null) return;

    final result = await _processUpdate(
      model: 'product.product',
      recordId: productId,
      recordName: payload['product_name'] as String?,
      serverValues: values,
      changedFields: changedFields ?? values.keys.toList(),
      action: action,
    );

    _notifyResult(result);
  }

  /// Handle withhold line updates from Odoo
  Future<void> _handleWithholdUpdate(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final saleId = payload['sale_id'] as int?;
    final saleName = payload['sale_name'] as String?;

    if (saleId == null || action == null) {
      logger.w('[WebSocketSync]', 'Invalid withhold update payload: saleId=$saleId, action=$action');
      return;
    }

    logger.i('[WebSocketSync]', '🔄 Processing withhold update: action=$action, saleId=$saleId, saleName=$saleName');

    // For bulk_update action, replace all withhold lines for this order
    if (action == 'bulk_update') {
      final withholdLinesData = payload['withhold_lines'] as List<dynamic>?;
      final totalWithhold = (payload['total_withhold'] as num?)?.toDouble() ?? 0.0;
      final lineCount = payload['line_count'] as int? ?? 0;

      logger.i('[WebSocketSync]', '📋 Withhold bulk update: $lineCount lines, total=$totalWithhold');

      // Parse withhold lines from server data
      final lines = <WithholdLine>[];
      if (withholdLinesData != null) {
        for (final lineData in withholdLinesData) {
          try {
            final data = lineData as Map<String, dynamic>;
            // Create WithholdLine from server notification data
            lines.add(WithholdLine(
              id: data['id'] as int? ?? 0,
              lineUuid: const Uuid().v4(),
              taxId: data['tax_id'] as int? ?? 0,
              taxName: data['tax_name'] as String? ?? 'Retención',
              taxPercent: (data['tax_amount'] as num?)?.toDouble() ?? 0.0,
              withholdType: WithholdType.fromCode(data['withhold_type']) ?? WithholdType.incomeSale,
              taxSupportCode: TaxSupportCode.fromCode(data['taxsupport_code']),
              base: (data['base'] as num?)?.toDouble() ?? 0.0,
              amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
              notes: data['notes'] as String?,
            ));
          } catch (e) {
            logger.w('[WebSocketSync]', 'Error parsing withhold line: $e');
          }
        }
      }

      // Save to local database for offline-first
      try {
        await _saveWithholdLinesToDb(saleId, withholdLinesData ?? []);
        logger.i('[WebSocketSync]', '💾 Withhold lines saved to DB for order $saleId');
      } catch (e) {
        logger.e('[WebSocketSync]', 'Error saving withhold lines to DB: $e');
      }

      // Update the withhold lines provider (in-memory)
      try {
        onWithholdLinesUpdate?.call(saleId, lines);
        logger.i('[WebSocketSync]', '✅ Withhold lines updated for order $saleId: ${lines.length} lines');
      } catch (e) {
        logger.e('[WebSocketSync]', 'Error updating withhold provider: $e');
      }
    }
  }

  /// Save withhold lines to local database
  Future<void> _saveWithholdLinesToDb(int orderId, List<dynamic> linesData) async {
    // Delete existing lines for this order
    await (_db.delete(_db.saleOrderWithholdLine)
          ..where((t) => t.orderId.equals(orderId)))
        .go();

    // Insert new lines
    for (final lineData in linesData) {
      final data = lineData as Map<String, dynamic>;
      final taxName = data['tax_name'] as String? ?? 'Retención';

      // Infer withhold type from tax name if not provided
      String withholdType = data['withhold_type'] as String? ?? 'withhold_income_sale';
      if (data['withhold_type'] == null) {
        // Determine from tax name: IVA = withhold_vat_sale, otherwise income
        if (taxName.toLowerCase().contains('iva')) {
          withholdType = 'withhold_vat_sale';
        }
      }

      final companion = SaleOrderWithholdLineCompanion.insert(
        odooId: Value(data['id'] as int?),
        orderId: orderId,
        sequence: Value(data['sequence'] as int? ?? 10),
        taxId: data['tax_id'] as int? ?? 0,
        taxName: taxName,
        taxPercent: Value((data['tax_amount'] as num?)?.toDouble() ?? 0.0),
        withholdType: withholdType,
        taxsupportCode: Value(data['taxsupport_code'] as String?),
        base: Value((data['base'] as num?)?.toDouble() ?? 0.0),
        amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
        notes: Value(data['notes'] as String?),
        isSynced: const Value(true),
        lastSyncDate: Value(DateTime.now()),
      );
      await _db.into(_db.saleOrderWithholdLine).insert(companion);
    }
  }

  /// Handle invoice updates from WebSocket
  ///
  /// When an invoice is created/updated in Odoo, sync it to local DB
  /// This enables offline-first viewing and reprinting of invoices
  Future<void> _handleInvoiceUpdate(Map<String, dynamic> payload) async {
    final invoiceId = payload['invoice_id'] as int?;
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;
    final changedFields = (payload['changed_fields'] as List?)?.cast<String>();
    final orderId = payload['order_id'] as int?;

    if (invoiceId == null || action == null) {
      logger.w('[WebSocketSync]', 'Invalid invoice update payload: invoiceId=$invoiceId, action=$action');
      return;
    }

    logger.i('[WebSocketSync]', '🧾 Processing account.move $action: id=$invoiceId, orderId=$orderId, changedFields=$changedFields');

    if (action == 'deleted') {
      // Delete local invoice
      await (_db.delete(_db.accountMove)
            ..where((t) => t.odooId.equals(invoiceId)))
          .go();
      logger.i('[WebSocketSync]', '🗑️ Invoice $invoiceId deleted from local DB');
      _notifyUIUpdate('account.move', invoiceId, {}, ['deleted']);
      return;
    }

    if (values == null) return;

    // Parse invoice data and save to local DB
    try {
      await _upsertInvoiceFromPayload(invoiceId, values, orderId);
      logger.i('[WebSocketSync]', '✅ Invoice $invoiceId synced to local DB');

      // Notify UI about invoice update
      _notifyUIUpdate('account.move', invoiceId, values, changedFields ?? values.keys.toList());

      // Also update the sale order invoice_status if included
      if (orderId != null && values.containsKey('state')) {
        // Invalidate sale order providers to refresh invoice data
        onSaleOrdersInvalidate?.call();
      }
    } catch (e) {
      logger.e('[WebSocketSync]', 'Error syncing invoice $invoiceId: $e');
    }
  }

  /// Upsert invoice from WebSocket payload to local DB
  Future<void> _upsertInvoiceFromPayload(
    int invoiceId,
    Map<String, dynamic> values,
    int? orderId,
  ) async {
    // Parse many2one fields
    int? partnerId;
    String? partnerName;
    if (values['partner_id'] is List && (values['partner_id'] as List).isNotEmpty) {
      partnerId = values['partner_id'][0] as int;
      partnerName = values['partner_id'][1] as String;
    } else if (values['partner_id'] is int) {
      partnerId = values['partner_id'];
    }

    int? journalId;
    String? journalName;
    if (values['journal_id'] is List && (values['journal_id'] as List).isNotEmpty) {
      journalId = values['journal_id'][0] as int;
      journalName = values['journal_id'][1] as String;
    } else if (values['journal_id'] is int) {
      journalId = values['journal_id'];
    }

    int? companyId;
    if (values['company_id'] is List && (values['company_id'] as List).isNotEmpty) {
      companyId = values['company_id'][0] as int;
    } else if (values['company_id'] is int) {
      companyId = values['company_id'];
    }

    int? currencyId;
    String? currencyName;
    if (values['currency_id'] is List && (values['currency_id'] as List).isNotEmpty) {
      currencyId = values['currency_id'][0] as int;
      currencyName = values['currency_id'][1] as String;
    } else if (values['currency_id'] is int) {
      currencyId = values['currency_id'];
    }

    int? docTypeId;
    String? docTypeName;
    if (values['l10n_latam_document_type_id'] is List &&
        (values['l10n_latam_document_type_id'] as List).isNotEmpty) {
      docTypeId = values['l10n_latam_document_type_id'][0] as int;
      docTypeName = values['l10n_latam_document_type_id'][1] as String;
    }

    String? sriPaymentName;
    if (values['l10n_ec_sri_payment_id'] is List &&
        (values['l10n_ec_sri_payment_id'] as List).isNotEmpty) {
      sriPaymentName = values['l10n_ec_sri_payment_id'][1] as String;
    }

    final companion = AccountMoveCompanion.insert(
      odooId: invoiceId,
      name: Value(values['name'] as String?),
      moveType: values['move_type'] as String? ?? 'out_invoice',
      l10nEcAuthorizationNumber: Value(
        values['l10n_ec_authorization_number'] as String?,
      ),
      l10nLatamDocumentNumber: Value(
        values['l10n_latam_document_number'] as String?,
      ),
      l10nLatamDocumentTypeId: Value(docTypeId),
      l10nLatamDocumentTypeName: Value(docTypeName),
      l10nEcSriPaymentName: Value(sriPaymentName),
      state: Value(values['state'] as String? ?? 'draft'),
      paymentState: Value(values['payment_state'] as String? ?? 'not_paid'),
      invoiceDate: Value(
        values['invoice_date'] != null && values['invoice_date'] != false
            ? DateTime.tryParse('${values['invoice_date']}')
            : null,
      ),
      invoiceDateDue: Value(
        values['invoice_date_due'] != null && values['invoice_date_due'] != false
            ? DateTime.tryParse('${values['invoice_date_due']}')
            : null,
      ),
      date: Value(
        values['date'] != null && values['date'] != false
            ? DateTime.tryParse('${values['date']}')
            : null,
      ),
      partnerId: Value(partnerId),
      partnerName: Value(partnerName),
      partnerVat: Value(values['partner_vat'] as String?),
      journalId: Value(journalId),
      journalName: Value(journalName),
      amountUntaxed: Value((values['amount_untaxed'] as num?)?.toDouble() ?? 0.0),
      amountTax: Value((values['amount_tax'] as num?)?.toDouble() ?? 0.0),
      amountTotal: Value((values['amount_total'] as num?)?.toDouble() ?? 0.0),
      amountResidual: Value((values['amount_residual'] as num?)?.toDouble() ?? 0.0),
      companyId: Value(companyId),
      currencyId: Value(currencyId),
      currencyName: Value(currencyName),
      invoiceOrigin: Value(values['invoice_origin'] as String?),
      ref: Value(values['ref'] as String?),
      saleOrderId: Value(orderId),
      writeDate: Value(
        values['write_date'] != null && values['write_date'] != false
            ? DateTime.tryParse('${values['write_date']}Z')
            : null,
      ),
      lastSyncDate: Value(DateTime.now()),
    );

    await _db.into(_db.accountMove).insert(
          companion,
          onConflict: DoUpdate(
            (old) => AccountMoveCompanion.custom(
              name: Variable(values['name'] as String? ?? ''),
              moveType: Variable(values['move_type'] as String? ?? 'out_invoice'),
              l10nEcAuthorizationNumber: Variable(
                values['l10n_ec_authorization_number'] as String?,
              ),
              l10nLatamDocumentNumber: Variable(
                values['l10n_latam_document_number'] as String?,
              ),
              l10nLatamDocumentTypeId: Variable(docTypeId),
              l10nLatamDocumentTypeName: Variable(docTypeName),
              l10nEcSriPaymentName: Variable(sriPaymentName),
              state: Variable(values['state'] as String? ?? 'draft'),
              paymentState: Variable(values['payment_state'] as String?),
              invoiceDate: Variable(
                values['invoice_date'] != null && values['invoice_date'] != false
                    ? DateTime.tryParse('${values['invoice_date']}')
                    : null,
              ),
              invoiceDateDue: Variable(
                values['invoice_date_due'] != null && values['invoice_date_due'] != false
                    ? DateTime.tryParse('${values['invoice_date_due']}')
                    : null,
              ),
              date: Variable(
                values['date'] != null && values['date'] != false
                    ? DateTime.tryParse('${values['date']}')
                    : null,
              ),
              partnerId: Variable(partnerId),
              partnerName: Variable(partnerName),
              partnerVat: Variable(values['partner_vat'] as String?),
              journalId: Variable(journalId),
              journalName: Variable(journalName),
              amountUntaxed: Variable((values['amount_untaxed'] as num?)?.toDouble() ?? 0.0),
              amountTax: Variable((values['amount_tax'] as num?)?.toDouble() ?? 0.0),
              amountTotal: Variable((values['amount_total'] as num?)?.toDouble() ?? 0.0),
              amountResidual: Variable((values['amount_residual'] as num?)?.toDouble() ?? 0.0),
              companyId: Variable(companyId),
              currencyId: Variable(currencyId),
              currencyName: Variable(currencyName),
              invoiceOrigin: Variable(values['invoice_origin'] as String?),
              ref: Variable(values['ref'] as String?),
              saleOrderId: Variable(orderId),
              writeDate: Variable(
                values['write_date'] != null && values['write_date'] != false
                    ? DateTime.tryParse('${values['write_date']}Z')
                    : null,
              ),
              lastSyncDate: Variable(DateTime.now()),
            ),
            target: [_db.accountMove.odooId],
          ),
        );
  }

  /// Process an update with field-level conflict detection
  Future<SyncResult> _processUpdate({
    required String model,
    required int recordId,
    String? recordName,
    required Map<String, dynamic> serverValues,
    required List<String> changedFields,
    required String action,
  }) async {
    final syncedFields = <String>[];
    final skippedFields = <String>[];
    final conflictFields = <String>[];

    // Get dirty fields for this record
    final dirtyFieldsQuery = _db.select(_db.dirtyFields)
      ..where((t) => t.model.equals(model) & t.recordId.equals(recordId));
    final dirtyFieldsList = await dirtyFieldsQuery.get();
    final dirtyFieldsMap = {for (var df in dirtyFieldsList) df.fieldName: df};

    // Check if record is currently being edited (in-memory tracking)
    final isEditing = _editingRecords.contains('$model:$recordId');

    // Process each changed field
    for (final fieldName in changedFields) {
      final serverValue = serverValues[fieldName];
      final dirtyField = dirtyFieldsMap[fieldName];

      if (dirtyField == null) {
        // Field not modified locally - safe to sync
        syncedFields.add(fieldName);
      } else {
        // Field was modified locally
        final localValue = dirtyField.localValue;
        final serverValueJson = jsonEncode(serverValue);

        if (localValue == serverValueJson) {
          // Same value - no conflict, can clear dirty flag
          syncedFields.add(fieldName);
          await _clearDirtyField(model, recordId, fieldName);
        } else {
          // Different values - conflict!
          conflictFields.add(fieldName);

          // Create conflict record
          await _createConflict(
            model: model,
            recordId: recordId,
            recordName: recordName,
            fieldName: fieldName,
            localValue: localValue,
            serverValue: serverValueJson,
            serverWriteDate: serverValues['write_date'] != null
                ? DateTime.tryParse(serverValues['write_date'].toString())
                : null,
          );

          // If editing, keep the local value (skip this field)
          if (isEditing) {
            skippedFields.add(fieldName);
          }
        }
      }
    }

    // ========== PERFORM ACTUAL DATABASE UPDATE ==========
    // Only update fields that are safe to sync (not in conflict and not being edited)
    if (syncedFields.isNotEmpty) {
      final fieldsToUpdate = syncedFields.toSet();
      // Remove conflict fields from update
      fieldsToUpdate.removeAll(conflictFields);
      // Remove skipped fields from update
      fieldsToUpdate.removeAll(skippedFields);

      if (fieldsToUpdate.isNotEmpty) {
        try {
          final updateCount = await _applyFieldUpdates(
            model: model,
            recordId: recordId,
            serverValues: serverValues,
            fieldsToUpdate: fieldsToUpdate.toList(),
            action: action,
          );

          if (updateCount > 0) {
            logger.i(
              '[WebSocketSync]',
              '$model[$recordId]: Updated $updateCount fields in local DB',
            );

            // Notify UI about the update by invalidating providers
            _notifyUIUpdate(model, recordId, serverValues, fieldsToUpdate.toList());
          } else if (action == 'created') {
            logger.i(
              '[WebSocketSync]',
              '$model[$recordId]: Inserted new record in local DB',
            );

            // Notify UI about the new record
            _notifyUIUpdate(model, recordId, serverValues, fieldsToUpdate.toList());
          }
        } catch (e) {
          logger.e(
            '[WebSocketSync]',
            'Error applying updates to $model[$recordId]: $e',
          );
        }
      }
    }

    // Log results
    logger.i(
      '[WebSocketSync]',
      '$model[$recordId] $action: '
          'synced=${syncedFields.length}, skipped=${skippedFields.length}, '
          'conflicts=${conflictFields.length}',
    );

    return SyncResult(
      model: model,
      recordId: recordId,
      recordName: recordName,
      action: action,
      syncedFields: syncedFields,
      skippedFields: skippedFields,
      conflictFields: conflictFields,
    );
  }

  /// Apply field updates to the local database
  /// Returns the number of rows affected
  Future<int> _applyFieldUpdates({
    required String model,
    required int recordId,
    required Map<String, dynamic> serverValues,
    required List<String> fieldsToUpdate,
    required String action,
  }) async {
    switch (model) {
      case 'sale.order':
        return _updateSaleOrder(recordId, serverValues, fieldsToUpdate, action);
      case 'res.partner':
        return _updatePartner(recordId, serverValues, fieldsToUpdate, action);
      case 'product.product':
        return _updateProduct(recordId, serverValues, fieldsToUpdate, action);
      case 'res.company':
        return _updateCompany(recordId, serverValues, fieldsToUpdate, action);
      case 'res.users':
        return _updateUser(recordId, serverValues, fieldsToUpdate, action);
      default:
        logger.w('[WebSocketSync]', 'Unknown model for update: $model');
        return 0;
    }
  }

  /// Update sale.order record
  Future<int> _updateSaleOrder(
    int odooId,
    Map<String, dynamic> values,
    List<String> fieldsToUpdate,
    String action,
  ) async {
    // Check if record exists
    final existingQuery = _db.select(_db.saleOrder)
      ..where((t) => t.odooId.equals(odooId));
    final existing = await existingQuery.getSingleOrNull();

    if (existing == null && action == 'created') {
      // Insert new record
      await _db
          .into(_db.saleOrder)
          .insert(
            SaleOrderCompanion.insert(
              odooId: odooId,
              name: values['name']?.toString() ?? 'New Order',
              state: Value(values['state']?.toString() ?? 'draft'),
              dateOrder: Value(_parseDateTime(values['date_order'])),
              partnerId: Value(_extractId(values['partner_id'])),
              partnerName: Value(
                _extractName(values['partner_id'], values['partner_name']),
              ),
              userId: Value(_extractId(values['user_id'])),
              userName: Value(
                _extractName(values['user_id'], values['user_name']),
              ),
              companyId: Value(_extractId(values['company_id'])),
              companyName: Value(
                _extractName(values['company_id'], values['company_name']),
              ),
              amountUntaxed: Value(
                (values['amount_untaxed'] as num?)?.toDouble() ?? 0.0,
              ),
              amountTax: Value(
                (values['amount_tax'] as num?)?.toDouble() ?? 0.0,
              ),
              amountTotal: Value(
                (values['amount_total'] as num?)?.toDouble() ?? 0.0,
              ),
              writeDate: Value(_parseDateTime(values['write_date'])),
              isSynced: const Value(true),
              lastSyncDate: Value(DateTime.now()),
            ),
          );
      return 1;
    }

    if (existing == null) {
      logger.w('[WebSocketSync]', 'sale.order[$odooId] not found for update');
      return 0;
    }

    // Build dynamic update companion
    final companion = _buildCompanion('sale.order', values, fieldsToUpdate);
    companion['isSynced'] = const Value(true);
    companion['lastSyncDate'] = Value(DateTime.now());

    // Use raw SQL for partial update
    return _executePartialUpdate('sale_order', 'odoo_id', odooId, companion);
  }

  /// Update res.partner record
  Future<int> _updatePartner(
    int odooId,
    Map<String, dynamic> values,
    List<String> fieldsToUpdate,
    String action,
  ) async {
    final existingQuery = _db.select(_db.resPartner)
      ..where((t) => t.odooId.equals(odooId));
    final existing = await existingQuery.getSingleOrNull();

    if (existing == null && action == 'created') {
      await _db
          .into(_db.resPartner)
          .insert(
            ResPartnerCompanion.insert(
              odooId: odooId,
              name: values['name']?.toString() ?? 'New Partner',
              displayName: Value(values['display_name']?.toString()),
              vat: Value(values['vat']?.toString()),
              email: Value(values['email']?.toString()),
              phone: Value(values['phone']?.toString()),
              mobile: Value(values['mobile']?.toString()),
              street: Value(values['street']?.toString()),
              city: Value(values['city']?.toString()),
              countryId: Value(_extractId(values['country_id'])),
              countryName: Value(
                _extractName(values['country_id'], values['country_name']),
              ),
              stateId: Value(_extractId(values['state_id'])),
              stateName: Value(
                _extractName(values['state_id'], values['state_name']),
              ),
              isCompany: Value(values['is_company'] == true),
              active: Value(values['active'] != false),
              avatar128: Value(values['avatar_128']?.toString()),
              writeDate: Value(_parseDateTime(values['write_date'])),
              isSynced: const Value(true),
            ),
          );
      return 1;
    }

    if (existing == null) {
      logger.w('[WebSocketSync]', 'res.partner[$odooId] not found for update');
      return 0;
    }

    final companion = _buildCompanion('res.partner', values, fieldsToUpdate);
    final updateCount =
        await _executePartialUpdate('res_partner', 'odoo_id', odooId, companion);

    // Also update cached partner data in sale_order records
    // This ensures that orders showing this partner get the updated avatar/info
    if (fieldsToUpdate.contains('avatar_128') ||
        fieldsToUpdate.contains('name') ||
        fieldsToUpdate.contains('vat') ||
        fieldsToUpdate.contains('phone') ||
        fieldsToUpdate.contains('email') ||
        fieldsToUpdate.contains('street')) {
      try {
        await _updateSaleOrderPartnerCache(odooId, values);
      } catch (e) {
        logger.w(
          '[WebSocketSync]',
          'Error updating sale_order partner cache: $e',
        );
      }
    }

    return updateCount;
  }

  /// Update cached partner data in sale_order records
  Future<void> _updateSaleOrderPartnerCache(
    int partnerId,
    Map<String, dynamic> values,
  ) async {
    logger.d('[WebSocketSync]', '_updateSaleOrderPartnerCache called for partner $partnerId');
    logger.d('[WebSocketSync]', 'Values keys: ${values.keys.toList()}');

    final updates = <String, dynamic>{};

    if (values.containsKey('avatar_128')) {
      updates['partner_avatar'] = values['avatar_128'];
      final preview = values['avatar_128']?.toString().substring(0, 50);
      logger.d('[WebSocketSync]', 'Will update partner_avatar. Preview: $preview...');
    }
    if (values.containsKey('name')) {
      updates['partner_name'] = values['name'];
    }
    if (values.containsKey('vat')) {
      updates['partner_vat'] = values['vat'];
    }
    if (values.containsKey('phone')) {
      updates['partner_phone'] = values['phone'];
    }
    if (values.containsKey('email')) {
      updates['partner_email'] = values['email'];
    }
    if (values.containsKey('street')) {
      updates['partner_street'] = values['street'];
    }

    if (updates.isEmpty) {
      logger.d('[WebSocketSync]', 'No updates to apply to sale_order');
      return;
    }

    // Build SET clause
    final setClauses = updates.keys.map((k) => '$k = ?').join(', ');
    final setValues = updates.values.toList();

    logger.d('[WebSocketSync]', 'Executing: UPDATE sale_order SET $setClauses WHERE partner_id = $partnerId');
    logger.d('[WebSocketSync]', 'Update keys: ${updates.keys.toList()}');

    await _db.customStatement(
      'UPDATE sale_order SET $setClauses WHERE partner_id = ?',
      [...setValues, partnerId],
    );

    logger.i(
      '[WebSocketSync]',
      'Updated partner cache in sale_order for partner_id=$partnerId, fields=${updates.keys.toList()}',
    );
  }

  /// Update product.product record
  Future<int> _updateProduct(
    int odooId,
    Map<String, dynamic> values,
    List<String> fieldsToUpdate,
    String action,
  ) async {
    final existingQuery = _db.select(_db.productProduct)
      ..where((t) => t.odooId.equals(odooId));
    final existing = await existingQuery.getSingleOrNull();

    if (existing == null && action == 'created') {
      await _db
          .into(_db.productProduct)
          .insert(
            ProductProductCompanion.insert(
              odooId: odooId,
              name: values['name']?.toString() ?? 'New Product',
              displayName: Value(values['display_name']?.toString()),
              defaultCode: Value(values['default_code']?.toString()),
              barcode: Value(values['barcode']?.toString()),
              type: Value(values['type']?.toString() ?? 'consu'),
              saleOk: Value(values['sale_ok'] != false),
              active: Value(values['active'] != false),
              listPrice: Value(
                (values['list_price'] as num?)?.toDouble() ?? 0.0,
              ),
              standardPrice: Value(
                (values['standard_price'] as num?)?.toDouble() ?? 0.0,
              ),
              categId: Value(_extractId(values['categ_id'])),
              categName: Value(
                _extractName(values['categ_id'], values['categ_name']),
              ),
              uomId: Value(_extractId(values['uom_id'])),
              uomName: Value(
                _extractName(values['uom_id'], values['uom_name']),
              ),
              writeDate: Value(_parseDateTime(values['write_date'])),
            ),
          );
      return 1;
    }

    if (existing == null) {
      logger.w(
        '[WebSocketSync]',
        'product.product[$odooId] not found for update',
      );
      return 0;
    }

    final companion = _buildCompanion('product.product', values, fieldsToUpdate);
    return _executePartialUpdate(
      'product_product',
      'odoo_id',
      odooId,
      companion,
    );
  }

  /// Update res.company record
  Future<int> _updateCompany(
    int odooId,
    Map<String, dynamic> values,
    List<String> fieldsToUpdate,
    String action,
  ) async {
    final existingQuery = _db.select(_db.resCompanyTable)
      ..where((t) => t.odooId.equals(odooId));
    final existing = await existingQuery.getSingleOrNull();

    if (existing == null) {
      // Companies are usually pre-populated, so we don't auto-create
      logger.w('[WebSocketSync]', 'res.company[$odooId] not found for update');
      return 0;
    }

    final companion = _buildCompanion('res.company', values, fieldsToUpdate);
    return _executePartialUpdate(
      'res_company_table',
      'odoo_id',
      odooId,
      companion,
    );
  }

  /// Update res.users record
  Future<int> _updateUser(
    int odooId,
    Map<String, dynamic> values,
    List<String> fieldsToUpdate,
    String action,
  ) async {
    final existingQuery = _db.select(_db.resUsers)
      ..where((t) => t.odooId.equals(odooId));
    final existing = await existingQuery.getSingleOrNull();

    if (existing == null) {
      // Users are usually pre-populated, so we don't auto-create
      logger.w('[WebSocketSync]', 'res.users[$odooId] not found for update');
      return 0;
    }

    final companion = _buildCompanion('res.users', values, fieldsToUpdate);
    return _executePartialUpdate('res_users', 'odoo_id', odooId, companion);
  }

  /// Execute a partial update using raw SQL for only the specified fields
  Future<int> _executePartialUpdate(
    String tableName,
    String idColumn,
    int idValue,
    Map<String, Value<dynamic>> companion,
  ) async {
    if (companion.isEmpty) return 0;

    final setParts = <String>[];
    final args = <dynamic>[];

    companion.forEach((column, value) {
      if (value.present) {
        setParts.add('$column = ?');
        args.add(value.value);
      }
    });

    if (setParts.isEmpty) return 0;

    args.add(idValue);
    final sql =
        'UPDATE $tableName SET ${setParts.join(', ')} WHERE $idColumn = ?';

    return _db.customUpdate(
      sql,
      variables: args.map((a) => Variable(a)).toList(),
    );
  }

  // ========== GENERIC COMPANION BUILDER ==========

  /// Build a Drift companion map for any model using OdooFieldRegistry type info.
  ///
  /// Replaces the 5 model-specific _build*Companion methods by using the
  /// centralized field type definitions to determine how to convert each value.
  Map<String, Value<dynamic>> _buildCompanion(
    String model,
    Map<String, dynamic> values,
    List<String> fieldsToUpdate,
  ) {
    final companion = <String, Value<dynamic>>{};
    final fieldDefs = OdooFieldRegistry.getFieldDefMap(model);

    for (final odooField in fieldsToUpdate) {
      final fieldDef = fieldDefs[odooField];
      if (fieldDef == null || !values.containsKey(odooField)) continue;

      final value = values[odooField];
      final column = fieldDef.columnName;

      switch (fieldDef.type) {
        case OdooFieldType.string:
        case OdooFieldType.selection:
          companion[column] = Value(value?.toString());
        case OdooFieldType.integer:
          companion[column] = Value(_extractInt(value));
        case OdooFieldType.many2one:
          companion[column] = Value(_extractId(value));
        case OdooFieldType.double_:
          companion[column] = Value(_parseDouble(value));
        case OdooFieldType.boolean:
          companion[column] = Value(value == true);
        case OdooFieldType.datetime:
          companion[column] = Value(_parseDateTime(value));
        case OdooFieldType.many2many:
          if (value is List) {
            companion[column] = Value(jsonEncode(value));
          }
        case OdooFieldType.serialized:
          if (value is List) {
            companion[column] = Value(value.map((e) => e.toString()).join(','));
          } else if (value is String) {
            companion[column] = Value(value);
          }
      }
    }

    // Post-processing: recalculate derived credit fields for partners
    if (model == 'res.partner') {
      final creditFields = {'credit_limit', 'credit', 'credit_to_invoice', 'total_overdue'};
      if (fieldsToUpdate.any((f) => creditFields.contains(f))) {
        _recalculateCreditFields(companion, values);
      }
    }

    return companion;
  }

  /// Recalculate derived credit fields when credit data changes
  void _recalculateCreditFields(
    Map<String, Value<dynamic>> companion,
    Map<String, dynamic> values,
  ) {
    final creditLimit = _parseDouble(values['credit_limit']);
    final credit = _parseDouble(values['credit']);
    final creditToInvoice = _parseDouble(values['credit_to_invoice']);
    final usePartnerCreditLimit = values['use_partner_credit_limit'] == true;

    // Only calculate if credit control is enabled AND has a valid limit
    if (usePartnerCreditLimit && creditLimit != null && creditLimit > 0) {
      final creditUsed = (credit ?? 0) + (creditToInvoice ?? 0);
      final creditAvailable = creditLimit - creditUsed;
      final creditUsagePercentage = (creditUsed / creditLimit) * 100;
      final creditExceeded = creditAvailable < 0;

      companion['credit_available'] = Value(creditAvailable);
      companion['credit_usage_percentage'] = Value(creditUsagePercentage);
      companion['credit_exceeded'] = Value(creditExceeded);
      companion['credit_last_sync_date'] = Value(DateTime.now());
    } else {
      // Credit control disabled - clear calculated fields
      companion['credit_available'] = const Value(null);
      companion['credit_usage_percentage'] = const Value(null);
      companion['credit_exceeded'] = const Value(false);
      companion['credit_last_sync_date'] = Value(DateTime.now());
    }
  }

  /// Parse a dynamic value to double
  double? _parseDouble(dynamic val) {
    if (val == null || val == false) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  /// Extract an integer value from dynamic input
  int? _extractInt(dynamic val) {
    if (val == null || val == false) return null;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  // ========== UTILITY METHODS ==========

  // Delegate to package utilities
  int? _extractId(dynamic value) => odoo.extractMany2oneId(value);
  String? _extractName(dynamic value, [String? fallback]) =>
      odoo.extractMany2oneName(value) ?? fallback;
  DateTime? _parseDateTime(dynamic value) => odoo.parseOdooDateTime(value);

  /// Handle deleted records
  Future<void> _handleRecordDeleted(
    String model,
    int recordId,
    String? recordName,
  ) async {
    // Check if there are pending local changes
    final dirtyFieldsQuery = _db.select(_db.dirtyFields)
      ..where((t) => t.model.equals(model) & t.recordId.equals(recordId));
    final dirtyFieldsList = await dirtyFieldsQuery.get();

    if (dirtyFieldsList.isNotEmpty) {
      // Record has local changes but was deleted on server
      // Create a special conflict for this case
      await _createConflict(
        model: model,
        recordId: recordId,
        recordName: recordName,
        fieldName: '_deleted_',
        localValue: 'Record has local changes',
        serverValue: 'Record was deleted on server',
        serverWriteDate: DateTime.now(),
      );

      final result = SyncResult(
        model: model,
        recordId: recordId,
        recordName: recordName,
        action: 'deleted',
        conflictFields: ['_deleted_'],
      );

      _notifyResult(result);
    } else {
      // No local changes - safe to delete locally
      try {
        await _deleteLocalRecord(model, recordId);
        logger.i('[WebSocketSync]', '$model[$recordId] deleted from local DB');
      } catch (e) {
        logger.e('[WebSocketSync]', 'Error deleting $model[$recordId]: $e');
      }

      final result = SyncResult(
        model: model,
        recordId: recordId,
        recordName: recordName,
        action: 'deleted',
        syncedFields: ['_all_'],
      );

      _notifyResult(result);
    }
  }

  /// Delete a record from local database
  Future<void> _deleteLocalRecord(String model, int odooId) async {
    switch (model) {
      case 'sale.order':
        // Delete related child records first
        // 1. Sale order lines
        await (_db.delete(
          _db.saleOrderLine,
        )..where((t) => t.orderId.equals(odooId))).go();
        // 2. Withhold lines
        await (_db.delete(
          _db.saleOrderWithholdLine,
        )..where((t) => t.orderId.equals(odooId))).go();
        // 3. Payment lines (if any)
        await (_db.delete(
          _db.saleOrderPaymentLine,
        )..where((t) => t.orderId.equals(odooId))).go();
        // 4. Invoices related to this order
        final invoices = await (_db.select(_db.accountMove)
              ..where((t) => t.saleOrderId.equals(odooId)))
            .get();
        for (final invoice in invoices) {
          // Delete invoice lines first
          await (_db.delete(
            _db.accountMoveLine,
          )..where((t) => t.moveId.equals(invoice.odooId))).go();
          // Then delete invoice
          await (_db.delete(
            _db.accountMove,
          )..where((t) => t.odooId.equals(invoice.odooId))).go();
        }
        // 5. Finally delete the order itself
        await (_db.delete(
          _db.saleOrder,
        )..where((t) => t.odooId.equals(odooId))).go();
        logger.i('[WebSocketSync]', '🗑️ Deleted sale.order[$odooId] with all child records');
        break;
      case 'res.partner':
        await (_db.delete(
          _db.resPartner,
        )..where((t) => t.odooId.equals(odooId))).go();
        break;
      case 'product.product':
        await (_db.delete(
          _db.productProduct,
        )..where((t) => t.odooId.equals(odooId))).go();
        break;
      case 'res.company':
        // Generally we don't delete companies, just mark inactive
        logger.w('[WebSocketSync]', 'Skipping delete for res.company[$odooId]');
        break;
      case 'res.users':
        // Generally we don't delete users, just mark inactive
        logger.w('[WebSocketSync]', 'Skipping delete for res.users[$odooId]');
        break;
      case 'account.move':
        // Delete invoice lines first
        await (_db.delete(
          _db.accountMoveLine,
        )..where((t) => t.moveId.equals(odooId))).go();
        // Then delete the invoice
        await (_db.delete(
          _db.accountMove,
        )..where((t) => t.odooId.equals(odooId))).go();
        break;
      case 'account.move.line':
        await (_db.delete(
          _db.accountMoveLine,
        )..where((t) => t.odooId.equals(odooId))).go();
        break;
      case 'sale.order.line':
        await (_db.delete(
          _db.saleOrderLine,
        )..where((t) => t.odooId.equals(odooId))).go();
        break;
      case 'sale.order.withhold.line':
        await (_db.delete(
          _db.saleOrderWithholdLine,
        )..where((t) => t.odooId.equals(odooId))).go();
        break;
      case 'sale.order.payment.line':
        await (_db.delete(
          _db.saleOrderPaymentLine,
        )..where((t) => t.odooId.equals(odooId))).go();
        break;
      default:
        logger.w('[WebSocketSync]', 'Unknown model for delete: $model');
    }
  }

  /// Create a conflict record in the database
  Future<void> _createConflict({
    required String model,
    required int recordId,
    String? recordName,
    required String fieldName,
    String? localValue,
    String? serverValue,
    DateTime? serverWriteDate,
  }) async {
    final localData = jsonEncode({
      'field': fieldName,
      'value': localValue,
      'record_name': recordName,
    });
    final remoteData = jsonEncode({
      'field': fieldName,
      'value': serverValue,
      'write_date': serverWriteDate?.toIso8601String(),
    });

    await _db.into(_db.syncConflict).insert(
      SyncConflictCompanion.insert(
        model: model,
        localId: recordId,
        remoteId: recordId,
        conflictType: 'both_modified',
        localData: localData,
        remoteData: remoteData,
        detectedAt: DateTime.now(),
      ),
    );

    logger.w(
      '[WebSocketSync]',
      'Conflict detected: $model[$recordId].$fieldName',
    );
  }

  /// Clear a dirty field (after successful sync or same value)
  Future<void> _clearDirtyField(
    String model,
    int recordId,
    String fieldName,
  ) async {
    await (_db.delete(_db.dirtyFields)..where(
          (t) =>
              t.model.equals(model) &
              t.recordId.equals(recordId) &
              t.fieldName.equals(fieldName),
        ))
        .go();
  }

  /// Notify callbacks of sync results
  void _notifyResult(SyncResult result) {
    if (result.hasConflicts) {
      onConflictDetected?.call(result);
    }

    onSyncCompleted?.call(result);
  }

  /// Notify UI about database updates
  ///
  /// Invalidates relevant providers based on the model type so the UI
  /// reflects the latest data from the database.
  void _notifyUIUpdate(
    String model,
    int recordId,
    Map<String, dynamic> serverValues,
    List<String> updatedFields,
  ) {
    logger.i('[WebSocketSync]', '🔔 Notifying UI for $model[$recordId], fields=$updatedFields');

    switch (model) {
      case 'sale.order':
        // Invalidate the orders list providers to refresh the list
        logger.d('[WebSocketSync]', 'Invalidating saleOrdersProvider and saleOrdersStreamProvider');
        onSaleOrdersInvalidate?.call();

        // Invalidate the specific order provider
        onSaleOrderInvalidate?.call(recordId);

        // Update FastSale provider if the order is open in a tab
        final isOrderOpen = isOrderOpenInFastSale?.call(recordId) ?? false;

        if (isOrderOpen) {
          // Build update data from server values using Odoo field names
          final updateData = <String, dynamic>{};
          for (final field in updatedFields) {
            // Find the Odoo field name from local column name
            final saleMapping = OdooFieldRegistry.getFieldMapping('sale.order');
            final entry = saleMapping.entries
                .where((e) => e.value == field)
                .firstOrNull;
            final odooField = entry?.key ?? field;
            if (serverValues.containsKey(odooField)) {
              updateData[odooField] = serverValues[odooField];
            }
          }

          if (updateData.isNotEmpty) {
            logger.i(
              '[WebSocketSync]',
              'Notifying FastSale about order $recordId update: ${updateData.keys.toList()}',
            );
            onFastSaleOrderUpdate?.call(recordId, updateData);
          }
        }

        logger.d('[WebSocketSync]', 'UI notified for sale.order[$recordId]');
        break;

      case 'res.partner':
        // Partner updates - just log for now
        logger.d('[WebSocketSync]', 'Partner updated: $recordId');
        break;

      case 'product.product':
        // Product updates - just log for now
        logger.d('[WebSocketSync]', 'Product updated: $recordId');
        break;

      default:
        logger.d('[WebSocketSync]', 'No UI notification for model: $model');
    }
  }

  // ============ Public API for marking dirty fields ============

  /// Mark a field as modified locally (called when user edits a field)
  Future<void> markFieldDirty({
    required String model,
    required int recordId,
    required String fieldName,
    String? originalValue,
    String? localValue,
    bool isEditing = false,
  }) async {
    await _db
        .into(_db.dirtyFields)
        .insertOnConflictUpdate(
          DirtyFieldsCompanion.insert(
            model: model,
            recordId: recordId,
            fieldName: fieldName,
            oldValue: Value(originalValue),
            localValue: Value(localValue),
            modifiedAt: DateTime.now(),
          ),
        );

    if (isEditing) {
      _editingRecords.add('$model:$recordId');
    }

    logger.d('[WebSocketSync]', 'Marked dirty: $model[$recordId].$fieldName');
  }

  /// Mark a record as being edited (in-memory tracking)
  Future<void> setRecordEditing({
    required String model,
    required int recordId,
    required bool isEditing,
  }) async {
    final key = '$model:$recordId';
    if (isEditing) {
      _editingRecords.add(key);
    } else {
      _editingRecords.remove(key);
    }
    logger.d('[WebSocketSync]', 'Set editing=$isEditing for $model[$recordId]');
  }

  /// Clear all dirty fields for a record (after successful sync to server)
  Future<void> clearRecordDirtyFields({
    required String model,
    required int recordId,
  }) async {
    await (_db.delete(
      _db.dirtyFields,
    )..where((t) => t.model.equals(model) & t.recordId.equals(recordId))).go();

    logger.d('[WebSocketSync]', 'Cleared dirty fields for $model[$recordId]');
  }

  /// Get all dirty fields for a record
  Future<List<DirtyField>> getDirtyFields({
    required String model,
    required int recordId,
  }) async {
    final query = _db.select(_db.dirtyFields)
      ..where((t) => t.model.equals(model) & t.recordId.equals(recordId));
    return query.get();
  }

  /// Check if a specific field is dirty
  Future<bool> isFieldDirty({
    required String model,
    required int recordId,
    required String fieldName,
  }) async {
    final query = _db.select(_db.dirtyFields)
      ..where(
        (t) =>
            t.model.equals(model) &
            t.recordId.equals(recordId) &
            t.fieldName.equals(fieldName),
      );
    final result = await query.getSingleOrNull();
    return result != null;
  }

  // ============ Conflict Resolution API ============

  /// Get pending conflicts for a model/record
  Future<List<SyncConflictData>> getPendingConflicts({
    String? model,
    int? recordId,
  }) async {
    var query = _db.select(_db.syncConflict)
      ..where((t) => t.isResolved.equals(false));

    if (model != null) {
      query = query..where((t) => t.model.equals(model));
    }
    if (recordId != null) {
      query = query..where((t) => t.localId.equals(recordId));
    }

    return query.get();
  }

  /// Resolve a conflict by accepting local value
  Future<void> resolveConflictLocalWins(int conflictId) async {
    await (_db.update(_db.syncConflict)
          ..where((t) => t.id.equals(conflictId)))
        .write(SyncConflictCompanion(
      resolution: const Value('local_wins'),
      resolvedAt: Value(DateTime.now()),
      isResolved: const Value(true),
    ));
  }

  /// Resolve a conflict by accepting server value
  Future<void> resolveConflictServerWins(int conflictId) async {
    await (_db.update(_db.syncConflict)
          ..where((t) => t.id.equals(conflictId)))
        .write(SyncConflictCompanion(
      resolution: const Value('server_wins'),
      resolvedAt: Value(DateTime.now()),
      isResolved: const Value(true),
    ));

    // Clear dirty field using data from localData JSON
    final conflict = await (_db.select(_db.syncConflict)
          ..where((t) => t.id.equals(conflictId)))
        .getSingle();

    final localData = jsonDecode(conflict.localData) as Map<String, dynamic>;
    final fieldName = localData['field'] as String?;
    if (fieldName != null) {
      await _clearDirtyField(conflict.model, conflict.localId, fieldName);
    }
  }

  /// Get count of pending conflicts
  Future<int> getPendingConflictCount() async {
    final query = _db.selectOnly(_db.syncConflict)
      ..addColumns([_db.syncConflict.id.count()])
      ..where(_db.syncConflict.isResolved.equals(false));
    final result = await query.getSingle();
    return result.read(_db.syncConflict.id.count()) ?? 0;
  }

  /// Dispose the service
  void dispose() {
    _wsSubscription?.cancel();
    _editingRecords.clear();
    onConflictDetected = null;
    onSyncCompleted = null;
    logger.i('[WebSocketSync]', 'Service disposed');
  }
}

// Provider moved to providers/sync_service_providers.dart
