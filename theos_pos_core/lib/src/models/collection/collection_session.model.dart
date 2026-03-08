/// Collection Session Model (collection.session)
///
/// Model for collection sessions with all fields needed by theos_pos.
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'collection_session.model.freezed.dart';
part 'collection_session.model.g.dart';

/// Session state enum
enum SessionState {
  @JsonValue('opening_control')
  openingControl('opening_control'),
  @JsonValue('opened')
  opened('opened'),
  @JsonValue('closing_control')
  closingControl('closing_control'),
  @JsonValue('closed')
  closed('closed');

  final String code;
  const SessionState(this.code);
}

/// Extension for SessionState
extension SessionStateExtension on SessionState {
  String get label {
    switch (this) {
      case SessionState.openingControl:
        return 'Control de Apertura';
      case SessionState.opened:
        return 'Abierta';
      case SessionState.closingControl:
        return 'Control de Cierre';
      case SessionState.closed:
        return 'Cerrada';
    }
  }

  String toOdooString() {
    switch (this) {
      case SessionState.openingControl:
        return 'opening_control';
      case SessionState.opened:
        return 'opened';
      case SessionState.closingControl:
        return 'closing_control';
      case SessionState.closed:
        return 'closed';
    }
  }

  static SessionState fromString(dynamic value) {
    if (value == null || value == false) return SessionState.openingControl;
    final strValue = value is String ? value : value.toString();
    switch (strValue) {
      case 'opening_control':
        return SessionState.openingControl;
      case 'opened':
        return SessionState.opened;
      case 'closing_control':
        return SessionState.closingControl;
      case 'closed':
        return SessionState.closed;
      default:
        return SessionState.openingControl;
    }
  }
}

/// Collection Session model representing collection.session in Odoo
///
/// ## State Machine (equivalent to @api.constrains state transitions)
/// - opening_control -> opened
/// - opened -> closing_control
/// - closing_control -> closed
///
/// ## Computed fields (equivalent to @api.depends)
/// - totalCollected -> depends on cashEntries and payments
/// - cashDifference -> depends on closingBalance and expectedBalance
@OdooModel('collection.session', tableName: 'collection_session')
@freezed
abstract class CollectionSession with _$CollectionSession {
  const CollectionSession._();

