import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import 'model_record_handler.dart';

/// Servicio para resolver y traer registros relacionados faltantes desde Odoo.
///
/// Cuando se cargan órdenes de venta o líneas, verifica si los registros
/// relacionados (productos, clientes, impuestos, etc.) existen localmente.
/// Si no existen, los trae automáticamente desde Odoo.
///
/// Esto permite que la app funcione correctamente en modo offline-first,
/// asegurando que los datos necesarios para editar y calcular estén disponibles.
///
/// ## Uso con Registry
///
/// El resolver puede usar un [ModelRecordHandlerRegistry] para delegar
/// el fetch/upsert a handlers específicos de cada modelo:
///
/// ```dart
/// final registry = ModelRecordHandlerRegistry()
///   ..register(ProductRecordHandler())
///   ..register(PartnerRecordHandler());
///
/// final resolver = RelatedRecordResolver(
///   odooClient: client,
///   handlerRegistry: registry,
/// );
/// ```
class RelatedRecordResolver {
  final OdooClient? odooClient;
  final AppDatabase db;
  final ModelRecordHandlerRegistry? handlerRegistry;

  RelatedRecordResolver({
    this.odooClient,
    required this.db,
    this.handlerRegistry,
  });

  /// Check if we're online and can fetch from Odoo
  bool get isOnline => odooClient != null;

  // ============ Generic Handler Methods ============

  /// Fetch and upsert records using the handler registry
  Future<void> _fetchAndUpsertViaHandler(String model, List<int> ids) async {
    final handler = handlerRegistry?.getHandler(model);
    final client = odooClient;
    if (handler != null && client != null) {
      final records = await handler.fetch(client, ids);
      for (final record in records) {
        await handler.upsert(db, record);
      }
      logger.d(
        '[RelatedRecordResolver] ✅ Fetched ${records.length} $model records via handler',
      );
      return;
    }
    throw StateError(
      '[RelatedRecordResolver] No registered handler for model: $model',
    );
  }

  // ============ Main Resolution Methods ============

  /// Verifica y trae registros faltantes para una orden de venta
  ///
  /// Revisa: partner_id, pricelist_id, payment_term_id, user_id, warehouse_id, team_id, fiscal_position_id
  Future<void> resolveForOrder(SaleOrderData order) async {
    if (!isOnline) return;

    final missingIds = <String, List<int>>{};

    // Partner
    if (order.partnerId != null) {
      final exists = await _partnerExists(order.partnerId!);
      if (!exists) {
        missingIds['res.partner'] = [
          ...(missingIds['res.partner'] ?? []),
          order.partnerId!,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Partner ${order.partnerId} not found locally',
        );
      }
    }

    // Pricelist
    if (order.pricelistId != null) {
      final exists = await _pricelistExists(order.pricelistId!);
      if (!exists) {
        missingIds['product.pricelist'] = [
          ...(missingIds['product.pricelist'] ?? []),
          order.pricelistId!,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Pricelist ${order.pricelistId} not found locally',
        );
      }
    }

    // Payment term
    if (order.paymentTermId != null) {
      final exists = await _paymentTermExists(order.paymentTermId!);
      if (!exists) {
        missingIds['account.payment.term'] = [
          ...(missingIds['account.payment.term'] ?? []),
          order.paymentTermId!,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Payment term ${order.paymentTermId} not found locally',
        );
      }
    }

    // User (salesperson)
    if (order.userId != null) {
      final exists = await _userExists(order.userId!);
      if (!exists) {
        missingIds['res.users'] = [
          ...(missingIds['res.users'] ?? []),
          order.userId!,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 User ${order.userId} not found locally',
        );
      }
    }

    // Warehouse
    if (order.warehouseId != null) {
      final exists = await _warehouseExists(order.warehouseId!);
      if (!exists) {
        missingIds['stock.warehouse'] = [
          ...(missingIds['stock.warehouse'] ?? []),
          order.warehouseId!,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Warehouse ${order.warehouseId} not found locally',
        );
      }
    }

    // Team
    if (order.teamId != null) {
      final exists = await _teamExists(order.teamId!);
      if (!exists) {
        missingIds['crm.team'] = [
          ...(missingIds['crm.team'] ?? []),
          order.teamId!,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Team ${order.teamId} not found locally',
        );
      }
    }

    // Fiscal Position
    if (order.fiscalPositionId != null) {
      final exists = await _fiscalPositionExists(order.fiscalPositionId!);
      if (!exists) {
        missingIds['account.fiscal.position'] = [
          ...(missingIds['account.fiscal.position'] ?? []),
          order.fiscalPositionId!,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Fiscal Position ${order.fiscalPositionId} not found locally',
        );
      }
    }

    // Fetch missing records
    await _fetchMissingRecords(missingIds);
  }

