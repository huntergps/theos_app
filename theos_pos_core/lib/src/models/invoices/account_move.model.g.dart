// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_move.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountMove _$AccountMoveFromJson(Map<String, dynamic> json) => _AccountMove(
  id: (json['id'] as num?)?.toInt() ?? 0,
  name: json['name'] as String? ?? '',
  moveType: json['moveType'] as String? ?? 'out_invoice',
  l10nEcAuthorizationNumber: json['l10nEcAuthorizationNumber'] as String?,
  l10nEcAuthorizationDate: json['l10nEcAuthorizationDate'] == null
      ? null
      : DateTime.parse(json['l10nEcAuthorizationDate'] as String),
  l10nLatamDocumentNumber: json['l10nLatamDocumentNumber'] as String?,
  l10nLatamDocumentTypeId: (json['l10nLatamDocumentTypeId'] as num?)?.toInt(),
  l10nLatamDocumentTypeName: json['l10nLatamDocumentTypeName'] as String?,
  l10nEcSriPaymentName: json['l10nEcSriPaymentName'] as String?,
  state: json['state'] as String? ?? 'draft',
  paymentState: json['paymentState'] as String?,
  invoiceDate: json['invoiceDate'] == null
      ? null
      : DateTime.parse(json['invoiceDate'] as String),
  invoiceDateDue: json['invoiceDateDue'] == null
      ? null
      : DateTime.parse(json['invoiceDateDue'] as String),
  date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
  partnerId: (json['partnerId'] as num?)?.toInt(),
  partnerName: json['partnerName'] as String?,
  partnerVat: json['partnerVat'] as String?,
  partnerStreet: json['partnerStreet'] as String?,
  partnerCity: json['partnerCity'] as String?,
  partnerPhone: json['partnerPhone'] as String?,
  partnerEmail: json['partnerEmail'] as String?,
  journalId: (json['journalId'] as num?)?.toInt(),
  journalName: json['journalName'] as String?,
  amountUntaxed: (json['amountUntaxed'] as num?)?.toDouble() ?? 0.0,
  amountTax: (json['amountTax'] as num?)?.toDouble() ?? 0.0,
  amountTotal: (json['amountTotal'] as num?)?.toDouble() ?? 0.0,
  amountResidual: (json['amountResidual'] as num?)?.toDouble() ?? 0.0,
  companyId: (json['companyId'] as num?)?.toInt(),
  currencyId: (json['currencyId'] as num?)?.toInt(),
  currencySymbol: json['currencySymbol'] as String?,
  invoiceOrigin: json['invoiceOrigin'] as String?,
  ref: json['ref'] as String?,
  saleOrderId: (json['saleOrderId'] as num?)?.toInt(),
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => AccountMoveLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  writeDate: json['writeDate'] == null
      ? null
      : DateTime.parse(json['writeDate'] as String),
  lastSyncDate: json['lastSyncDate'] == null
      ? null
      : DateTime.parse(json['lastSyncDate'] as String),
);

