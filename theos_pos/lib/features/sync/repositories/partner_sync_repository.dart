/// PartnerSyncRepository - Sync de clientes usando GenericSyncRepository
library;

import 'package:odoo_sdk/odoo_sdk.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Repository for syncing res.partner (customers/suppliers) from Odoo.
///
/// Usa GenericSyncRepository para eliminar código repetitivo.
class PartnerSyncRepository {
  final OdooClient? odooClient;
  final AppDatabase db;
  final GenericSyncRepository _syncRepo;

  PartnerSyncRepository({
    required this.db,
    this.odooClient,
  }) : _syncRepo = GenericSyncRepository(odooClient: odooClient);

  bool get isOnline => odooClient != null;

  void cancelSync() => _syncRepo.cancelSync();
  void resetCancelFlag() => _syncRepo.resetCancelFlag();

  static const _partnerFields = [
    'id',
    'name',
    'display_name',
    'ref',
    'vat',
    'email',
    'phone',
    'street',
    'street2',
    'city',
    'zip',
    'country_id',
    'state_id',
    'avatar_128',
    'is_company',
    'active',
    'parent_id',
    'commercial_partner_id',
    'property_product_pricelist',
    'property_payment_term_id',
    'lang',
    'comment',
    'write_date',
    // Credit control fields (l10n_ec_sale_credit module)
    'credit_limit',
    'credit',
    'credit_to_invoice',
    'allow_over_credit',
    'total_overdue',
    'unpaid_invoices_count',
    // Post-dated invoice field (l10n_ec_sale_base module)
    'dias_max_factura_posterior',
  ];

  /// Sync all partners from Odoo
  Future<int> syncPartners({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'res.partner',
        fields: _partnerFields,
        domain: [
          ['active', '=', true],
        ],
        batchSize: batchSize,
        fromOdoo: clientManager.fromOdoo,
        upsertLocal: clientManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }
}
