import 'package:theos_pos_core/theos_pos_core.dart' show SaleOrder, SaleOrderLine;

import '../../../shared/utils/formatting_utils.dart';

/// Base interface for order state used by both screens
///
/// This interface defines the common properties and computed values
/// that both Fast Sale POS and Sale Order Form share.
///
/// Implementation classes:
/// - [FastSaleTabState] - POS tab state
/// - [SaleOrderFormState] - Form state
abstract class BaseOrderState {
  // ========== Core Order Data ==========

  /// The underlying sale order (null for new orders)
  SaleOrder? get order;

  /// Order lines (product lines only, excludes sections/notes)
  List<SaleOrderLine> get lines;

  /// All lines including sections and notes
  List<SaleOrderLine> get allLines => lines;

  // ========== Partner Data ==========

  /// Partner/customer ID
  int? get partnerId;

  /// Partner/customer name
  String? get partnerName;

  /// Partner VAT/RUC
  String? get partnerVat => order?.partnerVat;

  /// Partner phone
  String? get partnerPhone => order?.partnerPhone;

  /// Partner email
  String? get partnerEmail => order?.partnerEmail;

  /// Partner street address
  String? get partnerStreet => order?.partnerStreet;

  // ========== Configuration Data ==========

  /// Pricelist ID
  int? get pricelistId;

  /// Payment term ID
  int? get paymentTermId;

  /// Warehouse ID
  int? get warehouseId;

  /// Seller/user ID
  int? get userId;

  /// Order date
  DateTime? get dateOrder;

  // ========== Tracking & Validation ==========

  /// Whether there are unsaved changes
  bool get hasChanges;

  /// Version counter for lines (incremented on WebSocket updates)
  int get linesVersion;

  /// Authorized payment term IDs for the current partner
  List<int> get partnerPaymentTermIds;

  /// Whether credit check has been bypassed
  bool get creditCheckBypassed => false;

  // ========== Ecuador l10n Fields ==========

  /// Whether this is a final consumer sale
  bool get isFinalConsumer => order?.isFinalConsumer ?? false;

  /// End customer name (for final consumer sales)
  String? get endCustomerName => order?.endCustomerName;

  /// End customer phone
  String? get endCustomerPhone => order?.endCustomerPhone;

  /// End customer email
  String? get endCustomerEmail => order?.endCustomerEmail;

  /// Referrer ID
  int? get referrerId => order?.referrerId;

  /// Referrer name
  String? get referrerName => order?.referrerName;

  // ========== Computed Values ==========

  /// Calculate subtotal from product lines
  double get subtotal {
    return lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceSubtotal);
  }

  /// Calculate tax total from product lines
  double get taxTotal {
    return lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTax);
  }

  /// Calculate grand total from product lines
  double get total {
    return lines
        .where((l) => l.isProductLine)
        .fold(0.0, (sum, line) => sum + line.priceTotal);
  }

  /// Number of product lines (excluding sections/notes)
  int get productLineCount {
    return lines.where((l) => l.isProductLine).length;
  }

  /// Whether the order can be edited
  bool get isEditable {
    return order?.isEditable ?? true;
  }

  /// Whether the order is a new unsaved order
  bool get isNewOrder {
    return order == null || (order!.id < 0);
  }

  /// Whether the order is synced with Odoo
  bool get isSynced {
    return order?.isSynced ?? false;
  }
}

/// Detail of a conflict between local and server values
class ConflictDetail {
  final String fieldName;
  final dynamic localValue;
  final dynamic serverValue;
  final String? serverUserName;

  const ConflictDetail({
    required this.fieldName,
    required this.localValue,
    required this.serverValue,
    this.serverUserName,
  });

  @override
  String toString() =>
      'ConflictDetail($fieldName: local=$localValue, server=$serverValue'
      '${serverUserName != null ? ", by=$serverUserName" : ""})';
}

/// Extension methods for any state implementing BaseOrderState
extension BaseOrderStateExtension on BaseOrderState {
  /// Check if a partner field can be modified
  bool canEditPartner(String field) {
    if (!isEditable) return false;
    // Add field-specific checks if needed
    return true;
  }

  /// Check if order has partner
  bool get hasPartner => partnerId != null;

  /// Check if order has lines
  bool get hasLines => productLineCount > 0;

  /// Check if order is ready for confirmation
  bool get canConfirm {
    return hasPartner && hasLines && isEditable;
  }

  /// Get a summary of the order state
  String get stateSummary {
    return 'Order ${order?.name ?? "New"}: '
        '$productLineCount lines, '
        'total: ${total.toCurrency()}, '
        'hasChanges: $hasChanges';
  }
}
