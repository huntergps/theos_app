import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../repositories/sales_repository.dart';
import '../utils/partner_utils.dart' as partner_utils;

/// Order defaults with all values needed to create a new order
class OrderDefaults {
  final int? partnerId;
  final String? partnerName;
  final String? partnerVat;
  final int? warehouseId;
  final String? warehouseName;
  final int? pricelistId;
  final String? pricelistName;
  final int? paymentTermId;
  final String? paymentTermName;
  final int? userId;
  final String? userName;
  final int? companyId;

  const OrderDefaults({
    this.partnerId,
    this.partnerName,
    this.partnerVat,
    this.warehouseId,
    this.warehouseName,
    this.pricelistId,
    this.pricelistName,
    this.paymentTermId,
    this.paymentTermName,
    this.userId,
    this.userName,
    this.companyId,
  });

  /// Empty defaults (no values set)
  static const OrderDefaults empty = OrderDefaults();

  /// Check if we have essential defaults
  bool get hasEssentials =>
      partnerId != null && warehouseId != null && pricelistId != null;

  @override
  String toString() => 'OrderDefaults('
      'partner=$partnerId ($partnerName), '
      'warehouse=$warehouseId ($warehouseName), '
      'pricelist=$pricelistId ($pricelistName), '
      'paymentTerm=$paymentTermId)';
}

/// Service for loading order defaults with offline-first approach
///
/// Priority:
/// 1. Local database (company/user settings) - instant
/// 2. Consumidor Final lookup - fast
/// 3. Odoo defaults (optional background sync)
///
/// Usage:
/// ```dart
/// final service = ref.read(orderDefaultsServiceProvider);
///
/// // Fast: Load from local database only
/// final defaults = await service.getLocalDefaults();
///
/// // Complete: Load local first, then optionally sync Odoo
/// final defaults = await service.getDefaults(syncWithOdoo: true);
/// ```
class OrderDefaultsService {
  static const _tag = '[OrderDefaults]';
  final AppDatabase _db;
  final SalesRepository? _salesRepo;

  OrderDefaultsService({required AppDatabase db, SalesRepository? salesRepo})
      : _db = db,
        _salesRepo = salesRepo;

  /// Get defaults from local database only (fastest)
  ///
  /// This is the true offline-first approach:
  /// - Returns immediately with cached company/user defaults
  /// - No network calls
  /// - Falls back to Consumidor Final if no default partner
  Future<OrderDefaults> getLocalDefaults() async {
    logger.d(_tag, 'Loading local defaults...');

    final currentUser = await userManager.getCurrentUser();
    final company = currentUser?.companyId != null
        ? await companyManager.readLocal(currentUser!.companyId!)
        : null;

    if (company == null) {
      logger.w(_tag, 'No company found in local database');
      return await _getConsumidorFinalFallback();
    }

    // Start with company/user defaults
    int? partnerId = company.defaultPartnerId;
    String? partnerName = company.defaultPartnerName;

    // Fallback to Consumidor Final if no default partner
    if (partnerId == null) {
      final consumidorFinal = await partner_utils.findConsumidorFinal(
        appDb: _db,
        logTag: _tag,
      );
      if (consumidorFinal != null) {
        partnerId = consumidorFinal.$1;
        partnerName = consumidorFinal.$2;
      }
    }

    final defaults = OrderDefaults(
      partnerId: partnerId,
      partnerName: partnerName,
      warehouseId: company.defaultWarehouseId ?? currentUser?.warehouseId,
      warehouseName: company.defaultWarehouseName ?? currentUser?.warehouseName,
      pricelistId: company.defaultPricelistId,
      pricelistName: company.defaultPricelistName,
      paymentTermId: company.defaultPaymentTermId,
      paymentTermName: company.defaultPaymentTermName,
      userId: currentUser?.id,
      userName: currentUser?.name,
      companyId: company.id,
    );

    logger.d(_tag, 'Local defaults loaded: $defaults');
    return defaults;
  }

  /// Get defaults with optional Odoo sync
  ///
  /// If [syncWithOdoo] is true, will try to fetch fresh defaults from Odoo
  /// and merge with local values. If Odoo call fails, returns local defaults.
  Future<OrderDefaults> getDefaults({
    bool syncWithOdoo = false,
  }) async {
    // Always start with local defaults (instant)
    final localDefaults = await getLocalDefaults();

    if (!syncWithOdoo || _salesRepo == null) {
      return localDefaults;
    }

    // Optionally try to get fresh defaults from Odoo
    try {
      final odooDefaults = await _salesRepo.getDefaultValues();
      logger.d(_tag, 'Odoo defaults received: $odooDefaults');

      return _mergeDefaults(localDefaults, odooDefaults);
    } catch (e) {
      logger.w(_tag, 'Could not get Odoo defaults: $e');
      return localDefaults;
    }
  }

