part of 'sales_repository.dart';

/// Read operations: fetching orders by ID, enriching with local/remote data,
/// getting orders with lines, searching, and retrieving default values.
extension SalesRepositoryReads on SalesRepository {
  /// Get order by ID
  ///
  /// Offline-first strategy:
  /// 1. Always try to get from local cache first
  /// 2. Enrich with partner data from local res_partner table
  /// 3. If forceRefresh or not in cache and online, fetch from Odoo
  Future<SaleOrder?> getById(int orderId, {bool forceRefresh = false}) async {
    SaleOrder? order;

    // OFFLINE-FIRST: Always try local cache first
    order = await _orderManager.getSaleOrder(orderId);

    // If we have local data and not forcing refresh, return immediately
    // This avoids blocking on slow/unavailable Odoo server
    if (order != null && !forceRefresh) {
      logger.d(
        '[SalesRepository]',
        'Order $orderId found locally (offline-first)',
      );
      // Only enrich with local data, never call Odoo here
      order = await _enrichOrderWithLocalDataOnly(order);
      return order;
    }

    // If offline or no Odoo client, return local data (may be null)
    if (_odooClient == null) {
      if (order != null) {
        order = await _enrichOrderWithLocalDataOnly(order);
      }
      return order;
    }

    // forceRefresh requested OR no local data - fetch from Odoo
    try {
      final response = await _odooClient.searchRead(
        model: 'sale.order',
        fields: saleOrderManager.odooFields,
        domain: [
          ['id', '=', orderId],
        ],
        limit: 1,
      );

      if (response.isNotEmpty) {
        order = saleOrderManager.fromOdoo(response.first);
        await _orderManager.upsertLocal(order);

        // Enrich with related data (may fetch from Odoo and cache)
        order = await _enrichOrderWithRelatedData(order);

        // Save enriched order with partner details to local DB
        // This ensures partnerVat/Street/Phone/Email are persisted
        await _orderManager.upsertLocal(order);

        return order;
      }

      // Order not found in Odoo - check if we have a local record
      final localOrder = await _orderManager.getSaleOrder(orderId);
      if (localOrder != null) {
        // If it's an offline order (negative ID or not synced), return local data
        if (localOrder.id < 0 || localOrder.isSynced == false) {
          logger.d(
            '[SalesRepository]',
            'Order $orderId not in Odoo but is local/offline - returning local data',
          );
          return await _enrichOrderWithLocalDataOnly(localOrder);
        }

        // Synced order that no longer exists in Odoo - clean up
        logger.w(
          '[SalesRepository]',
          'Order $orderId exists locally but not in Odoo - deleting local record',
        );
        await _deleteOrderAndChildren(orderId);
      }
      return null;
    } catch (e) {
      logger.e('[SalesRepository]', 'Error getting order from Odoo: $e');
      // Fallback to local
      order = await _orderManager.getSaleOrder(orderId);
      if (order != null) {
        order = await _enrichOrderWithLocalDataOnly(order);
      }
      return order;
    }
  }

  /// Enrich order with LOCAL data only - never calls Odoo
  ///
  /// Used for offline-first reads to avoid blocking on slow/unavailable server.
  /// Only looks up missing data in local database tables.
  Future<SaleOrder> _enrichOrderWithLocalDataOnly(SaleOrder order) async {
    var enrichedOrder = order;

    // Enrich partner from local DB only if FULL details missing
    // partnerName alone is not enough - we need vat/phone/email/avatar too
    final hasFullPartnerDetails =
        order.partnerName != null &&
        order.partnerAvatar != null &&
        (order.partnerVat != null ||
            order.partnerPhone != null ||
            order.partnerEmail != null);
    if (order.partnerId != null && !hasFullPartnerDetails) {
      try {
        final partner = await clientManager.getPartner(order.partnerId!);
        if (partner != null) {
          enrichedOrder = enrichedOrder.copyWith(
            partnerName: partner.name,
            partnerVat: partner.vat,
            partnerStreet: partner.street,
            partnerPhone: partner.phone,
            partnerEmail: partner.email,
            partnerAvatar: partner.avatar128,
          );
        }
      } catch (e) {
        logger.w('[SalesRepository]', 'Error getting local partner: $e');
      }
    }

    // Enrich warehouse from local DB only if name missing
    if (order.warehouseId != null && order.warehouseName == null) {
      try {
        final warehouse = await warehouseManager.readLocal(order.warehouseId!);
        if (warehouse != null) {
          enrichedOrder = enrichedOrder.copyWith(warehouseName: warehouse.name);
        }
      } catch (e) {
        logger.w('[SalesRepository]', 'Error getting local warehouse: $e');
      }
    }

    // Enrich user from local DB only if name missing
    if (order.userId != null && order.userName == null) {
      try {
        final user = await userManager.getUser(order.userId!);
        if (user != null) {
          enrichedOrder = enrichedOrder.copyWith(userName: user.name);
        }
      } catch (e) {
        logger.w('[SalesRepository]', 'Error getting local user: $e');
      }
    }

    return enrichedOrder;
  }