Map<String, dynamic> _$AccountMoveToJson(_AccountMove instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'moveType': instance.moveType,
      'l10nEcAuthorizationNumber': instance.l10nEcAuthorizationNumber,
      'l10nEcAuthorizationDate': instance.l10nEcAuthorizationDate
          ?.toIso8601String(),
      'l10nLatamDocumentNumber': instance.l10nLatamDocumentNumber,
      'l10nLatamDocumentTypeId': instance.l10nLatamDocumentTypeId,
      'l10nLatamDocumentTypeName': instance.l10nLatamDocumentTypeName,
      'l10nEcSriPaymentName': instance.l10nEcSriPaymentName,
      'state': instance.state,
      'paymentState': instance.paymentState,
      'invoiceDate': instance.invoiceDate?.toIso8601String(),
      'invoiceDateDue': instance.invoiceDateDue?.toIso8601String(),
      'date': instance.date?.toIso8601String(),
      'partnerId': instance.partnerId,
      'partnerName': instance.partnerName,
      'partnerVat': instance.partnerVat,
      'partnerStreet': instance.partnerStreet,
      'partnerCity': instance.partnerCity,
      'partnerPhone': instance.partnerPhone,
      'partnerEmail': instance.partnerEmail,
      'journalId': instance.journalId,
      'journalName': instance.journalName,
      'amountUntaxed': instance.amountUntaxed,
      'amountTax': instance.amountTax,
      'amountTotal': instance.amountTotal,
      'amountResidual': instance.amountResidual,
      'companyId': instance.companyId,
      'currencyId': instance.currencyId,
      'currencySymbol': instance.currencySymbol,
      'invoiceOrigin': instance.invoiceOrigin,
      'ref': instance.ref,
      'saleOrderId': instance.saleOrderId,
      'lines': instance.lines,
      'writeDate': instance.writeDate?.toIso8601String(),
      'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
    };

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for AccountMove.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.move
class AccountMoveManager extends OdooModelManager<AccountMove>
    with GenericDriftOperations<AccountMove> {
  @override
  String get odooModel => 'account.move';

  @override
  String get tableName => 'account_move';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'move_type',
    'l10n_ec_authorization_number',
    'l10n_ec_authorization_date',
    'l10n_latam_document_number',
    'l10n_latam_document_type_id',
    'state',
    'payment_state',
    'invoice_date',
    'invoice_date_due',
    'date',
    'partner_id',
    'partner_vat',
    'journal_id',
    'amount_untaxed',
    'amount_tax',
    'amount_total',
    'amount_residual',
    'company_id',
    'currency_id',
    'invoice_origin',
    'ref',
    'write_date',
  ];

  @override
  AccountMove fromOdoo(Map<String, dynamic> data) {
    return AccountMove(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      moveType: parseOdooSelection(data['move_type']) ?? '',
      l10nEcAuthorizationNumber: parseOdooString(
        data['l10n_ec_authorization_number'],
      ),
      l10nEcAuthorizationDate: parseOdooDateTime(
        data['l10n_ec_authorization_date'],
      ),
      l10nLatamDocumentNumber: parseOdooString(
        data['l10n_latam_document_number'],
      ),
      l10nLatamDocumentTypeId: extractMany2oneId(
        data['l10n_latam_document_type_id'],
      ),
      l10nLatamDocumentTypeName: extractMany2oneName(
        data['l10n_latam_document_type_id'],
      ),
      l10nEcSriPaymentName: extractMany2oneName(data['l10n_ec_sri_payment_id']),
      state: parseOdooSelection(data['state']) ?? '',
      paymentState: parseOdooSelection(data['payment_state']),
      invoiceDate: parseOdooDate(data['invoice_date']),
      invoiceDateDue: parseOdooDate(data['invoice_date_due']),
      date: parseOdooDate(data['date']),
      partnerId: extractMany2oneId(data['partner_id']),
      partnerName: extractMany2oneName(data['partner_id']),
      partnerVat: parseOdooString(data['partner_vat']),
      journalId: extractMany2oneId(data['journal_id']),
      journalName: extractMany2oneName(data['journal_id']),
      amountUntaxed: parseOdooDouble(data['amount_untaxed']) ?? 0.0,
      amountTax: parseOdooDouble(data['amount_tax']) ?? 0.0,
      amountTotal: parseOdooDouble(data['amount_total']) ?? 0.0,
      amountResidual: parseOdooDouble(data['amount_residual']) ?? 0.0,
      companyId: extractMany2oneId(data['company_id']),
      currencyId: extractMany2oneId(data['currency_id']),
      currencySymbol: extractMany2oneName(data['currency_id']),
      invoiceOrigin: parseOdooString(data['invoice_origin']),
      ref: parseOdooString(data['ref']),
      lines: const [],
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(AccountMove record) {
    return {
      'name': record.name,
      'move_type': record.moveType,
      'l10n_ec_authorization_number': record.l10nEcAuthorizationNumber,
      'l10n_ec_authorization_date': formatOdooDateTime(
        record.l10nEcAuthorizationDate,
      ),
      'l10n_latam_document_number': record.l10nLatamDocumentNumber,
      'l10n_latam_document_type_id': record.l10nLatamDocumentTypeId,
      'state': record.state,
      'payment_state': record.paymentState,
      'invoice_date': formatOdooDate(record.invoiceDate),
      'invoice_date_due': formatOdooDate(record.invoiceDateDue),
      'date': formatOdooDate(record.date),
      'partner_id': record.partnerId,
      'partner_vat': record.partnerVat,
      'journal_id': record.journalId,
      'amount_untaxed': record.amountUntaxed,
      'amount_tax': record.amountTax,
      'amount_total': record.amountTotal,
      'amount_residual': record.amountResidual,
      'company_id': record.companyId,
      'currency_id': record.currencyId,
      'invoice_origin': record.invoiceOrigin,
      'ref': record.ref,
      'write_date': formatOdooDateTime(record.writeDate),
    };
  }

  @override
  AccountMove fromDrift(dynamic row) {
    return AccountMove(
      id: row.odooId as int,
      name: row.name as String,
      moveType: row.moveType as String,
      l10nEcAuthorizationNumber: row.l10nEcAuthorizationNumber as String?,
      l10nEcAuthorizationDate: row.l10nEcAuthorizationDate as DateTime?,
      l10nLatamDocumentNumber: row.l10nLatamDocumentNumber as String?,
      l10nLatamDocumentTypeId: row.l10nLatamDocumentTypeId as int?,
      l10nLatamDocumentTypeName: row.l10nLatamDocumentTypeName as String?,
      l10nEcSriPaymentName: row.l10nEcSriPaymentName as String?,
      state: row.state as String,
      paymentState: row.paymentState as String?,
      invoiceDate: row.invoiceDate as DateTime?,
      invoiceDateDue: row.invoiceDateDue as DateTime?,
      date: row.date as DateTime?,
      partnerId: row.partnerId as int?,
      partnerName: row.partnerName as String?,
      partnerVat: row.partnerVat as String?,
      partnerStreet: row.partnerStreet as String?,
      partnerCity: row.partnerCity as String?,
      partnerPhone: row.partnerPhone as String?,
      partnerEmail: row.partnerEmail as String?,
      journalId: row.journalId as int?,
      journalName: row.journalName as String?,
      amountUntaxed: row.amountUntaxed as double,
      amountTax: row.amountTax as double,
      amountTotal: row.amountTotal as double,
      amountResidual: row.amountResidual as double,
      companyId: row.companyId as int?,
      currencyId: row.currencyId as int?,
      currencySymbol: row.currencySymbol as String?,
      invoiceOrigin: row.invoiceOrigin as String?,
      ref: row.ref as String?,
      saleOrderId: row.saleOrderId as int?,
      writeDate: row.writeDate as DateTime?,
      lastSyncDate: row.lastSyncDate as DateTime?,
    );
  }

  @override
  int getId(AccountMove record) => record.id;

  @override
  String? getUuid(AccountMove record) => null;

  @override
  AccountMove withIdAndUuid(AccountMove record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  AccountMove withSyncStatus(AccountMove record, bool isSynced) {
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
    'move_type': 'moveType',
    'l10n_ec_authorization_number': 'l10nEcAuthorizationNumber',
    'l10n_ec_authorization_date': 'l10nEcAuthorizationDate',
    'l10n_latam_document_number': 'l10nLatamDocumentNumber',
    'l10n_latam_document_type_id': 'l10nLatamDocumentTypeId',
    'state': 'state',
    'payment_state': 'paymentState',
    'invoice_date': 'invoiceDate',
    'invoice_date_due': 'invoiceDateDue',
    'date': 'date',
    'partner_id': 'partnerId',
    'partner_vat': 'partnerVat',
    'journal_id': 'journalId',
    'amount_untaxed': 'amountUntaxed',
    'amount_tax': 'amountTax',
    'amount_total': 'amountTotal',
    'amount_residual': 'amountResidual',
    'company_id': 'companyId',
    'currency_id': 'currencyId',
    'invoice_origin': 'invoiceOrigin',
    'ref': 'ref',
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
      throw StateError('Table \'account_move\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(AccountMove record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'move_type': Variable<String>(record.moveType),
      'l10n_ec_authorization_number': driftVar<String>(
        record.l10nEcAuthorizationNumber,
      ),
      'l10n_ec_authorization_date': driftVar<DateTime>(
        record.l10nEcAuthorizationDate,
      ),
      'l10n_latam_document_number': driftVar<String>(
        record.l10nLatamDocumentNumber,
      ),
      'l10n_latam_document_type_id': driftVar<int>(
        record.l10nLatamDocumentTypeId,
      ),
      'l10n_latam_document_type_id_name': driftVar<String>(
        record.l10nLatamDocumentTypeName,
      ),
      'l10n_ec_sri_payment_id_name': driftVar<String>(
        record.l10nEcSriPaymentName,
      ),
      'state': Variable<String>(record.state),
      'payment_state': driftVar<String>(record.paymentState),
      'invoice_date': driftVar<DateTime>(record.invoiceDate),
      'invoice_date_due': driftVar<DateTime>(record.invoiceDateDue),
      'date': driftVar<DateTime>(record.date),
      'partner_id': driftVar<int>(record.partnerId),
      'partner_id_name': driftVar<String>(record.partnerName),
      'partner_vat': driftVar<String>(record.partnerVat),
      'journal_id': driftVar<int>(record.journalId),
      'journal_id_name': driftVar<String>(record.journalName),
      'amount_untaxed': Variable<double>(record.amountUntaxed),
      'amount_tax': Variable<double>(record.amountTax),
      'amount_total': Variable<double>(record.amountTotal),
      'amount_residual': Variable<double>(record.amountResidual),
      'company_id': driftVar<int>(record.companyId),
      'currency_id': driftVar<int>(record.currencyId),
      'currency_id_name': driftVar<String>(record.currencySymbol),
      'invoice_origin': driftVar<String>(record.invoiceOrigin),
      'ref': driftVar<String>(record.ref),
      'write_date': driftVar<DateTime>(record.writeDate),
      'partner_street': driftVar<String>(record.partnerStreet),
      'partner_city': driftVar<String>(record.partnerCity),
      'partner_phone': driftVar<String>(record.partnerPhone),
      'partner_email': driftVar<String>(record.partnerEmail),
      'sale_order_id': driftVar<int>(record.saleOrderId),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'moveType',
    'l10nEcAuthorizationNumber',
    'l10nEcAuthorizationDate',
    'l10nLatamDocumentNumber',
    'l10nLatamDocumentTypeId',
    'state',
    'paymentState',
    'invoiceDate',
    'invoiceDateDue',
    'date',
    'partnerId',
    'partnerVat',
    'journalId',
    'amountUntaxed',
    'amountTax',
    'amountTotal',
    'amountResidual',
    'companyId',
    'currencyId',
    'invoiceOrigin',
    'ref',
    'writeDate',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'name': 'Name',
    'moveType': 'Move Type',
    'l10nEcAuthorizationNumber': 'L10n Ec Authorization Number',
    'l10nEcAuthorizationDate': 'L10n Ec Authorization Date',
    'l10nLatamDocumentNumber': 'L10n Latam Document Number',
    'l10nLatamDocumentTypeId': 'L10n Latam Document Type Id',
    'l10nLatamDocumentTypeName': 'L10n Latam Document Type Name',
    'l10nEcSriPaymentName': 'L10n Ec Sri Payment Name',
    'state': 'State',
    'paymentState': 'Payment State',
    'invoiceDate': 'Invoice Date',
    'invoiceDateDue': 'Invoice Date Due',
    'date': 'Date',
    'partnerId': 'Partner Id',
    'partnerName': 'Partner Name',
    'partnerVat': 'Partner Vat',
    'partnerStreet': 'Partner Street',
    'partnerCity': 'Partner City',
    'partnerPhone': 'Partner Phone',
    'partnerEmail': 'Partner Email',
    'journalId': 'Journal Id',
    'journalName': 'Journal Name',
    'amountUntaxed': 'Amount Untaxed',
    'amountTax': 'Amount Tax',
    'amountTotal': 'Amount Total',
    'amountResidual': 'Amount Residual',
    'companyId': 'Company Id',
    'currencyId': 'Currency Id',
    'currencySymbol': 'Currency Symbol',
    'invoiceOrigin': 'Invoice Origin',
    'ref': 'Ref',
    'saleOrderId': 'Sale Order Id',
    'lines': 'Lines',
    'writeDate': 'Write Date',
    'lastSyncDate': 'Last Sync Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(AccountMove record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(AccountMove record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(AccountMove record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(AccountMove record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'name':
        return record.name;
      case 'moveType':
        return record.moveType;
      case 'l10nEcAuthorizationNumber':
        return record.l10nEcAuthorizationNumber;
      case 'l10nEcAuthorizationDate':
        return record.l10nEcAuthorizationDate;
      case 'l10nLatamDocumentNumber':
        return record.l10nLatamDocumentNumber;
      case 'l10nLatamDocumentTypeId':
        return record.l10nLatamDocumentTypeId;
      case 'l10nLatamDocumentTypeName':
        return record.l10nLatamDocumentTypeName;
      case 'l10nEcSriPaymentName':
        return record.l10nEcSriPaymentName;
      case 'state':
        return record.state;
      case 'paymentState':
        return record.paymentState;
      case 'invoiceDate':
        return record.invoiceDate;
      case 'invoiceDateDue':
        return record.invoiceDateDue;
      case 'date':
        return record.date;
      case 'partnerId':
        return record.partnerId;
      case 'partnerName':
        return record.partnerName;
      case 'partnerVat':
        return record.partnerVat;
      case 'partnerStreet':
        return record.partnerStreet;
      case 'partnerCity':
        return record.partnerCity;
      case 'partnerPhone':
        return record.partnerPhone;
      case 'partnerEmail':
        return record.partnerEmail;
      case 'journalId':
        return record.journalId;
      case 'journalName':
        return record.journalName;
      case 'amountUntaxed':
        return record.amountUntaxed;
      case 'amountTax':
        return record.amountTax;
      case 'amountTotal':
        return record.amountTotal;
      case 'amountResidual':
        return record.amountResidual;
      case 'companyId':
        return record.companyId;
      case 'currencyId':
        return record.currencyId;
      case 'currencySymbol':
        return record.currencySymbol;
      case 'invoiceOrigin':
        return record.invoiceOrigin;
      case 'ref':
        return record.ref;
      case 'saleOrderId':
        return record.saleOrderId;
      case 'lines':
        return record.lines;
      case 'writeDate':
        return record.writeDate;
      case 'lastSyncDate':
        return record.lastSyncDate;
      default:
        return null;
    }
  }

  @override
  AccountMove applyWebSocketChangesToRecord(
    AccountMove record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      partnerStreet: record.partnerStreet,
      partnerCity: record.partnerCity,
      partnerPhone: record.partnerPhone,
      partnerEmail: record.partnerEmail,
      saleOrderId: record.saleOrderId,
      lines: record.lines,
      lastSyncDate: record.lastSyncDate,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'name':
        return (obj as dynamic).name;
      case 'moveType':
        return (obj as dynamic).moveType;
      case 'l10nEcAuthorizationNumber':
        return (obj as dynamic).l10nEcAuthorizationNumber;
      case 'l10nEcAuthorizationDate':
        return (obj as dynamic).l10nEcAuthorizationDate;
      case 'l10nLatamDocumentNumber':
        return (obj as dynamic).l10nLatamDocumentNumber;
      case 'l10nLatamDocumentTypeId':
        return (obj as dynamic).l10nLatamDocumentTypeId;
      case 'l10nLatamDocumentTypeName':
        return (obj as dynamic).l10nLatamDocumentTypeName;
      case 'l10nEcSriPaymentName':
        return (obj as dynamic).l10nEcSriPaymentName;
      case 'state':
        return (obj as dynamic).state;
      case 'paymentState':
        return (obj as dynamic).paymentState;
      case 'invoiceDate':
        return (obj as dynamic).invoiceDate;
      case 'invoiceDateDue':
        return (obj as dynamic).invoiceDateDue;
      case 'date':
        return (obj as dynamic).date;
      case 'partnerId':
        return (obj as dynamic).partnerId;
      case 'partnerName':
        return (obj as dynamic).partnerName;
      case 'partnerVat':
        return (obj as dynamic).partnerVat;
      case 'partnerStreet':
        return (obj as dynamic).partnerStreet;
      case 'partnerCity':
        return (obj as dynamic).partnerCity;
      case 'partnerPhone':
        return (obj as dynamic).partnerPhone;
      case 'partnerEmail':
        return (obj as dynamic).partnerEmail;
      case 'journalId':
        return (obj as dynamic).journalId;
      case 'journalName':
        return (obj as dynamic).journalName;
      case 'amountUntaxed':
        return (obj as dynamic).amountUntaxed;
      case 'amountTax':
        return (obj as dynamic).amountTax;
      case 'amountTotal':
        return (obj as dynamic).amountTotal;
      case 'amountResidual':
        return (obj as dynamic).amountResidual;
      case 'companyId':
        return (obj as dynamic).companyId;
      case 'currencyId':
        return (obj as dynamic).currencyId;
      case 'currencySymbol':
        return (obj as dynamic).currencySymbol;
      case 'invoiceOrigin':
        return (obj as dynamic).invoiceOrigin;
      case 'ref':
        return (obj as dynamic).ref;
      case 'saleOrderId':
        return (obj as dynamic).saleOrderId;
      case 'lines':
        return (obj as dynamic).lines;
      case 'writeDate':
        return (obj as dynamic).writeDate;
      case 'lastSyncDate':
        return (obj as dynamic).lastSyncDate;
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
    'moveType',
    'l10nEcAuthorizationNumber',
    'l10nEcAuthorizationDate',
    'l10nLatamDocumentNumber',
    'l10nLatamDocumentTypeId',
    'l10nLatamDocumentTypeName',
    'l10nEcSriPaymentName',
    'state',
    'paymentState',
    'invoiceDate',
    'invoiceDateDue',
    'date',
    'partnerId',
    'partnerName',
    'partnerVat',
    'partnerStreet',
    'partnerCity',
    'partnerPhone',
    'partnerEmail',
    'journalId',
    'journalName',
    'amountUntaxed',
    'amountTax',
    'amountTotal',
    'amountResidual',
    'companyId',
    'currencyId',
    'currencySymbol',
    'invoiceOrigin',
    'ref',
    'saleOrderId',
    'lines',
    'writeDate',
    'lastSyncDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'moveType',
    'l10nEcAuthorizationNumber',
    'l10nEcAuthorizationDate',
    'l10nLatamDocumentNumber',
    'l10nLatamDocumentTypeId',
    'state',
    'paymentState',
    'invoiceDate',
    'invoiceDateDue',
    'date',
    'partnerId',
    'partnerVat',
    'journalId',
    'amountUntaxed',
    'amountTax',
    'amountTotal',
    'amountResidual',
    'companyId',
    'currencyId',
    'invoiceOrigin',
    'ref',
    'writeDate',
  ];
}

/// Global instance of AccountMoveManager.
final accountMoveManager = AccountMoveManager();
