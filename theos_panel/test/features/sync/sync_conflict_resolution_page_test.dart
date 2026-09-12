// This is the exact widget `router.dart` pushes for SYN-03 when a live
// operations queue is available (see `onOpenConflicts` in
// `lib/app/router.dart`). `sync_conflict_route_test.dart` proves the router
// reaches this slot instead of the old fixed dialog; this file proves the
// slot itself works end to end against a real `OfflineQueueStore` contract
// (a hand-written fake, not a mock of business behaviour) rather than only
// through the synthetic `SyncReviewItem` fixtures used elsewhere in this
// suite.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/sync/sync_conflict_resolution_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _FakeOfflineQueueStore implements OfflineQueueStore {
  final List<OfflineOperation> deadLetter;
  int? conflictCalledWith;

  _FakeOfflineQueueStore(this.deadLetter);

  @override
  Future<List<OfflineOperation>> getDeadLetterOperations() async =>
      deadLetter;

  @override
  Future<void> markOperationConflict(int id) async {
    conflictCalledWith = id;
  }

  @override
  Future<int> queueOperation({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority = 0,
    String? deviceId,
    String? operationKey,
    int commandVersion = 1,
    OfflineReplayPolicy? replayPolicy,
  }) => throw UnimplementedError('not used by SYN-03');

  @override
  Future<List<OfflineOperation>> getPendingOperations({
    bool includeNotReady = false,
  }) => throw UnimplementedError('not used by SYN-03');

  @override
  Future<int> getPendingCount() => throw UnimplementedError('not used by SYN-03');

  @override
  Future<List<OfflineOperation>> getOperationsForModel(String model) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<OfflineOperation?> getOperationById(int id) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<void> removeOperation(int id) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<void> markOperationFailed(int id, String errorMessage) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<void> resetOperationRetry(int id) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<Map<String, dynamic>> getRetryStats() =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<int> removeOperationsBefore(DateTime date) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<int> removeDeadLetterOperations() =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<List<OfflineOperation>> getOperationsForRecord(
    String model,
    int recordId,
  ) => throw UnimplementedError('not used by SYN-03');

  @override
  Future<void> markOperationProcessing(int id) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<void> markOperationPending(int id) =>
      throw UnimplementedError('should never be called by SYN-03 — see '
          'QueueSyncConflictPort.decide()\'s "keepPending" branch');

  @override
  Future<void> markOperationCompleted(int id) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<void> markOperationDeadLetter(int id, String errorMessage) =>
      throw UnimplementedError('not used by SYN-03');

  @override
  Future<void> replaceOperationValues(int id, Map<String, dynamic> values) =>
      throw UnimplementedError('not used by SYN-03');
}

// `id` is the queue row identity `SyncReviewItem.operationId` carries and the
// only thing `decide()` may act on; `recordId` is the target Odoo record,
// what `documentLabel` shows. They are deliberately different numbers here
// so a test that confuses one for the other fails loudly instead of passing
// by coincidence.
OfflineOperation _uncertainOperation() => OfflineOperation(
  id: 7,
  model: 'sale.order',
  recordId: 41,
  method: 'order_confirm',
  values: const {},
  createdAt: DateTime(2026, 9, 11),
  replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
  lastError:
      'Recovered an operation after an interrupted dispatch without a '
      'server reconciliation contract. Manual review is required.',
);

void main() {
  testWidgets(
    'SyncConflictResolutionPage renders real dead-letter rows from the queue',
    (tester) async {
      final queue = _FakeOfflineQueueStore([_uncertainOperation()]);
      await tester.pumpWidget(
        FluentApp(theme: OrbiFluentTheme.light, home: SyncConflictResolutionPage(queue: queue)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resolver conflicto'), findsWidgets);
      expect(find.text('sale.order #41 · Incierta'), findsOneWidget);
      expect(
        find.textContaining('no llegó confirmación del servidor'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '"Revisar con supervisor" calls the real markOperationConflict, never a resend',
    (tester) async {
      final queue = _FakeOfflineQueueStore([_uncertainOperation()]);
      await tester.pumpWidget(
        FluentApp(theme: OrbiFluentTheme.light, home: SyncConflictResolutionPage(queue: queue)),
      );
      await tester.pumpAndSettle();

      // The default test surface is short enough that the explanatory
      // `InfoBar` pushes the action below the fold of the page's
      // `SingleChildScrollView`; scroll it into view before tapping.
      final reviewButton = find.widgetWithText(
        FilledButton,
        'Revisar con supervisor',
      );
      await tester.ensureVisible(reviewButton);
      await tester.pumpAndSettle();
      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      expect(queue.conflictCalledWith, 7);
    },
  );
}
