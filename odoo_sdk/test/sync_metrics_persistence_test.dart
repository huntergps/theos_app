import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

/// In-memory implementation of [SyncMetricsPersistence] for testing.
class InMemorySyncMetricsPersistence implements SyncMetricsPersistence {
  final List<SyncOperationMetric> _stored = [];

  List<SyncOperationMetric> get allStored => List.unmodifiable(_stored);

  @override
  Future<void> saveMetric(SyncOperationMetric metric) async {
    _stored.add(metric);
  }

  @override
  Future<void> saveMetrics(List<SyncOperationMetric> metrics) async {
    _stored.addAll(metrics);
  }

  @override
  Future<List<SyncOperationMetric>> loadMetrics({DateTime? since}) async {
    if (since == null) return List.from(_stored);
    return _stored.where((m) => !m.startTime.isBefore(since)).toList();
  }

  @override
  Future<void> clearMetrics({DateTime? before}) async {
    if (before == null) {
      _stored.clear();
    } else {
      _stored.removeWhere((m) => m.startTime.isBefore(before));
    }
  }

  @override
  Future<int> metricsCount() async => _stored.length;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // SyncOperationMetric JSON serialization
  // ═══════════════════════════════════════════════════════════════════════════

  group('SyncOperationMetric.toJson()', () {
    test('produces correct map', () {
      final start = DateTime.utc(2025, 6, 15, 10, 0, 0);
      final end = DateTime.utc(2025, 6, 15, 10, 0, 5);

      final metric = SyncOperationMetric(
        model: 'sale.order',
        startTime: start,
        endTime: end,
        status: SyncStatus.success,
        recordsSynced: 10,
        recordsFailed: 2,
        conflictsDetected: 1,
        error: 'Some error',
      );

      final json = metric.toJson();

      expect(json['model'], equals('sale.order'));
      expect(json['startTime'], equals(start.toIso8601String()));
      expect(json['endTime'], equals(end.toIso8601String()));
      expect(json['status'], equals('success'));
      expect(json['recordsSynced'], equals(10));
      expect(json['recordsFailed'], equals(2));
      expect(json['conflictsDetected'], equals(1));
      expect(json['error'], equals('Some error'));
    });

    test('omits error when null', () {
      final metric = SyncOperationMetric(
        model: 'res.partner',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
      );

      final json = metric.toJson();

      expect(json.containsKey('error'), isFalse);
    });
  });

