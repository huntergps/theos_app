import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;

/// Local DB service for withhold line operations.
///
/// Encapsulates all direct Drift access for SaleOrderWithholdLine,
/// used as fallback when SalesRepository is not available and
/// for loading lines from the local database.
class WithholdLineLocalService {
  final AppDatabase _db;

  const WithholdLineLocalService(this._db);

  /// Save a withhold line to local DB
  Future<void> saveLineToDb(int orderId, WithholdLine line) async {
    try {
      final db = _db;
      final companion = SaleOrderWithholdLineCompanion.insert(
        lineUuid: Value(line.lineUuid),
        odooId: Value(line.id),
        orderId: orderId,
        taxId: line.taxId,
        taxName: line.taxName,
        taxPercent: Value(line.taxPercent),
        withholdType: line.withholdType.code,
        taxsupportCode: Value(line.taxSupportCode?.code),
        base: Value(line.base),
        amount: Value(line.amount),
        notes: Value(line.notes),
        isSynced: const Value(false),
      );
      await db.into(db.saleOrderWithholdLine).insert(companion);
      logger.d('[WithholdLineLocalService]', 'Saved withhold line to DB: ${line.taxName}');
    } catch (e) {
      logger.e('[WithholdLineLocalService]', 'Error saving withhold line to DB: $e');
    }
  }

  /// Remove a withhold line from local DB by UUID
  Future<void> removeLineFromDb(int orderId, String uuid) async {
    try {
      final db = _db;
      await (db.delete(db.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId))
            ..where((t) => t.lineUuid.equals(uuid)))
          .go();
      logger.d('[WithholdLineLocalService]', 'Removed withhold line from DB: $uuid');
    } catch (e) {
      logger.e('[WithholdLineLocalService]', 'Error removing withhold line from DB: $e');
    }
  }

  /// Clear all withhold lines for an order from local DB
  Future<void> clearLinesFromDb(int orderId) async {
    try {
      final db = _db;
      await (db.delete(db.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId)))
          .go();
      logger.d('[WithholdLineLocalService]', 'Cleared withhold lines from DB for order $orderId');
    } catch (e) {
      logger.e('[WithholdLineLocalService]', 'Error clearing withhold lines from DB: $e');
    }
  }

  /// Load withhold lines from local database for an order
  Future<List<WithholdLine>> loadFromDb(int orderId) async {
    try {
      final db = _db;
      final dbLines = await (db.select(db.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId)))
          .get();

      if (dbLines.isEmpty) {
        return [];
      }

      return dbLines.map((dbLine) => WithholdLine(
            id: dbLine.odooId ?? 0,
            lineUuid: const Uuid().v4(),
            taxId: dbLine.taxId,
            taxName: dbLine.taxName,
            taxPercent: dbLine.taxPercent,
            withholdType: WithholdType.fromCode(dbLine.withholdType) ?? WithholdType.incomeSale,
            taxSupportCode: TaxSupportCode.fromCode(dbLine.taxsupportCode),
            base: dbLine.base,
            amount: dbLine.amount,
            notes: dbLine.notes,
          )).toList();
    } catch (e) {
      logger.e('[WithholdLineLocalService]', 'Error loading withhold lines from DB: $e');
      return [];
    }
  }
}
