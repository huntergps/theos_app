import 'package:drift/drift.dart';

import '../../../features/banks/repositories/bank_repository.dart';
import '../../../core/services/odoo_service.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import 'order_validation_types.dart';
import 'payment_service_models.dart';
import 'journal_payment_method_service.dart';
import 'card_payment_sync_service.dart';
import 'payment_line_persistence_service.dart';
import 'credit_withholding_service.dart';
import 'payment_validation_service.dart';

export 'payment_service_models.dart';

/// Servicio para gestionar los pagos de órdenes de venta
///
/// Proporciona métodos para:
/// - Obtener diarios y métodos de pago disponibles
/// - Obtener anticipos y notas de crédito del cliente
/// - Obtener bancos, marcas de tarjeta, plazos y lotes
/// - Guardar líneas de pago
///
/// Sigue el patrón offline-first: lee de la base local primero,
/// y usa Odoo para sincronización y operaciones de escritura.
///
/// Descompuesto en Fase E2 en sub-servicios por composición
/// (`JournalPaymentMethodService`, etc.) — este facade delega, la API
/// pública se mantiene 100% intacta.
class PaymentService {
  final OdooService _odoo;
  final AppDatabase _db;

  final JournalPaymentMethodService _journal;
  final CardPaymentSyncService _card;
  final PaymentLinePersistenceService _paymentLines;
  final CreditWithholdingService _credit;
  late final PaymentValidationService _validation;

  // NOTA: bankRepo/offlineQueue ya no se guardan como campos propios — solo
  // se necesitan para construir CardPaymentSyncService/
  // PaymentLinePersistenceService (composición, Fase E2). La firma del
  // constructor (tipos y orden de parámetros posicionales) se mantiene
  // 100% intacta para no romper los call sites existentes.
  //
  // _validation se asigna en el body (no en la lista de inicializadores)
  // porque reutiliza la misma instancia de _credit (no tiene sentido crear
  // un segundo CreditWithholdingService independiente).
  PaymentService(
    this._odoo,
    BankRepository bankRepo,
    OfflineQueueDataSource? offlineQueue,
    this._db,
  ) : _journal = JournalPaymentMethodService(_odoo, _db),
      _card = CardPaymentSyncService(_odoo, bankRepo, _db),
      _paymentLines = PaymentLinePersistenceService(_odoo, offlineQueue, _db),
      _credit = CreditWithholdingService(_odoo) {
    _validation = PaymentValidationService(_db, _credit);
  }

  /// Obtiene los diarios de pago disponibles para la sesión de cobranza
  ///
  /// Usa la configuración del punto de cobro (collection_config.allowed_journal_ids)
  /// para obtener solo los diarios permitidos.
  ///
  /// OFFLINE-FIRST: Primero intenta cargar desde la base de datos local.
  ///
  /// [sessionId]: ID de la sesión de cobranza (collection.session)
  Future<List<AvailableJournal>> getAvailableJournals(int? sessionId) =>
      _journal.getAvailableJournals(sessionId);

  /// Obtiene los anticipos disponibles del cliente
  ///
  /// Usa datos locales (offline-first)
  Future<List<AvailableAdvance>> getAvailableAdvances(int partnerId) async {
    try {
      // Obtener anticipos de la base local
      final advances =
          await (_db.select(_db.accountAdvance)
                ..where((t) => t.partnerId.equals(partnerId))
                ..where((t) => t.advanceType.equals('advance'))
                ..where((t) => t.state.isIn(['posted', 'in_use']))
                ..where((t) => t.amountAvailable.isBiggerThanValue(0))
                ..orderBy([(t) => OrderingTerm.desc(t.date)]))
              .get();

      if (advances.isEmpty) {
        logger.d(
          '[PaymentService]',
          'No advances found locally for partner $partnerId',
        );
        return [];
      }

      // Convertir a AvailableAdvance
      return advances
          .map(
            (a) => AvailableAdvance(
              id: a.odooId,
              // Los anticipos creados offline aún no tienen número de secuencia
              name: a.name ?? 'Anticipo sin sincronizar',
              amountAvailable: a.amountAvailable,
              date: a.date,
              reference: a.reference,
            ),
          )
          .toList();
    } catch (e, st) {
      logger.e(
        '[PaymentService]',
        'Error getting advances for partner $partnerId',
        e,
        st,
      );
      return [];
    }
  }