  /// Enrich order with all related data using [RelatedRecordResolver]
  ///
  /// Delegates to the resolver which handles the offline-first pattern:
  /// 1. Check local table for the record
  /// 2. If not found and online, fetch from Odoo and cache
  /// 3. Return enriched order with names populated
  ///
  /// This ensures each model manages its own data lifecycle.
  Future<SaleOrder> _enrichOrderWithRelatedData(SaleOrder order) async {
    // Use RelatedRecordResolver to fetch any missing related records
    // This ensures records are cached in their proper tables
    if (_relatedResolver != null) {
      await _relatedResolver.resolveForOrderIds(
        partnerId: order.partnerId,
        pricelistId: order.pricelistId,
        paymentTermId: order.paymentTermId,
        warehouseId: order.warehouseId,
        userId: order.userId,
      );
    }

    // Now enrich from local cache (which was just populated if needed)
    return _enrichOrderWithLocalDataOnly(order);
  }

  /// Get order with its lines
  ///
  /// OFFLINE-FIRST strategy:
  /// 1. Always get lines from local database first
  /// 2. Only sync from Odoo when forceRefresh is explicitly true
  /// 3. This ensures the app never blocks on slow/unavailable Odoo server
  Future<(SaleOrder?, List<SaleOrderLine>)> getWithLines(
    int orderId, {
    bool forceRefresh = false,
  }) async {
    final order = await getById(orderId, forceRefresh: forceRefresh);
    if (order == null) return (null, <SaleOrderLine>[]);

    // First, try to get lines from local cache
    var localLines = await _lineManager.getSaleOrderLines(orderId);
    logger.d(
      '[SalesRepository] Local lines for order $orderId: ${localLines.length}',
    );

    // Enrich local lines with isUnitProduct from product database
    if (localLines.isNotEmpty) {
      final productIds = localLines
          .where((l) => l.productId != null)
          .map((l) => l.productId!)
          .toSet();
      if (productIds.isNotEmpty) {
        try {
          final productIsUnitMap = <int, bool>{};
          for (final pid in productIds) {
            final p = await productManager.readLocal(pid);
            if (p != null) {
              productIsUnitMap[p.id] = p.isUnitProduct;
            }
          }

          // Update lines with isUnitProduct
          localLines = localLines.map((line) {
            if (line.productId != null &&
                productIsUnitMap.containsKey(line.productId)) {
              return line.copyWith(
                isUnitProduct: productIsUnitMap[line.productId]!,
              );
            }
            return line;
          }).toList();
        } catch (e) {
          logger.w(
            '[SalesRepository]',
            'Error enriching local lines with isUnitProduct: $e',
          );
        }
      }
    }

    // OFFLINE-FIRST: Only sync from Odoo when explicitly requested
    // This prevents blocking on slow/unavailable server during normal reads
    // IMPORTANT: Never sync offline orders (negative IDs) - they don't exist in Odoo
    // and syncing would DELETE local lines!
    final shouldSync = _odooClient != null && forceRefresh && orderId > 0;

    if (shouldSync) {
      logger.d(
        '[SalesRepository] Syncing lines from Odoo (forceRefresh=$forceRefresh, localEmpty=${localLines.isEmpty})',
      );
      try {
        final response = await _odooClient.searchRead(
          model: 'sale.order.line',
          fields: saleOrderLineManager.odooFields,
          domain: [
            ['order_id', '=', orderId],
          ],
          order: 'sequence asc',
        );

        // Collect all unique tax IDs from all lines
        final allTaxIds = <int>{};
        for (final lineData in response) {
          final taxIds = lineData['tax_ids'];
          if (taxIds is List) {
            for (final taxId in taxIds) {
              if (taxId is int) {
                allTaxIds.add(taxId);
              }
            }
          }
        }

        // Fetch tax names: try local first, then server
        Map<int, String> taxIdToName = {};
        if (allTaxIds.isNotEmpty) {
          // Try local tax table first
          try {
            final appDb = _db;
            final localTaxes = await (appDb.select(appDb.accountTax)
                  ..where((t) => t.odooId.isIn(allTaxIds.toList())))
                .get();
            for (final tax in localTaxes) {
              taxIdToName[tax.odooId] = tax.name;
            }
          } catch (e) {
            logger.w('[SalesRepository] Could not read local taxes: $e');
          }

          // Fetch missing tax names from server
          final missingTaxIds = allTaxIds.where((id) => !taxIdToName.containsKey(id)).toList();
          if (missingTaxIds.isNotEmpty) {
            try {
              final taxData = await _odooClient.read(
                model: 'account.tax',
                ids: missingTaxIds,
                fields: ['id', 'name'],
              );
              for (final tax in taxData) {
                taxIdToName[tax['id'] as int] = tax['name'] as String? ?? '';
              }
              // Note: Tax names are persisted in the local DB via catalog sync
              // (syncTaxes). The taxNamesCacheProvider reads from the local
              // Drift DB via taxManager.watchLocalSearch(), so names survive
              // app restart. This server fallback only covers the rare case
              // where a tax ID on a line hasn't been synced yet.
              logger.d(
                '[SalesRepository] Loaded ${taxIdToName.length} tax names (${missingTaxIds.length} from server)',
              );
            } catch (e) {
              logger.w('[SalesRepository] Could not fetch tax names from server: $e');
            }
          } else {
            logger.d(
              '[SalesRepository] All ${taxIdToName.length} tax names resolved from local DB',
            );
          }
        }

        // Parse lines and enrich with tax names and isUnitProduct
        final lines = <SaleOrderLine>[];
        // Collect all product IDs to batch lookup isUnitProduct
        final productIds = <int>{};
        for (final lineData in response) {
          final productId = odoo.extractMany2oneId(lineData['product_id']);
          if (productId != null) {
            productIds.add(productId);
          }
        }

        // Batch lookup isUnitProduct via productManager
        final productIsUnitMap = <int, bool>{};
        if (productIds.isNotEmpty) {
          try {
            for (final pid in productIds) {
              final p = await productManager.readLocal(pid);
              if (p != null) {
                productIsUnitMap[p.id] = p.isUnitProduct;
              }
            }
          } catch (e) {
            logger.w(
              '[SalesRepository]',
              'Error looking up isUnitProduct via manager: $e',
            );
          }
        }

        for (final lineData in response) {
          // Build tax names string from tax_ids
          String? taxNamesStr;
          final taxIds = lineData['tax_ids'];
          if (taxIds is List && taxIds.isNotEmpty) {
            final names = <String>[];
            for (final taxId in taxIds) {
              if (taxId is int && taxIdToName.containsKey(taxId)) {
                names.add(taxIdToName[taxId]!);
              }
            }
            if (names.isNotEmpty) {
              taxNamesStr = names.join(', ');
            }
          }

          // Create line from Odoo data
          var line = saleOrderLineManager.fromOdoo(lineData);

          // Enrich with tax names if we have them
          if (taxNamesStr != null) {
            line = line.copyWith(taxNames: taxNamesStr);
          }

          // Enrich with isUnitProduct from local product database
          final productId = line.productId;
          if (productId != null && productIsUnitMap.containsKey(productId)) {
            line = line.copyWith(isUnitProduct: productIsUnitMap[productId]!);
          }

          lines.add(line);
        }

        // Save to local cache
        await _lineManager.deleteByOrderId(orderId);
        await _lineManager.upsertLocalBatch(lines);

        // Return enriched lines
        localLines = lines;

        // Resolve missing related records (only during forceRefresh)
        if (_relatedResolver != null) {
          try {
            // Resolve order-level relations
            await _relatedResolver.resolveForOrderIds(
              partnerId: order.partnerId,
              pricelistId: order.pricelistId,
              paymentTermId: order.paymentTermId,
            );

            // Resolve line-level relations
            await _relatedResolver.resolveForLineIds(
              productIds: lines.map((l) => l.productId).toList(),
              taxIdsStrings: lines.map((l) => l.taxIds).toList(),
              uomIds: lines.map((l) => l.productUomId).toList(),
            );
          } catch (e) {
            logger.w('[SalesRepository] Error resolving related records: $e');
          }
        }

        // Sync withhold lines (Ecuador) during forceRefresh
        await syncWithholdLinesFromOdoo(orderId);

        // Sync payment lines (Ecuador collection box) during forceRefresh
        await syncPaymentLinesFromOdoo(orderId);

        // Sync invoices and their lines during forceRefresh (force=true because user requested refresh)
        await syncInvoicesForOrder(orderId, forceRefresh: true);

        return (order, lines);
      } catch (e) {
        logger.e(
          '[SalesRepository]',
          'Error syncing order lines from Odoo: $e',
        );
        // Fall through to return local lines
      }
    }

    // Return local lines (either already loaded or fallback after sync error)
    logger.d(
      '[SalesRepository] Returning ${localLines.length} local lines for order $orderId',
    );

    // NOTE: RelatedRecordResolver is NOT called here (offline-first)
    // Missing related records will be resolved only when forceRefresh is true
    // This ensures the app never blocks on slow/unavailable Odoo server
    // The UI should handle missing data gracefully (show "-" or IDs)

    return (order, localLines);
  }

