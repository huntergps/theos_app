import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:odoo_sdk/src/sync/offline_queue.dart';

/// Mock implementation of OfflineQueueStore for testing.
class MockOfflineQueueStore extends Mock implements OfflineQueueStore {}

/// Mock implementation of OfflineQueueWrapper for testing.
class MockOfflineQueue extends Mock implements OfflineQueueWrapper {}

/// Fake OfflineOperation for mocktail registerFallbackValue.
class FakeOfflineOperation extends Fake implements OfflineOperation {
  @override
  int get id => 1;

  @override
  String get model => 'test.model';

  @override
  String get method => 'create';

  @override
  int? get recordId => null;

  @override
  Map<String, dynamic> get values => {};

  @override
  DateTime get createdAt => DateTime.now();

  @override
  int get retryCount => 0;

  @override
  int get priority => OfflinePriority.normal;
}

/// Setup function to register all fallback values for offline queue mocks.
void registerOfflineQueueFallbacks() {
  registerFallbackValue(FakeOfflineOperation());
  registerFallbackValue(OfflinePriority.normal);
}

/// In-memory implementation of OfflineQueueStore for testing.
///
/// This provides a fully functional queue that stores operations in memory,
/// useful for integration-style tests.
class InMemoryOfflineQueueStore implements OfflineQueueStore {
  final List<OfflineOperation> _operations = [];
  int _nextId = 1;

  /// Maximum retries before moving to dead letter.
  static const int maxRetries = 5;

  /// All operations currently in the queue.
  List<OfflineOperation> get allOperations => List.unmodifiable(_operations);

  /// Clear all operations.
  void clear() {
    _operations.clear();
    _nextId = 1;
  }

  @override
  Future<int> queueOperation({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority = OfflinePriority.normal,
    String? deviceId,
  }) async {
    final id = _nextId++;
    final operation = OfflineOperation(
      id: id,
      model: model,
      method: method,
      recordId: recordId,
      values: values,
      createdAt: DateTime.now(),
      baseWriteDate: baseWriteDate,
      parentOrderId: parentOrderId,
      priority: priority,
      deviceId: deviceId,
      retryCount: 0,
    );
    _operations.add(operation);
    return id;
  }

