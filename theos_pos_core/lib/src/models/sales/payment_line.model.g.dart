// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_line.model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentLine _$PaymentLineFromJson(Map<String, dynamic> json) => _PaymentLine(
  id: (json['id'] as num?)?.toInt() ?? 0,
  lineUuid: json['lineUuid'] as String?,
  uuid: json['uuid'] as String?,
  isSynced: json['isSynced'] as bool? ?? false,
  type: $enumDecode(_$PaymentLineTypeEnumMap, json['type']),
  date: DateTime.parse(json['date'] as String),
  amount: (json['amount'] as num).toDouble(),
  reference: json['reference'] as String?,
  orderId: (json['orderId'] as num?)?.toInt(),
  state: json['state'] as String? ?? 'draft',
  journalId: (json['journalId'] as num?)?.toInt(),
  journalName: json['journalName'] as String?,
  journalType: json['journalType'] as String?,
  paymentMethodId: (json['paymentMethodId'] as num?)?.toInt(),
  paymentMethodLineId: (json['paymentMethodLineId'] as num?)?.toInt(),
  paymentMethodCode: json['paymentMethodCode'] as String?,
  paymentMethodName: json['paymentMethodName'] as String?,
  bankId: (json['bankId'] as num?)?.toInt(),
  bankName: json['bankName'] as String?,
  cardType: $enumDecodeNullable(_$CardTypeEnumMap, json['cardType']),
  cardBrandId: (json['cardBrandId'] as num?)?.toInt(),
  cardBrandName: json['cardBrandName'] as String?,
  cardDeadlineId: (json['cardDeadlineId'] as num?)?.toInt(),
  cardDeadlineName: json['cardDeadlineName'] as String?,
  loteId: (json['loteId'] as num?)?.toInt(),
  loteName: json['loteName'] as String?,
  voucherDate: json['voucherDate'] == null
      ? null
      : DateTime.parse(json['voucherDate'] as String),
  partnerBankId: (json['partnerBankId'] as num?)?.toInt(),
  partnerBankName: json['partnerBankName'] as String?,
  effectiveDate: json['effectiveDate'] == null
      ? null
      : DateTime.parse(json['effectiveDate'] as String),
  advanceId: (json['advanceId'] as num?)?.toInt(),
  advanceName: json['advanceName'] as String?,
  advanceAvailable: (json['advanceAvailable'] as num?)?.toDouble(),
  creditNoteId: (json['creditNoteId'] as num?)?.toInt(),
  creditNoteName: json['creditNoteName'] as String?,
  creditNoteAvailable: (json['creditNoteAvailable'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PaymentLineToJson(_PaymentLine instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lineUuid': instance.lineUuid,
      'uuid': instance.uuid,
      'isSynced': instance.isSynced,
      'type': _$PaymentLineTypeEnumMap[instance.type]!,
      'date': instance.date.toIso8601String(),
      'amount': instance.amount,
      'reference': instance.reference,
      'orderId': instance.orderId,
      'state': instance.state,
      'journalId': instance.journalId,
      'journalName': instance.journalName,
      'journalType': instance.journalType,
      'paymentMethodId': instance.paymentMethodId,
      'paymentMethodLineId': instance.paymentMethodLineId,
      'paymentMethodCode': instance.paymentMethodCode,
      'paymentMethodName': instance.paymentMethodName,
      'bankId': instance.bankId,
      'bankName': instance.bankName,
      'cardType': _$CardTypeEnumMap[instance.cardType],
      'cardBrandId': instance.cardBrandId,
      'cardBrandName': instance.cardBrandName,
      'cardDeadlineId': instance.cardDeadlineId,
      'cardDeadlineName': instance.cardDeadlineName,
      'loteId': instance.loteId,
      'loteName': instance.loteName,
      'voucherDate': instance.voucherDate?.toIso8601String(),
      'partnerBankId': instance.partnerBankId,
      'partnerBankName': instance.partnerBankName,
      'effectiveDate': instance.effectiveDate?.toIso8601String(),
      'advanceId': instance.advanceId,
      'advanceName': instance.advanceName,
      'advanceAvailable': instance.advanceAvailable,
      'creditNoteId': instance.creditNoteId,
      'creditNoteName': instance.creditNoteName,
      'creditNoteAvailable': instance.creditNoteAvailable,
    };

const _$PaymentLineTypeEnumMap = {
  PaymentLineType.payment: 'payment',
  PaymentLineType.advance: 'advance',
  PaymentLineType.creditNote: 'creditNote',
};

const _$CardTypeEnumMap = {CardType.credit: 'credit', CardType.debit: 'debit'};

_AvailableJournal _$AvailableJournalFromJson(Map<String, dynamic> json) =>
    _AvailableJournal(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      type: json['type'] as String,
      isCardJournal: json['isCardJournal'] as bool? ?? false,
      paymentMethods:
          (json['paymentMethods'] as List<dynamic>?)
              ?.map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      cardBrandIds:
          (json['cardBrandIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      defaultCardBrandId: (json['defaultCardBrandId'] as num?)?.toInt(),
      deadlineCreditIds:
          (json['deadlineCreditIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      deadlineDebitIds:
          (json['deadlineDebitIds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      defaultDeadlineCreditId: (json['defaultDeadlineCreditId'] as num?)
          ?.toInt(),
      defaultDeadlineDebitId: (json['defaultDeadlineDebitId'] as num?)?.toInt(),
    );

Map<String, dynamic> _$AvailableJournalToJson(_AvailableJournal instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'isCardJournal': instance.isCardJournal,
      'paymentMethods': instance.paymentMethods,
      'cardBrandIds': instance.cardBrandIds,
      'defaultCardBrandId': instance.defaultCardBrandId,
      'deadlineCreditIds': instance.deadlineCreditIds,
      'deadlineDebitIds': instance.deadlineDebitIds,
      'defaultDeadlineCreditId': instance.defaultDeadlineCreditId,
      'defaultDeadlineDebitId': instance.defaultDeadlineDebitId,
    };

_PaymentMethod _$PaymentMethodFromJson(Map<String, dynamic> json) =>
    _PaymentMethod(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      spanishName: json['spanishName'] as String?,
      code: json['code'] as String,
    );

Map<String, dynamic> _$PaymentMethodToJson(_PaymentMethod instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'spanishName': instance.spanishName,
      'code': instance.code,
    };

_AvailableAdvance _$AvailableAdvanceFromJson(Map<String, dynamic> json) =>
    _AvailableAdvance(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      amountAvailable: (json['amountAvailable'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      reference: json['reference'] as String?,
    );

Map<String, dynamic> _$AvailableAdvanceToJson(_AvailableAdvance instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'amountAvailable': instance.amountAvailable,
      'date': instance.date.toIso8601String(),
      'reference': instance.reference,
    };

_AvailableCreditNote _$AvailableCreditNoteFromJson(Map<String, dynamic> json) =>
    _AvailableCreditNote(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      amountResidual: (json['amountResidual'] as num).toDouble(),
      invoiceDate: json['invoiceDate'] == null
          ? null
          : DateTime.parse(json['invoiceDate'] as String),
      ref: json['ref'] as String?,
    );

Map<String, dynamic> _$AvailableCreditNoteToJson(
  _AvailableCreditNote instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'amountResidual': instance.amountResidual,
  'invoiceDate': instance.invoiceDate?.toIso8601String(),
  'ref': instance.ref,
};

_AvailableBank _$AvailableBankFromJson(Map<String, dynamic> json) =>
    _AvailableBank(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );

Map<String, dynamic> _$AvailableBankToJson(_AvailableBank instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_CardBrand _$CardBrandFromJson(Map<String, dynamic> json) =>
    _CardBrand(id: (json['id'] as num).toInt(), name: json['name'] as String);

Map<String, dynamic> _$CardBrandToJson(_CardBrand instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_CardDeadline _$CardDeadlineFromJson(Map<String, dynamic> json) =>
    _CardDeadline(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      deadlineDays: (json['deadlineDays'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$CardDeadlineToJson(_CardDeadline instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'deadlineDays': instance.deadlineDays,
      'percentage': instance.percentage,
    };

_CardLote _$CardLoteFromJson(Map<String, dynamic> json) => _CardLote(
  id: (json['id'] as num?)?.toInt() ?? 0,
  localId: (json['localId'] as num?)?.toInt(),
  loteUuid: json['loteUuid'] as String?,
  name: json['name'] as String,
  journalId: (json['journalId'] as num).toInt(),
  journalName: json['journalName'] as String?,
  state: json['state'] as String? ?? 'open',
  date: json['date'] == null ? null : DateTime.parse(json['date'] as String),
  numeroLote: json['numeroLote'] as String?,
  amountTotal: (json['amountTotal'] as num?)?.toDouble() ?? 0,
  amountBalance: (json['amountBalance'] as num?)?.toDouble() ?? 0,
  paymentCount: (json['paymentCount'] as num?)?.toInt() ?? 0,
  isPosLote: json['isPosLote'] as bool? ?? false,
);

Map<String, dynamic> _$CardLoteToJson(_CardLote instance) => <String, dynamic>{
  'id': instance.id,
  'localId': instance.localId,
  'loteUuid': instance.loteUuid,
  'name': instance.name,
  'journalId': instance.journalId,
  'journalName': instance.journalName,
  'state': instance.state,
  'date': instance.date?.toIso8601String(),
  'numeroLote': instance.numeroLote,
  'amountTotal': instance.amountTotal,
  'amountBalance': instance.amountBalance,
  'paymentCount': instance.paymentCount,
  'isPosLote': instance.isPosLote,
};

// **************************************************************************
// OdooModelGenerator
// **************************************************************************

/// Generated manager for PaymentLine.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.payment.line
class PaymentLineManager extends OdooModelManager<PaymentLine>
    with GenericDriftOperations<PaymentLine> {
  @override
  String get odooModel => 'account.payment.line';

  @override
  String get tableName => 'sale_order_payment_line';

  @override
  List<String> get odooFields => [
    'id',
    'date',
    'amount',
    'payment_reference',
    'state',
    'journal_id',
    'payment_method_line_id',
    'bank_id',
    'card_brand_id',
    'card_deadline_id',
    'lote_id',
    'bank_reference_date',
    'partner_bank_id',
    'effective_date',
    'advance_id',
    'credit_note_id',
  ];

  @override
  PaymentLine fromOdoo(Map<String, dynamic> data) {
    return PaymentLine(
      id: data['id'] as int? ?? 0,
      isSynced: false,
      type: PaymentLineType.values.first,
      date: parseOdooDate(data['date']) ?? DateTime(1970),
      amount: parseOdooDouble(data['amount']) ?? 0.0,
      reference: parseOdooString(data['payment_reference']),
      state: parseOdooSelection(data['state']) ?? '',
      journalId: extractMany2oneId(data['journal_id']),
      journalName: extractMany2oneName(data['journal_id']),
      paymentMethodLineId: extractMany2oneId(data['payment_method_line_id']),
      bankId: extractMany2oneId(data['bank_id']),
      bankName: extractMany2oneName(data['bank_id']),
      cardBrandId: extractMany2oneId(data['card_brand_id']),
      cardBrandName: extractMany2oneName(data['card_brand_id']),
      cardDeadlineId: extractMany2oneId(data['card_deadline_id']),
      cardDeadlineName: extractMany2oneName(data['card_deadline_id']),
      loteId: extractMany2oneId(data['lote_id']),
      loteName: extractMany2oneName(data['lote_id']),
      voucherDate: parseOdooDate(data['bank_reference_date']),
      partnerBankId: extractMany2oneId(data['partner_bank_id']),
      partnerBankName: extractMany2oneName(data['partner_bank_id']),
      effectiveDate: parseOdooDate(data['effective_date']),
      advanceId: extractMany2oneId(data['advance_id']),
      advanceName: extractMany2oneName(data['advance_id']),
      creditNoteId: extractMany2oneId(data['credit_note_id']),
      creditNoteName: extractMany2oneName(data['credit_note_id']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(PaymentLine record) {
    return {
      'date': formatOdooDate(record.date),
      'amount': record.amount,
      'payment_reference': record.reference,
      'state': record.state,
      'journal_id': record.journalId,
      'payment_method_line_id': record.paymentMethodLineId,
      'bank_id': record.bankId,
      'card_brand_id': record.cardBrandId,
      'card_deadline_id': record.cardDeadlineId,
      'lote_id': record.loteId,
      'bank_reference_date': formatOdooDate(record.voucherDate),
      'partner_bank_id': record.partnerBankId,
      'effective_date': formatOdooDate(record.effectiveDate),
      'advance_id': record.advanceId,
      'credit_note_id': record.creditNoteId,
    };
  }

  @override
  PaymentLine fromDrift(dynamic row) {
    return PaymentLine(
      id: row.odooId as int,
      lineUuid: row.lineUuid as String?,
      uuid: row.uuid as String?,
      isSynced: row.isSynced as bool? ?? false,
      type: (row.type as String?) != null
          ? PaymentLineType.values.firstWhere(
              (e) => e.name == (row.type as String?),
              orElse: () => PaymentLineType.values.first,
            )
          : PaymentLineType.values.first,
      date: row.date as DateTime,
      amount: row.amount as double,
      reference: row.paymentReference as String?,
      orderId: row.orderId as int?,
      state: row.state as String,
      journalId: row.journalId as int?,
      journalName: row.journalName as String?,
      journalType: row.journalType as String?,
      paymentMethodId: row.paymentMethodId as int?,
      paymentMethodLineId: row.paymentMethodLineId as int?,
      paymentMethodCode: row.paymentMethodCode as String?,
      paymentMethodName: row.paymentMethodName as String?,
      bankId: row.bankId as int?,
      bankName: row.bankName as String?,
      cardType: (row.cardType as String?) != null
          ? CardType.values.firstWhere(
              (e) => e.name == (row.cardType as String?),
              orElse: () => CardType.values.first,
            )
          : null,
      cardBrandId: row.cardBrandId as int?,
      cardBrandName: row.cardBrandName as String?,
      cardDeadlineId: row.cardDeadlineId as int?,
      cardDeadlineName: row.cardDeadlineName as String?,
      loteId: row.loteId as int?,
      loteName: row.loteName as String?,
      voucherDate: row.bankReferenceDate as DateTime?,
      partnerBankId: row.partnerBankId as int?,
      partnerBankName: row.partnerBankName as String?,
      effectiveDate: row.effectiveDate as DateTime?,
      advanceId: row.advanceId as int?,
      advanceName: row.advanceName as String?,
      advanceAvailable: row.advanceAvailable as double?,
      creditNoteId: row.creditNoteId as int?,
      creditNoteName: row.creditNoteName as String?,
      creditNoteAvailable: row.creditNoteAvailable as double?,
    );
  }

  @override
  int getId(PaymentLine record) => record.id;

  @override
  String? getUuid(PaymentLine record) => record.uuid;

  @override
  PaymentLine withIdAndUuid(PaymentLine record, int id, String uuid) {
    return record.copyWith(id: id, uuid: uuid);
  }

  @override
  PaymentLine withSyncStatus(PaymentLine record, bool isSynced) {
    return record.copyWith(isSynced: isSynced);
  }

  // ═══════════════════════════════════════════════════
  // Field Mappings for Sync
  // ═══════════════════════════════════════════════════

  /// Map of Odoo field names to Dart field names.
  /// Used for WebSocket sync field-level updates.
  static const Map<String, String> fieldMappings = {
    'id': 'id',
    'date': 'date',
    'amount': 'amount',
    'payment_reference': 'reference',
    'state': 'state',
    'journal_id': 'journalId',
    'payment_method_line_id': 'paymentMethodLineId',
    'bank_id': 'bankId',
    'card_brand_id': 'cardBrandId',
    'card_deadline_id': 'cardDeadlineId',
    'lote_id': 'loteId',
    'bank_reference_date': 'voucherDate',
    'partner_bank_id': 'partnerBankId',
    'effective_date': 'effectiveDate',
    'advance_id': 'advanceId',
    'credit_note_id': 'creditNoteId',
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
        'Table \'sale_order_payment_line\' not found in database.',
      );
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(PaymentLine record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'date': Variable<DateTime>(record.date),
      'amount': Variable<double>(record.amount),
      'payment_reference': driftVar<String>(record.reference),
      'state': Variable<String>(record.state),
      'journal_id': driftVar<int>(record.journalId),
      'journal_id_name': driftVar<String>(record.journalName),
      'payment_method_line_id': driftVar<int>(record.paymentMethodLineId),
      'bank_id': driftVar<int>(record.bankId),
      'bank_id_name': driftVar<String>(record.bankName),
      'card_brand_id': driftVar<int>(record.cardBrandId),
      'card_brand_id_name': driftVar<String>(record.cardBrandName),
      'card_deadline_id': driftVar<int>(record.cardDeadlineId),
      'card_deadline_id_name': driftVar<String>(record.cardDeadlineName),
      'lote_id': driftVar<int>(record.loteId),
      'lote_id_name': driftVar<String>(record.loteName),
      'bank_reference_date': driftVar<DateTime>(record.voucherDate),
      'partner_bank_id': driftVar<int>(record.partnerBankId),
      'partner_bank_id_name': driftVar<String>(record.partnerBankName),
      'effective_date': driftVar<DateTime>(record.effectiveDate),
      'advance_id': driftVar<int>(record.advanceId),
      'advance_id_name': driftVar<String>(record.advanceName),
      'credit_note_id': driftVar<int>(record.creditNoteId),
      'credit_note_id_name': driftVar<String>(record.creditNoteName),
      'line_uuid': driftVar<String>(record.lineUuid),
      'uuid': driftVar<String>(record.uuid),
      'is_synced': Variable<bool>(record.isSynced),
      'type': Variable<String>(record.type.name),
      'order_id': driftVar<int>(record.orderId),
      'journal_type': driftVar<String>(record.journalType),
      'payment_method_id': driftVar<int>(record.paymentMethodId),
      'payment_method_code': driftVar<String>(record.paymentMethodCode),
      'payment_method_name': driftVar<String>(record.paymentMethodName),
      'card_type': driftVar<String>(record.cardType?.name),
      'advance_available': driftVar<double>(record.advanceAvailable),
      'credit_note_available': driftVar<double>(record.creditNoteAvailable),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'date',
    'amount',
    'reference',
    'state',
    'journalId',
    'paymentMethodLineId',
    'bankId',
    'cardBrandId',
    'cardDeadlineId',
    'loteId',
    'voucherDate',
    'partnerBankId',
    'effectiveDate',
    'advanceId',
    'creditNoteId',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'lineUuid': 'Line Uuid',
    'uuid': 'Uuid',
    'isSynced': 'Is Synced',
    'type': 'Type',
    'date': 'Date',
    'amount': 'Amount',
    'reference': 'Reference',
    'orderId': 'Order Id',
    'state': 'State',
    'journalId': 'Journal Id',
    'journalName': 'Journal Name',
    'journalType': 'Journal Type',
    'paymentMethodId': 'Payment Method Id',
    'paymentMethodLineId': 'Payment Method Line Id',
    'paymentMethodCode': 'Payment Method Code',
    'paymentMethodName': 'Payment Method Name',
    'bankId': 'Bank Id',
    'bankName': 'Bank Name',
    'cardType': 'Card Type',
    'cardBrandId': 'Card Brand Id',
    'cardBrandName': 'Card Brand Name',
    'cardDeadlineId': 'Card Deadline Id',
    'cardDeadlineName': 'Card Deadline Name',
    'loteId': 'Lote Id',
    'loteName': 'Lote Name',
    'voucherDate': 'Voucher Date',
    'partnerBankId': 'Partner Bank Id',
    'partnerBankName': 'Partner Bank Name',
    'effectiveDate': 'Effective Date',
    'advanceId': 'Advance Id',
    'advanceName': 'Advance Name',
    'advanceAvailable': 'Advance Available',
    'creditNoteId': 'Credit Note Id',
    'creditNoteName': 'Credit Note Name',
    'creditNoteAvailable': 'Credit Note Available',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(PaymentLine record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(PaymentLine record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(PaymentLine record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(PaymentLine record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'lineUuid':
        return record.lineUuid;
      case 'uuid':
        return record.uuid;
      case 'isSynced':
        return record.isSynced;
      case 'type':
        return record.type;
      case 'date':
        return record.date;
      case 'amount':
        return record.amount;
      case 'reference':
        return record.reference;
      case 'orderId':
        return record.orderId;
      case 'state':
        return record.state;
      case 'journalId':
        return record.journalId;
      case 'journalName':
        return record.journalName;
      case 'journalType':
        return record.journalType;
      case 'paymentMethodId':
        return record.paymentMethodId;
      case 'paymentMethodLineId':
        return record.paymentMethodLineId;
      case 'paymentMethodCode':
        return record.paymentMethodCode;
      case 'paymentMethodName':
        return record.paymentMethodName;
      case 'bankId':
        return record.bankId;
      case 'bankName':
        return record.bankName;
      case 'cardType':
        return record.cardType;
      case 'cardBrandId':
        return record.cardBrandId;
      case 'cardBrandName':
        return record.cardBrandName;
      case 'cardDeadlineId':
        return record.cardDeadlineId;
      case 'cardDeadlineName':
        return record.cardDeadlineName;
      case 'loteId':
        return record.loteId;
      case 'loteName':
        return record.loteName;
      case 'voucherDate':
        return record.voucherDate;
      case 'partnerBankId':
        return record.partnerBankId;
      case 'partnerBankName':
        return record.partnerBankName;
      case 'effectiveDate':
        return record.effectiveDate;
      case 'advanceId':
        return record.advanceId;
      case 'advanceName':
        return record.advanceName;
      case 'advanceAvailable':
        return record.advanceAvailable;
      case 'creditNoteId':
        return record.creditNoteId;
      case 'creditNoteName':
        return record.creditNoteName;
      case 'creditNoteAvailable':
        return record.creditNoteAvailable;
      default:
        return null;
    }
  }

  @override
  PaymentLine applyWebSocketChangesToRecord(
    PaymentLine record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      lineUuid: record.lineUuid,
      uuid: record.uuid,
      isSynced: record.isSynced,
      type: record.type,
      orderId: record.orderId,
      journalType: record.journalType,
      paymentMethodId: record.paymentMethodId,
      paymentMethodCode: record.paymentMethodCode,
      paymentMethodName: record.paymentMethodName,
      cardType: record.cardType,
      advanceAvailable: record.advanceAvailable,
      creditNoteAvailable: record.creditNoteAvailable,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'lineUuid':
        return (obj as dynamic).lineUuid;
      case 'uuid':
        return (obj as dynamic).uuid;
      case 'isSynced':
        return (obj as dynamic).isSynced;
      case 'type':
        return (obj as dynamic).type;
      case 'date':
        return (obj as dynamic).date;
      case 'amount':
        return (obj as dynamic).amount;
      case 'reference':
        return (obj as dynamic).paymentReference;
      case 'orderId':
        return (obj as dynamic).orderId;
      case 'state':
        return (obj as dynamic).state;
      case 'journalId':
        return (obj as dynamic).journalId;
      case 'journalName':
        return (obj as dynamic).journalName;
      case 'journalType':
        return (obj as dynamic).journalType;
      case 'paymentMethodId':
        return (obj as dynamic).paymentMethodId;
      case 'paymentMethodLineId':
        return (obj as dynamic).paymentMethodLineId;
      case 'paymentMethodCode':
        return (obj as dynamic).paymentMethodCode;
      case 'paymentMethodName':
        return (obj as dynamic).paymentMethodName;
      case 'bankId':
        return (obj as dynamic).bankId;
      case 'bankName':
        return (obj as dynamic).bankName;
      case 'cardType':
        return (obj as dynamic).cardType;
      case 'cardBrandId':
        return (obj as dynamic).cardBrandId;
      case 'cardBrandName':
        return (obj as dynamic).cardBrandName;
      case 'cardDeadlineId':
        return (obj as dynamic).cardDeadlineId;
      case 'cardDeadlineName':
        return (obj as dynamic).cardDeadlineName;
      case 'loteId':
        return (obj as dynamic).loteId;
      case 'loteName':
        return (obj as dynamic).loteName;
      case 'voucherDate':
        return (obj as dynamic).bankReferenceDate;
      case 'partnerBankId':
        return (obj as dynamic).partnerBankId;
      case 'partnerBankName':
        return (obj as dynamic).partnerBankName;
      case 'effectiveDate':
        return (obj as dynamic).effectiveDate;
      case 'advanceId':
        return (obj as dynamic).advanceId;
      case 'advanceName':
        return (obj as dynamic).advanceName;
      case 'advanceAvailable':
        return (obj as dynamic).advanceAvailable;
      case 'creditNoteId':
        return (obj as dynamic).creditNoteId;
      case 'creditNoteName':
        return (obj as dynamic).creditNoteName;
      case 'creditNoteAvailable':
        return (obj as dynamic).creditNoteAvailable;
      case 'writeDate':
        return (obj as dynamic).writeDate;
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
    'lineUuid',
    'uuid',
    'isSynced',
    'type',
    'date',
    'amount',
    'reference',
    'orderId',
    'state',
    'journalId',
    'journalName',
    'journalType',
    'paymentMethodId',
    'paymentMethodLineId',
    'paymentMethodCode',
    'paymentMethodName',
    'bankId',
    'bankName',
    'cardType',
    'cardBrandId',
    'cardBrandName',
    'cardDeadlineId',
    'cardDeadlineName',
    'loteId',
    'loteName',
    'voucherDate',
    'partnerBankId',
    'partnerBankName',
    'effectiveDate',
    'advanceId',
    'advanceName',
    'advanceAvailable',
    'creditNoteId',
    'creditNoteName',
    'creditNoteAvailable',
  ];

  @override
  List<String> get writableFieldNames => const [
    'date',
    'amount',
    'reference',
    'state',
    'journalId',
    'paymentMethodLineId',
    'bankId',
    'cardBrandId',
    'cardDeadlineId',
    'loteId',
    'voucherDate',
    'partnerBankId',
    'effectiveDate',
    'advanceId',
    'creditNoteId',
  ];
}

/// Global instance of PaymentLineManager.
final paymentLineManager = PaymentLineManager();

/// Generated manager for CardLote.
///
/// Provides offline-first CRUD operations and sync
/// with Odoo model: account.card.lote
class CardLoteManager extends OdooModelManager<CardLote>
    with GenericDriftOperations<CardLote> {
  @override
  String get odooModel => 'account.card.lote';

  @override
  String get tableName => 'account_card_lote';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'journal_id',
    'state',
    'date',
    'numero_lote',
    'amount_total',
    'amount_balance',
    'payment_count',
    'is_pos_lote',
  ];

  @override
  CardLote fromOdoo(Map<String, dynamic> data) {
    return CardLote(
      id: data['id'] as int? ?? 0,
      name: parseOdooStringRequired(data['name']),
      journalId: extractMany2oneId(data['journal_id']) ?? 0,
      journalName: extractMany2oneName(data['journal_id']),
      state: parseOdooSelection(data['state']) ?? '',
      date: parseOdooDate(data['date']),
      numeroLote: parseOdooString(data['numero_lote']),
      amountTotal: parseOdooDouble(data['amount_total']) ?? 0.0,
      amountBalance: parseOdooDouble(data['amount_balance']) ?? 0.0,
      paymentCount: parseOdooInt(data['payment_count']) ?? 0,
      isPosLote: parseOdooBool(data['is_pos_lote']),
    );
  }

  @override
  Map<String, dynamic> toOdoo(CardLote record) {
    return {
      'name': record.name,
      'journal_id': record.journalId,
      'state': record.state,
      'date': formatOdooDate(record.date),
      'numero_lote': record.numeroLote,
      'amount_total': record.amountTotal,
      'amount_balance': record.amountBalance,
      'payment_count': record.paymentCount,
      'is_pos_lote': record.isPosLote,
    };
  }

  @override
  CardLote fromDrift(dynamic row) {
    return CardLote(
      id: row.odooId as int,
      localId: row.localId as int?,
      loteUuid: row.loteUuid as String?,
      name: row.name as String,
      journalId: row.journalId as int,
      journalName: row.journalName as String?,
      state: row.state as String,
      date: row.date as DateTime?,
      numeroLote: row.numeroLote as String?,
      amountTotal: row.amountTotal as double,
      amountBalance: row.amountBalance as double,
      paymentCount: row.paymentCount as int,
      isPosLote: row.isPosLote as bool,
    );
  }

  @override
  int getId(CardLote record) => record.id;

  @override
  String? getUuid(CardLote record) => null;

  @override
  CardLote withIdAndUuid(CardLote record, int id, String uuid) {
    return record.copyWith(id: id);
  }

  @override
  CardLote withSyncStatus(CardLote record, bool isSynced) {
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
    'journal_id': 'journalId',
    'state': 'state',
    'date': 'date',
    'numero_lote': 'numeroLote',
    'amount_total': 'amountTotal',
    'amount_balance': 'amountBalance',
    'payment_count': 'paymentCount',
    'is_pos_lote': 'isPosLote',
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
      throw StateError('Table \'account_card_lote\' not found in database.');
    }
    return resolved;
  }

  @override
  dynamic createDriftCompanion(CardLote record) {
    return RawValuesInsertable({
      'odoo_id': Variable<int>(record.id),
      'name': Variable<String>(record.name),
      'journal_id': Variable<int>(record.journalId),
      'journal_id_name': driftVar<String>(record.journalName),
      'state': Variable<String>(record.state),
      'date': driftVar<DateTime>(record.date),
      'numero_lote': driftVar<String>(record.numeroLote),
      'amount_total': Variable<double>(record.amountTotal),
      'amount_balance': Variable<double>(record.amountBalance),
      'payment_count': Variable<int>(record.paymentCount),
      'is_pos_lote': Variable<bool>(record.isPosLote),
      'local_id': driftVar<int>(record.localId),
      'lote_uuid': driftVar<String>(record.loteUuid),
    });
  }

  /// List of writable fields for partial updates.
  static const List<String> writableFields = [
    'name',
    'journalId',
    'state',
    'date',
    'numeroLote',
    'amountTotal',
    'amountBalance',
    'paymentCount',
    'isPosLote',
  ];

  /// List of required fields for validation.
  static const List<String> requiredFields = ['id'];

  /// Field labels for validation error messages.
  static const Map<String, String> fieldLabels = {
    'id': 'Id',
    'localId': 'Local Id',
    'loteUuid': 'Lote Uuid',
    'name': 'Name',
    'journalId': 'Journal Id',
    'journalName': 'Journal Name',
    'state': 'State',
    'date': 'Date',
    'numeroLote': 'Numero Lote',
    'amountTotal': 'Amount Total',
    'amountBalance': 'Amount Balance',
    'paymentCount': 'Payment Count',
    'isPosLote': 'Is Pos Lote',
  };

  // ═══════════════════════════════════════════════════
  // Automatic Validation
  // ═══════════════════════════════════════════════════

  /// Validate a record automatically based on field annotations.
  ///
  /// Returns a map of field -> error message for invalid fields.
  /// Empty map means the record is valid.
  Map<String, String> validateRecord(CardLote record) {
    final errors = <String, String>{};

    return errors;
  }

  /// Check if a record is valid.
  bool isValid(CardLote record) => validateRecord(record).isEmpty;

  /// Validate and throw if invalid.
  void ensureValid(CardLote record) {
    final errors = validateRecord(record);
    if (errors.isNotEmpty) {
      throw ValidationException(errors);
    }
  }

  // ═══════════════════════════════════════════════════
  // SmartOdooModel Support Overrides
  // ═══════════════════════════════════════════════════

  @override
  dynamic getRecordFieldValue(CardLote record, String fieldName) {
    switch (fieldName) {
      case 'id':
        return record.id;
      case 'localId':
        return record.localId;
      case 'loteUuid':
        return record.loteUuid;
      case 'name':
        return record.name;
      case 'journalId':
        return record.journalId;
      case 'journalName':
        return record.journalName;
      case 'state':
        return record.state;
      case 'date':
        return record.date;
      case 'numeroLote':
        return record.numeroLote;
      case 'amountTotal':
        return record.amountTotal;
      case 'amountBalance':
        return record.amountBalance;
      case 'paymentCount':
        return record.paymentCount;
      case 'isPosLote':
        return record.isPosLote;
      default:
        return null;
    }
  }

  @override
  CardLote applyWebSocketChangesToRecord(
    CardLote record,
    Map<String, dynamic> changes,
  ) {
    final current = toOdoo(record);
    current.addAll(changes);
    current['id'] = getId(record);
    var updated = fromOdoo(current);
    // Preserve local-only fields from original record
    updated = updated.copyWith(
      localId: record.localId,
      loteUuid: record.loteUuid,
    );
    return updated;
  }

  @override
  dynamic accessProperty(dynamic obj, String name) {
    switch (name) {
      case 'odooId':
        return (obj as dynamic).odooId;
      case 'localId':
        return (obj as dynamic).localId;
      case 'loteUuid':
        return (obj as dynamic).loteUuid;
      case 'name':
        return (obj as dynamic).name;
      case 'journalId':
        return (obj as dynamic).journalId;
      case 'journalName':
        return (obj as dynamic).journalName;
      case 'state':
        return (obj as dynamic).state;
      case 'date':
        return (obj as dynamic).date;
      case 'numeroLote':
        return (obj as dynamic).numeroLote;
      case 'amountTotal':
        return (obj as dynamic).amountTotal;
      case 'amountBalance':
        return (obj as dynamic).amountBalance;
      case 'paymentCount':
        return (obj as dynamic).paymentCount;
      case 'isPosLote':
        return (obj as dynamic).isPosLote;
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
    'localId',
    'loteUuid',
    'name',
    'journalId',
    'journalName',
    'state',
    'date',
    'numeroLote',
    'amountTotal',
    'amountBalance',
    'paymentCount',
    'isPosLote',
  ];

  @override
  List<String> get writableFieldNames => const [
    'name',
    'journalId',
    'state',
    'date',
    'numeroLote',
    'amountTotal',
    'amountBalance',
    'paymentCount',
    'isPosLote',
  ];
}

/// Global instance of CardLoteManager.
final cardLoteManager = CardLoteManager();
