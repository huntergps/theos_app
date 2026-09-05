import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;
  final openDatabases = <AppDatabase>[];

  AppDatabase openDatabase() {
    final database = AppDatabase(NativeDatabase(databaseFile));
    openDatabases.add(database);
    return database;
  }

  Future<void> closeDatabase(AppDatabase database) async {
    if (openDatabases.remove(database)) await database.close();
  }

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'theos-offline-restart-',
    );
    databaseFile = File('${temporaryDirectory.path}/queue.sqlite');
  });

  tearDown(() async {
    for (final database in openDatabases.reversed) {
      await database.close();
    }
    openDatabases.clear();
    await temporaryDirectory.delete(recursive: true);
  });

  test('offline save survives restart and is applied exactly once', () async {
    final firstDatabase = openDatabase();
    final firstQueue = OfflineQueueDataSource(firstDatabase);
    final operationId = await firstQueue.queueOperation(
      model: 'sale.order',
      method: 'write',
      recordId: 42,
      values: const {'name': 'SO42'},
      operationKey: 'restart-once-42',
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
    await closeDatabase(firstDatabase);

    final restartedDatabase = openDatabase();
    final restartedQueue = OfflineQueueDataSource(restartedDatabase);
    final duplicateId = await restartedQueue.queueOperation(
      model: 'sale.order',
      method: 'write',
      recordId: 42,
      values: const {'name': 'SO42'},
      operationKey: 'restart-once-42',
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
    expect(duplicateId, operationId);
    expect((await restartedQueue.getPendingOperations()).map((op) => op.id), [
      operationId,
    ]);

    var dispatches = 0;
    final processor = OfflineQueueProcessor(
      queue: restartedQueue,
      handler: (_) async {
        dispatches++;
        return null;
      },
    );
    final result = await processor.processQueue();
    await processor.shutdown();
    expect(result.synced, 1);
    expect(dispatches, 1);
    await closeDatabase(restartedDatabase);

    final secondRestartDatabase = openDatabase();
    final secondRestartQueue = OfflineQueueDataSource(secondRestartDatabase);
    expect(await secondRestartQueue.getPendingOperations(), isEmpty);
    final secondProcessor = OfflineQueueProcessor(
      queue: secondRestartQueue,
      handler: (_) async {
        dispatches++;
        return null;
      },
    );
    expect((await secondProcessor.processQueue()).isEmpty, isTrue);
    await secondProcessor.shutdown();
    expect(dispatches, 1);
  });

  test(
    'restart recovers an interrupted retry-safe dispatch and applies it once',
    () async {
      final firstDatabase = openDatabase();
      final firstQueue = OfflineQueueDataSource(firstDatabase);
      final operationId = await firstQueue.queueOperation(
        model: 'sale.order',
        method: 'write',
        recordId: 77,
        values: const {'note': 'offline'},
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await firstQueue.markOperationProcessing(operationId);
      await closeDatabase(firstDatabase);

      final restartedDatabase = openDatabase();
      final restartedQueue = OfflineQueueDataSource(restartedDatabase);
      final recovered = await restartedQueue.getPendingOperations();
      expect(recovered, hasLength(1));
      expect(recovered.single.status, OfflineOperationStatus.recoveryPending);

      var dispatches = 0;
      final processor = OfflineQueueProcessor(
        queue: restartedQueue,
        handler: (_) async {
          dispatches++;
          return null;
        },
      );
      expect((await processor.processQueue()).synced, 1);
      await processor.shutdown();
      expect(dispatches, 1);
      expect(await restartedQueue.getOperationById(operationId), isNull);
    },
  );

  test(
    'restart dead-letters an interrupted ambiguous create without replaying it',
    () async {
      final firstDatabase = openDatabase();
      final firstQueue = OfflineQueueDataSource(firstDatabase);
      final operationId = await firstQueue.queueOperation(
        model: 'account.advance',
        method: 'create',
        recordId: -1,
        values: const {'amount': 25.0},
        replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
      );
      await firstQueue.markOperationProcessing(operationId);
      await closeDatabase(firstDatabase);

      final restartedDatabase = openDatabase();
      final restartedQueue = OfflineQueueDataSource(restartedDatabase);
      var dispatches = 0;
      final processor = OfflineQueueProcessor(
        queue: restartedQueue,
        handler: (_) async {
          dispatches++;
          return null;
        },
      );

      final result = await processor.processQueue();
      await processor.shutdown();

      expect(result.failed, 1);
      expect(dispatches, 0);
      final retained = await restartedQueue.getOperationById(operationId);
      expect(retained?.status, OfflineOperationStatus.deadLetter);
      expect(await restartedQueue.getDeadLetterOperations(), hasLength(1));
    },
  );

  test(
    'shutdown waits for an active durable writer before database close',
    () async {
      final database = openDatabase();
      final queue = OfflineQueueDataSource(database);
      await queue.queueOperation(
        model: 'sale.order',
        method: 'write',
        recordId: 99,
        values: const {'note': 'pending-close'},
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      final processor = OfflineQueueProcessor(
        queue: queue,
        handler: (_) async {
          entered.complete();
          await release.future;
          return null;
        },
      );

      final processing = processor.processQueue();
      await entered.future;
      var shutdownFinished = false;
      final shutdown = processor.shutdown().then((_) {
        shutdownFinished = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(shutdownFinished, isFalse);

      release.complete();
      await Future.wait([processing, shutdown]);
      expect(shutdownFinished, isTrue);
      expect(await queue.getPendingOperations(), isEmpty);
      await closeDatabase(database);
    },
  );
}
