/// Linux-only [CredentialBackend]: a runtime fallback, not a platform
/// switch — see
/// `docs/orbi_panel/decisions/C01-credencial-en-archivo-cifrado.md` §8.6.
///
/// Unlike macOS (§4: the native Keychain fails unconditionally, so the whole
/// platform is switched to the encrypted file at compile time), Linux's
/// `libsecret` backend works today for the majority of desktops that have
/// `gnome-keyring` or `kwallet` running. Only a minority — a terminal with no
/// desktop session, a server, a container — has no secret service to answer
/// at all (§7). Routing every Linux install through the encrypted file the
/// way macOS is routed would break the unattended reconnect that works today
/// for that majority: this backend tries the native store first and only
/// falls back when it fails, never as a blanket replacement.
///
/// ## Why the fallback is scoped to two exact error codes, not "any exception"
///
/// §7 already identified the two `PlatformException` codes
/// `flutter_secure_storage_linux` raises when there is genuinely no secret
/// service to answer: `"Libsecret error"` (the generic D-Bus connection
/// failure) and `"KeyringLocked"` (a collection exists but nothing could
/// unlock it). Falling back on *any* exception would also swallow a bad file
/// permission or a full disk behind the same silent path — exactly the kind
/// of quiet degradation this project has already been bitten by twice
/// tonight (the offline unlock going dark on macOS, and the web session
/// giving up without a word). An error this backend does not recognise is
/// **rethrown**, not absorbed: it must fail loudly, the same as it would
/// without this backend in front of it.
library;

import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import 'credential_store.dart'
    show
        CredentialBackend,
        FlutterSecureCredentialBackend,
        LatePasswordCredentialBackend;
import 'encrypted_file_credential_backend.dart';

const Set<String> _knownSecretServiceFailureCodes = {
  'Libsecret error',
  'KeyringLocked',
};

/// Wraps a native [CredentialBackend] (`libsecret` via
/// `FlutterSecureCredentialBackend` by default) and falls back to an
/// [EncryptedFileCredentialBackend] only when the native call fails with one
/// of the two known "no secret service available" codes.
///
/// The password behind the fallback is set late, exactly like
/// [EncryptedFileCredentialBackend]: this is constructed once at bootstrap,
/// before any operator has typed anything, so [password] starts unset — set
/// it with the freshly-typed password before a `write`/`read` that might
/// need the fallback. Most Linux sessions never touch it: the fallback only
/// asks for it the moment it actually fires.
final class LinuxSecretServiceFallbackCredentialBackend
    implements LatePasswordCredentialBackend {
  LinuxSecretServiceFallbackCredentialBackend({
    String? password,
    required Directory directory,
    CredentialBackend? native,
    CredentialBackend? fallback,
  }) : _native = native ?? FlutterSecureCredentialBackend(),
       _fallback =
           fallback ??
           EncryptedFileCredentialBackend(
             directory: directory,
             password: password,
           );

  final CredentialBackend _native;
  final CredentialBackend _fallback;

  /// Forwards to the underlying [EncryptedFileCredentialBackend]'s own
  /// late-bound password, when the fallback is that concrete type (always
  /// true outside of tests, which may inject a fake that ignores this).
  @override
  set password(String? value) {
    final fallback = _fallback;
    if (fallback is EncryptedFileCredentialBackend) {
      fallback.password = value;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _native.write(key, value);
    } on PlatformException catch (error) {
      if (!_isKnownFailure(error)) rethrow;
      _reportFallback('write', error);
      await _fallback.write(key, value);
      return;
    }
    // Native just succeeded: drop any stale copy the fallback might be
    // holding from an earlier outage, so a *later* transient native failure
    // can never resurrect an old value instead of reporting "nothing here".
    await _fallback.delete(key);
  }

  @override
  Future<String?> read(String key) async {
    try {
      final value = await _native.read(key);
      if (value != null) return value;
      // Native answered "nothing here" — legitimately true most of the
      // time, but also what native says right after a write that had to
      // land in the fallback during an earlier outage. Check the fallback
      // before reporting "nothing" ourselves.
      return await _fallback.read(key);
    } on PlatformException catch (error) {
      if (!_isKnownFailure(error)) rethrow;
      _reportFallback('read', error);
      return _fallback.read(key);
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _native.delete(key);
    } on PlatformException catch (error) {
      if (!_isKnownFailure(error)) rethrow;
      _reportFallback('delete', error);
    }
    // Whether or not native had anything to delete, also clear the
    // fallback: an orphaned copy on either side outlives the identity it
    // belonged to, which is worse than one extra no-op delete.
    await _fallback.delete(key);
  }

  bool _isKnownFailure(PlatformException error) =>
      _knownSecretServiceFailureCodes.contains(error.code);

  /// Leaves a trace every time the fallback actually fires — the third piece
  /// of this design, and not optional: a fallback nobody hears about is the
  /// same silent-degradation bug this backend exists to stop repeating.
  /// Never the key, the value, or anything that could identify the
  /// credential — only that libsecret failed, with which error code.
  void _reportFallback(String operation, PlatformException error) {
    logger.w(
      '[LinuxSecretServiceFallback]',
      'El servicio de secretos de Linux (libsecret) no respondió durante '
          '"$operation" (código: ${error.code}). Se usó el archivo cifrado '
          'de respaldo para esta operación.',
    );
  }
}
