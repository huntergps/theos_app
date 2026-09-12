import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show ConnectivityMonitor, NotificationSeverity;

/// Every login failure this app can tell apart FROM THE CLIENT SIDE.
///
/// The list is deliberately shorter than the exception hierarchy it is built
/// from: two server errors that arrive here as the same exception are ONE
/// cause, not two, because guessing which of them happened would put a
/// confident wrong instruction in front of someone at a counter. Where the
/// kit genuinely cannot separate two situations (a wrong password from an
/// unknown user, for one — see [invalidCredentials]) the message says the
/// honest ambiguous thing.
enum LoginFailureCause {
  /// The form was submitted without everything the server needs.
  incompleteForm,

  /// The server rejected the identity. It NEVER says whether the user exists:
  /// that answer is free reconnaissance for whoever is trying logins.
  invalidCredentials,

  /// The password was accepted and the account then asked for a second step
  /// (2FA / OTP) that this app cannot present yet.
  additionalVerificationRequired,

  /// The server understood who is knocking and refused to open.
  accessDenied,

  /// 🔴 The case the owner will hit and that used to be invisible.
  ///
  /// Signing in is TWO operations, not one: prove the password, then ask the
  /// server to mint an API key for this device (see
  /// `native_auth_bootstrap_io.dart` — `res.users.apikeys.description`
  /// create + make_key). When the second one fails the symptom on screen used
  /// to be identical to a bad password, and the remedy is the opposite:
  /// nothing the person types will ever fix it.
  ///
  /// A wrong password can never produce this cause — it fails at the first
  /// operation, as [invalidCredentials] — which is exactly what makes the
  /// distinction safe to state out loud.
  credentialIssueFailed,

  /// The pasted API key does not belong to the typed user, or is dead.
  apiKeyRejected,

  /// The saved environment's address is not https.
  insecureAddress,

  /// Measured, not assumed: connectivity reported no transport at all.
  noNetwork,

  /// Measured, not assumed: the device has a transport and the server still
  /// did not answer.
  serverNotResponding,

  /// The connection failed and connectivity could not be consulted, so which
  /// side is at fault is genuinely unknown. Says so.
  serverUnreachable,

  /// The server answered too late.
  timeout,

  /// The server broke on its own (5xx).
  serverError,

  /// A stored session is no longer valid.
  sessionExpired,

  /// The server does not expose a model/field/method this app needs.
  incompatibleServer,

  /// Password login is not available on this platform (web).
  passwordLoginUnsupportedHere,

  /// 🔴 The sign-in attempt never left the device.
  ///
  /// Measured in the browser against ERP2: pressing "Iniciar sesión" produced
  /// ZERO network requests, zero console errors and zero words on screen —
  /// the password field just cleared itself. The cause was a service whose
  /// `login()` returned `AuthServiceStatus.required` without touching the
  /// network, and `required` carries no message, so the form had nothing to
  /// say and said nothing.
  ///
  /// Failing silently is worse than failing: the person cannot tell a wrong
  /// password from an app that never tried. This cause exists so that no path
  /// can ever end in silence again, even one nobody anticipated.
  loginNotAttempted,

  /// The server is refusing further attempts for now (HTTP 429). Says nothing
  /// about whether the credential was right, which is why a stored one must
  /// NOT be discarded on it.
  tooManyAttempts,

  /// Nothing above matched. Never dressed up as something more specific.
  unknown,
}

/// What the person reads: what happened, and what to do about it.
///
/// Both halves are plain counter Spanish. Neither ever carries a status code,
/// an exception name, a stack trace or a server payload — explaining is not
/// dumping.
final class LoginFailureMessage {
  const LoginFailureMessage({
    required this.cause,
    required this.title,
    required this.guidance,
    required this.severity,
  });

  final LoginFailureCause cause;

  /// One short line: what happened.
  final String title;

  /// One or two lines: what to do next.
  final String guidance;

