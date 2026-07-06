import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/odoo_service.dart';
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
      logger.d('[PaymentService]', 'Payment lines saved locally for order $saleOrderId');

      // 2. Intentar sincronizar si estamos online
      if (_isOnline) {
        try {
          await _syncPaymentLinesToOdoo(saleOrderId, lines, collectionSessionId);

          // Marcar como sincronizadas
          await _markPaymentLinesAsSynced(saleOrderId);
          logger.i('[PaymentService]', 'Payment lines synced to Odoo for order $saleOrderId');
          return true;
        } catch (syncError) {
          logger.w('[PaymentService]', 'Failed to sync payment lines, queueing: $syncError');
          await _queuePaymentLinesForSync(saleOrderId, lines, collectionSessionId);
        }
      } else {
        // 3. Si offline, encolar para sincronización posterior
        logger.d('[PaymentService]', 'Offline - queueing payment lines for sync');
        await _queuePaymentLinesForSync(saleOrderId, lines, collectionSessionId);
      }

      return true;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error saving payment lines', e, st);
      return false;
    }
  }

  /// Guarda las líneas de pago en la base de datos local
  Future<void> _savePaymentLinesLocally(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    for (final line in lines) {
      final lineUuid = line.lineUuid ?? _uuid.v4();

      await _db.into(_db.saleOrderPaymentLine).insertOnConflictUpdate(
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

  /// Resuelve el campo de banco correcto segun la version del servidor Odoo
  /// antes de enviar una linea de pago.
  ///
  /// `bank_id` (Many2one res.bank) fue reemplazado por `bank_name_ec` (Char)
  /// en el modelo real `l10n_ec_collection_box.sale.order.payment` (ver
  /// working/l10n_ec_collection_box/models/sale_order_payment.py). El campo
  /// PaymentLine.bankId/bankName esta marcado @OdooLocalOnly (no lo incluye
  /// paymentLineManager.toOdoo()), asi que se agrega aqui manualmente segun
  /// la version detectada — mismo criterio que sales_repository_sync.dart
  /// usa en lectura (hasBankModel).
  Map<String, dynamic> applyBankFieldGuard(
    Map<String, dynamic> vals,
    PaymentLine line,
  ) {
    if (line.bankId == null && (line.bankName == null || line.bankName!.isEmpty)) {
      return vals;
    }
    // Si la version aun no se detecto (unknown), se asume 19.1 (hasBankModel
    // = true) por defecto — ver OdooVersion.unknown.
    final hasBankModel = _odoo.client?.version.hasBankModel ?? true;
    if (hasBankModel) {
      if (line.bankId != null) vals['bank_id'] = line.bankId;
    } else {
      if (line.bankName != null) vals['bank_name_ec'] = line.bankName;
    }
    return vals;
  }

  /// Sincroniza las líneas de pago a Odoo
  Future<void> _syncPaymentLinesToOdoo(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    // Preparar las líneas para Odoo
    final lineVals = lines
        .map((l) => [0, 0, applyBankFieldGuard(paymentLineManager.toOdoo(l), l)])
        .toList();

    // Crear el wizard usando vals_list (requerido por Odoo 18 JSON2 API)
    final wizardId = await _odoo.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleOrderId,
            'collection_session_id': ?collectionSessionId,
            'line_ids': lineVals,
          }
        ],
      },
    );

    if (wizardId == null) {
      throw Exception('Failed to create payment wizard');
    }

    // Ejecutar action_apply con ids como args
    final actualId = wizardId is List ? wizardId[0] : wizardId;
    await _odoo.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply',
      kwargs: {'ids': [actualId]},
    );
  }

  /// Marca las líneas de pago como sincronizadas
  Future<void> _markPaymentLinesAsSynced(int saleOrderId) async {
    await (_db.update(_db.saleOrderPaymentLine)
          ..where((t) => t.orderId.equals(saleOrderId)))
        .write(const SaleOrderPaymentLineCompanion(
      isSynced: Value(true),
      lastSyncDate: Value(null), // Se actualizará con DateTime.now()
    ));

    // Actualizar con fecha actual
    await (_db.update(_db.saleOrderPaymentLine)
          ..where((t) => t.orderId.equals(saleOrderId)))
        .write(SaleOrderPaymentLineCompanion(
      lastSyncDate: Value(DateTime.now()),
    ));
  }

  /// Encola las líneas de pago para sincronización posterior
  Future<void> _queuePaymentLinesForSync(
    int saleOrderId,
    List<PaymentLine> lines,
    int? collectionSessionId,
  ) async {
    if (_offlineQueue == null) return;

    await _offlineQueue.queueOperation(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'apply_payment_lines',
      recordId: saleOrderId,
      values: {
        'sale_id': saleOrderId,
        'collection_session_id': ?collectionSessionId,
        'lines': lines
            .map((l) => applyBankFieldGuard(paymentLineManager.toOdoo(l), l))
            .toList(),
      },
      priority: OfflinePriority.high,
    );
  }

  /// Guarda y crea factura
  Future<int?> savePaymentLinesAndCreateInvoice(
    int saleOrderId,
    List<PaymentLine> lines, {
    int? collectionSessionId,
  }) async {
    try {
      if (lines.isEmpty) {
        logger.w('[PaymentService]', 'No payment lines to save');
        return null;
      }

      // Preparar las líneas para Odoo
      final lineVals = lines
          .map((l) => [0, 0, applyBankFieldGuard(paymentLineManager.toOdoo(l), l)])
          .toList();

      // Crear el wizard usando vals_list (requerido por Odoo 18 JSON2 API)
      final wizardId = await _odoo.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        kwargs: {
          'vals_list': [
            {
              'sale_id': saleOrderId,
              'collection_session_id': ?collectionSessionId,
              'line_ids': lineVals,
            }
          ],
        },
      );

      if (wizardId == null) {
        throw Exception('Failed to create payment wizard');
      }

      // Ejecutar action_apply_and_create_invoice con ids como kwargs
      final actualId = wizardId is List ? wizardId[0] : wizardId;
      final result = await _odoo.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply_and_create_invoice',
        kwargs: {'ids': [actualId]},
      );

      logger.i('[PaymentService]', 'Payment lines saved and invoice created: $result');

      // Intentar extraer el ID de la factura del resultado
      if (result is Map && result.containsKey('res_id')) {
        return result['res_id'] as int?;
      }

      return null;
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error saving payment lines and creating invoice', e, st);
      return null;
    }
  }

  /// Crea factura para venta a crédito (sin pagos)
  ///
  /// Usa el wizard estándar de Odoo para crear la factura.
  /// Retorna el ID de la factura creada o null si falla.
  Future<int?> createInvoiceForCreditSale(int saleOrderId) async {
    try {
      logger.i('[PaymentService]', 'Creating invoice for credit sale: $saleOrderId');

      // Crear wizard de facturación con contexto de la orden
      final wizardId = await _odoo.call(
        model: 'sale.advance.payment.inv',
        method: 'create',
        kwargs: {
          'vals_list': [
            {
              'advance_payment_method': 'delivered', // Facturar productos entregados
            }
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
        kwargs: {'ids': [actualId]},
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
      logger.e('[PaymentService]', 'Error creating invoice for credit sale', e, st);
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
          'domain': [['id', '=', orderId]],
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
