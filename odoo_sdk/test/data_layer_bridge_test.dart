import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

import 'mocks/mock_helpers.dart';

void main() {
  setUpAll(registerAllFallbacks);

  late OdooDataLayer layer;
  late MockGeneratedDatabase mockDb;
  late MockOfflineQueueStore mockStore;

  setUp(() {
    layer = OdooDataLayer();
    mockDb = MockGeneratedDatabase();
    mockStore = mockQueueStore();
    OdooRecordRegistry.clear();
  });

  tearDown(() {
    try {
      layer.dispose();
    } catch (_) {}
    OdooRecordRegistry.clear();
  });

  group('DataLayerBridge', () {
    test('isReady is false before initialization', () {
      final bridge = DataLayerBridge(layer);
      expect(bridge.isReady, isFalse);
      expect(bridge.odooClient, isNull);
      expect(bridge.offlineQueue, isNull);
    });

    test('initialize creates context and becomes ready', () async {
      final bridge = DataLayerBridge(layer);
      await bridge.initialize(
        session: testSession(),
        database: mockDb,
        queueStore: mockStore,
        registerModels: (_) {},
      );
      expect(bridge.isReady, isTrue);
      expect(bridge.odooClient, isNotNull);
      expect(bridge.offlineQueue, isNotNull);
    });

    test('registeredModels returns empty when no models registered', () async {
      final bridge = DataLayerBridge(layer);
      await bridge.initialize(
        session: testSession(),
        database: mockDb,
        queueStore: mockStore,
        registerModels: (_) {},
      );
      expect(bridge.registeredModels, isEmpty);
    });

    test('registeredModels returns empty when not ready', () {
      final bridge = DataLayerBridge(layer);
      expect(bridge.registeredModels, isEmpty);
    });

    group('manager access', () {
      test('managerFor throws when not ready', () {
        final bridge = DataLayerBridge(layer);
        expect(() => bridge.managerFor('x'), throwsStateError);
      });

      test('configFor throws when not ready', () {
        final bridge = DataLayerBridge(layer);
        expect(() => bridge.configFor('x'), throwsStateError);
      });
    });

    group('sync', () {
      test('syncAll throws when not ready', () {
        final bridge = DataLayerBridge(layer);
        expect(() => bridge.syncAll(), throwsStateError);
      });

      test('syncModel throws when not ready', () {
        final bridge = DataLayerBridge(layer);
        expect(() => bridge.syncModel('x'), throwsStateError);
      });
    });

    group('context switching', () {
      test('switchContext delegates to layer', () async {
        final bridge = DataLayerBridge(layer);
        await bridge.initialize(
          session: testSession(id: 'a'),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
        );
        await layer.createAndInitializeContext(
          session: testSession(id: 'b'),
          database: mockDb,
          queueStore: mockQueueStore(),
          registerModels: (_) {},
          setActive: false,
        );

        bridge.switchContext('b');
        expect(layer.activeContextId, 'b');
      });

      test('switchContext throws for nonexistent context', () async {
        final bridge = DataLayerBridge(layer);
        await bridge.initialize(
          session: testSession(),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
        );
        expect(() => bridge.switchContext('nope'), throwsStateError);
      });
    });

    test('dispose does not dispose underlying layer', () async {
      final bridge = DataLayerBridge(layer);
      await bridge.initialize(
        session: testSession(),
        database: mockDb,
        queueStore: mockStore,
        registerModels: (_) {},
      );
      bridge.dispose();
      // Layer should still be functional
      expect(layer.contextCount, 1);
    });
  });
}
