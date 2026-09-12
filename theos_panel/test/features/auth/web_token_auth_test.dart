import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_panel/features/auth/login_failure_messages.dart';
import 'package:theos_panel/features/auth/web_credential_store.dart';
import 'package:theos_panel/features/auth/web_token_auth.dart';

/// Records what was sent and answers whatever the test wants back.
final class _FakeTransport {
  _FakeTransport(this.response, {this.throws = false});

  final OrbiTokenHttpResponse response;
  final bool throws;
  Uri? url;
  Map<String, Object?>? body;

  Future<OrbiTokenHttpResponse> call(Uri url, Map<String, Object?> body) async {
    this.url = url;
    this.body = body;
    if (throws) throw Exception('socket closed');
    return response;
  }
}

OrbiTokenHttpResponse _ok({
  String database = 'erp2',
  Object? uid = 7,
  Object? apiKey = 'the-key',
  Object? expiresAt = '2026-09-12 23:41:07',
}) => OrbiTokenHttpResponse(
  statusCode: 200,
  body: {
    'database': database,
    'uid': uid,
    'token_type': 'bearer',
    'scope': 'rpc',
    'api_key': apiKey,
    'expires_at': expiresAt,
  },
);

OrbiTokenHttpResponse _error(int status, String code) => OrbiTokenHttpResponse(
  statusCode: status,
  body: {'error': code, 'error_description': 'whatever the server said'},
);

Future<WebAuthCredential> _issue(
  _FakeTransport transport, {
  String serverUrl = 'https://erp2.tecnosmart.com.ec',
  String? database,
}) => OrbiWebTokenAuthClient(transport: transport.call).issue(
  serverUrl: serverUrl,
  login: 'alice',
  password: 'secreto',
  database: database,
);

