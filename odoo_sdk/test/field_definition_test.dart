/// Tests for FieldDefinition and FieldRegistry
import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('FieldDefinition', () {
    test('creates basic field definition', () {
      const field = FieldDefinition(name: 'productName', type: FieldType.char);

      expect(field.name, equals('productName'));
      expect(field.type, equals(FieldType.char));
      expect(
        field.effectiveOdooName,
        equals('product_name'),
      ); // auto snake_case
      expect(field.required, isFalse);
      expect(field.readonly, isFalse);
    });

    test('respects explicit odooName', () {
      const field = FieldDefinition(
        name: 'price',
        type: FieldType.float,
        odooName: 'list_price',
      );

      expect(field.effectiveOdooName, equals('list_price'));
    });

    test('effectiveLabel returns label or derived name', () {
      const fieldWithLabel = FieldDefinition(
        name: 'price',
        type: FieldType.float,
        label: 'Product Price',
      );

      const fieldWithoutLabel = FieldDefinition(
        name: 'productQty',
        type: FieldType.integer,
      );

      expect(fieldWithLabel.effectiveLabel, equals('Product Price'));
      // effectiveLabel derives from name
      expect(fieldWithoutLabel.effectiveLabel, isNotEmpty);
    });

    test('computed field configuration', () {
      const field = FieldDefinition(
        name: 'total',
        type: FieldType.computed,
        compute: '_computeTotal',
        depends: ['subtotal', 'tax'],
      );

      expect(field.isComputed, isTrue);
      expect(field.depends, containsAll(['subtotal', 'tax']));
      expect(field.compute, equals('_computeTotal'));
    });

    test('relational field configuration', () {
      const field = FieldDefinition(
        name: 'partnerId',
        type: FieldType.many2one,
        relatedModel: 'res.partner',
      );

      expect(field.relatedModel, equals('res.partner'));
    });

    test('selection field with options', () {
      const field = FieldDefinition(
        name: 'state',
        type: FieldType.selection,
        selectionOptions: {'draft': 'Draft', 'done': 'Done'},
      );

      expect(field.selectionOptions, isNotNull);
      expect(field.selectionOptions!.length, equals(2));
    });

    group('field flags', () {
      test('isReadable returns false for local-only fields', () {
        const field = FieldDefinition(
          name: 'uuid',
          type: FieldType.char,
          localOnly: true,
        );

        expect(field.isReadable, isFalse);
      });

      test('isWritable respects readonly flag', () {
        const readonlyField = FieldDefinition(
          name: 'total',
          type: FieldType.float,
          readonly: true,
        );

        const writableField = FieldDefinition(
          name: 'price',
          type: FieldType.float,
        );

        expect(readonlyField.isWritable, isFalse);
        expect(writableField.isWritable, isTrue);
      });
    });
  });

  group('FieldBuilder', () {
    test('char field builder', () {
      final field = FieldBuilder.char(
        'name',
      ).label('Product Name').isRequired().build();

      expect(field.type, equals(FieldType.char));
      expect(field.name, equals('name'));
      expect(field.label, equals('Product Name'));
      expect(field.required, isTrue);
    });

    test('integer field builder', () {
      final field = FieldBuilder.integer('quantity').isRequired().build();

      expect(field.type, equals(FieldType.integer));
      expect(field.required, isTrue);
    });

    test('float field builder', () {
      final field = FieldBuilder.float('price').odooName('list_price').build();

      expect(field.type, equals(FieldType.float));
      expect(field.odooName, equals('list_price'));
    });

    test('monetary field builder', () {
      final field = FieldBuilder.monetary('amount').build();

      expect(field.type, equals(FieldType.monetary));
    });

    test('selection field builder', () {
      final field = FieldBuilder.selection('state', {
        'draft': 'Draft',
        'confirmed': 'Confirmed',
        'done': 'Done',
      }).build();

      expect(field.type, equals(FieldType.selection));
      expect(field.selectionOptions!.length, equals(3));
    });

    test('many2one field builder', () {
      final field = FieldBuilder.many2one('partnerId', 'res.partner').build();

      expect(field.type, equals(FieldType.many2one));
      expect(field.relatedModel, equals('res.partner'));
    });

    test('one2many field builder', () {
      final field = FieldBuilder.one2many(
        'orderLines',
        'sale.order.line',
        'orderId',
      ).build();

      expect(field.type, equals(FieldType.one2many));
      expect(field.relatedModel, equals('sale.order.line'));
      expect(field.inverseField, equals('orderId'));
    });

    test('localOnly field builder', () {
      final field = FieldBuilder.char('localUuid').localOnly().build();

      expect(field.localOnly, isTrue);
      expect(field.isReadable, isFalse);
    });

    test('chained builder methods', () {
      final field = FieldBuilder.char('code')
          .label('Product Code')
          .odooName('default_code')
          .isRequired()
          .isReadonly()
          .help('Internal reference code')
          .build();

      expect(field.label, equals('Product Code'));
      expect(field.odooName, equals('default_code'));
      expect(field.required, isTrue);
      expect(field.readonly, isTrue);
      expect(field.help, equals('Internal reference code'));
    });
  });

  group('FieldRegistry', () {
    late FieldRegistry registry;

    setUp(() {
      registry = FieldRegistry('test.model');
    });

    test('model name is stored', () {
      expect(registry.modelName, equals('test.model'));
    });

    test('register single field', () {
      registry.register(
        const FieldDefinition(name: 'price', type: FieldType.float),
      );

      expect(registry['price'], isNotNull);
      expect(registry['price']!.type, equals(FieldType.float));
    });

    test('register multiple fields', () {
      registry.registerAll([
        const FieldDefinition(name: 'name', type: FieldType.char),
        const FieldDefinition(name: 'price', type: FieldType.float),
        const FieldDefinition(name: 'qty', type: FieldType.integer),
      ]);

      expect(registry.all.length, equals(3));
    });

    test('required fields collection', () {
      registry.registerAll([
        const FieldDefinition(
          name: 'name',
          type: FieldType.char,
          required: true,
        ),
        const FieldDefinition(name: 'price', type: FieldType.float),
        const FieldDefinition(
          name: 'partnerId',
          type: FieldType.many2one,
          relatedModel: 'res.partner',
          required: true,
        ),
      ]);

      final required = registry.required.toList();
      expect(required.length, equals(2));
      expect(required.map((f) => f.name), containsAll(['name', 'partnerId']));
    });

    test('computed fields collection', () {
      registry.registerAll([
        const FieldDefinition(name: 'price', type: FieldType.float),
        const FieldDefinition(
          name: 'subtotal',
          type: FieldType.computed,
          compute: '_computeSubtotal',
          depends: ['price', 'qty'],
        ),
        const FieldDefinition(
          name: 'total',
          type: FieldType.computed,
          compute: '_computeTotal',
          depends: ['subtotal', 'tax'],
        ),
      ]);

      final computed = registry.computed.toList();
      expect(computed.length, equals(2));
    });

    test('odooFieldNames excludes local-only fields', () {
      registry.registerAll([
        const FieldDefinition(name: 'name', type: FieldType.char),
        const FieldDefinition(
          name: 'uuid',
          type: FieldType.char,
          localOnly: true,
        ),
        const FieldDefinition(name: 'price', type: FieldType.float),
      ]);

      final odooFields = registry.odooFieldNames;
      expect(odooFields, contains('name'));
      expect(odooFields, contains('price'));
      expect(odooFields, isNot(contains('uuid')));
    });

    test('byOdooName retrieves field by Odoo name', () {
      registry.register(
        const FieldDefinition(
          name: 'partnerId',
          type: FieldType.many2one,
          relatedModel: 'res.partner',
          odooName: 'partner_id',
        ),
      );

      final field = registry.byOdooName('partner_id');
      expect(field, isNotNull);
      expect(field!.name, equals('partnerId'));
    });
  });

  group('ModelFieldRegistry', () {
    tearDown(() {
      ModelFieldRegistry.clear();
    });

    test('register and get by type', () {
      final registry = FieldRegistry('product.product');
      ModelFieldRegistry.register<_TestProduct>(registry);

      final retrieved = ModelFieldRegistry.get<_TestProduct>();
      expect(retrieved, same(registry));
    });

    test('returns null for unregistered type', () {
      final retrieved = ModelFieldRegistry.get<_TestProduct>();
      expect(retrieved, isNull);
    });
  });
}

/// Test class for registry tests
class _TestProduct {}
