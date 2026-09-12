import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/auth/pin_credential_store.dart';

void main() {
  late SharedPreferences preferences;
  late PinCredentialStore store;
  const scopeKey = 'scope-1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = PinCredentialStore(preferences);
  });

  test('validateSellerPin rejects the wrong length and non-digits', () {
    expect(validateSellerPin('123'), isNotNull);
    expect(validateSellerPin('12345'), isNotNull);
    expect(validateSellerPin('12a4'), isNotNull);
    expect(validateSellerPin('1234'), isNull);
  });

  test('pinScopeKeyFor never embeds the raw server/database/login text', () {
    final key = pinScopeKeyFor('https://erp.test', 'demo', 'seller');
    expect(key.contains('erp.test'), isFalse);
    expect(key.contains('demo'), isFalse);
    expect(key.contains('seller'), isFalse);
  });

  test('an unenrolled scope verifies nothing and reports as not enrolled', () {
    expect(store.isEnrolled(scopeKey), isFalse);
    expect(store.verify(scopeKey, '1234'), isFalse);
  });

  test('enrolling then verifying the same PIN succeeds', () async {
    await store.enroll(scopeKey, '1234');
    expect(store.isEnrolled(scopeKey), isTrue);
    expect(store.verify(scopeKey, '1234'), isTrue);
  });

  test('a wrong PIN never verifies against an enrolled one', () async {
    await store.enroll(scopeKey, '1234');
    expect(store.verify(scopeKey, '4321'), isFalse);
    expect(store.verify(scopeKey, '0000'), isFalse);
  });

  test('enroll rejects a malformed PIN and stores nothing', () async {
    await expectLater(() => store.enroll(scopeKey, '12'), throwsFormatException);
    expect(store.isEnrolled(scopeKey), isFalse);
  });

  // The non-negotiable rule from the coordinator handoff: "Nunca guardes un
  // PIN en claro. Ni en preferencias, ni en la base local, ni en un
  // registro." — this asserts it directly against what SharedPreferences
  // actually persisted, not just against the store's own API.
  test('the raw PIN never appears anywhere in what gets persisted', () async {
    const pin = '7391';
    await store.enroll(scopeKey, pin);
    for (final key in preferences.getKeys()) {
      final raw = preferences.get(key);
      expect(
        raw.toString().contains(pin),
        isFalse,
        reason: 'Preference "$key" must never contain the raw PIN',
      );
    }
  });

  test('two enrollments of the same PIN produce different stored payloads '
      'because each draws a fresh random salt', () async {
    await store.enroll(scopeKey, '1234');
    final first = preferences.getString('orbi/auth/pin/hash/$scopeKey');
    await store.enroll(scopeKey, '1234');
    final second = preferences.getString('orbi/auth/pin/hash/$scopeKey');
    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(first, isNot(second));
    // Yet both still verify the same PIN.
    expect(store.verify(scopeKey, '1234'), isTrue);
  });

  // The hashing mechanism moved out to `secret_derivation.dart` so the
  // workspace lock screen could reuse it instead of growing a second copy.
  // That refactor is only safe if the payload on disk stayed byte-compatible:
  // a device that enrolled a PIN before the move must not be asked to enrol
  // again. This builds the payload from an independent reimplementation of the
  // original algorithm and requires the store to still accept it.
  test('a PIN enrolled before the mechanism was extracted still verifies, '
      'because the stored payload format did not change', () async {
    const pin = '5108';
    const iterations = 10000;
    final salt = Uint8List.fromList(List<int>.generate(16, (i) => i * 7 % 256));
    var block = Uint8List.fromList(utf8.encode(pin));
    for (var round = 0; round < iterations; round++) {
      block = Uint8List.fromList(Hmac(sha256, salt).convert(block).bytes);
    }
    await preferences.setString(
      'orbi/auth/pin/hash/$scopeKey',
      jsonEncode({
        'version': 1,
        'salt': base64Encode(salt),
        'hash': base64Encode(block),
        'iterations': iterations,
      }),
    );

    expect(store.isEnrolled(scopeKey), isTrue);
    expect(store.verify(scopeKey, pin), isTrue);
    expect(store.verify(scopeKey, '5107'), isFalse);
  });

  test('a corrupt payload never verifies and never throws', () async {
    await preferences.setString('orbi/auth/pin/hash/$scopeKey', 'basura');
    expect(store.verify(scopeKey, '1234'), isFalse);
  });

  test('forget removes the PIN and its attempt bookkeeping', () async {
    await store.enroll(scopeKey, '1234');
    await store.registerFailure(scopeKey);
    await store.forget(scopeKey);
    expect(store.isEnrolled(scopeKey), isFalse);
    expect(store.readAttempts(scopeKey).failedAttempts, 0);
  });

  group('lockout', () {
    test('failures below the max do not lock the scope', () async {
      await store.enroll(scopeKey, '1234');
      for (var i = 0; i < kSellerPinMaxAttempts - 1; i++) {
        final state = await store.registerFailure(scopeKey);
        expect(state.isLockedAt(DateTime.now()), isFalse);
      }
      expect(
        store.readAttempts(scopeKey).failedAttempts,
        kSellerPinMaxAttempts - 1,
      );
    });

    test('reaching the max attempts locks the scope for the full duration', () async {
      await store.enroll(scopeKey, '1234');
      final now = DateTime(2026, 9, 11, 10);
      SellerPinAttemptState? last;
      for (var i = 0; i < kSellerPinMaxAttempts; i++) {
        last = await store.registerFailure(scopeKey, now: now);
      }
      expect(last!.isLockedAt(now), isTrue);
      expect(last.lockedUntil, now.add(kSellerPinLockoutDuration));
      // The counter resets once locked, so a stale count can't shorten a
      // later window.
      expect(store.readAttempts(scopeKey).failedAttempts, 0);
    });

    test('the lockout expires after kSellerPinLockoutDuration', () async {
      await store.enroll(scopeKey, '1234');
      final now = DateTime(2026, 9, 11, 10);
      for (var i = 0; i < kSellerPinMaxAttempts; i++) {
        await store.registerFailure(scopeKey, now: now);
      }
      final state = store.readAttempts(scopeKey);
      expect(state.isLockedAt(now.add(kSellerPinLockoutDuration - const Duration(seconds: 1))), isTrue);
      expect(state.isLockedAt(now.add(kSellerPinLockoutDuration + const Duration(seconds: 1))), isFalse);
    });

    test('clearAttempts is called after a successful verify by the caller '
        'and resets the counter', () async {
      await store.enroll(scopeKey, '1234');
      await store.registerFailure(scopeKey);
      await store.registerFailure(scopeKey);
      await store.clearAttempts(scopeKey);
      expect(store.readAttempts(scopeKey).failedAttempts, 0);
    });
  });
}
