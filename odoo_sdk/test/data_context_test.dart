import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';

import 'mocks/mock_helpers.dart';

// Mock manager that we can register with the proper type param
class _FakeModel {}

class _MockManager extends Mock implements OdooModelManager<_FakeModel> {
  @override
  String get odooModel => 'fake.model';
}

void main() {
  setUpAll(registerAllFallbacks);

  late DataSession session;
  late MockGeneratedDatabase mockDb;
  late MockOfflineQueueStore mockStore;

  setUp(() {
    session = testSession();
    mockDb = MockGeneratedDatabase();
    mockStore = mockQueueStore();
    OdooRecordRegistry.clear();
  });

  group('DataContext', () {
    test('starts in created state', () {
      final ctx = DataContext(session);
      expect(ctx.state, ContextState.created);
      expect(ctx.client, isNull);
      expect(ctx.database, isNull);
      expect(ctx.queue, isNull);
    });

    test('holds session reference', () {
      final ctx = DataContext(session);
      expect(ctx.session, same(session));
      expect(ctx.session.id, 'test');
    });

    group('registration', () {
      test('registerConfig stores config in context registry', () {
        final ctx = DataContext(session);
        const config = SmartModelConfig(
          odooModel: 'product.product',
          tableName: 'product_product',
          fieldDefinitions: [],
        );
        ctx.registerConfig<String>(config);
        expect(ctx.configs.has<String>(), isTrue);
        expect(ctx.configs.getByModel('product.product'), isNotNull);
      });

      test('registerManager stores manager in context registry', () {
        final ctx = DataContext(session);
        final mgr = _MockManager();
        ctx.registerManager<_FakeModel>(mgr);
        expect(ctx.managers.getByModel('fake.model'), same(mgr));
      });
    });

    group('initialize', () {
      test('transitions to initialized state', () async {
        final ctx = DataContext(session);
        await ctx.initialize(database: mockDb, queueStore: mockStore);
        expect(ctx.state, ContextState.initialized);
        expect(ctx.client, isNotNull);
        expect(ctx.database, same(mockDb));
        expect(ctx.queue, isNotNull);
        ctx.dispose();
      });

      test('throws on double initialize', () async {
        final ctx = DataContext(session);
        await ctx.initialize(database: mockDb, queueStore: mockStore);
        expect(
          () => ctx.initialize(database: mockDb, queueStore: mockStore),
          throwsStateError,
        );
        ctx.dispose();
      });

      test('throws when initializing disposed context', () async {
        final ctx = DataContext(session);
        ctx.dispose();
        expect(
          () => ctx.initialize(database: mockDb, queueStore: mockStore),
          throwsStateError,
        );
      });

      test('initializes registered managers', () async {
        final ctx = DataContext(session);
        final mgr = _MockManager();
        when(
          () => mgr.initialize(
            client: any(named: 'client'),
            db: any(named: 'db'),
            queue: any(named: 'queue'),
            config: any(named: 'config'),
          ),
        ).thenReturn(null);
        when(() => mgr.dispose()).thenReturn(null);

        ctx.registerManager<_FakeModel>(mgr);
        await ctx.initialize(database: mockDb, queueStore: mockStore);
        verify(
          () => mgr.initialize(
            client: any(named: 'client'),
            db: any(named: 'db'),
            queue: any(named: 'queue'),
            config: any(named: 'config'),
          ),
        ).called(1);
        ctx.dispose();
      });
    });

    group('manager access', () {
      test('managerFor throws when not initialized', () {
        final ctx = DataContext(session);
        expect(() => ctx.managerFor<_FakeModel>(), throwsStateError);
      });

      test('managerByModel throws when not initialized', () {
        final ctx = DataContext(session);
        expect(() => ctx.managerByModel('x'), throwsStateError);
      });

      test('managerFor returns registered manager after init', () async {
        final ctx = DataContext(session);
        final mgr = _MockManager();
        when(
          () => mgr.initialize(
            client: any(named: 'client'),
            db: any(named: 'db'),
            queue: any(named: 'queue'),
            config: any(named: 'config'),
          ),
        ).thenReturn(null);
        when(() => mgr.dispose()).thenReturn(null);

        ctx.registerManager<_FakeModel>(mgr);
        await ctx.initialize(database: mockDb, queueStore: mockStore);
        expect(ctx.managerFor<_FakeModel>(), same(mgr));
        expect(ctx.managerByModel('fake.model'), same(mgr));
        expect(ctx.registeredModels, contains('fake.model'));
        ctx.dispose();
      });
    });

    group('dispose', () {
      test('transitions to disposed state', () async {
        final ctx = DataContext(session);
        await ctx.initialize(database: mockDb, queueStore: mockStore);
        ctx.dispose();
        expect(ctx.state, ContextState.disposed);
        expect(ctx.client, isNull);
        expect(ctx.database, isNull);
        expect(ctx.queue, isNull);
      });

      test('double dispose is safe', () async {
        final ctx = DataContext(session);
        await ctx.initialize(database: mockDb, queueStore: mockStore);
        ctx.dispose();
        expect(() => ctx.dispose(), returnsNormally);
      });

      test('disposes all managers', () async {
        final ctx = DataContext(session);
        final mgr = _MockManager();
        when(
          () => mgr.initialize(
            client: any(named: 'client'),
            db: any(named: 'db'),
            queue: any(named: 'queue'),
            config: any(named: 'config'),
          ),
        ).thenReturn(null);
        when(() => mgr.dispose()).thenReturn(null);

        ctx.registerManager<_FakeModel>(mgr);
        await ctx.initialize(database: mockDb, queueStore: mockStore);
        ctx.dispose();
        verify(() => mgr.dispose()).called(1);
      });
    });

    test('toString includes id and state', () {
      final ctx = DataContext(session);
      expect(ctx.toString(), contains('test'));
      expect(ctx.toString(), contains('created'));
    });
  });

  group('ContextConfigRegistry', () {
    test('register and retrieve by type', () {
      final reg = ContextConfigRegistry();
      const config = SmartModelConfig(
        odooModel: 'sale.order',
        tableName: 'sale_order',
        fieldDefinitions: [],
      );
      reg.register<String>(config);
      expect(reg.get<String>(), same(config));
      expect(reg.has<String>(), isTrue);
      expect(reg.has<int>(), isFalse);
    });

    test('register and retrieve by model name', () {
      final reg = ContextConfigRegistry();
      const config = SmartModelConfig(
        odooModel: 'product.product',
        tableName: 'product_product',
        fieldDefinitions: [],
      );
      reg.register<String>(config);
      expect(reg.getByModel('product.product'), same(config));
      expect(reg.hasModel('product.product'), isTrue);
      expect(reg.hasModel('nonexistent'), isFalse);
    });

    test('all and modelNames iterables', () {
      final reg = ContextConfigRegistry();
      reg.register<String>(
        const SmartModelConfig(
          odooModel: 'a.a',
          tableName: 'a_a',
          fieldDefinitions: [],
        ),
      );
      reg.register<int>(
        const SmartModelConfig(
          odooModel: 'b.b',
          tableName: 'b_b',
          fieldDefinitions: [],
        ),
      );
      expect(reg.all.length, 2);
      expect(reg.modelNames, containsAll(['a.a', 'b.b']));
    });

    test('clear removes all', () {
      final reg = ContextConfigRegistry();
      reg.register<String>(
        const SmartModelConfig(
          odooModel: 'x',
          tableName: 'x',
          fieldDefinitions: [],
        ),
      );
      reg.clear();
      expect(reg.all, isEmpty);
      expect(reg.has<String>(), isFalse);
    });
  });

  group('ContextManagerRegistry', () {
    test('register and retrieve by model name', () {
      final reg = ContextManagerRegistry();
      final mgr = _MockManager();
      reg.register<_FakeModel>(mgr);
      expect(reg.getByModel('fake.model'), same(mgr));
      expect(reg.modelNames, contains('fake.model'));
      expect(reg.length, 1);
    });

    test('getByType returns typed manager', () {
      final reg = ContextManagerRegistry();
      final mgr = _MockManager();
      reg.register<_FakeModel>(mgr);
      expect(reg.getByType<_FakeModel>(), same(mgr));
    });

    test('registerAllInGlobalRegistry pushes to OdooRecordRegistry', () {
      OdooRecordRegistry.clear();
      final reg = ContextManagerRegistry();
      final mgr = _MockManager();
      reg.register<_FakeModel>(mgr);
      reg.registerAllInGlobalRegistry();
      // The method should not throw — it pushes types into the global registry
    });

    test('disposeAll clears everything', () {
      final reg = ContextManagerRegistry();
      final mgr = _MockManager();
      when(() => mgr.dispose()).thenReturn(null);
      reg.register<_FakeModel>(mgr);
      reg.disposeAll();
      expect(reg.length, 0);
      verify(() => mgr.dispose()).called(1);
    });
  });

  group('ContextFieldRegistry', () {
    test('register and retrieve', () {
      final reg = ContextFieldRegistry();
      final fr = FieldRegistry('test');
      reg.register<String>(fr);
      expect(reg.get<String>(), same(fr));
      expect(reg.has<String>(), isTrue);
    });

    test('clear removes all', () {
      final reg = ContextFieldRegistry();
      reg.register<String>(FieldRegistry('test'));
      reg.clear();
      expect(reg.has<String>(), isFalse);
    });
  });

  group('ContextComputeRegistry', () {
    test('register and retrieve', () {
      final reg = ContextComputeRegistry();
      final engine = ComputedFieldEngine<String>();
      reg.register<String>(engine);
      expect(reg.get<String>(), same(engine));
      expect(reg.has<String>(), isTrue);
    });

    test('clear removes all', () {
      final reg = ContextComputeRegistry();
      reg.register<String>(ComputedFieldEngine<String>());
      reg.clear();
      expect(reg.has<String>(), isFalse);
    });
  });
}
