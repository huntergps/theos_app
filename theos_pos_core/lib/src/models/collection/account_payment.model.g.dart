// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_payment.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountPayment _$AccountPaymentFromJson(Map<String, dynamic> json) =>
    _AccountPayment(
      id: (json['id'] as num).toInt(),
      paymentUuid: json['paymentUuid'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
      collectionSessionId: (json['collectionSessionId'] as num?)?.toInt(),
      invoiceId: (json['invoiceId'] as num?)?.toInt(),
      partnerId: (json['partnerId'] as num?)?.toInt(),
      partnerName: json['partnerName'] as String?,
      journalId: (json['journalId'] as num?)?.toInt(),
      journalName: json['journalName'] as String?,
      paymentMethodLineId: (json['paymentMethodLineId'] as num?)?.toInt(),
      paymentMethodLineName: json['paymentMethodLineName'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentType: json['paymentType'] as String? ?? 'inbound',
      state: json['state'] as String? ?? 'draft',
      paymentOriginType: json['paymentOriginType'] as String?,
      paymentMethodCategory: json['paymentMethodCategory'] as String?,
      bankId: (json['bankId'] as num?)?.toInt(),
      bankName: json['bankName'] as String?,
      checkNumber: json['checkNumber'] as String?,
      checkAmountInWords: json['checkAmountInWords'] as String?,
      bankReferenceDate: json['bankReferenceDate'] == null
          ? null
          : DateTime.parse(json['bankReferenceDate'] as String),
      esPosfechado: json['esPosfechado'] as bool? ?? false,
      chequeRecibidoId: (json['chequeRecibidoId'] as num?)?.toInt(),
      cardBrandId: (json['cardBrandId'] as num?)?.toInt(),
      cardBrandName: json['cardBrandName'] as String?,
      cardType: json['cardType'] as String?,
      loteId: (json['loteId'] as num?)?.toInt(),
      cardHolderName: json['cardHolderName'] as String?,
      cardLast4: json['cardLast4'] as String?,
      authorizationCode: json['authorizationCode'] as String?,
      isCardPayment: json['isCardPayment'] as bool? ?? false,
      isTransferPayment: json['isTransferPayment'] as bool? ?? false,
      isCheckPayment: json['isCheckPayment'] as bool? ?? false,
      isCashPayment: json['isCashPayment'] as bool? ?? false,
      saleId: (json['saleId'] as num?)?.toInt(),
      advanceId: (json['advanceId'] as num?)?.toInt(),
      collectionUserId: (json['collectionUserId'] as num?)?.toInt(),
      date: json['date'] == null
          ? null
          : DateTime.parse(json['date'] as String),
      name: json['name'] as String?,
      ref: json['ref'] as String?,
      lastSyncDate: json['lastSyncDate'] == null
          ? null
          : DateTime.parse(json['lastSyncDate'] as String),
      writeDate: json['writeDate'] == null
          ? null
          : DateTime.parse(json['writeDate'] as String),
    );

Map<String, dynamic> _$AccountPaymentToJson(_AccountPayment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'paymentUuid': instance.paymentUuid,
      'isSynced': instance.isSynced,
      'collectionSessionId': instance.collectionSessionId,
      'invoiceId': instance.invoiceId,
      'partnerId': instance.partnerId,
      'partnerName': instance.partnerName,
      'journalId': instance.journalId,
      'journalName': instance.journalName,
      'paymentMethodLineId': instance.paymentMethodLineId,
      'paymentMethodLineName': instance.paymentMethodLineName,
      'amount': instance.amount,
      'paymentType': instance.paymentType,
      'state': instance.state,
      'paymentOriginType': instance.paymentOriginType,
      'paymentMethodCategory': instance.paymentMethodCategory,
      'bankId': instance.bankId,
      'bankName': instance.bankName,
      'checkNumber': instance.checkNumber,
      'checkAmountInWords': instance.checkAmountInWords,
      'bankReferenceDate': instance.bankReferenceDate?.toIso8601String(),
      'esPosfechado': instance.esPosfechado,
      'chequeRecibidoId': instance.chequeRecibidoId,
      'cardBrandId': instance.cardBrandId,
      'cardBrandName': instance.cardBrandName,
      'cardType': instance.cardType,
      'loteId': instance.loteId,
      'cardHolderName': instance.cardHolderName,
      'cardLast4': instance.cardLast4,
      'authorizationCode': instance.authorizationCode,
      'isCardPayment': instance.isCardPayment,
      'isTransferPayment': instance.isTransferPayment,
      'isCheckPayment': instance.isCheckPayment,
      'isCashPayment': instance.isCashPayment,
      'saleId': instance.saleId,
      'advanceId': instance.advanceId,
      'collectionUserId': instance.collectionUserId,
      'date': instance.date?.toIso8601String(),
      'name': instance.name,
      'ref': instance.ref,
      'lastSyncDate': instance.lastSyncDate?.toIso8601String(),
      'writeDate': instance.writeDate?.toIso8601String(),
    };

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for AccountPayment.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.payment
class AccountPaymentManager extends OdooModelManager<AccountPayment>
    with GenericDriftOperations<AccountPayment> {
  @override
  String get odooModel => 'account.payment';

  @override
  String get tableName => 'account_payment';

  @override
  List<String> get odooFields => [
    'id',
    'collection_session_id',
    'reconciled_invoice_ids',
    'partner_id',
    'journal_id',
    'payment_method_line_id',
    'amount',
    'payment_type',
    'state',
    'payment_origin_type',
    'payment_method_category',
    'bank_id',
    'check_number',
    'check_amount_in_words',
    'bank_reference_date',
    'es_posfechado',
    'cheque_recibido_id',
    'card_brand_id',
    'card_type',
    'lote_id',
    'card_holder_name',
    'card_last_4',
    'authorization_code',
    'is_card_payment',
    'is_transfer_payment',
    'is_check_payment',
    'is_cash_payment',
    'sale_id',
    'advance_id',
    'collection_user_id',
    'date',
    'name',
    'ref',
    'write_date',
  ];

  @override
  AccountPayment fromOdoo(Map<String, dynamic> data) {
    return AccountPayment(
      id: data['id'] as int? ?? 0,
      isSynced: false,
      collectionSessionId: extractMany2oneId(data['collection_session_id']),
      invoiceId: extractMany2oneId(data['reconciled_invoice_ids']),
      partnerId: extractMany2oneId(data['partner_id']),
      partnerName: extractMany2oneName(data['partner_id']),
      journalId: extractMany2oneId(data['journal_id']),
      journalName: extractMany2oneName(data['journal_id']),
      paymentMethodLineId: extractMany2oneId(data['payment_method_line_id']),
      paymentMethodLineName: extractMany2oneName(
        data['payment_method_line_id'],
      ),
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      paymentType: parseOdooSelection(data['payment_type']) ?? '',
      state: parseOdooSelection(data['state']) ?? '',
      paymentOriginType: parseOdooSelection(data['payment_origin_type']),
      paymentMethodCategory: parseOdooSelection(
        data['payment_method_category'],
      ),
      bankId: extractMany2oneId(data['bank_id']),
      bankName: extractMany2oneName(data['bank_id']),
      checkNumber: parseOdooString(data['check_number']),
      checkAmountInWords: parseOdooString(data['check_amount_in_words']),
      bankReferenceDate: parseOdooDate(data['bank_reference_date']),
      esPosfechado: parseOdooBool(data['es_posfechado']),
      chequeRecibidoId: extractMany2oneId(data['cheque_recibido_id']),
      cardBrandId: extractMany2oneId(data['card_brand_id']),
      cardBrandName: extractMany2oneName(data['card_brand_id']),
      cardType: parseOdooSelection(data['card_type']),
      loteId: extractMany2oneId(data['lote_id']),
      cardHolderName: parseOdooString(data['card_holder_name']),
      cardLast4: parseOdooString(data['card_last_4']),
      authorizationCode: parseOdooString(data['authorization_code']),
      isCardPayment: parseOdooBool(data['is_card_payment']),
      isTransferPayment: parseOdooBool(data['is_transfer_payment']),
      isCheckPayment: parseOdooBool(data['is_check_payment']),
      isCashPayment: parseOdooBool(data['is_cash_payment']),
      saleId: extractMany2oneId(data['sale_id']),
      advanceId: extractMany2oneId(data['advance_id']),
      collectionUserId: extractMany2oneId(data['collection_user_id']),
      date: parseOdooDate(data['date']),
      name: parseOdooString(data['name']),
      ref: parseOdooString(data['ref']),
      writeDate: parseOdooDateTime(data['write_date']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(AccountPayment record) {
    return {
      'collection_session_id': record.collectionSessionId,
      'reconciled_invoice_ids': record.invoiceId,
      'partner_id': record.partnerId,
      'journal_id': record.journalId,
      'payment_method_line_id': record.paymentMethodLineId,
      'amount': record.amount,
      'payment_type': record.paymentType,
      'state': record.state,
      'payment_origin_type': record.paymentOriginType,
      'payment_method_category': record.paymentMethodCategory,
      'bank_id': record.bankId,
      'check_number': record.checkNumber,
      'check_amount_in_words': record.checkAmountInWords,
      'bank_reference_date': formatOdooDate(record.bankReferenceDate),
      'es_posfechado': record.esPosfechado,
      'cheque_recibido_id': record.chequeRecibidoId,
      'card_brand_id': record.cardBrandId,
      'card_type': record.cardType,
      'lote_id': record.loteId,
      'card_holder_name': record.cardHolderName,
      'card_last_4': record.cardLast4,
      'authorization_code': record.authorizationCode,
      'is_card_payment': record.isCardPayment,
      'is_transfer_payment': record.isTransferPayment,
      'is_check_payment': record.isCheckPayment,
      'is_cash_payment': record.isCashPayment,
      'sale_id': record.saleId,
      'advance_id': record.advanceId,
      'collection_user_id': record.collectionUserId,
      'date': formatOdooDate(record.date),
      'name': record.name,
      'ref': record.ref,
      'write_date': formatOdooDateTime(record.writeDate),
    };
  }

  @override
  AccountPayment fromDrift(dynamic row) {
    return AccountPayment(
      id: row.odooId as int,
      paymentUuid: row.paymentUuid as String?,
      isSynced: row.isSynced as bool? ?? false,
      collectionSessionId: row.collectionSessionId as int?,
      invoiceId: row.invoiceId as int?,
      partnerId: row.partnerId as int?,
      partnerName: row.partnerName as String?,
      journalId: row.journalId as int?,
      journalName: row.journalName as String?,
      paymentMethodLineId: row.paymentMethodLineId as int?,
      paymentMethodLineName: row.paymentMethodLineName as String?,
      amount: row.amount as double,
      paymentType: row.paymentType as String,
      state: row.state as String,
      paymentOriginType: row.paymentOriginType as String?,
      paymentMethodCategory: row.paymentMethodCategory as String?,
      bankId: row.bankId as int?,
      bankName: row.bankName as String?,
      checkNumber: row.checkNumber as String?,
      checkAmountInWords: row.checkAmountInWords as String?,
      bankReferenceDate: row.bankReferenceDate as DateTime?,
      esPosfechado: row.esPosfechado as bool,
      chequeRecibidoId: row.chequeRecibidoId as int?,
      cardBrandId: row.cardBrandId as int?,
      cardBrandName: row.cardBrandName as String?,
      cardType: row.cardType as String?,
      loteId: row.loteId as int?,
      cardHolderName: row.cardHolderName as String?,
      cardLast4: row.cardLast4 as String?,
      authorizationCode: row.authorizationCode as String?,
      isCardPayment: row.isCardPayment as bool,
      isTransferPayment: row.isTransferPayment as bool,
      isCheckPayment: row.isCheckPayment as bool,
      isCashPayment: row.isCashPayment as bool,
      saleId: row.saleId as int?,
      advanceId: row.advanceId as int?,
      collectionUserId: row.collectionUserId as int?,
      date: row.date as DateTime?,
      name: row.name as String?,
      ref: row.ref as String?,
      lastSyncDate: row.lastSyncDate as DateTime?,
      writeDate: row.writeDate as DateTime?,
    );
  }

  @override
  int getId(AccountPayment record) => record.id;

  @override
  String? getUuid(AccountPayment record) => null;

  @override
  AccountPayment withIdAndUuid(AccountPayment record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  AccountPayment withSyncStatus(AccountPayment record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'collection_session_id': 'collectionSessionId',
    'reconciled_invoice_ids': 'invoiceId',
    'partner_id': 'partnerId',
    'journal_id': 'journalId',
    'payment_method_line_id': 'paymentMethodLineId',
    'amount': 'amount',
    'payment_type': 'paymentType',
    'state': 'state',
    'payment_origin_type': 'paymentOriginType',
    'payment_method_category': 'paymentMethodCategory',
    'bank_id': 'bankId',
    'check_number': 'checkNumber',
    'check_amount_in_words': 'checkAmountInWords',
    'bank_reference_date': 'bankReferenceDate',
    'es_posfechado': 'esPosfechado',
    'cheque_recibido_id': 'chequeRecibidoId',
    'card_brand_id': 'cardBrandId',
    'card_type': 'cardType',
    'lote_id': 'loteId',
    'card_holder_name': 'cardHolderName',
    'card_last_4': 'cardLast4',
    'authorization_code': 'authorizationCode',
    'is_card_payment': 'isCardPayment',
    'is_transfer_payment': 'isTransferPayment',
    'is_check_payment': 'isCheckPayment',
    'is_cash_payment': 'isCashPayment',
    'sale_id': 'saleId',
    'advance_id': 'advanceId',
    'collection_user_id': 'collectionUserId',
    'date': 'date',
    'name': 'name',
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
      throw StateError('Table \'account_payment\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(AccountPayment record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'collection_session_id': driftVar<int>(record.collectionSessionId),
      'reconciled_invoice_ids': driftVar<int>(record.invoiceId),
      'partner_id': driftVar<int>(record.partnerId),
      'partner_id_name': driftVar<String>(record.partnerName),
      'journal_id': driftVar<int>(record.journalId),
      'journal_id_name': driftVar<String>(record.journalName),
      'payment_method_line_id': driftVar<int>(record.paymentMethodLineId),
      'payment_method_line_id_name': driftVar<String>(
        record.paymentMethodLineName,
      ),
      'amount': Variable<double>(record.amount),
      'payment_type': Variable<String>(record.paymentType),
      'state': Variable<String>(record.state),
      'payment_origin_type': driftVar<String>(record.paymentOriginType),
      'payment_method_category': driftVar<String>(record.paymentMethodCategory),
      'bank_id': driftVar<int>(record.bankId),
      'bank_id_name': driftVar<String>(record.bankName),
      'check_number': driftVar<String>(record.checkNumber),
      'check_amount_in_words': driftVar<String>(record.checkAmountInWords),
      'bank_reference_date': driftVar<DateTime>(record.bankReferenceDate),
      'es_posfechado': Variable<bool>(record.esPosfechado),
      'cheque_recibido_id': driftVar<int>(record.chequeRecibidoId),
      'card_brand_id': driftVar<int>(record.cardBrandId),
      'card_brand_id_name': driftVar<String>(record.cardBrandName),
      'card_type': driftVar<String>(record.cardType),
      'lote_id': driftVar<int>(record.loteId),
      'card_holder_name': driftVar<String>(record.cardHolderName),
      'card_last_4': driftVar<String>(record.cardLast4),
      'authorization_code': driftVar<String>(record.authorizationCode),
      'is_card_payment': Variable<bool>(record.isCardPayment),
      'is_transfer_payment': Variable<bool>(record.isTransferPayment),
      'is_check_payment': Variable<bool>(record.isCheckPayment),
      'is_cash_payment': Variable<bool>(record.isCashPayment),
      'sale_id': driftVar<int>(record.saleId),
      'advance_id': driftVar<int>(record.advanceId),
      'collection_user_id': driftVar<int>(record.collectionUserId),
      'date': driftVar<DateTime>(record.date),
      'name': driftVar<String>(record.name),
      'ref': driftVar<String>(record.ref),
      'write_date': driftVar<DateTime>(record.writeDate),
      'payment_uuid': driftVar<String>(record.paymentUuid),
      'is_synced': Variable<bool>(record.isSynced),
      'last_sync_date': driftVar<DateTime>(record.lastSyncDate),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'collectionSessionId',
    'invoiceId',
    'partnerId',
    'journalId',
    'paymentMethodLineId',
    'amount',
    'paymentType',
    'state',
    'paymentOriginType',
    'paymentMethodCategory',
    'bankId',
    'checkNumber',
    'checkAmountInWords',
    'bankReferenceDate',
    'esPosfechado',
    'chequeRecibidoId',
    'cardBrandId',
    'cardType',
    'loteId',
    'cardHolderName',
    'cardLast4',
    'authorizationCode',
    'isCardPayment',
    'isTransferPayment',
    'isCheckPayment',
    'isCashPayment',
    'saleId',
    'advanceId',
    'collectionUserId',
    'date',
    'name',
    'ref',
    'writeDate',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'paymentUuid': 'Payment Uuid',
    'isSynced': 'Is Synced',
    'collectionSessionId': 'Collection Session Id',
    'invoiceId': 'Invoice Id',
    'partnerId': 'Partner Id',
    'partnerName': 'Partner Name',
    'journalId': 'Journal Id',
    'journalName': 'Journal Name',
    'paymentMethodLineId': 'Payment Method Line Id',
    'paymentMethodLineName': 'Payment Method Line Name',
    'amount': 'Amount',
    'paymentType': 'Payment Type',
    'state': 'State',
    'paymentOriginType': 'Payment Origin Type',
    'paymentMethodCategory': 'Payment Method Category',
    'bankId': 'Bank Id',
    'bankName': 'Bank Name',
    'checkNumber': 'Check Number',
    'checkAmountInWords': 'Check Amount In Words',
    'bankReferenceDate': 'Bank Reference Date',
    'esPosfechado': 'Es Posfechado',
    'chequeRecibidoId': 'Cheque Recibido Id',
    'cardBrandId': 'Card Brand Id',
    'cardBrandName': 'Card Brand Name',
    'cardType': 'Card Type',
    'loteId': 'Lote Id',
    'cardHolderName': 'Card Holder Name',
    'cardLast4': 'Card Last4',
    'authorizationCode': 'Authorization Code',
    'isCardPayment': 'Is Card Payment',
    'isTransferPayment': 'Is Transfer Payment',
    'isCheckPayment': 'Is Check Payment',
    'isCashPayment': 'Is Cash Payment',
    'saleId': 'Sale Id',
    'advanceId': 'Advance Id',
    'collectionUserId': 'Collection User Id',
    'date': 'Date',
    'name': 'Name',
    'ref': 'Ref',
    'lastSyncDate': 'Last Sync Date',
    'writeDate': 'Write Date',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(AccountPayment record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(AccountPayment record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(AccountPayment record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(AccountPayment record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'paymentUuid':
        return record.paymentUuid;
      case 'isSynced':
        return record.isSynced;
      case 'collectionSessionId':
        return record.collectionSessionId;
      case 'invoiceId':
        return record.invoiceId;
      case 'partnerId':
        return record.partnerId;
      case 'partnerName':
        return record.partnerName;
      case 'journalId':
        return record.journalId;
      case 'journalName':
        return record.journalName;
      case 'paymentMethodLineId':
        return record.paymentMethodLineId;
      case 'paymentMethodLineName':
        return record.paymentMethodLineName;
      case 'amount':
        return record.amount;
      case 'paymentType':
        return record.paymentType;
      case 'state':
        return record.state;
      case 'paymentOriginType':
        return record.paymentOriginType;
      case 'paymentMethodCategory':
        return record.paymentMethodCategory;
      case 'bankId':
        return record.bankId;
      case 'bankName':
        return record.bankName;
      case 'checkNumber':
        return record.checkNumber;
      case 'checkAmountInWords':
        return record.checkAmountInWords;
      case 'bankReferenceDate':
        return record.bankReferenceDate;
      case 'esPosfechado':
        return record.esPosfechado;
      case 'chequeRecibidoId':
        return record.chequeRecibidoId;
      case 'cardBrandId':
        return record.cardBrandId;
      case 'cardBrandName':
        return record.cardBrandName;
      case 'cardType':
        return record.cardType;
      case 'loteId':
        return record.loteId;
      case 'cardHolderName':
        return record.cardHolderName;
      case 'cardLast4':
        return record.cardLast4;
      case 'authorizationCode':
        return record.authorizationCode;
      case 'isCardPayment':
        return record.isCardPayment;
      case 'isTransferPayment':
        return record.isTransferPayment;
      case 'isCheckPayment':
        return record.isCheckPayment;
      case 'isCashPayment':
        return record.isCashPayment;
      case 'saleId':
        return record.saleId;
      case 'advanceId':
        return record.advanceId;
      case 'collectionUserId':
        return record.collectionUserId;
      case 'date':
        return record.date;
      case 'name':
        return record.name;
      case 'ref':
        return record.ref;
      case 'lastSyncDate':
        return record.lastSyncDate;
      case 'writeDate':
        return record.writeDate;
      default:
        return null;
    }
  }

  @override
  AccountPayment applyWebSocketChangesToRecord(
    AccountPayment record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      paymentUuid: record.paymentUuid,
      isSynced: record.isSynced,
      lastSyncDate: record.lastSyncDate,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'paymentUuid':
        return (obj as dynamic).paymentUuid;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'collectionSessionId':
        return (obj as dynamic).collectionSessionId;
      case 'invoiceId':
        return (obj as dynamic).invoiceId;
      case 'partnerId':
        return (obj as dynamic).partnerId;
      case 'partnerName':
        return (obj as dynamic).partnerName;
      case 'journalId':
        return (obj as dynamic).journalId;
      case 'journalName':
        return (obj as dynamic).journalName;
      case 'paymentMethodLineId':
        return (obj as dynamic).paymentMethodLineId;
      case 'paymentMethodLineName':
        return (obj as dynamic).paymentMethodLineName;
      case 'amount':
        return (obj as dynamic).amount;
      case 'paymentType':
        return (obj as dynamic).paymentType;
      case 'state':
        return (obj as dynamic).state;
      case 'paymentOriginType':
        return (obj as dynamic).paymentOriginType;
      case 'paymentMethodCategory':
        return (obj as dynamic).paymentMethodCategory;
      case 'bankId':
        return (obj as dynamic).bankId;
      case 'bankName':
        return (obj as dynamic).bankName;
      case 'checkNumber':
        return (obj as dynamic).checkNumber;
      case 'checkAmountInWords':
        return (obj as dynamic).checkAmountInWords;
      case 'bankReferenceDate':
        return (obj as dynamic).bankReferenceDate;
      case 'esPosfechado':
        return (obj as dynamic).esPosfechado;
      case 'chequeRecibidoId':
        return (obj as dynamic).chequeRecibidoId;
      case 'cardBrandId':
        return (obj as dynamic).cardBrandId;
      case 'cardBrandName':
        return (obj as dynamic).cardBrandName;
      case 'cardType':
        return (obj as dynamic).cardType;
      case 'loteId':
        return (obj as dynamic).loteId;
      case 'cardHolderName':
        return (obj as dynamic).cardHolderName;
      case 'cardLast4':
        return (obj as dynamic).cardLast4;
      case 'authorizationCode':
        return (obj as dynamic).authorizationCode;
      case 'isCardPayment':
        return (obj as dynamic).isCardPayment;
      case 'isTransferPayment':
        return (obj as dynamic).isTransferPayment;
      case 'isCheckPayment':
        return (obj as dynamic).isCheckPayment;
      case 'isCashPayment':
        return (obj as dynamic).isCashPayment;
      case 'saleId':
        return (obj as dynamic).saleId;
      case 'advanceId':
        return (obj as dynamic).advanceId;
      case 'collectionUserId':
        return (obj as dynamic).collectionUserId;
      case 'date':
        return (obj as dynamic).date;
      case 'name':
        return (obj as dynamic).name;
      case 'ref':
        return (obj as dynamic).ref;
      case 'lastSyncDate':
        return (obj as dynamic).lastSyncDate;
      case 'writeDate':
        return (obj as dynamic).writeDate;
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
    'paymentUuid',
    'isSynced',
    'collectionSessionId',
    'invoiceId',
    'partnerId',
    'partnerName',
    'journalId',
    'journalName',
    'paymentMethodLineId',
    'paymentMethodLineName',
    'amount',
    'paymentType',
    'state',
    'paymentOriginType',
    'paymentMethodCategory',
    'bankId',
    'bankName',
    'checkNumber',
    'checkAmountInWords',
    'bankReferenceDate',
    'esPosfechado',
    'chequeRecibidoId',
    'cardBrandId',
    'cardBrandName',
    'cardType',
    'loteId',
    'cardHolderName',
    'cardLast4',
    'authorizationCode',
    'isCardPayment',
    'isTransferPayment',
    'isCheckPayment',
    'isCashPayment',
    'saleId',
    'advanceId',
    'collectionUserId',
    'date',
    'name',
    'ref',
    'lastSyncDate',
    'writeDate',
  ];

  @override
  List<String> get writableFieldNames => const [
    'collectionSessionId',
    'invoiceId',
    'partnerId',
    'journalId',
    'paymentMethodLineId',
    'amount',
    'paymentType',
    'state',
    'paymentOriginType',
    'paymentMethodCategory',
    'bankId',
    'checkNumber',
    'checkAmountInWords',
    'bankReferenceDate',
    'esPosfechado',
    'chequeRecibidoId',
    'cardBrandId',
    'cardType',
    'loteId',
    'cardHolderName',
    'cardLast4',
    'authorizationCode',
    'isCardPayment',
    'isTransferPayment',
    'isCheckPayment',
    'isCashPayment',
    'saleId',
    'advanceId',
    'collectionUserId',
    'date',
    'name',
    'ref',
    'writeDate',
  ];
}

/// Global instance of AccountPaymentManager.
final accountPaymentManager = AccountPaymentManager();
