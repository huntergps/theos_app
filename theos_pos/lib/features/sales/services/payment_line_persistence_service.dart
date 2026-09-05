import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show
        OfflineLocalCommand,
        OfflineQueueCommandStore,
        OdooConnectionException,
        OdooOfflineException,
        OdooTimeoutException;
import 'package:uuid/uuid.dart';

import '../../../core/services/odoo_service.dart';
import 'payment_wizard_contract.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

const _uuid = Uuid();

/// Servicio para guardar/sincronizar líneas de pago de una orden de venta
/// (offline-first) y crear facturas asociadas.
///
/// Extraído tal cual de `payment_service.dart` como parte de la
/// descomposición sin cambio de comportamiento (Fase E2, sección 3 del plan
/// de descomposición). `PaymentService` delega aquí (facade).
///
/// [applyBankFieldGuard] es público porque `pos_payment_tab.dart` lo usa
/// directamente vía `paymentService.applyBankFieldGuard(...)` — mantiene la
/// misma firma que tenía en `PaymentService`.
class PaymentLinePersistenceService {
  final OdooService _odoo;
  final OfflineQueueDataSource? _offlineQueue;
  final AppDatabase _db;

  PaymentLinePersistenceService(this._odoo, this._offlineQueue, this._db);

  /// Verifica si hay conexión a Odoo
  bool get _isOnline => _odoo.client != null;

  /// Guarda las líneas de pago en la orden de venta
  ///
  /// OFFLINE-FIRST:
  /// 1. Guarda las líneas en la base local primero
  /// 2. Si online, intenta sincronizar con Odoo
  /// 3. Si offline o falla sync, encola para procesamiento posterior
  Future<bool> savePaymentLines(
    int saleOrderId,
    List<PaymentLine> lines, {
    int? collectionSessionId,
  }) async {
    try {
      if (lines.isEmpty) {
        logger.w('[PaymentService]', 'No payment lines to save');
        return true;
      }

      // 1. SIEMPRE guardar en base local primero
      await _savePaymentLinesLocally(saleOrderId, lines, collectionSessionId);
      logger.d(
        '[PaymentService]',
        'Payment lines saved locally for order $saleOrderId',
      );

      // 2. Intentar sincronizar si estamos online
      if (_isOnline) {
        try {
          await _syncPaymentLinesToOdoo(
            saleOrderId,
            lines,
            collectionSessionId,
          );

          // Marcar como sincronizadas
          await _markPaymentLinesAsSynced(saleOrderId);
          logger.i(
            '[PaymentService]',
            'Payment lines synced to Odoo for order $saleOrderId',
          );
          return true;
        } catch (syncError) {
          if (!_isConnectivityFailure(syncError)) {
            logger.e(
              '[PaymentService]',
              'Odoo rejected payment lines; they remain local and unsynced',
              syncError,
            );
            return false;
          }
          logger.w(
            '[PaymentService]',
            'Connection lost while syncing payment lines; queueing: $syncError',
          );
          await _queuePaymentLinesForSync(
            saleOrderId,
            lines,
            collectionSessionId,
          );
        }
      } else {
        // 3. Si offline, encolar para sincronización posterior
        logger.d(
          '[PaymentService]',
          'Offline - queueing payment lines for sync',
        );
        await _queuePaymentLinesForSync(
          saleOrderId,
          lines,
          collectionSessionId,
        );
      }

      return true;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error saving payment lines', e, st);
      return false;
    }
  }

  bool _isConnectivityFailure(Object error) =>
      error is OdooConnectionException ||
      error is OdooTimeoutException ||
      error is OdooOfflineException;

