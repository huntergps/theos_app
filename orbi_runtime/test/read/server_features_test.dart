import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lector falso mínimo: sólo lo que `ServerFeatureStore.probe` necesita
/// (`fields_get` con `attributes`), igual de forma que
/// `runtime_catalog_availability_test.dart` lo hace para `_probe`.
class _FeatureReader implements Json2FieldsGetAttributesPort {
  _FeatureReader({this.missingModels = const {}, this.errorsByModel = const {}});

  final Set<String> missingModels;
  final Map<String, Exception Function()> errorsByModel;
  final calls = <String>[];

  @override
  Future<Map<String, dynamic>> fieldsGetAttributes({
    required String model,
    required List<String> fields,
    required List<String> attributes,
  }) async {
    calls.add(model);
    if (missingModels.contains(model)) {
      throw const OdooNotFoundException('model does not exist');
    }
    final failure = errorsByModel[model];
    if (failure != null) throw failure();
    return {'id': <String, dynamic>{}};
  }
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  group('ServerFeatureStore.probe persists real evidence', () {
    test('a missing model is persisted as unavailable', () async {
      final prefs = await _preferences();
      final store = ServerFeatureStore(
        preferences: prefs,
        serverUrl: 'https://mepriga.example',
        database: 'mepriga',
      );
      final reader = _FeatureReader(missingModels: {'sale.order'});
      final result = await store.probe(ServerFeature.sales, reader);
      expect(result.stateOf(ServerFeature.sales), ServerFeatureState.unavailable);
      expect(store.read().stateOf(ServerFeature.sales), ServerFeatureState.unavailable);
    });

    test('a successful fields_get is persisted as available', () async {
      final prefs = await _preferences();
      final store = ServerFeatureStore(
        preferences: prefs,
        serverUrl: 'https://erp2.example',
        database: 'erp2',
      );
      final reader = _FeatureReader();
      final result = await store.probe(ServerFeature.cashbox, reader);
      expect(result.isAvailable(ServerFeature.cashbox), isTrue);
      expect(reader.calls, ['collection.session']);
    });

    test('a 403 still marks the model available: the model exists, only '
        'this session cannot ask it — permissions are RouteAccessPolicy\'s '
        'job, not this probe\'s', () async {
      final prefs = await _preferences();
      final store = ServerFeatureStore(
        preferences: prefs,
        serverUrl: 'https://erp2.example',
        database: 'erp2',
      );
      final reader = _FeatureReader(
        errorsByModel: {
          'approval.request': () =>
              const OdooAccessDeniedException('no permission'),
        },
      );
      final result = await store.probe(ServerFeature.approvals, reader);
      expect(result.isAvailable(ServerFeature.approvals), isTrue);
    });

    test('a transient error (network/500) keeps the last known state instead '
        'of forgetting it', () async {
      final prefs = await _preferences();
      final store = ServerFeatureStore(
        preferences: prefs,
        serverUrl: 'https://erp2.example',
        database: 'erp2',
      );
      // First probe succeeds and is persisted as available.
      await store.probe(ServerFeature.sales, _FeatureReader());
      expect(store.read().isAvailable(ServerFeature.sales), isTrue);

      // A later probe fails transiently — must NOT erase the earlier fact.
      final flaky = _FeatureReader(
        errorsByModel: {
          'sale.order': () => Exception('connection reset'),
        },
      );
      final result = await store.probe(ServerFeature.sales, flaky);
      expect(result.isAvailable(ServerFeature.sales), isTrue);
      expect(store.read().isAvailable(ServerFeature.sales), isTrue);
    });

    test('nothing probed yet reads as unknown, not unavailable', () async {
      final prefs = await _preferences();
      final store = ServerFeatureStore(
        preferences: prefs,
        serverUrl: 'https://erp2.example',
        database: 'erp2',
      );
      expect(store.read().stateOf(ServerFeature.envases), ServerFeatureState.unknown);
      expect(store.read().isAvailable(ServerFeature.envases), isFalse);
    });
  });

  test('features survive offline: a fresh store over the same preferences '
      'reads the same facts without any reader at all', () async {
    final prefs = await _preferences();
    final first = ServerFeatureStore(
      preferences: prefs,
      serverUrl: 'https://erp2.example',
      database: 'erp2',
    );
    await first.probe(ServerFeature.sales, _FeatureReader());
    await first.probe(
      ServerFeature.envases,
      _FeatureReader(missingModels: {'l10n_ec.envases.operacion'}),
    );

    // A brand-new store instance, same prefs, same key — as if the app was
    // restarted offline and nothing on the network is reachable.
    final restored = ServerFeatureStore(
      preferences: prefs,
      serverUrl: 'https://erp2.example',
      database: 'erp2',
    );
    final snapshot = restored.read();
    expect(snapshot.isAvailable(ServerFeature.sales), isTrue);
    expect(
      snapshot.stateOf(ServerFeature.envases),
      ServerFeatureState.unavailable,
    );
  });

  test('features are scoped per server+database, never shared', () async {
    final prefs = await _preferences();
    final erp2 = ServerFeatureStore(
      preferences: prefs,
      serverUrl: 'https://erp2.example',
      database: 'erp2',
    );
    final mepriga = ServerFeatureStore(
      preferences: prefs,
      serverUrl: 'https://mepriga.example',
      database: 'mepriga',
    );
    await erp2.probe(ServerFeature.sales, _FeatureReader());
    await mepriga.probe(
      ServerFeature.sales,
      _FeatureReader(missingModels: {'sale.order'}),
    );
    expect(erp2.read().isAvailable(ServerFeature.sales), isTrue);
    expect(mepriga.read().isAvailable(ServerFeature.sales), isFalse);
  });
}
