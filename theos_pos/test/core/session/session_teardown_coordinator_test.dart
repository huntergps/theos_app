import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/session/session_teardown_coordinator.dart';

void main() {
  test('coalesces concurrent teardown calls', () async {
    final coordinator = SessionTeardownCoordinator();
    final release = Completer<void>();
    var calls = 0;

    final first = coordinator.run(() async {
      calls++;
      await release.future;
    });
    final second = coordinator.run(() async {
      calls++;
    });

    expect(coordinator.isRunning, isTrue);
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    release.complete();
    await first;
    expect(coordinator.isRunning, isFalse);
  });

  test('allows a new teardown after completion', () async {
    final coordinator = SessionTeardownCoordinator();
    var calls = 0;
    await coordinator.run(() => calls++);
    await coordinator.run(() => calls++);
    expect(calls, 2);
  });

  test('shares failures and can recover for a later attempt', () async {
    final coordinator = SessionTeardownCoordinator();
    final error = StateError('teardown failed');
    final first = coordinator.run(() => Future<void>.error(error));
    final second = coordinator.run(() {});
    expect(identical(first, second), isTrue);
    await expectLater(first, throwsA(same(error)));
    await coordinator.run(() {});
    expect(coordinator.isRunning, isFalse);
  });
}
