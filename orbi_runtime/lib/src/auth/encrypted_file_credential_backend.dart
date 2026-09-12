/// [CredentialBackend] backed by a password-derived encrypted file — see
/// `docs/orbi_panel/decisions/C01-credencial-en-archivo-cifrado.md` §8 for
/// the full history and §8.6/§8.7 for the current scope.
///
/// **Not macOS-specific, not used there.** This was originally built to
/// replace [FlutterSecureCredentialBackend] on macOS while its Keychain
/// rejected every call (§4). That plan is cancelled: the dueño's "universal
/// package" request meant `flutter_secure_storage` itself, and macOS's real
/// fix is signing with a real Apple Developer team (configured — see §4),
/// not a bespoke file format. macOS uses [FlutterSecureCredentialBackend]
/// unconditionally, like every other platform.
///
/// The one place this still matters: it is the fallback storage inside
/// [LinuxSecretServiceFallbackCredentialBackend], used only the moment
/// `libsecret` genuinely has no secret service to answer. Nothing else in
/// this codebase should construct this class directly.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show compute;

import 'credential_store.dart' show LatePasswordCredentialBackend;
import 'encrypted_credential_envelope.dart';

/// Reads/writes one encrypted file per credential key inside [directory],
/// named after a hash of the key so the (already-obfuscated, see
/// `CredentialStore._key`) scope string never appears as a filename on disk.
///
/// ## The password is set late, deliberately
///
/// A composition root builds its [CredentialStore]/backend once, at
/// bootstrap — before any operator has typed anything. The operator's
/// password is only known later, inside whatever login call already has it
/// in scope. So [password] is **not** a constructor argument: it starts
/// unset, and the caller that owns the login flow must set the [password]
/// property with the freshly-typed password immediately before any
/// `write`/`read` that needs it. Calling either before a password has ever
/// been set throws [StateError] — loudly, not as a silently-empty read.
///
/// The password is held only until the next call to the setter replaces or
/// clears it (`password = null` when done with it) — never written
/// anywhere, never logged, and never captured by a closure that could
/// outlive this instance.
final class EncryptedFileCredentialBackend
    implements LatePasswordCredentialBackend {
  // `this._password` would make the parameter itself private, so it could
  // only ever be passed from within this exact file — the public name has
  // to stay `password`, distinct from the private field it seeds.
  EncryptedFileCredentialBackend({
    required this.directory,
    String? password,
    this.cost = const Argon2Cost(),
    // ignore: prefer_initializing_formals
  }) : _password = password;

  final Directory directory;
  final Argon2Cost cost;
  String? _password;

  /// Set this immediately before a `write`/`read` that needs it, with the
  /// password the operator just typed. Set it to `null` once done with it if
  /// the instance outlives that one operation, so it never lingers in memory
  /// longer than necessary.
  @override
  set password(String? value) => _password = value;

  /// Used by [write], where a missing password is a caller bug (write must
  /// only ever be called right after a login that already has one) and
  /// deserves a loud [StateError], never a silently-discarded credential.
  /// [read] guards `_password == null` itself before reaching here — see its
  /// comment for why a missing password there is not a bug.
  String get _requiredPassword {
    final password = _password;
    if (password == null) {
      throw StateError(
        'EncryptedFileCredentialBackend.write called before a password was '
        'set — the caller must set `password` with the operator\'s '
        'freshly-typed password first.',
      );
    }
    return password;
  }

  @override
  Future<void> write(String key, String value) async {
    final envelope = await compute(
      _sealInIsolate,
      _SealRequest(password: _requiredPassword, plainText: value, cost: cost),
    );
    await directory.create(recursive: true);
    await _fileFor(key).writeAsBytes(envelope.encode(), flush: true);
  }

  @override
  Future<String?> read(String key) async {
    // Unlike `write`, a missing password here is not a caller bug: the
    // unattended cold-start path (`restoreOnce`, called with nobody around
    // to type anything) is expected to call `read` before any password is
    // known on this platform. That path already treats a `null` result as
    // "nothing to restore, fall through to requiring login" — exactly
    // right, so this degrades into that instead of throwing through it.
    if (_password == null) return null;
    final file = _fileFor(key);
    if (!await file.exists()) return null;
    final Uint8List raw;
    try {
      raw = await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
    final EncryptedCredentialEnvelope envelope;
    try {
      envelope = EncryptedCredentialEnvelope.decode(raw);
    } on FormatException {
      // An unreadable payload is not a credential: nothing to recover from
      // a format this build cannot evaluate, and pretending otherwise would
      // be worse than reporting "nothing stored".
      return null;
    }
    return compute(
      _openInIsolate,
      _OpenRequest(password: _requiredPassword, envelope: envelope),
    );
  }

  @override
  Future<void> delete(String key) async {
    final file = _fileFor(key);
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // Nothing else to do: a delete that cannot complete must not throw
        // through a logout path that has to finish regardless.
      }
    }
  }

  File _fileFor(String key) {
    final digest = sha256.convert(utf8.encode(key)).toString();
    return File('${directory.path}/$digest.orbicred');
  }
}

/// Isolate entry points below: `compute()` requires a top-level or static
/// function plus a single argument, hence the small request records instead
/// of closures capturing `this`.

final class _SealRequest {
  const _SealRequest({
    required this.password,
    required this.plainText,
    required this.cost,
  });

  final String password;
  final String plainText;
  final Argon2Cost cost;
}

EncryptedCredentialEnvelope _sealInIsolate(_SealRequest request) =>
    EncryptedCredentialEnvelope.seal(
      request.password,
      request.plainText,
      cost: request.cost,
    );

final class _OpenRequest {
  const _OpenRequest({required this.password, required this.envelope});

  final String password;
  final EncryptedCredentialEnvelope envelope;
}

String? _openInIsolate(_OpenRequest request) =>
    request.envelope.open(request.password);
