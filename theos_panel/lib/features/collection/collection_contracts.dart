enum CollectionShiftState { opening, opened, closing, closed, conflict }

enum CollectionResultState { local, queued, ambiguous, synced, conflict }

enum CollectionSaleRoute { cashInvoice, existingInvoice }

enum CollectionPaymentLineKind { payment, advance, creditNote }

enum CollectionCapability {
  advances,
  withholdings,
  creditNotes,
  cashOuts,
  deposits,
}

class CollectionCapabilitySnapshot {
  final Set<CollectionCapability> available;
  const CollectionCapabilitySnapshot({this.available = const {}});
  bool supports(CollectionCapability capability) =>
      available.contains(capability);
}

class CollectionShiftSnapshot {
  final String id;
  final CollectionShiftState state;
  final int expectedVersion;

  /// Expected cash ending balance from collection.session, in minor units.
  /// Null means the native session did not provide it locally.
  final int? expectedBalanceMinor;
  final int? differenceMinor;
  const CollectionShiftSnapshot({
    required this.id,
    required this.state,
    required this.expectedVersion,
    this.expectedBalanceMinor,
    this.differenceMinor,
  });
}

class CollectionPendingSale {
  final String id;
  final String label;
  final int amountMinor;
  final int? partnerId;
  final CollectionSaleRoute route;
  final int? wizardId;
  final int? remoteId;
  final String? commandId;
  final int? collectionSessionId;
  final bool requiresDueConfirmation;
  final int? calculatedDueMinor;

  /// The point of emission is the authority for these values when true.
  /// They are optional for server-numbered journals and are never generated
  /// by the UI.
  final bool numberedByClient;
  final int? sequential;
  final String? emissionDate;
  final String? accessKey;
  final List<CollectionCachedReference> cachedAdvances;
  final List<CollectionCachedReference> cachedCreditNotes;
  final List<CollectionWithholdDraft> cachedWithholds;
  const CollectionPendingSale({
    required this.id,
    required this.label,
    required this.amountMinor,
    this.partnerId,
    this.route = CollectionSaleRoute.existingInvoice,
    this.wizardId,
    this.remoteId,
    this.commandId,
    this.collectionSessionId,
    this.requiresDueConfirmation = false,
    this.calculatedDueMinor,
    this.numberedByClient = false,
    this.sequential,
    this.emissionDate,
    this.accessKey,
    this.cachedAdvances = const [],
    this.cachedCreditNotes = const [],
    this.cachedWithholds = const [],
  });
}

/// Read-only references materialized from the existing Odoo caches. They are
/// identifiers for wizard lines, never a second financial snapshot/table.
class CollectionCachedReference {
  final int id;
  final String label;
  final int amountMinor;
  const CollectionCachedReference({
    required this.id,
    required this.label,
    required this.amountMinor,
  });
}

/// Existing sale.order.withhold.line snapshot. It is only carried to the
/// collection intent; persistence/replay remains the native withhold model.
class CollectionWithholdDraft {
  final String uuid;
  final int taxId;
  final int baseMinor;
  final int amountMinor;
  final String? taxsupportCode;
  final String? notes;
  const CollectionWithholdDraft({
    required this.uuid,
    required this.taxId,
    required this.baseMinor,
    required this.amountMinor,
    this.taxsupportCode,
    this.notes,
  });
}

class CollectionPaymentDraft {
  final int journalId;
  final int amountMinor;
  final CollectionPaymentLineKind kind;
  final int? advanceId;
  final int? creditNoteId;
  final int? paymentMethodLineId;
  const CollectionPaymentDraft({
    required this.journalId,
    required this.amountMinor,
    this.kind = CollectionPaymentLineKind.payment,
    this.advanceId,
    this.creditNoteId,
    this.paymentMethodLineId,
  });
}

class CollectionJournalOption {
  final int id;
  final String name;
  const CollectionJournalOption({required this.id, required this.name});
}

class CollectionCashOutTypeOption {
  final int id;
  final String name;
  const CollectionCashOutTypeOption({required this.id, required this.name});
}

final class CollectionFinancialContext {
  const CollectionFinancialContext({
    required this.shift,
    required this.journalId,
    required this.amountMinor,
    this.selectedSale,
    this.cashOutTypeId,
    this.partnerId,
  });
  final CollectionShiftSnapshot shift;
  final int? journalId;
  final int amountMinor;
  final CollectionPendingSale? selectedSale;
  final int? cashOutTypeId;
  final int? partnerId;
}

/// Optional extension implemented by the durable runtime composition. Legacy
/// fakes can keep implementing [CollectionActions] while the real cashier
/// surface gets denomination-aware close semantics.
abstract interface class CollectionShiftCountActions {
  Future<CollectionShiftCloseResult> closeWithCount(
    CollectionShiftSnapshot shift,
    CollectionCashCount count,
  );
}

final class CollectionCashCount {
  const CollectionCashCount({
    this.bills100 = 0,
    this.bills50 = 0,
    this.bills20 = 0,
    this.bills10 = 0,
    this.bills5 = 0,
    this.bills1 = 0,
    this.coins1 = 0,
    this.coins50 = 0,
    this.coins25 = 0,
    this.coins10 = 0,
    this.coins5 = 0,
    this.coins1Cent = 0,
    this.notes,
    this.expectedBalanceMinor = 0,
  });
  final int bills100;
  final int bills50;
  final int bills20;
  final int bills10;
  final int bills5;
  final int bills1;
  final int coins1;
  final int coins50;
  final int coins25;
  final int coins10;
  final int coins5;
  final int coins1Cent;
  final String? notes;
  final int expectedBalanceMinor;

  bool get isValid => [
    bills100,
    bills50,
    bills20,
    bills10,
    bills5,
    bills1,
    coins1,
    coins50,
    coins25,
    coins10,
    coins5,
    coins1Cent,
    expectedBalanceMinor,
  ].every((value) => value >= 0);

  int get cashTotalMinor =>
      bills100 * 10000 +
      bills50 * 5000 +
      bills20 * 2000 +
      bills10 * 1000 +
      bills5 * 500 +
      bills1 * 100 +
      coins1 * 100 +
      coins50 * 50 +
      coins25 * 25 +
      coins10 * 10 +
      coins5 * 5 +
      coins1Cent;

  int get differenceMinor => cashTotalMinor - expectedBalanceMinor;
}

final class CollectionShiftCloseResult {
  const CollectionShiftCloseResult({
    required this.shift,
    required this.result,
    this.message,
  });
  final CollectionShiftSnapshot shift;
  final CollectionResultState result;
  final String? message;
}

/// An online, scope-bound action supplied by composition. The callback owns
/// the typed runtime request (wizard/session IDs and capability checks); the UI
/// never invents payloads or reports success without its result.
final class CollectionFinancialAction {
  const CollectionFinancialAction({
    required this.capability,
    required this.label,
    required this.run,
    this.runWithContext,
  });
  final CollectionCapability capability;
  final String label;
  final Future<CollectionResultState> Function() run;
  final Future<CollectionResultState> Function(
    CollectionFinancialContext context,
  )?
  runWithContext;
}

int collectionTotalMinor(Iterable<CollectionPaymentDraft> lines) =>
    lines.fold(0, (sum, line) => sum + line.amountMinor);

abstract interface class CollectionActions {
  Future<CollectionShiftSnapshot> open(CollectionShiftSnapshot shift);
  Future<CollectionShiftSnapshot> close(CollectionShiftSnapshot shift);
  Future<CollectionResultState> collect(
    CollectionPendingSale sale,
    List<CollectionPaymentDraft> payments,
  );
}
