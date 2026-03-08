import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_pos/features/sales/services/sale_order_logic_engine.dart';
import 'package:theos_pos/features/sales/services/order_validation_types.dart';
import 'package:theos_pos/features/products/repositories/product_repository.dart';
import 'package:theos_pos/features/clients/clients.dart'
    show ClientCreditService, CreditValidationResult, CreditCheckType;
import 'package:theos_pos/shared/providers/company_config_provider.dart'
    show SalesConfig;

// ============================================================
// Mocks
// ============================================================

class MockProductRepository extends Mock implements ProductRepository {}

class MockClientCreditService extends Mock implements ClientCreditService {}

void main() {
  late SaleOrderLogicEngine engine;
  late MockProductRepository mockProductRepo;
  late MockClientCreditService mockCreditService;
  late Company testCompany;
  late SalesConfig testSalesConfig;

  setUp(() {
    mockProductRepo = MockProductRepository();
    mockCreditService = MockClientCreditService();
    testCompany = const Company(id: 1, name: 'Test Company');
    testSalesConfig = const SalesConfig(saleCustomerInvoiceLimitSri: 50.0);

    // Default stub: getById returns null (no product found)
    when(() => mockProductRepo.getById(any()))
        .thenAnswer((_) async => null);

    engine = SaleOrderLogicEngine(
      getCompany: () async => testCompany,
      getSalesConfig: () => testSalesConfig,
      productRepo: mockProductRepo,
      creditService: mockCreditService,
    );
  });

  // ============================================================
  // canEditField()
  // ============================================================
  group('canEditField()', () {
    test('draft order allows editing any field', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      expect(engine.canEditField(order, 'partner_id'), isTrue);
      expect(engine.canEditField(order, 'pricelist_id'), isTrue);
      expect(engine.canEditField(order, 'note'), isTrue);
      expect(engine.canEditField(order, 'any_field'), isTrue);
    });

    test('sent order allows editing any field', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.sent,
        dateOrder: DateTime.now(),
      );

      expect(engine.canEditField(order, 'partner_id'), isTrue);
      expect(engine.canEditField(order, 'note'), isTrue);
    });

    test('approved order only allows editing note', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.approved,
        dateOrder: DateTime.now(),
      );

      expect(engine.canEditField(order, 'note'), isTrue);
      expect(engine.canEditField(order, 'partner_id'), isFalse);
      expect(engine.canEditField(order, 'pricelist_id'), isFalse);
    });

    test('sale order only allows editing note', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.sale,
        dateOrder: DateTime.now(),
      );

      expect(engine.canEditField(order, 'note'), isTrue);
      expect(engine.canEditField(order, 'partner_id'), isFalse);
    });

    test('done order allows no edits', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        dateOrder: DateTime.now(),
      );

      expect(engine.canEditField(order, 'note'), isFalse);
      expect(engine.canEditField(order, 'partner_id'), isFalse);
    });

    test('cancelled order allows no edits', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.cancel,
        dateOrder: DateTime.now(),
      );

      expect(engine.canEditField(order, 'note'), isFalse);
      expect(engine.canEditField(order, 'partner_id'), isFalse);
    });

    test('waitingApproval order only allows editing note', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.waitingApproval,
        dateOrder: DateTime.now(),
      );

      expect(engine.canEditField(order, 'note'), isTrue);
      expect(engine.canEditField(order, 'partner_id'), isFalse);
    });
  });

  // ============================================================
  // getAllowedTransitions()
  // ============================================================
  group('getAllowedTransitions()', () {
    test('draft can transition to sent, waitingApproval, sale, cancel', () {
      final transitions = engine.getAllowedTransitions(SaleOrderState.draft);

      expect(transitions, contains(SaleOrderState.sent));
      expect(transitions, contains(SaleOrderState.waitingApproval));
      expect(transitions, contains(SaleOrderState.sale));
      expect(transitions, contains(SaleOrderState.cancel));
    });

    test('done is terminal state with no transitions', () {
      final transitions = engine.getAllowedTransitions(SaleOrderState.done);
      expect(transitions, isEmpty);
    });

    test('cancel can only transition to draft', () {
      final transitions = engine.getAllowedTransitions(SaleOrderState.cancel);
      expect(transitions, equals([SaleOrderState.draft]));
    });

    test('waitingApproval can transition to approved or cancel', () {
      final transitions =
          engine.getAllowedTransitions(SaleOrderState.waitingApproval);
      expect(transitions, contains(SaleOrderState.approved));
      expect(transitions, contains(SaleOrderState.cancel));
      expect(transitions.length, 2);
    });

    test('approved can transition to sale, cancel, draft', () {
      final transitions = engine.getAllowedTransitions(SaleOrderState.approved);
      expect(transitions, contains(SaleOrderState.sale));
      expect(transitions, contains(SaleOrderState.cancel));
      expect(transitions, contains(SaleOrderState.draft));
    });

    test('sale can transition to done, cancel, draft', () {
      final transitions = engine.getAllowedTransitions(SaleOrderState.sale);
      expect(transitions, contains(SaleOrderState.done));
      expect(transitions, contains(SaleOrderState.cancel));
      expect(transitions, contains(SaleOrderState.draft));
    });
  });

  // ============================================================
  // validateAction() — confirm
  // ============================================================
  group('validateAction() — confirm', () {
    test('fails when partner is null', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: null,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 10,
          priceTotal: 10,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrorType(ValidationErrorType.partnerRequired), isTrue);
    });

    test('fails when no product lines', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Section',
          displayType: LineDisplayType.lineSection,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrorType(ValidationErrorType.linesRequired), isTrue);
    });

    test('fails when state is done', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 10,
          priceTotal: 10,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrorType(ValidationErrorType.invalidState), isTrue);
    });

    test('fails when final consumer and no end customer name', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        isFinalConsumer: true,
        endCustomerName: null,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 10,
          priceTotal: 10,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(result.isValid, isFalse);
      expect(
        result.hasErrorType(ValidationErrorType.finalConsumerNameRequired),
        isTrue,
      );
    });

    test('fails when final consumer limit exceeded', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        isFinalConsumer: true,
        endCustomerName: 'John Doe',
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 60,
          priceTotal: 60,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(result.isValid, isFalse);
      expect(
        result.hasErrorType(ValidationErrorType.finalConsumerLimitExceeded),
        isTrue,
      );
    });

    test('passes when final consumer under limit', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        isFinalConsumer: true,
        endCustomerName: 'John Doe',
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 40,
          priceTotal: 40,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      // Should not have final consumer limit error
      expect(
        result.hasErrorType(ValidationErrorType.finalConsumerLimitExceeded),
        isFalse,
      );
    });

    test('detects discount exceeding max', () async {
      final company = const Company(
        id: 1,
        name: 'Test',
        maxDiscountPercentage: 30.0,
      );
      final engineWithLimit = SaleOrderLogicEngine(
        getCompany: () async => company,
        getSalesConfig: () => testSalesConfig,
        productRepo: mockProductRepo,
      );

      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product A',
          productId: 10,
          productName: 'Product A',
          productUomQty: 1,
          priceUnit: 100,
          discount: 50,
          priceTotal: 50,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engineWithLimit.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(result.isValid, isFalse);
      expect(
        result.hasErrorType(ValidationErrorType.discountExceedsLimit),
        isTrue,
      );
    });

    test('passes discount validation when no limit configured', () async {
      // Default maxDiscountPercentage is 100.0, meaning no limit
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 100,
          discount: 99,
          priceTotal: 1,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(
        result.hasErrorType(ValidationErrorType.discountExceedsLimit),
        isFalse,
      );
    });

    test('succeeds for valid draft order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 10,
          priceTotal: 10,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      expect(result.isValid, isTrue);
      expect(result.suggestedAction, ValidationAction.proceed);
    });

    test('can accumulate multiple errors', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        partnerId: null,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.confirm,
      );

      expect(result.isValid, isFalse);
      // Should have at least partnerRequired, linesRequired, invalidState
      expect(result.errors.length, greaterThanOrEqualTo(3));
    });
  });

  // ============================================================
  // validateAction() — save
  // ============================================================
  group('validateAction() — save', () {
    test('succeeds for editable order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.save,
      );

      expect(result.isValid, isTrue);
    });

    test('fails for non-editable order (sale state)', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.sale,
        locked: true,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.save,
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrorType(ValidationErrorType.invalidState), isTrue);
    });

    test('fails for done order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.save,
      );

      expect(result.isValid, isFalse);
    });
  });

  // ============================================================
  // validateAction() — editLine
  // ============================================================
  group('validateAction() — editLine', () {
    test('fails for non-editable order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.editLine,
        context: {'lineId': 1, 'field': 'price_unit'},
      );

      expect(result.isValid, isFalse);
      expect(
        result.hasErrorType(ValidationErrorType.fieldNotEditable),
        isTrue,
      );
    });

    test('fails for approved order (lines not modifiable)', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.approved,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.editLine,
        context: {'lineId': 1, 'field': 'price_unit'},
      );

      expect(result.isValid, isFalse);
      expect(
        result.hasErrorType(ValidationErrorType.fieldNotEditable),
        isTrue,
      );
    });

    test('succeeds for draft order line edit', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.editLine,
        context: {'lineId': 1, 'field': 'price_unit'},
      );

      expect(result.isValid, isTrue);
    });

    test('succeeds when no context provided (no validation done)', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.editLine,
      );

      expect(result.isValid, isTrue);
    });
  });

  // ============================================================
  // validateAction() — cancel
  // ============================================================
  group('validateAction() — cancel', () {
    test('fails for done order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.cancel,
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrorType(ValidationErrorType.invalidState), isTrue);
    });

    test('succeeds for draft order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.cancel,
      );

      expect(result.isValid, isTrue);
    });

    test('succeeds for sale order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.sale,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.cancel,
      );

      expect(result.isValid, isTrue);
    });
  });

  // ============================================================
  // validateAction() — approve
  // ============================================================
  group('validateAction() — approve', () {
    test('fails when not in waitingApproval state', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.approve,
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrorType(ValidationErrorType.invalidState), isTrue);
    });

    test('succeeds when in waitingApproval state', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.waitingApproval,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.approve,
      );

      expect(result.isValid, isTrue);
    });
  });

  // ============================================================
  // validateAction() — invoice
  // ============================================================
  group('validateAction() — invoice', () {
    test('fails when in draft state', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.invoice,
      );

      expect(result.isValid, isFalse);
    });

    test('succeeds when in sale state', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.sale,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.invoice,
      );

      expect(result.isValid, isTrue);
    });

    test('succeeds when in approved state', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.approved,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.invoice,
      );

      expect(result.isValid, isTrue);
    });

    test('fails when in done state', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.invoice,
      );

      expect(result.isValid, isFalse);
    });
  });

  // ============================================================
  // validateAction() — deleteLine
  // ============================================================
  group('validateAction() — deleteLine', () {
    test('succeeds for any state (no state guard in engine)', () async {
      // deleteLine goes through default: break in _validateStateForAction
      // so no state validation is applied
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.done,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.deleteLine,
      );

      expect(result.isValid, isTrue);
    });

    test('succeeds for draft order', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateAction(
        order: order,
        lines: const [],
        action: OrderAction.deleteLine,
      );

      expect(result.isValid, isTrue);
    });
  });

  // ============================================================
  // validateCredit()
  // ============================================================
  group('validateCredit()', () {
    test('returns null when no partner', () async {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: null,
        dateOrder: DateTime.now(),
      );

      final result = await engine.validateCredit(
        order: order,
        lines: const [],
      );

      expect(result, isNull);
    });

    test('returns null when no credit service', () async {
      final engineNoCreditService = SaleOrderLogicEngine(
        getCompany: () async => testCompany,
        getSalesConfig: () => testSalesConfig,
        productRepo: mockProductRepo,
        creditService: null,
      );

      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );

      final result = await engineNoCreditService.validateCredit(
        order: order,
        lines: const [],
      );

      expect(result, isNull);
    });

    test('returns null when credit validation passes', () async {
      when(() => mockCreditService.validateOrderCredit(
            clientId: any(named: 'clientId'),
            orderAmount: any(named: 'orderAmount'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => CreditValidationResult.ok());

      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 100,
          priceTotal: 100,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateCredit(
        order: order,
        lines: lines,
      );

      expect(result, isNull);
    });

    test('returns result when credit validation fails', () async {
      final failedResult = CreditValidationResult(
        type: CreditCheckType.creditLimitExceeded,
        isValid: false,
        message: 'Credit limit exceeded',
      );
      when(() => mockCreditService.validateOrderCredit(
            clientId: any(named: 'clientId'),
            orderAmount: any(named: 'orderAmount'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => failedResult);

      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 2,
          priceUnit: 500,
          priceTotal: 1000,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engine.validateCredit(
        order: order,
        lines: lines,
      );

      expect(result, isNotNull);
      expect(result!.isValid, isFalse);
    });

    test('calculates order amount from product lines only', () async {
      when(() => mockCreditService.validateOrderCredit(
            clientId: any(named: 'clientId'),
            orderAmount: any(named: 'orderAmount'),
            bypassCheck: any(named: 'bypassCheck'),
          )).thenAnswer((_) async => CreditValidationResult.ok());

      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 100,
          priceTotal: 100,
          displayType: LineDisplayType.product,
        ),
        const SaleOrderLine(
          id: 2,
          orderId: 1,
          name: 'Section Header',
          displayType: LineDisplayType.lineSection,
        ),
        const SaleOrderLine(
          id: 3,
          orderId: 1,
          name: 'Product 2',
          productId: 11,
          productUomQty: 1,
          priceUnit: 200,
          priceTotal: 200,
          displayType: LineDisplayType.product,
        ),
      ];

      await engine.validateCredit(order: order, lines: lines);

      // Should calculate 100 + 200 = 300 (excluding section line)
      verify(() => mockCreditService.validateOrderCredit(
            clientId: 5,
            orderAmount: 300.0,
            bypassCheck: false,
          )).called(1);
    });
  });

  // ============================================================
  // ProductValidationInfo
  // ============================================================
  group('ProductValidationInfo', () {
    test('creates instance with required fields', () {
      final info = ProductValidationInfo(
        productId: 1,
        name: 'Test Product',
        temporalNoDespachar: false,
        cost: 10.0,
      );

      expect(info.productId, 1);
      expect(info.name, 'Test Product');
      expect(info.temporalNoDespachar, isFalse);
      expect(info.cost, 10.0);
    });
  });

  // ============================================================
  // Engine with null company
  // ============================================================
  group('engine with null company', () {
    test('uses default maxDiscount of 100 when company is null', () async {
      final engineNoCompany = SaleOrderLogicEngine(
        getCompany: () async => null,
        getSalesConfig: () => testSalesConfig,
      );

      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 5,
        dateOrder: DateTime.now(),
      );
      final lines = [
        const SaleOrderLine(
          id: 1,
          orderId: 1,
          name: 'Product',
          productId: 10,
          productUomQty: 1,
          priceUnit: 100,
          discount: 90,
          priceTotal: 10,
          displayType: LineDisplayType.product,
        ),
      ];

      final result = await engineNoCompany.validateAction(
        order: order,
        lines: lines,
        action: OrderAction.confirm,
      );

      // 90% discount should pass when no company => maxDiscount defaults to 100
      expect(
        result.hasErrorType(ValidationErrorType.discountExceedsLimit),
        isFalse,
      );
    });
  });
}
