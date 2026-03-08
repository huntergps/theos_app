// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_session.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CollectionSession _$CollectionSessionFromJson(
  Map<String, dynamic> json,
) => _CollectionSession(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  state: $enumDecode(_$SessionStateEnumMap, json['state']),
  sessionUuid: json['sessionUuid'] as String?,
  configId: (json['configId'] as num?)?.toInt(),
  configName: json['configName'] as String?,
  companyId: (json['companyId'] as num?)?.toInt(),
  companyName: json['companyName'] as String?,
  userId: (json['userId'] as num?)?.toInt(),
  userName: json['userName'] as String?,
  currencyId: (json['currencyId'] as num?)?.toInt(),
  currencySymbol: json['currencySymbol'] as String?,
  cashJournalId: (json['cashJournalId'] as num?)?.toInt(),
  cashJournalName: json['cashJournalName'] as String?,
  startAt: json['startAt'] == null
      ? null
      : DateTime.parse(json['startAt'] as String),
  stopAt: json['stopAt'] == null
      ? null
      : DateTime.parse(json['stopAt'] as String),
  cashRegisterBalanceStart:
      (json['cashRegisterBalanceStart'] as num?)?.toDouble() ?? 0.0,
  cashRegisterBalanceEndReal:
      (json['cashRegisterBalanceEndReal'] as num?)?.toDouble() ?? 0.0,
  cashRegisterBalanceEnd:
      (json['cashRegisterBalanceEnd'] as num?)?.toDouble() ?? 0.0,
  cashRegisterDifference:
      (json['cashRegisterDifference'] as num?)?.toDouble() ?? 0.0,
  orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
  invoiceCount: (json['invoiceCount'] as num?)?.toInt() ?? 0,
  paymentCount: (json['paymentCount'] as num?)?.toInt() ?? 0,
  advanceCount: (json['advanceCount'] as num?)?.toInt() ?? 0,
  chequeRecibidoCount: (json['chequeRecibidoCount'] as num?)?.toInt() ?? 0,
  cashOutCount: (json['cashOutCount'] as num?)?.toInt() ?? 0,
  depositCount: (json['depositCount'] as num?)?.toInt() ?? 0,
  withholdCount: (json['withholdCount'] as num?)?.toInt() ?? 0,
  totalPaymentsAmount: (json['totalPaymentsAmount'] as num?)?.toDouble() ?? 0.0,
  totalCashOutAmount: (json['totalCashOutAmount'] as num?)?.toDouble() ?? 0.0,
  totalDepositAmount: (json['totalDepositAmount'] as num?)?.toDouble() ?? 0.0,
  totalWithholdAmount: (json['totalWithholdAmount'] as num?)?.toDouble() ?? 0.0,
  totalCashAdvanceAmount:
      (json['totalCashAdvanceAmount'] as num?)?.toDouble() ?? 0.0,
  cashOutSecurityTotal:
      (json['cashOutSecurityTotal'] as num?)?.toDouble() ?? 0.0,
  cashOutInvoiceTotal: (json['cashOutInvoiceTotal'] as num?)?.toDouble() ?? 0.0,
  cashOutRefundTotal: (json['cashOutRefundTotal'] as num?)?.toDouble() ?? 0.0,
  cashOutWithholdTotal:
      (json['cashOutWithholdTotal'] as num?)?.toDouble() ?? 0.0,
  cashOutOtherTotal: (json['cashOutOtherTotal'] as num?)?.toDouble() ?? 0.0,
  checksOnDayTotal: (json['checksOnDayTotal'] as num?)?.toDouble() ?? 0.0,
  checksPostdatedTotal:
      (json['checksPostdatedTotal'] as num?)?.toDouble() ?? 0.0,
  advanceChecksOnDayTotal:
      (json['advanceChecksOnDayTotal'] as num?)?.toDouble() ?? 0.0,
  advanceChecksPostdatedTotal:
      (json['advanceChecksPostdatedTotal'] as num?)?.toDouble() ?? 0.0,
  totalChecksOnDay: (json['totalChecksOnDay'] as num?)?.toDouble() ?? 0.0,
  totalChecksPostdated:
      (json['totalChecksPostdated'] as num?)?.toDouble() ?? 0.0,
  systemDepositsCashTotal:
      (json['systemDepositsCashTotal'] as num?)?.toDouble() ?? 0.0,
  manualDepositsCashTotal:
      (json['manualDepositsCashTotal'] as num?)?.toDouble() ?? 0.0,
  diffDepositsCashTotal:
      (json['diffDepositsCashTotal'] as num?)?.toDouble() ?? 0.0,
  systemDepositsChecksTotal:
      (json['systemDepositsChecksTotal'] as num?)?.toDouble() ?? 0.0,
  manualDepositsChecksTotal:
      (json['manualDepositsChecksTotal'] as num?)?.toDouble() ?? 0.0,
  diffDepositsChecksTotal:
      (json['diffDepositsChecksTotal'] as num?)?.toDouble() ?? 0.0,
  totalCashInvoicesAmount:
      (json['totalCashInvoicesAmount'] as num?)?.toDouble() ?? 0.0,
  totalCashCollectedAmount:
      (json['totalCashCollectedAmount'] as num?)?.toDouble() ?? 0.0,
  totalCashPendingAmount:
      (json['totalCashPendingAmount'] as num?)?.toDouble() ?? 0.0,
  totalCreditOrdersAmount:
      (json['totalCreditOrdersAmount'] as num?)?.toDouble() ?? 0.0,
  totalCreditInvoicesAmount:
      (json['totalCreditInvoicesAmount'] as num?)?.toDouble() ?? 0.0,
  creditSalesDifference:
      (json['creditSalesDifference'] as num?)?.toDouble() ?? 0.0,
  systemChecksOnDay: (json['systemChecksOnDay'] as num?)?.toDouble() ?? 0.0,
  systemChecksPostdated:
      (json['systemChecksPostdated'] as num?)?.toDouble() ?? 0.0,
  systemCardsTotal: (json['systemCardsTotal'] as num?)?.toDouble() ?? 0.0,
  systemTransfersTotal:
      (json['systemTransfersTotal'] as num?)?.toDouble() ?? 0.0,
  systemAdvancesTotal: (json['systemAdvancesTotal'] as num?)?.toDouble() ?? 0.0,
  systemCreditNotesTotal:
      (json['systemCreditNotesTotal'] as num?)?.toDouble() ?? 0.0,
  manualChecksOnDay: (json['manualChecksOnDay'] as num?)?.toDouble() ?? 0.0,
  manualChecksPostdated:
      (json['manualChecksPostdated'] as num?)?.toDouble() ?? 0.0,
  manualCardsTotal: (json['manualCardsTotal'] as num?)?.toDouble() ?? 0.0,
  manualTransfersTotal:
      (json['manualTransfersTotal'] as num?)?.toDouble() ?? 0.0,
  manualAdvancesTotal: (json['manualAdvancesTotal'] as num?)?.toDouble() ?? 0.0,
  manualCreditNotesTotal:
      (json['manualCreditNotesTotal'] as num?)?.toDouble() ?? 0.0,
  manualWithholdsTotal:
      (json['manualWithholdsTotal'] as num?)?.toDouble() ?? 0.0,
  diffChecksOnDay: (json['diffChecksOnDay'] as num?)?.toDouble() ?? 0.0,
  diffChecksPostdated: (json['diffChecksPostdated'] as num?)?.toDouble() ?? 0.0,
  diffCardsTotal: (json['diffCardsTotal'] as num?)?.toDouble() ?? 0.0,
  diffTransfersTotal: (json['diffTransfersTotal'] as num?)?.toDouble() ?? 0.0,
  diffAdvancesTotal: (json['diffAdvancesTotal'] as num?)?.toDouble() ?? 0.0,
  diffCreditNotesTotal:
      (json['diffCreditNotesTotal'] as num?)?.toDouble() ?? 0.0,
  diffWithholdsTotal: (json['diffWithholdsTotal'] as num?)?.toDouble() ?? 0.0,
  summarySystemTotal: (json['summarySystemTotal'] as num?)?.toDouble() ?? 0.0,
  summaryManualTotal: (json['summaryManualTotal'] as num?)?.toDouble() ?? 0.0,
  summaryDiffTotal: (json['summaryDiffTotal'] as num?)?.toDouble() ?? 0.0,
  factDepositsCash: (json['factDepositsCash'] as num?)?.toDouble() ?? 0.0,
  factDepositsChecks: (json['factDepositsChecks'] as num?)?.toDouble() ?? 0.0,
  carteraDepositsCash: (json['carteraDepositsCash'] as num?)?.toDouble() ?? 0.0,
  carteraDepositsChecks:
      (json['carteraDepositsChecks'] as num?)?.toDouble() ?? 0.0,
  anticipoDepositsCash:
      (json['anticipoDepositsCash'] as num?)?.toDouble() ?? 0.0,
  anticipoDepositsChecks:
      (json['anticipoDepositsChecks'] as num?)?.toDouble() ?? 0.0,
  factAdvancesUsed: (json['factAdvancesUsed'] as num?)?.toDouble() ?? 0.0,
  carteraAdvancesUsed: (json['carteraAdvancesUsed'] as num?)?.toDouble() ?? 0.0,
  summaryAdvancesUsedTotal:
      (json['summaryAdvancesUsedTotal'] as num?)?.toDouble() ?? 0.0,
  factTotalWithNcWithholds:
      (json['factTotalWithNcWithholds'] as num?)?.toDouble() ?? 0.0,
  factCash: (json['factCash'] as num?)?.toDouble() ?? 0.0,
  factCards: (json['factCards'] as num?)?.toDouble() ?? 0.0,
  factTransfers: (json['factTransfers'] as num?)?.toDouble() ?? 0.0,
  factChecksDay: (json['factChecksDay'] as num?)?.toDouble() ?? 0.0,
  factChecksPost: (json['factChecksPost'] as num?)?.toDouble() ?? 0.0,
  factTotal: (json['factTotal'] as num?)?.toDouble() ?? 0.0,
  carteraCash: (json['carteraCash'] as num?)?.toDouble() ?? 0.0,
  carteraCards: (json['carteraCards'] as num?)?.toDouble() ?? 0.0,
  carteraTransfers: (json['carteraTransfers'] as num?)?.toDouble() ?? 0.0,
  carteraChecksDay: (json['carteraChecksDay'] as num?)?.toDouble() ?? 0.0,
  carteraChecksPost: (json['carteraChecksPost'] as num?)?.toDouble() ?? 0.0,
  carteraTotal: (json['carteraTotal'] as num?)?.toDouble() ?? 0.0,
  anticipoCash: (json['anticipoCash'] as num?)?.toDouble() ?? 0.0,
  anticipoCards: (json['anticipoCards'] as num?)?.toDouble() ?? 0.0,
  anticipoTransfers: (json['anticipoTransfers'] as num?)?.toDouble() ?? 0.0,
  anticipoChecksDay: (json['anticipoChecksDay'] as num?)?.toDouble() ?? 0.0,
  anticipoChecksPost: (json['anticipoChecksPost'] as num?)?.toDouble() ?? 0.0,
  anticipoTotal: (json['anticipoTotal'] as num?)?.toDouble() ?? 0.0,
  totalCash: (json['totalCash'] as num?)?.toDouble() ?? 0.0,
  totalCards: (json['totalCards'] as num?)?.toDouble() ?? 0.0,
  totalTransfers: (json['totalTransfers'] as num?)?.toDouble() ?? 0.0,
  totalChecksDay: (json['totalChecksDay'] as num?)?.toDouble() ?? 0.0,
  totalChecksPost: (json['totalChecksPost'] as num?)?.toDouble() ?? 0.0,
  totalGeneral: (json['totalGeneral'] as num?)?.toDouble() ?? 0.0,
  supervisorId: (json['supervisorId'] as num?)?.toInt(),
  supervisorName: json['supervisorName'] as String?,
  supervisorValidationDate: json['supervisorValidationDate'] == null
      ? null
      : DateTime.parse(json['supervisorValidationDate'] as String),
  supervisorNotes: json['supervisorNotes'] as String?,
  openingNotes: json['openingNotes'] as String?,
  closingNotes: json['closingNotes'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  lastSyncDate: json['lastSyncDate'] == null
      ? null
      : DateTime.parse(json['lastSyncDate'] as String),
  syncRetryCount: (json['syncRetryCount'] as num?)?.toInt() ?? 0,
  lastSyncAttempt: json['lastSyncAttempt'] == null
      ? null
      : DateTime.parse(json['lastSyncAttempt'] as String),
);

Map<String, dynamic> _$CollectionSessionToJson(_CollectionSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'state': _$SessionStateEnumMap[instance.state]!,
      'sessionUuid': instance.sessionUuid,
      'configId': instance.configId,
      'configName': instance.configName,
      'companyId': instance.companyId,
      'companyName': instance.companyName,
      'userId': instance.userId,
      'userName': instance.userName,
      'currencyId': instance.currencyId,
      'currencySymbol': instance.currencySymbol,
      'cashJournalId': instance.cashJournalId,
      'cashJournalName': instance.cashJournalName,
      'startAt': instance.startAt?.toIso8601String(),
      'stopAt': instance.stopAt?.toIso8601String(),
      'cashRegisterBalanceStart': instance.cashRegisterBalanceStart,
      'cashRegisterBalanceEndReal': instance.cashRegisterBalanceEndReal,
      'cashRegisterBalanceEnd': instance.cashRegisterBalanceEnd,
      'cashRegisterDifference': instance.cashRegisterDifference,
      'orderCount': instance.orderCount,
      'invoiceCount': instance.invoiceCount,
      'paymentCount': instance.paymentCount,
      'advanceCount': instance.advanceCount,
      'chequeRecibidoCount': instance.chequeRecibidoCount,
      'cashOutCount': instance.cashOutCount,
      'depositCount': instance.depositCount,
      'withholdCount': instance.withholdCount,
      'totalPaymentsAmount': instance.totalPaymentsAmount,
      'totalCashOutAmount': instance.totalCashOutAmount,
      'totalDepositAmount': instance.totalDepositAmount,
      'totalWithholdAmount': instance.totalWithholdAmount,
      'totalCashAdvanceAmount': instance.totalCashAdvanceAmount,
      'cashOutSecurityTotal': instance.cashOutSecurityTotal,
      'cashOutInvoiceTotal': instance.cashOutInvoiceTotal,
      'cashOutRefundTotal': instance.cashOutRefundTotal,
      'cashOutWithholdTotal': instance.cashOutWithholdTotal,
      'cashOutOtherTotal': instance.cashOutOtherTotal,
      'checksOnDayTotal': instance.checksOnDayTotal,
      'checksPostdatedTotal': instance.checksPostdatedTotal,
      'advanceChecksOnDayTotal': instance.advanceChecksOnDayTotal,
      'advanceChecksPostdatedTotal': instance.advanceChecksPostdatedTotal,
      'totalChecksOnDay': instance.totalChecksOnDay,
      'totalChecksPostdated': instance.totalChecksPostdated,
      'systemDepositsCashTotal': instance.systemDepositsCashTotal,
      'manualDepositsCashTotal': instance.manualDepositsCashTotal,
      'diffDepositsCashTotal': instance.diffDepositsCashTotal,
      'systemDepositsChecksTotal': instance.systemDepositsChecksTotal,
      'manualDepositsChecksTotal': instance.manualDepositsChecksTotal,
      'diffDepositsChecksTotal': instance.diffDepositsChecksTotal,
      'totalCashInvoicesAmount': instance.totalCashInvoicesAmount,
      'totalCashCollectedAmount': instance.totalCashCollectedAmount,
      'totalCashPendingAmount': instance.totalCashPendingAmount,
      'totalCreditOrdersAmount': instance.totalCreditOrdersAmount,
      'totalCreditInvoicesAmount': instance.totalCreditInvoicesAmount,
      'creditSalesDifference': instance.creditSalesDifference,
      'systemChecksOnDay': instance.systemChecksOnDay,
      'systemChecksPostdated': instance.systemChecksPostdated,
      'systemCardsTotal': instance.systemCardsTotal,
      'systemTransfersTotal': instance.systemTransfersTotal,
      'systemAdvancesTotal': instance.systemAdvancesTotal,
      'systemCreditNotesTotal': instance.systemCreditNotesTotal,
      'manualChecksOnDay': instance.manualChecksOnDay,
      'manualChecksPostdated': instance.manualChecksPostdated,
      'manualCardsTotal': instance.manualCardsTotal,
      'manualTransfersTotal': instance.manualTransfersTotal,
      'manualAdvancesTotal': instance.manualAdvancesTotal,
      'manualCreditNotesTotal': instance.manualCreditNotesTotal,
      'manualWithholdsTotal': instance.manualWithholdsTotal,
      'diffChecksOnDay': instance.diffChecksOnDay,
      'diffChecksPostdated': instance.diffChecksPostdated,
      'diffCardsTotal': instance.diffCardsTotal,
      'diffTransfersTotal': instance.diffTransfersTotal,
      'diffAdvancesTotal': instance.diffAdvancesTotal,
      'diffCreditNotesTotal': instance.diffCreditNotesTotal,
      'diffWithholdsTotal': instance.diffWithholdsTotal,
      'summarySystemTotal': instance.summarySystemTotal,
      'summaryManualTotal': instance.summaryManualTotal,
      'summaryDiffTotal': instance.summaryDiffTotal,
      'factDepositsCash': instance.factDepositsCash,
      'factDepositsChecks': instance.factDepositsChecks,
      'carteraDepositsCash': instance.carteraDepositsCash,
      'carteraDepositsChecks': instance.carteraDepositsChecks,
      'anticipoDepositsCash': instance.anticipoDepositsCash,
      'anticipoDepositsChecks': instance.anticipoDepositsChecks,
      'factAdvancesUsed': instance.factAdvancesUsed,
      'carteraAdvancesUsed': instance.carteraAdvancesUsed,
      'summaryAdvancesUsedTotal': instance.summaryAdvancesUsedTotal,
      'factTotalWithNcWithholds': instance.factTotalWithNcWithholds,
      'factCash': instance.factCash,
      'factCards': instance.factCards,
      'factTransfers': instance.factTransfers,
      'factChecksDay': instance.factChecksDay,
      'factChecksPost': instance.factChecksPost,
      'factTotal': instance.factTotal,
      'carteraCash': instance.carteraCash,
      'carteraCards': instance.carteraCards,
      'carteraTransfers': instance.carteraTransfers,
      'carteraChecksDay': instance.carteraChecksDay,
      'carteraChecksPost': instance.carteraChecksPost,
      'carteraTotal': instance.carteraTotal,
      'anticipoCash': instance.anticipoCash,
      'anticipoCards': instance.anticipoCards,
      'anticipoTransfers': instance.anticipoTransfers,
      'anticipoChecksDay': instance.anticipoChecksDay,
      'anticipoChecksPost': instance.anticipoChecksPost,
      'anticipoTotal': instance.anticipoTotal,
      'totalCash': instance.totalCash,
      'totalCards': instance.totalCards,
      'totalTransfers': instance.totalTransfers,
      'totalChecksDay': instance.totalChecksDay,
      'totalChecksPost': instance.totalChecksPost,
      'totalGeneral': instance.totalGeneral,
      'supervisorId': instance.supervisorId,
      'supervisorName': instance.supervisorName,
      'supervisorValidationDate': instance.supervisorValidationDate
          ?.toIso8601String(),
      'supervisorNotes': instance.supervisorNotes,
      'openingNotes': instance.openingNotes,
      'closingNotes': instance.closingNotes,
      'isSynced': instance.isSynced,
      'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
      'syncRetryCount': instance.syncRetryCount,
      'lastSyncAttempt': instance.lastSyncAttempt?.toIso8601String(),
    };

const _$SessionStateEnumMap = {
  SessionState.openingControl: 'opening_control',
  SessionState.opened: 'opened',
  SessionState.closingControl: 'closing_control',
  SessionState.closed: 'closed',
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for CollectionSession.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: collection.session
class CollectionSessionManager extends OdooModelManager<CollectionSession>
    with GenericDriftOperations<CollectionSession> {
  @override
  String get odooModel => 'collection.session';

  @override
  String get tableName => 'collection_session';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'state',
    'session_uuid',
    'config_id',
    'company_id',
    'user_id',
    'currency_id',
    'currency_symbol',
    'cash_journal_id',
    'start_at',
    'stop_at',
    'cash_register_balance_start',
    'cash_register_balance_end_real',
    'cash_register_balance_end',
    'cash_register_difference',
    'order_count',
    'invoice_count',
    'payment_count',
    'advance_count',
    'cheque_recibido_count',
    'cash_out_count',
    'deposit_count',
    'withhold_count',
    'total_payments_amount',
    'total_cash_out_amount',
    'total_deposit_amount',
    'total_withhold_amount',
    'total_cash_advance_amount',
    'cash_out_security_total',
    'cash_out_invoice_total',
    'cash_out_refund_total',
    'cash_out_withhold_total',
    'cash_out_other_total',
    'checks_on_day_total',
    'checks_postdated_total',
    'advance_checks_on_day_total',
    'advance_checks_postdated_total',
    'total_checks_on_day',
    'total_checks_postdated',
    'system_deposits_cash_total',
    'manual_deposits_cash_total',
    'diff_deposits_cash_total',
    'system_deposits_checks_total',
    'manual_deposits_checks_total',
    'diff_deposits_checks_total',
    'total_cash_invoices_amount',
    'total_cash_collected_amount',
    'total_cash_pending_amount',
    'total_credit_orders_amount',
    'total_credit_invoices_amount',
    'credit_sales_difference',
    'system_checks_on_day',
    'system_checks_postdated',
    'system_cards_total',
    'system_transfers_total',
    'system_advances_total',
    'system_credit_notes_total',
    'manual_checks_on_day',
    'manual_checks_postdated',
    'manual_cards_total',
    'manual_transfers_total',
    'manual_advances_total',
    'manual_credit_notes_total',
    'manual_withholds_total',
    'diff_checks_on_day',
    'diff_checks_postdated',
    'diff_cards_total',
    'diff_transfers_total',
    'diff_advances_total',
    'diff_credit_notes_total',
    'diff_withholds_total',
    'summary_system_total',
    'summary_manual_total',
    'summary_diff_total',
    'fact_deposits_cash',
    'fact_deposits_checks',
    'cartera_deposits_cash',
    'cartera_deposits_checks',
    'anticipo_deposits_cash',
    'anticipo_deposits_checks',
    'fact_advances_used',
    'cartera_advances_used',
    'summary_advances_used_total',
    'fact_total_with_nc_withholds',
    'fact_cash',
    'fact_cards',
    'fact_transfers',
    'fact_checks_day',
    'fact_checks_post',
    'fact_total',
    'cartera_cash',
    'cartera_cards',
    'cartera_transfers',
    'cartera_checks_day',
    'cartera_checks_post',
    'cartera_total',
    'anticipo_cash',
    'anticipo_cards',
    'anticipo_transfers',
    'anticipo_checks_day',
    'anticipo_checks_post',
    'anticipo_total',
    'total_cash',
    'total_cards',
    'total_transfers',
    'total_checks_day',
    'total_checks_post',
    'total_general',
    'supervisor_id',
    'supervisor_validation_date',
    'supervisor_notes',
    'opening_notes',
    'closing_notes',
  ];

  @override
  CollectionSession fromOdoo(Map<String, dynamic> data) {
    return CollectionSession(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      state: SessionState.values.firstWhere(
        (e) => e.code == parseOdooSelection(data['state']),
        orElse: () => SessionState.values.first,
      ),
      sessionUuid: parseOdooString(data['session_uuid']),
      configId: extractMany2oneId(data['config_id']),
      configName: extractMany2oneName(data['config_id']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      userId: extractMany2oneId(data['user_id']),
      userName: extractMany2oneName(data['user_id']),
      currencyId: extractMany2oneId(data['currency_id']),
      currencySymbol: parseOdooString(data['currency_symbol']),
      cashJournalId: extractMany2oneId(data['cash_journal_id']),
      cashJournalName: extractMany2oneName(data['cash_journal_id']),
      startAt: parseOdooDateTime(data['start_at']),
      stopAt: parseOdooDateTime(data['stop_at']),
      cashRegisterBalanceStart:
          parseOdooDouble(data['cash_register_balance_start']) ?? 0.0,
      cashRegisterBalanceEndReal:
          parseOdooDouble(data['cash_register_balance_end_real']) ?? 0.0,
      cashRegisterBalanceEnd:
          parseOdooDouble(data['cash_register_balance_end']) ?? 0.0,
      cashRegisterDifference:
          parseOdooDouble(data['cash_register_difference']) ?? 0.0,
      orderCount: parseOdooInt(data['order_count']) ?? 0,
      invoiceCount: parseOdooInt(data['invoice_count']) ?? 0,
      paymentCount: parseOdooInt(data['payment_count']) ?? 0,
      advanceCount: parseOdooInt(data['advance_count']) ?? 0,
      chequeRecibidoCount: parseOdooInt(data['cheque_recibido_count']) ?? 0,
      cashOutCount: parseOdooInt(data['cash_out_count']) ?? 0,
      depositCount: parseOdooInt(data['deposit_count']) ?? 0,
      withholdCount: parseOdooInt(data['withhold_count']) ?? 0,
      totalPaymentsAmount:
          parseOdooDouble(data['total_payments_amount']) ?? 0.0,
      totalCashOutAmount: parseOdooDouble(data['total_cash_out_amount']) ?? 0.0,
      totalDepositAmount: parseOdooDouble(data['total_deposit_amount']) ?? 0.0,
      totalWithholdAmount:
          parseOdooDouble(data['total_withhold_amount']) ?? 0.0,
      totalCashAdvanceAmount:
          parseOdooDouble(data['total_cash_advance_amount']) ?? 0.0,
      cashOutSecurityTotal:
          parseOdooDouble(data['cash_out_security_total']) ?? 0.0,
      cashOutInvoiceTotal:
          parseOdooDouble(data['cash_out_invoice_total']) ?? 0.0,
      cashOutRefundTotal: parseOdooDouble(data['cash_out_refund_total']) ?? 0.0,
      cashOutWithholdTotal:
          parseOdooDouble(data['cash_out_withhold_total']) ?? 0.0,
      cashOutOtherTotal: parseOdooDouble(data['cash_out_other_total']) ?? 0.0,
      checksOnDayTotal: parseOdooDouble(data['checks_on_day_total']) ?? 0.0,
      checksPostdatedTotal:
          parseOdooDouble(data['checks_postdated_total']) ?? 0.0,
      advanceChecksOnDayTotal:
          parseOdooDouble(data['advance_checks_on_day_total']) ?? 0.0,
      advanceChecksPostdatedTotal:
          parseOdooDouble(data['advance_checks_postdated_total']) ?? 0.0,
      totalChecksOnDay: parseOdooDouble(data['total_checks_on_day']) ?? 0.0,
      totalChecksPostdated:
          parseOdooDouble(data['total_checks_postdated']) ?? 0.0,
      systemDepositsCashTotal:
          parseOdooDouble(data['system_deposits_cash_total']) ?? 0.0,
      manualDepositsCashTotal:
          parseOdooDouble(data['manual_deposits_cash_total']) ?? 0.0,
      diffDepositsCashTotal:
          parseOdooDouble(data['diff_deposits_cash_total']) ?? 0.0,
      systemDepositsChecksTotal:
          parseOdooDouble(data['system_deposits_checks_total']) ?? 0.0,
      manualDepositsChecksTotal:
          parseOdooDouble(data['manual_deposits_checks_total']) ?? 0.0,
      diffDepositsChecksTotal:
          parseOdooDouble(data['diff_deposits_checks_total']) ?? 0.0,
      totalCashInvoicesAmount:
          parseOdooDouble(data['total_cash_invoices_amount']) ?? 0.0,
      totalCashCollectedAmount:
          parseOdooDouble(data['total_cash_collected_amount']) ?? 0.0,
      totalCashPendingAmount:
          parseOdooDouble(data['total_cash_pending_amount']) ?? 0.0,
      totalCreditOrdersAmount:
          parseOdooDouble(data['total_credit_orders_amount']) ?? 0.0,
      totalCreditInvoicesAmount:
          parseOdooDouble(data['total_credit_invoices_amount']) ?? 0.0,
      creditSalesDifference:
          parseOdooDouble(data['credit_sales_difference']) ?? 0.0,
      systemChecksOnDay: parseOdooDouble(data['system_checks_on_day']) ?? 0.0,
      systemChecksPostdated:
          parseOdooDouble(data['system_checks_postdated']) ?? 0.0,
      systemCardsTotal: parseOdooDouble(data['system_cards_total']) ?? 0.0,
      systemTransfersTotal:
          parseOdooDouble(data['system_transfers_total']) ?? 0.0,
      systemAdvancesTotal:
          parseOdooDouble(data['system_advances_total']) ?? 0.0,
      systemCreditNotesTotal:
          parseOdooDouble(data['system_credit_notes_total']) ?? 0.0,
      manualChecksOnDay: parseOdooDouble(data['manual_checks_on_day']) ?? 0.0,
      manualChecksPostdated:
          parseOdooDouble(data['manual_checks_postdated']) ?? 0.0,
      manualCardsTotal: parseOdooDouble(data['manual_cards_total']) ?? 0.0,
      manualTransfersTotal:
          parseOdooDouble(data['manual_transfers_total']) ?? 0.0,
      manualAdvancesTotal:
          parseOdooDouble(data['manual_advances_total']) ?? 0.0,
      manualCreditNotesTotal:
          parseOdooDouble(data['manual_credit_notes_total']) ?? 0.0,
      manualWithholdsTotal:
          parseOdooDouble(data['manual_withholds_total']) ?? 0.0,
      diffChecksOnDay: parseOdooDouble(data['diff_checks_on_day']) ?? 0.0,
      diffChecksPostdated:
          parseOdooDouble(data['diff_checks_postdated']) ?? 0.0,
      diffCardsTotal: parseOdooDouble(data['diff_cards_total']) ?? 0.0,
      diffTransfersTotal: parseOdooDouble(data['diff_transfers_total']) ?? 0.0,
      diffAdvancesTotal: parseOdooDouble(data['diff_advances_total']) ?? 0.0,
      diffCreditNotesTotal:
          parseOdooDouble(data['diff_credit_notes_total']) ?? 0.0,
      diffWithholdsTotal: parseOdooDouble(data['diff_withholds_total']) ?? 0.0,
      summarySystemTotal: parseOdooDouble(data['summary_system_total']) ?? 0.0,
      summaryManualTotal: parseOdooDouble(data['summary_manual_total']) ?? 0.0,
      summaryDiffTotal: parseOdooDouble(data['summary_diff_total']) ?? 0.0,
      factDepositsCash: parseOdooDouble(data['fact_deposits_cash']) ?? 0.0,
      factDepositsChecks: parseOdooDouble(data['fact_deposits_checks']) ?? 0.0,
      carteraDepositsCash:
          parseOdooDouble(data['cartera_deposits_cash']) ?? 0.0,
      carteraDepositsChecks:
          parseOdooDouble(data['cartera_deposits_checks']) ?? 0.0,
      anticipoDepositsCash:
          parseOdooDouble(data['anticipo_deposits_cash']) ?? 0.0,
      anticipoDepositsChecks:
          parseOdooDouble(data['anticipo_deposits_checks']) ?? 0.0,
      factAdvancesUsed: parseOdooDouble(data['fact_advances_used']) ?? 0.0,
      carteraAdvancesUsed:
          parseOdooDouble(data['cartera_advances_used']) ?? 0.0,
      summaryAdvancesUsedTotal:
          parseOdooDouble(data['summary_advances_used_total']) ?? 0.0,
      factTotalWithNcWithholds:
          parseOdooDouble(data['fact_total_with_nc_withholds']) ?? 0.0,
      factCash: parseOdooDouble(data['fact_cash']) ?? 0.0,
      factCards: parseOdooDouble(data['fact_cards']) ?? 0.0,
      factTransfers: parseOdooDouble(data['fact_transfers']) ?? 0.0,
      factChecksDay: parseOdooDouble(data['fact_checks_day']) ?? 0.0,
      factChecksPost: parseOdooDouble(data['fact_checks_post']) ?? 0.0,
      factTotal: parseOdooDouble(data['fact_total']) ?? 0.0,
      carteraCash: parseOdooDouble(data['cartera_cash']) ?? 0.0,
      carteraCards: parseOdooDouble(data['cartera_cards']) ?? 0.0,
      carteraTransfers: parseOdooDouble(data['cartera_transfers']) ?? 0.0,
      carteraChecksDay: parseOdooDouble(data['cartera_checks_day']) ?? 0.0,
      carteraChecksPost: parseOdooDouble(data['cartera_checks_post']) ?? 0.0,
      carteraTotal: parseOdooDouble(data['cartera_total']) ?? 0.0,
      anticipoCash: parseOdooDouble(data['anticipo_cash']) ?? 0.0,
      anticipoCards: parseOdooDouble(data['anticipo_cards']) ?? 0.0,
      anticipoTransfers: parseOdooDouble(data['anticipo_transfers']) ?? 0.0,
      anticipoChecksDay: parseOdooDouble(data['anticipo_checks_day']) ?? 0.0,
      anticipoChecksPost: parseOdooDouble(data['anticipo_checks_post']) ?? 0.0,
      anticipoTotal: parseOdooDouble(data['anticipo_total']) ?? 0.0,
      totalCash: parseOdooDouble(data['total_cash']) ?? 0.0,
      totalCards: parseOdooDouble(data['total_cards']) ?? 0.0,
      totalTransfers: parseOdooDouble(data['total_transfers']) ?? 0.0,
      totalChecksDay: parseOdooDouble(data['total_checks_day']) ?? 0.0,
      totalChecksPost: parseOdooDouble(data['total_checks_post']) ?? 0.0,
      totalGeneral: parseOdooDouble(data['total_general']) ?? 0.0,
      supervisorId: extractMany2oneId(data['supervisor_id']),
      supervisorName: extractMany2oneName(data['supervisor_id']),
      supervisorValidationDate: parseOdooDateTime(
        data['supervisor_validation_date'],
      ),
      supervisorNotes: parseOdooString(data['supervisor_notes']),
      openingNotes: parseOdooString(data['opening_notes']),
      closingNotes: parseOdooString(data['closing_notes']),
      isSynced: false,
      syncRetryCount: 0,
    );
  }

  @override
  Map<String, dynamic> toOdoo(CollectionSession record) {
    return {
      'name': record.name,
      'state': record.state.code,
      'session_uuid': record.sessionUuid,
      'config_id': record.configId,
      'company_id': record.companyId,
      'user_id': record.userId,
      'currency_id': record.currencyId,
      'currency_symbol': record.currencySymbol,
      'cash_journal_id': record.cashJournalId,
      'start_at': formatOdooDateTime(record.startAt),
      'stop_at': formatOdooDateTime(record.stopAt),
      'cash_register_balance_start': record.cashRegisterBalanceStart,
      'cash_register_balance_end_real': record.cashRegisterBalanceEndReal,
      'cash_register_balance_end': record.cashRegisterBalanceEnd,
      'cash_register_difference': record.cashRegisterDifference,
      'order_count': record.orderCount,
      'invoice_count': record.invoiceCount,
      'payment_count': record.paymentCount,
      'advance_count': record.advanceCount,
      'cheque_recibido_count': record.chequeRecibidoCount,
      'cash_out_count': record.cashOutCount,
      'deposit_count': record.depositCount,
      'withhold_count': record.withholdCount,
      'total_payments_amount': record.totalPaymentsAmount,
      'total_cash_out_amount': record.totalCashOutAmount,
      'total_deposit_amount': record.totalDepositAmount,
      'total_withhold_amount': record.totalWithholdAmount,
      'total_cash_advance_amount': record.totalCashAdvanceAmount,
      'cash_out_security_total': record.cashOutSecurityTotal,
      'cash_out_invoice_total': record.cashOutInvoiceTotal,
      'cash_out_refund_total': record.cashOutRefundTotal,
      'cash_out_withhold_total': record.cashOutWithholdTotal,
      'cash_out_other_total': record.cashOutOtherTotal,
      'checks_on_day_total': record.checksOnDayTotal,
      'checks_postdated_total': record.checksPostdatedTotal,
      'advance_checks_on_day_total': record.advanceChecksOnDayTotal,
      'advance_checks_postdated_total': record.advanceChecksPostdatedTotal,
      'total_checks_on_day': record.totalChecksOnDay,
      'total_checks_postdated': record.totalChecksPostdated,
      'system_deposits_cash_total': record.systemDepositsCashTotal,
      'manual_deposits_cash_total': record.manualDepositsCashTotal,
      'diff_deposits_cash_total': record.diffDepositsCashTotal,
      'system_deposits_checks_total': record.systemDepositsChecksTotal,
      'manual_deposits_checks_total': record.manualDepositsChecksTotal,
      'diff_deposits_checks_total': record.diffDepositsChecksTotal,
      'total_cash_invoices_amount': record.totalCashInvoicesAmount,
      'total_cash_collected_amount': record.totalCashCollectedAmount,
      'total_cash_pending_amount': record.totalCashPendingAmount,
      'total_credit_orders_amount': record.totalCreditOrdersAmount,
      'total_credit_invoices_amount': record.totalCreditInvoicesAmount,
      'credit_sales_difference': record.creditSalesDifference,
      'system_checks_on_day': record.systemChecksOnDay,
      'system_checks_postdated': record.systemChecksPostdated,
      'system_cards_total': record.systemCardsTotal,
      'system_transfers_total': record.systemTransfersTotal,
      'system_advances_total': record.systemAdvancesTotal,
      'system_credit_notes_total': record.systemCreditNotesTotal,
      'manual_checks_on_day': record.manualChecksOnDay,
      'manual_checks_postdated': record.manualChecksPostdated,
      'manual_cards_total': record.manualCardsTotal,
      'manual_transfers_total': record.manualTransfersTotal,
      'manual_advances_total': record.manualAdvancesTotal,
      'manual_credit_notes_total': record.manualCreditNotesTotal,
      'manual_withholds_total': record.manualWithholdsTotal,
      'diff_checks_on_day': record.diffChecksOnDay,
      'diff_checks_postdated': record.diffChecksPostdated,
      'diff_cards_total': record.diffCardsTotal,
      'diff_transfers_total': record.diffTransfersTotal,
      'diff_advances_total': record.diffAdvancesTotal,
      'diff_credit_notes_total': record.diffCreditNotesTotal,
      'diff_withholds_total': record.diffWithholdsTotal,
      'summary_system_total': record.summarySystemTotal,
      'summary_manual_total': record.summaryManualTotal,
      'summary_diff_total': record.summaryDiffTotal,
      'fact_deposits_cash': record.factDepositsCash,
      'fact_deposits_checks': record.factDepositsChecks,
      'cartera_deposits_cash': record.carteraDepositsCash,
      'cartera_deposits_checks': record.carteraDepositsChecks,
      'anticipo_deposits_cash': record.anticipoDepositsCash,
      'anticipo_deposits_checks': record.anticipoDepositsChecks,
      'fact_advances_used': record.factAdvancesUsed,
      'cartera_advances_used': record.carteraAdvancesUsed,
      'summary_advances_used_total': record.summaryAdvancesUsedTotal,
      'fact_total_with_nc_withholds': record.factTotalWithNcWithholds,
      'fact_cash': record.factCash,
      'fact_cards': record.factCards,
      'fact_transfers': record.factTransfers,
      'fact_checks_day': record.factChecksDay,
      'fact_checks_post': record.factChecksPost,
      'fact_total': record.factTotal,
      'cartera_cash': record.carteraCash,
      'cartera_cards': record.carteraCards,
      'cartera_transfers': record.carteraTransfers,
      'cartera_checks_day': record.carteraChecksDay,
      'cartera_checks_post': record.carteraChecksPost,
      'cartera_total': record.carteraTotal,
      'anticipo_cash': record.anticipoCash,
      'anticipo_cards': record.anticipoCards,
      'anticipo_transfers': record.anticipoTransfers,
      'anticipo_checks_day': record.anticipoChecksDay,
      'anticipo_checks_post': record.anticipoChecksPost,
      'anticipo_total': record.anticipoTotal,
      'total_cash': record.totalCash,
      'total_cards': record.totalCards,
      'total_transfers': record.totalTransfers,
      'total_checks_day': record.totalChecksDay,
      'total_checks_post': record.totalChecksPost,
      'total_general': record.totalGeneral,
      'supervisor_id': record.supervisorId,
      'supervisor_validation_date': formatOdooDateTime(
        record.supervisorValidationDate,
      ),
      'supervisor_notes': record.supervisorNotes,
      'opening_notes': record.openingNotes,
      'closing_notes': record.closingNotes,
    };
  }

  @override
  CollectionSession fromDrift(dynamic row) {
    return CollectionSession(
      id: row.odooId as int,
      name: row.name as String,
      state: SessionState.values.firstWhere(
        (e) => e.code == (row.state as String?),
        orElse: () => SessionState.values.first,
      ),
      sessionUuid: row.sessionUuid as String?,
      configId: row.configId as int?,
      configName: row.configName as String?,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      userId: row.userId as int?,
      userName: row.userName as String?,
      currencyId: row.currencyId as int?,
      currencySymbol: row.currencySymbol as String?,
      cashJournalId: row.cashJournalId as int?,
      cashJournalName: row.cashJournalName as String?,
      startAt: row.startAt as DateTime?,
      stopAt: row.stopAt as DateTime?,
      cashRegisterBalanceStart: row.cashRegisterBalanceStart as double,
      cashRegisterBalanceEndReal: row.cashRegisterBalanceEndReal as double,
      cashRegisterBalanceEnd: row.cashRegisterBalanceEnd as double,
      cashRegisterDifference: row.cashRegisterDifference as double,
      orderCount: row.orderCount as int,
      invoiceCount: row.invoiceCount as int,
      paymentCount: row.paymentCount as int,
      advanceCount: row.advanceCount as int,
      chequeRecibidoCount: row.chequeRecibidoCount as int,
      cashOutCount: row.cashOutCount as int,
      depositCount: row.depositCount as int,
      withholdCount: row.withholdCount as int,
      totalPaymentsAmount: row.totalPaymentsAmount as double,
      totalCashOutAmount: row.totalCashOutAmount as double,
      totalDepositAmount: row.totalDepositAmount as double,
      totalWithholdAmount: row.totalWithholdAmount as double,
      totalCashAdvanceAmount: row.totalCashAdvanceAmount as double,
      cashOutSecurityTotal: row.cashOutSecurityTotal as double,
      cashOutInvoiceTotal: row.cashOutInvoiceTotal as double,
      cashOutRefundTotal: row.cashOutRefundTotal as double,
      cashOutWithholdTotal: row.cashOutWithholdTotal as double,
      cashOutOtherTotal: row.cashOutOtherTotal as double,
      checksOnDayTotal: row.checksOnDayTotal as double,
      checksPostdatedTotal: row.checksPostdatedTotal as double,
      advanceChecksOnDayTotal: row.advanceChecksOnDayTotal as double,
      advanceChecksPostdatedTotal: row.advanceChecksPostdatedTotal as double,
      totalChecksOnDay: row.totalChecksOnDay as double,
      totalChecksPostdated: row.totalChecksPostdated as double,
      systemDepositsCashTotal: row.systemDepositsCashTotal as double,
      manualDepositsCashTotal: row.manualDepositsCashTotal as double,
      diffDepositsCashTotal: row.diffDepositsCashTotal as double,
      systemDepositsChecksTotal: row.systemDepositsChecksTotal as double,
      manualDepositsChecksTotal: row.manualDepositsChecksTotal as double,
      diffDepositsChecksTotal: row.diffDepositsChecksTotal as double,
      totalCashInvoicesAmount: row.totalCashInvoicesAmount as double,
      totalCashCollectedAmount: row.totalCashCollectedAmount as double,
      totalCashPendingAmount: row.totalCashPendingAmount as double,
      totalCreditOrdersAmount: row.totalCreditOrdersAmount as double,
      totalCreditInvoicesAmount: row.totalCreditInvoicesAmount as double,
      creditSalesDifference: row.creditSalesDifference as double,
      systemChecksOnDay: row.systemChecksOnDay as double,
      systemChecksPostdated: row.systemChecksPostdated as double,
      systemCardsTotal: row.systemCardsTotal as double,
      systemTransfersTotal: row.systemTransfersTotal as double,
      systemAdvancesTotal: row.systemAdvancesTotal as double,
      systemCreditNotesTotal: row.systemCreditNotesTotal as double,
      manualChecksOnDay: row.manualChecksOnDay as double,
      manualChecksPostdated: row.manualChecksPostdated as double,
      manualCardsTotal: row.manualCardsTotal as double,
      manualTransfersTotal: row.manualTransfersTotal as double,
      manualAdvancesTotal: row.manualAdvancesTotal as double,
      manualCreditNotesTotal: row.manualCreditNotesTotal as double,
      manualWithholdsTotal: row.manualWithholdsTotal as double,
      diffChecksOnDay: row.diffChecksOnDay as double,
      diffChecksPostdated: row.diffChecksPostdated as double,
      diffCardsTotal: row.diffCardsTotal as double,
      diffTransfersTotal: row.diffTransfersTotal as double,
      diffAdvancesTotal: row.diffAdvancesTotal as double,
      diffCreditNotesTotal: row.diffCreditNotesTotal as double,
      diffWithholdsTotal: row.diffWithholdsTotal as double,
      summarySystemTotal: row.summarySystemTotal as double,
      summaryManualTotal: row.summaryManualTotal as double,
      summaryDiffTotal: row.summaryDiffTotal as double,
      factDepositsCash: row.factDepositsCash as double,
      factDepositsChecks: row.factDepositsChecks as double,
      carteraDepositsCash: row.carteraDepositsCash as double,
      carteraDepositsChecks: row.carteraDepositsChecks as double,
      anticipoDepositsCash: row.anticipoDepositsCash as double,
      anticipoDepositsChecks: row.anticipoDepositsChecks as double,
      factAdvancesUsed: row.factAdvancesUsed as double,
      carteraAdvancesUsed: row.carteraAdvancesUsed as double,
      summaryAdvancesUsedTotal: row.summaryAdvancesUsedTotal as double,
      factTotalWithNcWithholds: row.factTotalWithNcWithholds as double,
      factCash: row.factCash as double,
      factCards: row.factCards as double,
      factTransfers: row.factTransfers as double,
      factChecksDay: row.factChecksDay as double,
      factChecksPost: row.factChecksPost as double,
      factTotal: row.factTotal as double,
      carteraCash: row.carteraCash as double,
      carteraCards: row.carteraCards as double,
      carteraTransfers: row.carteraTransfers as double,
      carteraChecksDay: row.carteraChecksDay as double,
      carteraChecksPost: row.carteraChecksPost as double,
      carteraTotal: row.carteraTotal as double,
      anticipoCash: row.anticipoCash as double,
      anticipoCards: row.anticipoCards as double,
      anticipoTransfers: row.anticipoTransfers as double,
      anticipoChecksDay: row.anticipoChecksDay as double,
      anticipoChecksPost: row.anticipoChecksPost as double,
      anticipoTotal: row.anticipoTotal as double,
      totalCash: row.totalCash as double,
      totalCards: row.totalCards as double,
      totalTransfers: row.totalTransfers as double,
      totalChecksDay: row.totalChecksDay as double,
      totalChecksPost: row.totalChecksPost as double,
      totalGeneral: row.totalGeneral as double,
      supervisorId: row.supervisorId as int?,
      supervisorName: row.supervisorName as String?,
      supervisorValidationDate: row.supervisorValidationDate as DateTime?,
      supervisorNotes: row.supervisorNotes as String?,
      openingNotes: row.openingNotes as String?,
      closingNotes: row.closingNotes as String?,
      isSynced: row.isSynced as bool? ?? false,
      lastSyncDate: row.lastSyncDate as DateTime?,
      syncRetryCount: row.syncRetryCount as int? ?? 0,
      lastSyncAttempt: row.lastSyncAttempt as DateTime?,
    );
  }

  @override
  int getId(CollectionSession record) => record.id;

  @override
  String? getUuid(CollectionSession record) => null;

  @override
  CollectionSession withIdAndUuid(
    CollectionSession record,
    int id,
    String uuid,
  ) {
    return record.copyWith(id: id);
  }

  @override
  CollectionSession withSyncStatus(CollectionSession record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'name': 'name',
    'state': 'state',
    'session_uuid': 'sessionUuid',
    'config_id': 'configId',
    'company_id': 'companyId',
    'user_id': 'userId',
    'currency_id': 'currencyId',
    'currency_symbol': 'currencySymbol',
    'cash_journal_id': 'cashJournalId',
    'start_at': 'startAt',
    'stop_at': 'stopAt',
    'cash_register_balance_start': 'cashRegisterBalanceStart',
    'cash_register_balance_end_real': 'cashRegisterBalanceEndReal',
    'cash_register_balance_end': 'cashRegisterBalanceEnd',
    'cash_register_difference': 'cashRegisterDifference',
    'order_count': 'orderCount',
    'invoice_count': 'invoiceCount',
    'payment_count': 'paymentCount',
    'advance_count': 'advanceCount',
    'cheque_recibido_count': 'chequeRecibidoCount',
    'cash_out_count': 'cashOutCount',
    'deposit_count': 'depositCount',
    'withhold_count': 'withholdCount',
    'total_payments_amount': 'totalPaymentsAmount',
    'total_cash_out_amount': 'totalCashOutAmount',
    'total_deposit_amount': 'totalDepositAmount',
    'total_withhold_amount': 'totalWithholdAmount',
    'total_cash_advance_amount': 'totalCashAdvanceAmount',
    'cash_out_security_total': 'cashOutSecurityTotal',
    'cash_out_invoice_total': 'cashOutInvoiceTotal',
    'cash_out_refund_total': 'cashOutRefundTotal',
    'cash_out_withhold_total': 'cashOutWithholdTotal',
    'cash_out_other_total': 'cashOutOtherTotal',
    'checks_on_day_total': 'checksOnDayTotal',
    'checks_postdated_total': 'checksPostdatedTotal',
    'advance_checks_on_day_total': 'advanceChecksOnDayTotal',
    'advance_checks_postdated_total': 'advanceChecksPostdatedTotal',
    'total_checks_on_day': 'totalChecksOnDay',
    'total_checks_postdated': 'totalChecksPostdated',
    'system_deposits_cash_total': 'systemDepositsCashTotal',
    'manual_deposits_cash_total': 'manualDepositsCashTotal',
    'diff_deposits_cash_total': 'diffDepositsCashTotal',
    'system_deposits_checks_total': 'systemDepositsChecksTotal',
    'manual_deposits_checks_total': 'manualDepositsChecksTotal',
    'diff_deposits_checks_total': 'diffDepositsChecksTotal',
    'total_cash_invoices_amount': 'totalCashInvoicesAmount',
    'total_cash_collected_amount': 'totalCashCollectedAmount',
    'total_cash_pending_amount': 'totalCashPendingAmount',
    'total_credit_orders_amount': 'totalCreditOrdersAmount',
    'total_credit_invoices_amount': 'totalCreditInvoicesAmount',
    'credit_sales_difference': 'creditSalesDifference',
    'system_checks_on_day': 'systemChecksOnDay',
    'system_checks_postdated': 'systemChecksPostdated',
    'system_cards_total': 'systemCardsTotal',
    'system_transfers_total': 'systemTransfersTotal',
    'system_advances_total': 'systemAdvancesTotal',
    'system_credit_notes_total': 'systemCreditNotesTotal',
    'manual_checks_on_day': 'manualChecksOnDay',
    'manual_checks_postdated': 'manualChecksPostdated',
    'manual_cards_total': 'manualCardsTotal',
    'manual_transfers_total': 'manualTransfersTotal',
    'manual_advances_total': 'manualAdvancesTotal',
    'manual_credit_notes_total': 'manualCreditNotesTotal',
    'manual_withholds_total': 'manualWithholdsTotal',
    'diff_checks_on_day': 'diffChecksOnDay',
    'diff_checks_postdated': 'diffChecksPostdated',
    'diff_cards_total': 'diffCardsTotal',
    'diff_transfers_total': 'diffTransfersTotal',
    'diff_advances_total': 'diffAdvancesTotal',
    'diff_credit_notes_total': 'diffCreditNotesTotal',
    'diff_withholds_total': 'diffWithholdsTotal',
    'summary_system_total': 'summarySystemTotal',
    'summary_manual_total': 'summaryManualTotal',
    'summary_diff_total': 'summaryDiffTotal',
    'fact_deposits_cash': 'factDepositsCash',
    'fact_deposits_checks': 'factDepositsChecks',
    'cartera_deposits_cash': 'carteraDepositsCash',
    'cartera_deposits_checks': 'carteraDepositsChecks',
    'anticipo_deposits_cash': 'anticipoDepositsCash',
    'anticipo_deposits_checks': 'anticipoDepositsChecks',
    'fact_advances_used': 'factAdvancesUsed',
    'cartera_advances_used': 'carteraAdvancesUsed',
    'summary_advances_used_total': 'summaryAdvancesUsedTotal',
    'fact_total_with_nc_withholds': 'factTotalWithNcWithholds',
    'fact_cash': 'factCash',
    'fact_cards': 'factCards',
    'fact_transfers': 'factTransfers',
    'fact_checks_day': 'factChecksDay',
    'fact_checks_post': 'factChecksPost',
    'fact_total': 'factTotal',
    'cartera_cash': 'carteraCash',
    'cartera_cards': 'carteraCards',
    'cartera_transfers': 'carteraTransfers',
    'cartera_checks_day': 'carteraChecksDay',
    'cartera_checks_post': 'carteraChecksPost',
    'cartera_total': 'carteraTotal',
    'anticipo_cash': 'anticipoCash',
    'anticipo_cards': 'anticipoCards',
    'anticipo_transfers': 'anticipoTransfers',
    'anticipo_checks_day': 'anticipoChecksDay',
    'anticipo_checks_post': 'anticipoChecksPost',
    'anticipo_total': 'anticipoTotal',
    'total_cash': 'totalCash',
    'total_cards': 'totalCards',
    'total_transfers': 'totalTransfers',
    'total_checks_day': 'totalChecksDay',
    'total_checks_post': 'totalChecksPost',
    'total_general': 'totalGeneral',
    'supervisor_id': 'supervisorId',
    'supervisor_validation_date': 'supervisorValidationDate',
    'supervisor_notes': 'supervisorNotes',
    'opening_notes': 'openingNotes',
    'closing_notes': 'closingNotes',
  };

  /// Get Dart field name from Odoo field name.
  String? getDartFieldName(String odooField) => fieldMappings[odooField];

  /// Get Odoo field name from Dart field name.
  String? getOdooFieldName(String dartField) {
    for (final entry in fieldMappings.entries) {
      if (entry.value == dartField) return entry.key;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════
  // GenericDriftOperations — Database & Table
  // ═══════════════════════════════════════════════════

  @override
  GeneratedDatabase get database {
    final db = this.db;
    if (db == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return db;
  }

  @override
  TableInfo get table {
    final resolved = resolveTable();
    if (resolved == null) {
      throw StateError('Table \'collection_session\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(CollectionSession record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'state': Variable<String>(record.state.code),
      'session_uuid': driftVar<String>(record.sessionUuid),
      'config_id': driftVar<int>(record.configId),
      'config_id_name': driftVar<String>(record.configName),
      'company_id': driftVar<int>(record.companyId),
      'company_id_name': driftVar<String>(record.companyName),
      'user_id': driftVar<int>(record.userId),
      'user_id_name': driftVar<String>(record.userName),
      'currency_id': driftVar<int>(record.currencyId),
      'currency_symbol': driftVar<String>(record.currencySymbol),
      'cash_journal_id': driftVar<int>(record.cashJournalId),
      'cash_journal_id_name': driftVar<String>(record.cashJournalName),
      'start_at': driftVar<DateTime>(record.startAt),
      'stop_at': driftVar<DateTime>(record.stopAt),
      'cash_register_balance_start': Variable<double>(
        record.cashRegisterBalanceStart,
      ),
      'cash_register_balance_end_real': Variable<double>(
        record.cashRegisterBalanceEndReal,
      ),
      'cash_register_balance_end': Variable<double>(
        record.cashRegisterBalanceEnd,
      ),
      'cash_register_difference': Variable<double>(
        record.cashRegisterDifference,
      ),
      'order_count': Variable<int>(record.orderCount),
      'invoice_count': Variable<int>(record.invoiceCount),
      'payment_count': Variable<int>(record.paymentCount),
      'advance_count': Variable<int>(record.advanceCount),
      'cheque_recibido_count': Variable<int>(record.chequeRecibidoCount),
      'cash_out_count': Variable<int>(record.cashOutCount),
      'deposit_count': Variable<int>(record.depositCount),
      'withhold_count': Variable<int>(record.withholdCount),
      'total_payments_amount': Variable<double>(record.totalPaymentsAmount),
      'total_cash_out_amount': Variable<double>(record.totalCashOutAmount),
      'total_deposit_amount': Variable<double>(record.totalDepositAmount),
      'total_withhold_amount': Variable<double>(record.totalWithholdAmount),
      'total_cash_advance_amount': Variable<double>(
        record.totalCashAdvanceAmount,
      ),
      'cash_out_security_total': Variable<double>(record.cashOutSecurityTotal),
      'cash_out_invoice_total': Variable<double>(record.cashOutInvoiceTotal),
      'cash_out_refund_total': Variable<double>(record.cashOutRefundTotal),
      'cash_out_withhold_total': Variable<double>(record.cashOutWithholdTotal),
      'cash_out_other_total': Variable<double>(record.cashOutOtherTotal),
      'checks_on_day_total': Variable<double>(record.checksOnDayTotal),
      'checks_postdated_total': Variable<double>(record.checksPostdatedTotal),
      'advance_checks_on_day_total': Variable<double>(
        record.advanceChecksOnDayTotal,
      ),
      'advance_checks_postdated_total': Variable<double>(
        record.advanceChecksPostdatedTotal,
      ),
      'total_checks_on_day': Variable<double>(record.totalChecksOnDay),
      'total_checks_postdated': Variable<double>(record.totalChecksPostdated),
      'system_deposits_cash_total': Variable<double>(
        record.systemDepositsCashTotal,
      ),
      'manual_deposits_cash_total': Variable<double>(
        record.manualDepositsCashTotal,
      ),
      'diff_deposits_cash_total': Variable<double>(
        record.diffDepositsCashTotal,
      ),
      'system_deposits_checks_total': Variable<double>(
        record.systemDepositsChecksTotal,
      ),
      'manual_deposits_checks_total': Variable<double>(
        record.manualDepositsChecksTotal,
      ),
      'diff_deposits_checks_total': Variable<double>(
        record.diffDepositsChecksTotal,
      ),
      'total_cash_invoices_amount': Variable<double>(
        record.totalCashInvoicesAmount,
      ),
      'total_cash_collected_amount': Variable<double>(
        record.totalCashCollectedAmount,
      ),
      'total_cash_pending_amount': Variable<double>(
        record.totalCashPendingAmount,
      ),
      'total_credit_orders_amount': Variable<double>(
        record.totalCreditOrdersAmount,
      ),
      'total_credit_invoices_amount': Variable<double>(
        record.totalCreditInvoicesAmount,
      ),
      'credit_sales_difference': Variable<double>(record.creditSalesDifference),
      'system_checks_on_day': Variable<double>(record.systemChecksOnDay),
      'system_checks_postdated': Variable<double>(record.systemChecksPostdated),
      'system_cards_total': Variable<double>(record.systemCardsTotal),
      'system_transfers_total': Variable<double>(record.systemTransfersTotal),
      'system_advances_total': Variable<double>(record.systemAdvancesTotal),
      'system_credit_notes_total': Variable<double>(
        record.systemCreditNotesTotal,
      ),
      'manual_checks_on_day': Variable<double>(record.manualChecksOnDay),
      'manual_checks_postdated': Variable<double>(record.manualChecksPostdated),
      'manual_cards_total': Variable<double>(record.manualCardsTotal),
      'manual_transfers_total': Variable<double>(record.manualTransfersTotal),
      'manual_advances_total': Variable<double>(record.manualAdvancesTotal),
      'manual_credit_notes_total': Variable<double>(
        record.manualCreditNotesTotal,
      ),
      'manual_withholds_total': Variable<double>(record.manualWithholdsTotal),
      'diff_checks_on_day': Variable<double>(record.diffChecksOnDay),
      'diff_checks_postdated': Variable<double>(record.diffChecksPostdated),
      'diff_cards_total': Variable<double>(record.diffCardsTotal),
      'diff_transfers_total': Variable<double>(record.diffTransfersTotal),
      'diff_advances_total': Variable<double>(record.diffAdvancesTotal),
      'diff_credit_notes_total': Variable<double>(record.diffCreditNotesTotal),
      'diff_withholds_total': Variable<double>(record.diffWithholdsTotal),
      'summary_system_total': Variable<double>(record.summarySystemTotal),
      'summary_manual_total': Variable<double>(record.summaryManualTotal),
      'summary_diff_total': Variable<double>(record.summaryDiffTotal),
      'fact_deposits_cash': Variable<double>(record.factDepositsCash),
      'fact_deposits_checks': Variable<double>(record.factDepositsChecks),
      'cartera_deposits_cash': Variable<double>(record.carteraDepositsCash),
      'cartera_deposits_checks': Variable<double>(record.carteraDepositsChecks),
      'anticipo_deposits_cash': Variable<double>(record.anticipoDepositsCash),
      'anticipo_deposits_checks': Variable<double>(
        record.anticipoDepositsChecks,
      ),
      'fact_advances_used': Variable<double>(record.factAdvancesUsed),
      'cartera_advances_used': Variable<double>(record.carteraAdvancesUsed),
      'summary_advances_used_total': Variable<double>(
        record.summaryAdvancesUsedTotal,
      ),
      'fact_total_with_nc_withholds': Variable<double>(
        record.factTotalWithNcWithholds,
      ),
      'fact_cash': Variable<double>(record.factCash),
      'fact_cards': Variable<double>(record.factCards),
      'fact_transfers': Variable<double>(record.factTransfers),
      'fact_checks_day': Variable<double>(record.factChecksDay),
      'fact_checks_post': Variable<double>(record.factChecksPost),
      'fact_total': Variable<double>(record.factTotal),
      'cartera_cash': Variable<double>(record.carteraCash),
      'cartera_cards': Variable<double>(record.carteraCards),
      'cartera_transfers': Variable<double>(record.carteraTransfers),
      'cartera_checks_day': Variable<double>(record.carteraChecksDay),
      'cartera_checks_post': Variable<double>(record.carteraChecksPost),
      'cartera_total': Variable<double>(record.carteraTotal),
      'anticipo_cash': Variable<double>(record.anticipoCash),
      'anticipo_cards': Variable<double>(record.anticipoCards),
      'anticipo_transfers': Variable<double>(record.anticipoTransfers),
      'anticipo_checks_day': Variable<double>(record.anticipoChecksDay),
      'anticipo_checks_post': Variable<double>(record.anticipoChecksPost),
      'anticipo_total': Variable<double>(record.anticipoTotal),
      'total_cash': Variable<double>(record.totalCash),
      'total_cards': Variable<double>(record.totalCards),
      'total_transfers': Variable<double>(record.totalTransfers),
      'total_checks_day': Variable<double>(record.totalChecksDay),
      'total_checks_post': Variable<double>(record.totalChecksPost),
      'total_general': Variable<double>(record.totalGeneral),
      'supervisor_id': driftVar<int>(record.supervisorId),
      'supervisor_id_name': driftVar<String>(record.supervisorName),
      'supervisor_validation_date': driftVar<DateTime>(
        record.supervisorValidationDate,
      ),
      'supervisor_notes': driftVar<String>(record.supervisorNotes),
      'opening_notes': driftVar<String>(record.openingNotes),
      'closing_notes': driftVar<String>(record.closingNotes),
      'is_synced': Variable<bool>(record.isSynced),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
      'sync_retry_count': Variable<int>(record.syncRetryCount),
      'last_sync_attempt': driftVar<DateTime>(record.lastSyncAttempt),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'state',
    'sessionUuid',
    'configId',
    'companyId',
    'userId',
    'currencyId',
    'currencySymbol',
    'cashJournalId',
    'startAt',
    'stopAt',
    'cashRegisterBalanceStart',
    'cashRegisterBalanceEndReal',
    'cashRegisterBalanceEnd',
    'cashRegisterDifference',
    'orderCount',
    'invoiceCount',
    'paymentCount',
    'advanceCount',
    'chequeRecibidoCount',
    'cashOutCount',
    'depositCount',
    'withholdCount',
    'totalPaymentsAmount',
    'totalCashOutAmount',
    'totalDepositAmount',
    'totalWithholdAmount',
    'totalCashAdvanceAmount',
    'cashOutSecurityTotal',
    'cashOutInvoiceTotal',
    'cashOutRefundTotal',
    'cashOutWithholdTotal',
    'cashOutOtherTotal',
    'checksOnDayTotal',
    'checksPostdatedTotal',
    'advanceChecksOnDayTotal',
    'advanceChecksPostdatedTotal',
    'totalChecksOnDay',
    'totalChecksPostdated',
    'systemDepositsCashTotal',
    'manualDepositsCashTotal',
    'diffDepositsCashTotal',
    'systemDepositsChecksTotal',
    'manualDepositsChecksTotal',
    'diffDepositsChecksTotal',
    'totalCashInvoicesAmount',
    'totalCashCollectedAmount',
    'totalCashPendingAmount',
    'totalCreditOrdersAmount',
    'totalCreditInvoicesAmount',
    'creditSalesDifference',
    'systemChecksOnDay',
    'systemChecksPostdated',
    'systemCardsTotal',
    'systemTransfersTotal',
    'systemAdvancesTotal',
    'systemCreditNotesTotal',
    'manualChecksOnDay',
    'manualChecksPostdated',
    'manualCardsTotal',
    'manualTransfersTotal',
    'manualAdvancesTotal',
    'manualCreditNotesTotal',
    'manualWithholdsTotal',
    'diffChecksOnDay',
    'diffChecksPostdated',
    'diffCardsTotal',
    'diffTransfersTotal',
    'diffAdvancesTotal',
    'diffCreditNotesTotal',
    'diffWithholdsTotal',
    'summarySystemTotal',
    'summaryManualTotal',
    'summaryDiffTotal',
    'factDepositsCash',
    'factDepositsChecks',
    'carteraDepositsCash',
    'carteraDepositsChecks',
    'anticipoDepositsCash',
    'anticipoDepositsChecks',
    'factAdvancesUsed',
    'carteraAdvancesUsed',
    'summaryAdvancesUsedTotal',
    'factTotalWithNcWithholds',
    'factCash',
    'factCards',
    'factTransfers',
    'factChecksDay',
    'factChecksPost',
    'factTotal',
    'carteraCash',
    'carteraCards',
    'carteraTransfers',
    'carteraChecksDay',
    'carteraChecksPost',
    'carteraTotal',
    'anticipoCash',
    'anticipoCards',
    'anticipoTransfers',
    'anticipoChecksDay',
    'anticipoChecksPost',
    'anticipoTotal',
    'totalCash',
    'totalCards',
    'totalTransfers',
    'totalChecksDay',
    'totalChecksPost',
    'totalGeneral',
    'supervisorId',
    'supervisorValidationDate',
    'supervisorNotes',
    'openingNotes',
    'closingNotes',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'state': 'State',
    'sessionUuid': 'Session Uuid',
    'configId': 'Config Id',
    'configName': 'Config Name',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'userId': 'User Id',
    'userName': 'User Name',
    'currencyId': 'Currency Id',
    'currencySymbol': 'Currency Symbol',
    'cashJournalId': 'Cash Journal Id',
    'cashJournalName': 'Cash Journal Name',
    'startAt': 'Start At',
    'stopAt': 'Stop At',
    'cashRegisterBalanceStart': 'Cash Register Balance Start',
    'cashRegisterBalanceEndReal': 'Cash Register Balance End Real',
    'cashRegisterBalanceEnd': 'Cash Register Balance End',
    'cashRegisterDifference': 'Cash Register Difference',
    'orderCount': 'Order Count',
    'invoiceCount': 'Invoice Count',
    'paymentCount': 'Payment Count',
    'advanceCount': 'Advance Count',
    'chequeRecibidoCount': 'Cheque Recibido Count',
    'cashOutCount': 'Cash Out Count',
    'depositCount': 'Deposit Count',
    'withholdCount': 'Withhold Count',
    'totalPaymentsAmount': 'Total Payments Amount',
    'totalCashOutAmount': 'Total Cash Out Amount',
    'totalDepositAmount': 'Total Deposit Amount',
    'totalWithholdAmount': 'Total Withhold Amount',
    'totalCashAdvanceAmount': 'Total Cash Advance Amount',
    'cashOutSecurityTotal': 'Cash Out Security Total',
    'cashOutInvoiceTotal': 'Cash Out Invoice Total',
    'cashOutRefundTotal': 'Cash Out Refund Total',
    'cashOutWithholdTotal': 'Cash Out Withhold Total',
    'cashOutOtherTotal': 'Cash Out Other Total',
    'checksOnDayTotal': 'Checks On Day Total',
    'checksPostdatedTotal': 'Checks Postdated Total',
    'advanceChecksOnDayTotal': 'Advance Checks On Day Total',
    'advanceChecksPostdatedTotal': 'Advance Checks Postdated Total',
    'totalChecksOnDay': 'Total Checks On Day',
    'totalChecksPostdated': 'Total Checks Postdated',
    'systemDepositsCashTotal': 'System Deposits Cash Total',
    'manualDepositsCashTotal': 'Manual Deposits Cash Total',
    'diffDepositsCashTotal': 'Diff Deposits Cash Total',
    'systemDepositsChecksTotal': 'System Deposits Checks Total',
    'manualDepositsChecksTotal': 'Manual Deposits Checks Total',
    'diffDepositsChecksTotal': 'Diff Deposits Checks Total',
    'totalCashInvoicesAmount': 'Total Cash Invoices Amount',
    'totalCashCollectedAmount': 'Total Cash Collected Amount',
    'totalCashPendingAmount': 'Total Cash Pending Amount',
    'totalCreditOrdersAmount': 'Total Credit Orders Amount',
    'totalCreditInvoicesAmount': 'Total Credit Invoices Amount',
    'creditSalesDifference': 'Credit Sales Difference',
    'systemChecksOnDay': 'System Checks On Day',
    'systemChecksPostdated': 'System Checks Postdated',
    'systemCardsTotal': 'System Cards Total',
    'systemTransfersTotal': 'System Transfers Total',
    'systemAdvancesTotal': 'System Advances Total',
    'systemCreditNotesTotal': 'System Credit Notes Total',
    'manualChecksOnDay': 'Manual Checks On Day',
    'manualChecksPostdated': 'Manual Checks Postdated',
    'manualCardsTotal': 'Manual Cards Total',
    'manualTransfersTotal': 'Manual Transfers Total',
    'manualAdvancesTotal': 'Manual Advances Total',
    'manualCreditNotesTotal': 'Manual Credit Notes Total',
    'manualWithholdsTotal': 'Manual Withholds Total',
    'diffChecksOnDay': 'Diff Checks On Day',
    'diffChecksPostdated': 'Diff Checks Postdated',
    'diffCardsTotal': 'Diff Cards Total',
    'diffTransfersTotal': 'Diff Transfers Total',
    'diffAdvancesTotal': 'Diff Advances Total',
    'diffCreditNotesTotal': 'Diff Credit Notes Total',
    'diffWithholdsTotal': 'Diff Withholds Total',
    'summarySystemTotal': 'Summary System Total',
    'summaryManualTotal': 'Summary Manual Total',
    'summaryDiffTotal': 'Summary Diff Total',
    'factDepositsCash': 'Fact Deposits Cash',
    'factDepositsChecks': 'Fact Deposits Checks',
    'carteraDepositsCash': 'Cartera Deposits Cash',
    'carteraDepositsChecks': 'Cartera Deposits Checks',
    'anticipoDepositsCash': 'Anticipo Deposits Cash',
    'anticipoDepositsChecks': 'Anticipo Deposits Checks',
    'factAdvancesUsed': 'Fact Advances Used',
    'carteraAdvancesUsed': 'Cartera Advances Used',
    'summaryAdvancesUsedTotal': 'Summary Advances Used Total',
    'factTotalWithNcWithholds': 'Fact Total With Nc Withholds',
    'factCash': 'Fact Cash',
    'factCards': 'Fact Cards',
    'factTransfers': 'Fact Transfers',
    'factChecksDay': 'Fact Checks Day',
    'factChecksPost': 'Fact Checks Post',
    'factTotal': 'Fact Total',
    'carteraCash': 'Cartera Cash',
    'carteraCards': 'Cartera Cards',
    'carteraTransfers': 'Cartera Transfers',
    'carteraChecksDay': 'Cartera Checks Day',
    'carteraChecksPost': 'Cartera Checks Post',
    'carteraTotal': 'Cartera Total',
    'anticipoCash': 'Anticipo Cash',
    'anticipoCards': 'Anticipo Cards',
    'anticipoTransfers': 'Anticipo Transfers',
    'anticipoChecksDay': 'Anticipo Checks Day',
    'anticipoChecksPost': 'Anticipo Checks Post',
    'anticipoTotal': 'Anticipo Total',
    'totalCash': 'Total Cash',
    'totalCards': 'Total Cards',
    'totalTransfers': 'Total Transfers',
    'totalChecksDay': 'Total Checks Day',
    'totalChecksPost': 'Total Checks Post',
    'totalGeneral': 'Total General',
    'supervisorId': 'Supervisor Id',
    'supervisorName': 'Supervisor Name',
    'supervisorValidationDate': 'Supervisor Validation Date',
    'supervisorNotes': 'Supervisor Notes',
    'openingNotes': 'Opening Notes',
    'closingNotes': 'Closing Notes',
    'isSynced': 'Is Synced',
    'lastSyncDate': 'Last Sync Date',
    'syncRetryCount': 'Sync Retry Count',
    'lastSyncAttempt': 'Last Sync Attempt',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(CollectionSession record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(CollectionSession record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(CollectionSession record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(CollectionSession record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'state':
        return record.state;
      case 'sessionUuid':
        return record.sessionUuid;
      case 'configId':
        return record.configId;
      case 'configName':
        return record.configName;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'userId':
        return record.userId;
      case 'userName':
        return record.userName;
      case 'currencyId':
        return record.currencyId;
      case 'currencySymbol':
        return record.currencySymbol;
      case 'cashJournalId':
        return record.cashJournalId;
      case 'cashJournalName':
        return record.cashJournalName;
      case 'startAt':
        return record.startAt;
      case 'stopAt':
        return record.stopAt;
      case 'cashRegisterBalanceStart':
        return record.cashRegisterBalanceStart;
      case 'cashRegisterBalanceEndReal':
        return record.cashRegisterBalanceEndReal;
      case 'cashRegisterBalanceEnd':
        return record.cashRegisterBalanceEnd;
      case 'cashRegisterDifference':
        return record.cashRegisterDifference;
      case 'orderCount':
        return record.orderCount;
      case 'invoiceCount':
        return record.invoiceCount;
      case 'paymentCount':
        return record.paymentCount;
      case 'advanceCount':
        return record.advanceCount;
      case 'chequeRecibidoCount':
        return record.chequeRecibidoCount;
      case 'cashOutCount':
        return record.cashOutCount;
      case 'depositCount':
        return record.depositCount;
      case 'withholdCount':
        return record.withholdCount;
      case 'totalPaymentsAmount':
        return record.totalPaymentsAmount;
      case 'totalCashOutAmount':
        return record.totalCashOutAmount;
      case 'totalDepositAmount':
        return record.totalDepositAmount;
      case 'totalWithholdAmount':
        return record.totalWithholdAmount;
      case 'totalCashAdvanceAmount':
        return record.totalCashAdvanceAmount;
      case 'cashOutSecurityTotal':
        return record.cashOutSecurityTotal;
      case 'cashOutInvoiceTotal':
        return record.cashOutInvoiceTotal;
      case 'cashOutRefundTotal':
        return record.cashOutRefundTotal;
      case 'cashOutWithholdTotal':
        return record.cashOutWithholdTotal;
      case 'cashOutOtherTotal':
        return record.cashOutOtherTotal;
      case 'checksOnDayTotal':
        return record.checksOnDayTotal;
      case 'checksPostdatedTotal':
        return record.checksPostdatedTotal;
      case 'advanceChecksOnDayTotal':
        return record.advanceChecksOnDayTotal;
      case 'advanceChecksPostdatedTotal':
        return record.advanceChecksPostdatedTotal;
      case 'totalChecksOnDay':
        return record.totalChecksOnDay;
      case 'totalChecksPostdated':
        return record.totalChecksPostdated;
      case 'systemDepositsCashTotal':
        return record.systemDepositsCashTotal;
      case 'manualDepositsCashTotal':
        return record.manualDepositsCashTotal;
      case 'diffDepositsCashTotal':
        return record.diffDepositsCashTotal;
      case 'systemDepositsChecksTotal':
        return record.systemDepositsChecksTotal;
      case 'manualDepositsChecksTotal':
        return record.manualDepositsChecksTotal;
      case 'diffDepositsChecksTotal':
        return record.diffDepositsChecksTotal;
      case 'totalCashInvoicesAmount':
        return record.totalCashInvoicesAmount;
      case 'totalCashCollectedAmount':
        return record.totalCashCollectedAmount;
      case 'totalCashPendingAmount':
        return record.totalCashPendingAmount;
      case 'totalCreditOrdersAmount':
        return record.totalCreditOrdersAmount;
      case 'totalCreditInvoicesAmount':
        return record.totalCreditInvoicesAmount;
      case 'creditSalesDifference':
        return record.creditSalesDifference;
      case 'systemChecksOnDay':
        return record.systemChecksOnDay;
      case 'systemChecksPostdated':
        return record.systemChecksPostdated;
      case 'systemCardsTotal':
        return record.systemCardsTotal;
      case 'systemTransfersTotal':
        return record.systemTransfersTotal;
      case 'systemAdvancesTotal':
        return record.systemAdvancesTotal;
      case 'systemCreditNotesTotal':
        return record.systemCreditNotesTotal;
      case 'manualChecksOnDay':
        return record.manualChecksOnDay;
      case 'manualChecksPostdated':
        return record.manualChecksPostdated;
      case 'manualCardsTotal':
        return record.manualCardsTotal;
      case 'manualTransfersTotal':
        return record.manualTransfersTotal;
      case 'manualAdvancesTotal':
        return record.manualAdvancesTotal;
      case 'manualCreditNotesTotal':
        return record.manualCreditNotesTotal;
      case 'manualWithholdsTotal':
        return record.manualWithholdsTotal;
      case 'diffChecksOnDay':
        return record.diffChecksOnDay;
      case 'diffChecksPostdated':
        return record.diffChecksPostdated;
      case 'diffCardsTotal':
        return record.diffCardsTotal;
      case 'diffTransfersTotal':
        return record.diffTransfersTotal;
      case 'diffAdvancesTotal':
        return record.diffAdvancesTotal;
      case 'diffCreditNotesTotal':
        return record.diffCreditNotesTotal;
      case 'diffWithholdsTotal':
        return record.diffWithholdsTotal;
      case 'summarySystemTotal':
        return record.summarySystemTotal;
      case 'summaryManualTotal':
        return record.summaryManualTotal;
      case 'summaryDiffTotal':
        return record.summaryDiffTotal;
      case 'factDepositsCash':
        return record.factDepositsCash;
      case 'factDepositsChecks':
        return record.factDepositsChecks;
      case 'carteraDepositsCash':
        return record.carteraDepositsCash;
      case 'carteraDepositsChecks':
        return record.carteraDepositsChecks;
      case 'anticipoDepositsCash':
        return record.anticipoDepositsCash;
      case 'anticipoDepositsChecks':
        return record.anticipoDepositsChecks;
      case 'factAdvancesUsed':
        return record.factAdvancesUsed;
      case 'carteraAdvancesUsed':
        return record.carteraAdvancesUsed;
      case 'summaryAdvancesUsedTotal':
        return record.summaryAdvancesUsedTotal;
      case 'factTotalWithNcWithholds':
        return record.factTotalWithNcWithholds;
      case 'factCash':
        return record.factCash;
      case 'factCards':
        return record.factCards;
      case 'factTransfers':
        return record.factTransfers;
      case 'factChecksDay':
        return record.factChecksDay;
      case 'factChecksPost':
        return record.factChecksPost;
      case 'factTotal':
        return record.factTotal;
      case 'carteraCash':
        return record.carteraCash;
      case 'carteraCards':
        return record.carteraCards;
      case 'carteraTransfers':
        return record.carteraTransfers;
      case 'carteraChecksDay':
        return record.carteraChecksDay;
      case 'carteraChecksPost':
        return record.carteraChecksPost;
      case 'carteraTotal':
        return record.carteraTotal;
      case 'anticipoCash':
        return record.anticipoCash;
      case 'anticipoCards':
        return record.anticipoCards;
      case 'anticipoTransfers':
        return record.anticipoTransfers;
      case 'anticipoChecksDay':
        return record.anticipoChecksDay;
      case 'anticipoChecksPost':
        return record.anticipoChecksPost;
      case 'anticipoTotal':
        return record.anticipoTotal;
      case 'totalCash':
        return record.totalCash;
      case 'totalCards':
        return record.totalCards;
      case 'totalTransfers':
        return record.totalTransfers;
      case 'totalChecksDay':
        return record.totalChecksDay;
      case 'totalChecksPost':
        return record.totalChecksPost;
      case 'totalGeneral':
        return record.totalGeneral;
      case 'supervisorId':
        return record.supervisorId;
      case 'supervisorName':
        return record.supervisorName;
      case 'supervisorValidationDate':
        return record.supervisorValidationDate;
      case 'supervisorNotes':
        return record.supervisorNotes;
      case 'openingNotes':
        return record.openingNotes;
      case 'closingNotes':
        return record.closingNotes;
      case 'isSynced':
        return record.isSynced;
      case 'lastSyncDate':
        return record.lastSyncDate;
      case 'syncRetryCount':
        return record.syncRetryCount;
      case 'lastSyncAttempt':
        return record.lastSyncAttempt;
      default:
        return null;
    }
  }

  @override
  CollectionSession applyWebSocketChangesToRecord(
    CollectionSession record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      isSynced: record.isSynced,
      lastSyncDate: record.lastSyncDate,
      syncRetryCount: record.syncRetryCount,
      lastSyncAttempt: record.lastSyncAttempt,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'name':
        return (obj as dynamic).name;
      case 'state':
        return (obj as dynamic).state;
      case 'sessionUuid':
        return (obj as dynamic).sessionUuid;
      case 'configId':
        return (obj as dynamic).configId;
      case 'configName':
        return (obj as dynamic).configName;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'userId':
        return (obj as dynamic).userId;
      case 'userName':
        return (obj as dynamic).userName;
      case 'currencyId':
        return (obj as dynamic).currencyId;
      case 'currencySymbol':
        return (obj as dynamic).currencySymbol;
      case 'cashJournalId':
        return (obj as dynamic).cashJournalId;
      case 'cashJournalName':
        return (obj as dynamic).cashJournalName;
      case 'startAt':
        return (obj as dynamic).startAt;
      case 'stopAt':
        return (obj as dynamic).stopAt;
      case 'cashRegisterBalanceStart':
        return (obj as dynamic).cashRegisterBalanceStart;
      case 'cashRegisterBalanceEndReal':
        return (obj as dynamic).cashRegisterBalanceEndReal;
      case 'cashRegisterBalanceEnd':
        return (obj as dynamic).cashRegisterBalanceEnd;
      case 'cashRegisterDifference':
        return (obj as dynamic).cashRegisterDifference;
      case 'orderCount':
        return (obj as dynamic).orderCount;
      case 'invoiceCount':
        return (obj as dynamic).invoiceCount;
      case 'paymentCount':
        return (obj as dynamic).paymentCount;
      case 'advanceCount':
        return (obj as dynamic).advanceCount;
      case 'chequeRecibidoCount':
        return (obj as dynamic).chequeRecibidoCount;
      case 'cashOutCount':
        return (obj as dynamic).cashOutCount;
      case 'depositCount':
        return (obj as dynamic).depositCount;
      case 'withholdCount':
        return (obj as dynamic).withholdCount;
      case 'totalPaymentsAmount':
        return (obj as dynamic).totalPaymentsAmount;
      case 'totalCashOutAmount':
        return (obj as dynamic).totalCashOutAmount;
      case 'totalDepositAmount':
        return (obj as dynamic).totalDepositAmount;
      case 'totalWithholdAmount':
        return (obj as dynamic).totalWithholdAmount;
      case 'totalCashAdvanceAmount':
        return (obj as dynamic).totalCashAdvanceAmount;
      case 'cashOutSecurityTotal':
        return (obj as dynamic).cashOutSecurityTotal;
      case 'cashOutInvoiceTotal':
        return (obj as dynamic).cashOutInvoiceTotal;
      case 'cashOutRefundTotal':
        return (obj as dynamic).cashOutRefundTotal;
      case 'cashOutWithholdTotal':
        return (obj as dynamic).cashOutWithholdTotal;
      case 'cashOutOtherTotal':
        return (obj as dynamic).cashOutOtherTotal;
      case 'checksOnDayTotal':
        return (obj as dynamic).checksOnDayTotal;
      case 'checksPostdatedTotal':
        return (obj as dynamic).checksPostdatedTotal;
      case 'advanceChecksOnDayTotal':
        return (obj as dynamic).advanceChecksOnDayTotal;
      case 'advanceChecksPostdatedTotal':
        return (obj as dynamic).advanceChecksPostdatedTotal;
      case 'totalChecksOnDay':
        return (obj as dynamic).totalChecksOnDay;
      case 'totalChecksPostdated':
        return (obj as dynamic).totalChecksPostdated;
      case 'systemDepositsCashTotal':
        return (obj as dynamic).systemDepositsCashTotal;
      case 'manualDepositsCashTotal':
        return (obj as dynamic).manualDepositsCashTotal;
      case 'diffDepositsCashTotal':
        return (obj as dynamic).diffDepositsCashTotal;
      case 'systemDepositsChecksTotal':
        return (obj as dynamic).systemDepositsChecksTotal;
      case 'manualDepositsChecksTotal':
        return (obj as dynamic).manualDepositsChecksTotal;
      case 'diffDepositsChecksTotal':
        return (obj as dynamic).diffDepositsChecksTotal;
      case 'totalCashInvoicesAmount':
        return (obj as dynamic).totalCashInvoicesAmount;
      case 'totalCashCollectedAmount':
        return (obj as dynamic).totalCashCollectedAmount;
      case 'totalCashPendingAmount':
        return (obj as dynamic).totalCashPendingAmount;
      case 'totalCreditOrdersAmount':
        return (obj as dynamic).totalCreditOrdersAmount;
      case 'totalCreditInvoicesAmount':
        return (obj as dynamic).totalCreditInvoicesAmount;
      case 'creditSalesDifference':
        return (obj as dynamic).creditSalesDifference;
      case 'systemChecksOnDay':
        return (obj as dynamic).systemChecksOnDay;
      case 'systemChecksPostdated':
        return (obj as dynamic).systemChecksPostdated;
      case 'systemCardsTotal':
        return (obj as dynamic).systemCardsTotal;
      case 'systemTransfersTotal':
        return (obj as dynamic).systemTransfersTotal;
      case 'systemAdvancesTotal':
        return (obj as dynamic).systemAdvancesTotal;
      case 'systemCreditNotesTotal':
        return (obj as dynamic).systemCreditNotesTotal;
      case 'manualChecksOnDay':
        return (obj as dynamic).manualChecksOnDay;
      case 'manualChecksPostdated':
        return (obj as dynamic).manualChecksPostdated;
      case 'manualCardsTotal':
        return (obj as dynamic).manualCardsTotal;
      case 'manualTransfersTotal':
        return (obj as dynamic).manualTransfersTotal;
      case 'manualAdvancesTotal':
        return (obj as dynamic).manualAdvancesTotal;
      case 'manualCreditNotesTotal':
        return (obj as dynamic).manualCreditNotesTotal;
      case 'manualWithholdsTotal':
        return (obj as dynamic).manualWithholdsTotal;
      case 'diffChecksOnDay':
        return (obj as dynamic).diffChecksOnDay;
      case 'diffChecksPostdated':
        return (obj as dynamic).diffChecksPostdated;
      case 'diffCardsTotal':
        return (obj as dynamic).diffCardsTotal;
      case 'diffTransfersTotal':
        return (obj as dynamic).diffTransfersTotal;
      case 'diffAdvancesTotal':
        return (obj as dynamic).diffAdvancesTotal;
      case 'diffCreditNotesTotal':
        return (obj as dynamic).diffCreditNotesTotal;
      case 'diffWithholdsTotal':
        return (obj as dynamic).diffWithholdsTotal;
      case 'summarySystemTotal':
        return (obj as dynamic).summarySystemTotal;
      case 'summaryManualTotal':
        return (obj as dynamic).summaryManualTotal;
      case 'summaryDiffTotal':
        return (obj as dynamic).summaryDiffTotal;
      case 'factDepositsCash':
        return (obj as dynamic).factDepositsCash;
      case 'factDepositsChecks':
        return (obj as dynamic).factDepositsChecks;
      case 'carteraDepositsCash':
        return (obj as dynamic).carteraDepositsCash;
      case 'carteraDepositsChecks':
        return (obj as dynamic).carteraDepositsChecks;
      case 'anticipoDepositsCash':
        return (obj as dynamic).anticipoDepositsCash;
      case 'anticipoDepositsChecks':
        return (obj as dynamic).anticipoDepositsChecks;
      case 'factAdvancesUsed':
        return (obj as dynamic).factAdvancesUsed;
      case 'carteraAdvancesUsed':
        return (obj as dynamic).carteraAdvancesUsed;
      case 'summaryAdvancesUsedTotal':
        return (obj as dynamic).summaryAdvancesUsedTotal;
      case 'factTotalWithNcWithholds':
        return (obj as dynamic).factTotalWithNcWithholds;
      case 'factCash':
        return (obj as dynamic).factCash;
      case 'factCards':
        return (obj as dynamic).factCards;
      case 'factTransfers':
        return (obj as dynamic).factTransfers;
      case 'factChecksDay':
        return (obj as dynamic).factChecksDay;
      case 'factChecksPost':
        return (obj as dynamic).factChecksPost;
      case 'factTotal':
        return (obj as dynamic).factTotal;
      case 'carteraCash':
        return (obj as dynamic).carteraCash;
      case 'carteraCards':
        return (obj as dynamic).carteraCards;
      case 'carteraTransfers':
        return (obj as dynamic).carteraTransfers;
      case 'carteraChecksDay':
        return (obj as dynamic).carteraChecksDay;
      case 'carteraChecksPost':
        return (obj as dynamic).carteraChecksPost;
      case 'carteraTotal':
        return (obj as dynamic).carteraTotal;
      case 'anticipoCash':
        return (obj as dynamic).anticipoCash;
      case 'anticipoCards':
        return (obj as dynamic).anticipoCards;
      case 'anticipoTransfers':
        return (obj as dynamic).anticipoTransfers;
      case 'anticipoChecksDay':
        return (obj as dynamic).anticipoChecksDay;
      case 'anticipoChecksPost':
        return (obj as dynamic).anticipoChecksPost;
      case 'anticipoTotal':
        return (obj as dynamic).anticipoTotal;
      case 'totalCash':
        return (obj as dynamic).totalCash;
      case 'totalCards':
        return (obj as dynamic).totalCards;
      case 'totalTransfers':
        return (obj as dynamic).totalTransfers;
      case 'totalChecksDay':
        return (obj as dynamic).totalChecksDay;
      case 'totalChecksPost':
        return (obj as dynamic).totalChecksPost;
      case 'totalGeneral':
        return (obj as dynamic).totalGeneral;
      case 'supervisorId':
        return (obj as dynamic).supervisorId;
      case 'supervisorName':
        return (obj as dynamic).supervisorName;
      case 'supervisorValidationDate':
        return (obj as dynamic).supervisorValidationDate;
      case 'supervisorNotes':
        return (obj as dynamic).supervisorNotes;
      case 'openingNotes':
        return (obj as dynamic).openingNotes;
      case 'closingNotes':
        return (obj as dynamic).closingNotes;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'lastSyncDate':
        return (obj as dynamic).lastSyncDate;
      case 'syncRetryCount':
        return (obj as dynamic).syncRetryCount;
      case 'lastSyncAttempt':
        return (obj as dynamic).lastSyncAttempt;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'localCreatedAt':
        return (obj as dynamic).localCreatedAt;
      default:
        return super.accessProperty(obj, name);
    }
  }

  @override
  List<String> get computedFieldNames => const [];

  @override
  List<String> get storedFieldNames => const [
    'id',
    'name',
    'state',
    'sessionUuid',
    'configId',
    'configName',
    'companyId',
    'companyName',
    'userId',
    'userName',
    'currencyId',
    'currencySymbol',
    'cashJournalId',
    'cashJournalName',
    'startAt',
    'stopAt',
    'cashRegisterBalanceStart',
    'cashRegisterBalanceEndReal',
    'cashRegisterBalanceEnd',
    'cashRegisterDifference',
    'orderCount',
    'invoiceCount',
    'paymentCount',
    'advanceCount',
    'chequeRecibidoCount',
    'cashOutCount',
    'depositCount',
    'withholdCount',
    'totalPaymentsAmount',
    'totalCashOutAmount',
    'totalDepositAmount',
    'totalWithholdAmount',
    'totalCashAdvanceAmount',
    'cashOutSecurityTotal',
    'cashOutInvoiceTotal',
    'cashOutRefundTotal',
    'cashOutWithholdTotal',
    'cashOutOtherTotal',
    'checksOnDayTotal',
    'checksPostdatedTotal',
    'advanceChecksOnDayTotal',
    'advanceChecksPostdatedTotal',
    'totalChecksOnDay',
    'totalChecksPostdated',
    'systemDepositsCashTotal',
    'manualDepositsCashTotal',
    'diffDepositsCashTotal',
    'systemDepositsChecksTotal',
    'manualDepositsChecksTotal',
    'diffDepositsChecksTotal',
    'totalCashInvoicesAmount',
    'totalCashCollectedAmount',
    'totalCashPendingAmount',
    'totalCreditOrdersAmount',
    'totalCreditInvoicesAmount',
    'creditSalesDifference',
    'systemChecksOnDay',
    'systemChecksPostdated',
    'systemCardsTotal',
    'systemTransfersTotal',
    'systemAdvancesTotal',
    'systemCreditNotesTotal',
    'manualChecksOnDay',
    'manualChecksPostdated',
    'manualCardsTotal',
    'manualTransfersTotal',
    'manualAdvancesTotal',
    'manualCreditNotesTotal',
    'manualWithholdsTotal',
    'diffChecksOnDay',
    'diffChecksPostdated',
    'diffCardsTotal',
    'diffTransfersTotal',
    'diffAdvancesTotal',
    'diffCreditNotesTotal',
    'diffWithholdsTotal',
    'summarySystemTotal',
    'summaryManualTotal',
    'summaryDiffTotal',
    'factDepositsCash',
    'factDepositsChecks',
    'carteraDepositsCash',
    'carteraDepositsChecks',
    'anticipoDepositsCash',
    'anticipoDepositsChecks',
    'factAdvancesUsed',
    'carteraAdvancesUsed',
    'summaryAdvancesUsedTotal',
    'factTotalWithNcWithholds',
    'factCash',
    'factCards',
    'factTransfers',
    'factChecksDay',
    'factChecksPost',
    'factTotal',
    'carteraCash',
    'carteraCards',
    'carteraTransfers',
    'carteraChecksDay',
    'carteraChecksPost',
    'carteraTotal',
    'anticipoCash',
    'anticipoCards',
    'anticipoTransfers',
    'anticipoChecksDay',
    'anticipoChecksPost',
    'anticipoTotal',
    'totalCash',
    'totalCards',
    'totalTransfers',
    'totalChecksDay',
    'totalChecksPost',
    'totalGeneral',
    'supervisorId',
    'supervisorName',
    'supervisorValidationDate',
    'supervisorNotes',
    'openingNotes',
    'closingNotes',
    'isSynced',
    'lastSyncDate',
    'syncRetryCount',
    'lastSyncAttempt',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'state',
    'sessionUuid',
    'configId',
    'companyId',
    'userId',
    'currencyId',
    'currencySymbol',
    'cashJournalId',
    'startAt',
    'stopAt',
    'cashRegisterBalanceStart',
    'cashRegisterBalanceEndReal',
    'cashRegisterBalanceEnd',
    'cashRegisterDifference',
    'orderCount',
    'invoiceCount',
    'paymentCount',
    'advanceCount',
    'chequeRecibidoCount',
    'cashOutCount',
    'depositCount',
    'withholdCount',
    'totalPaymentsAmount',
    'totalCashOutAmount',
    'totalDepositAmount',
    'totalWithholdAmount',
    'totalCashAdvanceAmount',
    'cashOutSecurityTotal',
    'cashOutInvoiceTotal',
    'cashOutRefundTotal',
    'cashOutWithholdTotal',
    'cashOutOtherTotal',
    'checksOnDayTotal',
    'checksPostdatedTotal',
    'advanceChecksOnDayTotal',
    'advanceChecksPostdatedTotal',
    'totalChecksOnDay',
    'totalChecksPostdated',
    'systemDepositsCashTotal',
    'manualDepositsCashTotal',
    'diffDepositsCashTotal',
    'systemDepositsChecksTotal',
    'manualDepositsChecksTotal',
    'diffDepositsChecksTotal',
    'totalCashInvoicesAmount',
    'totalCashCollectedAmount',
    'totalCashPendingAmount',
    'totalCreditOrdersAmount',
    'totalCreditInvoicesAmount',
    'creditSalesDifference',
    'systemChecksOnDay',
    'systemChecksPostdated',
    'systemCardsTotal',
    'systemTransfersTotal',
    'systemAdvancesTotal',
    'systemCreditNotesTotal',
    'manualChecksOnDay',
    'manualChecksPostdated',
    'manualCardsTotal',
    'manualTransfersTotal',
    'manualAdvancesTotal',
    'manualCreditNotesTotal',
    'manualWithholdsTotal',
    'diffChecksOnDay',
    'diffChecksPostdated',
    'diffCardsTotal',
    'diffTransfersTotal',
    'diffAdvancesTotal',
    'diffCreditNotesTotal',
    'diffWithholdsTotal',
    'summarySystemTotal',
    'summaryManualTotal',
    'summaryDiffTotal',
    'factDepositsCash',
    'factDepositsChecks',
    'carteraDepositsCash',
    'carteraDepositsChecks',
    'anticipoDepositsCash',
    'anticipoDepositsChecks',
    'factAdvancesUsed',
    'carteraAdvancesUsed',
    'summaryAdvancesUsedTotal',
    'factTotalWithNcWithholds',
    'factCash',
    'factCards',
    'factTransfers',
    'factChecksDay',
    'factChecksPost',
    'factTotal',
    'carteraCash',
    'carteraCards',
    'carteraTransfers',
    'carteraChecksDay',
    'carteraChecksPost',
    'carteraTotal',
    'anticipoCash',
    'anticipoCards',
    'anticipoTransfers',
    'anticipoChecksDay',
    'anticipoChecksPost',
    'anticipoTotal',
    'totalCash',
    'totalCards',
    'totalTransfers',
    'totalChecksDay',
    'totalChecksPost',
    'totalGeneral',
    'supervisorId',
    'supervisorValidationDate',
    'supervisorNotes',
    'openingNotes',
    'closingNotes',
  ];
}

/// Global instance of CollectionSessionManager.
final collectionSessionManager = CollectionSessionManager();
