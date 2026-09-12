import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/secret_derivation.dart';

/// The mechanism both the seller PIN and the workspace unlock derivation sit
/// on. Every property asserted here is one neither caller is allowed to lose.
void main() {
  group('SecretDerivation', () {
    test('a derivation matches the secret it was made from', () {
      final derivation = SecretDerivation.fromSecret('contraseña-real');
      expect(derivation.matches('contraseña-real'), isTrue);
    });

    test('no other candidate matches, including near misses', () {
      final derivation = SecretDerivation.fromSecret('contraseña-real');
      expect(derivation.matches('contraseña-rea'), isFalse);
      expect(derivation.matches('contraseña-reaL'), isFalse);
      expect(derivation.matches('Contraseña-real'), isFalse);
      expect(derivation.matches(''), isFalse);
    });

    test('the encoded payload never contains the secret, in cleartext or in '
        'any base64 of it', () {
      const secret = 'Tr4nsp0rte-Gal4pagos';
      final payload = SecretDerivation.fromSecret(secret).encode();
      expect(payload.contains(secret), isFalse);
      expect(payload.contains(base64Encode(utf8.encode(secret))), isFalse);
      expect(
        payload.contains(base64Url.encode(utf8.encode(secret))),
        isFalse,
      );
    });

    test('two enrolments of the same secret differ, because each draws a '
        'fresh random salt — yet both still verify it', () {
      const secret = 'la-misma-contraseña';
      final first = SecretDerivation.fromSecret(secret);
      final second = SecretDerivation.fromSecret(secret);
      expect(first.encode(), isNot(second.encode()));
      expect(first.salt, isNot(second.salt));
      expect(first.matches(secret), isTrue);
      expect(second.matches(secret), isTrue);
    });

    test('a payload survives a round trip through storage', () {
      const secret = 'ida-y-vuelta';
      final decoded = SecretDerivation.decode(
        SecretDerivation.fromSecret(secret).encode(),
      );
      expect(decoded.matches(secret), isTrue);
      expect(decoded.matches('otra'), isFalse);
      expect(decoded.iterations, kSecretDerivationIterations);
    });

    test('the iteration count travels with the payload, so raising the cost '
        'later never invalidates what is already enrolled', () {
      final cheap = SecretDerivation.fromSecret('secreto', iterations: 7);
      final decoded = SecretDerivation.decode(cheap.encode());
      expect(decoded.iterations, 7);
      expect(decoded.matches('secreto'), isTrue);
    });

    test('decode refuses anything it cannot evaluate instead of guessing', () {
      expect(() => SecretDerivation.decode('no-json'), throwsFormatException);
      expect(() => SecretDerivation.decode('[]'), throwsFormatException);
      expect(
        () => SecretDerivation.decode(jsonEncode({'version': 2})),
        throwsFormatException,
      );
      expect(
        () => SecretDerivation.decode(
          jsonEncode({'version': 1, 'salt': 'AA==', 'hash': 'AA=='}),
        ),
        throwsFormatException,
      );
      expect(
        () => SecretDerivation.decode(
          jsonEncode({
            'version': 1,
            'salt': 'AA==',
            'hash': 'AA==',
            'iterations': 0,
          }),
        ),
        throwsFormatException,
      );
    });
  });

  group('secretScopeKey', () {
    test('never embeds the raw values it scopes by', () {
      final key = secretScopeKey([
        'https://erp2.galapagos.tech',
        'orbi_demo',
        'vendedor@orbi',
        '42',
      ]);
      expect(key.contains('erp2'), isFalse);
      expect(key.contains('orbi_demo'), isFalse);
      expect(key.contains('vendedor'), isFalse);
    });

    test('is stable for the same parts and different for any change', () {
      final base = secretScopeKey(['a', 'b', 'c']);
      expect(secretScopeKey(['a', 'b', 'c']), base);
      expect(secretScopeKey(['a', 'b', 'd']), isNot(base));
      expect(secretScopeKey(['a', 'b']), isNot(base));
    });
  });

  group('LocalAttemptState', () {
    const maxAttempts = 4;
    const lockout = Duration(minutes: 5);
    final now = DateTime(2026, 9, 11, 10);

    test('failures below the cap never lock', () {
      var state = const LocalAttemptState();
      for (var i = 1; i < maxAttempts; i++) {
        state = state.afterFailure(
          maxAttempts: maxAttempts,
          lockout: lockout,
          now: now,
        );
        expect(state.failedAttempts, i);
        expect(state.isLockedAt(now), isFalse);
      }
    });

    test('reaching the cap locks for the full window and resets the counter, '
        'so a stale high count cannot shorten a later window', () {
      var state = const LocalAttemptState();
      for (var i = 0; i < maxAttempts; i++) {
        state = state.afterFailure(
          maxAttempts: maxAttempts,
          lockout: lockout,
          now: now,
        );
      }
      expect(state.isLockedAt(now), isTrue);
      expect(state.lockedUntil, now.add(lockout));
      expect(state.failedAttempts, 0);
      expect(state.remainingAt(now), lockout);
      expect(
        state.isLockedAt(now.add(lockout - const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        state.isLockedAt(now.add(lockout + const Duration(seconds: 1))),
        isFalse,
      );
      expect(state.remainingAt(now.add(lockout)), Duration.zero);
    });

    test('a lockout survives a round trip through storage', () {
      final locked = const LocalAttemptState().afterFailure(
        maxAttempts: 1,
        lockout: lockout,
        now: now,
      );
      final decoded = LocalAttemptState.decode(locked.encode());
      expect(decoded.lockedUntil, locked.lockedUntil);
      expect(decoded.isLockedAt(now), isTrue);
    });
  });
}
