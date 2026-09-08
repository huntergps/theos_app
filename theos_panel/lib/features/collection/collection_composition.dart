import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'collection_contracts.dart';

final collectionActionsProvider = Provider<CollectionActions>(
  (ref) => const UnconfiguredCollectionActions(),
);

final collectionShiftProvider = Provider<CollectionShiftSnapshot>(
  (ref) => const CollectionShiftSnapshot(
    id: 'active',
    state: CollectionShiftState.conflict,
    expectedVersion: 0,
  ),
);

final collectionPendingProvider = Provider<List<CollectionPendingSale>>(
  (ref) => const [],
);
final collectionCapabilitiesProvider = Provider<CollectionCapabilitySnapshot>(
  (ref) => const CollectionCapabilitySnapshot(),
);

/// Until the runtime scope is connected, actions stay visibly unavailable and
/// never report a fabricated success.
class UnconfiguredCollectionActions implements CollectionActions {
  const UnconfiguredCollectionActions();
  @override
  Future<CollectionShiftSnapshot> open(CollectionShiftSnapshot shift) async =>
      CollectionShiftSnapshot(
        id: shift.id,
        state: CollectionShiftState.conflict,
        expectedVersion: shift.expectedVersion,
      );
  @override
  Future<CollectionShiftSnapshot> close(CollectionShiftSnapshot shift) async =>
      CollectionShiftSnapshot(
        id: shift.id,
        state: CollectionShiftState.conflict,
        expectedVersion: shift.expectedVersion,
      );
  @override
  Future<CollectionResultState> collect(
    CollectionPendingSale sale,
    List<CollectionPaymentDraft> payments,
  ) async => CollectionResultState.conflict;
}
