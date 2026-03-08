// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Product.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: product.product
class ProductManager extends OdooModelManager<Product>
    with GenericDriftOperations<Product> {
  @override
  String get odooModel => 'product.product';

  @override
  String get tableName => 'product_product';

  @override
  List<String> get odooFields => [
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
    'uom_po_id',
    'taxes_id',
    'supplier_taxes_id',
    'description',
    'description_sale',
    'product_tmpl_id',
    'image_128',
    'qty_available',
    'virtual_available',
    'tracking',
    'is_storable',
    'l10n_ec_auxiliary_code',
    'is_unit_product',
    'temporal_no_despachar',
    'write_date',
  ];

  @override
  Product fromOdoo(Map<String, dynamic> data) {
    return Product(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      displayNameOdoo: parseOdooString(data['display_name']),
      defaultCode: parseOdooString(data['default_code']),
      barcode: parseOdooString(data['barcode']),
      type: ProductType.values.firstWhere(
        (e) => e.name == parseOdooSelection(data['type']),
        orElse: () => ProductType.values.first,
      ),
      saleOk: parseOdooBool(data['sale_ok']),
      purchaseOk: parseOdooBool(data['purchase_ok']),
      active: parseOdooBool(data['active']),
      listPrice: parseOdooDouble(data['list_price']) ?? 0.0,
      standardPrice: parseOdooDouble(data['standard_price']) ?? 0.0,
      categId: extractMany2oneId(data['categ_id']),
      categName: extractMany2oneName(data['categ_id']),
      uomId: extractMany2oneId(data['uom_id']),
      uomName: extractMany2oneName(data['uom_id']),
      uomPoId: extractMany2oneId(data['uom_po_id']),
      uomPoName: extractMany2oneName(data['uom_po_id']),
      taxesId: data['taxes_id']?.toString(),
      supplierTaxesId: data['supplier_taxes_id']?.toString(),
      description: parseOdooString(data['description']),
      descriptionSale: parseOdooString(data['description_sale']),
      productTmplId: extractMany2oneId(data['product_tmpl_id']),
      image128: parseOdooString(data['image_128']),
      qtyAvailable: parseOdooDouble(data['qty_available']) ?? 0.0,
      virtualAvailable: parseOdooDouble(data['virtual_available']) ?? 0.0,
      tracking: TrackingType.values.firstWhere(
        (e) => e.name == parseOdooSelection(data['tracking']),
        orElse: () => TrackingType.values.first,
      ),
      isStorable: parseOdooBool(data['is_storable']),
      l10nEcAuxiliaryCode: parseOdooString(data['l10n_ec_auxiliary_code']),
      isUnitProduct: parseOdooBool(data['is_unit_product']),
      temporalNoDespachar: parseOdooBool(data['temporal_no_despachar']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Product record) {
    return {
      'name': record.name,
      'default_code': record.defaultCode,
      'barcode': record.barcode,
      'type': record.type.name,
      'sale_ok': record.saleOk,
      'purchase_ok': record.purchaseOk,
      'active': record.active,
      'list_price': record.listPrice,
      'standard_price': record.standardPrice,
      'categ_id': record.categId,
      'uom_id': record.uomId,
      'uom_po_id': record.uomPoId,
      'taxes_id': record.taxesId,
      'supplier_taxes_id': record.supplierTaxesId,
      'description': record.description,
      'description_sale': record.descriptionSale,
      'product_tmpl_id': record.productTmplId,
      'image_128': record.image128,
      'tracking': record.tracking.name,
      'is_storable': record.isStorable,
      'l10n_ec_auxiliary_code': record.l10nEcAuxiliaryCode,
      'is_unit_product': record.isUnitProduct,
      'temporal_no_despachar': record.temporalNoDespachar,
    };
  }

  @override
  Product fromDrift(dynamic row) {
    return Product(
      id: row.odooId as int,
      name: row.name as String,
      displayNameOdoo: row.displayNameOdoo as String?,
      defaultCode: row.defaultCode as String?,
      barcode: row.barcode as String?,
      type: ProductType.values.firstWhere(
        (e) => e.name == (row.type as String?),
        orElse: () => ProductType.values.first,
      ),
      saleOk: row.saleOk as bool,
      purchaseOk: row.purchaseOk as bool,
      active: row.active as bool,
      listPrice: row.listPrice as double,
      standardPrice: row.standardPrice as double,
      categId: row.categId as int?,
      categName: row.categName as String?,
      uomId: row.uomId as int?,
      uomName: row.uomName as String?,
      uomPoId: row.uomPoId as int?,
      uomPoName: row.uomPoName as String?,
      taxesId: row.taxesId as String?,
      supplierTaxesId: row.supplierTaxesId as String?,
      description: row.description as String?,
      descriptionSale: row.descriptionSale as String?,
      productTmplId: row.productTmplId as int?,
      image128: row.image128 as String?,
      qtyAvailable: row.qtyAvailable as double,
      virtualAvailable: row.virtualAvailable as double,
      tracking: TrackingType.values.firstWhere(
        (e) => e.name == (row.tracking as String?),
        orElse: () => TrackingType.values.first,
      ),
      isStorable: row.isStorable as bool,
      l10nEcAuxiliaryCode: row.l10nEcAuxiliaryCode as String?,
      isUnitProduct: row.isUnitProduct as bool,
      temporalNoDespachar: row.temporalNoDespachar as bool,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(Product record) => record.id;

  @override
  String? getUuid(Product record) => null;

  @override
  Product withIdAndUuid(Product record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  Product withSyncStatus(Product record, bool isSynced) {
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
    'display_name': 'displayNameOdoo',
    'default_code': 'defaultCode',
    'barcode': 'barcode',
    'type': 'type',
    'sale_ok': 'saleOk',
    'purchase_ok': 'purchaseOk',
    'active': 'active',
    'list_price': 'listPrice',
    'standard_price': 'standardPrice',
    'categ_id': 'categId',
    'uom_id': 'uomId',
    'uom_po_id': 'uomPoId',
    'taxes_id': 'taxesId',
    'supplier_taxes_id': 'supplierTaxesId',
    'description': 'description',
    'description_sale': 'descriptionSale',
    'product_tmpl_id': 'productTmplId',
    'image_128': 'image128',
    'qty_available': 'qtyAvailable',
    'virtual_available': 'virtualAvailable',
    'tracking': 'tracking',
    'is_storable': 'isStorable',
    'l10n_ec_auxiliary_code': 'l10nEcAuxiliaryCode',
    'is_unit_product': 'isUnitProduct',
    'temporal_no_despachar': 'temporalNoDespachar',
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
      throw StateError('Table \'product_product\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Product record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'display_name': driftVar<String>(record.displayNameOdoo),
      'default_code': driftVar<String>(record.defaultCode),
      'barcode': driftVar<String>(record.barcode),
      'type': Variable<String>(record.type.name),
      'sale_ok': Variable<bool>(record.saleOk),
      'purchase_ok': Variable<bool>(record.purchaseOk),
      'active': Variable<bool>(record.active),
      'list_price': Variable<double>(record.listPrice),
      'standard_price': Variable<double>(record.standardPrice),
      'categ_id': driftVar<int>(record.categId),
      'categ_id_name': driftVar<String>(record.categName),
      'uom_id': driftVar<int>(record.uomId),
      'uom_id_name': driftVar<String>(record.uomName),
      'uom_po_id': driftVar<int>(record.uomPoId),
      'uom_po_id_name': driftVar<String>(record.uomPoName),
      'taxes_id': driftVar<String>(record.taxesId),
      'supplier_taxes_id': driftVar<String>(record.supplierTaxesId),
      'description': driftVar<String>(record.description),
      'description_sale': driftVar<String>(record.descriptionSale),
      'product_tmpl_id': driftVar<int>(record.productTmplId),
      'image_128': driftVar<String>(record.image128),
      'qty_available': Variable<double>(record.qtyAvailable),
      'virtual_available': Variable<double>(record.virtualAvailable),
      'tracking': Variable<String>(record.tracking.name),
      'is_storable': Variable<bool>(record.isStorable),
      'l10n_ec_auxiliary_code': driftVar<String>(record.l10nEcAuxiliaryCode),
      'is_unit_product': Variable<bool>(record.isUnitProduct),
      'temporal_no_despachar': Variable<bool>(record.temporalNoDespachar),
      'write_date': driftVar<DateTime>(record.writeDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'defaultCode',
    'barcode',
    'type',
    'saleOk',
    'purchaseOk',
    'active',
    'listPrice',
    'standardPrice',
    'categId',
    'uomId',
    'uomPoId',
    'taxesId',
    'supplierTaxesId',
    'description',
    'descriptionSale',
    'productTmplId',
    'image128',
    'tracking',
    'isStorable',
    'l10nEcAuxiliaryCode',
    'isUnitProduct',
    'temporalNoDespachar',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'displayNameOdoo': 'Display Name Odoo',
    'defaultCode': 'Default Code',
    'barcode': 'Barcode',
    'type': 'Type',
    'saleOk': 'Sale Ok',
    'purchaseOk': 'Purchase Ok',
    'active': 'Active',
    'listPrice': 'List Price',
    'standardPrice': 'Standard Price',
    'categId': 'Categ Id',
    'categName': 'Categ Name',
    'uomId': 'Uom Id',
    'uomName': 'Uom Name',
    'uomPoId': 'Uom Po Id',
    'uomPoName': 'Uom Po Name',
    'uomIds': 'Uom Ids',
    'taxesId': 'Taxes Id',
    'supplierTaxesId': 'Supplier Taxes Id',
    'description': 'Description',
    'descriptionSale': 'Description Sale',
    'productTmplId': 'Product Tmpl Id',
    'image128': 'Image128',
    'qtyAvailable': 'Qty Available',
    'virtualAvailable': 'Virtual Available',
    'tracking': 'Tracking',
    'isStorable': 'Is Storable',
    'l10nEcAuxiliaryCode': 'L10n Ec Auxiliary Code',
    'isUnitProduct': 'Is Unit Product',
    'temporalNoDespachar': 'Temporal No Despachar',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Product record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Product record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Product record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Product record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'displayNameOdoo':
        return record.displayNameOdoo;
      case 'defaultCode':
        return record.defaultCode;
      case 'barcode':
        return record.barcode;
      case 'type':
        return record.type;
      case 'saleOk':
        return record.saleOk;
      case 'purchaseOk':
        return record.purchaseOk;
      case 'active':
        return record.active;
      case 'listPrice':
        return record.listPrice;
      case 'standardPrice':
        return record.standardPrice;
      case 'categId':
        return record.categId;
      case 'categName':
        return record.categName;
      case 'uomId':
        return record.uomId;
      case 'uomName':
        return record.uomName;
      case 'uomPoId':
        return record.uomPoId;
      case 'uomPoName':
        return record.uomPoName;
      case 'uomIds':
        return record.uomIds;
      case 'taxesId':
        return record.taxesId;
      case 'supplierTaxesId':
        return record.supplierTaxesId;
      case 'description':
        return record.description;
      case 'descriptionSale':
        return record.descriptionSale;
      case 'productTmplId':
        return record.productTmplId;
      case 'image128':
        return record.image128;
      case 'qtyAvailable':
        return record.qtyAvailable;
      case 'virtualAvailable':
        return record.virtualAvailable;
      case 'tracking':
        return record.tracking;
      case 'isStorable':
        return record.isStorable;
      case 'l10nEcAuxiliaryCode':
        return record.l10nEcAuxiliaryCode;
      case 'isUnitProduct':
        return record.isUnitProduct;
      case 'temporalNoDespachar':
        return record.temporalNoDespachar;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  Product applyWebSocketChangesToRecord(
    Product record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(uomIds: record.uomIds);
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'name':
        return (obj as dynamic).name;
      case 'displayNameOdoo':
        return (obj as dynamic).displayNameOdoo;
      case 'defaultCode':
        return (obj as dynamic).defaultCode;
      case 'barcode':
        return (obj as dynamic).barcode;
      case 'type':
        return (obj as dynamic).type;
      case 'saleOk':
        return (obj as dynamic).saleOk;
      case 'purchaseOk':
        return (obj as dynamic).purchaseOk;
      case 'active':
        return (obj as dynamic).active;
      case 'listPrice':
        return (obj as dynamic).listPrice;
      case 'standardPrice':
        return (obj as dynamic).standardPrice;
      case 'categId':
        return (obj as dynamic).categId;
      case 'categName':
        return (obj as dynamic).categName;
      case 'uomId':
        return (obj as dynamic).uomId;
      case 'uomName':
        return (obj as dynamic).uomName;
      case 'uomPoId':
        return (obj as dynamic).uomPoId;
      case 'uomPoName':
        return (obj as dynamic).uomPoName;
      case 'uomIds':
        return (obj as dynamic).uomIds;
      case 'taxesId':
        return (obj as dynamic).taxesId;
      case 'supplierTaxesId':
        return (obj as dynamic).supplierTaxesId;
      case 'description':
        return (obj as dynamic).description;
      case 'descriptionSale':
        return (obj as dynamic).descriptionSale;
      case 'productTmplId':
        return (obj as dynamic).productTmplId;
      case 'image128':
        return (obj as dynamic).image128;
      case 'qtyAvailable':
        return (obj as dynamic).qtyAvailable;
      case 'virtualAvailable':
        return (obj as dynamic).virtualAvailable;
      case 'tracking':
        return (obj as dynamic).tracking;
      case 'isStorable':
        return (obj as dynamic).isStorable;
      case 'l10nEcAuxiliaryCode':
        return (obj as dynamic).l10nEcAuxiliaryCode;
      case 'isUnitProduct':
        return (obj as dynamic).isUnitProduct;
      case 'temporalNoDespachar':
        return (obj as dynamic).temporalNoDespachar;
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
    'displayNameOdoo',
    'defaultCode',
    'barcode',
    'type',
    'saleOk',
    'purchaseOk',
    'active',
    'listPrice',
    'standardPrice',
    'categId',
    'categName',
    'uomId',
    'uomName',
    'uomPoId',
    'uomPoName',
    'uomIds',
    'taxesId',
    'supplierTaxesId',
    'description',
    'descriptionSale',
    'productTmplId',
    'image128',
    'qtyAvailable',
    'virtualAvailable',
    'tracking',
    'isStorable',
    'l10nEcAuxiliaryCode',
    'isUnitProduct',
    'temporalNoDespachar',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'defaultCode',
    'barcode',
    'type',
    'saleOk',
    'purchaseOk',
    'active',
    'listPrice',
    'standardPrice',
    'categId',
    'uomId',
    'uomPoId',
    'taxesId',
    'supplierTaxesId',
    'description',
    'descriptionSale',
    'productTmplId',
    'image128',
    'tracking',
    'isStorable',
    'l10nEcAuxiliaryCode',
    'isUnitProduct',
    'temporalNoDespachar',
  ];
}

/// Global instance of ProductManager.
final productManager = ProductManager();
