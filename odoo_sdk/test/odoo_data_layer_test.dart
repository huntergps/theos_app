import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

import 'mocks/mock_helpers.dart';

void main() {
  setUpAll(registerAllFallbacks);

  late MockGeneratedDatabase mockDb;
  late MockOfflineQueueStore mockStore;

  setUp(() {
    mockDb = MockGeneratedDatabase();
    mockStore = mockQueueStore();
    OdooRecordRegistry.clear();
  });

  group('OdooDataLayer', () {
    test('starts empty', () {
      final layer = OdooDataLayer();
      expect(layer.contextCount, 0);
      expect(layer.activeContextId, isNull);
      expect(layer.activeContext, isNull);
      expect(layer.contextIds, isEmpty);
      layer.dispose();
    });

    group('createContext', () {
      test('creates and registers context', () {
        final layer = OdooDataLayer();
        final ctx = layer.createContext(testSession());
        expect(layer.contextCount, 1);
        expect(layer.getContext('test'), same(ctx));
        expect(ctx.state, ContextState.created);
        layer.dispose();
      });

      test('throws on duplicate session id', () {
        final layer = OdooDataLayer();
        layer.createContext(testSession());
        expect(
          () => layer.createContext(testSession()),
          throwsStateError,
        );
        layer.dispose();
      });
    });

    group('createAndInitializeContext', () {
      test('creates, initializes, and activates', () async {
        final layer = OdooDataLayer();
        final ctx = await layer.createAndInitializeContext(
          session: testSession(),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
        );
        expect(ctx.state, ContextState.initialized);
        expect(layer.activeContextId, 'test');
        expect(layer.activeContext, same(ctx));
        layer.dispose();
      });

      test('setActive=false does not activate', () async {
        final layer = OdooDataLayer();
        await layer.createAndInitializeContext(
          session: testSession(),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
          setActive: false,
        );
        expect(layer.activeContextId, isNull);
        layer.dispose();
      });
    });

    group('setActiveContext', () {
      test('switches active context', () async {
        final layer = OdooDataLayer();
        await layer.createAndInitializeContext(
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

        layer.setActiveContext('b');
        expect(layer.activeContextId, 'b');
      });

      test('throws for nonexistent context', () {
        final layer = OdooDataLayer();
        expect(
          () => layer.setActiveContext('nope'),
          throwsStateError,
        );
        layer.dispose();
      });

      test('throws for non-initialized context', () {
        final layer = OdooDataLayer();
        layer.createContext(testSession());
        expect(
          () => layer.setActiveContext('test'),
          throwsStateError,
        );
        layer.dispose();
      });

      test('emits on contextChanges stream', () async {
        final layer = OdooDataLayer();
        await layer.createAndInitializeContext(
          session: testSession(id: 'a'),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
          setActive: false,
        );

        final changes = <String?>[];
        layer.contextChanges.listen(changes.add);

        layer.setActiveContext('a');
        await Future.delayed(Duration.zero);

        expect(changes, ['a']);
        layer.dispose();
      });
    });

    group('disposeContext', () {
      test('removes and disposes context', () async {
        final layer = OdooDataLayer();
        await layer.createAndInitializeContext(
          session: testSession(),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
        );
        layer.disposeContext('test');
        expect(layer.contextCount, 0);
        expect(layer.getContext('test'), isNull);
      });

      test('clears active if disposing active context', () async {
        final layer = OdooDataLayer();
        await layer.createAndInitializeContext(
          session: testSession(),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
        );
        expect(layer.activeContextId, 'test');
        layer.disposeContext('test');
        expect(layer.activeContextId, isNull);
        layer.dispose();
      });

      test('disposing non-active context keeps active', () async {
        final layer = OdooDataLayer();
        await layer.createAndInitializeContext(
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
        layer.disposeContext('b');
        expect(layer.activeContextId, 'a');
        layer.dispose();
      });
    });

    group('dispose', () {
      test('disposes all contexts', () async {
        final layer = OdooDataLayer();
        await layer.createAndInitializeContext(
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
        layer.dispose();
        expect(layer.contextCount, 0);
        expect(layer.activeContextId, isNull);
      });
    });

    group('multiple contexts isolation', () {
      test('two contexts can exist independently', () async {
        final layer = OdooDataLayer();
        final ctxA = await layer.createAndInitializeContext(
          session: testSession(id: 'a'),
          database: mockDb,
          queueStore: mockStore,
          registerModels: (_) {},
        );
        final ctxB = await layer.createAndInitializeContext(
          session: testSession(id: 'b'),
          database: mockDb,
          queueStore: mockQueueStore(),
          registerModels: (_) {},
          setActive: false,
        );

        expect(ctxA.session.id, 'a');
        expect(ctxB.session.id, 'b');
        expect(ctxA, isNot(same(ctxB)));
        expect(layer.contextCount, 2);
        layer.dispose();
      });
    });
  });
}
