import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show
        AuthProfile,
        AuthServiceResult,
        NotificationSeverity;
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_failure_messages.dart';

/// Every cause paired with an exception that really reaches the login screen
/// from the kit, so the table below is a contract against the ACTUAL
/// exception hierarchy and not against a set of hand-written stand-ins.
///
/// `noNetwork` and `serverNotResponding` are absent on purpose: neither is
/// produced by an exception. They only exist once connectivity has been
/// measured — see the refinement group at the bottom.
const _causeByError = <String, (Object, LoginFailureCause)>{
  'bad password (bootstrap)': (
    NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.invalidCredentials,
    ),
    LoginFailureCause.invalidCredentials,
  ),
  'two-factor account': (
    NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.additionalVerificationRequired,
    ),
    LoginFailureCause.additionalVerificationRequired,
  ),
  'server refuses the account': (
    NativeAuthBootstrapException(NativeAuthBootstrapFailureKind.accessDenied),
    LoginFailureCause.accessDenied,
  ),
  'api key could not be minted': (
    NativeAuthBootstrapException(NativeAuthBootstrapFailureKind.protocol),
    LoginFailureCause.credentialIssueFailed,
  ),
  'connection failed (bootstrap)': (
    NativeAuthBootstrapException(NativeAuthBootstrapFailureKind.connection),
    LoginFailureCause.serverUnreachable,
  ),
  'address is not https': (
    NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.insecureTransport,
    ),
    LoginFailureCause.insecureAddress,
  ),
  'password login on the web': (
    NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.unsupportedPlatform,
    ),
    LoginFailureCause.passwordLoginUnsupportedHere,
  ),
  'session expired': (
    OdooSessionExpiredException(),
    LoginFailureCause.sessionExpired,
  ),
  'authentication rejected': (
    OdooAuthenticationException('unauthorized'),
    LoginFailureCause.invalidCredentials,
  ),
  'access denied': (
    OdooAccessDeniedException('forbidden'),
    LoginFailureCause.accessDenied,
  ),
  'model missing on this server': (
    OdooMethodNotFoundException(
      targetModel: 'res.users.apikeys.description',
      methodName: 'make_key',
      message: 'missing',
    ),
    LoginFailureCause.incompatibleServer,
  ),
  'field missing on this server': (
    OdooFieldNotFoundException(
      targetModel: 'res.users',
      fieldName: 'ghost',
      message: 'missing',
    ),
    LoginFailureCause.incompatibleServer,
  ),
  'timed out': (OdooTimeoutException(), LoginFailureCause.timeout),
  'no connection': (
    OdooConnectionException(),
    LoginFailureCause.serverUnreachable,
  ),
  'server exploded': (
    OdooServerException('boom'),
    LoginFailureCause.serverError,
  ),
};

