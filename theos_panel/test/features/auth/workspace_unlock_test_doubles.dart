import 'package:orbi_runtime/orbi_runtime.dart';

/// In-memory stand-in for the operating system's secure store.
///
/// A test host has no `flutter_secure_storage` plugin, so every test that
/// needs the workspace unlock derivation overrides
/// `workspaceUnlockBackendProvider` with this. [entries] is exposed on purpose:
/// the rule "never store the password" is only worth asserting against what
/// actually reached storage, keys included.
final class FakeCredentialBackend implements CredentialBackend {
  final Map<String, String> entries = {};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<void> delete(String key) async => entries.remove(key);
}

/// A secure store that refuses everything — a locked Keychain, a missing
/// plugin, a platform channel that is not there. Nothing in the app may break
/// because of it; unlocking simply falls back to requiring the network.
final class ThrowingCredentialBackend implements CredentialBackend {
  @override
  Future<String?> read(String key) async =>
      throw StateError('secure store unavailable');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('secure store unavailable');

  @override
  Future<void> delete(String key) async =>
      throw StateError('secure store unavailable');
}