  /// Get company defaults from local database
  Future<Company?> getCompanyConfig() async {
    final currentUser = await userManager.getCurrentUser();
    if (currentUser?.companyId == null) return null;
    return await companyManager.readLocal(currentUser!.companyId!);
  }

  /// Lookup a name by table and ID (local database only)
  Future<String?> lookupName(String table, int id) async {
    switch (table) {
      case 'res_partner':
        final partner = await clientManager.readLocal(id);
        return partner?.name;

      case 'stock_warehouse':
        final warehouse = await warehouseManager.readLocal(id);
        return warehouse?.name;

      case 'product_pricelist':
        final pricelist = await pricelistManager.readLocal(id);
        return pricelist?.name;

      case 'account_payment_term':
        final paymentTerm = await paymentTermManager.readLocal(id);
        return paymentTerm?.name;

      default:
        logger.w(_tag, 'Unknown table for name lookup: $table');
        return null;
    }
  }

  /// Merge local defaults with Odoo defaults
  ///
  /// Odoo values take priority for fields that are set
  OrderDefaults _mergeDefaults(
    OrderDefaults local,
    Map<String, dynamic> odoo,
  ) {
    int? partnerId = local.partnerId;
    String? partnerName = local.partnerName;

    // Extract partner from Odoo
    if (odoo['partner_id'] != null) {
      if (odoo['partner_id'] is List && (odoo['partner_id'] as List).isNotEmpty) {
        partnerId = (odoo['partner_id'] as List)[0] as int?;
        if ((odoo['partner_id'] as List).length > 1) {
          partnerName = (odoo['partner_id'] as List)[1] as String?;
        }
      } else if (odoo['partner_id'] is int) {
        partnerId = odoo['partner_id'] as int;
      }
    }

    // Extract warehouse
    int? warehouseId = local.warehouseId;
    if (odoo['warehouse_id'] != null) {
      if (odoo['warehouse_id'] is List && (odoo['warehouse_id'] as List).isNotEmpty) {
        warehouseId = (odoo['warehouse_id'] as List)[0] as int?;
      } else if (odoo['warehouse_id'] is int) {
        warehouseId = odoo['warehouse_id'] as int;
      }
    }

    // Extract pricelist
    int? pricelistId = local.pricelistId;
    if (odoo['pricelist_id'] != null) {
      if (odoo['pricelist_id'] is List && (odoo['pricelist_id'] as List).isNotEmpty) {
        pricelistId = (odoo['pricelist_id'] as List)[0] as int?;
      } else if (odoo['pricelist_id'] is int) {
        pricelistId = odoo['pricelist_id'] as int;
      }
    }

    // Extract payment term
    int? paymentTermId = local.paymentTermId;
    if (odoo['payment_term_id'] != null) {
      if (odoo['payment_term_id'] is List && (odoo['payment_term_id'] as List).isNotEmpty) {
        paymentTermId = (odoo['payment_term_id'] as List)[0] as int?;
      } else if (odoo['payment_term_id'] is int) {
        paymentTermId = odoo['payment_term_id'] as int;
      }
    }

    return OrderDefaults(
      partnerId: partnerId ?? local.partnerId,
      partnerName: partnerName ?? local.partnerName,
      warehouseId: warehouseId ?? local.warehouseId,
      warehouseName: local.warehouseName, // Keep local name for now
      pricelistId: pricelistId ?? local.pricelistId,
      pricelistName: local.pricelistName,
      paymentTermId: paymentTermId ?? local.paymentTermId,
      paymentTermName: local.paymentTermName,
      userId: local.userId,
      userName: local.userName,
      companyId: local.companyId,
    );
  }

  /// Fallback when no company is available
  Future<OrderDefaults> _getConsumidorFinalFallback() async {
    final consumidorFinal = await partner_utils.findConsumidorFinal(
      appDb: _db,
      logTag: _tag,
    );

    if (consumidorFinal != null) {
      return OrderDefaults(
        partnerId: consumidorFinal.$1,
        partnerName: consumidorFinal.$2,
      );
    }

    return OrderDefaults.empty;
  }
}

// Provider definitions moved to providers/service_providers.dart
