import 'package:drift/drift.dart' show Value;

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;

/// Local DB service for payment line operations.
///
/// Encapsulates all direct Drift access for SaleOrderPaymentLine,
/// used as fallback when SalesRepository is not available and
/// for loading lines from the local database.
class PaymentLineLocalService {
  final AppDatabase _db;

  const PaymentLineLocalService(this._db);

  /// Save a payment line to local DB
  Future<void> saveLineToDb(int orderId, PaymentLine line) async {
    try {
      final db = _db;

      final companion = SaleOrderPaymentLineCompanion.insert(
        odooId: Value(line.id),
        lineUuid: Value(line.lineUuid),
        orderId: orderId,
        paymentType: const Value('inbound'),
        journalId: Value(line.journalId),
        journalName: Value(line.journalName),
        journalType: Value(line.journalType),
        paymentMethodLineId: Value(line.paymentMethodLineId),
        paymentMethodCode: Value(line.paymentMethodCode),
        paymentMethodName: Value(line.paymentMethodName),
        amount: Value(line.amount),
        date: Value(line.date),
        paymentReference: Value(line.reference),
        creditNoteId: Value(line.creditNoteId),
        creditNoteName: Value(line.creditNoteName),
        advanceId: Value(line.advanceId),
        advanceName: Value(line.advanceName),
        cardType: Value(line.cardType?.name),
        cardBrandId: Value(line.cardBrandId),
        cardBrandName: Value(line.cardBrandName),
        cardDeadlineId: Value(line.cardDeadlineId),
        cardDeadlineName: Value(line.cardDeadlineName),
        loteId: Value(line.loteId),
        loteName: Value(line.loteName),
        bankId: Value(line.bankId),
        bankName: Value(line.bankName),
        partnerBankId: Value(line.partnerBankId),
        partnerBankName: Value(line.partnerBankName),
        effectiveDate: Value(line.effectiveDate),
        bankReferenceDate: Value(line.voucherDate),
        isSynced: const Value(false),
      );
      await db.into(db.saleOrderPaymentLine).insert(companion);
      logger.d('[PaymentLineLocalService]', 'Saved payment line to DB: ${line.description}');
    } catch (e) {
      logger.e('[PaymentLineLocalService]', 'Error saving payment line to DB: $e');
    }
  }

  /// Remove a payment line from local DB by order ID and line ID
  Future<void> removeLineFromDb(int orderId, int lineId) async {
    try {
      final db = _db;

      await (db.delete(db.saleOrderPaymentLine)
            ..where((t) => t.orderId.equals(orderId))
            ..where((t) => t.odooId.equals(lineId)))
          .go();
      logger.d('[PaymentLineLocalService]', 'Removed payment line from DB: $lineId');
    } catch (e) {
      logger.e('[PaymentLineLocalService]', 'Error removing payment line from DB: $e');
    }
  }

  /// Clear all payment lines for an order from local DB
  Future<void> clearLinesFromDb(int orderId) async {
    try {
      final db = _db;

      await (db.delete(db.saleOrderPaymentLine)
            ..where((t) => t.orderId.equals(orderId)))
          .go();
      logger.d('[PaymentLineLocalService]', 'Cleared payment lines from DB for order $orderId');
    } catch (e) {
      logger.e('[PaymentLineLocalService]', 'Error clearing payment lines from DB: $e');
    }
  }

  /// Load payment lines from local database for an order
  Future<List<PaymentLine>> loadFromDb(int orderId) async {
    try {
      final db = _db;

      final dbLines = await (db.select(db.saleOrderPaymentLine)
            ..where((t) => t.orderId.equals(orderId)))
          .get();

      if (dbLines.isEmpty) {
        return [];
      }

      return dbLines.map((dbLine) {
        CardType? cardType;
        if (dbLine.cardType == 'credit') {
          cardType = CardType.credit;
        } else if (dbLine.cardType == 'debit') {
          cardType = CardType.debit;
        }

        PaymentLineType type = PaymentLineType.payment;
        if (dbLine.advanceId != null) {
          type = PaymentLineType.advance;
        } else if (dbLine.creditNoteId != null) {
          type = PaymentLineType.creditNote;
        }

        return PaymentLine(
          id: dbLine.odooId ?? dbLine.id,
          lineUuid: dbLine.lineUuid,
          type: type,
          date: dbLine.date ?? DateTime.now(),
          amount: dbLine.amount,
          reference: dbLine.paymentReference,
          journalId: dbLine.journalId,
          journalName: dbLine.journalName,
          journalType: dbLine.journalType,
          paymentMethodLineId: dbLine.paymentMethodLineId,
          paymentMethodCode: dbLine.paymentMethodCode,
          paymentMethodName: dbLine.paymentMethodName,
          bankId: dbLine.bankId,
          bankName: dbLine.bankName,
          cardType: cardType,
          cardBrandId: dbLine.cardBrandId,
          cardBrandName: dbLine.cardBrandName,
          cardDeadlineId: dbLine.cardDeadlineId,
          cardDeadlineName: dbLine.cardDeadlineName,
          loteId: dbLine.loteId,
          loteName: dbLine.loteName,
          voucherDate: dbLine.bankReferenceDate,
          partnerBankId: dbLine.partnerBankId,
          partnerBankName: dbLine.partnerBankName,
          effectiveDate: dbLine.effectiveDate,
          advanceId: dbLine.advanceId,
          advanceName: dbLine.advanceName,
          creditNoteId: dbLine.creditNoteId,
          creditNoteName: dbLine.creditNoteName,
        );
      }).toList();
    } catch (e) {
      logger.e('[PaymentLineLocalService]', 'Error loading payment lines from DB: $e');
      return [];
    }
  }
}
