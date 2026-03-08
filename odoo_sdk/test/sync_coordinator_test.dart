import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

import 'mocks/mock_odoo_client.dart';
import 'mocks/mock_offline_queue.dart';
import 'mocks/test_model_manager.dart';

// Second test manager to simulate multiple models
class TestPartnerManager extends TestProductManager {
  @override
  String get odooModel => 'res.partner';

  @override
  String get tableName => 'res_partner';

  @override
  List<String> get odooFields => [
    'id',
    'name',
    'email',
    'active',
    'write_date',
  ];
}

class TestCategoryManager extends TestProductManager {
  @override
  String get odooModel => 'product.category';

  @override
  String get tableName => 'product_category';

  @override
  List<String> get odooFields => ['id', 'name', 'active', 'write_date'];
}

class MockDatabase extends Mock implements GeneratedDatabase {}

/// A manager whose syncFromOdoo throws an exception instead of catching it
/// internally. This exercises the SyncCoordinator's catch block and
/// stopOnError / error stream paths.
class ThrowingSyncManager extends TestProductManager {
  final Object errorToThrow;
  final String _model;

  ThrowingSyncManager({required Object error, String model = 'product.product'})
    : errorToThrow = error,
      _model = model;

  @override
  String get odooModel => _model;

  @override
  Future<SyncResult> syncFromOdoo({
    DateTime? since,
    List<dynamic>? additionalDomain,
    List<String>? selectedFields,
    void Function(SyncProgress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    throw errorToThrow;
  }
}

void main() {
  late MockOdooClient mockClient;
  late InMemoryOfflineQueueStore queueStore;
  late OfflineQueueWrapper queue;
  late MockDatabase mockDb;

  late TestProductManager productManager;
  late TestPartnerManager partnerManager;
  late TestCategoryManager categoryManager;

  setUpAll(() {
    registerOdooClientFallbacks();
    registerOfflineQueueFallbacks();
  });

  setUp(() async {
    mockClient = MockOdooClient();
    queueStore = InMemoryOfflineQueueStore();
    mockDb = MockDatabase();

    mockClient.setupConfigured();

    queue = OfflineQueueWrapper(queueStore);
    await queue.initialize();

    productManager = TestProductManager();
    partnerManager = TestPartnerManager();
    categoryManager = TestCategoryManager();

    productManager.initialize(client: mockClient, db: mockDb, queue: queue);
    partnerManager.initialize(client: mockClient, db: mockDb, queue: queue);
    categoryManager.initialize(client: mockClient, db: mockDb, queue: queue);

    // Default mock setups: empty sync results
    _setupEmptySync(mockClient, 'product.product');
    _setupEmptySync(mockClient, 'res.partner');
    _setupEmptySync(mockClient, 'product.category');
  });

  tearDown(() {
    productManager.dispose();
    partnerManager.dispose();
    categoryManager.dispose();
    queue.dispose();
  });

  group('SyncCoordinatorConfig', () {
    test('default config has empty values', () {
      const config = SyncCoordinatorConfig.defaultConfig;
      expect(config.modelOrder, isEmpty);
      expect(config.parallelGroups, isEmpty);
      expect(config.excludeModels, isEmpty);
      expect(config.stopOnError, isFalse);
      expect(config.maxConcurrent, equals(3));
    });

    test('custom config stores values', () {
      const config = SyncCoordinatorConfig(
        modelOrder: ['a', 'b'],
        parallelGroups: [
          ['c', 'd'],
        ],
        excludeModels: {'e'},
        stopOnError: true,
        maxConcurrent: 5,
      );
      expect(config.modelOrder, equals(['a', 'b']));
      expect(config.parallelGroups, hasLength(1));
      expect(config.excludeModels, contains('e'));
      expect(config.stopOnError, isTrue);
      expect(config.maxConcurrent, equals(5));
    });
  });

  group('MultiSyncProgress', () {
    test('initial factory creates empty progress', () {
      final progress = MultiSyncProgress.initial(['a', 'b', 'c']);
      expect(progress.totalModels, equals(3));
      expect(progress.completedModels, isEmpty);
      expect(progress.activeModels, isEmpty);
      expect(progress.modelProgress, isEmpty);
      expect(progress.overallProgress, equals(0.0));
    });

    test('overallProgress reflects completion', () {
      const progress = MultiSyncProgress(
        modelProgress: {},
        completedModels: {'a', 'b'},
        activeModels: {'c'},
        totalModels: 4,
      );
      expect(progress.overallProgress, equals(0.5));
    });

    test('overallProgress is 1.0 when totalModels is 0', () {
      const progress = MultiSyncProgress(
        modelProgress: {},
        completedModels: {},
        activeModels: {},
        totalModels: 0,
      );
      expect(progress.overallProgress, equals(1.0));
    });

    test('copyWith updates fields', () {
      final original = MultiSyncProgress.initial(['a', 'b']);
      final updated = original.copyWith(
        completedModels: {'a'},
        activeModels: {'b'},
      );
      expect(updated.completedModels, contains('a'));
      expect(updated.activeModels, contains('b'));
      expect(updated.totalModels, equals(2));
    });
  });

  group('SyncCoordinator', () {
    group('constructor and registration', () {
      test('creates with managers map', () {
        final coordinator = SyncCoordinator(
          managers: {'product.product': productManager},
        );
        expect(coordinator.isSyncingNow, isFalse);
        coordinator.dispose();
      });

      test('registerManager adds a new manager', () async {
        final coordinator = SyncCoordinator(managers: {});
        coordinator.registerManager('product.product', productManager);

        final report = await coordinator.syncAll();
        // Should sync the registered model
        expect(report.results, hasLength(1));
        coordinator.dispose();
      });

      test('unregisterManager removes a manager', () async {
        final coordinator = SyncCoordinator(
          managers: {'product.product': productManager},
        );
        coordinator.unregisterManager('product.product');

        final report = await coordinator.syncAll();
        expect(report.results, isEmpty);
        coordinator.dispose();
      });
    });

    group('syncAll - sequential sync', () {
      test('syncs all registered models', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final report = await coordinator.syncAll();

        expect(report.results, hasLength(2));
        expect(
          report.results.every((r) => r.status != SyncStatus.error),
          isTrue,
        );
        coordinator.dispose();
      });

      test('respects model order', () async {
        final syncOrder = <String>[];

        // Setup mocks to track call order
        when(
          () => mockClient.searchCount(
            model: any(named: 'model'),
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((inv) async {
          syncOrder.add(inv.namedArguments[#model] as String);
          return 0;
        });

        when(
          () => mockClient.searchRead(
            model: any(named: 'model'),
            fields: any(named: 'fields'),
            domain: any(named: 'domain'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            order: any(named: 'order'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async => []);

        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
            'product.category': categoryManager,
          },
          config: const SyncCoordinatorConfig(
            modelOrder: ['product.category', 'product.product', 'res.partner'],
          ),
        );

        await coordinator.syncAll();

        expect(syncOrder.first, equals('product.category'));
        expect(syncOrder[1], equals('product.product'));
        expect(syncOrder.last, equals('res.partner'));
        coordinator.dispose();
      });

      test('excludes models from sync', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
          config: const SyncCoordinatorConfig(excludeModels: {'res.partner'}),
        );

        final report = await coordinator.syncAll();

        // Only product.product should be synced
        expect(report.results, hasLength(1));
        expect(report.results.first.model, equals('product.product'));
        coordinator.dispose();
      });

      test('returns alreadyInProgress when sync is running', () async {
        final coordinator = SyncCoordinator(
          managers: {'product.product': productManager},
        );

        // Setup a slow sync
        when(
          () => mockClient.searchCount(
            model: 'product.product',
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 0;
        });

        // Start first sync
        final firstSync = coordinator.syncAll();

        // Try starting second sync immediately
        final secondReport = await coordinator.syncAll();
        expect(
          secondReport.results.first.status,
          equals(SyncStatus.alreadyInProgress),
        );

        await firstSync;
        coordinator.dispose();
      });

      test('sets isSyncing stream correctly', () async {
        final coordinator = SyncCoordinator(
          managers: {'product.product': productManager},
        );

        final syncStates = <bool>[];
        final sub = coordinator.isSyncing.listen(syncStates.add);

        await coordinator.syncAll();

        // Allow stream events to propagate
        await Future.delayed(Duration.zero);
        await sub.cancel();

        // Should have been true at some point and then false
        expect(syncStates, contains(true));
        expect(syncStates.last, isFalse);
        coordinator.dispose();
      });
    });

    group('syncParallel', () {
      test('syncs models in parallel', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final report = await coordinator.syncParallel([
          'product.product',
          'res.partner',
        ]);

        expect(report.results, hasLength(2));
        coordinator.dispose();
      });

      test('returns error for unregistered model', () async {
        final coordinator = SyncCoordinator(
          managers: {'product.product': productManager},
        );

        final report = await coordinator.syncParallel([
          'product.product',
          'nonexistent.model',
        ]);

        expect(report.results, hasLength(2));
        final errorResult = report.results.where(
          (r) => r.model == 'nonexistent.model',
        );
        expect(errorResult.first.status, equals(SyncStatus.error));
        coordinator.dispose();
      });

      test('reports progress during parallel sync', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final progressCalls = <(String, SyncProgress)>[];

        await coordinator.syncParallel(
          ['product.product', 'res.partner'],
          onProgress: (model, progress) => progressCalls.add((model, progress)),
        );

        // Progress should have been reported for each model
        expect(progressCalls, isNotEmpty);
        coordinator.dispose();
      });
    });

    group('syncOptimized', () {
      test(
        'syncs ordered models first, then parallel, then remaining',
        () async {
          final coordinator = SyncCoordinator(
            managers: {
              'product.product': productManager,
              'res.partner': partnerManager,
              'product.category': categoryManager,
            },
            config: const SyncCoordinatorConfig(
              modelOrder: ['product.category'],
              parallelGroups: [
                ['product.product', 'res.partner'],
              ],
            ),
          );

          final report = await coordinator.syncOptimized();

          expect(report.results, hasLength(3));
          coordinator.dispose();
        },
      );

      test('returns alreadyInProgress if already syncing', () async {
        final coordinator = SyncCoordinator(
          managers: {'product.product': productManager},
        );

        // Make sync slow
        when(
          () => mockClient.searchCount(
            model: 'product.product',
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 0;
        });

        final first = coordinator.syncOptimized();
        final second = await coordinator.syncOptimized();

        expect(
          second.results.first.status,
          equals(SyncStatus.alreadyInProgress),
        );

        await first;
        coordinator.dispose();
      });

      test('excludes specified models', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
          config: const SyncCoordinatorConfig(excludeModels: {'res.partner'}),
        );

        final report = await coordinator.syncOptimized();

        expect(report.results, hasLength(1));
        expect(report.results.first.model, equals('product.product'));
        coordinator.dispose();
      });
    });

    group('cancellation', () {
      test('syncAll respects cancellation token', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final token = CancellationToken();
        token.cancel(); // Cancel immediately

        final report = await coordinator.syncAll(cancellation: token);

        // All results should be cancelled
        for (final result in report.results) {
          expect(result.status, equals(SyncStatus.cancelled));
        }

        token.dispose();
        coordinator.dispose();
      });

      test('syncParallel respects cancellation token', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final token = CancellationToken();
        token.cancel();

        final report = await coordinator.syncParallel([
          'product.product',
          'res.partner',
        ], cancellation: token);

        expect(
          report.results.every((r) => r.status == SyncStatus.cancelled),
          isTrue,
        );

        token.dispose();
        coordinator.dispose();
      });

      test('syncOptimized respects cancellation token', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final token = CancellationToken();
        token.cancel();

        final report = await coordinator.syncOptimized(cancellation: token);

        for (final result in report.results) {
          expect(result.status, equals(SyncStatus.cancelled));
        }

        token.dispose();
        coordinator.dispose();
      });
    });

    group('error handling', () {
      test('continues after error by default', () async {
        // Make product sync fail
        when(
          () => mockClient.searchCount(
            model: 'product.product',
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenThrow(Exception('Network error'));

        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
          config: const SyncCoordinatorConfig(
            modelOrder: ['product.product', 'res.partner'],
          ),
        );

        final report = await coordinator.syncAll();

        // Both models should have results
        expect(report.results, hasLength(2));
        // Product should have failed
        expect(report.results.first.status, equals(SyncStatus.error));
        // Partner should have succeeded
        expect(report.results.last.status, isNot(SyncStatus.error));
        coordinator.dispose();
      });

      test('stops on error when configured', () async {
        // Use a throwing manager so the coordinator's catch block is hit
        final throwingManager = ThrowingSyncManager(
          error: Exception('Network error'),
          model: 'product.product',
        );
        throwingManager.initialize(
          client: mockClient,
          db: mockDb,
          queue: queue,
        );

        final coordinator = SyncCoordinator(
          managers: {
            'product.product': throwingManager,
            'res.partner': partnerManager,
          },
          config: const SyncCoordinatorConfig(
            modelOrder: ['product.product', 'res.partner'],
            stopOnError: true,
          ),
        );

        final report = await coordinator.syncAll();

        // Should have stopped after the first failure
        expect(report.results, hasLength(1));
        expect(report.results.first.status, equals(SyncStatus.error));
        coordinator.dispose();
        throwingManager.dispose();
      });

      test('emits errors to error stream', () async {
        // Use a throwing manager so the coordinator's catch block is hit
        // and errors are emitted to the stream
        final throwingManager = ThrowingSyncManager(
          error: Exception('Sync failed'),
          model: 'product.product',
        );
        throwingManager.initialize(
          client: mockClient,
          db: mockDb,
          queue: queue,
        );

        final coordinator = SyncCoordinator(
          managers: {'product.product': throwingManager},
        );

        final errors = <SyncError>[];
        final sub = coordinator.errors.listen(errors.add);

        await coordinator.syncAll();

        await Future.delayed(Duration.zero);
        await sub.cancel();

        expect(errors, hasLength(1));
        expect(errors.first.model, equals('product.product'));
        expect(errors.first.error.toString(), contains('Sync failed'));
        coordinator.dispose();
        throwingManager.dispose();
      });

      test('syncParallel catches errors per model', () async {
        when(
          () => mockClient.searchCount(
            model: 'product.product',
            domain: any(named: 'domain'),
            cancelToken: any(named: 'cancelToken'),
          ),
        ).thenThrow(Exception('Product sync failed'));

        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final report = await coordinator.syncParallel([
          'product.product',
          'res.partner',
        ]);

        expect(report.results, hasLength(2));
        final productResult = report.results.firstWhere(
          (r) => r.model == 'product.product',
        );
        final partnerResult = report.results.firstWhere(
          (r) => r.model == 'res.partner',
        );

        expect(productResult.status, equals(SyncStatus.error));
        expect(partnerResult.status, isNot(SyncStatus.error));
        coordinator.dispose();
      });
    });

    group('progress tracking', () {
      test('emits progress updates during syncAll', () async {
        final coordinator = SyncCoordinator(
          managers: {'product.product': productManager},
        );

        final progressUpdates = <MultiSyncProgress?>[];
        final sub = coordinator.progress.listen(progressUpdates.add);

        await coordinator.syncAll();

        await Future.delayed(Duration.zero);
        await sub.cancel();

        // Should have emitted at least initial and null (complete)
        expect(progressUpdates, isNotEmpty);
        coordinator.dispose();
      });

      test('reports per-model progress via callback', () async {
        final coordinator = SyncCoordinator(
          managers: {
            'product.product': productManager,
            'res.partner': partnerManager,
          },
        );

        final progressCalls = <String>[];

        await coordinator.syncAll(
          onProgress: (model, progress) => progressCalls.add(model),
        );

        // Should have progress for both models
        expect(progressCalls, contains('product.product'));
        expect(progressCalls, contains('res.partner'));
        coordinator.dispose();
      });
    });

    group('dispose', () {
      test('dispose does not throw', () {
        final coordinator = SyncCoordinator(managers: {});
        expect(() => coordinator.dispose(), returnsNormally);
      });
    });
  });

  group('SyncError', () {
    test('stores model and error', () {
      final error = SyncError(
        model: 'product.product',
        error: Exception('test'),
      );
      expect(error.model, equals('product.product'));
      expect(error.error, isA<Exception>());
      expect(error.timestamp, isA<DateTime>());
    });

    test('toString includes model and error', () {
      final error = SyncError(
        model: 'product.product',
        error: 'Something failed',
      );
      expect(error.toString(), contains('product.product'));
      expect(error.toString(), contains('Something failed'));
    });
  });

  group('SyncOperationMetrics', () {
    test('computes duration', () {
      final start = DateTime(2024, 1, 1, 10, 0, 0);
      final end = DateTime(2024, 1, 1, 10, 0, 5);
      final metrics = SyncOperationMetrics(
        model: 'test',
        startTime: start,
        endTime: end,
        recordsFetched: 100,
      );
      expect(metrics.duration.inSeconds, equals(5));
    });

    test('computes recordsPerSecond', () {
      final start = DateTime(2024, 1, 1, 10, 0, 0);
      final end = DateTime(2024, 1, 1, 10, 0, 2);
      final metrics = SyncOperationMetrics(
        model: 'test',
        startTime: start,
        endTime: end,
        recordsFetched: 100,
      );
      expect(metrics.recordsPerSecond, equals(50.0));
    });

    test('computes bytesPerRecord', () {
      final now = DateTime.now();
      final metrics = SyncOperationMetrics(
        model: 'test',
        startTime: now,
        endTime: now,
        recordsFetched: 10,
        bytesReceived: 1000,
      );
      expect(metrics.bytesPerRecord, equals(100.0));
    });

    test('computes recordsChanged', () {
      final now = DateTime.now();
      final metrics = SyncOperationMetrics(
        model: 'test',
        startTime: now,
        endTime: now,
        recordsInserted: 5,
        recordsUpdated: 3,
        recordsDeleted: 2,
      );
      expect(metrics.recordsChanged, equals(10));
    });

    test('error factory sets success false', () {
      final metrics = SyncOperationMetrics.error(
        model: 'test',
        error: 'Something broke',
      );
      expect(metrics.success, isFalse);
      expect(metrics.errorMessage, equals('Something broke'));
    });

    test('toJson includes all fields', () {
      final now = DateTime.now();
      final metrics = SyncOperationMetrics(
        model: 'test',
        startTime: now,
        endTime: now,
        recordsFetched: 10,
      );
      final json = metrics.toJson();
      expect(json['model'], equals('test'));
      expect(json['recordsFetched'], equals(10));
      expect(json['success'], isTrue);
    });

    test('toString shows formatted output', () {
      final now = DateTime.now();
      final metrics = SyncOperationMetrics(
        model: 'test',
        startTime: now,
        endTime: now,
        recordsFetched: 10,
        recordsInserted: 5,
      );
      expect(metrics.toString(), contains('test'));
      expect(metrics.toString(), contains('10'));
    });

    test('toString shows FAILED for errors', () {
      final metrics = SyncOperationMetrics.error(
        model: 'test',
        error: 'Connection timeout',
      );
      expect(metrics.toString(), contains('FAILED'));
    });
  });

  group('SyncOperationMetricsBuilder', () {
    test('tracks metrics incrementally', () {
      final builder = SyncOperationMetricsBuilder('test');
      builder.addRecordsFetched(10);
      builder.addRecordsInserted(5);
      builder.addRecordsUpdated(3);
      builder.addRecordsDeleted(2);
      builder.addRecordsSkipped(1);
      builder.addApiRequest(bytes: 500);
      builder.addDbOperation();
      builder.addDbOperations(3);

      final metrics = builder.build();
      expect(metrics.model, equals('test'));
      expect(metrics.recordsFetched, equals(10));
      expect(metrics.recordsInserted, equals(5));
      expect(metrics.recordsUpdated, equals(3));
      expect(metrics.recordsDeleted, equals(2));
      expect(metrics.recordsSkipped, equals(1));
      expect(metrics.apiRequests, equals(1));
      expect(metrics.bytesReceived, equals(500));
      expect(metrics.dbOperations, equals(4));
      expect(metrics.success, isTrue);
    });

    test('setError marks as failed', () {
      final builder = SyncOperationMetricsBuilder('test');
      builder.setError('Something broke');

      final metrics = builder.build();
      expect(metrics.success, isFalse);
      expect(metrics.errorMessage, equals('Something broke'));
    });

    test('incrementRetry tracks count', () {
      final builder = SyncOperationMetricsBuilder('test');
      builder.incrementRetry();
      builder.incrementRetry();

      final metrics = builder.build();
      expect(metrics.retryCount, equals(2));
    });
  });

  group('SyncSessionMetrics', () {
    test('aggregates across models', () {
      final now = DateTime.now();
      final metrics = SyncSessionMetrics(
        modelMetrics: [
          SyncOperationMetrics(
            model: 'a',
            startTime: now,
            endTime: now,
            recordsFetched: 10,
            recordsInserted: 5,
            apiRequests: 2,
            bytesReceived: 1000,
          ),
          SyncOperationMetrics(
            model: 'b',
            startTime: now,
            endTime: now,
            recordsFetched: 20,
            recordsUpdated: 3,
            apiRequests: 3,
            bytesReceived: 2000,
          ),
        ],
        startTime: now,
        endTime: now,
      );

      expect(metrics.totalRecordsFetched, equals(30));
      expect(metrics.totalRecordsInserted, equals(5));
      expect(metrics.totalRecordsUpdated, equals(3));
      expect(metrics.totalApiRequests, equals(5));
      expect(metrics.totalBytesReceived, equals(3000));
      expect(metrics.successfulModels, equals(2));
      expect(metrics.failedModels, equals(0));
      expect(metrics.successRate, equals(1.0));
    });

    test('identifies failures', () {
      final now = DateTime.now();
      final metrics = SyncSessionMetrics(
        modelMetrics: [
          SyncOperationMetrics(
            model: 'ok',
            startTime: now,
            endTime: now,
            success: true,
          ),
          SyncOperationMetrics.error(model: 'bad', error: 'failed'),
        ],
        startTime: now,
        endTime: now,
      );

      expect(metrics.failedModels, equals(1));
      expect(metrics.failures, hasLength(1));
      expect(metrics.failures.first.model, equals('bad'));
      expect(metrics.successRate, equals(0.5));
    });

    test('slowestModel returns longest duration', () {
      final now = DateTime.now();
      final metrics = SyncSessionMetrics(
        modelMetrics: [
          SyncOperationMetrics(
            model: 'fast',
            startTime: now,
            endTime: now.add(const Duration(seconds: 1)),
          ),
          SyncOperationMetrics(
            model: 'slow',
            startTime: now,
            endTime: now.add(const Duration(seconds: 5)),
          ),
        ],
        startTime: now,
        endTime: now,
      );

      expect(metrics.slowestModel!.model, equals('slow'));
    });

    test('largestModel returns most records', () {
      final now = DateTime.now();
      final metrics = SyncSessionMetrics(
        modelMetrics: [
          SyncOperationMetrics(
            model: 'small',
            startTime: now,
            endTime: now,
            recordsFetched: 10,
          ),
          SyncOperationMetrics(
            model: 'large',
            startTime: now,
            endTime: now,
            recordsFetched: 1000,
          ),
        ],
        startTime: now,
        endTime: now,
      );

      expect(metrics.largestModel!.model, equals('large'));
    });

    test('empty factory creates empty metrics', () {
      final metrics = SyncSessionMetrics.empty();
      expect(metrics.modelMetrics, isEmpty);
      expect(metrics.totalRecordsFetched, equals(0));
      expect(metrics.successRate, equals(1.0));
    });

    test('toJson produces valid map', () {
      final now = DateTime.now();
      final metrics = SyncSessionMetrics(
        modelMetrics: [
          SyncOperationMetrics(model: 'a', startTime: now, endTime: now),
        ],
        startTime: now,
        endTime: now,
      );
      final json = metrics.toJson();
      expect(json['modelsTotal'], equals(1));
      expect(json['modelsSuccess'], equals(1));
    });

    test('toSummary produces readable output', () {
      final now = DateTime.now();
      final metrics = SyncSessionMetrics(
        modelMetrics: [
          SyncOperationMetrics(
            model: 'a',
            startTime: now,
            endTime: now.add(const Duration(seconds: 2)),
            recordsFetched: 100,
            recordsInserted: 50,
            recordsUpdated: 30,
          ),
        ],
        startTime: now,
        endTime: now.add(const Duration(seconds: 2)),
      );

      final summary = metrics.toSummary();
      expect(summary, contains('Sync Session Summary'));
      expect(summary, contains('Fetched'));
      expect(summary, contains('100'));
    });
  });

  group('SyncMetricsTracker', () {
    test('tracks session lifecycle', () {
      final tracker = SyncMetricsTracker();

      tracker.startSession();
      final builder = tracker.startModel('product.product');
      builder.addRecordsFetched(50);
      tracker.completeModel('product.product');

      final result = tracker.endSession();
      expect(result.modelMetrics, hasLength(1));
      expect(result.totalRecordsFetched, equals(50));

      tracker.dispose();
    });

    test('emits metrics via stream', () async {
      final tracker = SyncMetricsTracker();
      final updates = <SyncSessionMetrics?>[];
      final sub = tracker.metricsStream.listen(updates.add);

      tracker.startSession();
      tracker.startModel('a');
      tracker.completeModel('a');
      tracker.endSession();

      await Future.delayed(Duration.zero);
      await sub.cancel();

      expect(updates, isNotEmpty);
      tracker.dispose();
    });

    test('currentMetrics returns latest', () {
      final tracker = SyncMetricsTracker();

      expect(tracker.currentMetrics, isNull);

      tracker.startSession();
      tracker.startModel('test');

      expect(tracker.currentMetrics, isNotNull);

      tracker.dispose();
    });
  });
}

// Helper to set up empty sync mocks for a model
void _setupEmptySync(MockOdooClient client, String model) {
  when(
    () => client.searchCount(
      model: model,
      domain: any(named: 'domain'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => 0);

  when(
    () => client.searchRead(
      model: model,
      fields: any(named: 'fields'),
      domain: any(named: 'domain'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      order: any(named: 'order'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((_) async => []);
}