  /// Verifica y trae registros faltantes para líneas de orden de venta
  ///
  /// Revisa: product_id, tax_ids, product_uom_id
  Future<void> resolveForLines(List<SaleOrderLineData> lines) async {
    if (!isOnline) return;

    final missingProducts = <int>{};
    final missingTaxes = <int>{};
    final missingUoms = <int>{};

    for (final line in lines) {
      // Product
      if (line.productId != null) {
        final exists = await _productExists(line.productId!);
        if (!exists) {
          missingProducts.add(line.productId!);
        }
      }

      // Taxes (stored as comma-separated string like "1,2,3")
      if (line.taxIds != null && line.taxIds!.isNotEmpty) {
        final taxIdList = TaxCalculatorService.parseTaxIds(line.taxIds!);
        for (final taxId in taxIdList) {
          final exists = await _taxExists(taxId);
          if (!exists) {
            missingTaxes.add(taxId);
          }
        }
      }

      // UoM
      if (line.productUomId != null) {
        final exists = await _uomExists(line.productUomId!);
        if (!exists) {
          missingUoms.add(line.productUomId!);
        }
      }
    }

    // Log what's missing
    if (missingProducts.isNotEmpty) {
      logger.d('[RelatedRecordResolver] 🔍 Missing products: $missingProducts');
    }
    if (missingTaxes.isNotEmpty) {
      logger.d('[RelatedRecordResolver] 🔍 Missing taxes: $missingTaxes');
    }
    if (missingUoms.isNotEmpty) {
      logger.d('[RelatedRecordResolver] 🔍 Missing UoMs: $missingUoms');
    }

    // Fetch missing records in batch
    final missingIds = <String, List<int>>{};
    if (missingProducts.isNotEmpty) {
      missingIds['product.product'] = missingProducts.toList();
    }
    if (missingTaxes.isNotEmpty) {
      missingIds['account.tax'] = missingTaxes.toList();
    }
    if (missingUoms.isNotEmpty) {
      missingIds['uom.uom'] = missingUoms.toList();
    }

    await _fetchMissingRecords(missingIds);
  }

