import 'package:orbi_runtime/orbi_runtime.dart';

/// Native platforms: the operating system's own secure store — Keychain on
/// iOS/macOS, Keystore-backed `EncryptedSharedPreferences` on Android,
/// libsecret on Linux, DPAPI on Windows — through the same
/// [CredentialBackend] the runtime already uses for the Odoo API key.
CredentialBackend createUnlockCredentialBackend() =>
    FlutterSecureCredentialBackend();
