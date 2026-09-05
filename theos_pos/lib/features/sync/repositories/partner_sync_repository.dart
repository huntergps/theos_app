/// PartnerSyncRepository - Sync de clientes usando GenericSyncRepository
library;

import 'package:odoo_sdk/odoo_sdk.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

import 'sync_models.dart';

/// Repository for syncing res.partner (customers/suppliers) from Odoo.
///
/// Usa GenericSyncRepository para eliminar código repetitivo.
class PartnerSyncRepository {
  final OdooClient? odooClient;
  final AppDatabase db;
  final GenericSyncRepository _syncRepo;

  PartnerSyncRepository({required this.db, this.odooClient})
    : _syncRepo = GenericSyncRepository(odooClient: odooClient);

  bool get isOnline => odooClient != null;

  void cancelSync() => _syncRepo.cancelSync();
  void resetCancelFlag() => _syncRepo.resetCancelFlag();

  /// Sync all partners from Odoo
  Future<int> syncPartners({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'res.partner',
        fields: clientManager.odooFields,
        domain: [
          ['active', '=', true],
        ],
        batchSize: batchSize,
        fromOdoo: clientManager.fromOdoo,
        upsertLocal: clientManager.upsertLocal,
        upsertLocalBatch: clientManager.upsertLocalBatch,
        isolateParser: ClientManager.fromOdooMap,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.requireSuccess();
  }
}
