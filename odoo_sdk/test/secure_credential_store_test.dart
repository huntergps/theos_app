import 'dart:async';

import 'package:odoo_sdk/src/security/credential_guard.dart';
import 'package:odoo_sdk/src/security/secure_credential_store.dart';
import 'package:test/test.dart';

/// In-memory implementation of [SecureCredentialStore] for testing.
class InMemorySecureStore implements SecureCredentialStore {
  final Map<String, String> _data = {};

  @override
  Future<void> store(String key, String value) async => _data[key] = value;

  @override
  Future<String?> retrieve(String key) async => _data[key];

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  /// Test helper: returns an unmodifiable view of all stored data.
  Map<String, String> get allData => Map.unmodifiable(_data);
}

void main() {
  group('SecureCredentialStore (InMemorySecureStore)', () {
    late InMemorySecureStore store;

    setUp(() {
      store = InMemorySecureStore();
    });

    test('store and retrieve a credential', () async {
      await store.store('my_key', 'my_value');
      final result = await store.retrieve('my_key');
      expect(result, equals('my_value'));
    });

    test('retrieve returns null for missing key', () async {
      final result = await store.retrieve('nonexistent');
      expect(result, isNull);
    });

    test('store overwrites existing value', () async {
      await store.store('key', 'value1');
      await store.store('key', 'value2');
      final result = await store.retrieve('key');
      expect(result, equals('value2'));
    });

    test('delete removes a credential', () async {
      await store.store('key', 'value');
      await store.delete('key');
      final result = await store.retrieve('key');
      expect(result, isNull);
    });

    test('delete is no-op for missing key', () async {
      // Should not throw
      await store.delete('nonexistent');
    });

    test('deleteAll removes all credentials', () async {
      await store.store('key1', 'value1');
      await store.store('key2', 'value2');
      await store.store('key3', 'value3');

      await store.deleteAll();

      expect(await store.retrieve('key1'), isNull);
      expect(await store.retrieve('key2'), isNull);
      expect(await store.retrieve('key3'), isNull);
      expect(store.allData, isEmpty);
    });

    test('containsKey returns true for existing key', () async {
      await store.store('exists', 'yes');
      expect(await store.containsKey('exists'), isTrue);
    });

    test('containsKey returns false for missing key', () async {
      expect(await store.containsKey('missing'), isFalse);
    });

    test('containsKey returns false after delete', () async {
      await store.store('key', 'value');
      await store.delete('key');
      expect(await store.containsKey('key'), isFalse);
    });
  });

  group('CredentialKeys', () {
    test('constants have expected values', () {
      expect(CredentialKeys.apiKey, equals('odoo_api_key'));
      expect(CredentialKeys.sessionId, equals('odoo_session_id'));
      expect(CredentialKeys.sessionToken, equals('odoo_session_token'));
      expect(CredentialKeys.refreshToken, equals('odoo_refresh_token'));
    });

    test('scoped() generates correct prefixed key', () {
      final scoped = CredentialKeys.scoped('pos-store-1', 'odoo_api_key');
      expect(scoped, equals('pos-store-1:odoo_api_key'));
    });

    test('scoped() works with CredentialKeys constants', () {
      expect(
        CredentialKeys.scoped('ctx-1', CredentialKeys.apiKey),
        equals('ctx-1:odoo_api_key'),
      );
      expect(
        CredentialKeys.scoped('ctx-2', CredentialKeys.sessionId),
        equals('ctx-2:odoo_session_id'),
      );
    });

    test('scoped() handles empty contextId', () {
      expect(
        CredentialKeys.scoped('', CredentialKeys.apiKey),
        equals(':odoo_api_key'),
      );
    });

    test('scoped() handles special characters in contextId', () {
      expect(
        CredentialKeys.scoped('store/branch-1', CredentialKeys.apiKey),
        equals('store/branch-1:odoo_api_key'),
      );
    });
  });

  group('CredentialGuard', () {
    late InMemorySecureStore store;
    late CredentialGuard guard;

    setUp(() {
      store = InMemorySecureStore();
      guard = CredentialGuard(
        store: store,
        contextId: 'test-ctx',
        autoClearAfter: null, // Disable auto-clear for most tests
      );
    });

    tearDown(() {
      guard.dispose();
    });

    test('get() loads from store on first access', () async {
      // Pre-populate the store with a scoped key
      await store.store('test-ctx:odoo_api_key', 'key_abc123');

      final result = await guard.get(CredentialKeys.apiKey);
      expect(result, equals('key_abc123'));
    });

    test('get() returns cached value on subsequent access', () async {
      await store.store('test-ctx:odoo_api_key', 'key_abc123');

      // First access: loads from store
      final first = await guard.get(CredentialKeys.apiKey);
      expect(first, equals('key_abc123'));

      // Modify store directly (simulating external change)
      await store.store('test-ctx:odoo_api_key', 'key_changed');

      // Second access: returns cached value (not the updated store value)
      final second = await guard.get(CredentialKeys.apiKey);
      expect(second, equals('key_abc123'));
    });

    test('get() returns null for missing credential', () async {
      final result = await guard.get(CredentialKeys.apiKey);
      expect(result, isNull);
    });

    test('set() stores in both cache and store', () async {
      await guard.set(CredentialKeys.apiKey, 'key_new');

      // Verify in-memory cache
      expect(guard.hasCachedCredentials, isTrue);

      // Verify underlying store has the scoped key
      final storeValue = await store.retrieve('test-ctx:odoo_api_key');
      expect(storeValue, equals('key_new'));

      // Verify guard returns the value
      final guardValue = await guard.get(CredentialKeys.apiKey);
      expect(guardValue, equals('key_new'));
    });

    test('remove() deletes from both cache and store', () async {
      await guard.set(CredentialKeys.apiKey, 'key_to_remove');

      await guard.remove(CredentialKeys.apiKey);

      // Cache should be empty
      expect(guard.hasCachedCredentials, isFalse);

      // Store should be empty for this key
      final storeValue = await store.retrieve('test-ctx:odoo_api_key');
      expect(storeValue, isNull);

      // Guard should return null
      final guardValue = await guard.get(CredentialKeys.apiKey);
      expect(guardValue, isNull);
    });

    test('clearMemoryCache() clears cache but NOT store', () async {
      await guard.set(CredentialKeys.apiKey, 'key_persist');
      await guard.set(CredentialKeys.sessionId, 'session_123');

      guard.clearMemoryCache();

      // Cache should be empty
      expect(guard.hasCachedCredentials, isFalse);

      // Store should still have the values
      expect(
        await store.retrieve('test-ctx:odoo_api_key'),
        equals('key_persist'),
      );
      expect(
        await store.retrieve('test-ctx:odoo_session_id'),
        equals('session_123'),
      );
    });

    test('deleteAll() clears both cache and store', () async {
      await guard.set(CredentialKeys.apiKey, 'key_delete');
      await guard.set(CredentialKeys.sessionId, 'session_delete');

      await guard.deleteAll();

      // Cache should be empty
      expect(guard.hasCachedCredentials, isFalse);

      // Store should be empty for these keys
      expect(await store.retrieve('test-ctx:odoo_api_key'), isNull);
      expect(await store.retrieve('test-ctx:odoo_session_id'), isNull);
    });

    test('getApiKey() convenience method works', () async {
      await store.store('test-ctx:odoo_api_key', 'api_key_123');
      final result = await guard.getApiKey();
      expect(result, equals('api_key_123'));
    });

    test('setApiKey() convenience method works', () async {
      await guard.setApiKey('api_key_456');
      final result = await guard.getApiKey();
      expect(result, equals('api_key_456'));

      // Verify in store
      expect(
        await store.retrieve('test-ctx:odoo_api_key'),
        equals('api_key_456'),
      );
    });

    test('hasCachedCredentials reflects cache state', () async {
      expect(guard.hasCachedCredentials, isFalse);

      await guard.set(CredentialKeys.apiKey, 'value');
      expect(guard.hasCachedCredentials, isTrue);

      guard.clearMemoryCache();
      expect(guard.hasCachedCredentials, isFalse);
    });

    test('dispose() clears everything', () async {
      await guard.set(CredentialKeys.apiKey, 'value');
      await guard.set(CredentialKeys.sessionId, 'session');

      guard.dispose();

      expect(guard.hasCachedCredentials, isFalse);
    });

    test('contextId is accessible', () {
      expect(guard.contextId, equals('test-ctx'));
    });
  });

  group('CredentialGuard auto-clear', () {
    late InMemorySecureStore store;

    test('auto-clear timer is created when autoClearAfter is set', () async {
      store = InMemorySecureStore();
      final guard = CredentialGuard(
        store: store,
        contextId: 'timer-test',
        autoClearAfter: const Duration(milliseconds: 100),
      );

      await guard.set(CredentialKeys.apiKey, 'temporary');
      expect(guard.hasCachedCredentials, isTrue);

      // Wait for the auto-clear timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Cache should have been cleared by the timer
      expect(guard.hasCachedCredentials, isFalse);

      // But the store should still have the value
      expect(
        await store.retrieve('timer-test:odoo_api_key'),
        equals('temporary'),
      );

      guard.dispose();
    });

    test('auto-clear timer resets on each access', () async {
      store = InMemorySecureStore();
      final guard = CredentialGuard(
        store: store,
        contextId: 'timer-reset',
        autoClearAfter: const Duration(milliseconds: 150),
      );

      await guard.set(CredentialKeys.apiKey, 'resetme');

      // Access at 80ms to reset timer
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await guard.get(CredentialKeys.apiKey);

      // At 160ms total (80ms after reset), should still be cached
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(guard.hasCachedCredentials, isTrue);

      // Wait another 100ms (180ms after last reset), timer should have fired
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(guard.hasCachedCredentials, isFalse);

      guard.dispose();
    });

    test('no timer when autoClearAfter is null', () async {
      store = InMemorySecureStore();
      final guard = CredentialGuard(
        store: store,
        contextId: 'no-timer',
        autoClearAfter: null,
      );

      await guard.set(CredentialKeys.apiKey, 'persistent');

      // Wait well beyond any timer duration
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should still be cached
      expect(guard.hasCachedCredentials, isTrue);

      guard.dispose();
    });
  });

  group('CredentialGuard multi-context isolation', () {
    late InMemorySecureStore store;
    late CredentialGuard guardA;
    late CredentialGuard guardB;

    setUp(() {
      store = InMemorySecureStore();
      guardA = CredentialGuard(
        store: store,
        contextId: 'context-a',
        autoClearAfter: null,
      );
      guardB = CredentialGuard(
        store: store,
        contextId: 'context-b',
        autoClearAfter: null,
      );
    });

    tearDown(() {
      guardA.dispose();
      guardB.dispose();
    });

    test('two guards with different contextIds do not interfere', () async {
      await guardA.setApiKey('key_a');
      await guardB.setApiKey('key_b');

      expect(await guardA.getApiKey(), equals('key_a'));
      expect(await guardB.getApiKey(), equals('key_b'));
    });

    test('clearing one guard does not affect the other', () async {
      await guardA.setApiKey('key_a');
      await guardB.setApiKey('key_b');

      guardA.clearMemoryCache();

      // Guard A cache is cleared, but store still has the value
      expect(guardA.hasCachedCredentials, isFalse);

      // Guard B is unaffected
      expect(await guardB.getApiKey(), equals('key_b'));
      expect(guardB.hasCachedCredentials, isTrue);

      // Guard A can reload from store
      expect(await guardA.getApiKey(), equals('key_a'));
    });

    test('deleting from one guard does not affect the other', () async {
      await guardA.setApiKey('key_a');
      await guardB.setApiKey('key_b');

      await guardA.deleteAll();

      // Guard A is fully deleted
      expect(await guardA.getApiKey(), isNull);

      // Guard B is completely unaffected
      expect(await guardB.getApiKey(), equals('key_b'));
    });

    test('store contains separately scoped keys', () async {
      await guardA.setApiKey('key_a');
      await guardB.setApiKey('key_b');

      expect(
        store.allData,
        equals({
          'context-a:odoo_api_key': 'key_a',
          'context-b:odoo_api_key': 'key_b',
        }),
      );
    });
  });
}
