import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('SyncMetricsCollector', () {
    late SyncMetricsCollector collector;

    setUp(() {
      collector = SyncMetricsCollector();
    });

    test('records sync metrics from SyncResult', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 2));
      final result = SyncResult(
        model: 'sale.order',
        status: SyncStatus.success,
        synced: 10,
        failed: 2,
        timestamp: DateTime.now(),
      );

      collector.recordFromResult(result, startTime: startTime);

      expect(collector.metrics.length, equals(1));
      expect(collector.metrics.first.model, equals('sale.order'));
      expect(collector.metrics.first.recordsSynced, equals(10));
      expect(collector.metrics.first.recordsFailed, equals(2));
      expect(collector.metrics.first.durationMs, greaterThan(1900));
    });

    test('calculates model metrics correctly', () {
      // Add multiple sync operations for the same model
      for (var i = 0; i < 5; i++) {
        final startTime = DateTime.now().subtract(Duration(milliseconds: 100 * (i + 1)));
        collector.record(SyncOperationMetric(
          model: 'res.partner',
          startTime: startTime,
          endTime: DateTime.now(),
          status: i < 4 ? SyncStatus.success : SyncStatus.error,
          recordsSynced: 10,
          recordsFailed: i < 4 ? 0 : 5,
          conflictsDetected: i == 2 ? 2 : 0,
        ));
      }

      final metrics = collector.getModelMetrics('res.partner');

      expect(metrics, isNotNull);
      expect(metrics!.totalOperations, equals(5));
      expect(metrics.successfulOperations, equals(4));
      expect(metrics.failedOperations, equals(1));
      expect(metrics.successRate, equals(80.0));
      expect(metrics.totalConflicts, equals(2));
    });

    test('calculates conflict rate correctly', () {
      collector.record(SyncOperationMetric(
        model: 'sale.order',
        startTime: DateTime.now().subtract(const Duration(seconds: 1)),
        endTime: DateTime.now(),
        status: SyncStatus.partial,
        recordsSynced: 8,
        recordsFailed: 0,
        conflictsDetected: 2,
      ));

      final metrics = collector.getModelMetrics('sale.order');

      expect(metrics, isNotNull);
      // Conflict rate = 2 / (8 + 0 + 2) = 20%
      expect(metrics!.conflictRate, equals(20.0));
    });

    test('returns global metrics across all models', () {
      // Add metrics for multiple models
      collector.record(SyncOperationMetric(
        model: 'sale.order',
        startTime: DateTime.now().subtract(const Duration(seconds: 1)),
        endTime: DateTime.now(),
        status: SyncStatus.success,
        recordsSynced: 10,
      ));

      collector.record(SyncOperationMetric(
        model: 'res.partner',
        startTime: DateTime.now().subtract(const Duration(seconds: 1)),
        endTime: DateTime.now(),
        status: SyncStatus.success,
        recordsSynced: 20,
      ));

      collector.record(SyncOperationMetric(
        model: 'product.product',
        startTime: DateTime.now().subtract(const Duration(seconds: 1)),
        endTime: DateTime.now(),
        status: SyncStatus.error,
        recordsFailed: 5,
      ));

      final global = collector.getGlobalMetrics();

      expect(global.byModel.length, equals(3));
      expect(global.totalOperations, equals(3));
      expect(global.totalRecordsSynced, equals(30));
      expect(global.overallSuccessRate, closeTo(66.67, 0.1));
    });

    test('timed helper records duration correctly', () async {
      final result = await collector.timed('test.model', () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return SyncResult.success(model: 'test.model', synced: 5);
      });

      expect(result.synced, equals(5));
      expect(collector.metrics.length, equals(1));
      expect(collector.metrics.first.durationMs, greaterThanOrEqualTo(50));
    });

    test('timed helper records error on failure', () async {
      try {
        await collector.timed('failing.model', () async {
          throw Exception('Sync failed');
        });
      } catch (_) {}

      expect(collector.metrics.length, equals(1));
      expect(collector.metrics.first.status, equals(SyncStatus.error));
      expect(collector.metrics.first.error, contains('Sync failed'));
    });

    test('notifies callbacks on new metrics', () {
      final receivedMetrics = <SyncOperationMetric>[];
      collector.addCallback((metric) => receivedMetrics.add(metric));

      collector.record(SyncOperationMetric(
        model: 'test',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
      ));

      expect(receivedMetrics.length, equals(1));
      expect(receivedMetrics.first.model, equals('test'));
    });

    test('respects max metrics limit', () {
      final collector = SyncMetricsCollector(maxMetrics: 5);

      for (var i = 0; i < 10; i++) {
        collector.record(SyncOperationMetric(
          model: 'model_$i',
          startTime: DateTime.now(),
          endTime: DateTime.now(),
          status: SyncStatus.success,
        ));
      }

      expect(collector.metrics.length, equals(5));
      expect(collector.metrics.first.model, equals('model_5'));
      expect(collector.metrics.last.model, equals('model_9'));
    });

    test('filters metrics by time window', () {
      // Add old metric
      collector.record(SyncOperationMetric(
        model: 'old',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        endTime: DateTime.now().subtract(const Duration(hours: 2)),
        status: SyncStatus.success,
      ));

      // Add recent metric
      collector.record(SyncOperationMetric(
        model: 'recent',
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        endTime: DateTime.now(),
        status: SyncStatus.success,
      ));

      final recentOnly = collector.metricsInWindow(
        DateTime.now().subtract(const Duration(hours: 1)),
        DateTime.now(),
      );

      expect(recentOnly.length, equals(1));
      expect(recentOnly.first.model, equals('recent'));
    });

    test('modelsByConflictRate sorts correctly', () {
      collector.record(SyncOperationMetric(
        model: 'low_conflicts',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
        recordsSynced: 100,
        conflictsDetected: 1,
      ));

      collector.record(SyncOperationMetric(
        model: 'high_conflicts',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
        recordsSynced: 100,
        conflictsDetected: 20,
      ));

      final global = collector.getGlobalMetrics();
      final sorted = global.modelsByConflictRate;

      expect(sorted.first.model, equals('high_conflicts'));
      expect(sorted.last.model, equals('low_conflicts'));
    });
  });

  group('SyncOperationMetric', () {
    test('calculates duration correctly', () {
      final start = DateTime(2024, 1, 1, 10, 0, 0);
      final end = DateTime(2024, 1, 1, 10, 0, 5);

      final metric = SyncOperationMetric(
        model: 'test',
        startTime: start,
        endTime: end,
        status: SyncStatus.success,
      );

      expect(metric.duration, equals(const Duration(seconds: 5)));
      expect(metric.durationMs, equals(5000));
    });

    test('creates from SyncResult correctly', () {
      final startTime = DateTime.now().subtract(const Duration(seconds: 3));
      final result = SyncResult(
        model: 'sale.order',
        status: SyncStatus.partial,
        synced: 8,
        failed: 2,
        timestamp: DateTime.now(),
        conflicts: [
          ConflictInfo(
            operationId: 1,
            model: 'sale.order',
            recordId: 100,
            localWriteDate: DateTime.now(),
            serverWriteDate: DateTime.now(),
            localValues: {},
          ),
        ],
      );

      final metric = SyncOperationMetric.fromResult(result, startTime: startTime);

      expect(metric.model, equals('sale.order'));
      expect(metric.status, equals(SyncStatus.partial));
      expect(metric.recordsSynced, equals(8));
      expect(metric.recordsFailed, equals(2));
      expect(metric.conflictsDetected, equals(1));
      expect(metric.isSuccess, isTrue); // partial is still considered success
    });
  });

  group('ModelSyncMetrics', () {
    test('calculates percentages correctly', () {
      final now = DateTime.now();
      final metrics = ModelSyncMetrics(
        model: 'test',
        totalOperations: 100,
        successfulOperations: 80,
        failedOperations: 20,
        totalRecordsSynced: 1000,
        totalRecordsFailed: 100,
        totalConflicts: 50,
        averageDurationMs: 500,
        minDurationMs: 100,
        maxDurationMs: 2000,
        p50DurationMs: 400,
        p95DurationMs: 1500,
        p99DurationMs: 1900,
        windowStart: now,
        windowEnd: now,
      );

      expect(metrics.successRate, equals(80.0));
      expect(metrics.failureRate, equals(20.0));
      // conflictRate = 50 / (1000 + 100 + 50) = 4.35%
      expect(metrics.conflictRate, closeTo(4.35, 0.1));
      expect(metrics.averageRecordsPerSync, equals(10.0));
    });
  });
}
