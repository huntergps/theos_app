/// Tests for ComputedFieldEngine
import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('ComputedFieldEngine', () {
    late ComputedFieldEngine<_TestModel> engine;

    setUp(() {
      engine = ComputedFieldEngine<_TestModel>();
    });

    group('registerDependencies', () {
      test('registers simple dependencies', () {
        engine.registerDependencies('amountTotal', ['quantity', 'price']);

        expect(engine.getDependents('quantity'), contains('amountTotal'));
        expect(engine.getDependents('price'), contains('amountTotal'));
      });

      test('handles dot notation dependencies', () {
        engine.registerDependencies('amountTotal', [
          'orderLines.priceSubtotal',
        ]);

        // Should use base field name
        expect(engine.getDependents('orderLines'), contains('amountTotal'));
      });

      test('multiple computed fields can depend on same field', () {
        engine.registerDependencies('subtotal', ['quantity', 'price']);
        engine.registerDependencies('tax', ['subtotal']);
        engine.registerDependencies('total', ['subtotal', 'tax']);

        expect(engine.getDependents('quantity'), contains('subtotal'));
        expect(engine.getDependents('subtotal'), containsAll(['tax', 'total']));
      });
    });

    group('getAffectedFields', () {
      setUp(() {
        engine.registerDependencies('subtotal', ['quantity', 'price']);
        engine.registerDependencies('tax', ['subtotal']);
        engine.registerDependencies('total', ['subtotal', 'tax']);
      });

      test('finds direct dependents', () {
        final affected = engine.getAffectedFields({'quantity'});
        expect(affected, contains('subtotal'));
      });

      test('finds transitive dependents', () {
        final affected = engine.getAffectedFields({'quantity'});

        // quantity -> subtotal -> tax, total
        expect(affected, containsAll(['subtotal', 'tax', 'total']));
      });

      test('handles multiple changed fields', () {
        final affected = engine.getAffectedFields({'quantity', 'price'});

        expect(affected, containsAll(['subtotal', 'tax', 'total']));
      });

      test('returns empty set when no dependents', () {
        final affected = engine.getAffectedFields({'nonExistent'});
        expect(affected, isEmpty);
      });
    });

    group('computeOrder', () {
      test('returns topological order', () {
        engine.registerDependencies('subtotal', ['quantity', 'price']);
        engine.registerDependencies('tax', ['subtotal']);
        engine.registerDependencies('total', ['subtotal', 'tax']);

        final order = engine.computeOrder;

        // subtotal must come before tax and total
        expect(order.indexOf('subtotal'), lessThan(order.indexOf('tax')));
        expect(order.indexOf('subtotal'), lessThan(order.indexOf('total')));
        // tax must come before total
        expect(order.indexOf('tax'), lessThan(order.indexOf('total')));
      });

      test('caches computed order', () {
        engine.registerDependencies('subtotal', ['quantity']);

        final order1 = engine.computeOrder;
        final order2 = engine.computeOrder;

        expect(identical(order1, order2), isTrue);
      });
    });

    group('isComputed', () {
      test('returns true for computed fields', () {
        engine.registerDependencies('subtotal', ['quantity']);

        expect(engine.isComputed('subtotal'), isTrue);
        expect(engine.isComputed('quantity'), isFalse);
      });
    });

    group('getDependencies', () {
      test('returns dependencies for computed field', () {
        engine.registerDependencies('subtotal', ['quantity', 'price']);

        final deps = engine.getDependencies('subtotal');
        expect(deps, containsAll(['quantity', 'price']));
      });

      test('returns empty set for non-computed field', () {
        final deps = engine.getDependencies('quantity');
        expect(deps, isEmpty);
      });
    });

    group('clear', () {
      test('clears all state', () {
        engine.registerDependencies('subtotal', ['quantity']);

        engine.clear();

        expect(engine.getDependents('quantity'), isEmpty);
        expect(engine.isComputed('subtotal'), isFalse);
      });
    });
  });

  group('ComputedFieldEngine.fromConfig', () {
    test('builds engine from SmartModelConfig', () {
      const config = SmartModelConfig(
        odooModel: 'test.model',
        tableName: 'test_model',
        fieldDefinitions: [
          FieldDefinition(name: 'quantity', type: FieldType.integer),
          FieldDefinition(name: 'price', type: FieldType.float),
          FieldDefinition(
            name: 'subtotal',
            type: FieldType.computed,
            compute: '_computeSubtotal',
            depends: ['quantity', 'price'],
          ),
        ],
      );

      final engine = ComputedFieldEngine<_TestModel>.fromConfig(config);

      expect(engine.isComputed('subtotal'), isTrue);
      expect(engine.getDependents('quantity'), contains('subtotal'));
      expect(engine.getDependents('price'), contains('subtotal'));
    });
  });

  group('ComputedFieldEngine.fromRegistry', () {
    test('builds engine from FieldRegistry', () {
      final registry = FieldRegistry('test.model');
      registry.registerAll([
        const FieldDefinition(name: 'quantity', type: FieldType.integer),
        const FieldDefinition(
          name: 'subtotal',
          type: FieldType.computed,
          compute: '_computeSubtotal',
          depends: ['quantity'],
        ),
      ]);

      final engine = ComputedFieldEngine<_TestModel>.fromRegistry(registry);

      expect(engine.isComputed('subtotal'), isTrue);
      expect(engine.getDependents('quantity'), contains('subtotal'));
    });
  });

  group('ComputeEngineRegistry', () {
    tearDown(() {
      ComputeEngineRegistry.clear();
    });

    test('can register and retrieve engine by type', () {
      final engine = ComputedFieldEngine<_TestModel>();
      ComputeEngineRegistry.register<_TestModel>(engine);

      final retrieved = ComputeEngineRegistry.get<_TestModel>();
      expect(retrieved, same(engine));
    });

    test('returns null for unregistered type', () {
      final retrieved = ComputeEngineRegistry.get<_TestModel>();
      expect(retrieved, isNull);
    });

    test('has() checks registration', () {
      expect(ComputeEngineRegistry.has<_TestModel>(), isFalse);

      ComputeEngineRegistry.register<_TestModel>(
        ComputedFieldEngine<_TestModel>(),
      );

      expect(ComputeEngineRegistry.has<_TestModel>(), isTrue);
    });
  });
}

/// Test model class for engine tests
class _TestModel {
  final int quantity;
  final double price;
  final double subtotal;

  _TestModel({this.quantity = 0, this.price = 0.0, this.subtotal = 0.0});

  _TestModel copyWith({int? quantity, double? price, double? subtotal}) {
    return _TestModel(
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}
