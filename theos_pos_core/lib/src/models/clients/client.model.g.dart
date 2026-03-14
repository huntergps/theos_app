// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client.model.dart';

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for Client.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: res.partner
class ClientManager extends OdooModelManager<Client>
    with GenericDriftOperations<Client> {
  @override
  String get odooModel => 'res.partner';

  @override
  String get tableName => 'res_partner';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'display_name',
    'ref',
    'vat',
    'email',
    'phone',
    'mobile',
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
    'property_product_pricelist',
    'property_payment_term_id',
    'lang',
    'comment',
    'credit_limit',
    'credit',
    'credit_to_invoice',
    'allow_over_credit',
    'use_partner_credit_limit',
    'total_overdue',
    'unpaid_invoices_count',
    'oldest_overdue_days',
    'dias_max_factura_posterior',
    'tipo_cliente',
    'canal_cliente',
    'customer_rank',
    'supplier_rank',
    'acepta_cheques',
    'emitir_factura_fecha_posterior',
    'no_invoice',
    'last_day_to_invoice',
    'external_id',
    'partner_latitude',
    'partner_longitude',
    'can_use_custom_payments',
    'write_date',
  ];

  @override
  Client fromOdoo(Map<String, dynamic> data) {
    return Client(
      id: data['id'] as int? ?? 0,
      isSynced: false,
      name: parseOdooStringRequired(data['name']),
      displayName: parseOdooString(data['display_name']),
      ref: parseOdooString(data['ref']),
      vat: parseOdooString(data['vat']),
      email: parseOdooString(data['email']),
      phone: parseOdooString(data['phone']),
      mobile: parseOdooString(data['mobile']),
      street: parseOdooString(data['street']),
      street2: parseOdooString(data['street2']),
      city: parseOdooString(data['city']),
      zip: parseOdooString(data['zip']),
      countryId: extractMany2oneId(data['country_id']),
      countryName: extractMany2oneName(data['country_id']),
      stateId: extractMany2oneId(data['state_id']),
      stateName: extractMany2oneName(data['state_id']),
      avatar128: parseOdooString(data['avatar_128']),
      isCompany: parseOdooBool(data['is_company']),
      active: parseOdooBool(data['active']),
      parentId: extractMany2oneId(data['parent_id']),
      parentName: extractMany2oneName(data['parent_id']),
      commercialPartnerName: extractMany2oneName(data['commercial_partner_id']),
      propertyProductPricelistId: extractMany2oneId(
        data['property_product_pricelist'],
      ),
      propertyProductPricelistName: extractMany2oneName(
        data['property_product_pricelist'],
      ),
      propertyPaymentTermId: extractMany2oneId(
        data['property_payment_term_id'],
      ),
      propertyPaymentTermName: extractMany2oneName(
        data['property_payment_term_id'],
      ),
      lang: parseOdooString(data['lang']),
      comment: parseOdooString(data['comment']),
      creditLimit: parseOdooDouble(data['credit_limit']),
      credit: parseOdooDouble(data['credit']),
      creditToInvoice: parseOdooDouble(data['credit_to_invoice']),
      allowOverCredit: parseOdooBool(data['allow_over_credit']),
      usePartnerCreditLimit: parseOdooBool(data['use_partner_credit_limit']),
      totalOverdue: parseOdooDouble(data['total_overdue']),
      overdueInvoicesCount: parseOdooInt(data['unpaid_invoices_count']),
      oldestOverdueDays: parseOdooInt(data['oldest_overdue_days']),
      diasMaxFacturaPosterior: parseOdooInt(data['dias_max_factura_posterior']),
      tipoCliente: parseOdooSelection(data['tipo_cliente']),
      canalCliente: parseOdooSelection(data['canal_cliente']),
      customerRank: parseOdooInt(data['customer_rank']),
      supplierRank: parseOdooInt(data['supplier_rank']),
      aceptaCheques: parseOdooBool(data['acepta_cheques']),
      emitirFacturaFechaPosterior: parseOdooBool(
        data['emitir_factura_fecha_posterior'],
      ),
      noInvoice: parseOdooBool(data['no_invoice']),
      lastDayToInvoice: parseOdooInt(data['last_day_to_invoice']),
      externalId: parseOdooString(data['external_id']),
      partnerLatitude: parseOdooDouble(data['partner_latitude']),
      partnerLongitude: parseOdooDouble(data['partner_longitude']),
      canUseCustomPayments: parseOdooBool(data['can_use_custom_payments']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(Client record) {
    return {
      'name': record.name,
      'display_name': record.displayName,
      'ref': record.ref,
      'vat': record.vat,
      'email': record.email,
      'phone': record.phone,
      'mobile': record.mobile,
      'street': record.street,
      'street2': record.street2,
      'city': record.city,
      'zip': record.zip,
      'country_id': record.countryId,
      'state_id': record.stateId,
      'avatar_128': record.avatar128,
      'is_company': record.isCompany,
      'active': record.active,
      'parent_id': record.parentId,
      'property_product_pricelist': record.propertyProductPricelistId,
      'property_payment_term_id': record.propertyPaymentTermId,
      'lang': record.lang,
      'comment': record.comment,
      'credit_limit': record.creditLimit,
      'credit': record.credit,
      'credit_to_invoice': record.creditToInvoice,
      'allow_over_credit': record.allowOverCredit,
      'use_partner_credit_limit': record.usePartnerCreditLimit,
      'total_overdue': record.totalOverdue,
      'unpaid_invoices_count': record.overdueInvoicesCount,
      'oldest_overdue_days': record.oldestOverdueDays,
      'dias_max_factura_posterior': record.diasMaxFacturaPosterior,
      'tipo_cliente': record.tipoCliente,
      'canal_cliente': record.canalCliente,
      'customer_rank': record.customerRank,
      'supplier_rank': record.supplierRank,
      'acepta_cheques': record.aceptaCheques,
      'emitir_factura_fecha_posterior': record.emitirFacturaFechaPosterior,
      'no_invoice': record.noInvoice,
      'last_day_to_invoice': record.lastDayToInvoice,
      'external_id': record.externalId,
      'partner_latitude': record.partnerLatitude,
      'partner_longitude': record.partnerLongitude,
      'can_use_custom_payments': record.canUseCustomPayments,
      'write_date': formatOdooDateTime(record.writeDate),
    };
  }

  @override
  Client fromDrift(dynamic row) {
    return Client(
      id: row.odooId as int,
      uuid: row.partnerUuid as String?,
      isSynced: row.isSynced as bool? ?? false,
      name: row.name as String,
      displayName: row.displayName as String?,
      ref: row.ref as String?,
      vat: row.vat as String?,
      email: row.email as String?,
      phone: row.phone as String?,
      mobile: row.mobile as String?,
      street: row.street as String?,
      street2: row.street2 as String?,
      city: row.city as String?,
      zip: row.zip as String?,
      countryId: row.countryId as int?,
      countryName: row.countryName as String?,
      stateId: row.stateId as int?,
      stateName: row.stateName as String?,
      avatar128: row.avatar128 as String?,
      isCompany: row.isCompany as bool,
      active: row.active as bool,
      parentId: row.parentId as int?,
      parentName: row.parentName as String?,
      commercialPartnerName: row.commercialPartnerName as String?,
      propertyProductPricelistId: row.propertyProductPricelist as int?,
      propertyProductPricelistName: row.propertyProductPricelistName as String?,
      propertyPaymentTermId: row.propertyPaymentTermId as int?,
      propertyPaymentTermName: row.propertyPaymentTermName as String?,
      lang: row.lang as String?,
      comment: row.comment as String?,
      creditLimit: row.creditLimit as double?,
      credit: row.credit as double?,
      creditToInvoice: row.creditToInvoice as double?,
      allowOverCredit: row.allowOverCredit as bool,
      usePartnerCreditLimit: row.usePartnerCreditLimit as bool,
      totalOverdue: row.totalOverdue as double?,
      overdueInvoicesCount: row.unpaidInvoicesCount as int?,
      oldestOverdueDays: row.oldestOverdueDays as int?,
      diasMaxFacturaPosterior: row.diasMaxFacturaPosterior as int?,
      tipoCliente: row.tipoCliente as String?,
      canalCliente: row.canalCliente as String?,
      customerRank: row.customerRank as int?,
      supplierRank: row.supplierRank as int?,
      aceptaCheques: row.aceptaCheques as bool,
      emitirFacturaFechaPosterior: row.emitirFacturaFechaPosterior as bool,
      noInvoice: row.noInvoice as bool,
      lastDayToInvoice: row.lastDayToInvoice as int?,
      externalId: row.externalId as String?,
      partnerLatitude: row.partnerLatitude as double?,
      partnerLongitude: row.partnerLongitude as double?,
      canUseCustomPayments: row.canUseCustomPayments as bool,
      writeDate: row.writeDate as DateTime?,
      creditLastSyncDate: row.creditLastSyncDate as DateTime?,
    );
  }

  @override
  int getId(Client record) => record.id;

  @override
  String? getUuid(Client record) => record.uuid;

  @override
  Client withIdAndUuid(Client record, int id, String uuid) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  Client withSyncStatus(Client record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'name': 'name',
    'display_name': 'displayName',
    'ref': 'ref',
    'vat': 'vat',
    'email': 'email',
    'phone': 'phone',
    'mobile': 'mobile',
    'street': 'street',
    'street2': 'street2',
    'city': 'city',
    'zip': 'zip',
    'country_id': 'countryId',
    'state_id': 'stateId',
    'avatar_128': 'avatar128',
    'is_company': 'isCompany',
    'active': 'active',
    'parent_id': 'parentId',
    'property_product_pricelist': 'propertyProductPricelistId',
    'property_payment_term_id': 'propertyPaymentTermId',
    'lang': 'lang',
    'comment': 'comment',
    'credit_limit': 'creditLimit',
    'credit': 'credit',
    'credit_to_invoice': 'creditToInvoice',
    'allow_over_credit': 'allowOverCredit',
    'use_partner_credit_limit': 'usePartnerCreditLimit',
    'total_overdue': 'totalOverdue',
    'unpaid_invoices_count': 'overdueInvoicesCount',
    'oldest_overdue_days': 'oldestOverdueDays',
    'dias_max_factura_posterior': 'diasMaxFacturaPosterior',
    'tipo_cliente': 'tipoCliente',
    'canal_cliente': 'canalCliente',
    'customer_rank': 'customerRank',
    'supplier_rank': 'supplierRank',
    'acepta_cheques': 'aceptaCheques',
    'emitir_factura_fecha_posterior': 'emitirFacturaFechaPosterior',
    'no_invoice': 'noInvoice',
    'last_day_to_invoice': 'lastDayToInvoice',
    'external_id': 'externalId',
    'partner_latitude': 'partnerLatitude',
    'partner_longitude': 'partnerLongitude',
    'can_use_custom_payments': 'canUseCustomPayments',
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
      throw StateError('Table \'res_partner\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(Client record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'display_name': driftVar<String>(record.displayName),
      'ref': driftVar<String>(record.ref),
      'vat': driftVar<String>(record.vat),
      'email': driftVar<String>(record.email),
      'phone': driftVar<String>(record.phone),
      'mobile': driftVar<String>(record.mobile),
      'street': driftVar<String>(record.street),
      'street2': driftVar<String>(record.street2),
      'city': driftVar<String>(record.city),
      'zip': driftVar<String>(record.zip),
      'country_id': driftVar<int>(record.countryId),
      'country_id_name': driftVar<String>(record.countryName),
      'state_id': driftVar<int>(record.stateId),
      'state_id_name': driftVar<String>(record.stateName),
      'avatar_128': driftVar<String>(record.avatar128),
      'is_company': Variable<bool>(record.isCompany),
      'active': Variable<bool>(record.active),
      'parent_id': driftVar<int>(record.parentId),
      'parent_id_name': driftVar<String>(record.parentName),
      'commercial_partner_id_name': driftVar<String>(
        record.commercialPartnerName,
      ),
      'property_product_pricelist': driftVar<int>(
        record.propertyProductPricelistId,
      ),
      'property_product_pricelist_name': driftVar<String>(
        record.propertyProductPricelistName,
      ),
      'property_payment_term_id': driftVar<int>(record.propertyPaymentTermId),
      'property_payment_term_id_name': driftVar<String>(
        record.propertyPaymentTermName,
      ),
      'lang': driftVar<String>(record.lang),
      'comment': driftVar<String>(record.comment),
      'credit_limit': driftVar<double>(record.creditLimit),
      'credit': driftVar<double>(record.credit),
      'credit_to_invoice': driftVar<double>(record.creditToInvoice),
      'allow_over_credit': Variable<bool>(record.allowOverCredit),
      'use_partner_credit_limit': Variable<bool>(record.usePartnerCreditLimit),
      'total_overdue': driftVar<double>(record.totalOverdue),
      'unpaid_invoices_count': driftVar<int>(record.overdueInvoicesCount),
      'oldest_overdue_days': driftVar<int>(record.oldestOverdueDays),
      'dias_max_factura_posterior': driftVar<int>(
        record.diasMaxFacturaPosterior,
      ),
      'tipo_cliente': driftVar<String>(record.tipoCliente),
      'canal_cliente': driftVar<String>(record.canalCliente),
      'customer_rank': driftVar<int>(record.customerRank),
      'supplier_rank': driftVar<int>(record.supplierRank),
      'acepta_cheques': Variable<bool>(record.aceptaCheques),
      'emitir_factura_fecha_posterior': Variable<bool>(
        record.emitirFacturaFechaPosterior,
      ),
      'no_invoice': Variable<bool>(record.noInvoice),
      'last_day_to_invoice': driftVar<int>(record.lastDayToInvoice),
      'external_id': driftVar<String>(record.externalId),
      'partner_latitude': driftVar<double>(record.partnerLatitude),
      'partner_longitude': driftVar<double>(record.partnerLongitude),
      'can_use_custom_payments': Variable<bool>(record.canUseCustomPayments),
      'write_date': driftVar<DateTime>(record.writeDate),
      'partner_uuid': driftVar<String>(record.uuid),
      'is_synced': Variable<bool>(record.isSynced),
      'credit_last_sync_date': driftVar<DateTime>(record.creditLastSyncDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'displayName',
    'ref',
    'vat',
    'email',
    'phone',
    'mobile',
    'street',
    'street2',
    'city',
    'zip',
    'countryId',
    'stateId',
    'avatar128',
    'isCompany',
    'active',
    'parentId',
    'propertyProductPricelistId',
    'propertyPaymentTermId',
    'lang',
    'comment',
    'creditLimit',
    'credit',
    'creditToInvoice',
    'allowOverCredit',
    'usePartnerCreditLimit',
    'totalOverdue',
    'overdueInvoicesCount',
    'oldestOverdueDays',
    'diasMaxFacturaPosterior',
    'tipoCliente',
    'canalCliente',
    'customerRank',
    'supplierRank',
    'aceptaCheques',
    'emitirFacturaFechaPosterior',
    'noInvoice',
    'lastDayToInvoice',
    'externalId',
    'partnerLatitude',
    'partnerLongitude',
    'canUseCustomPayments',
    'writeDate',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'uuid': 'Uuid',
    'isSynced': 'Is Synced',
    'name': 'Name',
    'displayName': 'Display Name',
    'ref': 'Ref',
    'vat': 'Vat',
    'email': 'Email',
    'phone': 'Phone',
    'mobile': 'Mobile',
    'street': 'Street',
    'street2': 'Street2',
    'city': 'City',
    'zip': 'Zip',
    'countryId': 'Country Id',
    'countryName': 'Country Name',
    'stateId': 'State Id',
    'stateName': 'State Name',
    'avatar128': 'Avatar128',
    'isCompany': 'Is Company',
    'active': 'Active',
    'parentId': 'Parent Id',
    'parentName': 'Parent Name',
    'commercialPartnerName': 'Commercial Partner Name',
    'propertyProductPricelistId': 'Property Product Pricelist Id',
    'propertyProductPricelistName': 'Property Product Pricelist Name',
    'propertyPaymentTermId': 'Property Payment Term Id',
    'propertyPaymentTermName': 'Property Payment Term Name',
    'lang': 'Lang',
    'comment': 'Comment',
    'creditLimit': 'Credit Limit',
    'credit': 'Credit',
    'creditToInvoice': 'Credit To Invoice',
    'allowOverCredit': 'Allow Over Credit',
    'usePartnerCreditLimit': 'Use Partner Credit Limit',
    'totalOverdue': 'Total Overdue',
    'overdueInvoicesCount': 'Overdue Invoices Count',
    'oldestOverdueDays': 'Oldest Overdue Days',
    'diasMaxFacturaPosterior': 'Dias Max Factura Posterior',
    'tipoCliente': 'Tipo Cliente',
    'canalCliente': 'Canal Cliente',
    'customerRank': 'Customer Rank',
    'supplierRank': 'Supplier Rank',
    'aceptaCheques': 'Acepta Cheques',
    'emitirFacturaFechaPosterior': 'Emitir Factura Fecha Posterior',
    'noInvoice': 'No Invoice',
    'lastDayToInvoice': 'Last Day To Invoice',
    'externalId': 'External Id',
    'partnerLatitude': 'Partner Latitude',
    'partnerLongitude': 'Partner Longitude',
    'canUseCustomPayments': 'Can Use Custom Payments',
    'writeDate': 'Write Date',
    'creditLastSyncDate': 'Credit Last Sync Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(Client record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(Client record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(Client record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(Client record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'uuid':
        return record.uuid;
      case 'isSynced':
        return record.isSynced;
      case 'name':
        return record.name;
      case 'displayName':
        return record.displayName;
      case 'ref':
        return record.ref;
      case 'vat':
        return record.vat;
      case 'email':
        return record.email;
      case 'phone':
        return record.phone;
      case 'mobile':
        return record.mobile;
      case 'street':
        return record.street;
      case 'street2':
        return record.street2;
      case 'city':
        return record.city;
      case 'zip':
        return record.zip;
      case 'countryId':
        return record.countryId;
      case 'countryName':
        return record.countryName;
      case 'stateId':
        return record.stateId;
      case 'stateName':
        return record.stateName;
      case 'avatar128':
        return record.avatar128;
      case 'isCompany':
        return record.isCompany;
      case 'active':
        return record.active;
      case 'parentId':
        return record.parentId;
      case 'parentName':
        return record.parentName;
      case 'commercialPartnerName':
        return record.commercialPartnerName;
      case 'propertyProductPricelistId':
        return record.propertyProductPricelistId;
      case 'propertyProductPricelistName':
        return record.propertyProductPricelistName;
      case 'propertyPaymentTermId':
        return record.propertyPaymentTermId;
      case 'propertyPaymentTermName':
        return record.propertyPaymentTermName;
      case 'lang':
        return record.lang;
      case 'comment':
        return record.comment;
      case 'creditLimit':
        return record.creditLimit;
      case 'credit':
        return record.credit;
      case 'creditToInvoice':
        return record.creditToInvoice;
      case 'allowOverCredit':
        return record.allowOverCredit;
      case 'usePartnerCreditLimit':
        return record.usePartnerCreditLimit;
      case 'totalOverdue':
        return record.totalOverdue;
      case 'overdueInvoicesCount':
        return record.overdueInvoicesCount;
      case 'oldestOverdueDays':
        return record.oldestOverdueDays;
      case 'diasMaxFacturaPosterior':
        return record.diasMaxFacturaPosterior;
      case 'tipoCliente':
        return record.tipoCliente;
      case 'canalCliente':
        return record.canalCliente;
      case 'customerRank':
        return record.customerRank;
      case 'supplierRank':
        return record.supplierRank;
      case 'aceptaCheques':
        return record.aceptaCheques;
      case 'emitirFacturaFechaPosterior':
        return record.emitirFacturaFechaPosterior;
      case 'noInvoice':
        return record.noInvoice;
      case 'lastDayToInvoice':
        return record.lastDayToInvoice;
      case 'externalId':
        return record.externalId;
      case 'partnerLatitude':
        return record.partnerLatitude;
      case 'partnerLongitude':
        return record.partnerLongitude;
      case 'canUseCustomPayments':
        return record.canUseCustomPayments;
      case 'writeDate':
        return record.writeDate;
      case 'creditLastSyncDate':
        return record.creditLastSyncDate;
      default:
        return null;
    }
  }

  @override
  Client applyWebSocketChangesToRecord(
    Client record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      uuid: record.uuid,
      isSynced: record.isSynced,
      creditLastSyncDate: record.creditLastSyncDate,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'uuid':
        return (obj as dynamic).partnerUuid;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'name':
        return (obj as dynamic).name;
      case 'displayName':
        return (obj as dynamic).displayName;
      case 'ref':
        return (obj as dynamic).ref;
      case 'vat':
        return (obj as dynamic).vat;
      case 'email':
        return (obj as dynamic).email;
      case 'phone':
        return (obj as dynamic).phone;
      case 'mobile':
        return (obj as dynamic).mobile;
      case 'street':
        return (obj as dynamic).street;
      case 'street2':
        return (obj as dynamic).street2;
      case 'city':
        return (obj as dynamic).city;
      case 'zip':
        return (obj as dynamic).zip;
      case 'countryId':
        return (obj as dynamic).countryId;
      case 'countryName':
        return (obj as dynamic).countryName;
      case 'stateId':
        return (obj as dynamic).stateId;
      case 'stateName':
        return (obj as dynamic).stateName;
      case 'avatar128':
        return (obj as dynamic).avatar128;
      case 'isCompany':
        return (obj as dynamic).isCompany;
      case 'active':
        return (obj as dynamic).active;
      case 'parentId':
        return (obj as dynamic).parentId;
      case 'parentName':
        return (obj as dynamic).parentName;
      case 'commercialPartnerName':
        return (obj as dynamic).commercialPartnerName;
      case 'propertyProductPricelistId':
        return (obj as dynamic).propertyProductPricelist;
      case 'propertyProductPricelistName':
        return (obj as dynamic).propertyProductPricelistName;
      case 'propertyPaymentTermId':
        return (obj as dynamic).propertyPaymentTermId;
      case 'propertyPaymentTermName':
        return (obj as dynamic).propertyPaymentTermName;
      case 'lang':
        return (obj as dynamic).lang;
      case 'comment':
        return (obj as dynamic).comment;
      case 'creditLimit':
        return (obj as dynamic).creditLimit;
      case 'credit':
        return (obj as dynamic).credit;
      case 'creditToInvoice':
        return (obj as dynamic).creditToInvoice;
      case 'allowOverCredit':
        return (obj as dynamic).allowOverCredit;
      case 'usePartnerCreditLimit':
        return (obj as dynamic).usePartnerCreditLimit;
      case 'totalOverdue':
        return (obj as dynamic).totalOverdue;
      case 'overdueInvoicesCount':
        return (obj as dynamic).unpaidInvoicesCount;
      case 'oldestOverdueDays':
        return (obj as dynamic).oldestOverdueDays;
      case 'diasMaxFacturaPosterior':
        return (obj as dynamic).diasMaxFacturaPosterior;
      case 'tipoCliente':
        return (obj as dynamic).tipoCliente;
      case 'canalCliente':
        return (obj as dynamic).canalCliente;
      case 'customerRank':
        return (obj as dynamic).customerRank;
      case 'supplierRank':
        return (obj as dynamic).supplierRank;
      case 'aceptaCheques':
        return (obj as dynamic).aceptaCheques;
      case 'emitirFacturaFechaPosterior':
        return (obj as dynamic).emitirFacturaFechaPosterior;
      case 'noInvoice':
        return (obj as dynamic).noInvoice;
      case 'lastDayToInvoice':
        return (obj as dynamic).lastDayToInvoice;
      case 'externalId':
        return (obj as dynamic).externalId;
      case 'partnerLatitude':
        return (obj as dynamic).partnerLatitude;
      case 'partnerLongitude':
        return (obj as dynamic).partnerLongitude;
      case 'canUseCustomPayments':
        return (obj as dynamic).canUseCustomPayments;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'creditLastSyncDate':
        return (obj as dynamic).creditLastSyncDate;
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
    'uuid',
    'isSynced',
    'name',
    'displayName',
    'ref',
    'vat',
    'email',
    'phone',
    'mobile',
    'street',
    'street2',
    'city',
    'zip',
    'countryId',
    'countryName',
    'stateId',
    'stateName',
    'avatar128',
    'isCompany',
    'active',
    'parentId',
    'parentName',
    'commercialPartnerName',
    'propertyProductPricelistId',
    'propertyProductPricelistName',
    'propertyPaymentTermId',
    'propertyPaymentTermName',
    'lang',
    'comment',
    'creditLimit',
    'credit',
    'creditToInvoice',
    'allowOverCredit',
    'usePartnerCreditLimit',
    'totalOverdue',
    'overdueInvoicesCount',
    'oldestOverdueDays',
    'diasMaxFacturaPosterior',
    'tipoCliente',
    'canalCliente',
    'customerRank',
    'supplierRank',
    'aceptaCheques',
    'emitirFacturaFechaPosterior',
    'noInvoice',
    'lastDayToInvoice',
    'externalId',
    'partnerLatitude',
    'partnerLongitude',
    'canUseCustomPayments',
    'writeDate',
    'creditLastSyncDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'displayName',
    'ref',
    'vat',
    'email',
    'phone',
    'mobile',
    'street',
    'street2',
    'city',
    'zip',
    'countryId',
    'stateId',
    'avatar128',
    'isCompany',
    'active',
    'parentId',
    'propertyProductPricelistId',
    'propertyPaymentTermId',
    'lang',
    'comment',
    'creditLimit',
    'credit',
    'creditToInvoice',
    'allowOverCredit',
    'usePartnerCreditLimit',
    'totalOverdue',
    'overdueInvoicesCount',
    'oldestOverdueDays',
    'diasMaxFacturaPosterior',
    'tipoCliente',
    'canalCliente',
    'customerRank',
    'supplierRank',
    'aceptaCheques',
    'emitirFacturaFechaPosterior',
    'noInvoice',
    'lastDayToInvoice',
    'externalId',
    'partnerLatitude',
    'partnerLongitude',
    'canUseCustomPayments',
    'writeDate',
  ];
}

/// Global instance of ClientManager.
final clientManager = ClientManager();