  /// Resolve related records for multiple orders in batch
  Future<void> resolveForOrders(List<SaleOrderData> orders) async {
    if (!isOnline || orders.isEmpty) return;

    final missingPartners = <int>{};
    final missingPricelists = <int>{};
    final missingPaymentTerms = <int>{};
    final missingUsers = <int>{};
    final missingWarehouses = <int>{};
    final missingTeams = <int>{};
    final missingFiscalPositions = <int>{};

    for (final order in orders) {
      if (order.partnerId != null) {
        final exists = await _partnerExists(order.partnerId!);
        if (!exists) missingPartners.add(order.partnerId!);
      }
      if (order.pricelistId != null) {
        final exists = await _pricelistExists(order.pricelistId!);
        if (!exists) missingPricelists.add(order.pricelistId!);
      }
      if (order.paymentTermId != null) {
        final exists = await _paymentTermExists(order.paymentTermId!);
        if (!exists) missingPaymentTerms.add(order.paymentTermId!);
      }
      if (order.userId != null) {
        final exists = await _userExists(order.userId!);
        if (!exists) missingUsers.add(order.userId!);
      }
      if (order.warehouseId != null) {
        final exists = await _warehouseExists(order.warehouseId!);
        if (!exists) missingWarehouses.add(order.warehouseId!);
      }
      if (order.teamId != null) {
        final exists = await _teamExists(order.teamId!);
        if (!exists) missingTeams.add(order.teamId!);
      }
      if (order.fiscalPositionId != null) {
        final exists = await _fiscalPositionExists(order.fiscalPositionId!);
        if (!exists) missingFiscalPositions.add(order.fiscalPositionId!);
      }
    }

    final missingIds = <String, List<int>>{};
    if (missingPartners.isNotEmpty) {
      missingIds['res.partner'] = missingPartners.toList();
    }
    if (missingPricelists.isNotEmpty) {
      missingIds['product.pricelist'] = missingPricelists.toList();
    }
    if (missingPaymentTerms.isNotEmpty) {
      missingIds['account.payment.term'] = missingPaymentTerms.toList();
    }
    if (missingUsers.isNotEmpty) {
      missingIds['res.users'] = missingUsers.toList();
    }
    if (missingWarehouses.isNotEmpty) {
      missingIds['stock.warehouse'] = missingWarehouses.toList();
    }
    if (missingTeams.isNotEmpty) {
      missingIds['crm.team'] = missingTeams.toList();
    }
    if (missingFiscalPositions.isNotEmpty) {
      missingIds['account.fiscal.position'] = missingFiscalPositions.toList();
    }

    await _fetchMissingRecords(missingIds);
  }

  // ============ Existence Check Methods (Fast SQLite queries) ============

