import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show CredentialKeys;
import 'package:theos_pos/core/security/security.dart';

void main() {
  group('EphemeralCredentialStore', () {
    test('stores, retrieves, and overwrites a credential', () async {
      final store = EphemeralCredentialStore();

      expect(await store.retrieve(CredentialKeys.apiKey), isNull);
      expect(await store.containsKey(CredentialKeys.apiKey), isFalse);

      await store.store(CredentialKeys.apiKey, 'first-secret');

      expect(
        await store.retrieve(CredentialKeys.apiKey),
        equals('first-secret'),
      );
      expect(await store.containsKey(CredentialKeys.apiKey), isTrue);

      await store.store(CredentialKeys.apiKey, 'replacement-secret');

      expect(
        await store.retrieve(CredentialKeys.apiKey),
        equals('replacement-secret'),
      );
    });

    test('delete removes only the requested credential', () async {
      final store = EphemeralCredentialStore();
      await store.store(CredentialKeys.apiKey, 'api-secret');
      await store.store(CredentialKeys.sessionToken, 'session-secret');

      await store.delete(CredentialKeys.apiKey);

      expect(await store.retrieve(CredentialKeys.apiKey), isNull);
      expect(await store.containsKey(CredentialKeys.apiKey), isFalse);
      expect(
        await store.retrieve(CredentialKeys.sessionToken),
        equals('session-secret'),
      );
    });

    test('deleteAll removes every credential in the instance', () async {
      final store = EphemeralCredentialStore();
      await store.store(CredentialKeys.apiKey, 'api-secret');
      await store.store(CredentialKeys.sessionToken, 'session-secret');
      await store.store(CredentialKeys.sessionToken, 'token-secret');

      await store.deleteAll();

      expect(await store.containsKey(CredentialKeys.apiKey), isFalse);
      expect(await store.containsKey(CredentialKeys.sessionToken), isFalse);
      expect(await store.containsKey(CredentialKeys.sessionToken), isFalse);
    });

    test('a new instance does not restore credentials', () async {
      final currentPageStore = EphemeralCredentialStore();
      await currentPageStore.store(CredentialKeys.apiKey, 'web-secret');

      final refreshedPageStore = EphemeralCredentialStore();

      expect(
        await currentPageStore.retrieve(CredentialKeys.apiKey),
        equals('web-secret'),
      );
      expect(await refreshedPageStore.retrieve(CredentialKeys.apiKey), isNull);
      expect(
        await refreshedPageStore.containsKey(CredentialKeys.apiKey),
        isFalse,
      );
    });
  });
}
