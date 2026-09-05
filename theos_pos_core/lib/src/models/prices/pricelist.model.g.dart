// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pricelist.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Pricelist.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: product.pricelist
class PricelistManager extends OdooModelManager<Pricelist>
    with GenericDriftOperations<Pricelist> {
  @override
  String get odooModel => 'product.pricelist';

  @override
  String get tableName => 'product_pricelist';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'active',
    'currency_id',
    'company_id',
    'sequence',
    'write_date',
  ];

  /// Versión estática pura de [fromOdoo] — no referencia `this` ni
  /// estado de instancia (OdooClient, GeneratedDatabase), solo [data].
  /// Por eso su tear-off (`PricelistManager.fromOdooMap`) es transferible a
  /// `Isolate.run()`, a diferencia del tear-off del método de instancia
  /// [fromOdoo] (que arrastra el manager completo, no transferible).
  static Pricelist fromOdooMap(Map<String, dynamic> data) {
    return Pricelist(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      active: parseOdooBool(data['active']),
      currencyId: extractMany2oneId(data['currency_id']),
      currencyName: extractMany2oneName(data['currency_id']),
      companyId: extractMany2oneId(data['company_id']),
      companyName: extractMany2oneName(data['company_id']),
      sequence: parseOdooInt(data['sequence']) ?? 0,
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Pricelist fromOdoo(Map<String, dynamic> data) => fromOdooMap(data);

  @override
  Map<String, dynamic> toOdoo(Pricelist record) {
    return {
      'name': record.name,
      'active': record.active,
      'currency_id': record.currencyId,
      'company_id': record.companyId,
      'sequence': record.sequence,
    };
  }

  @override
  Pricelist fromDrift(dynamic row) {
    return Pricelist(
      id: row.odooId as int,
      name: row.name as String,
      active: row.active as bool,
      currencyId: row.currencyId as int?,
      currencyName: row.currencyName as String?,
      companyId: row.companyId as int?,
      companyName: row.companyName as String?,
      sequence: row.sequence as int,
      discountPolicy: row.discountPolicy as String?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Pricelist record) => record.id;

  @override
  String? getUuid(Pricelist record) => null;

  @override
  Pricelist withIdAndUuid(Pricelist record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Pricelist withSyncStatus(Pricelist record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'name': 'name',
    'active': 'active',
    'currency_id': 'currencyId',
    'company_id': 'companyId',
    'sequence': 'sequence',
    'write_date': 'writeDate',
  };

  /// Get Dart field name from Odoo field name.
  String? getDartFieldName(String odooField) => fieldMappings[odooField];

  /// Get Odoo field name from Dart field name.
  String? getOdooFieldName(String dartField) {
    for (final entry in fieldMappings.entries) {
      if (entry.value == dartField) return entry.key;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════
  // GenericDriftOperations — Database & Table
  // ═══════════════════════════════════════════════════

  @override
  GeneratedDatabase get database {
    final db = this.db;
    if (db == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return db;
  }

  @override
  TableInfo get table {
    final resolved = resolveTable();
    if (resolved == null) {
      throw StateError('Table \'product_pricelist\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Pricelist record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'active': Variable<bool>(record.active),
      'currency_id': driftVar<int>(record.currencyId),
      'currency_name': driftVar<String>(record.currencyName),
      'company_id': driftVar<int>(record.companyId),
      'company_name': driftVar<String>(record.companyName),
      'sequence': Variable<int>(record.sequence),
      'write_date': driftVar<DateTime>(record.writeDate),
      'discount_policy': driftVar<String>(record.discountPolicy),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'active',
    'currencyId',
    'companyId',
    'sequence',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'active': 'Active',
    'currencyId': 'Currency Id',
    'currencyName': 'Currency Name',
    'companyId': 'Company Id',
    'companyName': 'Company Name',
    'sequence': 'Sequence',
    'discountPolicy': 'Discount Policy',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Pricelist record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Pricelist record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Pricelist record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Pricelist record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'active':
        return record.active;
      case 'currencyId':
        return record.currencyId;
      case 'currencyName':
        return record.currencyName;
      case 'companyId':
        return record.companyId;
      case 'companyName':
        return record.companyName;
      case 'sequence':
        return record.sequence;
      case 'discountPolicy':
        return record.discountPolicy;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Pricelist applyWebSocketChangesToRecord(
    Pricelist record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(discountPolicy: record.discountPolicy);
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'name':
        return (obj as dynamic).name;
      case 'active':
        return (obj as dynamic).active;
      case 'currencyId':
        return (obj as dynamic).currencyId;
      case 'currencyName':
        return (obj as dynamic).currencyName;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'companyName':
        return (obj as dynamic).companyName;
      case 'sequence':
        return (obj as dynamic).sequence;
      case 'discountPolicy':
        return (obj as dynamic).discountPolicy;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'localCreatedAt':
        return (obj as dynamic).localCreatedAt;
      default:
        return super.accessProperty(obj, name);
    }
  }

  @override
  List<String> get computedFieldNames => const [];

  @override
  List<String> get storedFieldNames => const [
    'id',
    'name',
    'active',
    'currencyId',
    'currencyName',
    'companyId',
    'companyName',
    'sequence',
    'discountPolicy',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'active',
    'currencyId',
    'companyId',
    'sequence',
  ];
}

/// Global instance of PricelistManager.
final pricelistManager = PricelistManager();

/// Generated manager for PricelistItem.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: product.pricelist.item
class PricelistItemManager extends OdooModelManager<PricelistItem>
    with GenericDriftOperations<PricelistItem> {
  @override
  String get odooModel => 'product.pricelist.item';

  @override
  String get tableName => 'product_pricelist_item';

  @override
  List<String> get odooFields => [
    'id',
    'pricelist_id',
    'product_tmpl_id',
    'product_id',
    'categ_id',
    'applied_on',
    'min_quantity',
    'date_start',
    'date_end',
    'compute_price',
    'fixed_price',
    'percent_price',
    'base',
    'base_pricelist_id',
    'price_discount',
    'price_surcharge',
    'price_round',
    'price_min_margin',
    'price_max_margin',
    'write_date',
  ];

  /// Versión estática pura de [fromOdoo] — no referencia `this` ni
  /// estado de instancia (OdooClient, GeneratedDatabase), solo [data].
  /// Por eso su tear-off (`PricelistItemManager.fromOdooMap`) es transferible a
  /// `Isolate.run()`, a diferencia del tear-off del método de instancia
  /// [fromOdoo] (que arrastra el manager completo, no transferible).
  static PricelistItem fromOdooMap(Map<String, dynamic> data) {
    return PricelistItem(
      id: data['id'] as int? ?? 0,
      pricelistId: extractMany2oneId(data['pricelist_id']) ?? 0,
      productTmplId: extractMany2oneId(data['product_tmpl_id']),
      productId: extractMany2oneId(data['product_id']),
      categId: extractMany2oneId(data['categ_id']),
      appliedOn: parseOdooSelection(data['applied_on']) ?? '',
      minQuantity: parseOdooDouble(data['min_quantity']) ?? 0.0,
      dateStart: parseOdooDateTime(data['date_start']),
      dateEnd: parseOdooDateTime(data['date_end']),
      computePrice: parseOdooSelection(data['compute_price']) ?? '',
      fixedPrice: parseOdooDouble(data['fixed_price']) ?? 0.0,
      percentPrice: parseOdooDouble(data['percent_price']) ?? 0.0,
      base: parseOdooSelection(data['base']) ?? '',
      basePricelistId: extractMany2oneId(data['base_pricelist_id']),
      priceDiscount: parseOdooDouble(data['price_discount']) ?? 0.0,
      priceSurcharge: parseOdooDouble(data['price_surcharge']) ?? 0.0,
      priceRound: parseOdooDouble(data['price_round']) ?? 0.0,
      priceMinMargin: parseOdooDouble(data['price_min_margin']) ?? 0.0,
      priceMaxMargin: parseOdooDouble(data['price_max_margin']) ?? 0.0,
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  PricelistItem fromOdoo(Map<String, dynamic> data) => fromOdooMap(data);

  @override
  Map<String, dynamic> toOdoo(PricelistItem record) {
    return {
      'pricelist_id': record.pricelistId,
      'product_tmpl_id': record.productTmplId,
      'product_id': record.productId,
      'categ_id': record.categId,
      'applied_on': record.appliedOn,
      'min_quantity': record.minQuantity,
      'date_start': formatOdooDateTime(record.dateStart),
      'date_end': formatOdooDateTime(record.dateEnd),
      'compute_price': record.computePrice,
      'fixed_price': record.fixedPrice,
      'percent_price': record.percentPrice,
      'base': record.base,
      'base_pricelist_id': record.basePricelistId,
      'price_discount': record.priceDiscount,
      'price_surcharge': record.priceSurcharge,
      'price_round': record.priceRound,
      'price_min_margin': record.priceMinMargin,
      'price_max_margin': record.priceMaxMargin,
    };
  }

  @override
  PricelistItem fromDrift(dynamic row) {
    return PricelistItem(
      id: row.odooId as int,
      pricelistId: row.pricelistId as int,
      productTmplId: row.productTmplId as int?,
      productId: row.productId as int?,
      categId: row.categId as int?,
      appliedOn: row.appliedOn as String,
      minQuantity: row.minQuantity as double,
      dateStart: row.dateStart as DateTime?,
      dateEnd: row.dateEnd as DateTime?,
      computePrice: row.computePrice as String,
      fixedPrice: row.fixedPrice as double,
      percentPrice: row.percentPrice as double,
      uomId: row.uomId as int?,
      base: row.base as String,
      basePricelistId: row.basePricelistId as int?,
      priceDiscount: row.priceDiscount as double,
      priceSurcharge: row.priceSurcharge as double,
      priceRound: row.priceRound as double,
      priceMinMargin: row.priceMinMargin as double,
      priceMaxMargin: row.priceMaxMargin as double,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(PricelistItem record) => record.id;

  @override
  String? getUuid(PricelistItem record) => null;

  @override
  PricelistItem withIdAndUuid(PricelistItem record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  PricelistItem withSyncStatus(PricelistItem record, bool isSynced) {
    return record; // No sync status field
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'pricelist_id': 'pricelistId',
    'product_tmpl_id': 'productTmplId',
    'product_id': 'productId',
    'categ_id': 'categId',
    'applied_on': 'appliedOn',
    'min_quantity': 'minQuantity',
    'date_start': 'dateStart',
    'date_end': 'dateEnd',
    'compute_price': 'computePrice',
    'fixed_price': 'fixedPrice',
    'percent_price': 'percentPrice',
    'base': 'base',
    'base_pricelist_id': 'basePricelistId',
    'price_discount': 'priceDiscount',
    'price_surcharge': 'priceSurcharge',
    'price_round': 'priceRound',
    'price_min_margin': 'priceMinMargin',
    'price_max_margin': 'priceMaxMargin',
    'write_date': 'writeDate',
  };

  /// Get Dart field name from Odoo field name.
  String? getDartFieldName(String odooField) => fieldMappings[odooField];

  /// Get Odoo field name from Dart field name.
  String? getOdooFieldName(String dartField) {
    for (final entry in fieldMappings.entries) {
      if (entry.value == dartField) return entry.key;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════
  // GenericDriftOperations — Database & Table
  // ═══════════════════════════════════════════════════

  @override
  GeneratedDatabase get database {
    final db = this.db;
    if (db == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return db;
  }

  @override
  TableInfo get table {
    final resolved = resolveTable();
    if (resolved == null) {
      throw StateError(
        'Table \'product_pricelist_item\' not found in database.',
      );
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(PricelistItem record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'pricelist_id': Variable<int>(record.pricelistId),
      'product_tmpl_id': driftVar<int>(record.productTmplId),
      'product_id': driftVar<int>(record.productId),
      'categ_id': driftVar<int>(record.categId),
      'applied_on': Variable<String>(record.appliedOn),
      'min_quantity': Variable<double>(record.minQuantity),
      'date_start': driftVar<DateTime>(record.dateStart),
      'date_end': driftVar<DateTime>(record.dateEnd),
      'compute_price': Variable<String>(record.computePrice),
      'fixed_price': Variable<double>(record.fixedPrice),
      'percent_price': Variable<double>(record.percentPrice),
      'base': Variable<String>(record.base),
      'base_pricelist_id': driftVar<int>(record.basePricelistId),
      'price_discount': Variable<double>(record.priceDiscount),
      'price_surcharge': Variable<double>(record.priceSurcharge),
      'price_round': Variable<double>(record.priceRound),
      'price_min_margin': Variable<double>(record.priceMinMargin),
      'price_max_margin': Variable<double>(record.priceMaxMargin),
      'write_date': driftVar<DateTime>(record.writeDate),
      'uom_id': driftVar<int>(record.uomId),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'pricelistId',
    'productTmplId',
    'productId',
    'categId',
    'appliedOn',
    'minQuantity',
    'dateStart',
    'dateEnd',
    'computePrice',
    'fixedPrice',
    'percentPrice',
    'base',
    'basePricelistId',
    'priceDiscount',
    'priceSurcharge',
    'priceRound',
    'priceMinMargin',
    'priceMaxMargin',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'pricelistId': 'Pricelist Id',
    'productTmplId': 'Product Tmpl Id',
    'productId': 'Product Id',
    'categId': 'Categ Id',
    'appliedOn': 'Applied On',
    'minQuantity': 'Min Quantity',
    'dateStart': 'Date Start',
    'dateEnd': 'Date End',
    'computePrice': 'Compute Price',
    'fixedPrice': 'Fixed Price',
    'percentPrice': 'Percent Price',
    'uomId': 'Uom Id',
    'base': 'Base',
    'basePricelistId': 'Base Pricelist Id',
    'priceDiscount': 'Price Discount',
    'priceSurcharge': 'Price Surcharge',
    'priceRound': 'Price Round',
    'priceMinMargin': 'Price Min Margin',
    'priceMaxMargin': 'Price Max Margin',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(PricelistItem record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(PricelistItem record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(PricelistItem record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(PricelistItem record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'pricelistId':
        return record.pricelistId;
      case 'productTmplId':
        return record.productTmplId;
      case 'productId':
        return record.productId;
      case 'categId':
        return record.categId;
      case 'appliedOn':
        return record.appliedOn;
      case 'minQuantity':
        return record.minQuantity;
      case 'dateStart':
        return record.dateStart;
      case 'dateEnd':
        return record.dateEnd;
      case 'computePrice':
        return record.computePrice;
      case 'fixedPrice':
        return record.fixedPrice;
      case 'percentPrice':
        return record.percentPrice;
      case 'uomId':
        return record.uomId;
      case 'base':
        return record.base;
      case 'basePricelistId':
        return record.basePricelistId;
      case 'priceDiscount':
        return record.priceDiscount;
      case 'priceSurcharge':
        return record.priceSurcharge;
      case 'priceRound':
        return record.priceRound;
      case 'priceMinMargin':
        return record.priceMinMargin;
      case 'priceMaxMargin':
        return record.priceMaxMargin;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  PricelistItem applyWebSocketChangesToRecord(
    PricelistItem record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(uomId: record.uomId);
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'pricelistId':
        return (obj as dynamic).pricelistId;
      case 'productTmplId':
        return (obj as dynamic).productTmplId;
      case 'productId':
        return (obj as dynamic).productId;
      case 'categId':
        return (obj as dynamic).categId;
      case 'appliedOn':
        return (obj as dynamic).appliedOn;
      case 'minQuantity':
        return (obj as dynamic).minQuantity;
      case 'dateStart':
        return (obj as dynamic).dateStart;
      case 'dateEnd':
        return (obj as dynamic).dateEnd;
      case 'computePrice':
        return (obj as dynamic).computePrice;
      case 'fixedPrice':
        return (obj as dynamic).fixedPrice;
      case 'percentPrice':
        return (obj as dynamic).percentPrice;
      case 'uomId':
        return (obj as dynamic).uomId;
      case 'base':
        return (obj as dynamic).base;
      case 'basePricelistId':
        return (obj as dynamic).basePricelistId;
      case 'priceDiscount':
        return (obj as dynamic).priceDiscount;
      case 'priceSurcharge':
        return (obj as dynamic).priceSurcharge;
      case 'priceRound':
        return (obj as dynamic).priceRound;
      case 'priceMinMargin':
        return (obj as dynamic).priceMinMargin;
      case 'priceMaxMargin':
        return (obj as dynamic).priceMaxMargin;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'localCreatedAt':
        return (obj as dynamic).localCreatedAt;
      default:
        return super.accessProperty(obj, name);
    }
  }

  @override
  List<String> get computedFieldNames => const [];

  @override
  List<String> get storedFieldNames => const [
    'id',
    'pricelistId',
    'productTmplId',
    'productId',
    'categId',
    'appliedOn',
    'minQuantity',
    'dateStart',
    'dateEnd',
    'computePrice',
    'fixedPrice',
    'percentPrice',
    'uomId',
    'base',
    'basePricelistId',
    'priceDiscount',
    'priceSurcharge',
    'priceRound',
    'priceMinMargin',
    'priceMaxMargin',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'pricelistId',
    'productTmplId',
    'productId',
    'categId',
    'appliedOn',
    'minQuantity',
    'dateStart',
    'dateEnd',
    'computePrice',
    'fixedPrice',
    'percentPrice',
    'base',
    'basePricelistId',
    'priceDiscount',
    'priceSurcharge',
    'priceRound',
    'priceMinMargin',
    'priceMaxMargin',
  ];
}

/// Global instance of PricelistItemManager.
final pricelistItemManager = PricelistItemManager();
