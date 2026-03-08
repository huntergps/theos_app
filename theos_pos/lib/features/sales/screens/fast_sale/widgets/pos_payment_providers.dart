import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers.dart';
import '../../../../../core/database/repositories/repository_providers.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../../../advances/providers/advance_providers.dart';
import '../../../../advances/services/advance_service.dart';
import '../../../providers/service_providers.dart';
import '../fast_sale_providers.dart';
import 'pos_payment_line_notifier.dart';
import 'pos_withhold_line_notifier.dart';

export 'pos_payment_line_notifier.dart';
export 'pos_withhold_line_notifier.dart';

/// Provider for payment lines stored by order ID
/// `Map<orderId, List<PaymentLine>>`
final posPaymentLinesByOrderProvider =
    NotifierProvider<POSPaymentLinesByOrderNotifier, Map<int, List<PaymentLine>>>(
        () => POSPaymentLinesByOrderNotifier());

/// Provider for withhold lines stored by order ID
/// `Map<orderId, List<WithholdLine>>`
final posWithholdLinesByOrderProvider =
    NotifierProvider<POSWithholdLinesByOrderNotifier, Map<int, List<WithholdLine>>>(
        () => POSWithholdLinesByOrderNotifier());

/// Provider for payment lines of the current active order
final posPaymentLinesProvider = Provider<List<PaymentLine>>((ref) {
  final activeTab = ref.watch(fastSaleProvider.select((s) => s.activeTab));
  if (activeTab == null) return [];
  final allLines = ref.watch(posPaymentLinesByOrderProvider);
  return allLines[activeTab.orderId] ?? [];
});

/// Provider for withhold lines of the current active order
final posWithholdLinesProvider = Provider<List<WithholdLine>>((ref) {
  final activeTab = ref.watch(fastSaleProvider.select((s) => s.activeTab));
  if (activeTab == null) return [];
  final allLines = ref.watch(posWithholdLinesByOrderProvider);
  return allLines[activeTab.orderId] ?? [];
});

/// Reactive stream that triggers journal refresh when collection configs change.
///
/// Watches `collectionConfigManager.watchLocalSearch()` so that when configs
/// are synced or modified locally (e.g., allowed_journal_ids updated), the
/// dependent [posAvailableJournalsProvider] rebuilds automatically.
final _journalsConfigRefreshProvider = StreamProvider<void>((ref) {
  return collectionConfigManager.watchLocalSearch().map((_) {});
});

/// Provider for available journals in the current session.
///
/// Already local-first: PaymentService.getAvailableJournals() reads from local
/// DB first (session -> config -> allowed_journal_ids -> journal rows + payment
/// methods) and only falls back to Odoo when no local data exists.
///
/// Reactive: watches [currentSessionProvider] (rebuilds on session change) and
/// [_journalsConfigRefreshProvider] (rebuilds when collection configs change
/// in the local DB). The underlying data pipeline composes 3 tables
/// (collection_config, account_journal, account_payment_method_line) via raw
/// SQL queries, so a pure StreamProvider would require composing multiple Drift
/// watch queries. This hybrid approach gets reactivity with minimal complexity.
final posAvailableJournalsProvider = FutureProvider<List<AvailableJournal>>((ref) async {
  // Watch config stream — triggers rebuild when configs change in local DB
  ref.watch(_journalsConfigRefreshProvider);

  var currentSession = ref.watch(currentSessionProvider);

  // If no session in provider, try to load from database
  if (currentSession == null) {
    logger.d('[POSPayment] No session in provider, trying to load from database...');
    final collectionRepo = ref.read(collectionRepositoryProvider);
    final userRepo = ref.read(userRepositoryProvider);

    if (collectionRepo != null && userRepo != null) {
      try {
        final user = await userRepo.getCurrentUser();
        if (user != null) {
          // IMPORTANT: User.id is the Odoo user ID
          // CollectionSession.userId stores the Odoo user ID
          final session = await collectionRepo.getActiveUserSession(user.id);
          if (session != null) {
            // Set session in provider for future use
            ref.read(currentSessionProvider.notifier).set(session);
            currentSession = session;
            logger.d('[POSPayment] Loaded session from database: ${session.name}');
          } else {
            logger.d('[POSPayment] No active session found for user ${user.name}');
          }
        }
      } catch (e) {
        logger.e('[POSPayment]', 'Error loading session from database: $e');
      }
    }
  }

  if (currentSession == null) {
    logger.d('[POSPayment] No session available, returning empty journals');
    return [];
  }

  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getAvailableJournals(currentSession.id);
});

/// Reactive stream of available withhold taxes from local DB.
///
/// Watches all active taxes locally and filters to withhold types
/// (withhold_vat_sale, withhold_income_sale) using the synced
/// tax_group_l10n_ec_type field. Maps Tax -> AvailableWithholdTax
/// with generated Spanish names. UI auto-updates when taxes are synced.
final posWithholdTaxesStreamProvider = StreamProvider<List<AvailableWithholdTax>>((ref) {
  return taxManager.watchLocalSearch(
    domain: [
      ['active', '=', true],
    ],
    orderBy: 'sequence, name',
  ).map((taxes) {
    return taxes
        .where((tax) =>
            tax.taxGroupL10nEcType == 'withhold_vat_sale' ||
            tax.taxGroupL10nEcType == 'withhold_income_sale')
        .map((tax) {
      final percent = tax.amount.abs();
      final percentStr = percent == percent.truncateToDouble()
          ? percent.toInt().toString()
          : percent.toStringAsFixed(2);

      String spanishName;
      if (tax.taxGroupL10nEcType == 'withhold_vat_sale') {
        spanishName = '$percentStr% Ret. IVA';
      } else {
        spanishName = '$percentStr% Ret. de la Fuente';
      }

      final withholdType = tax.taxGroupL10nEcType == 'withhold_vat_sale'
          ? WithholdType.vatSale
          : WithholdType.incomeSale;

      return AvailableWithholdTax(
        id: tax.id,
        name: tax.name,
        spanishName: spanishName,
        amount: tax.amount,
        withholdType: withholdType,
      );
    }).toList();
  });
});

