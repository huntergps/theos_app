import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Reactive stream of all active payment terms from local DB.
///
/// Uses `paymentTermManager.watchLocalSearch()` so UI auto-updates
/// when payment terms are synced, created, or modified locally.
final paymentTermsProvider = StreamProvider<List<PaymentTerm>>((ref) {
  return paymentTermManager.watchLocalSearch(
    domain: [['active', '=', true]],
    orderBy: 'sequence asc',
  );
});

/// Reactive stream of a payment term by ID from local DB.
///
/// Uses `paymentTermManager.watchLocalRecord(id)` so UI auto-updates
/// when the payment term is modified or synced locally.
final paymentTermByIdProvider = StreamProvider.family<PaymentTerm?, int>((ref, paymentTermId) {
  return paymentTermManager.watchLocalRecord(paymentTermId);
});

/// Get a payment term name from cache. Derives from the payment terms stream.
final paymentTermNameProvider = Provider.family<String, int?>((ref, paymentTermId) {
  if (paymentTermId == null) return '';
  final terms = ref.watch(paymentTermsProvider);
  return terms.when(
    data: (list) {
      final found = list.where((t) => t.id == paymentTermId);
      return found.isNotEmpty ? found.first.name : '';
    },
    loading: () => '...',
    error: (_, _) => '',
  );
});

/// Cash payment terms derived from the main payment terms stream.
final cashPaymentTermsProvider = Provider<AsyncValue<List<PaymentTerm>>>((ref) {
  final terms = ref.watch(paymentTermsProvider);
  return terms.whenData(
    (list) => list.where((t) => t.isCash && !t.isCredit).toList(),
  );
});

/// Credit payment terms derived from the main payment terms stream.
final creditPaymentTermsProvider = Provider<AsyncValue<List<PaymentTerm>>>((ref) {
  final terms = ref.watch(paymentTermsProvider);
  return terms.whenData(
    (list) => list.where((t) => t.isCredit).toList(),
  );
});

/// Default cash payment term (first in the list). Derives from cash payment terms.
final defaultCashPaymentTermProvider = Provider<AsyncValue<PaymentTerm?>>((ref) {
  final cashTerms = ref.watch(cashPaymentTermsProvider);
  return cashTerms.whenData(
    (list) => list.isNotEmpty ? list.first : null,
  );
});

/// Check if a payment term requires credit validation. Derives from the payment terms stream.
final requiresCreditValidationProvider = Provider.family<bool, int?>((ref, paymentTermId) {
  if (paymentTermId == null) return false;
  final terms = ref.watch(paymentTermsProvider);
  return terms.when(
    data: (list) {
      final found = list.where((t) => t.id == paymentTermId);
      return found.isNotEmpty && found.first.isCredit;
    },
    loading: () => false,
    error: (_, _) => false,
  );
});