  Future<bool> _productExists(int id) async {
    final result = await (db.select(
      db.productProduct,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _partnerExists(int id) async {
    final result = await (db.select(
      db.resPartner,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _taxExists(int id) async {
    final result = await (db.select(
      db.accountTax,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _uomExists(int id) async {
    final result = await (db.select(
      db.uomUom,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _pricelistExists(int id) async {
    final result = await (db.select(
      db.productPricelist,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _paymentTermExists(int id) async {
    final result = await (db.select(
      db.accountPaymentTerm,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _userExists(int id) async {
    final result = await (db.select(
      db.resUsers,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _warehouseExists(int id) async {
    final result = await (db.select(
      db.stockWarehouse,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _teamExists(int id) async {
    final result = await (db.select(
      db.crmTeam,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _fiscalPositionExists(int id) async {
    final result = await (db.select(
      db.accountFiscalPosition,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  // ============ Registry-backed fetch ============

  /// Fetches every missing model through its registered, typed handler.
  ///
  /// A missing handler is a configuration error and is intentionally allowed
  /// to propagate instead of switching to a second persistence implementation.
  Future<void> _fetchMissingRecords(
    Map<String, List<int>> missingByModel,
  ) async {
    for (final entry in missingByModel.entries) {
      final ids = entry.value;
      if (ids.isEmpty) continue;

      logger.d(
        '[RelatedRecordResolver] Fetching ${ids.length} missing '
        '${entry.key} records: $ids',
      );
      await _fetchAndUpsertViaHandler(entry.key, ids);
    }
  }

  // ============ Alternative Methods for Models ============

  /// Resolve related records for a sale order (using model IDs directly)
  ///
  /// Use this method when you have the order model with IDs already extracted
  Future<void> resolveForOrderIds({
    int? partnerId,
    int? pricelistId,
    int? paymentTermId,
    int? warehouseId,
    int? userId,
    int? teamId,
    int? fiscalPositionId,
  }) async {
    if (!isOnline) return;

    final missingIds = <String, List<int>>{};

    if (partnerId != null) {
      final exists = await _partnerExists(partnerId);
      if (!exists) {
        missingIds['res.partner'] = [
          ...(missingIds['res.partner'] ?? []),
          partnerId,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Partner $partnerId not found locally',
        );
      }
    }

    if (pricelistId != null) {
      final exists = await _pricelistExists(pricelistId);
      if (!exists) {
        missingIds['product.pricelist'] = [
          ...(missingIds['product.pricelist'] ?? []),
          pricelistId,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Pricelist $pricelistId not found locally',
        );
      }
    }

    if (paymentTermId != null) {
      final exists = await _paymentTermExists(paymentTermId);
      if (!exists) {
        missingIds['account.payment.term'] = [
          ...(missingIds['account.payment.term'] ?? []),
          paymentTermId,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Payment term $paymentTermId not found locally',
        );
      }
    }

    if (warehouseId != null) {
      final exists = await _warehouseExists(warehouseId);
      if (!exists) {
        missingIds['stock.warehouse'] = [
          ...(missingIds['stock.warehouse'] ?? []),
          warehouseId,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Warehouse $warehouseId not found locally',
        );
      }
    }

    if (userId != null) {
      final exists = await _userExists(userId);
      if (!exists) {
        missingIds['res.users'] = [...(missingIds['res.users'] ?? []), userId];
        logger.d('[RelatedRecordResolver] 🔍 User $userId not found locally');
      }
    }

    if (teamId != null) {
      final exists = await _teamExists(teamId);
      if (!exists) {
        missingIds['crm.team'] = [...(missingIds['crm.team'] ?? []), teamId];
        logger.d('[RelatedRecordResolver] 🔍 Team $teamId not found locally');
      }
    }

    if (fiscalPositionId != null) {
      final exists = await _fiscalPositionExists(fiscalPositionId);
      if (!exists) {
        missingIds['account.fiscal.position'] = [
          ...(missingIds['account.fiscal.position'] ?? []),
          fiscalPositionId,
        ];
        logger.d(
          '[RelatedRecordResolver] 🔍 Fiscal position $fiscalPositionId not found locally',
        );
      }
    }

    await _fetchMissingRecords(missingIds);
  }

  /// Resolve related records for sale order lines (using extracted IDs)
  ///
  /// [productIds] - List of product IDs from lines
  /// [taxIdsStrings] - List of tax ID strings (comma-separated) from lines
  /// [uomIds] - List of UoM IDs from lines
  Future<void> resolveForLineIds({
    required List<int?> productIds,
    required List<String?> taxIdsStrings,
    required List<int?> uomIds,
  }) async {
    if (!isOnline) return;

    final missingProducts = <int>{};
    final missingTaxes = <int>{};
    final missingUoms = <int>{};

    // Check products
    for (final productId in productIds) {
      if (productId != null) {
        final exists = await _productExists(productId);
        if (!exists) {
          missingProducts.add(productId);
        }
      }
    }

    // Check taxes
    for (final taxIdsStr in taxIdsStrings) {
      if (taxIdsStr != null && taxIdsStr.isNotEmpty) {
        final taxIdList = TaxCalculatorService.parseTaxIds(taxIdsStr);
        for (final taxId in taxIdList) {
          final exists = await _taxExists(taxId);
          if (!exists) {
            missingTaxes.add(taxId);
          }
        }
      }
    }

    // Check UoMs
    for (final uomId in uomIds) {
      if (uomId != null) {
        final exists = await _uomExists(uomId);
        if (!exists) {
          missingUoms.add(uomId);
        }
      }
    }

    // Log what's missing
    if (missingProducts.isNotEmpty) {
      logger.d('[RelatedRecordResolver] 🔍 Missing products: $missingProducts');
    }
    if (missingTaxes.isNotEmpty) {
      logger.d('[RelatedRecordResolver] 🔍 Missing taxes: $missingTaxes');
    }
    if (missingUoms.isNotEmpty) {
      logger.d('[RelatedRecordResolver] 🔍 Missing UoMs: $missingUoms');
    }

    // Fetch missing records in batch
    final missingIds = <String, List<int>>{};
    if (missingProducts.isNotEmpty) {
      missingIds['product.product'] = missingProducts.toList();
    }
    if (missingTaxes.isNotEmpty) {
      missingIds['account.tax'] = missingTaxes.toList();
    }
    if (missingUoms.isNotEmpty) {
      missingIds['uom.uom'] = missingUoms.toList();
    }

    await _fetchMissingRecords(missingIds);
  }
}
