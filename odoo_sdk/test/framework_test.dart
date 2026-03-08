/// Simple test to verify the framework compiles and can be instantiated.
import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('OdooClient', () {
    test('can be instantiated with config', () {
      const config = OdooClientConfig(
        baseUrl: 'https://test.odoo.com',
        apiKey: 'test_api_key_123',
        database: 'test_db',
      );

      expect(config.baseUrl, equals('https://test.odoo.com'));
      expect(config.apiKey, equals('test_api_key_123'));
      expect(config.database, equals('test_db'));
    });

    test('client can be created', () {
      const config = OdooClientConfig(
        baseUrl: 'https://test.odoo.com',
        apiKey: 'test_api_key_123',
        database: 'test_db',
      );

      final client = OdooClient(config: config);
      expect(client, isNotNull);
      expect(client.isConfigured, isTrue);
    });
  });

  group('Field Annotations', () {
    test('OdooModel annotation has correct properties', () {
      const annotation = OdooModel('product.product', tableName: 'products');
      expect(annotation.modelName, equals('product.product'));
      expect(annotation.tableName, equals('products'));
    });

    test('OdooString annotation with odooName', () {
      const annotation = OdooString(odooName: 'default_code');
      expect(annotation.odooName, equals('default_code'));
    });

    test('OdooFloat annotation with precision', () {
      const annotation = OdooFloat(odooName: 'list_price', precision: 4);
      expect(annotation.odooName, equals('list_price'));
      expect(annotation.precision, equals(4));
    });

    test('OdooMany2One annotation', () {
      const annotation = OdooMany2One('product.category', odooName: 'categ_id');
      expect(annotation.relatedModel, equals('product.category'));
      expect(annotation.odooName, equals('categ_id'));
    });

    test('OdooMany2OneName annotation', () {
      const annotation = OdooMany2OneName(sourceField: 'categ_id');
      expect(annotation.sourceField, equals('categ_id'));
    });

    test('OdooSelection annotation with optional options', () {
      const annotation1 = OdooSelection(odooName: 'state');
      expect(annotation1.options, isNull);

      const annotation2 = OdooSelection(
        options: {'draft': 'Draft', 'done': 'Done'},
      );
      expect(annotation2.options, isNotNull);
      expect(annotation2.options!.length, equals(2));
    });
  });

  group('SyncResult', () {
    test('success result', () {
      final result = SyncResult.success(model: 'product.product', synced: 100);
      expect(result.isSuccess, isTrue);
      expect(result.synced, equals(100));
    });

    test('offline result', () {
      final result = SyncResult.offline(model: 'product.product');
      expect(result.isSuccess, isFalse);
      expect(result.status, equals(SyncStatus.offline));
    });

    test('cancelled result', () {
      final result = SyncResult.cancelled(model: 'product.product', synced: 50);
      expect(result.status, equals(SyncStatus.cancelled));
      expect(result.synced, equals(50));
    });
  });

  group('OfflineQueue', () {
    test('OfflineOperation can be created', () {
      final op = OfflineOperation(
        id: 1,
        model: 'product.product',
        method: 'create',
        recordId: -123,
        values: {'name': 'Test Product'},
        createdAt: DateTime.now(),
      );

      expect(op.id, equals(1));
      expect(op.model, equals('product.product'));
      expect(op.method, equals('create'));
    });

    test('OfflinePriority ordering', () {
      expect(OfflinePriority.critical < OfflinePriority.high, isTrue);
      expect(OfflinePriority.high < OfflinePriority.normal, isTrue);
      expect(OfflinePriority.normal < OfflinePriority.low, isTrue);
    });
  });

  group('Parsing Utils', () {
    test('extractMany2oneId from array', () {
      final result = extractMany2oneId([123, 'Partner Name']);
      expect(result, equals(123));
    });

    test('extractMany2oneId from int', () {
      final result = extractMany2oneId(456);
      expect(result, equals(456));
    });

    test('extractMany2oneId from false', () {
      final result = extractMany2oneId(false);
      expect(result, isNull);
    });

    test('extractMany2oneName from array', () {
      final result = extractMany2oneName([123, 'Partner Name']);
      expect(result, equals('Partner Name'));
    });

    test('parseOdooDateTime', () {
      final result = parseOdooDateTime('2024-01-15 10:30:00');
      expect(result, isNotNull);
      expect(result!.year, equals(2024));
      expect(result.month, equals(1));
      expect(result.day, equals(15));
    });

    test('parseOdooDouble conversions', () {
      expect(parseOdooDouble(10), equals(10.0));
      expect(parseOdooDouble(10.5), equals(10.5));
      expect(parseOdooDouble('10.5'), equals(10.5));
      expect(parseOdooDouble(null), equals(0.0));
      expect(parseOdooDouble(false), equals(0.0));
    });
  });

  group('WebSocket', () {
    test('WebSocketConfig can be created', () {
      const config = WebSocketConfig(
        url: 'wss://test.odoo.com/websocket',
        database: 'test_db',
        userId: 2,
        subscribedModels: ['product.product', 'res.partner'],
      );

      expect(config.url, equals('wss://test.odoo.com/websocket'));
      expect(config.database, equals('test_db'));
      expect(config.userId, equals(2));
      expect(config.subscribedModels.length, equals(2));
    });

    test('ModelRecordEvent can be created', () {
      final event = ModelRecordEvent(
        model: 'product.product',
        recordId: 123,
        operation: RecordOperation.write,
        timestamp: DateTime.now(),
      );

      expect(event.model, equals('product.product'));
      expect(event.recordId, equals(123));
      expect(event.operation, equals(RecordOperation.write));
    });
  });
}
