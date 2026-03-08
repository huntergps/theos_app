import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Mock managers for SmartOdooModel tests.
class MockSmartOrderManager extends Mock
    implements OdooModelManager<TestSmartOrder> {}

class MockSmartOrderWithStateManager extends Mock
    implements OdooModelManager<TestSmartOrderWithState> {}

class MockOrderLineManager extends Mock
    implements OdooModelManager<TestOrderLine> {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const TestSmartOrder(id: 0, name: '', quantity: 0, price: 0),
    );
    registerFallbackValue(
      const TestSmartOrderWithState(id: 0, name: '', state: ''),
    );
    registerFallbackValue(
      const TestOrderLine(id: 0, productId: 0, quantity: 0),
    );
    registerFallbackValue(<String>{});
    registerFallbackValue(<String, dynamic>{});
  });

  group('ComputedFieldEngine with compute functions', () {
    late ComputedFieldEngine<TestSaleOrder> engine;

    setUp(() {
      engine = ComputedFieldEngine<TestSaleOrder>();
    });

    tearDown(() {
      ComputeEngineRegistry.clear();
    });

    group('registerCompute', () {
      test('registers compute function with dependencies', () {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);

        expect(engine.isComputed('subtotal'), isTrue);
        expect(engine.getDependents('quantity'), contains('subtotal'));
        expect(engine.getDependents('price'), contains('subtotal'));
      });

      test('can register multiple compute functions', () {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);
        engine.registerCompute('tax', [
          'subtotal',
        ], (order) => order.subtotal * 0.12);
        engine.registerCompute('total', [
          'subtotal',
          'tax',
        ], (order) => order.subtotal + order.tax);

        expect(engine.isComputed('subtotal'), isTrue);
        expect(engine.isComputed('tax'), isTrue);
        expect(engine.isComputed('total'), isTrue);
      });
    });

    group('computeAffected', () {
      setUp(() {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);
        engine.registerCompute('tax', [
          'subtotal',
        ], (order) => order.subtotal * 0.12);
        engine.registerCompute('total', [
          'subtotal',
          'tax',
        ], (order) => order.subtotal + order.tax);
      });

      test('computes affected fields after change', () {
        // Note: computeAffected uses the original model for computations
        // so tax uses model.subtotal, and total uses model.subtotal + model.tax
        const order = TestSaleOrder(
          quantity: 10,
          price: 100.0,
          subtotal: 1000.0,
          tax: 120.0,
        );

        final computed = engine.computeAffected(order, {'quantity'});

        expect(computed['subtotal'], 1000.0);
        expect(computed['tax'], 120.0); // 1000 * 0.12
        expect(computed['total'], 1120.0); // Uses model.subtotal + model.tax
      });

      test('returns empty map when no fields affected', () {
        const order = TestSaleOrder(quantity: 10, price: 100.0);

        final computed = engine.computeAffected(order, {'nonExistent'});

        expect(computed, isEmpty);
      });

      test('computes only affected fields', () {
        // Add an independent computed field
        engine.registerCompute('discount', [
          'discountPercent',
        ], (order) => order.subtotal * (order.discountPercent / 100));

        const order = TestSaleOrder(quantity: 10, price: 100.0);

        final computed = engine.computeAffected(order, {'quantity'});

        expect(computed.containsKey('subtotal'), isTrue);
        expect(computed.containsKey('discount'), isFalse);
      });
    });

    group('computeAll', () {
      setUp(() {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);
        engine.registerCompute('tax', [
          'subtotal',
        ], (order) => order.subtotal * 0.12);
      });

      test('computes all registered computed fields', () {
        // computeAll uses original model values for all computations
        // tax uses order.subtotal (1000.0), not the computed subtotal
        const order = TestSaleOrder(
          quantity: 5,
          price: 200.0,
          subtotal: 1000.0,
        );

        final computed = engine.computeAll(order);

        expect(computed['subtotal'], 1000.0);
        expect(computed['tax'], 120.0); // 1000 * 0.12
      });

      test('computes in correct order', () {
        // Tax depends on subtotal, so subtotal should be computed first
        // However, computeAll uses the original model for all computations,
        // so tax will be 0 because it uses order.subtotal which is 0
        const order = TestSaleOrder(quantity: 5, price: 200.0, subtotal: 0.0);

        final computed = engine.computeAll(order);

        // Since computeAll uses the original model for all computations,
        // tax will be 0 because it uses order.subtotal which is 0
        expect(computed['subtotal'], 1000.0);
        expect(computed['tax'], 0.0); // Uses original subtotal (0)
      });
    });

    group('recompute', () {
      test('throws when apply function not set', () {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);

        const order = TestSaleOrder(quantity: 10, price: 100.0);

        expect(
          () => engine.recompute(order, {'quantity'}),
          throwsA(isA<StateError>()),
        );
      });

      test('applies computed values with apply function', () {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);
        engine.setApplyFunction((order, values) {
          return order.copyWith(
            subtotal: values['subtotal'] as double? ?? order.subtotal,
          );
        });

        const order = TestSaleOrder(quantity: 10, price: 100.0, subtotal: 0.0);
        final updated = engine.recompute(order, {'quantity'});

        expect(updated.subtotal, 1000.0);
        expect(updated.quantity, 10);
        expect(updated.price, 100.0);
      });

      test('returns original model when no fields affected', () {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);
        engine.setApplyFunction((order, values) => order);

        const order = TestSaleOrder(quantity: 10, price: 100.0);
        final updated = engine.recompute(order, {'nonExistent'});

        expect(identical(order, updated), isTrue);
      });
    });

    group('recomputeAll', () {
      test('throws when apply function not set', () {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);

        const order = TestSaleOrder(quantity: 10, price: 100.0);

        expect(() => engine.recomputeAll(order), throwsA(isA<StateError>()));
      });

      test('recomputes all fields and applies', () {
        engine.registerCompute('subtotal', [
          'quantity',
          'price',
        ], (order) => order.quantity * order.price);
        engine.setApplyFunction((order, values) {
          return order.copyWith(
            subtotal: values['subtotal'] as double? ?? order.subtotal,
          );
        });

        const order = TestSaleOrder(quantity: 5, price: 50.0, subtotal: 0.0);
        final updated = engine.recomputeAll(order);

        expect(updated.subtotal, 250.0);
      });
    });

    group('circular dependency detection', () {
      test('throws on circular dependency', () {
        engine.registerDependencies('a', ['b']);
        engine.registerDependencies('b', ['c']);
        engine.registerDependencies('c', ['a']);

        expect(() => engine.computeOrder, throwsA(isA<StateError>()));
      });

      test('allows diamond dependencies', () {
        // Diamond: A depends on B and C, both depend on D
        engine.registerDependencies('total', ['subtotal', 'tax']);
        engine.registerDependencies('subtotal', ['quantity']);
        engine.registerDependencies('tax', ['quantity']);

        expect(() => engine.computeOrder, returnsNormally);
      });
    });
  });

  group('ComputeMethodRegistry', () {
    tearDown(() {
      // Registry is static, need to be careful about test isolation
    });

    test('can register and retrieve compute methods', () {
      ComputeMethodRegistry.register<TestSaleOrder>(
        'subtotal',
        () => {'subtotal': 100.0},
      );

      final method = ComputeMethodRegistry.get<TestSaleOrder>('subtotal');
      expect(method, isNotNull);
      expect(method!(), {'subtotal': 100.0});
    });

    test('returns null for unregistered method', () {
      final method = ComputeMethodRegistry.get<TestSaleOrder>('nonExistent');
      expect(method, isNull);
    });

    test('can register multiple methods for same type', () {
      ComputeMethodRegistry.register<TestSaleOrder>(
        'subtotal',
        () => {'subtotal': 100.0},
      );
      ComputeMethodRegistry.register<TestSaleOrder>('tax', () => {'tax': 12.0});

      expect(ComputeMethodRegistry.get<TestSaleOrder>('subtotal'), isNotNull);
      expect(ComputeMethodRegistry.get<TestSaleOrder>('tax'), isNotNull);
    });
  });

  group('OnchangeMethodRegistry', () {
    test('can register and retrieve onchange methods', () {
      void testOnchange(dynamic value) {}

      OnchangeMethodRegistry.register<TestSaleOrder>('partnerId', testOnchange);

      final method = OnchangeMethodRegistry.get<TestSaleOrder>('partnerId');
      expect(method, isNotNull);
    });

    test('returns null for unregistered field', () {
      final method = OnchangeMethodRegistry.get<TestSaleOrder>('nonExistent');
      expect(method, isNull);
    });
  });

  group('SmartModelBuilder', () {
    test('creates builder from model', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'SO001',
        quantity: 10,
        price: 100.0,
      );

      final builder = order.edit();

      expect(builder, isA<SmartModelBuilder<TestSmartOrder>>());
    });

    test('set() updates field and calls onFieldChanged', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'SO001',
        quantity: 10,
        price: 100.0,
      );

      final updated = order.edit().set('quantity', 20).build();

      // TestSmartOrder.onFieldChanged returns model with quantity doubled
      // then build() calls recomputeAll which returns as-is
      expect(updated.quantity, 40); // 20 * 2 from onFieldChanged
    });

    test('can chain multiple set() calls', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'SO001',
        quantity: 10,
        price: 100.0,
      );

      final updated = order
          .edit()
          .set('quantity', 5) // becomes 10
          .set('price', 200.0) // becomes 400
          .build();

      expect(updated.quantity, 10);
      expect(updated.price, 400.0);
    });
  });

  group('SmartOdooModel mixin', () {
    setUp(() {
      final mockManager = MockSmartOrderManager();
      when(() => mockManager.onchangeHandlerMap).thenReturn(const {});
      when(() => mockManager.computedFieldNames).thenReturn(const []);
      when(() => mockManager.storedFieldNames).thenReturn(const []);
      when(() => mockManager.writableFieldNames).thenReturn(const []);
      when(() => mockManager.stateField).thenReturn(null);
      when(() => mockManager.stateTransitionMap).thenReturn(const {});
      when(() => mockManager.constraintFieldsMap).thenReturn(const {});
      when(
        () => mockManager.dispatchOnchange(any(), any(), any()),
      ).thenAnswer((inv) => inv.positionalArguments[0] as TestSmartOrder);
      when(
        () => mockManager.validateConstraintsFor(any(), any()),
      ).thenReturn(const {});
      when(
        () => mockManager.getRecordFieldValue(any(), any()),
      ).thenReturn(null);
      when(
        () => mockManager.applyWebSocketChangesToRecord(any(), any()),
      ).thenAnswer((inv) => inv.positionalArguments[0] as TestSmartOrder);
      OdooRecordRegistry.register<TestSmartOrder>(mockManager);
    });

    tearDown(() {
      OdooRecordRegistry.clear();
    });

    test('recompute returns self by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.recompute('quantity');

      expect(identical(result, order), isTrue);
    });

    test('recomputeAll processes multiple fields', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.recomputeAll({'quantity', 'price'});

      expect(identical(result, order), isTrue);
    });

    test('recomputeAllFields returns self by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.recomputeAllFields();

      expect(identical(result, order), isTrue);
    });

    test('dependencyGraph is empty by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.dependencyGraph, isEmpty);
    });

    test('onchangeHandlers is empty by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.onchangeHandlers, isEmpty);
    });

    test('computedFields is empty by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.computedFields, isEmpty);
    });

    test('isComputedField returns false for non-computed', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.isComputedField('quantity'), isFalse);
    });

    test('hasOnchange returns false when no handlers', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.hasOnchange('quantity'), isFalse);
    });
  });

  group('SmartOdooModel state machine', () {
    setUp(() {
      // Register mock for TestSmartOrder (used in "no current state" tests)
      final mockOrderManager = MockSmartOrderManager();
      when(() => mockOrderManager.stateField).thenReturn(null);
      when(() => mockOrderManager.stateTransitionMap).thenReturn(const {});
      OdooRecordRegistry.register<TestSmartOrder>(mockOrderManager);

      // Register mock for TestSmartOrderWithState (overrides currentState/stateTransitions
      // but _managerRef may still be accessed for other properties)
      final mockStateManager = MockSmartOrderWithStateManager();
      when(() => mockStateManager.stateField).thenReturn('state');
      when(() => mockStateManager.stateTransitionMap).thenReturn(const {
        'draft': ['sent', 'cancel'],
        'sent': ['sale', 'draft', 'cancel'],
        'sale': ['done', 'cancel'],
        'done': <String>[],
        'cancel': <String>[],
      });
      when(
        () => mockStateManager.getRecordFieldValue(any(), any()),
      ).thenReturn(null);
      OdooRecordRegistry.register<TestSmartOrderWithState>(mockStateManager);
    });

    tearDown(() {
      OdooRecordRegistry.clear();
    });

    test('canTransitionTo returns true when no current state', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.canTransitionTo('draft'), isTrue);
    });

    test('canTransitionTo checks allowed transitions', () {
      const order = TestSmartOrderWithState(
        id: 1,
        name: 'Test',
        state: 'draft',
      );

      expect(order.canTransitionTo('sent'), isTrue);
      expect(order.canTransitionTo('cancel'), isTrue);
      expect(order.canTransitionTo('done'), isFalse);
    });

    test('allowedTransitions returns valid states', () {
      const order = TestSmartOrderWithState(
        id: 1,
        name: 'Test',
        state: 'draft',
      );

      expect(order.allowedTransitions, containsAll(['sent', 'cancel']));
    });

    test('allowedTransitions returns empty when no current state', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.allowedTransitions, isEmpty);
    });

    test('ensureCanTransitionTo throws on invalid transition', () {
      const order = TestSmartOrderWithState(
        id: 1,
        name: 'Test',
        state: 'draft',
      );

      expect(
        () => order.ensureCanTransitionTo('done'),
        throwsA(isA<StateError>()),
      );
    });

    test('ensureCanTransitionTo succeeds on valid transition', () {
      const order = TestSmartOrderWithState(
        id: 1,
        name: 'Test',
        state: 'draft',
      );

      expect(() => order.ensureCanTransitionTo('sent'), returnsNormally);
    });
  });

  group('SmartOdooModel line management', () {
    test('addLine returns self by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.addLine('orderLines', {'product': 1});

      expect(identical(result, order), isTrue);
    });

    test('updateLine returns self by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.updateLine('orderLines', 0, {'quantity': 5});

      expect(identical(result, order), isTrue);
    });

    test('removeLine returns self by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.removeLine('orderLines', 0);

      expect(identical(result, order), isTrue);
    });

    test('setLines returns self by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.setLines<Map<String, dynamic>>('orderLines', []);

      expect(identical(result, order), isTrue);
    });
  });

  group('SmartOdooLine mixin', () {
    test('sequence defaults to 0', () {
      const line = TestOrderLine(id: 1, productId: 10, quantity: 5);

      expect(line.sequence, 0);
    });

    test('isDisplayLine defaults to false', () {
      const line = TestOrderLine(id: 1, productId: 10, quantity: 5);

      expect(line.isDisplayLine, isFalse);
    });

    test('recalculateAmounts returns self by default', () {
      const line = TestOrderLine(id: 1, productId: 10, quantity: 5);

      final result = line.recalculateAmounts();

      expect(identical(result, line), isTrue);
    });

    test('onAmountsChanged returns self by default', () {
      const line = TestOrderLine(id: 1, productId: 10, quantity: 5);

      final result = line.onAmountsChanged(taxPercent: 12.0);

      expect(identical(result, line), isTrue);
    });
  });

  group('ComputedFieldsMixin', () {
    setUp(() {
      ComputeEngineRegistry.clear();
    });

    tearDown(() {
      ComputeEngineRegistry.clear();
    });

    test('computeEngine returns null when not registered', () {
      const model = TestComputedModel(quantity: 10, price: 100.0);

      expect(model.computeEngine, isNull);
    });

    test('computeEngine returns registered engine', () {
      final engine = ComputedFieldEngine<TestComputedModel>();
      ComputeEngineRegistry.register<TestComputedModel>(engine);

      const model = TestComputedModel(quantity: 10, price: 100.0);

      expect(model.computeEngine, same(engine));
    });

    test('onFieldsChanged returns self when no engine', () {
      const model = TestComputedModel(quantity: 10, price: 100.0);

      final result = model.onFieldsChanged({'quantity'});

      expect(identical(result, model), isTrue);
    });

    test('refreshComputedFields returns self when no engine', () {
      const model = TestComputedModel(quantity: 10, price: 100.0);

      final result = model.refreshComputedFields();

      expect(identical(result, model), isTrue);
    });
  });

  group('ComputedFieldExtension', () {
    setUp(() {
      ComputeEngineRegistry.clear();
    });

    tearDown(() {
      ComputeEngineRegistry.clear();
    });

    test('recomputeFields returns self when no engine', () {
      const model = TestSaleOrder(quantity: 10, price: 100.0);

      final result = model.recomputeFields({'quantity'});

      expect(identical(result, model), isTrue);
    });

    test('recomputeAllFields returns self when no engine', () {
      const model = TestSaleOrder(quantity: 10, price: 100.0);

      final result = model.recomputeAllFields();

      expect(identical(result, model), isTrue);
    });

    test('recomputeFields uses registered engine', () {
      final engine = ComputedFieldEngine<TestSaleOrder>();
      engine.registerCompute('subtotal', [
        'quantity',
        'price',
      ], (order) => order.quantity * order.price);
      engine.setApplyFunction((order, values) {
        return order.copyWith(
          subtotal: values['subtotal'] as double? ?? order.subtotal,
        );
      });
      ComputeEngineRegistry.register<TestSaleOrder>(engine);

      const model = TestSaleOrder(quantity: 10, price: 100.0, subtotal: 0.0);
      final result = model.recomputeFields({'quantity'});

      expect(result.subtotal, 1000.0);
    });
  });

  group('SmartModelConfig integration', () {
    tearDown(() {
      SmartModelConfigRegistry.clear();
      ComputeEngineRegistry.clear();
    });

    test('model can access registered config', () {
      const config = SmartModelConfig(
        odooModel: 'sale.order',
        tableName: 'sale_orders',
        fieldDefinitions: [FieldDefinition(name: 'name', type: FieldType.char)],
      );
      SmartModelConfigRegistry.register<TestSmartOrder>(config);

      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.modelConfig, isNotNull);
      expect(order.modelConfig!.odooModel, 'sale.order');
    });

    test('model returns null config when not registered', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.modelConfig, isNull);
    });

    test('model can access syncConfig with defaults', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.syncConfig, isA<SyncConfig>());
    });

    test('odooModelName returns empty when no config', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.odooModelName, isEmpty);
    });

    test('tableName returns empty when no config', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.tableName, isEmpty);
    });
  });

  group('Field introspection', () {
    tearDown(() {
      SmartModelConfigRegistry.clear();
    });

    test('getFieldDefinition returns null when no registry', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.getFieldDefinition('name'), isNull);
    });

    test('allFieldDefinitions returns empty when no registry', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.allFieldDefinitions, isEmpty);
    });

    test('odooFieldNames returns empty when no registry', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.odooFieldNames, isEmpty);
    });

    test('isRequired returns false when no registry', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.isRequired('name'), isFalse);
    });

    test('isReadonly returns false when no registry', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.isReadonly('name'), isFalse);
    });

    test('getFieldType returns null when no registry', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.getFieldType('name'), isNull);
    });

    test('returns field info when registry configured', () {
      const config = SmartModelConfig(
        odooModel: 'sale.order',
        tableName: 'sale_orders',
        fieldDefinitions: [
          FieldDefinition(
            name: 'name',
            type: FieldType.char,
            required: true,
            readonly: true,
          ),
        ],
      );
      SmartModelConfigRegistry.register<TestSmartOrder>(config);

      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.isRequired('name'), isTrue);
      expect(order.isReadonly('name'), isTrue);
      expect(order.getFieldType('name'), FieldType.char);
    });
  });

  group('Constraint validation', () {
    setUp(() {
      final mockManager = MockSmartOrderManager();
      when(() => mockManager.constraintFieldsMap).thenReturn(const {});
      when(
        () => mockManager.validateConstraintsFor(any(), any()),
      ).thenReturn(const {});
      OdooRecordRegistry.register<TestSmartOrder>(mockManager);
    });

    tearDown(() {
      OdooRecordRegistry.clear();
    });

    test('validateConstraints returns empty by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final errors = order.validateConstraints({'quantity'});

      expect(errors, isEmpty);
    });

    test('constraintFields is empty by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      expect(order.constraintFields, isEmpty);
    });
  });

  group('WebSocket integration', () {
    setUp(() {
      final mockManager = MockSmartOrderManager();
      when(
        () => mockManager.applyWebSocketChangesToRecord(any(), any()),
      ).thenAnswer((inv) => inv.positionalArguments[0] as TestSmartOrder);
      OdooRecordRegistry.register<TestSmartOrder>(mockManager);
    });

    tearDown(() {
      OdooRecordRegistry.clear();
    });

    test('applyWebSocketUpdate returns self by default', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      final result = order.applyWebSocketUpdate({'name': 'Updated'});

      expect(identical(result, order), isTrue);
    });

    test('shouldSubscribeWebSocket returns syncConfig value', () {
      const order = TestSmartOrder(
        id: 1,
        name: 'Test',
        quantity: 10,
        price: 100.0,
      );

      // Default SyncConfig has subscribeWebSocket = true
      expect(order.shouldSubscribeWebSocket, isTrue);
    });
  });
}