  const factory CollectionSession({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooSelection() required SessionState state,
    @OdooString(odooName: 'session_uuid') String? sessionUuid,

    // Relaciones
    @OdooMany2One('collection.config', odooName: 'config_id')
    int? configId,
    @OdooMany2OneName(sourceField: 'config_id') String? configName,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooMany2One('res.users', odooName: 'user_id') int? userId,
    @OdooMany2OneName(sourceField: 'user_id') String? userName,
    @OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,
    @OdooString(odooName: 'currency_symbol') String? currencySymbol,
    @OdooMany2One('account.journal', odooName: 'cash_journal_id')
    int? cashJournalId,
    @OdooMany2OneName(sourceField: 'cash_journal_id') String? cashJournalName,

    // Fechas
    @OdooDateTime(odooName: 'start_at') DateTime? startAt,
    @OdooDateTime(odooName: 'stop_at') DateTime? stopAt,

    // Control de efectivo
    @OdooFloat(odooName: 'cash_register_balance_start') @Default(0.0)
    double cashRegisterBalanceStart,
    @OdooFloat(odooName: 'cash_register_balance_end_real') @Default(0.0)
    double cashRegisterBalanceEndReal,
    @OdooFloat(odooName: 'cash_register_balance_end') @Default(0.0)
    double cashRegisterBalanceEnd,
    @OdooFloat(odooName: 'cash_register_difference') @Default(0.0)
    double cashRegisterDifference,

    // Contadores
    @OdooInteger(odooName: 'order_count') @Default(0) int orderCount,
    @OdooInteger(odooName: 'invoice_count') @Default(0) int invoiceCount,
    @OdooInteger(odooName: 'payment_count') @Default(0) int paymentCount,
    @OdooInteger(odooName: 'advance_count') @Default(0) int advanceCount,
    @OdooInteger(odooName: 'cheque_recibido_count') @Default(0)
    int chequeRecibidoCount,
    @OdooInteger(odooName: 'cash_out_count') @Default(0) int cashOutCount,
    @OdooInteger(odooName: 'deposit_count') @Default(0) int depositCount,
    @OdooInteger(odooName: 'withhold_count') @Default(0) int withholdCount,

    // Totales monetarios
    @OdooFloat(odooName: 'total_payments_amount') @Default(0.0)
    double totalPaymentsAmount,
    @OdooFloat(odooName: 'total_cash_out_amount') @Default(0.0)
    double totalCashOutAmount,
    @OdooFloat(odooName: 'total_deposit_amount') @Default(0.0)
    double totalDepositAmount,
    @OdooFloat(odooName: 'total_withhold_amount') @Default(0.0)
    double totalWithholdAmount,
    @OdooFloat(odooName: 'total_cash_advance_amount') @Default(0.0)
    double totalCashAdvanceAmount,

    // Desglose salidas de efectivo
    @OdooFloat(odooName: 'cash_out_security_total') @Default(0.0)
    double cashOutSecurityTotal,
    @OdooFloat(odooName: 'cash_out_invoice_total') @Default(0.0)
    double cashOutInvoiceTotal,
    @OdooFloat(odooName: 'cash_out_refund_total') @Default(0.0)
    double cashOutRefundTotal,
    @OdooFloat(odooName: 'cash_out_withhold_total') @Default(0.0)
    double cashOutWithholdTotal,
    @OdooFloat(odooName: 'cash_out_other_total') @Default(0.0)
    double cashOutOtherTotal,

    // Totales de cheques
    @OdooFloat(odooName: 'checks_on_day_total') @Default(0.0)
    double checksOnDayTotal,
    @OdooFloat(odooName: 'checks_postdated_total') @Default(0.0)
    double checksPostdatedTotal,
    @OdooFloat(odooName: 'advance_checks_on_day_total') @Default(0.0)
    double advanceChecksOnDayTotal,
    @OdooFloat(odooName: 'advance_checks_postdated_total') @Default(0.0)
    double advanceChecksPostdatedTotal,
    @OdooFloat(odooName: 'total_checks_on_day') @Default(0.0)
    double totalChecksOnDay,
    @OdooFloat(odooName: 'total_checks_postdated') @Default(0.0)
    double totalChecksPostdated,

    // Control de depositos
    @OdooFloat(odooName: 'system_deposits_cash_total') @Default(0.0)
    double systemDepositsCashTotal,
    @OdooFloat(odooName: 'manual_deposits_cash_total') @Default(0.0)
    double manualDepositsCashTotal,
    @OdooFloat(odooName: 'diff_deposits_cash_total') @Default(0.0)
    double diffDepositsCashTotal,
    @OdooFloat(odooName: 'system_deposits_checks_total') @Default(0.0)
    double systemDepositsChecksTotal,
    @OdooFloat(odooName: 'manual_deposits_checks_total') @Default(0.0)
    double manualDepositsChecksTotal,
    @OdooFloat(odooName: 'diff_deposits_checks_total') @Default(0.0)
    double diffDepositsChecksTotal,

    // Facturas del cierre
    @OdooFloat(odooName: 'total_cash_invoices_amount') @Default(0.0)
    double totalCashInvoicesAmount,
    @OdooFloat(odooName: 'total_cash_collected_amount') @Default(0.0)
    double totalCashCollectedAmount,
    @OdooFloat(odooName: 'total_cash_pending_amount') @Default(0.0)
    double totalCashPendingAmount,
    @OdooFloat(odooName: 'total_credit_orders_amount') @Default(0.0)
    double totalCreditOrdersAmount,
    @OdooFloat(odooName: 'total_credit_invoices_amount') @Default(0.0)
    double totalCreditInvoicesAmount,
    @OdooFloat(odooName: 'credit_sales_difference') @Default(0.0)
    double creditSalesDifference,

    // Conteo manual - Sistema
    @OdooFloat(odooName: 'system_checks_on_day') @Default(0.0)
    double systemChecksOnDay,
    @OdooFloat(odooName: 'system_checks_postdated') @Default(0.0)
    double systemChecksPostdated,
    @OdooFloat(odooName: 'system_cards_total') @Default(0.0)
    double systemCardsTotal,
    @OdooFloat(odooName: 'system_transfers_total') @Default(0.0)
    double systemTransfersTotal,
    @OdooFloat(odooName: 'system_advances_total') @Default(0.0)
    double systemAdvancesTotal,
    @OdooFloat(odooName: 'system_credit_notes_total') @Default(0.0)
    double systemCreditNotesTotal,

    // Conteo manual - Manual
    @OdooFloat(odooName: 'manual_checks_on_day') @Default(0.0)
    double manualChecksOnDay,
    @OdooFloat(odooName: 'manual_checks_postdated') @Default(0.0)
    double manualChecksPostdated,
    @OdooFloat(odooName: 'manual_cards_total') @Default(0.0)
    double manualCardsTotal,
    @OdooFloat(odooName: 'manual_transfers_total') @Default(0.0)
    double manualTransfersTotal,
    @OdooFloat(odooName: 'manual_advances_total') @Default(0.0)
    double manualAdvancesTotal,
    @OdooFloat(odooName: 'manual_credit_notes_total') @Default(0.0)
    double manualCreditNotesTotal,
    @OdooFloat(odooName: 'manual_withholds_total') @Default(0.0)
    double manualWithholdsTotal,

    // Conteo manual - Diferencias
    @OdooFloat(odooName: 'diff_checks_on_day') @Default(0.0)
    double diffChecksOnDay,
    @OdooFloat(odooName: 'diff_checks_postdated') @Default(0.0)
    double diffChecksPostdated,
    @OdooFloat(odooName: 'diff_cards_total') @Default(0.0) double diffCardsTotal,
    @OdooFloat(odooName: 'diff_transfers_total') @Default(0.0)
    double diffTransfersTotal,
    @OdooFloat(odooName: 'diff_advances_total') @Default(0.0)
    double diffAdvancesTotal,
    @OdooFloat(odooName: 'diff_credit_notes_total') @Default(0.0)
    double diffCreditNotesTotal,
    @OdooFloat(odooName: 'diff_withholds_total') @Default(0.0)
    double diffWithholdsTotal,

    // Totales resumen
    @OdooFloat(odooName: 'summary_system_total') @Default(0.0)
    double summarySystemTotal,
    @OdooFloat(odooName: 'summary_manual_total') @Default(0.0)
    double summaryManualTotal,
    @OdooFloat(odooName: 'summary_diff_total') @Default(0.0)
    double summaryDiffTotal,

    // Detalle de Cobros - Depositos
    @OdooFloat(odooName: 'fact_deposits_cash') @Default(0.0)
    double factDepositsCash,
    @OdooFloat(odooName: 'fact_deposits_checks') @Default(0.0)
    double factDepositsChecks,
    @OdooFloat(odooName: 'cartera_deposits_cash') @Default(0.0)
    double carteraDepositsCash,
    @OdooFloat(odooName: 'cartera_deposits_checks') @Default(0.0)
    double carteraDepositsChecks,
    @OdooFloat(odooName: 'anticipo_deposits_cash') @Default(0.0)
    double anticipoDepositsCash,
    @OdooFloat(odooName: 'anticipo_deposits_checks') @Default(0.0)
    double anticipoDepositsChecks,

    // Anticipos cruzados
    @OdooFloat(odooName: 'fact_advances_used') @Default(0.0)
    double factAdvancesUsed,
    @OdooFloat(odooName: 'cartera_advances_used') @Default(0.0)
    double carteraAdvancesUsed,
    @OdooFloat(odooName: 'summary_advances_used_total') @Default(0.0)
    double summaryAdvancesUsedTotal,

    // Total facturas con NC y retenciones
    @OdooFloat(odooName: 'fact_total_with_nc_withholds') @Default(0.0)
    double factTotalWithNcWithholds,

    // Desglose facturas del dia
    @OdooFloat(odooName: 'fact_cash') @Default(0.0) double factCash,
    @OdooFloat(odooName: 'fact_cards') @Default(0.0) double factCards,
    @OdooFloat(odooName: 'fact_transfers') @Default(0.0) double factTransfers,
    @OdooFloat(odooName: 'fact_checks_day') @Default(0.0) double factChecksDay,
    @OdooFloat(odooName: 'fact_checks_post') @Default(0.0) double factChecksPost,
    @OdooFloat(odooName: 'fact_total') @Default(0.0) double factTotal,

    // Desglose cartera
    @OdooFloat(odooName: 'cartera_cash') @Default(0.0) double carteraCash,
    @OdooFloat(odooName: 'cartera_cards') @Default(0.0) double carteraCards,
    @OdooFloat(odooName: 'cartera_transfers') @Default(0.0)
    double carteraTransfers,
    @OdooFloat(odooName: 'cartera_checks_day') @Default(0.0)
    double carteraChecksDay,
    @OdooFloat(odooName: 'cartera_checks_post') @Default(0.0)
    double carteraChecksPost,
    @OdooFloat(odooName: 'cartera_total') @Default(0.0) double carteraTotal,

    // Desglose anticipos
    @OdooFloat(odooName: 'anticipo_cash') @Default(0.0) double anticipoCash,
    @OdooFloat(odooName: 'anticipo_cards') @Default(0.0) double anticipoCards,
    @OdooFloat(odooName: 'anticipo_transfers') @Default(0.0)
    double anticipoTransfers,
    @OdooFloat(odooName: 'anticipo_checks_day') @Default(0.0)
    double anticipoChecksDay,
    @OdooFloat(odooName: 'anticipo_checks_post') @Default(0.0)
    double anticipoChecksPost,
    @OdooFloat(odooName: 'anticipo_total') @Default(0.0) double anticipoTotal,

    // Totales generales
    @OdooFloat(odooName: 'total_cash') @Default(0.0) double totalCash,
    @OdooFloat(odooName: 'total_cards') @Default(0.0) double totalCards,
    @OdooFloat(odooName: 'total_transfers') @Default(0.0) double totalTransfers,
    @OdooFloat(odooName: 'total_checks_day') @Default(0.0) double totalChecksDay,
    @OdooFloat(odooName: 'total_checks_post') @Default(0.0)
    double totalChecksPost,
    @OdooFloat(odooName: 'total_general') @Default(0.0) double totalGeneral,

    // Validacion supervisor
    @OdooMany2One('res.users', odooName: 'supervisor_id') int? supervisorId,
    @OdooMany2OneName(sourceField: 'supervisor_id') String? supervisorName,
    @OdooDateTime(odooName: 'supervisor_validation_date')
    DateTime? supervisorValidationDate,
    @OdooString(odooName: 'supervisor_notes') String? supervisorNotes,
    @OdooString(odooName: 'opening_notes') String? openingNotes,
    @OdooString(odooName: 'closing_notes') String? closingNotes,

    // Sync
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? lastSyncDate,
    @OdooLocalOnly() @Default(0) int syncRetryCount,
    @OdooLocalOnly() DateTime? lastSyncAttempt,
  }) = _CollectionSession;

