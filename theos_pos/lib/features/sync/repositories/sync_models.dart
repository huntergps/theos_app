/// App-specific extensions for synchronization contracts.
library;

import 'package:odoo_sdk/odoo_sdk.dart';

/// Converts the SDK's value-based sync result into the fail-fast contract
/// required by the app watermark coordinator.
///
/// `GenericSyncRepository` deliberately reports transport/parser failures in
/// [ModelSyncResult] instead of throwing. Catalog callers must not interpret a
/// partial/error result as a completed subpass, otherwise the next watermark
/// can skip the missing rows permanently.
extension RequiredModelSyncResult on ModelSyncResult {
  int requireSuccess() {
    if (wasCancelled) {
      throw SyncCancelledException(
        'Sync of $model was cancelled',
        syncedCount: synced,
      );
    }
    if (error case final failure?) {
      throw StateError('Sync of $model failed: $failure');
    }
    return synced;
  }
}
