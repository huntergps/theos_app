import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/notifications/system_notification_presenter.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        NotificationCapability,
        NotificationChannel,
        NotificationScope,
        NotificationTarget;

final class _Plugin implements NotificationPluginPort {
  bool initializeResult = true;
  PermissionState permission = PermissionState.granted;
  int permissionRequests = 0;
  final shown = <int, String>{};
  final cancelled = <int>[];

  @override
  Future<bool> initialize() async => initializeResult;

  @override
  Future<PermissionState> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown[id] = payload;
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

final class _Ids implements SystemIdPort {
  final ids = <String, int>{};

  @override
  Future<int?> lookup({
    required String scopeKey,
    required String entryId,
    required NotificationChannel channel,
  }) async => ids['$scopeKey|$entryId|${channel.name}'];
}

SystemNotificationRequest request(String scope) => SystemNotificationRequest(
  scope: NotificationScope(scopeKey: scope, partitionKey: 'global'),
  target: NotificationTarget(type: 'entry', reference: 'entry-1'),
  entryId: 'entry-1',
  revision: 2,
  channel: NotificationChannel.system,
  title: 'Aviso',
  body: 'Detalle',
);

void main() {
  test(
    'initialization never requests permission before an explicit action',
    () async {
      final plugin = _Plugin();
      final presenter = SystemNotificationPresenter(
        plugin,
        _Ids(),
        activeScopeKey: 'scope',
        platform: NotificationPlatform.ios,
      );

      expect(await presenter.initialize(), isTrue);
      expect(plugin.permissionRequests, 0);
      expect(
        await presenter.requestPermissionFromUserAction(),
        PermissionState.granted,
      );
      expect(plugin.permissionRequests, 1);
    },
  );

  test('denied permission is returned without blocking inbox', () async {
    final plugin = _Plugin()..permission = PermissionState.denied;
    final presenter = SystemNotificationPresenter(
      plugin,
      _Ids(),
      activeScopeKey: 'scope',
      platform: NotificationPlatform.android,
    );
    await presenter.initialize();
    expect(
      await presenter.requestPermissionFromUserAction(),
      PermissionState.denied,
    );
  });

  test('unsupported platform reports real capabilities', () async {
    final plugin = _Plugin();
    final ids = _Ids()..ids['scope|entry-1|system'] = 7;
    final presenter = SystemNotificationPresenter(
      plugin,
      ids,
      activeScopeKey: 'scope',
      platform: NotificationPlatform.web,
    );
    await presenter.initialize();
    expect(
      presenter.capabilities.supports(NotificationCapability.schedule),
      isFalse,
    );
    expect(
      await presenter.requestPermissionFromUserAction(),
      PermissionState.unsupported,
    );
    expect(
      await presenter.showOrReplace(request('scope')),
      SystemDeliveryState.shown,
    );
  });

  test('stable registry ID replaces and cancels only active scope', () async {
    final plugin = _Plugin();
    final ids = _Ids()..ids['scope|entry-1|system'] = 42;
    final presenter = SystemNotificationPresenter(
      plugin,
      ids,
      activeScopeKey: 'scope',
      platform: NotificationPlatform.android,
    );
    await presenter.initialize();
    expect(
      await presenter.showOrReplace(request('scope')),
      SystemDeliveryState.shown,
    );
    expect(
      await presenter.showOrReplace(request('scope')),
      SystemDeliveryState.shown,
    );
    expect(plugin.shown.keys, [42]);
    expect(
      await presenter.showOrReplace(request('other')),
      SystemDeliveryState.denied,
    );
    expect(
      await presenter.cancel(
        scopeKey: 'other',
        entryId: 'entry-1',
        channel: NotificationChannel.system,
      ),
      SystemDeliveryState.denied,
    );
    expect(
      await presenter.cancel(
        scopeKey: 'scope',
        entryId: 'entry-1',
        channel: NotificationChannel.system,
      ),
      SystemDeliveryState.shown,
    );
    expect(plugin.cancelled, [42]);
  });

  test('show and cancel require successful initialization', () async {
    final plugin = _Plugin()..initializeResult = false;
    final ids = _Ids()..ids['scope|entry-1|system'] = 42;
    final presenter = SystemNotificationPresenter(
      plugin,
      ids,
      activeScopeKey: 'scope',
      platform: NotificationPlatform.android,
    );
    expect(await presenter.initialize(), isFalse);
    expect(
      await presenter.showOrReplace(request('scope')),
      SystemDeliveryState.unsupported,
    );
    expect(
      await presenter.cancel(
        scopeKey: 'scope',
        entryId: 'entry-1',
        channel: NotificationChannel.system,
      ),
      SystemDeliveryState.unsupported,
    );
    expect(plugin.shown, isEmpty);
    expect(plugin.cancelled, isEmpty);
  });

  test('payload contains only opaque target fields', () {
    final payload = request('scope').payload;
    expect(payload, contains('entry-1'));
    expect(payload, isNot(contains('amount')));
    expect(payload, isNot(contains('http')));
    expect(payload, isNot(contains('approve')));
  });
}