  /// Get unsynced orders (created offline)
  Future<List<SaleOrder>> getUnsynced() async {
    return _orderManager.searchLocal(domain: [['is_synced', '=', false]]);
  }

  Future<List<SaleOrder>> search(String query) async {
    // Search locally first
    final allOrders = await _orderManager.getSaleOrders();
    final lowerQuery = query.toLowerCase();
    return allOrders.where((order) {
      return order.name.toLowerCase().contains(lowerQuery) ||
          (order.partnerName?.toLowerCase().contains(lowerQuery) ?? false) ||
          (order.clientOrderRef?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  /// Get default values for a new sale order
  ///
  /// Follows offline-first pattern:
  /// 1. First try to read from company cache (already synced during login)
  /// 2. If online, fetch fresh from Odoo's default_get
  /// 3. Return cached values as fallback
  ///
  /// Returns defaults like:
  /// - partner_id (consumidor final configurado)
  /// - date_order
  /// - warehouse_id
  /// - pricelist_id
  Future<Map<String, dynamic>> getDefaultValues() async {
    // 1. First try to get from company cache (offline-first)
    final cachedDefaults = await _getDefaultsFromCompanyCache();

    // 2. If offline, return cached defaults
    if (_odooClient == null) {
      logger.d('[SalesRepository]', 'Offline - using cached defaults: $cachedDefaults');
      return cachedDefaults;
    }

    // 3. Try to fetch fresh from Odoo
    try {
      final result = await _odooClient.call(
        model: 'sale.order',
        method: 'default_get',
        kwargs: {
          'fields_list': [
            'partner_id',
            'date_order',
            'warehouse_id',
            'pricelist_id',
            'payment_term_id',
            'user_id',
          ],
        },
      );

      if (result is Map<String, dynamic>) {
        logger.d('[SalesRepository]', 'Fresh default values from Odoo: $result');
        return result;
      }

      return cachedDefaults;
    } catch (e) {
      logger.e('[SalesRepository]', 'Error getting default values, using cache: $e');
      return cachedDefaults;
    }
  }

  Future<Map<String, dynamic>> _getDefaultsFromCompanyCache() async {
    try {
      // Get current user's company via datasources
      final currentUser = await userManager.getCurrentUser();
      if (currentUser?.companyId == null) return {};
      final company = await companyManager.readLocal(currentUser!.companyId!);
      if (company == null) return {};

      final defaults = <String, dynamic>{};

      if (company.defaultPartnerId != null) {
        defaults['partner_id'] = company.defaultPartnerName != null
            ? [company.defaultPartnerId, company.defaultPartnerName]
            : company.defaultPartnerId;
      }
      if (company.defaultWarehouseId != null) {
        defaults['warehouse_id'] = company.defaultWarehouseName != null
            ? [company.defaultWarehouseId, company.defaultWarehouseName]
            : company.defaultWarehouseId;
      }
      if (company.defaultPricelistId != null) {
        defaults['pricelist_id'] = company.defaultPricelistName != null
            ? [company.defaultPricelistId, company.defaultPricelistName]
            : company.defaultPricelistId;
      }
      if (company.defaultPaymentTermId != null) {
        defaults['payment_term_id'] = company.defaultPaymentTermName != null
            ? [company.defaultPaymentTermId, company.defaultPaymentTermName]
            : company.defaultPaymentTermId;
      }

      return defaults;
    } catch (e) {
      logger.w('[SalesRepository]', 'Error getting cached defaults: $e');
      return {};
    }
  }
}
