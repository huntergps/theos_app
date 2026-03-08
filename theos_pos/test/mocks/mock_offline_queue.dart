import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Mock implementation of OfflineQueueWrapper for testing.
// ignore: deprecated_member_use
class MockOfflineQueue extends Mock implements OfflineQueueWrapper {
  /// Internal list to track queued operations for assertions.
  final List<MockQueuedOperation> _operations = [];

  /// Get all operations that have been enqueued.
  List<MockQueuedOperation> get queuedOperations => List.unmodifiable(_operations);

  /// Create a mock with default behavior.
  factory MockOfflineQueue.withDefaults() {
    final mock = MockOfflineQueue._();

    // Setup default enqueue behavior
    when(() => mock.enqueue(
          model: any(named: 'model'),
          method: any(named: 'method'),
          recordId: any(named: 'recordId'),
          values: any(named: 'values'),
          priority: any(named: 'priority'),
        )).thenAnswer((invocation) async {
      final op = MockQueuedOperation(
        id: mock._operations.length + 1,
        model: invocation.namedArguments[#model] as String,
        method: invocation.namedArguments[#method] as String,
        recordId: invocation.namedArguments[#recordId] as int?,
        values: invocation.namedArguments[#values] as Map<String, dynamic>? ?? {},
      );
      mock._operations.add(op);
      return op.id;
    });

    // Setup default getPendingForModel
    when(() => mock.getPendingForModel(any()))
        .thenAnswer((_) async => []);

    // Setup default markCompleted
    when(() => mock.markCompleted(any()))
        .thenAnswer((_) async {});

    // Setup default markFailed
    when(() => mock.markFailed(any(), any()))
        .thenAnswer((_) async {});

    return mock;
  }

  MockOfflineQueue._();

  /// Clear all tracked operations.
  void clearOperations() => _operations.clear();
}

/// Represents a queued operation for testing.
class MockQueuedOperation {
  final int id;
  final String model;
  final String method;
  final int? recordId;
  final Map<String, dynamic> values;
  bool completed = false;
  bool failed = false;
  String? errorMessage;

  MockQueuedOperation({
    required this.id,
    required this.model,
    required this.method,
    this.recordId,
    required this.values,
  });

  @override
  String toString() =>
      'MockQueuedOperation(id: $id, model: $model, method: $method, recordId: $recordId)';
}

/// Helper class for setting up OfflineQueue mock behaviors.
class OfflineQueueMockHelper {
  final MockOfflineQueue queue;

  OfflineQueueMockHelper(this.queue);

  /// Setup pending operations for a model.
  void setupPendingOperations({
    required String model,
    required List<OfflineOperation> operations,
  }) {
    when(() => queue.getPendingForModel(model))
        .thenAnswer((_) async => operations);
  }

  /// Setup all pending operations.
  void setupAllPending(List<OfflineOperation> operations) {
    when(() => queue.getPending())
        .thenAnswer((_) async => operations);
  }

  /// Verify that an operation was enqueued.
  void verifyEnqueued({
    required String model,
    required String method,
    int? recordId,
  }) {
    verify(() => queue.enqueue(
          model: model,
          method: method,
          recordId: recordId,
          values: any(named: 'values'),
          priority: any(named: 'priority'),
        )).called(1);
  }
}

/// Create a test OfflineOperation.
OfflineOperation createTestOperation({
  required int id,
  required String model,
  required String method,
  int? recordId,
  Map<String, dynamic>? values,
  int retryCount = 0,
}) {
  return OfflineOperation(
    id: id,
    model: model,
    method: method,
    recordId: recordId,
    values: values ?? {},
    createdAt: DateTime.now(),
    retryCount: retryCount,
  );
}
