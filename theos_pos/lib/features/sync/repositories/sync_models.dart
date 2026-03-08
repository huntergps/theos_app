/// Sync models - App adapter
///
/// Re-exports sync models from odoo_sdk and defines local data classes
/// for single-record sync results.
library;

export 'package:odoo_sdk/odoo_sdk.dart'
    show
        SyncProgress,
        SyncPhase,
        SyncModelInfo,
        SyncProgressCallback,
        SyncCancelledException;

/// Sync result for a single product.
class ProductSyncData {
  final String name;

  const ProductSyncData({required this.name});
}

/// Sync result for a single partner.
class PartnerSyncData {
  final String name;
  final String? vat;
  final String? street;
  final String? phone;
  final String? email;
  final String? avatar;

  const PartnerSyncData({
    required this.name,
    this.vat,
    this.street,
    this.phone,
    this.email,
    this.avatar,
  });
}

/// Sync result for a single UoM.
class UomSyncData {
  final String name;

  const UomSyncData({required this.name});
}

/// Sync result for a single user.
class UserSyncData {
  final String name;
  final String? email;

  const UserSyncData({required this.name, this.email});
}

/// Sync result for a single company.
class CompanySyncData {
  final String name;

  const CompanySyncData({required this.name});
}
