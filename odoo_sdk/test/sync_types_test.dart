import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('SyncProgressEvent', () {
    test('calculates progress percentage', () {
      const event = SyncProgressEvent(
        operationId: 1,
        current: 50,
        total: 100,
        status: SyncOperationStatus.processing,
      );
      expect(event.progress, 0.5);
    });

    test('handles zero total', () {
      const event = SyncProgressEvent(
        operationId: 1,
        current: 0,
        total: 0,
        status: SyncOperationStatus.pending,
      );
      expect(event.progress, 0.0);
    });

    test('toString includes error when present', () {
      const event = SyncProgressEvent(
        operationId: 1,
        current: 5,
        total: 10,
        status: SyncOperationStatus.failed,
        error: 'Connection failed',
      );
      expect(event.toString(), contains('error: Connection failed'));
    });
  });

  group('QueueProcessResult', () {
    test('hasErrors returns true when failed > 0', () {
      const result = QueueProcessResult(synced: 5, failed: 2);
      expect(result.hasErrors, true);
    });

    test('hasErrors returns false when failed = 0', () {
      const result = QueueProcessResult(synced: 5, failed: 0);
      expect(result.hasErrors, false);
    });

    test('hasConflicts returns true when conflicts exist', () {
      final result = QueueProcessResult(
        synced: 5,
        failed: 0,
        conflicts: [
          ConflictInfo(
            operationId: 1,
            model: 'sale.order',
            recordId: 42,
            localWriteDate: DateTime(2024, 1, 1),
            serverWriteDate: DateTime(2024, 1, 2),
            localValues: {},
          ),
        ],
      );
      expect(result.hasConflicts, true);
    });

    test('isEmpty returns true for empty result', () {
      const result = QueueProcessResult(synced: 0, failed: 0);
      expect(result.isEmpty, true);
    });

    test('total calculates synced + failed + skipped', () {
      const result = QueueProcessResult(synced: 5, failed: 2, skipped: 3);
      expect(result.total, 10);
    });

    test('merge combines two results', () {
      const result1 = QueueProcessResult(
        synced: 5,
        failed: 1,
        errors: ['Error 1'],
      );
      const result2 = QueueProcessResult(
        synced: 3,
        failed: 2,
        errors: ['Error 2'],
      );

      final merged = result1.merge(result2);
      expect(merged.synced, 8);
      expect(merged.failed, 3);
      expect(merged.errors, ['Error 1', 'Error 2']);
    });

    test('copyWithExtra adds extra data', () {
      const result = QueueProcessResult(
        synced: 5,
        failed: 0,
        extra: {'key1': 'value1'},
      );
      final updated = result.copyWithExtra({'key2': 'value2'});
      expect(updated.extra['key1'], 'value1');
      expect(updated.extra['key2'], 'value2');
    });

    test('noConnection constant is correct', () {
      expect(QueueProcessResult.noConnection.synced, 0);
      expect(QueueProcessResult.noConnection.failed, 0);
    });

    test('empty constant is correct', () {
      expect(QueueProcessResult.empty.isEmpty, true);
    });
  });

  group('SyncResult', () {
    test('success factory creates success status', () {
      final result = SyncResult.success(model: 'product.product', synced: 10);
      expect(result.status, SyncStatus.success);
      expect(result.synced, 10);
    });

    test('success factory creates partial when failed > 0', () {
      final result = SyncResult.success(
        model: 'product.product',
        synced: 10,
        failed: 2,
      );
      expect(result.status, SyncStatus.partial);
    });

    test('cancelled factory creates cancelled status', () {
      final result = SyncResult.cancelled(model: 'product.product', synced: 5);
      expect(result.status, SyncStatus.cancelled);
      expect(result.synced, 5);
    });

    test('offline factory creates offline status', () {
      final result = SyncResult.offline(model: 'product.product');
      expect(result.status, SyncStatus.offline);
    });

    test('error factory creates error status', () {
      final result = SyncResult.error(
        model: 'product.product',
        error: 'Connection failed',
      );
      expect(result.status, SyncStatus.error);
      expect(result.error, 'Connection failed');
    });

    test('isSuccess returns true for success and partial', () {
      final success = SyncResult.success(model: 'test', synced: 10);
      final partial = SyncResult.success(model: 'test', synced: 10, failed: 2);

      expect(success.isSuccess, true);
      expect(partial.isSuccess, true);
    });

    test('hasFailures returns true for errors', () {
      final result = SyncResult.error(model: 'test', error: 'Failed');
      expect(result.hasFailures, true);
    });

    test('errors wraps single error in list', () {
      final result = SyncResult.error(model: 'test', error: 'Error message');
      expect(result.errors, ['Error message']);
    });

    test('errors returns empty list when no error', () {
      final result = SyncResult.success(model: 'test', synced: 10);
      expect(result.errors, isEmpty);
    });

    test('fromQueueResult creates SyncResult from QueueProcessResult', () {
      const qr = QueueProcessResult(
        synced: 10,
        failed: 2,
        errors: ['Error 1', 'Error 2'],
      );
      final result = SyncResult.fromQueueResult(qr, model: 'sale.order');

      expect(result.model, 'sale.order');
      expect(result.synced, 10);
      expect(result.failed, 2);
      expect(result.status, SyncStatus.partial);
    });

    test('merge combines two results', () {
      final result1 = SyncResult.success(model: 'model1', synced: 5);
      final result2 = SyncResult.success(model: 'model2', synced: 3);

      final merged = result1.merge(result2);
      expect(merged.synced, 8);
      expect(merged.model, 'model1+model2');
    });

    test('combined creates proper combined result', () {
      final upload = SyncResult.success(model: 'upload', synced: 5);
      final download = SyncResult.success(model: 'download', synced: 10);

      final combined = SyncResult.combined(upload, download);
      expect(combined.synced, 15);
      expect(combined.status, SyncStatus.success);
    });

    test('combined handles errors', () {
      final upload = SyncResult.error(model: 'upload', error: 'Upload failed');
      final download = SyncResult.success(model: 'download', synced: 10);

      final combined = SyncResult.combined(upload, download);
      expect(combined.status, SyncStatus.error);
      expect(combined.error, contains('Upload'));
    });
  });

  group('SyncReport', () {
    test('totalSynced sums all results', () {
      final report = SyncReport(
        results: [
          SyncResult.success(model: 'model1', synced: 10),
          SyncResult.success(model: 'model2', synced: 20),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      expect(report.totalSynced, 30);
    });

    test('totalFailed sums all failures', () {
      final report = SyncReport(
        results: [
          SyncResult.success(model: 'model1', synced: 10, failed: 2),
          SyncResult.success(model: 'model2', synced: 20, failed: 3),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      expect(report.totalFailed, 5);
    });

    test('duration calculates time difference', () {
      final start = DateTime(2024, 1, 1, 10, 0, 0);
      final end = DateTime(2024, 1, 1, 10, 5, 30);

      final report = SyncReport(results: [], startTime: start, endTime: end);
      expect(report.duration.inSeconds, 330);
    });

    test('allSuccess returns true when all succeed', () {
      final report = SyncReport(
        results: [
          SyncResult.success(model: 'model1', synced: 10),
          SyncResult.success(model: 'model2', synced: 20),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      expect(report.allSuccess, true);
    });

    test('hasErrors returns true when any has error', () {
      final report = SyncReport(
        results: [
          SyncResult.success(model: 'model1', synced: 10),
          SyncResult.error(model: 'model2', error: 'Failed'),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
      expect(report.hasErrors, true);
    });

    test('forModel returns specific result', () {
      final report = SyncReport(
        results: [
          SyncResult.success(model: 'model1', synced: 10),
          SyncResult.success(model: 'model2', synced: 20),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );

      final result = report.forModel('model2');
      expect(result, isNotNull);
      expect(result!.synced, 20);
    });
  });

  group('ConflictInfo', () {
    test('timeDifference calculates difference', () {
      final conflict = ConflictInfo(
        operationId: 1,
        model: 'sale.order',
        recordId: 42,
        localWriteDate: DateTime(2024, 1, 1, 10, 0),
        serverWriteDate: DateTime(2024, 1, 1, 12, 0),
        localValues: {},
      );
      expect(conflict.timeDifference.inHours, 2);
    });

    test('toString includes model and record id', () {
      final conflict = ConflictInfo(
        operationId: 1,
        model: 'sale.order',
        recordId: 42,
        localWriteDate: DateTime(2024, 1, 1),
        serverWriteDate: DateTime(2024, 1, 2),
        localValues: {'name': 'Test'},
      );
      expect(conflict.toString(), contains('sale.order'));
      expect(conflict.toString(), contains('42'));
    });
  });

  group('Exceptions', () {
    test('OperationSkippedException has reason', () {
      const exception = OperationSkippedException('Record not found');
      expect(exception.reason, 'Record not found');
      expect(exception.toString(), contains('Record not found'));
    });

    test('SyncConflictException includes conflict info', () {
      final conflict = ConflictInfo(
        operationId: 1,
        model: 'sale.order',
        recordId: 42,
        localWriteDate: DateTime(2024, 1, 1),
        serverWriteDate: DateTime(2024, 1, 2),
        localValues: {},
      );
      final exception = SyncConflictException(conflict);

      expect(exception.conflict, conflict);
      expect(exception.toString(), contains('sale.order'));
    });
  });

  group('FieldChange', () {
    test('hasChanged returns true when values differ', () {
      const change = FieldChange(
        fieldName: 'name',
        oldValue: 'Old',
        newValue: 'New',
      );
      expect(change.hasChanged, true);
    });

    test('hasChanged returns false when values same', () {
      const change = FieldChange(
        fieldName: 'name',
        oldValue: 'Same',
        newValue: 'Same',
      );
      expect(change.hasChanged, false);
    });
  });
}
