import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/notifications/installation_system_id_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show NotificationChannel;

const _appId = 'theos_panel';
const _installationId = 'installation-1';

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  test('different scopes receive different IDs', () async {
    final prefs = await _preferences();
    final registry = NotificationSystemIdRegistry(
      preferences: prefs,
      appId: _appId,
      installationId: _installationId,
    );
    final first = await registry.allocate(
      scopeKey: 'scope-a',
      entryId: 'entry',
      channel: 'system',
    );
    final second = await registry.allocate(
      scopeKey: 'scope-b',
      entryId: 'entry',
      channel: 'system',
    );
    expect(first, isNot(second));
  });

  test('serializes 50 concurrent allocations without collisions', () async {
    final prefs = await _preferences();
    final first = NotificationSystemIdRegistry(
      preferences: prefs,
      appId: _appId,
      installationId: _installationId,
    );
    final second = NotificationSystemIdRegistry(
      preferences: prefs,
      appId: _appId,
      installationId: _installationId,
    );
    final ids = await Future.wait(
      List.generate(
        50,
        (index) => (index.isEven ? first : second).allocate(
          scopeKey: 'scope',
          entryId: 'entry-$index',
          channel: 'system',
        ),
      ),
    );
    expect(ids.toSet(), hasLength(50));
  });

  test(
    'recreated instance preserves IDs and allocation is idempotent',
    () async {
      final prefs = await _preferences();
      final first = NotificationSystemIdRegistry(
        preferences: prefs,
        appId: _appId,
        installationId: _installationId,
      );
      final allocated = await first.allocate(
        scopeKey: 'scope',
        entryId: 'entry',
        channel: 'system',
      );
      final recreated = NotificationSystemIdRegistry(
        preferences: prefs,
        appId: _appId,
        installationId: _installationId,
      );
      expect(
        await recreated.allocate(
          scopeKey: 'scope',
          entryId: 'entry',
          channel: 'system',
        ),
        allocated,
      );
      expect(
        await recreated.lookup(
          scopeKey: 'scope',
          entryId: 'entry',
          channel: NotificationChannel.system,
        ),
        allocated,
      );
    },
  );

  test('corrupt state fails closed without allocating a colliding ID', () async {
    final prefs = await _preferences();
    final storageKey =
        'orbi/notifications/system_ids/${jsonEncode([_appId, _installationId])}';
    expect(
      await prefs.setString(
        storageKey,
        jsonEncode({
          'version': 1,
          'nextId': 2,
          'mappings': {'bad': 1, 'duplicate': 1},
        }),
      ),
      isTrue,
    );
    final registry = NotificationSystemIdRegistry(
      preferences: prefs,
      appId: _appId,
      installationId: _installationId,
    );
    await expectLater(
      registry.allocate(scopeKey: 'scope', entryId: 'entry', channel: 'system'),
      throwsStateError,
    );
    await expectLater(
      registry.lookup(
        scopeKey: 'scope',
        entryId: 'entry',
        channel: NotificationChannel.system,
      ),
      throwsStateError,
    );
  });
}