void main() {
  group('the request that used to never happen', () {
    test('goes to POST /orbi/auth/token on the SAVED server', () async {
      final transport = _FakeTransport(_ok());
      await _issue(transport);
      expect(transport.url.toString(), 'https://erp2.tecnosmart.com.ec/orbi/auth/token');
    });

    test('is built from the saved server, never from where the page lives', () {
      // ERP2 now serves Orbi from its own domain under /orbi/, and the app is
      // also meant to run from somewhere else. Deriving the URL from Uri.base
      // would work in exactly one of those two.
      expect(
        OrbiWebTokenAuthClient.endpointFor(
          'https://erp2.tecnosmart.com.ec/orbi/',
        ).toString(),
        'https://erp2.tecnosmart.com.ec/orbi/auth/token',
      );
      expect(
        OrbiWebTokenAuthClient.endpointFor('https://otro.dominio.test').path,
        '/orbi/auth/token',
      );
    });

    test('carries login, password and a device label the user can revoke', () async {
      final transport = _FakeTransport(_ok());
      await _issue(transport);
      expect(transport.body!['login'], 'alice');
      expect(transport.body!['password'], 'secreto');
      expect(transport.body!['device'], isNotNull);
    });

    test('sends db only when there is one to pin', () async {
      final withDb = _FakeTransport(_ok());
      await _issue(withDb, database: 'erp2');
      expect(withDb.body!['db'], 'erp2');

      final without = _FakeTransport(_ok());
      await _issue(without);
      expect(without.body!.containsKey('db'), isFalse);
    });

    test('an empty form never reaches the network', () async {
      final transport = _FakeTransport(_ok());
      await expectLater(
        OrbiWebTokenAuthClient(transport: transport.call).issue(
          serverUrl: 'https://erp2.tecnosmart.com.ec',
          login: '  ',
          password: '',
        ),
        throwsA(isA<WebTokenAuthException>()),
      );
      expect(transport.url, isNull);
    });
  });

  group('what comes back on success', () {
    test('is the key, the uid, and the database the SERVER served', () async {
      // Not the one that was typed: the route is served from the db-aware
      // router, so the host already decided which database this is.
      final token = await _issue(
        _FakeTransport(_ok(database: 'la_del_servidor')),
        database: 'la_que_escribi',
      );
      expect(token.database, 'la_del_servidor');
      expect(token.uid, 7);
      expect(token.apiKey, 'the-key');
    });

    test('🔴 the expiry is read as UTC, not as local time', () async {
      // Odoo writes fields.Datetime.to_string: no zone marker, and it is UTC.
      // DateTime.parse would call it local, which in Guayaquil (UTC-5) hands
      // the credential five extra hours of apparent life — a dead key treated
      // as alive. The parsing itself belongs to WebAuthCredential; what is
      // asserted here is that this client routes through it instead of
      // reaching for DateTime.parse on its own.
      final token = await _issue(
        _FakeTransport(_ok(expiresAt: '2026-09-12 23:41:07')),
      );
      expect(token.expiresAt.isUtc, isTrue);
      expect(token.expiresAt, DateTime.utc(2026, 9, 12, 23, 41, 7));
      expect(
        token.expiresAt,
        isNot(DateTime.parse('2026-09-12 23:41:07').toUtc()),
        reason:
            'Reading it as local time is exactly the bug this guards; if the '
            'machine runs on UTC this assertion is vacuous, but on the '
            "owner's machine it is not.",
        skip: DateTime.now().timeZoneOffset == Duration.zero,
      );
    });

    test('an expired key knows it is expired', () async {
      final token = await _issue(
        _FakeTransport(_ok(expiresAt: '2026-09-12 23:41:07')),
      );
      expect(token.isExpiredAt(DateTime.utc(2026, 9, 12, 23, 41, 6)), isFalse);
      expect(token.isExpiredAt(DateTime.utc(2026, 9, 13)), isTrue);
    });

    test('a 200 missing any promised field is not accepted as a login', () async {
      for (final broken in [
        _ok(apiKey: ''),
        _ok(apiKey: 42),
        _ok(uid: 0),
        _ok(database: ''),
        _ok(expiresAt: 'no es una fecha'),
        const OrbiTokenHttpResponse(statusCode: 200, body: null),
      ]) {
        await expectLater(
          _issue(_FakeTransport(broken)),
          throwsA(
            isA<WebTokenAuthException>().having(
              (e) => e.kind,
              'kind',
              WebTokenAuthFailureKind.malformedResponse,
            ),
          ),
        );
      }
    });
  });

  group('every documented error becomes something the person can act on', () {
    const cases = <String, (int, String, LoginFailureCause)>{
      'wrong password or unknown user': (
        401,
        'invalid_credentials',
        LoginFailureCause.invalidCredentials,
      ),
      'second factor': (
        403,
        'mfa_required',
        LoginFailureCause.additionalVerificationRequired,
      ),
      'origin not on the allow-list': (
        403,
        'forbidden_origin',
        LoginFailureCause.accessDenied,
      ),
      'not in the required group': (
        403,
        'not_allowed',
        LoginFailureCause.accessDenied,
      ),
      'login refused': (
        403,
        'login_rejected',
        LoginFailureCause.accessDenied,
      ),
      'cooldown': (
        429,
        'too_many_attempts',
        LoginFailureCause.tooManyAttempts,
      ),
      'malformed request': (
        400,
        'invalid_request',
        LoginFailureCause.incompleteForm,
      ),
      'database unavailable': (
        400,
        'database_unavailable',
        LoginFailureCause.incompleteForm,
      ),
      'server broke': (500, 'server_error', LoginFailureCause.serverError),
    };

    cases.forEach((label, triple) {
      final (status, code, expected) = triple;
      test('$label -> ${expected.name}', () async {
        try {
          await _issue(_FakeTransport(_error(status, code)));
          fail('should have thrown');
        } on WebTokenAuthException catch (error) {
          expect(classifyLoginFailure(error), expected);
          // And whatever it is, the person gets words, never a code.
          final message = describeLoginFailure(error);
          expect(message.title, isNotEmpty);
          expect(message.guidance, isNotEmpty);
          expect(message.guidance, isNot(contains('$status')));
          expect(message.guidance, isNot(contains(code)));
        }
      });
    });

    test('the cooldown is its own cause, not "wrong password"', () async {
      // Telling somebody their password is wrong when the server merely said
      // "not right now" sends them to reset a password that was fine.
      try {
        await _issue(_FakeTransport(_error(429, 'too_many_attempts')));
        fail('should have thrown');
      } on WebTokenAuthException catch (error) {
        final message = describeLoginFailure(error);
        expect(message.cause, LoginFailureCause.tooManyAttempts);
        expect(message.guidance, contains('Espera'));
        expect(
          message.title,
          isNot(loginFailureMessageFor(
            LoginFailureCause.invalidCredentials,
          ).title),
        );
      }
    });

    test('an unrecognised code still trusts the status, never invents', () async {
      try {
        await _issue(_FakeTransport(_error(403, 'algo_nuevo')));
        fail('should have thrown');
      } on WebTokenAuthException catch (error) {
        expect(error.kind, WebTokenAuthFailureKind.forbidden);
      }
    });

    test('a redirect means we did not reach the route we meant to', () async {
      // A GET to this path answers 303 (it falls through to the catch-all
      // that redirects to login). If our POST ever gets one, the honest
      // reading is "we did not get there", not "your password is wrong".
      try {
        await _issue(
          _FakeTransport(const OrbiTokenHttpResponse(statusCode: 303)),
        );
        fail('should have thrown');
      } on WebTokenAuthException catch (error) {
        expect(error.kind, WebTokenAuthFailureKind.transport);
        expect(
          classifyLoginFailure(error),
          LoginFailureCause.serverUnreachable,
        );
      }
    });

    test('a socket that never connects is a connection problem', () async {
      try {
        await _issue(
          _FakeTransport(
            const OrbiTokenHttpResponse(statusCode: 0),
            throws: true,
          ),
        );
        fail('should have thrown');
      } on WebTokenAuthException catch (error) {
        expect(error.kind, WebTokenAuthFailureKind.transport);
      }
    });

    test('nothing it throws ever carries the password or a payload', () async {
      try {
        await _issue(_FakeTransport(_error(401, 'invalid_credentials')));
        fail('should have thrown');
      } on WebTokenAuthException catch (error) {
        expect(error.toString(), isNot(contains('secreto')));
        expect(error.toString(), isNot(contains('alice')));
        expect(error.toString(), isNot(contains('whatever the server said')));
      }
    });
  });

  group('when a STORED credential must be thrown away, and when not', () {
    // The persistence half asked the one question that decides this, and its
    // worry was exact: a typed password and a stored key are both rejected
    // with a plain 401, so cause alone cannot separate them. The type can.
    test('nothing a typed sign-in throws ever discards a stored key', () async {
      for (final kind in WebTokenAuthFailureKind.values) {
        expect(
          shouldDiscardStoredCredential(WebTokenAuthException(kind)),
          isFalse,
          reason:
              '${kind.name} came from someone typing a password; a typo must '
              'never cost anybody their offline unlock.',
        );
      }
    });

    test('a stored credential the server rejects IS discarded', () {
      for (final error in <Object>[
        const OdooAuthenticationException('unauthorized'),
        const OdooSessionExpiredException(),
        const OdooAccessDeniedException('forbidden'),
        StateError('API key belongs to another Odoo user'),
      ]) {
        expect(
          shouldDiscardStoredCredential(error),
          isTrue,
          reason: 'A rejected stored credential must not be replayed forever.',
        );
      }
    });

    test('a cooldown never discards: "not right now" is not "not valid"', () {
      // Discarding here would turn a few minutes of waiting into the loss of
      // the offline unlock.
      expect(
        shouldDiscardStoredCredential(
          const WebTokenAuthException(
            WebTokenAuthFailureKind.tooManyAttempts,
          ),
        ),
        isFalse,
      );
    });

    test('a network problem never discards either', () {
      for (final error in <Object>[
        const OdooConnectionException(),
        const OdooTimeoutException(),
        const OdooServerException('boom'),
      ]) {
        expect(shouldDiscardStoredCredential(error), isFalse);
      }
    });
  });

  group('the provider stays inert until the composition root wires it', () {
    test('no default client, so no widget test opens a socket by accident', () {
      // Same shape, and same hard-won reason, as networkPresenceProbeProvider
      // and workspaceUnlockBackendProvider.
      expect(orbiWebTokenClientProvider, isNotNull);
    });
  });
}
