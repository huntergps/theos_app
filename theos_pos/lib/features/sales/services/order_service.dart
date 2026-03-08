import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../repositories/sales_repository.dart';
import 'order_defaults_service.dart';

/// Unified Order Service for creating and managing sale orders
///
/// This service encapsulates shared logic between FastSaleNotifier
/// and SaleOrderFormNotifier to ensure consistency and reduce duplication.
///
/// Features:
/// - Offline-first order creation
/// - Unified defaults loading
/// - Shared field update logic
/// - Consistent sync behavior
///
/// Usage:
/// ```dart
/// final orderService = ref.read(orderServiceProvider);
/// final order = await orderService.createOrder();
/// ```
class OrderService {
  final OrderDefaultsService _defaultsService;
  final SalesRepository? _salesRepo;
  static const _tag = '[OrderService]';

  OrderService({
    required OrderDefaultsService defaultsService,
    required SalesRepository? salesRepo,
  })  : _defaultsService = defaultsService,
        _salesRepo = salesRepo;

  /// Create a new order with offline-first defaults
  ///
  /// This is the unified method for creating orders that should be used
  /// by both FastSaleNotifier and SaleOrderFormNotifier.
  ///
  /// Returns a tuple of (SaleOrder, List of name lookups to perform)
  Future<SaleOrder> createOrder({
    int? partnerId,
    String? partnerName,
    int? pricelistId,
    String? pricelistName,
    int? paymentTermId,
    String? paymentTermName,
    int? warehouseId,
    String? warehouseName,
    int? userId,
    String? userName,
  }) async {
    logger.d(_tag, 'Creating new order (offline-first)...');

    // Step 1: Get local defaults FIRST (instant, no network)
    final defaults = await _defaultsService.getLocalDefaults();
    logger.d(_tag, 'Local defaults: $defaults');

    // Step 2: Apply overrides if provided
    final effectivePartnerId = partnerId ?? defaults.partnerId;
    final effectivePartnerName = partnerName ?? defaults.partnerName;
    final effectivePricelistId = pricelistId ?? defaults.pricelistId;
    final effectivePricelistName = pricelistName ?? defaults.pricelistName;
    final effectivePaymentTermId = paymentTermId ?? defaults.paymentTermId;
    final effectivePaymentTermName =
        paymentTermName ?? defaults.paymentTermName;
    final effectiveWarehouseId = warehouseId ?? defaults.warehouseId;
    final effectiveWarehouseName = warehouseName ?? defaults.warehouseName;
    final effectiveUserId = userId ?? defaults.userId;
    final effectiveUserName = userName ?? defaults.userName;

    // Step 3: Generate temporary local ID
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    // Step 4: Create order object
    final order = SaleOrder(
      id: tempId,
      name: 'New', // Will be replaced by sequence on sync
      partnerId: effectivePartnerId,
      partnerName: effectivePartnerName,
      pricelistId: effectivePricelistId,
      pricelistName: effectivePricelistName,
      paymentTermId: effectivePaymentTermId,
      paymentTermName: effectivePaymentTermName,
      warehouseId: effectiveWarehouseId,
      warehouseName: effectiveWarehouseName,
      userId: effectiveUserId,
      userName: effectiveUserName,
      dateOrder: DateTime.now(),
      state: SaleOrderState.draft,
      companyId: defaults.companyId,
      amountTotal: 0,
      amountUntaxed: 0,
      amountTax: 0,
      locked: false,
    );

    logger.i(
      _tag,
      'Order created: partner=${order.partnerName}, '
      'pricelist=${order.pricelistName}, '
      'warehouse=${order.warehouseName}',
    );

    return order;
  }

  /// Sync defaults from Odoo in background
  ///
  /// Call this after creating an order to optionally get fresh defaults
  /// from Odoo and update missing fields. Returns updated order if changes
  /// were made, or null if no changes needed.
  Future<SaleOrder?> syncDefaultsFromOdoo(SaleOrder order) async {
    try {
      final salesRepo = _salesRepo;
      if (salesRepo == null) return null;

      final odooDefaults = await salesRepo.getDefaultValues();
      if (odooDefaults.isEmpty) return null;

      logger.d(_tag, 'Odoo defaults received: $odooDefaults');

      bool needsUpdate = false;
      SaleOrder updated = order;

      // Apply pricelist if local was null
      if (order.pricelistId == null && odooDefaults['pricelist_id'] != null) {
        final pricelistId = odoo.extractMany2oneId(odooDefaults['pricelist_id']);
        if (pricelistId != null) {
          final pricelistName = await _lookupName(
            'product_pricelist',
            pricelistId,
          );
          updated = updated.copyWith(
            pricelistId: pricelistId,
            pricelistName: pricelistName,
          );
          needsUpdate = true;
          logger.d(_tag, 'Applying Odoo pricelist: $pricelistId');
        }
      }

      // Apply payment term if local was null
      if (order.paymentTermId == null &&
          odooDefaults['payment_term_id'] != null) {
        final paymentTermId = odoo.extractMany2oneId(odooDefaults['payment_term_id']);
        if (paymentTermId != null) {
          final paymentTermName = await _lookupName(
            'account_payment_term',
            paymentTermId,
          );
          updated = updated.copyWith(
            paymentTermId: paymentTermId,
            paymentTermName: paymentTermName,
          );
          needsUpdate = true;
          logger.d(_tag, 'Applying Odoo paymentTerm: $paymentTermId');
        }
      }

      if (needsUpdate) {
        logger.i(_tag, 'Order updated with Odoo defaults');
        return updated;
      }

      return null;
    } catch (e) {
      logger.d(_tag, 'Background Odoo sync skipped: $e');
      return null;
    }
  }

  /// Lookup name from local DB by manager type and ID
  Future<String?> _lookupName(String table, int id) async {
    try {
      switch (table) {
        case 'product_pricelist':
          final record = await pricelistManager.readLocal(id);
          return record?.name;
        case 'account_payment_term':
          final record = await paymentTermManager.readLocal(id);
          return record?.name;
        default:
          logger.w(_tag, 'Unknown table for name lookup: $table');
          return null;
      }
    } catch (e) {
      logger.w(_tag, 'Could not lookup name: $e');
      return null;
    }
  }
}