  factory CollectionSession.fromJson(Map<String, dynamic> json) =>
      _$CollectionSessionFromJson(json);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPUTED FIELDS (equivalente a @api.depends)
  // ═══════════════════════════════════════════════════════════════════════════

  String get displayState => state.label;
  bool get isOpen => state == SessionState.opened;
  bool get isClosingControl => state == SessionState.closingControl;
  bool get isClosed => state == SessionState.closed;
  bool get canOpen => state == SessionState.openingControl;
  bool get canStartClosing => state == SessionState.opened;
  bool get canClose => state == SessionState.closingControl;
  bool get hasCashDifference => cashRegisterDifference.abs() > 0.01;

  double get expectedEndingBalance =>
      cashRegisterBalanceStart +
      totalPaymentsAmount -
      totalCashOutAmount -
      totalDepositAmount;

  /// Indica si se puede registrar transacciones
  bool get canRegisterTransactions => isOpen;

  /// Indica si se puede modificar balance inicial
  bool get canEditOpeningBalance => state == SessionState.openingControl;

  /// Indica si se puede modificar balance final
  bool get canEditClosingBalance => isClosingControl;

  // ═══════════════════════════════════════════════════════════════════════════
  // ONCHANGE SIMULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Simula onchange del balance de efectivo real.
  ///
  /// Actualiza la diferencia calculada.
  CollectionSession onEndBalanceRealChanged(double newEndBalanceReal) {
    final difference = newEndBalanceReal - cashRegisterBalanceEnd;
    return copyWith(
      cashRegisterBalanceEndReal: newEndBalanceReal,
      cashRegisterDifference: difference,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una nueva sesion con valores minimos.
  ///
  /// Similar a: collection.session.new({...})
  factory CollectionSession.newSession({
    required int configId,
    String? configName,
    required int userId,
    String? userName,
    int? companyId,
    String? companyName,
    int? cashJournalId,
    String? cashJournalName,
    double startingBalance = 0.0,
  }) {
    return CollectionSession(
      id: 0,
      name: 'Nueva Sesion',
      state: SessionState.openingControl,
      configId: configId,
      configName: configName,
      userId: userId,
      userName: userName,
      companyId: companyId,
      companyName: companyName,
      cashJournalId: cashJournalId,
      cashJournalName: cashJournalName,
      cashRegisterBalanceStart: startingBalance,
      startAt: DateTime.now(),
      isSynced: false,
    );
  }
}
