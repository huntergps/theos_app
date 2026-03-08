import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/features/sales/services/order_defaults_service.dart';
import 'package:theos_pos/features/sales/services/order_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

// ============================================================
// Mocks
// ============================================================

class MockOrderDefaultsService extends Mock implements OrderDefaultsService {}

/// Tests for OrderService pure business logic:
/// - createOrder() — generates negative temp IDs, applies defaults, applies overrides
/// - _lookupName() — table name routing (private, tested indirectly)
/// - syncDefaultsFromOdoo() — merge behavior
void main() {
  late MockOrderDefaultsService mockDefaultsService;
  late OrderService orderService;

  const testDefaults = OrderDefaults(
    partnerId: 1,
    partnerName: 'Consumidor Final',
    partnerVat: '9999999999999',
    warehouseId: 10,
    warehouseName: 'Main Warehouse',
    pricelistId: 20,
    pricelistName: 'Public Pricelist',
    paymentTermId: 30,
    paymentTermName: 'Immediate Payment',
    userId: 5,
    userName: 'Test User',
    companyId: 1,
  );

  setUp(() {
    mockDefaultsService = MockOrderDefaultsService();
    orderService = OrderService(
      defaultsService: mockDefaultsService,
      salesRepo: null,
    );
  });

  // ============================================================
  // createOrder()
  // ============================================================
  group('createOrder()', () {
    setUp(() {
      when(() => mockDefaultsService.getLocalDefaults())
          .thenAnswer((_) async => testDefaults);
    });

    test('should generate negative temporary ID', () async {
      final order = await orderService.createOrder();

      expect(order.id, isNegative);
    });

    test('should use defaults from OrderDefaultsService', () async {
      final order = await orderService.createOrder();

      expect(order.partnerId, 1);
      expect(order.partnerName, 'Consumidor Final');
      expect(order.warehouseId, 10);
      expect(order.warehouseName, 'Main Warehouse');
      expect(order.pricelistId, 20);
      expect(order.pricelistName, 'Public Pricelist');
      expect(order.paymentTermId, 30);
      expect(order.paymentTermName, 'Immediate Payment');
      expect(order.userId, 5);
      expect(order.userName, 'Test User');
      expect(order.companyId, 1);
    });

    test('should set order name to "New"', () async {
      final order = await orderService.createOrder();

      expect(order.name, 'New');
    });

    test('should set state to draft', () async {
      final order = await orderService.createOrder();

      expect(order.state, SaleOrderState.draft);
    });

    test('should set all amounts to zero', () async {
      final order = await orderService.createOrder();

      expect(order.amountTotal, closeTo(0.0, 0.001));
      expect(order.amountUntaxed, closeTo(0.0, 0.001));
      expect(order.amountTax, closeTo(0.0, 0.001));
    });

    test('should set locked to false', () async {
      final order = await orderService.createOrder();

      expect(order.locked, isFalse);
    });

    test('should set dateOrder to current time', () async {
      final before = DateTime.now();
      final order = await orderService.createOrder();
      final after = DateTime.now();

      expect(order.dateOrder, isNotNull);
      expect(
        order.dateOrder!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        order.dateOrder!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    group('overrides', () {
      test('should override partnerId when provided', () async {
        final order = await orderService.createOrder(
          partnerId: 99,
          partnerName: 'Custom Partner',
        );

        expect(order.partnerId, 99);
        expect(order.partnerName, 'Custom Partner');
      });

      test('should override warehouseId when provided', () async {
        final order = await orderService.createOrder(
          warehouseId: 50,
          warehouseName: 'Warehouse B',
        );

        expect(order.warehouseId, 50);
        expect(order.warehouseName, 'Warehouse B');
      });

      test('should override pricelistId when provided', () async {
        final order = await orderService.createOrder(
          pricelistId: 88,
          pricelistName: 'VIP Pricelist',
        );

        expect(order.pricelistId, 88);
        expect(order.pricelistName, 'VIP Pricelist');
      });

      test('should override paymentTermId when provided', () async {
        final order = await orderService.createOrder(
          paymentTermId: 77,
          paymentTermName: '30 Days',
        );

        expect(order.paymentTermId, 77);
        expect(order.paymentTermName, '30 Days');
      });

      test('should override userId when provided', () async {
        final order = await orderService.createOrder(
          userId: 42,
          userName: 'Admin',
        );

        expect(order.userId, 42);
        expect(order.userName, 'Admin');
      });

      test('should use defaults for non-overridden fields', () async {
        final order = await orderService.createOrder(
          partnerId: 99,
          partnerName: 'Override Partner',
        );

        // Overridden
        expect(order.partnerId, 99);
        expect(order.partnerName, 'Override Partner');
        // Defaults preserved
        expect(order.warehouseId, 10);
        expect(order.pricelistId, 20);
        expect(order.paymentTermId, 30);
        expect(order.userId, 5);
      });

      test('should handle all null overrides (use all defaults)', () async {
        final order = await orderService.createOrder();

        expect(order.partnerId, testDefaults.partnerId);
        expect(order.warehouseId, testDefaults.warehouseId);
        expect(order.pricelistId, testDefaults.pricelistId);
        expect(order.paymentTermId, testDefaults.paymentTermId);
        expect(order.userId, testDefaults.userId);
      });
    });

    group('with empty defaults', () {
      test('should handle empty defaults gracefully', () async {
        when(() => mockDefaultsService.getLocalDefaults())
            .thenAnswer((_) async => OrderDefaults.empty);

        final order = await orderService.createOrder();

        expect(order.id, isNegative);
        expect(order.name, 'New');
        expect(order.partnerId, isNull);
        expect(order.warehouseId, isNull);
        expect(order.pricelistId, isNull);
        expect(order.state, SaleOrderState.draft);
      });

      test('overrides should work even with empty defaults', () async {
        when(() => mockDefaultsService.getLocalDefaults())
            .thenAnswer((_) async => OrderDefaults.empty);

        final order = await orderService.createOrder(
          partnerId: 42,
          partnerName: 'My Partner',
        );

        expect(order.partnerId, 42);
        expect(order.partnerName, 'My Partner');
        expect(order.warehouseId, isNull); // Still null from empty defaults
      });
    });

    group('temporary ID uniqueness', () {
      test('should generate different IDs for different orders', () async {
        final order1 = await orderService.createOrder();
        // Small delay to ensure different millisecond timestamps
        await Future.delayed(const Duration(milliseconds: 2));
        final order2 = await orderService.createOrder();

        expect(order1.id, isNot(equals(order2.id)));
      });

      test('all generated IDs should be negative', () async {
        final orders = <SaleOrder>[];
        for (int i = 0; i < 5; i++) {
          orders.add(await orderService.createOrder());
          await Future.delayed(const Duration(milliseconds: 1));
        }

        for (final order in orders) {
          expect(order.id, isNegative,
              reason: 'Temp ID ${order.id} should be negative');
        }
      });
    });
  });

  // ============================================================
  // syncDefaultsFromOdoo()
  // ============================================================
  group('syncDefaultsFromOdoo()', () {
    test('should return null when salesRepo is null', () async {
      final service = OrderService(
        defaultsService: mockDefaultsService,
        salesRepo: null,
      );

      final order = SaleOrder(
        id: -1000,
        name: 'New',
        state: SaleOrderState.draft,
        amountTotal: 0,
        amountUntaxed: 0,
        amountTax: 0,
        locked: false,
      );

      final result = await service.syncDefaultsFromOdoo(order);
      expect(result, isNull);
    });

    // Note: Tests that mock SalesRepository.getDefaultValues() are skipped
    // because SalesRepository uses `part` files and its internal field
    // initializers prevent proper mocking with mocktail.
    // The null salesRepo path (above) covers the guard clause,
    // and integration-level tests should cover the Odoo sync path.
  });

  // ============================================================
  // OrderService constructor
  // ============================================================
  group('OrderService constructor', () {
    test('should accept null salesRepo', () {
      final service = OrderService(
        defaultsService: mockDefaultsService,
        salesRepo: null,
      );

      expect(service, isNotNull);
    });
  });
}
