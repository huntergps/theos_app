import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('OfflinePriority', () {
    test('critical is 0', () {
      expect(OfflinePriority.critical, 0);
    });

    test('high is 1', () {
      expect(OfflinePriority.high, 1);
    });

    test('normal is 2', () {
      expect(OfflinePriority.normal, 2);
    });

    test('low is 3', () {
      expect(OfflinePriority.low, 3);
    });

    test('priorities are ordered correctly', () {
      expect(OfflinePriority.critical < OfflinePriority.high, true);
      expect(OfflinePriority.high < OfflinePriority.normal, true);
      expect(OfflinePriority.normal < OfflinePriority.low, true);
    });
  });

  group('RetryBackoff', () {
    test('maxRetries is 10', () {
      expect(RetryBackoff.maxRetries, 10);
    });

    test('getNextRetryDelay returns zero for retry 0', () {
      expect(RetryBackoff.getNextRetryDelay(0), Duration.zero);
    });

    test('getNextRetryDelay returns 30s for retry 1', () {
      expect(RetryBackoff.getNextRetryDelay(1), const Duration(seconds: 30));
    });

    test('getNextRetryDelay returns 2min for retry 2', () {
      expect(RetryBackoff.getNextRetryDelay(2), const Duration(minutes: 2));
    });

    test('getNextRetryDelay returns 10min for retry 3', () {
      expect(RetryBackoff.getNextRetryDelay(3), const Duration(minutes: 10));
    });

    test('getNextRetryDelay returns 30min for retry 4', () {
      expect(RetryBackoff.getNextRetryDelay(4), const Duration(minutes: 30));
    });

    test('getNextRetryDelay caps at 1 hour for retry 5+', () {
      expect(RetryBackoff.getNextRetryDelay(5), const Duration(hours: 1));
      expect(RetryBackoff.getNextRetryDelay(10), const Duration(hours: 1));
    });

    test('shouldRetry returns true for count < maxRetries', () {
      expect(RetryBackoff.shouldRetry(0), true);
      expect(RetryBackoff.shouldRetry(5), true);
      expect(RetryBackoff.shouldRetry(9), true);
    });

    test('shouldRetry returns false for count >= maxRetries', () {
      expect(RetryBackoff.shouldRetry(10), false);
      expect(RetryBackoff.shouldRetry(15), false);
    });
  });

  group('OfflineOperation', () {
    test('creates with required fields', () {
      final op = OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'write',
        recordId: 42,
        values: {'name': 'Test'},
        createdAt: DateTime(2024, 1, 1),
      );

      expect(op.id, 1);
      expect(op.model, 'sale.order');
      expect(op.method, 'write');
      expect(op.recordId, 42);
      expect(op.values, {'name': 'Test'});
    });

    test('defaults priority to normal', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
      );
      expect(op.priority, OfflinePriority.normal);
    });

    test('defaults retryCount to 0', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
      );
      expect(op.retryCount, 0);
    });

    test('isReadyForRetry returns true when nextRetryAt is null', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
        nextRetryAt: null,
      );
      expect(op.isReadyForRetry, true);
    });

    test('isReadyForRetry returns true when nextRetryAt is in past', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
        nextRetryAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(op.isReadyForRetry, true);
    });

    test('isReadyForRetry returns false when nextRetryAt is in future', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
        nextRetryAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      expect(op.isReadyForRetry, false);
    });

    test('hasExceededMaxRetries based on retryCount', () {
      final opLow = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
        retryCount: 5,
      );
      expect(opLow.hasExceededMaxRetries, false);

      final opHigh = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'write',
        values: {},
        createdAt: DateTime.now(),
        retryCount: 10,
      );
      expect(opHigh.hasExceededMaxRetries, true);
    });

    test('toMap returns all fields', () {
      final now = DateTime.now();
      final op = OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'write',
        recordId: 42,
        values: {'name': 'Test'},
        createdAt: now,
        baseWriteDate: now,
        parentOrderId: 100,
        priority: OfflinePriority.high,
        deviceId: 'device-123',
        retryCount: 2,
        lastRetryAt: now,
        nextRetryAt: now.add(const Duration(minutes: 2)),
        lastError: 'Previous error',
      );

      final map = op.toMap();
      expect(map['id'], 1);
      expect(map['model'], 'sale.order');
      expect(map['method'], 'write');
      expect(map['record_id'], 42);
      expect(map['values'], {'name': 'Test'});
      expect(map['created_at'], now);
      expect(map['base_write_date'], now);
      expect(map['parent_order_id'], 100);
      expect(map['priority'], OfflinePriority.high);
      expect(map['device_id'], 'device-123');
      expect(map['retry_count'], 2);
      expect(map['last_error'], 'Previous error');
    });

    test('supports create operations without recordId', () {
      final op = OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'create',
        recordId: null,
        values: {'name': 'New Order'},
        createdAt: DateTime.now(),
      );

      expect(op.recordId, null);
      expect(op.method, 'create');
    });
  });
}
