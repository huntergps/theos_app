import 'package:drift/drift.dart';

// ignore_for_file: deprecated_member_use_from_same_package
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
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
  final OdooClient? _odooClient;
  final AppDatabase _db;
  final ModelRecordHandlerRegistry? _handlerRegistry;

  RelatedRecordResolver({
    OdooClient? odooClient,
    required AppDatabase db,
    ModelRecordHandlerRegistry? handlerRegistry,
  }) : _odooClient = odooClient,
       _db = db,
       _handlerRegistry = handlerRegistry;

  /// Check if we're online and can fetch from Odoo
  bool get isOnline => _odooClient != null;

  // ============ Generic Handler Methods ============

  /// Fetch and upsert records using the handler registry
  Future<void> _fetchAndUpsertViaHandler(String model, List<int> ids) async {
    final handler = _handlerRegistry?.getHandler(model);
    final client = _odooClient;
    if (handler != null && client != null) {
      final records = await handler.fetch(client, ids);
      for (final record in records) {
        await handler.upsert(_db, record);
      }
      logger.d(
        '[RelatedRecordResolver] ✅ Fetched ${records.length} $model records via handler',
      );
      return;
    }
    // Fallback to legacy methods if no handler registered
    await _fetchAndUpsertLegacy(model, ids);
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
    final result = await (_db.select(
      _db.productProduct,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _partnerExists(int id) async {
    final result = await (_db.select(
      _db.resPartner,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _taxExists(int id) async {
    final result = await (_db.select(
      _db.accountTax,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _uomExists(int id) async {
    final result = await (_db.select(
      _db.uomUom,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _pricelistExists(int id) async {
    final result = await (_db.select(
      _db.productPricelist,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _paymentTermExists(int id) async {
    final result = await (_db.select(
      _db.accountPaymentTerm,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _userExists(int id) async {
    final result = await (_db.select(
      _db.resUsers,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _warehouseExists(int id) async {
    final result = await (_db.select(
      _db.stockWarehouse,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _teamExists(int id) async {
    final result = await (_db.select(
      _db.crmTeam,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  Future<bool> _fiscalPositionExists(int id) async {
    final result = await (_db.select(
      _db.accountFiscalPosition,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    return result != null;
  }

  // ============ Legacy Fallback Methods ============

  /// Legacy fallback for fetch/upsert when no handler is registered
  Future<void> _fetchAndUpsertLegacy(String model, List<int> ids) async {
    switch (model) {
      case 'product.product':
        await _fetchProducts(ids);
        break;
      case 'res.partner':
        await _fetchPartners(ids);
        break;
      case 'account.tax':
        await _fetchTaxes(ids);
        break;
      case 'uom.uom':
        await _fetchUoms(ids);
        break;
      case 'product.pricelist':
        await _fetchPricelists(ids);
        break;
      case 'account.payment.term':
        await _fetchPaymentTerms(ids);
        break;
      case 'res.users':
        await _fetchUsers(ids);
        break;
      case 'stock.warehouse':
        await _fetchWarehouses(ids);
        break;
      case 'crm.team':
        await _fetchTeams(ids);
        break;
      case 'account.fiscal.position':
        await _fetchFiscalPositions(ids);
        break;
      default:
        logger.w('[RelatedRecordResolver] No handler for model: $model');
    }
  }


  // ============ Fetch Methods (from Odoo) ============

  /// Fetch missing records from Odoo and upsert to local DB
  ///
  /// Uses the handler registry if available, otherwise falls back to legacy methods.
  Future<void> _fetchMissingRecords(
    Map<String, List<int>> missingByModel,
  ) async {
    for (final entry in missingByModel.entries) {
      final model = entry.key;
      final ids = entry.value;

      if (ids.isEmpty) continue;

      logger.d(
        '[RelatedRecordResolver] 📥 Fetching ${ids.length} missing $model records: $ids',
      );

      try {
        await _fetchAndUpsertViaHandler(model, ids);
      } catch (e) {
        logger.e('[RelatedRecordResolver] ❌ Error fetching $model: $e');
      }
    }
  }

  Future<void> _fetchProducts(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'product.product',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
        'id',
        'name',
        'display_name',
        'default_code',
        'barcode',
        'type',
        'sale_ok',
        'purchase_ok',
        'active',
        'list_price',
        'standard_price',
        'categ_id',
        'uom_id',
        'taxes_id',
        'supplier_taxes_id',
        'description',
        'description_sale',
        'product_tmpl_id',
        'image_128',
        'qty_available',
        'virtual_available',
        'write_date',
        // Custom module fields (require: l10n_ec_base, product_extended)
        // See Issue 4 comment in product_sync_repository.dart
        'tracking',
        'is_storable',
        'is_unit_product',
        'temporal_no_despachar',
        'l10n_ec_auxiliary_code',
        'uom_ids',
      ],
    );

    for (final p in data) {
      await _upsertProduct(p);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} products');
  }

  Future<void> _fetchPartners(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'res.partner',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
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
      ],
    );

    for (final p in data) {
      await _upsertPartner(p);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} partners');
  }

  Future<void> _fetchTaxes(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'account.tax',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
        'id',
        'name',
        'description',
        'type_tax_use',
        'amount_type',
        'amount',
        'active',
        'price_include',
        'include_base_amount',
        'sequence',
        'company_id',
        'tax_group_id',
        'write_date',
      ],
    );

    for (final t in data) {
      await _upsertTax(t);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} taxes');
  }

  Future<void> _fetchUoms(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'uom.uom',
      domain: [
        ['id', 'in', ids],
      ],
      fields: ['id', 'name', 'factor', 'active', 'write_date'],
    );

    for (final u in data) {
      await _upsertUom(u);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} UoMs');
  }

  Future<void> _fetchPricelists(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'product.pricelist',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
        'id',
        'name',
        'active',
        'currency_id',
        'company_id',
        'sequence',
        'write_date',
      ],
    );

    for (final pl in data) {
      await _upsertPricelist(pl);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} pricelists');
  }

  Future<void> _fetchPaymentTerms(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'account.payment.term',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
        'id',
        'name',
        'active',
        'note',
        'company_id',
        'sequence',
        'write_date',
      ],
    );

    for (final pt in data) {
      await _upsertPaymentTerm(pt);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} payment terms');
  }

  Future<void> _fetchUsers(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'res.users',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
        'id',
        'name',
        'login',
        'email',
        'lang',
        'tz',
        'signature',
        'partner_id',
        'company_id',
        'notification_type',
        'write_date',
      ],
    );

    for (final u in data) {
      await _upsertUser(u);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} users');
  }

  Future<void> _fetchWarehouses(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'stock.warehouse',
      domain: [
        ['id', 'in', ids],
      ],
      fields: ['id', 'name', 'code', 'write_date'],
    );

    for (final w in data) {
      await _upsertWarehouse(w);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} warehouses');
  }

  Future<void> _fetchTeams(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'crm.team',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
        'id',
        'name',
        'active',
        'company_id',
        'user_id',
        'sequence',
        'write_date',
      ],
    );

    for (final t in data) {
      await _upsertTeam(t);
    }

    logger.d('[RelatedRecordResolver] ✅ Fetched ${data.length} teams');
  }

  Future<void> _fetchFiscalPositions(List<int> ids) async {
    final data = await _odooClient!.searchRead(
      model: 'account.fiscal.position',
      domain: [
        ['id', 'in', ids],
      ],
      fields: [
        'id',
        'name',
        'active',
        'company_id',
        'sequence',
        'note',
        'auto_apply',
        'country_id',
        'write_date',
      ],
    );

    for (final fp in data) {
      await _upsertFiscalPosition(fp);
    }

    logger.d(
      '[RelatedRecordResolver] ✅ Fetched ${data.length} fiscal positions',
    );
  }

  // ============ Upsert Methods (save to SQLite) ============

  Future<void> _upsertProduct(Map<String, dynamic> p) async {
    final odooId = p['id'] as int;

    final existing = await (_db.select(
      _db.productProduct,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

    final companion = ProductProductCompanion(
      odooId: Value(odooId),
      name: Value(p['name'] as String? ?? ''),
      displayName: Value(p['display_name'] as String?),
      defaultCode: Value(
        p['default_code'] is String ? p['default_code'] : null,
      ),
      barcode: Value(p['barcode'] is String ? p['barcode'] : null),
      type: Value(p['type'] as String? ?? 'consu'),
      saleOk: Value(p['sale_ok'] as bool? ?? true),
      purchaseOk: Value(p['purchase_ok'] as bool? ?? true),
      active: Value(p['active'] as bool? ?? true),
      listPrice: Value((p['list_price'] as num?)?.toDouble() ?? 0.0),
      standardPrice: Value((p['standard_price'] as num?)?.toDouble() ?? 0.0),
      categId: Value(_extractId(p['categ_id'])),
      categName: Value(_extractName(p['categ_id'])),
      uomId: Value(_extractId(p['uom_id'])),
      uomName: Value(_extractName(p['uom_id'])),
      taxesId: Value(_encodeIntList(p['taxes_id'])),
      supplierTaxesId: Value(_encodeIntList(p['supplier_taxes_id'])),
      description: Value(p['description'] is String ? p['description'] : null),
      descriptionSale: Value(
        p['description_sale'] is String ? p['description_sale'] : null,
      ),
      productTmplId: Value(_extractId(p['product_tmpl_id'])),
      image128: Value(p['image_128'] is String ? p['image_128'] : null),
      qtyAvailable: Value((p['qty_available'] as num?)?.toDouble() ?? 0.0),
      virtualAvailable: Value(
        (p['virtual_available'] as num?)?.toDouble() ?? 0.0,
      ),
      writeDate: Value(_parseDateTime(p['write_date'])),
      // Custom module fields
      tracking: Value(p['tracking'] is String ? p['tracking'] as String : null),
      isStorable: Value(p['is_storable'] as bool? ?? true),
      isUnitProduct: Value(p['is_unit_product'] as bool? ?? false),
      temporalNoDespachar: Value(p['temporal_no_despachar'] as bool? ?? false),
      l10nEcAuxiliaryCode: Value(
        p['l10n_ec_auxiliary_code'] is String ? p['l10n_ec_auxiliary_code'] as String : null,
      ),
      uomIds: Value(_encodeIntList(p['uom_ids'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.productProduct,
      )..where((t) => t.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.productProduct).insert(companion);
    }
  }

  Future<void> _upsertPartner(Map<String, dynamic> p) async {
    final odooId = p['id'] as int;

    final existing = await (_db.select(
      _db.resPartner,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

    // Get commercial partner name if different from current
    String? commercialPartnerName;
    final commercialPartnerId = _extractId(p['commercial_partner_id']);
    if (commercialPartnerId != null && commercialPartnerId != odooId) {
      commercialPartnerName = _extractName(p['commercial_partner_id']);
    }

    final companion = ResPartnerCompanion(
      odooId: Value(odooId),
      name: Value(p['name'] as String? ?? ''),
      displayName: Value(p['display_name'] as String?),
      ref: Value(p['ref'] is String ? p['ref'] : null),
      vat: Value(p['vat'] is String ? p['vat'] : null),
      email: Value(p['email'] is String ? p['email'] : null),
      phone: Value(p['phone'] is String ? p['phone'] : null),
      street: Value(p['street'] is String ? p['street'] : null),
      street2: Value(p['street2'] is String ? p['street2'] : null),
      city: Value(p['city'] is String ? p['city'] : null),
      zip: Value(p['zip'] is String ? p['zip'] : null),
      countryId: Value(_extractId(p['country_id'])),
      countryName: Value(_extractName(p['country_id'])),
      stateId: Value(_extractId(p['state_id'])),
      stateName: Value(_extractName(p['state_id'])),
      avatar128: Value(p['avatar_128'] is String ? p['avatar_128'] : null),
      isCompany: Value(p['is_company'] as bool? ?? false),
      active: Value(p['active'] as bool? ?? true),
      parentId: Value(_extractId(p['parent_id'])),
      parentName: Value(_extractName(p['parent_id'])),
      commercialPartnerName: Value(commercialPartnerName),
      propertyProductPricelist: Value(
        _extractId(p['property_product_pricelist']),
      ),
      propertyProductPricelistName: Value(
        _extractName(p['property_product_pricelist']),
      ),
      propertyPaymentTermId: Value(_extractId(p['property_payment_term_id'])),
      propertyPaymentTermName: Value(
        _extractName(p['property_payment_term_id']),
      ),
      lang: Value(p['lang'] is String ? p['lang'] : null),
      comment: Value(p['comment'] is String ? p['comment'] : null),
      writeDate: Value(_parseDateTime(p['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.resPartner,
      )..where((t) => t.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.resPartner).insert(companion);
    }
  }

  Future<void> _upsertTax(Map<String, dynamic> t) async {
    final odooId = t['id'] as int;

    final existing = await (_db.select(
      _db.accountTax,
    )..where((tbl) => tbl.odooId.equals(odooId))).getSingleOrNull();

    final companion = AccountTaxCompanion(
      odooId: Value(odooId),
      name: Value(t['name'] as String? ?? ''),
      description: Value(t['description'] is String ? t['description'] : null),
      typeTaxUse: Value(t['type_tax_use'] as String? ?? 'sale'),
      amountType: Value(t['amount_type'] as String? ?? 'percent'),
      amount: Value((t['amount'] as num?)?.toDouble() ?? 0.0),
      active: Value(t['active'] as bool? ?? true),
      priceInclude: Value(t['price_include'] as bool? ?? false),
      includeBaseAmount: Value(t['include_base_amount'] as bool? ?? false),
      sequence: Value(t['sequence'] as int? ?? 1),
      companyId: Value(_extractId(t['company_id'])),
      companyName: Value(_extractName(t['company_id'])),
      taxGroupId: Value(_extractId(t['tax_group_id'])),
      taxGroupIdName: Value(_extractName(t['tax_group_id'])),
      // Note: tax_group_l10n_ec_type is NOT fetched (not a direct field on account.tax),
      // so we don't set it here. It's populated during full sync via tax_group relation.
      writeDate: Value(_parseDateTime(t['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.accountTax,
      )..where((tbl) => tbl.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.accountTax).insert(companion);
    }
  }

  Future<void> _upsertUom(Map<String, dynamic> u) async {
    final odooId = u['id'] as int;

    final existing = await (_db.select(
      _db.uomUom,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

    final companion = UomUomCompanion(
      odooId: Value(odooId),
      name: Value(u['name'] as String? ?? ''),
      categoryId: Value(1), // Default category (not available in Odoo 19.2)
      uomType: Value('reference'), // Default type (not available in Odoo 19.2)
      factor: Value((u['factor'] as num?)?.toDouble() ?? 1.0),
      rounding: Value(0.01), // Default rounding (not available in Odoo 19.2)
      active: Value(u['active'] as bool? ?? true),
      writeDate: Value(_parseDateTime(u['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.uomUom,
      )..where((t) => t.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.uomUom).insert(companion);
    }
  }

  Future<void> _upsertPricelist(Map<String, dynamic> pl) async {
    final odooId = pl['id'] as int;

    final existing = await (_db.select(
      _db.productPricelist,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

    final companion = ProductPricelistCompanion(
      odooId: Value(odooId),
      name: Value(pl['name'] as String? ?? ''),
      active: Value(pl['active'] as bool? ?? true),
      currencyId: Value(_extractId(pl['currency_id'])),
      currencyName: Value(_extractName(pl['currency_id'])),
      companyId: Value(_extractId(pl['company_id'])),
      companyName: Value(_extractName(pl['company_id'])),
      sequence: Value(pl['sequence'] as int? ?? 16),
      writeDate: Value(_parseDateTime(pl['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.productPricelist,
      )..where((t) => t.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.productPricelist).insert(companion);
    }
  }

  Future<void> _upsertPaymentTerm(Map<String, dynamic> pt) async {
    final odooId = pt['id'] as int;

    final existing = await (_db.select(
      _db.accountPaymentTerm,
    )..where((tbl) => tbl.odooId.equals(odooId))).getSingleOrNull();

    final companion = AccountPaymentTermCompanion(
      odooId: Value(odooId),
      name: Value(pt['name'] as String? ?? ''),
      active: Value(pt['active'] as bool? ?? true),
      note: Value(pt['note'] is String ? pt['note'] : null),
      companyId: Value(_extractId(pt['company_id'])),
      sequence: Value(pt['sequence'] as int? ?? 10),
      writeDate: Value(_parseDateTime(pt['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.accountPaymentTerm,
      )..where((tbl) => tbl.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.accountPaymentTerm).insert(companion);
    }
  }

  Future<void> _upsertUser(Map<String, dynamic> u) async {
    final odooId = u['id'] as int;

    final existing = await (_db.select(
      _db.resUsers,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

    final companion = ResUsersCompanion(
      odooId: Value(odooId),
      name: Value(u['name'] as String? ?? ''),
      login: Value(u['login'] as String? ?? ''),
      email: Value(u['email'] is String ? u['email'] : null),
      lang: Value(u['lang'] is String ? u['lang'] : null),
      tz: Value(u['tz'] is String ? u['tz'] : null),
      signature: Value(u['signature'] is String ? u['signature'] : null),
      partnerId: Value(_extractId(u['partner_id'])),
      partnerName: Value(_extractName(u['partner_id'])),
      companyId: Value(_extractId(u['company_id'])),
      companyName: Value(_extractName(u['company_id'])),
      notificationType: Value(
        u['notification_type'] is String ? u['notification_type'] : null,
      ),
      writeDate: Value(_parseDateTime(u['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.resUsers,
      )..where((t) => t.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.resUsers).insert(companion);
    }
  }

  Future<void> _upsertWarehouse(Map<String, dynamic> w) async {
    final odooId = w['id'] as int;

    final existing = await (_db.select(
      _db.stockWarehouse,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

    final companion = StockWarehouseCompanion(
      odooId: Value(odooId),
      name: Value(w['name'] as String? ?? ''),
      code: Value(w['code'] is String ? w['code'] : null),
      writeDate: Value(_parseDateTime(w['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.stockWarehouse,
      )..where((t) => t.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.stockWarehouse).insert(companion);
    }
  }

  Future<void> _upsertTeam(Map<String, dynamic> t) async {
    final odooId = t['id'] as int;

    final existing = await (_db.select(
      _db.crmTeam,
    )..where((tbl) => tbl.odooId.equals(odooId))).getSingleOrNull();

    final companion = CrmTeamCompanion(
      odooId: Value(odooId),
      name: Value(t['name'] as String? ?? ''),
      active: Value(t['active'] as bool? ?? true),
      companyId: Value(_extractId(t['company_id'])),
      companyName: Value(_extractName(t['company_id'])),
      userId: Value(_extractId(t['user_id'])),
      userName: Value(_extractName(t['user_id'])),
      sequence: Value(t['sequence'] as int? ?? 10),
      writeDate: Value(_parseDateTime(t['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.crmTeam,
      )..where((tbl) => tbl.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.crmTeam).insert(companion);
    }
  }

  Future<void> _upsertFiscalPosition(Map<String, dynamic> fp) async {
    final odooId = fp['id'] as int;

    final existing = await (_db.select(
      _db.accountFiscalPosition,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

    final companion = AccountFiscalPositionCompanion(
      odooId: Value(odooId),
      name: Value(fp['name'] as String? ?? ''),
      active: Value(fp['active'] as bool? ?? true),
      companyId: Value(_extractId(fp['company_id'])),
      companyName: Value(_extractName(fp['company_id'])),
      sequence: Value(fp['sequence'] as int? ?? 10),
      note: Value(fp['note'] is String ? fp['note'] : null),
      autoApply: Value(fp['auto_apply'] as bool? ?? false),
      countryId: Value(_extractId(fp['country_id'])),
      countryName: Value(_extractName(fp['country_id'])),
      writeDate: Value(_parseDateTime(fp['write_date'])),
    );

    if (existing != null) {
      await (_db.update(
        _db.accountFiscalPosition,
      )..where((t) => t.odooId.equals(odooId))).write(companion);
    } else {
      await _db.into(_db.accountFiscalPosition).insert(companion);
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

  // ============ Helper Methods ============

  // Delegate to package utilities
  int? _extractId(dynamic value) => odoo.extractMany2oneId(value);
  String? _extractName(dynamic value) => odoo.extractMany2oneName(value) ??
      (value is String ? value : odoo.toStringOrNull(value));
  String? _encodeIntList(dynamic value) => odoo.extractMany2manyToJson(value);
  DateTime? _parseDateTime(dynamic value) => odoo.parseOdooDateTime(value);
}
