import 'collection_session.model.dart';

/// Extensions para organizar los campos de CollectionSession en grupos lógicos
///
/// Esto mejora la legibilidad sin cambiar el modelo base ni la BD.

// ============================================================================
// CASH CONTROL - Control de efectivo
// ============================================================================

extension CollectionSessionCashControl on CollectionSession {
  /// Resumen de control de efectivo
  ({
    double balanceStart,
    double balanceEndReal,
    double balanceEndExpected,
    double difference,
    bool hasDifference,
  }) get cashControl => (
    balanceStart: cashRegisterBalanceStart,
    balanceEndReal: cashRegisterBalanceEndReal,
    balanceEndExpected: cashRegisterBalanceEnd,
    difference: cashRegisterDifference,
    hasDifference: hasCashDifference,
  );
}

// ============================================================================
// COUNTERS - Contadores de documentos
// ============================================================================

extension CollectionSessionCounters on CollectionSession {
  /// Total de documentos procesados
  int get totalDocuments =>
      orderCount + invoiceCount + paymentCount + advanceCount +
      chequeRecibidoCount + cashOutCount + depositCount + withholdCount;

  /// Resumen de contadores
  ({
    int orders,
    int invoices,
    int payments,
    int advances,
    int cheques,
    int cashOuts,
    int deposits,
    int withholds,
    int total,
  }) get counters => (
    orders: orderCount,
    invoices: invoiceCount,
    payments: paymentCount,
    advances: advanceCount,
    cheques: chequeRecibidoCount,
    cashOuts: cashOutCount,
    deposits: depositCount,
    withholds: withholdCount,
    total: totalDocuments,
  );
}

// ============================================================================
// MANUAL COUNT - Conteo manual (Sistema vs Manual vs Diferencia)
// ============================================================================

extension CollectionSessionManualCount on CollectionSession {
  /// Totales del sistema
  ({
    double checksOnDay,
    double checksPostdated,
    double cards,
    double transfers,
    double advances,
    double creditNotes,
    double total,
  }) get systemTotals => (
    checksOnDay: systemChecksOnDay,
    checksPostdated: systemChecksPostdated,
    cards: systemCardsTotal,
    transfers: systemTransfersTotal,
    advances: systemAdvancesTotal,
    creditNotes: systemCreditNotesTotal,
    total: summarySystemTotal,
  );

  /// Totales manuales
  ({
    double checksOnDay,
    double checksPostdated,
    double cards,
    double transfers,
    double advances,
    double creditNotes,
    double withholds,
    double total,
  }) get manualTotals => (
    checksOnDay: manualChecksOnDay,
    checksPostdated: manualChecksPostdated,
    cards: manualCardsTotal,
    transfers: manualTransfersTotal,
    advances: manualAdvancesTotal,
    creditNotes: manualCreditNotesTotal,
    withholds: manualWithholdsTotal,
    total: summaryManualTotal,
  );

  /// Diferencias (Sistema - Manual)
  ({
    double checksOnDay,
    double checksPostdated,
    double cards,
    double transfers,
    double advances,
    double creditNotes,
    double withholds,
    double total,
  }) get differences => (
    checksOnDay: diffChecksOnDay,
    checksPostdated: diffChecksPostdated,
    cards: diffCardsTotal,
    transfers: diffTransfersTotal,
    advances: diffAdvancesTotal,
    creditNotes: diffCreditNotesTotal,
    withholds: diffWithholdsTotal,
    total: summaryDiffTotal,
  );

  /// Hay diferencias significativas en el conteo manual
  bool get hasManualCountDifferences => summaryDiffTotal.abs() > 0.01;
}

// ============================================================================
// COBROS DETAIL - Detalle de cobros por tipo
// ============================================================================

