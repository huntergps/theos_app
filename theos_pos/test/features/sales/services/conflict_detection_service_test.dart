import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_pos/features/sales/services/conflict_detection_service.dart';
import 'package:theos_pos/features/sales/providers/base_order_state.dart'
    show ConflictDetail;

void main() {
  late ConflictDetectionService service;

  setUp(() {
    service = ConflictDetectionService();
  });

  /// Helper to create a SaleOrder with customizable fields.
  SaleOrder makeOrder({
    int id = 1,
    int? partnerId = 5,
    int? pricelistId = 1,
    int? paymentTermId = 1,
    int? warehouseId = 1,
    int? userId = 1,
    String? note,
    String? partnerPhone,
    String? partnerEmail,
    String? endCustomerName,
    DateTime? writeDate,
    double amountTotal = 100.0,
  }) {
    return SaleOrder(
      id: id,
      name: 'SO001',
      state: SaleOrderState.draft,
      partnerId: partnerId,
      pricelistId: pricelistId,
      paymentTermId: paymentTermId,
      warehouseId: warehouseId,
      userId: userId,
      note: note,
      partnerPhone: partnerPhone,
      partnerEmail: partnerEmail,
      endCustomerName: endCustomerName,
      dateOrder: DateTime(2025, 1, 1),
      writeDate: writeDate,
      amountTotal: amountTotal,
    );
  }

  // ============================================================
  // detectOrderConflicts()
  // ============================================================
  group('detectOrderConflicts()', () {
    test('no conflicts when no local changes', () {
      final local = makeOrder();
      final server = makeOrder(partnerId: 99); // different partner

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {}, // no local changes
      );

      expect(result.hasConflicts, isFalse);
    });

    test('detects conflict when same field changed locally and on server', () {
      final local = makeOrder(partnerId: 5);
      final server = makeOrder(partnerId: 99);

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {'partner_id': 10}, // local also changed partner
        serverUserName: 'admin',
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflicts.length, 1);
      expect(result.conflicts[0].fieldName, 'Cliente');
      expect(result.conflicts[0].localValue, 10);
      expect(result.conflicts[0].serverValue, 99);
      expect(result.conflicts[0].serverUserName, 'admin');
    });

    test('no conflict when field only changed on server (mergeable)', () {
      final local = makeOrder(partnerId: 5, note: 'old');
      final server = makeOrder(partnerId: 5, note: 'new note');

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {'partner_id': 99}, // local changed different field
      );

      expect(result.hasConflicts, isFalse);
      expect(result.mergeableFields.containsKey('note'), isTrue);
      expect(result.mergeableFields['note'], 'new note');
    });

    test('conflict message includes user name and field names', () {
      final local = makeOrder(note: 'A');
      final server = makeOrder(note: 'B');

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {'note': 'C'},
        serverUserName: 'Juan',
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflictMessage, contains('Juan'));
      expect(result.conflictMessage, contains('Notas'));
    });

    test('uses default user name when none provided', () {
      final local = makeOrder(note: 'A');
      final server = makeOrder(note: 'B');

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {'note': 'C'},
      );

      expect(result.conflictMessage, contains('otro usuario'));
    });

    test('multiple conflicts and mergeable fields', () {
      final local = makeOrder(partnerId: 5, note: 'old', partnerPhone: '111');
      final server = makeOrder(
        partnerId: 99,
        note: 'server note',
        partnerPhone: '222',
      );

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {
          'partner_id': 10,
          'note': 'local note',
        },
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflicts.length, 2);
      expect(result.mergeableFields.containsKey('partner_phone'), isTrue);
    });

    test('conflictingFieldNames returns list of field names', () {
      final local = makeOrder(partnerId: 5, note: 'A');
      final server = makeOrder(partnerId: 99, note: 'B');

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {'partner_id': 10, 'note': 'C'},
      );

      expect(result.conflictingFieldNames, contains('Cliente'));
      expect(result.conflictingFieldNames, contains('Notas'));
    });

    test('no conflict for same values (within numeric tolerance)', () {
      final local = makeOrder(amountTotal: 100.0);
      final server = makeOrder(amountTotal: 100.0005); // within 0.001

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {},
      );

      expect(result.hasConflicts, isFalse);
    });

    test('no conflict when both null', () {
      final local = makeOrder(note: null);
      final server = makeOrder(note: null);

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {'note': 'test'}, // local changed, but server same as local original
      );

      // Since local and server both have null, no conflict even though local changed it
      expect(result.hasConflicts, isFalse);
    });
  });

  // ============================================================
  // detectLineConflicts()
  // ============================================================
  group('detectLineConflicts()', () {
    test('no conflicts when no local modifications', () {
      final localLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productUomQty: 5,
          priceUnit: 10,
          discount: 0,
          displayType: LineDisplayType.product,
        ),
      ];
      final serverLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productUomQty: 10, // different qty
          priceUnit: 10,
          discount: 0,
          displayType: LineDisplayType.product,
        ),
      ];

      final results = service.detectLineConflicts(
        localLines: localLines,
        serverLines: serverLines,
        modifiedLineIds: {}, // no modifications
      );

      expect(results, isEmpty);
    });

    test('detects conflict when modified line differs on server', () {
      final localLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productUomQty: 5,
          priceUnit: 10,
          discount: 0,
          displayType: LineDisplayType.product,
        ),
      ];
      final serverLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productUomQty: 10,
          priceUnit: 20,
          discount: 5,
          displayType: LineDisplayType.product,
        ),
      ];

      final results = service.detectLineConflicts(
        localLines: localLines,
        serverLines: serverLines,
        modifiedLineIds: {1},
      );

      expect(results.containsKey(1), isTrue);
      expect(results[1]!.hasConflicts, isTrue);
      expect(results[1]!.conflicts.length, 3); // qty, price, discount
    });

    test('detects line deleted on server', () {
      final localLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productUomQty: 5,
          priceUnit: 10,
          displayType: LineDisplayType.product,
        ),
      ];

      final results = service.detectLineConflicts(
        localLines: localLines,
        serverLines: [], // line not on server
        modifiedLineIds: {1},
        serverUserName: 'admin',
      );

      expect(results.containsKey(1), isTrue);
      expect(results[1]!.hasConflicts, isTrue);
      expect(results[1]!.conflictMessage, contains('eliminada'));
    });

    test('skips new local lines (negative IDs)', () {
      final localLines = [
        const SaleOrderLine(
          id: -123,
          orderId: 1,
          name: 'New local product',
          productUomQty: 1,
          priceUnit: 10,
          displayType: LineDisplayType.product,
        ),
      ];

      final results = service.detectLineConflicts(
        localLines: localLines,
        serverLines: [],
        modifiedLineIds: {-123},
      );

      expect(results, isEmpty);
    });

    test('no conflict when line fields match', () {
      final localLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productUomQty: 5,
          priceUnit: 10,
          discount: 0,
          displayType: LineDisplayType.product,
        ),
      ];
      final serverLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productUomQty: 5,
          priceUnit: 10,
          discount: 0,
          displayType: LineDisplayType.product,
        ),
      ];

      final results = service.detectLineConflicts(
        localLines: localLines,
        serverLines: serverLines,
        modifiedLineIds: {1},
      );

      expect(results.containsKey(1), isTrue);
      expect(results[1]!.hasConflicts, isFalse);
    });
  });

  // ============================================================
  // hasServerChanges()
  // ============================================================
  group('hasServerChanges()', () {
    test('returns true when server writeDate is newer', () {
      final local = makeOrder(
        writeDate: DateTime(2025, 1, 1, 10, 0),
      );
      final server = makeOrder(
        writeDate: DateTime(2025, 1, 1, 11, 0),
      );

      expect(
        service.hasServerChanges(localOrder: local, serverOrder: server),
        isTrue,
      );
    });

    test('returns false when server writeDate is older', () {
      final local = makeOrder(
        writeDate: DateTime(2025, 1, 1, 11, 0),
      );
      final server = makeOrder(
        writeDate: DateTime(2025, 1, 1, 10, 0),
      );

      expect(
        service.hasServerChanges(localOrder: local, serverOrder: server),
        isFalse,
      );
    });

    test('returns false when writeDates are equal', () {
      final date = DateTime(2025, 1, 1, 10, 0);
      final local = makeOrder(writeDate: date);
      final server = makeOrder(writeDate: date);

      expect(
        service.hasServerChanges(localOrder: local, serverOrder: server),
        isFalse,
      );
    });

    test('falls back to field comparison when no writeDate', () {
      final local = makeOrder(partnerId: 5, amountTotal: 100);
      final server = makeOrder(partnerId: 99, amountTotal: 100);

      expect(
        service.hasServerChanges(localOrder: local, serverOrder: server),
        isTrue,
      );
    });

    test('falls back: detects pricelist change', () {
      final local = makeOrder(pricelistId: 1);
      final server = makeOrder(pricelistId: 2);

      expect(
        service.hasServerChanges(localOrder: local, serverOrder: server),
        isTrue,
      );
    });

    test('falls back: detects amount change', () {
      final local = makeOrder(amountTotal: 100);
      final server = makeOrder(amountTotal: 200);

      expect(
        service.hasServerChanges(localOrder: local, serverOrder: server),
        isTrue,
      );
    });

    test('falls back: no changes detected', () {
      final local = makeOrder();
      final server = makeOrder();

      expect(
        service.hasServerChanges(localOrder: local, serverOrder: server),
        isFalse,
      );
    });
  });

  // ============================================================
  // ConflictDetectionResult data class
  // ============================================================
  group('ConflictDetectionResult', () {
    test('noConflicts factory', () {
      final result = ConflictDetectionResult.noConflicts();

      expect(result.hasConflicts, isFalse);
      expect(result.conflicts, isEmpty);
      expect(result.conflictMessage, isNull);
      expect(result.mergeableFields, isEmpty);
    });

    test('noConflicts with mergeable fields', () {
      final result = ConflictDetectionResult.noConflicts(
        mergeableFields: {'note': 'merged value'},
      );

      expect(result.hasConflicts, isFalse);
      expect(result.mergeableFields['note'], 'merged value');
    });

    test('withConflicts factory', () {
      final conflicts = [
        const ConflictDetail(
          fieldName: 'Cliente',
          localValue: 5,
          serverValue: 10,
        ),
      ];

      final result = ConflictDetectionResult.withConflicts(
        conflicts: conflicts,
        conflictMessage: 'Conflict!',
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflicts.length, 1);
      expect(result.conflictMessage, 'Conflict!');
    });
  });

  // ============================================================
  // Field display name mapping
  // ============================================================
  group('field display names', () {
    test('maps known fields to Spanish display names', () {
      final local = makeOrder(partnerEmail: 'a@b.com');
      final server = makeOrder(partnerEmail: 'x@y.com');

      final result = service.detectOrderConflicts(
        localOrder: local,
        serverOrder: server,
        changedFields: {'partner_email': 'c@d.com'},
      );

      expect(result.hasConflicts, isTrue);
      expect(result.conflicts[0].fieldName, 'Email');
    });
  });

  // ============================================================
  // Numeric tolerance in _valuesEqual
  // ============================================================
  group('numeric tolerance', () {
    test('treats numbers within 0.001 as equal', () {
      // Test via detectLineConflicts with nearly-equal prices
      final localLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productUomQty: 5.0,
          priceUnit: 10.0005, // within tolerance
          discount: 0,
          displayType: LineDisplayType.product,
        ),
      ];
      final serverLines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productUomQty: 5.0,
          priceUnit: 10.0,
          discount: 0,
          displayType: LineDisplayType.product,
        ),
      ];

      final results = service.detectLineConflicts(
        localLines: localLines,
        serverLines: serverLines,
        modifiedLineIds: {1},
      );

      // price_unit difference < 0.001, should not be a conflict
      expect(results[1]!.hasConflicts, isFalse);
    });
  });

  // ============================================================
  // DateTime comparison (ignores seconds/ms)
  // ============================================================
  group('DateTime comparison', () {
    test('treats DateTimes as equal if same up to minute', () {
      // Use the detectOrderConflicts method with dateOrder fields
      // that differ only in seconds
      final localOrder = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime(2025, 6, 15, 10, 30, 0),
        commitmentDate: DateTime(2025, 6, 20, 14, 0, 0),
      );
      final serverOrder = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime(2025, 6, 15, 10, 30, 45), // 45 seconds difference
        commitmentDate: DateTime(2025, 6, 20, 14, 0, 30), // 30 seconds difference
      );

      final result = service.detectOrderConflicts(
        localOrder: localOrder,
        serverOrder: serverOrder,
        changedFields: {
          'date_order': DateTime(2025, 6, 15, 10, 30, 10),
          'commitment_date': DateTime(2025, 6, 20, 14, 0, 15),
        },
      );

      // Same up to minute, so no conflict
      expect(result.hasConflicts, isFalse);
    });
  });
}