void main() {
  group('classifyLoginFailure keeps the causes the kit already tells apart', () {
    _causeByError.forEach((label, pair) {
      final (error, expected) = pair;
      test('$label -> ${expected.name}', () {
        expect(classifyLoginFailure(error), expected);
      });
    });

    test('an empty API-key form is a form problem, not a rejection', () {
      expect(
        classifyLoginFailure(
          ArgumentError('server, database, login and apiKey are required'),
        ),
        LoginFailureCause.incompleteForm,
      );
    });

    test('an API key that belongs to somebody else is named as such', () {
      expect(
        classifyLoginFailure(
          StateError('API key belongs to another Odoo user'),
        ),
        LoginFailureCause.apiKeyRejected,
      );
    });

    test('a StateError of ours is never blamed on the person\'s key', () {
      // `_MissingRuntime` in orbi_runtime raises exactly this. It is our
      // defect; telling the operator to regenerate their key would send them
      // chasing a problem they do not have.
      expect(
        classifyLoginFailure(StateError('Session runtime is required')),
        LoginFailureCause.unknown,
      );
    });

    test('a plain timeout is a timeout', () {
      expect(
        classifyLoginFailure(TimeoutException('slow')),
        LoginFailureCause.timeout,
      );
    });

    test('anything unrecognised stays unknown instead of being invented', () {
      expect(classifyLoginFailure(Object()), LoginFailureCause.unknown);
      expect(classifyLoginFailure('a bare string'), LoginFailureCause.unknown);
    });
  });

  group('the owner\'s case: a credential that could not be created', () {
    // THE regression this whole file exists for. Signing in is two steps —
    // prove the password, then have the server mint this device's API key —
    // and when the second one fails the old screen said the very same
    // sentence as a mistyped password. The remedy is the opposite, so the
    // two must never collapse again.
    test('is a different cause than a wrong password', () {
      const wrongPassword = NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.invalidCredentials,
      );
      const cannotMintKey = NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.protocol,
      );
      expect(
        classifyLoginFailure(cannotMintKey),
        isNot(classifyLoginFailure(wrongPassword)),
      );
    });

    test('says out loud that it is not a wrong password', () {
      final message = describeLoginFailure(
        const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      );
      expect(message.cause, LoginFailureCause.credentialIssueFailed);
      expect(message.guidance, contains('no es una contraseña equivocada'));
      // And it points at the only person who can actually fix it.
      expect(message.guidance.toLowerCase(), contains('administrador'));
    });

    test('never tells the person to retype something that is already right', () {
      final message = describeLoginFailure(
        const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      );
      expect(message.title.toLowerCase(), isNot(contains('contraseña incorrect')));
    });
  });

  group('what the person reads', () {
    test('every cause has a message, and the titles are all distinct', () {
      final titles = <String>{};
      for (final cause in LoginFailureCause.values) {
        final message = loginFailureMessageFor(cause);
        expect(message.cause, cause);
        expect(message.title.trim(), isNotEmpty);
        expect(message.guidance.trim(), isNotEmpty);
        expect(
          titles.add(message.title),
          isTrue,
          reason:
              'Two causes share the title "${message.title}" — '
              'decodeLoginFailureMessage resolves by title, and the form '
              'would show the wrong guidance.',
        );
      }
    });

    test('says what happened AND what to do, never just what happened', () {
      for (final cause in LoginFailureCause.values) {
        final message = loginFailureMessageFor(cause);
        expect(
          message.guidance.length,
          greaterThan(message.title.length),
          reason:
              '${cause.name}: the guidance must carry the instruction, not '
              'repeat the headline.',
        );
      }
    });

    test('never leaks internals — explaining is not dumping', () {
      // "https" is NOT on this list: it is the thing the person (or their
      // administrator) has to fix in the server address, and naming it is
      // help, not a leak. What may never appear is our plumbing.
      const forbidden = [
        'exception',
        'null',
        'stack',
        'traceback',
        'statuscode',
        'json',
        'rpc',
        'odooclient',
        'dio',
        '#0',
      ];
      for (final cause in LoginFailureCause.values) {
        final message = loginFailureMessageFor(cause);
        final text = '${message.title} ${message.guidance}'.toLowerCase();
        for (final needle in forbidden) {
          expect(
            text,
            isNot(contains(needle)),
            reason: '${cause.name} leaks "$needle" to a person at a counter.',
          );
        }
        expect(
          RegExp(r'\b[45]\d\d\b').hasMatch(text),
          isFalse,
          reason: '${cause.name} shows a raw status code.',
        );
      }
    });

    test('never reveals whether a user exists', () {
      // Saying "that user does not exist" hands an attacker a free directory
      // of valid logins. The message has to stay ambiguous between the two.
      final message = loginFailureMessageFor(
        LoginFailureCause.invalidCredentials,
      );
      final text = '${message.title} ${message.guidance}'.toLowerCase();
      for (final needle in [
        'no existe',
        'usuario desconocido',
        'no encontrado',
        'no está registrado',
        'no se encontró',
      ]) {
        expect(text, isNot(contains(needle)), reason: 'leaks "$needle"');
      }
    });

    test('is written in Ecuadorian Spanish, never voseo', () {
      // Dart's `\b` is ASCII-only, so it fires INSIDE accented words
      // ("pedírtela" would match a bare `pedí\b`). The boundaries below are
      // spelled out with the accented letters included, or this test reports
      // voseo that is not there.
      const letter = 'A-Za-zÁÉÍÓÚÜÑáéíóúüñ';
      final voseo = RegExp(
        '(?<![$letter])('
        'vos|tenés|podés|querés|hacés|sabés|debés|ponés|'
        'decime|mirá|revisá|configurá|entrá|probá|fijate|escribí|'
        'volvé|pedí|generá|corregí|esperá|avisá|conectate|acordate'
        ')(?![$letter])',
        caseSensitive: false,
      );
      for (final cause in LoginFailureCause.values) {
        final message = loginFailureMessageFor(cause);
        final text = '${message.title} ${message.guidance}';
        expect(
          voseo.hasMatch(text),
          isFalse,
          reason: '${cause.name} uses voseo: "$text"',
        );
      }
    });

    test('grades severity: what you can fix vs. what needs an administrator', () {
      // The transient/self-serve failures must not shout in the same red as
      // the ones that need somebody else to move.
      for (final cause in [
        LoginFailureCause.noNetwork,
        LoginFailureCause.serverNotResponding,
        LoginFailureCause.serverUnreachable,
        LoginFailureCause.timeout,
        LoginFailureCause.incompleteForm,
        LoginFailureCause.sessionExpired,
      ]) {
        expect(
          loginFailureMessageFor(cause).severity,
          NotificationSeverity.attention,
          reason: '${cause.name} should not be styled as a hard error.',
        );
      }
      for (final cause in [
        LoginFailureCause.invalidCredentials,
        LoginFailureCause.credentialIssueFailed,
        LoginFailureCause.accessDenied,
        LoginFailureCause.incompatibleServer,
        LoginFailureCause.serverError,
      ]) {
        expect(
          loginFailureMessageFor(cause).severity,
          NotificationSeverity.error,
          reason: '${cause.name} needs the hard-error treatment.',
        );
      }
    });
  });

  group('the message survives the trip through AuthViewState.message', () {
    test('every cause flattens and decodes back to itself', () {
      for (final cause in LoginFailureCause.values) {
        final original = loginFailureMessageFor(cause);
        final decoded = decodeLoginFailureMessage(original.flatten());
        expect(decoded, isNotNull, reason: '${cause.name} did not survive');
        expect(decoded!.cause, cause);
        expect(decoded.title, original.title);
        expect(decoded.guidance, original.guidance);
        expect(decoded.severity, original.severity);
      }
    });

    test('the flat form is still readable on its own', () {
      final flat = describeLoginFailure(
        const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        ),
      ).flatten();
      expect(flat, contains('No se pudo crear la clave de acceso'));
      expect(flat, contains('no es una contraseña equivocada'));
    });

    test('hand-written controller messages are left alone, not mislabelled', () {
      // These are the sentences AuthNotifier still writes by hand. Decoding
      // must return null so the form prints them as-is instead of dressing
      // them up as a classified cause.
      for (final message in [
        'El modo API key no está configurado en esta plataforma.',
        'El acceso web con contraseña está pendiente de W01.',
        'Este usuario no tiene acceso de vendedor por PIN.',
        'No se pudo restaurar la sesión.',
      ]) {
        expect(decodeLoginFailureMessage(message), isNull);
      }
      expect(decodeLoginFailureMessage(null), isNull);
      expect(decodeLoginFailureMessage(''), isNull);
      expect(decodeLoginFailureMessage('Un titular\ny un texto inventado'), isNull);
    });
  });

  _restoreAndUnknownGroups();

  group('connectivity splits "could not connect" into two different remedies', () {
    const unreachable = NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.connection,
    );

    test('no transport at all -> it is the device, and it says so', () {
      final refined = refineConnectionFailure(
        describeLoginFailure(unreachable),
        false,
      );
      expect(refined.cause, LoginFailureCause.noNetwork);
      expect(refined.guidance, contains('no hay wifi ni datos'));
      // And it clears the person of the two things they would otherwise
      // start re-checking.
      expect(refined.guidance, contains('no es un problema del servidor'));
    });

    test('a transport is up -> it is the server, and it says so', () {
      final refined = refineConnectionFailure(
        describeLoginFailure(unreachable),
        true,
      );
      expect(refined.cause, LoginFailureCause.serverNotResponding);
      expect(refined.title, contains('el servidor no responde'));
    });

    test('probe unavailable -> stays honest instead of guessing a side', () {
      final refined = refineConnectionFailure(
        describeLoginFailure(unreachable),
        null,
      );
      expect(refined.cause, LoginFailureCause.serverUnreachable);
    });

    test('refinement never touches a failure that is not a connection one', () {
      for (final hasNetwork in [true, false, null]) {
        final refined = refineConnectionFailure(
          describeLoginFailure(
            const NativeAuthBootstrapException(
              NativeAuthBootstrapFailureKind.invalidCredentials,
            ),
          ),
          hasNetwork,
        );
        expect(refined.cause, LoginFailureCause.invalidCredentials);
      }
    });
  });
}

