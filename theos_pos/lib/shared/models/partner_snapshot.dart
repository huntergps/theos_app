/// PartnerSnapshot - Lightweight embedded partner data for orders
///
/// This is a minimal snapshot of partner data embedded in orders.
/// It captures the partner state at the time of the order, avoiding
/// complex lazy loading while maintaining data integrity.
///
/// Use cases:
/// - SaleOrder.partner (main customer)
/// - SaleOrder.invoicePartner (billing address)
/// - SaleOrder.shippingPartner (shipping address)
/// - SaleOrderFormState.partner (form editing)
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import 'package:theos_pos_core/theos_pos_core.dart';

part 'partner_snapshot.freezed.dart';
part 'partner_snapshot.g.dart';

/// Lightweight snapshot of partner data for embedding in orders
///
/// Contains only the fields needed for display and basic operations.
/// For full partner data, load the complete Client model via PartnerManager.
@freezed
abstract class PartnerSnapshot with _$PartnerSnapshot {
  const PartnerSnapshot._();

  const factory PartnerSnapshot({
    /// Partner ID in Odoo
    required int id,

    /// Partner display name
    required String name,

    /// VAT/RUC identification
    String? vat,

    /// Street address
    String? street,

    /// Phone number
    String? phone,

    /// Email address
    String? email,

    /// Base64 avatar image
    String? avatar,

    /// Reference code
    String? ref,

    /// Whether partner is a company
    @Default(false) bool isCompany,

    /// Default pricelist ID
    int? pricelistId,

    /// Default payment term ID
    int? paymentTermId,

    /// Credit limit (for validation)
    double? creditLimit,

    /// Current credit balance
    double? credit,

    /// Credit to invoice
    double? creditToInvoice,

    /// Whether partner allows over-credit
    @Default(false) bool allowOverCredit,
  }) = _PartnerSnapshot;

  /// Create from full Client model
  factory PartnerSnapshot.fromClient(Client client) {
    return PartnerSnapshot(
      id: client.id,
      name: client.name,
      vat: client.vat,
      street: client.street,
      phone: client.phone ?? client.mobile,
      email: client.email,
      avatar: client.avatar128,
      ref: client.ref,
      isCompany: client.isCompany,
      pricelistId: client.propertyProductPricelistId,
      paymentTermId: client.propertyPaymentTermId,
      creditLimit: client.creditLimit,
      credit: client.credit,
      creditToInvoice: client.creditToInvoice,
      allowOverCredit: client.allowOverCredit,
    );
  }

  /// Create from Odoo many2one partner_id response
  factory PartnerSnapshot.fromOdooPartner(Map<String, dynamic> data) {
    return PartnerSnapshot(
      id: odoo.extractMany2oneId(data['partner_id']) ?? 0,
      name: odoo.extractMany2oneName(data['partner_id']) ?? '',
      vat: data['partner_vat'] as String?,
      street: data['partner_street'] as String?,
      phone: data['partner_phone'] as String?,
      email: data['partner_email'] as String?,
      avatar: data['partner_avatar'] as String?,
    );
  }

  /// Create from Drift row fields
  factory PartnerSnapshot.fromDrift({
    required int? partnerId,
    String? partnerName,
    String? partnerVat,
    String? partnerStreet,
    String? partnerPhone,
    String? partnerEmail,
    String? partnerAvatar,
  }) {
    if (partnerId == null) {
      throw ArgumentError('partnerId cannot be null');
    }
    return PartnerSnapshot(
      id: partnerId,
      name: partnerName ?? '',
      vat: partnerVat,
      street: partnerStreet,
      phone: partnerPhone,
      email: partnerEmail,
      avatar: partnerAvatar,
    );
  }

  /// Create nullable from Drift row fields
  static PartnerSnapshot? fromDriftNullable({
    int? partnerId,
    String? partnerName,
    String? partnerVat,
    String? partnerStreet,
    String? partnerPhone,
    String? partnerEmail,
    String? partnerAvatar,
  }) {
    if (partnerId == null) return null;
    return PartnerSnapshot(
      id: partnerId,
      name: partnerName ?? '',
      vat: partnerVat,
      street: partnerStreet,
      phone: partnerPhone,
      email: partnerEmail,
      avatar: partnerAvatar,
    );
  }

  factory PartnerSnapshot.fromJson(Map<String, dynamic> json) =>
      _$PartnerSnapshotFromJson(json);

  // =========================================================================
  // Computed Properties
  // =========================================================================

  /// Display string for UI (name with ref/vat)
  String get displayName {
    if (ref != null && ref!.isNotEmpty) {
      return '[$ref] $name';
    }
    if (vat != null && vat!.isNotEmpty) {
      return '$name ($vat)';
    }
    return name;
  }

  /// Whether this is the final consumer (Ecuador: RUC 9999999999999)
  bool get isFinalConsumer => vat == '9999999999999';

  /// Computed credit available
  double? get creditAvailable {
    if (creditLimit == null || creditLimit == 0) return null;
    return creditLimit! - (credit ?? 0) - (creditToInvoice ?? 0);
  }

  /// Whether credit is exceeded
  bool get isCreditExceeded {
    final available = creditAvailable;
    return available != null && available < 0;
  }

  /// Address components for display
  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    return parts.join(', ');
  }

}

/// Extension to create PartnerSnapshot from various sources
extension PartnerSnapshotExtension on Client {
  /// Convert to lightweight snapshot
  PartnerSnapshot toSnapshot() => PartnerSnapshot.fromClient(this);
}
