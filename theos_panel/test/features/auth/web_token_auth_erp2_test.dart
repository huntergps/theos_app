@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/auth/login_failure_messages.dart';
import 'package:theos_panel/features/auth/web_token_auth.dart';

/// Proves the browser path really reaches a real Odoo, using the REAL
/// transport — not a fake — against a live server.
///
/// Skips itself when `ORBI_ERP2_BASE_URL` is absent, the same convention the
/// rest of this repo uses for tests that need a live Odoo, and it never logs
/// the value.
///
/// 🔴 Both cases below are refused by the route BEFORE it authenticates
/// anything, on purpose: `invalid_request` and `database_unavailable` do not
/// touch `res.users.authenticate`, so running this never spends an attempt
/// against Odoo's per-IP login cooldown. A test that quietly burned the
/// owner's cooldown every CI run would be worse than no test.
void main() {
  final baseUrl = Platform.environment['ORBI_ERP2_BASE_URL'];
  final client = OrbiWebTokenAuthClient(transport: odooSdkTokenTransport());

  group(
    'the real transport against a real Odoo',
    skip: baseUrl == null || baseUrl.isEmpty
        ? 'set ORBI_ERP2_BASE_URL to run'
        : null,
    () {
      test('a request with nothing in it comes back as a form problem', () async {
        // Reaching this assertion at all is the point: it means a request
        // left the process, crossed the network, hit /orbi/auth/token and
        // came back parsed. That is precisely what the browser used to NOT
        // do — zero requests, zero errors, zero words.
        try {
          await client.issue(
            serverUrl: baseUrl!,
            login: ' ',
            password: 'x',
            database: 'definitivamente_no_existe_esta_base',
          );
          fail('the server accepted a nonexistent database');
        } on WebTokenAuthException catch (error) {
          expect(error.kind, WebTokenAuthFailureKind.badRequest);
          expect(
            classifyLoginFailure(error),
            LoginFailureCause.incompleteForm,
          );
        }
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('and the person gets words, never a status code', () async {
        try {
          await client.issue(
            serverUrl: baseUrl!,
            login: 'x',
            password: 'y',
            database: 'definitivamente_no_existe_esta_base',
          );
          fail('the server accepted a nonexistent database');
        } on WebTokenAuthException catch (error) {
          final message = describeLoginFailure(error);
          expect(message.title, isNotEmpty);
          expect(message.guidance, isNotEmpty);
          for (final leak in ['400', 'database_unavailable', 'HTTP']) {
            expect(message.guidance, isNot(contains(leak)));
          }
        }
      }, timeout: const Timeout(Duration(seconds: 30)));
    },
  );

  // ==========================================================================
  // The question the whole browser workstream exists to answer: can a person
  // sign in with a username and a password, from a browser, against a real
  // Odoo? Run with the ORBI_ERP2_TEST_SELLER_* variables, which are read from
  // the environment and never logged.
  //
  // 🔴 Unlike the group above, this one DOES authenticate, so it spends an
  // attempt against Odoo's per-IP cooldown and mints a real (expiring) key on
  // the server. It is gated behind its own variables precisely so it never
  // runs by accident in CI.
  // ==========================================================================
  final sellerUrl = Platform.environment['ORBI_ERP2_TEST_SELLER_SERVER_URL'];
  final sellerLogin = Platform.environment['ORBI_ERP2_TEST_SELLER_LOGIN'];
  final sellerPassword = Platform.environment['ORBI_ERP2_TEST_SELLER_PASSWORD'];
  final sellerDatabase = Platform.environment['ORBI_ERP2_TEST_SELLER_DATABASE'];
  final sellerUserId = Platform.environment['ORBI_ERP2_TEST_SELLER_USER_ID'];

  group(
    'signing in with a real password against a real Odoo',
    skip: (sellerUrl == null || sellerLogin == null || sellerPassword == null)
        ? 'set ORBI_ERP2_TEST_SELLER_* to run'
        : null,
    () {
      test('returns a usable, expiring credential', () async {
        final credential = await client.issue(
          serverUrl: sellerUrl!,
          login: sellerLogin!,
          password: sellerPassword!,
          database: sellerDatabase,
        );

        // The database the SERVER served, which is the authoritative one.
        if (sellerDatabase != null) {
          expect(credential.database, sellerDatabase);
        }
        if (sellerUserId != null) {
          expect(credential.uid, int.parse(sellerUserId));
        }
        expect(credential.apiKey, isNotEmpty);
        expect(credential.tokenType, 'bearer');
        expect(credential.scope, 'rpc');

        // 🔴 The expiry is the reason this credential is acceptable to keep
        // in a browser at all, so it is asserted, not assumed: roughly a day,
        // never absent and never open-ended.
        final now = DateTime.now().toUtc();
        expect(credential.expiresAt.isUtc, isTrue);
        expect(credential.isExpiredAt(now), isFalse);
        final life = credential.expiresAt.difference(now);
        expect(life, greaterThan(const Duration(hours: 23)));
        expect(
          life,
          lessThanOrEqualTo(const Duration(days: 1)),
          reason:
              'A longer life than a day is what made storing a real '
              'credential in a browser unacceptable in the first place.',
        );
      }, timeout: const Timeout(Duration(seconds: 45)));

      test('and a wrong password is refused without saying who exists', () async {
        // Costs one cooldown attempt, deliberately: proving the rejection
        // path against the real server is worth it, and the message must
        // never hint at whether the login exists.
        try {
          await client.issue(
            serverUrl: sellerUrl!,
            login: sellerLogin!,
            password: 'definitivamente-no-es-esta-contrasena',
          );
          fail('the server accepted a wrong password');
        } on WebTokenAuthException catch (error) {
          expect(
            error.kind,
            anyOf(
              WebTokenAuthFailureKind.invalidCredentials,
              // The owner's IP may already be in cooldown from earlier
              // probing; that is a different true answer, not a failure.
              WebTokenAuthFailureKind.tooManyAttempts,
            ),
          );
          final message = describeLoginFailure(error);
          for (final leak in ['no existe', 'unknown user', 'not found']) {
            expect(message.guidance.toLowerCase(), isNot(contains(leak)));
          }
          // And a typed password that was refused never costs the stored
          // credential.
          expect(
            shouldDiscardStoredCredential(error, someoneTyped: true),
            isFalse,
          );
        }
      }, timeout: const Timeout(Duration(seconds: 45)));
    },
  );
}