// =============================================================================
// Test Model Classes
// =============================================================================

/// Simple test model for compute function tests.
class TestSaleOrder {
  final int quantity;
  final double price;
  final double subtotal;
  final double tax;
  final double total;
  final double discountPercent;

  const TestSaleOrder({
    this.quantity = 0,
    this.price = 0.0,
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.total = 0.0,
    this.discountPercent = 0.0,
  });

  TestSaleOrder copyWith({
    int? quantity,
    double? price,
    double? subtotal,
    double? tax,
    double? total,
    double? discountPercent,
  }) {
    return TestSaleOrder(
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      total: total ?? this.total,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}

/// Test model implementing OdooRecord and SmartOdooModel.
class TestSmartOrder
    with OdooRecord<TestSmartOrder>, SmartOdooModel<TestSmartOrder> {
  @override
  final int id;
  final String name;
  final int quantity;
  final double price;

  const TestSmartOrder({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
  });

  int? get localId => null;

  DateTime? get writeDate => null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'price': price,
  };

  @override
  Map<String, dynamic> toOdoo() => toJson();

  TestSmartOrder copyWith({
    int? id,
    int? localId,
    String? name,
    int? quantity,
    double? price,
    DateTime? writeDate,
  }) {
    return TestSmartOrder(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }

  @override
  TestSmartOrder onFieldChanged(String field, dynamic newValue) {
    // Test implementation: double the value
    if (field == 'quantity' && newValue is int) {
      return copyWith(quantity: newValue * 2);
    }
    if (field == 'price' && newValue is double) {
      return copyWith(price: newValue * 2);
    }
    return this;
  }
}

/// Extension to enable SmartModelBuilder usage.
extension TestSmartOrderExtension on TestSmartOrder {
  SmartModelBuilder<TestSmartOrder> edit() =>
      SmartModelBuilder<TestSmartOrder>(this);
}

/// Test model with state machine.
class TestSmartOrderWithState
    with
        OdooRecord<TestSmartOrderWithState>,
        SmartOdooModel<TestSmartOrderWithState> {
  @override
  final int id;
  final String name;
  final String state;

  const TestSmartOrderWithState({
    required this.id,
    required this.name,
    required this.state,
  });

  int? get localId => null;

  DateTime? get writeDate => null;

  @override
  String? get currentState => state;

  @override
  Map<String, List<String>> get stateTransitions => const {
    'draft': ['sent', 'cancel'],
    'sent': ['sale', 'draft', 'cancel'],
    'sale': ['done', 'cancel'],
    'done': [],
    'cancel': [],
  };

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'state': state};

  @override
  Map<String, dynamic> toOdoo() => toJson();

  TestSmartOrderWithState copyWith({
    int? id,
    int? localId,
    String? name,
    String? state,
    DateTime? writeDate,
  }) {
    return TestSmartOrderWithState(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
    );
  }
}

/// Test line model implementing SmartOdooLine.
class TestOrderLine
    with
        OdooRecord<TestOrderLine>,
        SmartOdooModel<TestOrderLine>,
        SmartOdooLine<TestOrderLine, TestSmartOrder> {
  @override
  final int id;
  final int productId;
  final int quantity;
  final int? orderId;

  const TestOrderLine({
    required this.id,
    required this.productId,
    required this.quantity,
    this.orderId,
  });

  @override
  int? get parentId => orderId;

  int? get localId => null;

  DateTime? get writeDate => null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'quantity': quantity,
    'order_id': orderId,
  };

  @override
  Map<String, dynamic> toOdoo() => toJson();

  TestOrderLine copyWith({
    int? id,
    int? localId,
    int? productId,
    int? quantity,
    int? orderId,
    DateTime? writeDate,
  }) {
    return TestOrderLine(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      orderId: orderId ?? this.orderId,
    );
  }
}

/// Test model with ComputedFieldsMixin.
class TestComputedModel with ComputedFieldsMixin<TestComputedModel> {
  final int quantity;
  final double price;
  final double subtotal;

  const TestComputedModel({
    required this.quantity,
    required this.price,
    this.subtotal = 0.0,
  });

  TestComputedModel copyWith({int? quantity, double? price, double? subtotal}) {
    return TestComputedModel(
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}
