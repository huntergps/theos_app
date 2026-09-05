import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/security/security.dart';

void main() {
  test('selector uses durable native and ephemeral web storage', () async {
    final store = createPlatformCredentialStore();

    if (kIsWeb) {
      expect(
        platformCredentialStorePersistence,
        PlatformCredentialStorePersistence.ephemeral,
      );
      expect(store, isA<EphemeralCredentialStore>());
      await store.store('refresh-proof', 'secret');
      expect(
        await createPlatformCredentialStore().retrieve('refresh-proof'),
        isNull,
      );
    } else {
      expect(
        platformCredentialStorePersistence,
        PlatformCredentialStorePersistence.durable,
      );
      expect(store, isA<DurableSecureCredentialStore>());
    }
  });
}
