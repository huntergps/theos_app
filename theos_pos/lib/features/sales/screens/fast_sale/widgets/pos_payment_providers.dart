import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers.dart';
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
///
/// La carga de sesión desde BD se delega a [CurrentSession.ensureLoaded()] para
/// evitar que este provider mute otro provider durante su fase de build.
final posAvailableJournalsProvider = FutureProvider<List<AvailableJournal>>((ref) async {
  // Watch config stream — triggers rebuild when configs change in local DB
  ref.watch(_journalsConfigRefreshProvider);

  // Watch currentSessionProvider — triggers rebuild on session change.
  // Si es null, ensureLoaded() lo carga desde BD y actualiza el estado del
  // notifier sin que este provider lo haga directamente (evita "modify during build").
  final currentSession = ref.watch(currentSessionProvider) ??
      await ref.read(currentSessionProvider.notifier).ensureLoaded();

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

/// Reactive stream of partner bank accounts (for cheques).
///
/// Usa `AdvanceService.watchPartnerBanks()` (Drift `.watch()` sobre
/// `res_partner_bank`). NOTA: `res_partner_bank` ya tiene `bank_name` como
/// columna desnormalizada — no hizo falta ningún join manual con un
/// manager/tabla de `res.bank` para resolver el nombre del banco (el dato
/// ya estaba en la misma fila). No se unificó el `PartnerBank` local
/// (`advance_service.dart`) con el `PartnerBank` de `theos_pos_core` — fuera
/// de alcance de este refactor.
///
/// Los `ref.invalidate(posPartnerBanksProvider)` en `add_payment_dialog.dart`
/// (tras crear una cuenta bancaria) ya no son estrictamente necesarios
/// (el stream se actualiza solo), pero se dejan tal cual: son inofensivos y
/// tocar ese archivo no está en el alcance de esta ronda.
final posPartnerBanksStreamProvider = StreamProvider<List<PartnerBank>>((ref) {
  final activeTab = ref.watch(fastSaleProvider.select((s) => s.activeTab));
  final partnerId = activeTab?.order?.partnerId;
  if (partnerId == null) return Stream.value(const []);

  final advanceService = ref.watch(advanceServiceProvider);
  if (advanceService == null) return Stream.value(const []);
  return advanceService.watchPartnerBanks(partnerId);
});

/// Provider for partner bank accounts (for cheques).
///
/// Directly exposes [posPartnerBanksStreamProvider] — no FutureProvider
/// facade needed since consumers use `.when()` which works with both types.
/// Alias kept for backward compatibility.
final posPartnerBanksProvider = posPartnerBanksStreamProvider;

/// Reactive stream of available banks (for card payments).
///
/// Usa `PaymentService.watchBanks()` (Drift `.watch()` directo sobre
/// `res_bank`, ver nota en `BankRepository.watchBanks` — no existe un
/// `bankManager` generado para este modelo todavía). La UI se actualiza sola
/// cuando la tabla cambia, sin depender de que otro provider se invalide.
final posAvailableBanksStreamProvider = StreamProvider<List<AvailableBank>>((ref) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.watchBanks();
});

/// Provider for available banks (for card payments).
///
/// Directly exposes [posAvailableBanksStreamProvider] — no FutureProvider
/// facade needed since consumers use `.when()` which works with both types.
/// Alias kept for backward compatibility (mismo patrón que
/// `posAvailableAdvancesProvider`/`posAvailableCreditNotesProvider`).
final posAvailableBanksProvider = posAvailableBanksStreamProvider;

/// Reactive stream family de marcas de tarjeta configuradas por diario.
///
/// Antes era un `FutureProvider.family` (comentario "DEUDA TÉCNICA" —
/// desactualizado, ver ítem 1 Grupo B de `d-flutter.md`). `AccountCreditCardBrand`
/// es una tabla Drift plana sin `@OdooModel`/manager generado — en vez de
/// promoverla (fuera de alcance), `PaymentService.watchCardBrandsByJournal`
/// combina el `.watch()` del diario con el `.watch()` de la tabla de marcas.
/// La UI se actualiza sola cuando el diario o las marcas cambian en local
/// (ej. tras el sync-on-demand que sigue disparando `getCardBrands`).
final posCardBrandsByJournalStreamProvider =
    StreamProvider.family<List<CardBrand>, int>((ref, journalId) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.watchCardBrandsByJournal(journalId);
});

/// Provider family for card brands by journal.
///
/// Directly exposes [posCardBrandsByJournalStreamProvider] — no FutureProvider
/// facade needed since consumers use `.whenData()`/`AsyncValue` which works
/// with both types. Alias kept for backward compatibility (mismo patrón que
/// `posAvailableAdvancesProvider`/`posAvailableCreditNotesProvider`).
final posCardBrandsByJournalProvider = posCardBrandsByJournalStreamProvider;

/// Reactive stream family de plazos de tarjeta configurados por diario y
/// tipo de tarjeta (crédito/débito). Mismo patrón y motivo que
/// [posCardBrandsByJournalStreamProvider] — ver
/// `PaymentService.watchCardDeadlines`.
final posCardDeadlinesStreamProvider = StreamProvider.family<List<CardDeadline>,
    ({int journalId, CardType cardType})>((ref, params) {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.watchCardDeadlines(params.journalId, params.cardType);
});

/// Provider family for card deadlines by card type.
///
/// Directly exposes [posCardDeadlinesStreamProvider] — no FutureProvider
/// facade needed since consumers use `.whenData()`/`AsyncValue` which works
/// with both types. Alias kept for backward compatibility.
final posCardDeadlinesProvider = posCardDeadlinesStreamProvider;

/// Provider family for open lotes by journal
final posOpenLotesProvider = FutureProvider.family<List<CardLote>, int>((ref, journalId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getOpenLotes(journalId);
});