  /// Obtiene las notas de crédito disponibles del cliente
  ///
  /// Usa datos locales (offline-first)
  Future<List<AvailableCreditNote>> getAvailableCreditNotes(
    int partnerId,
  ) async {
    try {
      // Obtener notas de crédito de la base local (usando accountMove con moveType='out_refund')
      final creditNotes =
          await (_db.select(_db.accountMove)
                ..where((t) => t.partnerId.equals(partnerId))
                ..where((t) => t.moveType.equals('out_refund'))
                ..where((t) => t.state.equals('posted'))
                ..where((t) => t.paymentState.isIn(['not_paid', 'partial']))
                ..where((t) => t.amountResidual.isBiggerThanValue(0))
                ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
              .get();

      if (creditNotes.isEmpty) {
        logger.d(
          '[PaymentService]',
          'No credit notes found locally for partner $partnerId',
        );
        return [];
      }

      // Convertir a AvailableCreditNote
      return creditNotes
          .map(
            (nc) => AvailableCreditNote(
              id: nc.odooId,
              name: nc.name ?? '',
              amountResidual: nc.amountResidual,
              invoiceDate: nc.invoiceDate,
              ref: nc.ref,
            ),
          )
          .toList();
    } catch (e, st) {
      logger.e(
        '[PaymentService]',
        'Error getting credit notes for partner $partnerId',
        e,
        st,
      );
      return [];
    }
  }

  /// Obtiene los bancos disponibles (delegado a BankRepository)
  ///
  /// Lee de la tabla local `res_bank` (offline-first). NOTA: pese al
  /// comentario histórico, el código actual no sincroniza on-demand desde
  /// Odoo si la tabla está vacía — `res_bank` se llena vía el flujo general
  /// de sync de catálogo, no acá.
  Future<List<AvailableBank>> getBanks() => _card.getBanks();

  /// Reactive stream of available banks — mismo dato que [getBanks] pero
  /// reactivo, usando [BankRepository.watchBanks].
  Stream<List<AvailableBank>> watchBanks() => _card.watchBanks();

  /// Obtiene las marcas de tarjeta configuradas para un diario (sync-on-demand)
  /// Si las marcas no están en local, sincroniza desde Odoo primero
  Future<List<CardBrand>> getCardBrands(int journalId) =>
      _card.getCardBrands(journalId);

  /// Reactive stream de marcas de tarjeta configuradas para un diario —
  /// mismo dato que [getCardBrands] pero reactivo (ver
  /// `CardPaymentSyncService.watchCardBrandsByJournal`, ítem 1 Grupo B del
  /// plan de reactividad). No reemplaza el sync-on-demand de [getCardBrands].
  Stream<List<CardBrand>> watchCardBrandsByJournal(int journalId) =>
      _card.watchCardBrandsByJournal(journalId);

  /// Obtiene los plazos de tarjeta configurados para un diario (sync-on-demand)
  /// Si los plazos no están en local, sincroniza desde Odoo primero
  Future<List<CardDeadline>> getCardDeadlines(
    int journalId,
    CardType cardType,
  ) => _card.getCardDeadlines(journalId, cardType);

  /// Reactive stream de plazos de tarjeta configurados para un diario, según
  /// tipo de tarjeta — mismo dato que [getCardDeadlines] pero reactivo (ver
  /// `CardPaymentSyncService.watchCardDeadlines`, ítem 1 Grupo B del plan de
  /// reactividad). No reemplaza el sync-on-demand de [getCardDeadlines].
  Stream<List<CardDeadline>> watchCardDeadlines(
    int journalId,
    CardType cardType,
  ) => _card.watchCardDeadlines(journalId, cardType);

  /// Obtiene los lotes abiertos para un diario (sync-on-demand)
  /// Si no hay lotes locales, sincroniza desde Odoo primero
  Future<List<CardLote>> getOpenLotes(int journalId) =>
      _card.getOpenLotes(journalId);

  /// Crea un nuevo lote de tarjetas para un diario
  ///
  /// [journalId]: ID del diario de tarjetas (odooId)
  /// [isPosLote]: Si es un lote de POS (punto de venta)
  ///
  /// El número de lote se calcula automáticamente basándose en los lotes
  /// existentes para el diario y fecha.
  ///
  /// Crea primero en la base local con un UUID para tracking offline.
  /// Si hay conexión, sincroniza inmediatamente a Odoo.
  ///
  /// Retorna el lote creado o null si falla
  Future<CardLote?> createLote(int journalId, {bool isPosLote = true}) =>
      _card.createLote(journalId, isPosLote: isPosLote);

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
  }) => _paymentLines.savePaymentLines(
    saleOrderId,
    lines,
    collectionSessionId: collectionSessionId,
  );

  Future<bool> collectExistingInvoice({
    required int saleOrderId,
    required int invoiceId,
    required int collectionSessionId,
    required String collectionOpUuid,
    required List<PaymentLine> lines,
  }) => _paymentLines.collectExistingInvoice(
    saleOrderId: saleOrderId,
    invoiceId: invoiceId,
    collectionSessionId: collectionSessionId,
    collectionOpUuid: collectionOpUuid,
    lines: lines,
  );

  Future<int> collectExistingInvoiceOffline({
    required int saleOrderId,
    required int invoiceId,
    required int collectionSessionId,
    required int operatorId,
    required String operationUuid,
    required List<PaymentLine> lines,
  }) => _paymentLines.collectExistingInvoiceOffline(
    saleOrderId: saleOrderId,
    invoiceId: invoiceId,
    collectionSessionId: collectionSessionId,
    operatorId: operatorId,
    operationUuid: operationUuid,
    lines: lines,
  );

  /// Serializa el banco del catálogo custom de Odoo 19.5
  /// antes de enviar una linea de pago. Público — usado directamente por
  /// `pos_payment_tab.dart`.
  Map<String, dynamic> applyBankFieldGuard(
    Map<String, dynamic> vals,
    PaymentLine line,
  ) => _paymentLines.applyBankFieldGuard(vals, line);

  /// Guarda y crea factura
  Future<PaymentInvoiceResult?> savePaymentLinesAndCreateInvoice(
    int saleOrderId,
    List<PaymentLine> lines, {
    int? collectionSessionId,
  }) => _paymentLines.savePaymentLinesAndCreateInvoice(
    saleOrderId,
    lines,
    collectionSessionId: collectionSessionId,
  );

  Future<PaymentInvoiceResult> confirmOverpaymentAndCreateInvoice(
    PaymentInvoiceResult pending,
  ) => _paymentLines.confirmOverpaymentAndCreateInvoice(pending);

  /// Crea factura para venta a crédito (sin pagos)
  ///
  /// Usa el wizard estándar de Odoo para crear la factura.
  /// Retorna el ID de la factura creada o null si falla.
  Future<int?> createInvoiceForCreditSale(int saleOrderId) =>
      _paymentLines.createInvoiceForCreditSale(saleOrderId);

  /// Reads display fields for an invoice created by a payment operation.
  /// Keeps Odoo access out of presentation widgets.
  Future<Map<String, dynamic>?> getInvoiceSummary(int invoiceId) async {
    final result = await _odoo.call(
      model: 'account.move',
      method: 'search_read',
      kwargs: {
        'domain': [
          ['id', '=', invoiceId],
        ],
        'fields': ['name', 'state'],
        'limit': 1,
      },
    );
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    return null;
  }

  // ============================================================
  // CRÉDITO - Información de crédito del cliente
  // ============================================================

  /// Obtiene la información de crédito del cliente
  Future<PartnerCreditInfo?> getPartnerCreditInfo(int partnerId) =>
      _credit.getPartnerCreditInfo(partnerId);

  // ============================================================
  // RETENCIONES - Registro de retenciones del cliente
  // ============================================================

  /// Obtiene los tipos de retención disponibles
  Future<List<WithholdingType>> getWithholdingTypes() =>
      _credit.getWithholdingTypes();

  /// Registra una retención del cliente en la orden de venta
  ///
  /// Crea un registro de retención (out_withhold) vinculado a la factura.
  ///
  /// El wizard l10n_ec.wizard.account.withhold usa context para recibir
  /// las facturas via active_ids/active_model, y el campo related_invoice_ids
  /// se computa automáticamente.
  ///
  /// [invoiceId]: ID de la factura (account.move)
  /// [lines]: Líneas de retención con tax_id, base y amount
  /// [authorizationNumber]: Número de autorización SRI (49 dígitos)
  /// [documentNumber]: Secuencia de la retención (ej: 001-001-000000001)
  Future<WithholdingResult> registerWithholding({
    required int invoiceId,
    required List<WithholdingLine> lines,
    String? authorizationNumber,
    String? documentNumber,
  }) => _credit.registerWithholding(
    invoiceId: invoiceId,
    lines: lines,
    authorizationNumber: authorizationNumber,
    documentNumber: documentNumber,
  );

  // ============================================================
  // APROBACIÓN DE CRÉDITO
  // ============================================================

  /// Solicita aprobación de crédito para una orden de venta
  ///
  /// Crea una solicitud de aprobación cuando el cliente:
  /// - Excede su límite de crédito
  /// - Tiene deudas vencidas
  /// - Requiere crédito temporal
  Future<CreditApprovalResult> requestCreditApproval({
    required int partnerId,
    required double transactionAmount,
    required CreditAuthorizationType authorizationType,
    int? saleOrderId,
    int? invoiceId,
    int? paymentTermId,
    double? creditLimit,
  }) => _credit.requestCreditApproval(
    partnerId: partnerId,
    transactionAmount: transactionAmount,
    authorizationType: authorizationType,
    saleOrderId: saleOrderId,
    invoiceId: invoiceId,
    paymentTermId: paymentTermId,
    creditLimit: creditLimit,
  );

  /// Verifica si una orden tiene aprobación de crédito pendiente
  Future<bool> hasPendingCreditApproval(int saleOrderId) =>
      _credit.hasPendingCreditApproval(saleOrderId);

  /// Verifica si una orden tiene aprobación de crédito aprobada
  Future<bool> hasCreditApprovalApproved(int saleOrderId) =>
      _credit.hasCreditApprovalApproved(saleOrderId);

  // ============================================================
  // COBROS DE SESIÓN - Para vista de collection
  // ============================================================

  /// Obtiene los cobros registrados en una sesión de cobranza
  ///
  /// Retorna lista de pagos asociados a la sesión especificada
  Future<List<SessionPayment>> getSessionPayments(int sessionId) async {
    try {
      final payments = await _odoo.call(
        model: 'account.payment',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['collection_session_id', '=', sessionId],
          ],
          'fields': [
            'id',
            'name',
            'partner_id',
            'journal_id',
            'payment_method_line_id',
            'amount',
            'payment_type',
            'state',
            'date',
            'ref',
            'payment_origin_type',
            'payment_method_category',
            'reconciled_invoice_ids',
          ],
          'order': 'date desc, id desc',
        },
      );

      if (payments == null || payments is! List) {
        return [];
      }

      return payments
          .map((p) => SessionPayment.fromOdoo(p as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting session payments', e, st);
      return [];
    }
  }

  /// Obtiene el detalle de un cobro específico
  Future<SessionPayment?> getPaymentDetail(int paymentId) async {
    try {
      final payments = await _odoo.call(
        model: 'account.payment',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', '=', paymentId],
          ],
          'fields': [
            'id',
            'name',
            'partner_id',
            'journal_id',
            'payment_method_line_id',
            'amount',
            'payment_type',
            'state',
            'date',
            'ref',
            'payment_origin_type',
            'payment_method_category',
            'reconciled_invoice_ids',
            'move_id',
            'currency_id',
            'company_id',
            'collection_session_id',
          ],
          'limit': 1,
        },
      );

      if (payments == null || payments is! List || payments.isEmpty) {
        return null;
      }

      return SessionPayment.fromOdoo(payments[0] as Map<String, dynamic>);
    } catch (e, st) {
      logger.e('[PaymentService]', 'Error getting payment detail', e, st);
      return null;
    }
  }

  // ============================================================
  // VALIDACIÓN DE PAGOS
  // ============================================================

  /// Valida las líneas de pago antes de guardar
  ///
  /// Verifica:
  /// - Que cada línea tenga monto > 0
  /// - Que los anticipos tengan saldo suficiente
  /// - Que las notas de crédito tengan saldo residual suficiente
  /// - Detecta sobrepago (pagos > total de orden)
  ///
  /// [lines]: Lista de líneas de pago a validar
  /// [orderTotal]: Monto total de la orden
  /// [partnerId]: ID del cliente (para validar anticipos y NC)
  ///
  /// Retorna un ValidationResult con errores/advertencias
  Future<ValidationResult> validatePaymentLines({
    required List<PaymentLine> lines,
    required double orderTotal,
    int? partnerId,
  }) => _validation.validatePaymentLines(
    lines: lines,
    orderTotal: orderTotal,
    partnerId: partnerId,
  );

  /// Valida si el cliente puede hacer una venta a crédito
  ///
  /// Verifica:
  /// - Límite de crédito
  /// - Deuda vencida
  /// - Crédito disponible vs monto de la orden
  ///
  /// [partnerId]: ID del cliente
  /// [orderAmount]: Monto total de la orden (solo crédito, no pagos al contado)
  Future<ValidationResult> validateCreditSale({
    required int partnerId,
    required double orderAmount,
  }) => _validation.validateCreditSale(
    partnerId: partnerId,
    orderAmount: orderAmount,
  );

  /// Calcula el monto pendiente después de aplicar los pagos
  ///
  /// [orderTotal]: Monto total de la orden
  /// [lines]: Líneas de pago aplicadas
  ///
  /// Retorna el monto pendiente (positivo) o sobrepago (negativo)
  double calculateRemainingAmount(double orderTotal, List<PaymentLine> lines) =>
      _validation.calculateRemainingAmount(orderTotal, lines);

  /// Indica si hay sobrepago
  bool hasOverpayment(double orderTotal, List<PaymentLine> lines) =>
      _validation.hasOverpayment(orderTotal, lines);

  /// Indica si el pago está completo
  bool isPaymentComplete(double orderTotal, List<PaymentLine> lines) =>
      _validation.isPaymentComplete(orderTotal, lines);
}