  /// Registra un cobro offline de una factura ya existente, de forma atómica.
  Future<bool> collectExistingInvoice({
    required int saleOrderId,
    required int invoiceId,
    required int collectionSessionId,
    required String collectionOpUuid,
    required List<PaymentLine> lines,
    int? operatorId,
  }) async {
    try {
      return await _db.transaction(() async {
        if (collectionOpUuid.trim().isEmpty || lines.isEmpty) return false;
        if (_offlineQueue != null) {
          final existing =
              await (_db.select(_db.offlineQueue)..where(
                    (row) =>
                        row.method.equals(
                          OfflineLocalCommand
                              .invoiceCollectExisting
                              .storageName,
                        ) &
                        row.values.like('%$collectionOpUuid%'),
                  ))
                  .get();
          final matching = existing.where((row) {
            try {
              final values = jsonDecode(row.values);
              return values is Map &&
                  values['collection_op_uuid'] == collectionOpUuid;
            } catch (_) {
              return false;
            }
          });
          if (matching.isNotEmpty) {
            final payload = lines.map(toPaymentWizardLineValues).toList();
            final oldValues = jsonDecode(matching.first.values) as Map;
            final oldPayload = oldValues['payment_lines'];
            if (oldValues['sale_id'] != saleOrderId ||
                oldValues['invoice_id'] != invoiceId ||
                oldValues['collection_session_id'] != collectionSessionId ||
                oldValues['collection_user_id'] != operatorId) {
              return false;
            }
            return jsonEncode(oldPayload) == jsonEncode(payload);
          }
        }
        final invoice = await (_db.select(
          _db.accountMove,
        )..where((row) => row.odooId.equals(invoiceId))).getSingleOrNull();
        final session =
            await (_db.select(_db.collectionSession)
                  ..where((row) => row.odooId.equals(collectionSessionId)))
                .getSingleOrNull();
        final saleOrder = await (_db.select(
          _db.saleOrder,
        )..where((row) => row.odooId.equals(saleOrderId))).getSingleOrNull();
        if (invoice == null ||
            saleOrder == null ||
            invoice.saleOrderId == null ||
            invoice.saleOrderId != saleOrderId ||
            saleOrder.companyId != invoice.companyId ||
            invoice.state != 'posted' ||
            session == null ||
            operatorId == null ||
            operatorId <= 0 ||
            session.userId != operatorId ||
            !{'opened', 'opening_control'}.contains(session.state) ||
            invoice.companyId == null ||
            invoice.companyId != session.companyId ||
            invoice.currencyId != session.currencyId ||
            invoice.amountResidual <= 0) {
          return false;
        }
        final config =
            await (_db.select(_db.collectionConfig)
                  ..where((row) => row.odooId.equals(session.configId)))
                .getSingleOrNull();
        if (config == null ||
            !config.active ||
            config.companyId != invoice.companyId) {
          return false;
        }
        final allowed = _decodeJournalIds(config.allowedJournalIds);
        if (allowed.isEmpty) return false;
        final serialized = <Map<String, dynamic>>[];
        final uuids = <String>[];
        final uuidSet = <String>{};
        var total = 0.0;
        for (final line in lines) {
          if (line.type != PaymentLineType.payment ||
              line.journalId == null ||
              line.paymentMethodLineId == null ||
              !line.amount.isFinite ||
              line.amount <= 0 ||
              line.validate().isNotEmpty ||
              !allowed.contains(line.journalId!)) {
            return false;
          }
          final journal =
              await (_db.select(_db.accountJournal)
                    ..where((row) => row.odooId.equals(line.journalId!))
                    ..where((row) => row.companyId.equals(invoice.companyId!))
                    ..where((row) => row.active.equals(true)))
                  .getSingleOrNull();
          final method =
              await (_db.select(_db.accountPaymentMethodLine)
                    ..where(
                      (row) => row.odooId.equals(line.paymentMethodLineId!),
                    )
                    ..where((row) => row.journalId.equals(line.journalId!))
                    ..where((row) => row.active.equals(true)))
                  .getSingleOrNull();
          final uuid = line.lineUuid;
          if (journal == null ||
              method == null ||
              uuid == null ||
              uuid.trim().isEmpty ||
              !uuidSet.add(uuid)) {
            return false;
          }
          final persistedLine = await (_db.select(
            _db.saleOrderPaymentLine,
          )..where((row) => row.lineUuid.equals(uuid))).getSingleOrNull();
          if (persistedLine != null) return false;
          uuids.add(uuid);
          total += line.amount;
          serialized.add(toPaymentWizardLineValues(line));
        }
        if (total > invoice.amountResidual + 0.000001 ||
            _offlineQueue == null) {
          return false;
        }
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          await _db
              .into(_db.accountPaymentTable)
              .insert(
                AccountPaymentCompanion.insert(
                  paymentUuid: '$collectionOpUuid:${uuids[i]}',
                  collectionSessionId: Value(collectionSessionId),
                  invoiceId: Value(invoiceId),
                  saleId: Value(saleOrderId),
                  partnerId: Value(invoice.partnerId),
                  journalId: Value(line.journalId),
                  paymentMethodLineId: Value(line.paymentMethodLineId),
                  amount: Value(line.amount),
                  paymentType: const Value('inbound'),
                  state: const Value('draft'),
                  paymentOriginType: const Value('debt'),
                  date: Value(line.date),
                  isSynced: const Value(false),
                  collectionUserId: Value(operatorId),
                ),
              );
          await _db
              .into(_db.saleOrderPaymentLine)
              .insert(
                SaleOrderPaymentLineCompanion.insert(
                  lineUuid: Value(uuids[i]),
                  orderId: saleOrderId,
                  paymentType: const Value('inbound'),
                  journalId: Value(line.journalId),
                  paymentMethodLineId: Value(line.paymentMethodLineId),
                  amount: Value(line.amount),
                  date: Value(line.date),
                  state: const Value('draft'),
                  isSynced: const Value(false),
                ),
              );
        }
        final residual = invoice.amountResidual - total;
        await (_db.update(
          _db.accountMove,
        )..where((row) => row.odooId.equals(invoiceId))).write(
          AccountMoveCompanion(
            amountResidual: Value(residual < 0 ? 0 : residual),
            paymentState: Value(residual <= 0.000001 ? 'paid' : 'partial'),
          ),
        );
        await _offlineQueue.queueCommand(
          model: 'sale.order',
          command: OfflineLocalCommand.invoiceCollectExisting,
          parentOrderId: saleOrderId,
          values: {
            'sale_id': saleOrderId,
            'invoice_id': invoiceId,
            'collection_session_id': collectionSessionId,
            'collection_user_id': operatorId,
            'collection_op_uuid': collectionOpUuid,
            'payment_lines': serialized,
            'payment_line_uuids': uuids,
          },
        );
        return true;
      });
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error collecting existing invoice', e, st);
      return false;
    }
  }

  Set<int> _decodeJournalIds(String? value) {
    if (value == null || value.isEmpty) return <int>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<num>().map((e) => e.toInt()).toSet();
      }
    } catch (_) {}
    return value.split(',').map(int.tryParse).whereType<int>().toSet();
  }

  Future<int> collectExistingInvoiceOffline({
    required int saleOrderId,
    required int invoiceId,
    required int collectionSessionId,
    required int operatorId,
    required String operationUuid,
    required List<PaymentLine> lines,
  }) async {
    final accepted = await collectExistingInvoice(
      saleOrderId: saleOrderId,
      invoiceId: invoiceId,
      collectionSessionId: collectionSessionId,
      collectionOpUuid: operationUuid,
      lines: lines,
      operatorId: operatorId,
    );
    if (!accepted || _offlineQueue == null) {
      throw StateError('No se pudo registrar el cobro offline.');
    }
    final operations = await _offlineQueue.getOperationsForSaleOrder(
      saleOrderId,
    );
    final matches = operations.where(
      (item) =>
          item.method ==
              OfflineLocalCommand.invoiceCollectExisting.storageName &&
          item.values['collection_op_uuid'] == operationUuid,
    );
    final id = matches.firstOrNull?.id;
    if (id == null) {
      throw StateError('No se pudo identificar la operación offline.');
    }
    return id;
  }

  /// Guarda las líneas de pago en la base de datos local
  Future<void> _savePaymentLinesLocally(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    for (final line in lines) {
      final lineUuid = line.lineUuid ?? _uuid.v4();

      await _db
          .into(_db.saleOrderPaymentLine)
          .insertOnConflictUpdate(
            SaleOrderPaymentLineCompanion.insert(
              lineUuid: Value(lineUuid),
              orderId: saleOrderId,
              paymentType: const Value('inbound'),
              journalId: Value(line.journalId),
              journalName: Value(line.journalName),
              journalType: Value(line.journalType),
              paymentMethodLineId: Value(line.paymentMethodLineId),
              paymentMethodCode: Value(line.paymentMethodCode),
              paymentMethodName: Value(line.paymentMethodName),
              amount: Value(line.amount),
              date: Value(line.date),
              paymentReference: Value(line.reference),
              creditNoteId: Value(line.creditNoteId),
              creditNoteName: Value(line.creditNoteName),
              advanceId: Value(line.advanceId),
              advanceName: Value(line.advanceName),
              cardType: Value(line.cardType?.name),
              cardBrandId: Value(line.cardBrandId),
              cardBrandName: Value(line.cardBrandName),
              cardDeadlineId: Value(line.cardDeadlineId),
              cardDeadlineName: Value(line.cardDeadlineName),
              loteId: Value(line.loteId),
              loteName: Value(line.loteName),
              bankId: Value(line.bankId),
              bankName: Value(line.bankName),
              partnerBankId: Value(line.partnerBankId),
              partnerBankName: Value(line.partnerBankName),
              effectiveDate: Value(line.effectiveDate),
              state: const Value('draft'),
              isSynced: const Value(false),
            ),
          );
    }
  }

  /// Serializa el banco del catálogo custom, incluso sin conexión.
  /// `bankId` identifica `l10n.ec.bank`; nunca un registro de `res.bank`.
  Map<String, dynamic> applyBankFieldGuard(
    Map<String, dynamic> vals,
    PaymentLine line,
  ) {
    vals.remove('bank_id');
    if (line.bankId == null &&
        (line.bankName == null || line.bankName!.isEmpty)) {
      return vals;
    }
    if (line.bankId != null) vals['l10n_ec_bank_id'] = line.bankId;
    if (line.bankName != null) vals['bank_name_ec'] = line.bankName;
    return vals;
  }

  /// Converts a domain line into the contract of the transient payment wizard.
  ///
  /// `paymentLineManager.toOdoo()` targets the persistent payment model. The
  /// wizard has a different schema: some deployments use `line_type`, and it lacks
  /// fields such as `state`. Keeping this mapper explicit prevents payments
  /// from being dropped or rejected because two different Odoo models happened
  /// to share most field names.
  Map<String, dynamic> toPaymentWizardLineValues(PaymentLine line) {
    final validationErrors = line.validate();
    if (validationErrors.isNotEmpty) {
      throw StateError(validationErrors.values.join('. '));
    }

    final vals = <String, dynamic>{
      'line_type': switch (line.type) {
        PaymentLineType.payment => 'payment',
        PaymentLineType.advance => 'advance',
        PaymentLineType.creditNote => 'credit_note',
      },
      'date': line.date.toIso8601String().split('T').first,
      'amount': line.amount,
      if (line.reference != null && line.reference!.trim().isNotEmpty)
        'payment_reference': line.reference!.trim(),
    };

    switch (line.type) {
      case PaymentLineType.payment:
        if (line.paymentMethodLineId == null) {
          throw StateError('Método de pago requerido para el cobro');
        }
        vals.addAll({
          'journal_id': line.journalId,
          'payment_method_line_id': line.paymentMethodLineId,
          if (line.cardType != null) 'card_type': line.cardType!.name,
          if (line.cardBrandId != null) 'card_brand_id': line.cardBrandId,
          if (line.cardDeadlineId != null)
            'card_deadline_id': line.cardDeadlineId,
          if (line.loteId != null) 'lote_id': line.loteId,
          if (line.voucherDate != null)
            'bank_reference_date': line.voucherDate!
                .toIso8601String()
                .split('T')
                .first,
          if (line.partnerBankId != null) 'partner_bank_id': line.partnerBankId,
          if (line.effectiveDate != null)
            'effective_date': line.effectiveDate!
                .toIso8601String()
                .split('T')
                .first,
          if (line.bankId != null) 'l10n_ec_bank_id': line.bankId,
          if (line.bankName != null && line.bankName!.trim().isNotEmpty)
            'bank_name_ec': line.bankName!.trim(),
        });
      case PaymentLineType.advance:
        vals['advance_id'] = line.advanceId;
      case PaymentLineType.creditNote:
        vals['credit_note_id'] = line.creditNoteId;
    }

    return vals;
  }

  /// Sincroniza las líneas de pago a Odoo
  Future<void> _syncPaymentLinesToOdoo(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    final wizardId = await _createPaymentWizard(
      saleOrderId,
      lines,
      collectionSessionId: collectionSessionId,
    );
    await _odoo.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply',
      ids: [wizardId],
    );
  }

  /// Marca las líneas de pago como sincronizadas
  Future<void> _markPaymentLinesAsSynced(int saleOrderId) async {
    await (_db.update(
      _db.saleOrderPaymentLine,
    )..where((t) => t.orderId.equals(saleOrderId))).write(
      const SaleOrderPaymentLineCompanion(
        isSynced: Value(true),
        lastSyncDate: Value(null), // Se actualizará con DateTime.now()
      ),
    );

    // Actualizar con fecha actual
    await (_db.update(
      _db.saleOrderPaymentLine,
    )..where((t) => t.orderId.equals(saleOrderId))).write(
      SaleOrderPaymentLineCompanion(lastSyncDate: Value(DateTime.now())),
    );
  }

  /// Encola las líneas de pago para sincronización posterior
  Future<void> _queuePaymentLinesForSync(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    if (_offlineQueue == null) return;

    await _offlineQueue.queueCommand(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      command: OfflineLocalCommand.paymentWizardApply,
      recordId: saleOrderId,
      values: {
        'sale_id': saleOrderId,
        'collection_session_id': ?collectionSessionId,
        'line_ids': lines.map(toPaymentWizardLineValues).toList(),
      },
      priority: OfflinePriority.high,
    );
  }

  /// Saves the complete payment through the canonical Odoo wizard and creates
  /// the invoice. A null result means there is no usable connection and lets
  /// the caller enter the explicit offline queue flow. Business errors remain
  /// visible and are never converted into offline success.
  Future<PaymentInvoiceResult?> savePaymentLinesAndCreateInvoice(
    int saleOrderId,
    List<PaymentLine> lines, {
    int? collectionSessionId,
  }) async {
    try {
      if (lines.isEmpty) {
        logger.w('[PaymentService]', 'No payment lines to save');
        return null;
      }
      if (!_isOnline) return null;

      final wizardId = await _createPaymentWizard(
        saleOrderId,
        lines,
        collectionSessionId: collectionSessionId,
      );
      final result = await _odoo.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply_and_create_invoice',
        ids: [wizardId],
      );

      final parsed = _parsePaymentAction(
        result,
        paymentWizardId: wizardId,
        saleOrderId: saleOrderId,
        appliedAdvanceIds: lines
            .where((line) => line.advanceId != null)
            .map((line) => line.advanceId!)
            .toSet(),
      );
      if (parsed.isCreated) {
        await _refreshAppliedAdvances(parsed.appliedAdvanceIds);
      }
      logger.i('[PaymentService]', 'Payment wizard completed: $parsed');
      return parsed;
    } on OdooConnectionException catch (e) {
      logger.w('[PaymentService]', 'Connection lost while invoicing: $e');
      return null;
    } on OdooTimeoutException catch (e) {
      logger.w('[PaymentService]', 'Invoice request timed out: $e');
      return null;
    } on OdooOfflineException catch (e) {
      logger.w('[PaymentService]', 'Offline while invoicing: $e');
      return null;
    } catch (e, st) {
      logger.e(
        '[PaymentService]',
        'Error saving payment lines and creating invoice',
        e,
        st,
      );
      rethrow;
    }
  }

  Future<int> _createPaymentWizard(
    int saleOrderId,
    List<PaymentLine> lines, {
    int? collectionSessionId,
  }) async {
    final client = _odoo.client;
    if (client == null) throw const OdooOfflineException();
    final lineCommands = await adaptPaymentWizardCommands(client, [
      for (final line in lines) [0, 0, toPaymentWizardLineValues(line)],
    ]);
    if (!identical(_odoo.client, client)) {
      throw StateError('La sesión cambió durante la preparación del cobro.');
    }
    final result = await _odoo.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleOrderId,
            'collection_session_id': ?collectionSessionId,
            'line_ids': lineCommands,
          },
        ],
      },
    );
    final id = result is List && result.isNotEmpty ? result.first : result;
    if (id is! int) {
      throw StateError('Odoo no devolvió el ID del asistente de cobro');
    }
    return id;
  }

  /// Continues the same transient wizard after the cashier accepts converting
  /// a non-cash overpayment into an advance.
  Future<PaymentInvoiceResult> confirmOverpaymentAndCreateInvoice(
    PaymentInvoiceResult pending,
  ) async {
    if (!pending.requiresOverpaymentConfirmation ||
        pending.paymentWizardId == null ||
        pending.saleOrderId == null ||
        pending.overpaymentAmount == null) {
      throw StateError('No hay una confirmación de sobrepago pendiente');
    }

    final createResult = await _odoo.call(
      model: 'l10n_ec_collection_box.confirm.advance.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'payment_wizard_id': pending.paymentWizardId,
            'sale_id': pending.saleOrderId,
            'overpayment_amount': pending.overpaymentAmount,
          },
        ],
      },
    );
    final confirmId = createResult is List && createResult.isNotEmpty
        ? createResult.first
        : createResult;
    if (confirmId is! int) {
      throw StateError('Odoo no devolvió el ID de confirmación del anticipo');
    }

    final result = await _odoo.call(
      model: 'l10n_ec_collection_box.confirm.advance.wizard',
      method: 'action_create_advance',
      ids: [confirmId],
    );
    final parsed = _parsePaymentAction(
      result,
      paymentWizardId: pending.paymentWizardId!,
      saleOrderId: pending.saleOrderId!,
      appliedAdvanceIds: pending.appliedAdvanceIds,
    );
    if (!parsed.isCreated) {
      throw StateError('La confirmación no devolvió una factura creada');
    }
    await _refreshAppliedAdvances(parsed.appliedAdvanceIds);
    return parsed;
  }

  PaymentInvoiceResult _parsePaymentAction(
    dynamic raw, {
    required int paymentWizardId,
    required int saleOrderId,
    Set<int> appliedAdvanceIds = const {},
  }) {
    if (raw is! Map) {
      throw StateError('Odoo devolvió una acción de cobro inválida');
    }
    final action = Map<String, dynamic>.from(raw);
    final model = action['res_model']?.toString();
    if (model == 'account.move') {
      final invoiceId = _extractActionRecordId(action);
      if (invoiceId == null) {
        throw StateError('Odoo no devolvió la factura creada');
      }
      return PaymentInvoiceResult.created(
        invoiceId,
        appliedAdvanceIds: appliedAdvanceIds,
      );
    }
    if (model == 'l10n_ec_collection_box.confirm.advance.wizard') {
      final context = action['context'] is Map
          ? Map<String, dynamic>.from(action['context'] as Map)
          : const <String, dynamic>{};
      final overpayment = context['default_overpayment_amount'];
      return PaymentInvoiceResult.overpaymentConfirmationRequired(
        paymentWizardId:
            (context['default_payment_wizard_id'] as int?) ?? paymentWizardId,
        saleOrderId: (context['default_sale_id'] as int?) ?? saleOrderId,
        overpaymentAmount: overpayment is num
            ? overpayment.toDouble()
            : double.tryParse(overpayment?.toString() ?? '') ?? 0,
        appliedAdvanceIds: appliedAdvanceIds,
      );
    }
    throw StateError(
      'El cobro requiere una acción no soportada: ${model ?? action['type']}',
    );
  }

  int? _extractActionRecordId(Map<String, dynamic> action) {
    final resId = action['res_id'];
    if (resId is int) return resId;
    final domain = action['domain'];
    if (domain is List) {
      for (final term in domain) {
        if (term is List && term.length >= 3 && term[0] == 'id') {
          final ids = term[2];
          if (ids is List && ids.length == 1 && ids.first is int) {
            return ids.first as int;
          }
        }
      }
    }
    return null;
  }

  /// Refreshes advances only after Odoo has consumed them during the canonical
  /// payment transaction. This replaces the former manual "mark as used"
  /// shortcut, which changed the local balance without any accounting usage.
  Future<void> _refreshAppliedAdvances(Set<int> advanceIds) async {
    if (advanceIds.isEmpty) return;
    final result = await _odoo.call(
      model: 'account.advance',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['id', 'in', advanceIds.toList(growable: false)],
        ],
        'fields': [
          'id',
          'name',
          'date',
          'date_estimated',
          'date_due',
          'state',
          'advance_type',
          'partner_id',
          'reference',
          'amount',
          'amount_used',
          'amount_available',
          'amount_returned',
          'collection_session_id',
          'sale_order_id',
        ],
      },
    );
    if (result is! List) return;
    for (final raw in result.whereType<Map>()) {
      await advanceManager.upsertLocal(
        advanceManager.fromOdoo(Map<String, dynamic>.from(raw)),
      );
    }
  }

  /// Crea factura para venta a crédito (sin pagos)
  ///
  /// Usa el wizard estándar de Odoo para crear la factura.
  /// Retorna el ID de la factura creada o null si falla.
  Future<int?> createInvoiceForCreditSale(int saleOrderId) async {
    try {
      logger.i(
        '[PaymentService]',
        'Creating invoice for credit sale: $saleOrderId',
      );

      // Crear wizard de facturación con contexto de la orden
      final wizardId = await _odoo.call(
        model: 'sale.advance.payment.inv',
        method: 'create',
        kwargs: {
          'vals_list': [
            {
              'advance_payment_method':
                  'delivered', // Facturar productos entregados
            },
          ],
        },
        context: {
          'active_ids': [saleOrderId],
          'active_model': 'sale.order',
          'active_id': saleOrderId,
        },
      );

      if (wizardId == null) {
        throw Exception('Failed to create invoice wizard');
      }

      // Ejecutar create_invoices del wizard
      final actualId = wizardId is List ? wizardId[0] : wizardId;
      final result = await _odoo.call(
        model: 'sale.advance.payment.inv',
        method: 'create_invoices',
        ids: [actualId],
        context: {
          'active_ids': [saleOrderId],
          'active_model': 'sale.order',
          'active_id': saleOrderId,
        },
      );

      logger.i('[PaymentService]', 'Invoice created: $result');

      // Obtener el ID de la factura creada buscando facturas de la orden
      final invoices = await _odoo.call(
        model: 'account.move',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['invoice_origin', '=', await _getOrderName(saleOrderId)],
            ['move_type', '=', 'out_invoice'],
          ],
          'fields': ['id', 'name'],
          'order': 'id desc',
          'limit': 1,
        },
      );

      if (invoices is List && invoices.isNotEmpty) {
        return invoices[0]['id'] as int?;
      }

      return null;
    } catch (e, st) {
      logger.e(
        '[PaymentService]',
        'Error creating invoice for credit sale',
        e,
        st,
      );
      rethrow;
    }
  }

  /// Obtiene el nombre de la orden
  Future<String?> _getOrderName(int orderId) async {
    try {
      final result = await _odoo.call(
        model: 'sale.order',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', '=', orderId],
          ],
          'fields': ['name'],
          'limit': 1,
        },
      );
      if (result is List && result.isNotEmpty) {
        return result[0]['name'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

enum PaymentInvoiceStatus { created, overpaymentConfirmationRequired }

/// Typed result of the Odoo payment wizard. Intermediate actions deliberately
/// carry no invoice ID, so presentation cannot mistake them for final success.
class PaymentInvoiceResult {
  final PaymentInvoiceStatus status;
  final int? invoiceId;
  final int? paymentWizardId;
  final int? saleOrderId;
  final double? overpaymentAmount;
  final Set<int> appliedAdvanceIds;

  const PaymentInvoiceResult._({
    required this.status,
    this.invoiceId,
    this.paymentWizardId,
    this.saleOrderId,
    this.overpaymentAmount,
    this.appliedAdvanceIds = const {},
  });

  const PaymentInvoiceResult.created(
    int invoiceId, {
    Set<int> appliedAdvanceIds = const {},
  }) : this._(
         status: PaymentInvoiceStatus.created,
         invoiceId: invoiceId,
         appliedAdvanceIds: appliedAdvanceIds,
       );

  const PaymentInvoiceResult.overpaymentConfirmationRequired({
    required int paymentWizardId,
    required int saleOrderId,
    required double overpaymentAmount,
    Set<int> appliedAdvanceIds = const {},
  }) : this._(
         status: PaymentInvoiceStatus.overpaymentConfirmationRequired,
         paymentWizardId: paymentWizardId,
         saleOrderId: saleOrderId,
         overpaymentAmount: overpaymentAmount,
         appliedAdvanceIds: appliedAdvanceIds,
       );

  bool get isCreated => status == PaymentInvoiceStatus.created;

  bool get requiresOverpaymentConfirmation =>
      status == PaymentInvoiceStatus.overpaymentConfirmationRequired;

  @override
  String toString() => switch (status) {
    PaymentInvoiceStatus.created => 'created(invoiceId=$invoiceId)',
    PaymentInvoiceStatus.overpaymentConfirmationRequired =>
      'overpaymentConfirmationRequired(amount=$overpaymentAmount)',
  };
}
