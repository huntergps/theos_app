import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/collection/collection_contracts.dart';

void main() {
  test('capabilities are explicit and payment remains minor-units', () {
    const capabilities = CollectionCapabilitySnapshot(
      available: {CollectionCapability.deposits},
    );
    expect(capabilities.supports(CollectionCapability.deposits), isTrue);
    expect(capabilities.supports(CollectionCapability.advances), isFalse);
    const payment = CollectionPaymentDraft(journalId: 7, amountMinor: 1250);
    expect(payment.amountMinor, 1250);
    expect(
      collectionTotalMinor(const [
        CollectionPaymentDraft(journalId: 1, amountMinor: 500),
        CollectionPaymentDraft(journalId: 2, amountMinor: 750),
      ]),
      1250,
    );
  });

  test('shift conflict preserves version and difference', () {
    const shift = CollectionShiftSnapshot(
      id: 'shift-1',
      state: CollectionShiftState.conflict,
      expectedVersion: 4,
      differenceMinor: -125,
    );
    expect(shift.state, CollectionShiftState.conflict);
    expect(shift.differenceMinor, -125);
  });
}