/// Fails every call the way `NativeAuthService` does: it rolls back its own
/// side effects and RETHROWS the kit's typed exception.
final class _ThrowingAuthService implements AuthServicePort {
  _ThrowingAuthService(this.error);
  final Object error;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => throw error;
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      throw error;
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) async =>
      null;
  @override
  Future<void> close() async {}
}

void _restoreAndUnknownGroups() {
  group('restoring a session re-words what nobody typed', () {
    // The same flattening the login path had, in the OTHER two catch blocks
    // of AuthNotifier: "No se pudo restaurar la sesión." said nothing about
    // whether to wait for the wifi, sign in again, or call an administrator.
    test('a rejected stored credential is reported as an expired session', () {
      // Nobody typed anything, so "el usuario o la contraseña no coinciden"
      // would send the person hunting for a typo they never made.
      for (final error in <Object>[
        const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.invalidCredentials,
        ),
        const OdooAuthenticationException('unauthorized'),
        StateError('API key belongs to another Odoo user'),
      ]) {
        final message = describeSessionRestoreFailure(error);
        expect(message.cause, LoginFailureCause.sessionExpired);
        expect(message.guidance, contains('Escribe tu usuario y contraseña'));
      }
    });

    test('a network problem keeps its own wording, not the session one', () {
      expect(
        describeSessionRestoreFailure(
          const OdooConnectionException(),
        ).cause,
        LoginFailureCause.serverUnreachable,
      );
      expect(
        describeSessionRestoreFailure(const OdooTimeoutException()).cause,
        LoginFailureCause.timeout,
      );
    });

    test('a permission problem still points at the administrator', () {
      final message = describeSessionRestoreFailure(
        const OdooAccessDeniedException('forbidden'),
      );
      expect(message.cause, LoginFailureCause.accessDenied);
      expect(message.guidance.toLowerCase(), contains('administrador'));
    });

    test('causes that cannot happen while restoring are not invented', () {
      // Nothing was typed, so there is no incomplete form; and restoring
      // never mints a credential, so the web-password gap cannot apply.
      for (final error in <Object>[
        ArgumentError('server, database, login and apiKey are required'),
        const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.unsupportedPlatform,
        ),
      ]) {
        expect(
          describeSessionRestoreFailure(error).cause,
          LoginFailureCause.unknown,
        );
      }
    });

    test('AuthNotifier.restore actually reports the cause now', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            _ThrowingAuthService(const OdooTimeoutException()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(authControllerProvider.notifier);
      return notifier.restore().then((_) {
        final state = container.read(authControllerProvider);
        expect(state.status, AuthControllerStatus.error);
        expect(
          state.message,
          loginFailureMessageFor(LoginFailureCause.timeout).flatten(),
        );
        expect(state.message, isNot(contains('No se pudo restaurar')));
      });
    });

    test('AuthNotifier.restoreForSellerPin reports it too', () {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(
            _ThrowingAuthService(const OdooConnectionException()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(authControllerProvider.notifier);
      return notifier.restoreForSellerPin().then((_) {
        final state = container.read(authControllerProvider);
        expect(
          state.message,
          loginFailureMessageFor(LoginFailureCause.serverUnreachable).flatten(),
        );
        // And it still says nothing about the PIN, which would be a hint
        // about which PINs exist.
        expect(state.message!.toLowerCase(), isNot(contains('pin')));
      });
    });
  });

  group('the connectivity probe is inert until a real device supplies one', () {
    test('the default provider answers "I do not know", never a platform call', () {
      // A live default would await a platform channel that never completes
      // inside a widget test's fake-async zone — the exact deadlock the
      // offline-unlock work already paid for once. This must resolve, and it
      // must resolve to null.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container
          .read(networkPresenceProbeProvider)()
          .timeout(const Duration(seconds: 2))
          .then((answer) => expect(answer, isNull));
    });

    test('and "I do not know" keeps the ambiguous message', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container.read(networkPresenceProbeProvider)().then((answer) {
        final refined = refineConnectionFailure(
          describeLoginFailure(
            const NativeAuthBootstrapException(
              NativeAuthBootstrapFailureKind.connection,
            ),
          ),
          answer,
        );
        expect(refined.cause, LoginFailureCause.serverUnreachable);
      });
    });
  });
}
