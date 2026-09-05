import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/features/authentication/services/offline_session_attempt_guard.dart';

void main() {
  test('offline fallback accepts only transport unavailability', () {
    expect(isOfflineFallbackEligible(const OdooConnectionException()), isTrue);
    expect(isOfflineFallbackEligible(const OdooTimeoutException()), isTrue);
    expect(isOfflineFallbackEligible(const OdooOfflineException()), isTrue);

    expect(
      isOfflineFallbackEligible(const OdooServerException('server failed')),
      isFalse,
    );
    expect(
      isOfflineFallbackEligible(const OdooNotFoundException('missing')),
      isFalse,
    );
    expect(isOfflineFallbackEligible(StateError('parser bug')), isFalse);
  });

  test('failed offline attempt always deactivates its scope', () async {
    var deactivateCalls = 0;
    final guard = OfflineSessionAttemptGuard(() async => deactivateCalls++);

    await guard.close();
    await guard.close();

    expect(deactivateCalls, 1);
    expect(guard.succeeded, isFalse);
  });

  test('successful offline attempt keeps its active scope', () async {
    var deactivateCalls = 0;
    final guard = OfflineSessionAttemptGuard(() async => deactivateCalls++);

    guard.markSucceeded();
    await guard.close();

    expect(deactivateCalls, 0);
    expect(guard.succeeded, isTrue);
  });

  test('deactivation errors remain visible to the caller', () async {
    final failure = StateError('teardown failed');
    final guard = OfflineSessionAttemptGuard(() => Future<void>.error(failure));

    await expectLater(guard.close(), throwsA(same(failure)));
  });
}
