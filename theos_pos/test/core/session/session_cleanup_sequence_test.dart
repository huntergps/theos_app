import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/session/session_cleanup_sequence.dart';

void main() {
  test('runs cleanup phases in declaration order', () async {
    final calls = <String>[];

    await runBestEffortSessionCleanup([
      SessionCleanupStep('sync', () => calls.add('sync')),
      SessionCleanupStep('offline', () async => calls.add('offline')),
      SessionCleanupStep('database', () => calls.add('database')),
    ]);

    expect(calls, ['sync', 'offline', 'database']);
  });

  test(
    'continues through credential and database cleanup after a failure',
    () async {
      final calls = <String>[];
      final failures = <String>[];

      await runBestEffortSessionCleanup([
        SessionCleanupStep('sync', () {
          calls.add('sync');
          throw StateError('writer failed to stop');
        }),
        SessionCleanupStep('credentials', () => calls.add('credentials')),
        SessionCleanupStep('database', () => calls.add('database')),
      ], onError: (step, _, _) => failures.add(step));

      expect(calls, ['sync', 'credentials', 'database']);
      expect(failures, ['sync']);
    },
  );
}