/// Provider for available withhold taxes (StreamProvider).
///
/// Directly exposes [posWithholdTaxesStreamProvider] — no FutureProvider
/// facade needed since consumers use `.when()` which works with both types.
/// Alias kept for backward compatibility.
final posAvailableWithholdTaxesProvider = posWithholdTaxesStreamProvider;

/// Reactive stream of available advances for the active order's partner.
///
/// Uses `advanceManager.watchLocalSearch()` with domain filters matching
/// the original PaymentService query: advance_type=advance, state in
/// [posted, in_use], amount_available > 0. Maps Advance -> AvailableAdvance.
/// UI auto-updates when advances are synced or modified locally.
final posAvailableAdvancesStream = StreamProvider<List<AvailableAdvance>>((ref) {
  final activeTab = ref.watch(fastSaleProvider.select((s) => s.activeTab));
  if (activeTab?.order?.partnerId == null) return Stream.value([]);

  final partnerId = activeTab!.order!.partnerId!;
  return advanceManager.watchLocalSearch(
    domain: [
      ['partner_id', '=', partnerId],
      ['advance_type', '=', 'advance'],
      ['state', 'in', ['posted', 'in_use']],
      ['amount_available', '>', 0],
    ],
    orderBy: 'date desc',
  ).map((advances) => advances.map((a) => AvailableAdvance(
    id: a.id,
    name: a.name ?? '',
    amountAvailable: a.amountAvailable,
    date: a.date,
    reference: a.reference,
  )).toList());
});

/// Provider for available advances (StreamProvider).
///
/// Directly exposes [posAvailableAdvancesStream] — no FutureProvider
/// facade needed since consumers use `.when()` which works with both types.
/// Alias kept for backward compatibility.
final posAvailableAdvancesProvider = posAvailableAdvancesStream;

/// Reactive stream of available credit notes for the active order's partner.
///
/// Uses `accountMoveManager.watchLocalSearch()` with domain filters matching
/// the original PaymentService query: move_type=out_refund, state=posted,
/// payment_state in [not_paid, partial], amount_residual > 0.
/// Maps AccountMove -> AvailableCreditNote.
/// UI auto-updates when credit notes are synced or modified locally.
final posAvailableCreditNotesStream = StreamProvider<List<AvailableCreditNote>>((ref) {
  final activeTab = ref.watch(fastSaleProvider.select((s) => s.activeTab));
  if (activeTab?.order?.partnerId == null) return Stream.value([]);

  final partnerId = activeTab!.order!.partnerId!;
  return accountMoveManager.watchLocalSearch(
    domain: [
      ['partner_id', '=', partnerId],
      ['move_type', '=', 'out_refund'],
      ['state', '=', 'posted'],
      ['payment_state', 'in', ['not_paid', 'partial']],
      ['amount_residual', '>', 0],
    ],
    orderBy: 'invoice_date desc',
  ).map((moves) => moves.map((nc) => AvailableCreditNote(
    id: nc.id,
    name: nc.name,
    amountResidual: nc.amountResidual,
    invoiceDate: nc.invoiceDate,
    ref: nc.invoiceOrigin,
  )).toList());
});

/// Provider for available credit notes (StreamProvider).
///
/// Directly exposes [posAvailableCreditNotesStream] — no FutureProvider
/// facade needed since consumers use `.when()` which works with both types.
/// Alias kept for backward compatibility.
final posAvailableCreditNotesProvider = posAvailableCreditNotesStream;

/// Provider for partner bank accounts (for cheques)
final posPartnerBanksProvider = FutureProvider<List<PartnerBank>>((ref) async {
  final activeTab = ref.watch(fastSaleProvider.select((s) => s.activeTab));
  if (activeTab?.order?.partnerId == null) return [];

  final advanceService = ref.watch(advanceServiceProvider);
  return advanceService.getPartnerBanks(activeTab!.order!.partnerId!);
});

/// Provider for available banks (for card payments)
final posAvailableBanksProvider = FutureProvider<List<AvailableBank>>((ref) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getBanks();
});

/// Provider family for card brands by journal
final posCardBrandsByJournalProvider = FutureProvider.family<List<CardBrand>, int>((ref, journalId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getCardBrands(journalId);
});

/// Provider family for card deadlines by card type
final posCardDeadlinesProvider = FutureProvider.family<List<CardDeadline>, ({int journalId, CardType cardType})>((ref, params) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getCardDeadlines(params.journalId, params.cardType);
});

/// Provider family for open lotes by journal
final posOpenLotesProvider = FutureProvider.family<List<CardLote>, int>((ref, journalId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getOpenLotes(journalId);
});