extension CollectionSessionCobrosDetail on CollectionSession {
  /// Desglose de facturas del día
  ({
    double cash,
    double cards,
    double transfers,
    double checksDay,
    double checksPost,
    double total,
    double depositsCash,
    double depositsChecks,
  }) get facturas => (
    cash: factCash,
    cards: factCards,
    transfers: factTransfers,
    checksDay: factChecksDay,
    checksPost: factChecksPost,
    total: factTotal,
    depositsCash: factDepositsCash,
    depositsChecks: factDepositsChecks,
  );

  /// Desglose de cartera
  ({
    double cash,
    double cards,
    double transfers,
    double checksDay,
    double checksPost,
    double total,
    double depositsCash,
    double depositsChecks,
  }) get cartera => (
    cash: carteraCash,
    cards: carteraCards,
    transfers: carteraTransfers,
    checksDay: carteraChecksDay,
    checksPost: carteraChecksPost,
    total: carteraTotal,
    depositsCash: carteraDepositsCash,
    depositsChecks: carteraDepositsChecks,
  );

  /// Desglose de anticipos
  ({
    double cash,
    double cards,
    double transfers,
    double checksDay,
    double checksPost,
    double total,
    double depositsCash,
    double depositsChecks,
  }) get anticipos => (
    cash: anticipoCash,
    cards: anticipoCards,
    transfers: anticipoTransfers,
    checksDay: anticipoChecksDay,
    checksPost: anticipoChecksPost,
    total: anticipoTotal,
    depositsCash: anticipoDepositsCash,
    depositsChecks: anticipoDepositsChecks,
  );

  /// Totales generales por método de pago
  ({
    double cash,
    double cards,
    double transfers,
    double checksDay,
    double checksPost,
    double total,
  }) get paymentMethodTotals => (
    cash: totalCash,
    cards: totalCards,
    transfers: totalTransfers,
    checksDay: totalChecksDay,
    checksPost: totalChecksPost,
    total: totalGeneral,
  );
}

// ============================================================================
// DEPOSITS CONTROL - Control de depósitos
// ============================================================================

extension CollectionSessionDepositsControl on CollectionSession {
  /// Control de depósitos en efectivo
  ({
    double system,
    double manual,
    double difference,
  }) get depositsCash => (
    system: systemDepositsCashTotal,
    manual: manualDepositsCashTotal,
    difference: diffDepositsCashTotal,
  );

  /// Control de depósitos en cheques
  ({
    double system,
    double manual,
    double difference,
  }) get depositsChecks => (
    system: systemDepositsChecksTotal,
    manual: manualDepositsChecksTotal,
    difference: diffDepositsChecksTotal,
  );

  /// Hay diferencias en depósitos
  bool get hasDepositsDifferences =>
      diffDepositsCashTotal.abs() > 0.01 || diffDepositsChecksTotal.abs() > 0.01;
}

// ============================================================================
// VALIDATION - Información de validación
// ============================================================================

extension CollectionSessionValidation on CollectionSession {
  /// Información de validación del supervisor
  ({
    int? supervisorId,
    String? supervisorName,
    DateTime? validationDate,
    String? notes,
    bool isValidated,
  }) get supervisorValidation => (
    supervisorId: supervisorId,
    supervisorName: supervisorName,
    validationDate: supervisorValidationDate,
    notes: supervisorNotes,
    isValidated: supervisorValidationDate != null,
  );

  /// Notas de la sesión
  ({
    String? opening,
    String? closing,
    String? supervisor,
  }) get sessionNotes => (
    opening: openingNotes,
    closing: closingNotes,
    supervisor: supervisorNotes,
  );
}

// ============================================================================
// SYNC STATUS - Estado de sincronización
// ============================================================================

extension CollectionSessionSyncStatus on CollectionSession {
  /// Estado de sincronización
  ({
    bool isSynced,
    DateTime? lastSyncDate,
    int retryCount,
    DateTime? lastAttempt,
    bool needsSync,
  }) get syncStatus => (
    isSynced: isSynced,
    lastSyncDate: lastSyncDate,
    retryCount: syncRetryCount,
    lastAttempt: lastSyncAttempt,
    needsSync: !isSynced && syncRetryCount < 5,
  );
}
