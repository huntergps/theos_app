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
}