  group('SyncOperationMetric.fromJson()', () {
    test('round-trips correctly', () {
      final original = SyncOperationMetric(
        model: 'product.product',
        startTime: DateTime.utc(2025, 3, 10, 8, 30, 0),
        endTime: DateTime.utc(2025, 3, 10, 8, 30, 12),
        status: SyncStatus.partial,
        recordsSynced: 45,
        recordsFailed: 3,
        conflictsDetected: 2,
        error: 'Timeout on 3 records',
      );

      final json = original.toJson();
      final restored = SyncOperationMetric.fromJson(json);

      expect(restored.model, equals(original.model));
      expect(restored.startTime, equals(original.startTime));
      expect(restored.endTime, equals(original.endTime));
      expect(restored.status, equals(original.status));
      expect(restored.recordsSynced, equals(original.recordsSynced));
      expect(restored.recordsFailed, equals(original.recordsFailed));
      expect(restored.conflictsDetected, equals(original.conflictsDetected));
      expect(restored.error, equals(original.error));
    });

    test('handles missing optional fields', () {
      final json = <String, dynamic>{
        'model': 'res.partner',
        'startTime': '2025-06-15T10:00:00.000Z',
        'endTime': '2025-06-15T10:00:05.000Z',
        'status': 'success',
      };

      final metric = SyncOperationMetric.fromJson(json);

      expect(metric.model, equals('res.partner'));
      expect(metric.recordsSynced, equals(0));
      expect(metric.recordsFailed, equals(0));
      expect(metric.conflictsDetected, equals(0));
      expect(metric.error, isNull);
    });

    test('works with all SyncStatus values', () {
      for (final status in SyncStatus.values) {
        final json = <String, dynamic>{
          'model': 'test.model',
          'startTime': '2025-01-01T00:00:00.000Z',
          'endTime': '2025-01-01T00:00:01.000Z',
          'status': status.name,
        };

        final metric = SyncOperationMetric.fromJson(json);
        expect(metric.status, equals(status));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SyncMetricsPersistence interface (via InMemory impl)
  // ═══════════════════════════════════════════════════════════════════════════

  group('SyncMetricsPersistence', () {
    late InMemorySyncMetricsPersistence persistence;

    setUp(() {
      persistence = InMemorySyncMetricsPersistence();
    });

    test('save, load, clear, count', () async {
      final metric = SyncOperationMetric(
        model: 'sale.order',
        startTime: DateTime.utc(2025, 1, 1),
        endTime: DateTime.utc(2025, 1, 1, 0, 0, 5),
        status: SyncStatus.success,
        recordsSynced: 10,
      );

      await persistence.saveMetric(metric);
      expect(await persistence.metricsCount(), equals(1));

      final loaded = await persistence.loadMetrics();
      expect(loaded.length, equals(1));
      expect(loaded.first.model, equals('sale.order'));

      await persistence.clearMetrics();
      expect(await persistence.metricsCount(), equals(0));
    });

    test('loadMetrics(since:) filters by date', () async {
      final oldMetric = SyncOperationMetric(
        model: 'old.model',
        startTime: DateTime.utc(2025, 1, 1),
        endTime: DateTime.utc(2025, 1, 1, 0, 0, 1),
        status: SyncStatus.success,
      );
      final newMetric = SyncOperationMetric(
        model: 'new.model',
        startTime: DateTime.utc(2025, 6, 1),
        endTime: DateTime.utc(2025, 6, 1, 0, 0, 1),
        status: SyncStatus.success,
      );

      await persistence.saveMetric(oldMetric);
      await persistence.saveMetric(newMetric);

      final filtered = await persistence.loadMetrics(
        since: DateTime.utc(2025, 3, 1),
      );

      expect(filtered.length, equals(1));
      expect(filtered.first.model, equals('new.model'));
    });

    test('clearMetrics(before:) removes old metrics only', () async {
      final oldMetric = SyncOperationMetric(
        model: 'old.model',
        startTime: DateTime.utc(2025, 1, 1),
        endTime: DateTime.utc(2025, 1, 1, 0, 0, 1),
        status: SyncStatus.success,
      );
      final newMetric = SyncOperationMetric(
        model: 'new.model',
        startTime: DateTime.utc(2025, 6, 1),
        endTime: DateTime.utc(2025, 6, 1, 0, 0, 1),
        status: SyncStatus.success,
      );

      await persistence.saveMetric(oldMetric);
      await persistence.saveMetric(newMetric);

      await persistence.clearMetrics(before: DateTime.utc(2025, 3, 1));

      final remaining = await persistence.loadMetrics();
      expect(remaining.length, equals(1));
      expect(remaining.first.model, equals('new.model'));
    });

    test('saveMetrics() batch save', () async {
      final metrics = List.generate(
        5,
        (i) => SyncOperationMetric(
          model: 'model_$i',
          startTime: DateTime.utc(2025, 1, 1 + i),
          endTime: DateTime.utc(2025, 1, 1 + i, 0, 0, 1),
          status: SyncStatus.success,
          recordsSynced: i * 10,
        ),
      );

      await persistence.saveMetrics(metrics);

      expect(await persistence.metricsCount(), equals(5));
      final loaded = await persistence.loadMetrics();
      expect(loaded.length, equals(5));
      expect(loaded[2].model, equals('model_2'));
      expect(loaded[2].recordsSynced, equals(20));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SyncMetricsCollector with persistence
  // ═══════════════════════════════════════════════════════════════════════════

  group('SyncMetricsCollector with persistence', () {
    late InMemorySyncMetricsPersistence persistence;
    late SyncMetricsCollector collector;

    setUp(() {
      persistence = InMemorySyncMetricsPersistence();
      collector = SyncMetricsCollector(persistence: persistence);
    });

    test('record writes through to persistence', () {
      final metric = SyncOperationMetric(
        model: 'sale.order',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
        recordsSynced: 5,
      );

      collector.record(metric);

      // In-memory
      expect(collector.metrics.length, equals(1));
      // Persisted
      expect(persistence.allStored.length, equals(1));
      expect(persistence.allStored.first.model, equals('sale.order'));
    });

    test('loadFromPersistence() restores metrics', () async {
      // Pre-populate persistence
      final metrics = [
        SyncOperationMetric(
          model: 'model_a',
          startTime: DateTime.utc(2025, 1, 1),
          endTime: DateTime.utc(2025, 1, 1, 0, 0, 1),
          status: SyncStatus.success,
          recordsSynced: 10,
        ),
        SyncOperationMetric(
          model: 'model_b',
          startTime: DateTime.utc(2025, 2, 1),
          endTime: DateTime.utc(2025, 2, 1, 0, 0, 1),
          status: SyncStatus.error,
          error: 'Network error',
        ),
      ];
      await persistence.saveMetrics(metrics);

      // Create a fresh collector with same persistence
      final freshCollector = SyncMetricsCollector(persistence: persistence);
      expect(freshCollector.metrics, isEmpty);

      final loaded = await freshCollector.loadFromPersistence();

      expect(loaded, equals(2));
      expect(freshCollector.metrics.length, equals(2));
      expect(freshCollector.metrics[0].model, equals('model_a'));
      expect(freshCollector.metrics[1].model, equals('model_b'));
    });

    test('loadFromPersistence() respects maxMetrics', () async {
      // Pre-populate persistence with more than maxMetrics
      for (var i = 0; i < 10; i++) {
        await persistence.saveMetric(SyncOperationMetric(
          model: 'model_$i',
          startTime: DateTime.utc(2025, 1, 1 + i),
          endTime: DateTime.utc(2025, 1, 1 + i, 0, 0, 1),
          status: SyncStatus.success,
        ));
      }

      final smallCollector = SyncMetricsCollector(
        maxMetrics: 5,
        persistence: persistence,
      );

      final loaded = await smallCollector.loadFromPersistence();

      expect(loaded, equals(10)); // 10 were loaded from persistence
      expect(smallCollector.metrics.length, equals(5)); // trimmed to max
      // Should keep the most recent (last 5)
      expect(smallCollector.metrics.first.model, equals('model_5'));
      expect(smallCollector.metrics.last.model, equals('model_9'));
    });

    test('loadFromPersistence() with since filter', () async {
      await persistence.saveMetric(SyncOperationMetric(
        model: 'old',
        startTime: DateTime.utc(2025, 1, 1),
        endTime: DateTime.utc(2025, 1, 1, 0, 0, 1),
        status: SyncStatus.success,
      ));
      await persistence.saveMetric(SyncOperationMetric(
        model: 'recent',
        startTime: DateTime.utc(2025, 6, 1),
        endTime: DateTime.utc(2025, 6, 1, 0, 0, 1),
        status: SyncStatus.success,
      ));

      final freshCollector = SyncMetricsCollector(persistence: persistence);
      final loaded = await freshCollector.loadFromPersistence(
        since: DateTime.utc(2025, 3, 1),
      );

      expect(loaded, equals(1));
      expect(freshCollector.metrics.length, equals(1));
      expect(freshCollector.metrics.first.model, equals('recent'));
    });

    test('clear(clearPersistence: true) clears both memory and persistence',
        () async {
      collector.record(SyncOperationMetric(
        model: 'test',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
      ));

      expect(collector.metrics.length, equals(1));
      expect(persistence.allStored.length, equals(1));

      collector.clear(clearPersistence: true);

      expect(collector.metrics, isEmpty);
      // clearMetrics is fire-and-forget, but InMemory is synchronous
      // so the clear should have been invoked
      expect(await persistence.metricsCount(), equals(0));
    });

    test('clear() without flag only clears memory', () async {
      collector.record(SyncOperationMetric(
        model: 'test',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
      ));

      expect(collector.metrics.length, equals(1));
      expect(persistence.allStored.length, equals(1));

      collector.clear();

      expect(collector.metrics, isEmpty);
      // Persistence should still have the metric
      expect(await persistence.metricsCount(), equals(1));
    });

    test('hasPersistence returns true', () {
      expect(collector.hasPersistence, isTrue);
    });
  });

  group('SyncMetricsCollector without persistence', () {
    test('works exactly as before (backward compatible)', () {
      final collector = SyncMetricsCollector();

      collector.record(SyncOperationMetric(
        model: 'sale.order',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
        recordsSynced: 5,
      ));

      expect(collector.metrics.length, equals(1));
      expect(collector.metrics.first.model, equals('sale.order'));

      // clear() with no args should work fine
      collector.clear();
      expect(collector.metrics, isEmpty);
    });

    test('hasPersistence returns false', () {
      final collector = SyncMetricsCollector();
      expect(collector.hasPersistence, isFalse);
    });

    test('loadFromPersistence() returns 0 when no persistence', () async {
      final collector = SyncMetricsCollector();
      final loaded = await collector.loadFromPersistence();
      expect(loaded, equals(0));
    });

    test('clear(clearPersistence: true) works without error', () {
      final collector = SyncMetricsCollector();

      collector.record(SyncOperationMetric(
        model: 'test',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        status: SyncStatus.success,
      ));

      // Should not throw even with clearPersistence: true
      collector.clear(clearPersistence: true);
      expect(collector.metrics, isEmpty);
    });
  });
}