  /// Reuses the notification vocabulary (`orbi_runtime`) so the form's error
  /// panel is toned by the same scale the notification centre uses, instead
  /// of inventing a private one. [NotificationSeverity.attention] is for the
  /// failures that usually clear on their own or with one action from the
  /// person; [NotificationSeverity.error] is for the ones that need someone
  /// else (an administrator) to move.
  final NotificationSeverity severity;

  /// The single string an [AuthViewState.message] can carry.
  ///
  /// Lossless on purpose: [decodeLoginFailureMessage] recovers the whole
  /// object from it, so the screen can lay out the two halves separately and
  /// pick the panel's tone, while anything that only knows how to print a
  /// String still shows something a person can read.
  String flatten() => '$title\n$guidance';

  @override
  String toString() => 'LoginFailureMessage(${cause.name})';
}

const Map<LoginFailureCause, LoginFailureMessage> _messages = {
  LoginFailureCause.incompleteForm: LoginFailureMessage(
    cause: LoginFailureCause.incompleteForm,
    title: 'Faltan datos para entrar',
    guidance:
        'Revisa que hayas elegido un servidor en la lista y que el usuario y '
        'la clave estén completos.',
    severity: NotificationSeverity.attention,
  ),
  LoginFailureCause.invalidCredentials: LoginFailureMessage(
    cause: LoginFailureCause.invalidCredentials,
    title: 'El usuario o la contraseña no coinciden',
    guidance:
        'Vuelve a escribirlos con calma: fíjate en las mayúsculas y en que no '
        'haya quedado un espacio al final. Si no recuerdas la contraseña, '
        'pide a tu administrador que te la restablezca.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.additionalVerificationRequired: LoginFailureMessage(
    cause: LoginFailureCause.additionalVerificationRequired,
    title: 'Tu cuenta pide un paso de verificación más',
    guidance:
        'Esta cuenta tiene verificación en dos pasos y la aplicación todavía '
        'no sabe pedírtela. Genera una API key desde tu perfil en Odoo y '
        'entra con la opción «Usar API key».',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.accessDenied: LoginFailureMessage(
    cause: LoginFailureCause.accessDenied,
    title: 'El servidor no autorizó a esta cuenta',
    guidance:
        'Los datos llegaron bien, pero el servidor no le permite entrar a '
        'esta cuenta. Pide a tu administrador que revise los permisos de tu '
        'usuario en este entorno.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.credentialIssueFailed: LoginFailureMessage(
    cause: LoginFailureCause.credentialIssueFailed,
    title: 'No se pudo crear la clave de acceso de este dispositivo',
    guidance:
        'Esto no es una contraseña equivocada. El servidor no entregó la '
        'clave que la aplicación necesita para quedarse conectada. Vuelve a '
        'intentarlo; si sigue igual, pide a tu administrador que revise si tu '
        'usuario puede crear claves de API.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.apiKeyRejected: LoginFailureMessage(
    cause: LoginFailureCause.apiKeyRejected,
    title: 'Esa API key no sirve para este usuario',
    guidance:
        'La clave no corresponde al usuario que escribiste, o ya no está '
        'activa. Genera una nueva desde tu perfil en Odoo y pégala otra vez.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.insecureAddress: LoginFailureMessage(
    cause: LoginFailureCause.insecureAddress,
    title: 'La dirección de este servidor no es segura',
    guidance:
        'Orbi sólo se conecta por https. Abre «Gestionar servidores…» y '
        'corrige la dirección de este entorno.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.noNetwork: LoginFailureMessage(
    cause: LoginFailureCause.noNetwork,
    title: 'Tu dispositivo no tiene conexión a internet',
    guidance:
        'Ahora mismo no hay wifi ni datos móviles. Conéctate a una red y '
        'vuelve a intentarlo: no es un problema del servidor ni de tu '
        'contraseña.',
    severity: NotificationSeverity.attention,
  ),
  LoginFailureCause.serverNotResponding: LoginFailureMessage(
    cause: LoginFailureCause.serverNotResponding,
    title: 'Tu conexión está bien, pero el servidor no responde',
    guidance:
        'Este dispositivo sí tiene internet, así que el problema está en el '
        'servidor o en la dirección del entorno. Revísala en «Gestionar '
        'servidores…» y avisa a tu administrador si sigue caído.',
    severity: NotificationSeverity.attention,
  ),
  LoginFailureCause.serverUnreachable: LoginFailureMessage(
    cause: LoginFailureCause.serverUnreachable,
    title: 'No se pudo conectar con el servidor',
    guidance:
        'Revisa tu conexión a internet y que la dirección del entorno sea la '
        'correcta. Si tu conexión está bien, es el servidor el que no está '
        'respondiendo.',
    severity: NotificationSeverity.attention,
  ),
  LoginFailureCause.timeout: LoginFailureMessage(
    cause: LoginFailureCause.timeout,
    title: 'El servidor tardó demasiado en responder',
    guidance:
        'La conexión está muy lenta o el servidor está cargado. Espera un '
        'momento y vuelve a intentarlo.',
    severity: NotificationSeverity.attention,
  ),
  LoginFailureCause.serverError: LoginFailureMessage(
    cause: LoginFailureCause.serverError,
    title: 'El servidor tuvo un problema interno',
    guidance:
        'No es algo que puedas corregir desde aquí. Vuelve a intentarlo en '
        'unos minutos y, si sigue igual, avisa a tu administrador.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.sessionExpired: LoginFailureMessage(
    cause: LoginFailureCause.sessionExpired,
    title: 'Tu sesión caducó',
    guidance:
        'Por seguridad, el servidor cerró la sesión anterior. Escribe tu '
        'usuario y contraseña otra vez para continuar.',
    severity: NotificationSeverity.attention,
  ),
  LoginFailureCause.incompatibleServer: LoginFailureMessage(
    cause: LoginFailureCause.incompatibleServer,
    title: 'Este servidor no tiene lo que la aplicación necesita',
    guidance:
        'La versión del servidor no coincide con la que espera esta '
        'aplicación. Avisa a tu administrador: no es algo que se arregle '
        'desde esta pantalla.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.passwordLoginUnsupportedHere: LoginFailureMessage(
    cause: LoginFailureCause.passwordLoginUnsupportedHere,
    title: 'Aquí todavía no se puede entrar con contraseña',
    guidance:
        'Desde el navegador se entra con API key. Genera la tuya desde tu '
        'perfil en Odoo y activa la opción «Usar API key».',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.loginNotAttempted: LoginFailureMessage(
    cause: LoginFailureCause.loginNotAttempted,
    title: 'La aplicación no llegó a intentar el acceso',
    guidance:
        'No se envió nada al servidor, así que esto no dice nada sobre tu '
        'contraseña. Si estás en el navegador, entra con la opción «Usar API '
        'key» mientras tanto, y avisa a tu administrador de que el acceso con '
        'contraseña no está llegando al servidor.',
    severity: NotificationSeverity.error,
  ),
  LoginFailureCause.tooManyAttempts: LoginFailureMessage(
    cause: LoginFailureCause.tooManyAttempts,
    title: 'Demasiados intentos seguidos',
    guidance:
        'Por seguridad, el servidor no acepta más intentos desde aquí durante '
        'unos minutos. Espera un momento antes de volver a probar: seguir '
        'intentando alarga la espera.',
    severity: NotificationSeverity.attention,
  ),
  LoginFailureCause.unknown: LoginFailureMessage(
    cause: LoginFailureCause.unknown,
    title: 'No se pudo iniciar sesión',
    guidance:
        'Vuelve a intentarlo. Si el problema continúa, avisa a tu '
        'administrador e indícale la hora exacta en que ocurrió.',
    severity: NotificationSeverity.error,
  ),
};

/// The reader for [LoginFailureCause] → text. Pure, total, and the single
/// place these strings exist.
LoginFailureMessage loginFailureMessageFor(LoginFailureCause cause) =>
    _messages[cause]!;

/// Pure classifier: exception → the one cause we can honestly claim.
///
/// Order matters — the most specific subclass must be tested before its
/// parent, or `OdooSessionExpiredException` would be read as a plain
/// authentication failure and `OdooServerException` as a nameless
/// `OdooException`.
LoginFailureCause classifyLoginFailure(Object error) {
  if (error is NativeAuthBootstrapException) {
    return switch (error.kind) {
      NativeAuthBootstrapFailureKind.unsupportedPlatform =>
        LoginFailureCause.passwordLoginUnsupportedHere,
      NativeAuthBootstrapFailureKind.insecureTransport =>
        LoginFailureCause.insecureAddress,
      NativeAuthBootstrapFailureKind.invalidCredentials =>
        LoginFailureCause.invalidCredentials,
      NativeAuthBootstrapFailureKind.additionalVerificationRequired =>
        LoginFailureCause.additionalVerificationRequired,
      NativeAuthBootstrapFailureKind.accessDenied =>
        LoginFailureCause.accessDenied,
      // `protocol` is only ever raised AFTER the password was accepted and
      // the identity re-checked, while minting this device's API key — see
      // the doc on [LoginFailureCause.credentialIssueFailed].
      NativeAuthBootstrapFailureKind.protocol =>
        LoginFailureCause.credentialIssueFailed,
      NativeAuthBootstrapFailureKind.connection =>
        LoginFailureCause.serverUnreachable,
    };
  }
  if (error is OdooSessionExpiredException) {
    return LoginFailureCause.sessionExpired;
  }
  if (error is OdooAuthenticationException) {
    return LoginFailureCause.invalidCredentials;
  }
  if (error is OdooAccessDeniedException) return LoginFailureCause.accessDenied;
  if (error is OdooMethodNotFoundException ||
      error is OdooFieldNotFoundException ||
      error is OdooNotFoundException) {
    return LoginFailureCause.incompatibleServer;
  }
  if (error is OdooTimeoutException) return LoginFailureCause.timeout;
  if (error is OdooConnectionException || error is OdooOfflineException) {
    return LoginFailureCause.serverUnreachable;
  }
  if (error is OdooServerException) return LoginFailureCause.serverError;
  if (error is OdooValidationException) return LoginFailureCause.incompleteForm;
  if (error is OdooException) {
    if (error.statusCode >= 500) return LoginFailureCause.serverError;
    if (error.statusCode == 401) return LoginFailureCause.invalidCredentials;
    if (error.statusCode == 403) return LoginFailureCause.accessDenied;
    return LoginFailureCause.unknown;
  }
  if (error is TimeoutException) return LoginFailureCause.timeout;
  if (error is ArgumentError) return LoginFailureCause.incompleteForm;
  if (error is StateError) {
    // NativeAuthService's API-key path is the only one that reports a bad key
    // as a StateError, and it always names it. Every other StateError in the
    // runtime (an inactive scope, a missing session runtime) is a defect on
    // our side, not something to blame on the person's key.
    if (error.message.contains('API key')) {
      return LoginFailureCause.apiKeyRejected;
    }
    return LoginFailureCause.unknown;
  }
  // Socket/TLS failures are matched by name rather than by type: this file is
  // compiled for the web too, where `dart:io` does not exist.
  const networkTypeNames = {
    'SocketException',
    'HandshakeException',
    'HttpException',
    'TlsException',
    'ClientException',
  };
  if (networkTypeNames.contains(error.runtimeType.toString())) {
    return LoginFailureCause.serverUnreachable;
  }
  return LoginFailureCause.unknown;
}

/// The whole job in one call: exception → what the person reads.
LoginFailureMessage describeLoginFailure(Object error) =>
    loginFailureMessageFor(classifyLoginFailure(error));

/// The same job for a session that is being RESTORED rather than typed.
///
/// The classification is identical — it is the same kit raising the same
/// exceptions — but three of the texts would be lies here, because nobody
/// typed anything: telling someone "el usuario o la contraseña no coinciden"
/// when they only reopened the app sends them hunting for a typo they never
/// made. What actually happened is that the credential this device was
/// holding stopped being accepted, and the remedy is to sign in again.
///
/// The two causes that cannot occur while restoring (an incomplete form, and
/// web-password support) are reported as [LoginFailureCause.unknown] rather
/// than dressed up as something they are not.
LoginFailureMessage describeSessionRestoreFailure(Object error) {
  final cause = classifyLoginFailure(error);
  return loginFailureMessageFor(switch (cause) {
    LoginFailureCause.invalidCredentials ||
    LoginFailureCause.apiKeyRejected ||
    LoginFailureCause.credentialIssueFailed ||
    LoginFailureCause.sessionExpired => LoginFailureCause.sessionExpired,
    LoginFailureCause.incompleteForm ||
    LoginFailureCause.passwordLoginUnsupportedHere ||
    LoginFailureCause.loginNotAttempted => LoginFailureCause.unknown,
    _ => cause,
  });
}

/// Recovers the structured message from the flat string carried by
/// `AuthViewState.message`.
///
/// Returns null for any other text — messages the auth controller writes by
/// hand — so the caller can fall back to printing it as-is instead of
/// mislabelling it.
LoginFailureMessage? decodeLoginFailureMessage(String? message) {
  if (message == null) return null;
  final split = message.indexOf('\n');
  if (split <= 0) return null;
  final title = message.substring(0, split);
  final guidance = message.substring(split + 1);
  for (final candidate in _messages.values) {
    if (candidate.title == title && candidate.guidance == guidance) {
      return candidate;
    }
  }
  return null;
}

/// Answers one question and nothing else: does this device currently have a
/// network transport?
///
/// Deliberately a tri-state and not a health check. `true`/`false` is what
/// connectivity observed about the DEVICE — never proof that the server is
/// up, which is exactly the distinction this exists to draw — and `null`
/// means the question could not be asked at all, which
/// [refineConnectionFailure] reports as "we do not know" rather than guessing
/// a side.
typedef NetworkPresenceProbe = Future<bool?> Function();

/// **Inert by default, and the composition root supplies the real one** — the
/// same shape `workspaceUnlockBackendProvider`, `sharedPreferencesProvider`
/// and `authServiceProvider` already use in this app.
///
/// The default answers "I do not know", which costs nothing: the ambiguous
/// [LoginFailureCause.serverUnreachable] message stands, exactly the
/// behaviour there was before this refinement existed.
///
/// It must NOT default to the live monitor, and not for tidiness: a
/// plugin-backed platform channel never completes inside a widget test's
/// fake-async zone. `_refineLastFailure` awaits this probe on the login
/// screen, so a live default would deadlock any widget test that drives a
/// failed sign-in over a broken connection without overriding it —
/// `pumpAndSettle` would sit there for its entire ten-minute budget. The
/// offline-unlock work already paid for that lesson once; see the note on
/// `workspaceUnlockBackendProvider`.
final networkPresenceProbeProvider = Provider<NetworkPresenceProbe>(
  (ref) => () async => null,
);

/// The override `bootstrap.dart` registers so a real device can actually tell
/// "no hay red" from "el servidor no responde".
///
/// Wraps `ConnectivityMonitor` (`connectivity_plus`, already a declared
/// dependency of `orbi_runtime`, reached through its adapter so this package
/// needs no new dependency). A monitor that throws — no plugin on this
/// platform — answers `null`, which keeps the honest ambiguous message
/// instead of turning a missing plugin into a claim about the person's wifi.
// Declared as an inferred `final` rather than a named override type, so this
// file never has to spell a Riverpod internal type name.
final networkPresenceProbeOverride = networkPresenceProbeProvider
    .overrideWithValue(() async {
      try {
        return (await ConnectivityMonitor().check()).hasNetwork;
      } catch (_) {
        return null;
      }
    });

/// Splits the ambiguous "could not connect" into a measured answer.
///
/// [hasNetwork] is what the probe actually observed; a null means the probe
/// could not be consulted, and then the ambiguous message stands. We never
/// guess which side failed.
LoginFailureMessage refineConnectionFailure(
  LoginFailureMessage failure,
  bool? hasNetwork,
) {
  if (failure.cause != LoginFailureCause.serverUnreachable) return failure;
  if (hasNetwork == null) return failure;
  return loginFailureMessageFor(
    hasNetwork
        ? LoginFailureCause.serverNotResponding
        : LoginFailureCause.noNetwork,
  );
}
