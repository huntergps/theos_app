/// Contract (fix/sdk/user-lang-tz): Odoo works in the operator's own
/// language and timezone (`res.users.lang`/`res.users.tz`), never a fixed
/// `en_US`/UTC. `UserNotifier` is the single point in theos_pos where the
/// currently authenticated user is published — see `setUser`,
/// `restoreCachedUser` and `fetchUser` in
/// `theos_pos/lib/shared/providers/user_provider.dart` — so it is also the
/// single point that must push the user's own locale onto the active
/// `OdooClient` (`OdooClient.updateLocale`), never a screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos/shared/providers/user_provider.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show User;

void main() {
  group('UserNotifier applies the current user locale to the Odoo client', () {
    test('setUser applies lang/tz from the local user record', () async {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          odooServiceProvider.overrideWithValue(OdooService(client: client)),
        ],
      );
      addTearDown(container.dispose);

      const user = User(
        id: 7,
        name: 'Erik Salazar',
        login: 'erik',
        lang: 'es_EC',
        tz: 'America/Guayaquil',
      );

      await container.read(userProvider.notifier).setUser(user);

      expect(client.config.defaultLanguage, 'es_EC');
      expect(client.config.defaultTimezone, 'America/Guayaquil');
    });

    test(
      'a user with no lang/tz (Odoo returned false) never overrides an '
      'already-configured client locale',
      () async {
        final client = OdooClient(
          config: const OdooClientConfig(
            baseUrl: 'https://odoo.example.com',
            apiKey: 'test-key',
            defaultLanguage: 'es_EC',
            defaultTimezone: 'America/Guayaquil',
          ),
        );
        final container = ProviderContainer(
          overrides: [
            odooServiceProvider.overrideWithValue(OdooService(client: client)),
          ],
        );
        addTearDown(container.dispose);

        const user = User(id: 7, name: 'Erik Salazar', login: 'erik');

        await container.read(userProvider.notifier).setUser(user);

        expect(client.config.defaultLanguage, 'es_EC');
        expect(client.config.defaultTimezone, 'America/Guayaquil');
      },
    );

    test('never hardcodes es_EC/America/Guayaquil for a different user', () async {
      final client = OdooClient(
        config: const OdooClientConfig(
          baseUrl: 'https://odoo.example.com',
          apiKey: 'test-key',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          odooServiceProvider.overrideWithValue(OdooService(client: client)),
        ],
      );
      addTearDown(container.dispose);

      const user = User(
        id: 9,
        name: 'John Doe',
        login: 'john',
        lang: 'en_US',
        tz: 'UTC',
      );

      await container.read(userProvider.notifier).setUser(user);

      expect(client.config.defaultLanguage, 'en_US');
      expect(client.config.defaultTimezone, 'UTC');
    });
  });
}