  @override
  Future<List<OfflineOperation>> getPendingOperations({
    bool includeNotReady = false,
  }) async {
    return _operations
        .where((op) => op.retryCount < maxRetries)
        .where((op) => includeNotReady || op.isReadyForRetry)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Future<int> getPendingCount() async {
    return _operations.where((op) => op.retryCount < maxRetries).length;
  }

  @override
  Future<List<OfflineOperation>> getOperationsForModel(String model) async {
    return _operations
        .where((op) => op.model == model && op.retryCount < maxRetries)
        .toList();
  }

  @override
  Future<OfflineOperation?> getOperationById(int id) async {
    try {
      return _operations.firstWhere((op) => op.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeOperation(int id) async {
    _operations.removeWhere((op) => op.id == id);
  }

  @override
  Future<void> markOperationFailed(int id, String errorMessage) async {
    final index = _operations.indexWhere((op) => op.id == id);
    if (index >= 0) {
      final op = _operations[index];
      final newRetryCount = op.retryCount + 1;
      // Schedule next retry with exponential backoff
      final nextRetryDelay = Duration(milliseconds: 1000 * (1 << op.retryCount));
      _operations[index] = OfflineOperation(
        id: op.id,
        model: op.model,
        method: op.method,
        recordId: op.recordId,
        values: op.values,
        createdAt: op.createdAt,
        baseWriteDate: op.baseWriteDate,
        parentOrderId: op.parentOrderId,
        priority: op.priority,
        deviceId: op.deviceId,
        retryCount: newRetryCount,
        lastRetryAt: DateTime.now(),
        nextRetryAt: newRetryCount < maxRetries
            ? DateTime.now().add(nextRetryDelay)
            : null, // No next retry if max exceeded
        lastError: errorMessage,
      );
    }
  }

  @override
  Future<void> resetOperationRetry(int id) async {
    final index = _operations.indexWhere((op) => op.id == id);
    if (index >= 0) {
      final op = _operations[index];
      _operations[index] = OfflineOperation(
        id: op.id,
        model: op.model,
        method: op.method,
        recordId: op.recordId,
        values: op.values,
        createdAt: op.createdAt,
        baseWriteDate: op.baseWriteDate,
        parentOrderId: op.parentOrderId,
        priority: op.priority,
        deviceId: op.deviceId,
        retryCount: 0,
        lastRetryAt: null,
        nextRetryAt: null,
        lastError: null,
      );
    }
  }

  @override
  Future<List<OfflineOperation>> getDeadLetterOperations() async {
    return _operations.where((op) => op.retryCount >= maxRetries).toList();
  }

  @override
  Future<Map<String, dynamic>> getRetryStats() async {
    final pending = _operations.where((op) => op.retryCount < maxRetries);
    final ready = pending.where((op) => op.isReadyForRetry).length;
    final scheduled = pending.where((op) => !op.isReadyForRetry).length;
    final deadLetter = _operations.where((op) => op.retryCount >= maxRetries).length;

    return {
      'total': _operations.length,
      'ready': ready,
      'scheduled': scheduled,
      'dead_letter': deadLetter,
      // Legacy keys for backward compatibility
      'pending': ready + scheduled,
      'deadLetter': deadLetter,
    };
  }

  @override
  Future<int> removeOperationsBefore(DateTime date) async {
    final before = _operations.where((op) => op.createdAt.isBefore(date)).toList();
    _operations.removeWhere((op) => op.createdAt.isBefore(date));
    return before.length;
  }

  @override
  Future<int> removeDeadLetterOperations() async {
    final dead = _operations.where((op) => op.retryCount >= maxRetries).toList();
    _operations.removeWhere((op) => op.retryCount >= maxRetries);
    return dead.length;
  }

  @override
  Future<List<OfflineOperation>> getOperationsForRecord(
    String model,
    int recordId,
  ) async {
    return _operations
        .where((op) => op.model == model && op.recordId == recordId)
        .toList();
  }

  /// Get an operation by ID (for test assertions).
  OfflineOperation? getById(int id) {
    try {
      return _operations.firstWhere((op) => op.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Add an operation directly (for test setup).
  void addOperation(OfflineOperation op) {
    _operations.add(op);
    if (op.id >= _nextId) {
      _nextId = op.id + 1;
    }
  }
}

/// Extension methods for MockOfflineQueue setup.
extension MockOfflineQueueSetup on MockOfflineQueue {
  /// Setup an empty queue.
  void setupEmptyQueue() {
    when(() => pendingCount).thenAnswer((_) => Stream.value(0));
    when(() => isProcessing).thenAnswer((_) => Stream.value(false));
    when(() => deadLetterCount).thenAnswer((_) => Stream.value(0));
  }

  /// Setup queue with pending operations.
  void setupPendingOperations(int count) {
    when(() => pendingCount).thenAnswer((_) => Stream.value(count));
  }

  /// Setup successful enqueue.
  void setupEnqueue({int resultId = 1}) {
    when(() => enqueue(
          model: any(named: 'model'),
          method: any(named: 'method'),
          recordId: any(named: 'recordId'),
          values: any(named: 'values'),
          priority: any(named: 'priority'),
          deviceId: any(named: 'deviceId'),
        )).thenAnswer((_) async => resultId);
  }
}

/// Extension methods for MockOfflineQueueStore setup.
extension MockOfflineQueueStoreSetup on MockOfflineQueueStore {
  /// Setup empty queue.
  void setupEmptyQueue() {
    when(() => getPendingOperations(includeNotReady: any(named: 'includeNotReady')))
        .thenAnswer((_) async => []);
    when(() => getPendingCount()).thenAnswer((_) async => 0);
    when(() => getDeadLetterOperations()).thenAnswer((_) async => []);
  }

  /// Setup queue with operations.
  void setupOperations(List<OfflineOperation> operations) {
    when(() => getPendingOperations(includeNotReady: any(named: 'includeNotReady')))
        .thenAnswer((_) async => operations);
    when(() => getPendingCount()).thenAnswer((_) async => operations.length);
  }

  /// Setup successful queue operation.
  void setupQueueOperation({int resultId = 1}) {
    when(() => queueOperation(
          model: any(named: 'model'),
          method: any(named: 'method'),
          recordId: any(named: 'recordId'),
          values: any(named: 'values'),
          baseWriteDate: any(named: 'baseWriteDate'),
          parentOrderId: any(named: 'parentOrderId'),
          priority: any(named: 'priority'),
          deviceId: any(named: 'deviceId'),
        )).thenAnswer((_) async => resultId);
  }

  /// Setup remove operation.
  void setupRemoveOperation() {
    when(() => removeOperation(any())).thenAnswer((_) async {});
  }
}
