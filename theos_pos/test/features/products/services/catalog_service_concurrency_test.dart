import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/products/services/catalog_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../helpers/test_model_factory.dart';

void main() {
  test('concurrent initialization shares one complete catalog load', () async {
    final products = Completer<List<Product>>();
    var productLoads = 0;
    var uomLoads = 0;
    var categoryLoads = 0;
    var taxLoads = 0;
    final service = CatalogService(
      loadProducts: () {
        productLoads++;
        return products.future;
      },
      loadUoms: () async {
        uomLoads++;
        return [];
      },
      loadCategories: () async {
        categoryLoads++;
        return [];
      },
      loadTaxes: () async {
        taxLoads++;
        return [];
      },
    );
    addTearDown(service.dispose);

    final first = service.initialize();
    final second = service.initialize();
    final directCaller = service.loadCatalogs();
    await Future<void>.delayed(Duration.zero);

    expect(productLoads, 1);
    expect(uomLoads, 1);
    expect(categoryLoads, 1);
    expect(taxLoads, 1);

    products.complete([]);
    await Future.wait([first, second, directCaller]);
    expect(service.isLoaded, isTrue);
  });

  test('concurrent refresh calls share one reload', () async {
    var loads = 0;
    Future<List<Product>> loadProducts() async {
      loads++;
      await Future<void>.delayed(Duration.zero);
      return [];
    }

    final service = CatalogService(
      loadProducts: loadProducts,
      loadUoms: () async => [],
      loadCategories: () async => [],
      loadTaxes: () async => [],
    );
    addTearDown(service.dispose);

    await service.initialize();
    await Future.wait([service.refresh(), service.refresh()]);

    expect(loads, 2, reason: 'one initial load plus one shared refresh');
  });

  test('load failures remain visible and a later call can retry', () async {
    var shouldFail = true;
    var productLoads = 0;
    final service = CatalogService(
      loadProducts: () async {
        productLoads++;
        if (shouldFail) throw StateError('local catalog unavailable');
        return [];
      },
      loadUoms: () async => [],
      loadCategories: () async => [],
      loadTaxes: () async => [],
    );
    addTearDown(service.dispose);

    await expectLater(
      service.initialize(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'local catalog unavailable',
        ),
      ),
    );
    expect(service.isLoaded, isFalse);

    shouldFail = false;
    await service.initialize();

    expect(productLoads, 2);
    expect(service.isLoaded, isTrue);
  });

  test(
    'watching is idempotent and dispose cancels all subscriptions',
    () async {
      final streams = _CatalogTestStreams();
      final service = streams.createService();
      addTearDown(streams.close);

      service.populateForTesting(
        products: [],
        uoms: [],
        categories: [],
        taxes: [],
      );
      service.startWatching();
      service.startWatching();
      await Future<void>.delayed(Duration.zero);

      expect(service.activeWatchSubscriptionCount, 4);
      expect(streams.listenCount, 4);

      await service.dispose();

      expect(service.activeWatchSubscriptionCount, 0);
      expect(streams.cancelCount, 4);
    },
  );

  test(
    'equal snapshots do not rebuild and domain revisions stay isolated',
    () async {
      resetIdCounter();
      final streams = _CatalogTestStreams();
      final service = streams.createService();
      addTearDown(() async {
        await service.dispose();
        await streams.close();
      });
      final original = ProductFactory.create(id: 1, name: 'Original');
      service.populateForTesting(
        products: [original],
        uoms: [],
        categories: [],
        taxes: [],
      );
      service.startWatching();

      var productEvents = 0;
      var uomEvents = 0;
      final productSub = service.onProductsChanged.listen(
        (_) => productEvents++,
      );
      final uomSub = service.onUomsChanged.listen((_) => uomEvents++);
      addTearDown(productSub.cancel);
      addTearDown(uomSub.cancel);

      streams.products.add([original]);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(
        productEvents,
        0,
        reason: 'the initial Drift snapshot is unchanged',
      );

      streams.products.add([original.copyWith(name: 'Updated')]);
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(productEvents, 1);
      expect(
        uomEvents,
        0,
        reason: 'product changes must not rebuild UoM lookups',
      );
      expect(service.getProduct(1)?.name, 'Updated');
    },
  );
}

class _CatalogTestStreams {
  int listenCount = 0;
  int cancelCount = 0;

  late final StreamController<List<Product>> products = _controller<Product>();
  late final StreamController<List<Uom>> uoms = _controller<Uom>();
  late final StreamController<List<ProductCategory>> categories =
      _controller<ProductCategory>();
  late final StreamController<List<Tax>> taxes = _controller<Tax>();

  StreamController<List<T>> _controller<T>() {
    return StreamController<List<T>>.broadcast(
      onListen: () => listenCount++,
      onCancel: () => cancelCount++,
    );
  }

  CatalogService createService() {
    return CatalogService(
      loadProducts: () async => [],
      loadUoms: () async => [],
      loadCategories: () async => [],
      loadTaxes: () async => [],
      watchProducts: () => products.stream,
      watchUoms: () => uoms.stream,
      watchCategories: () => categories.stream,
      watchTaxes: () => taxes.stream,
      debounceDuration: Duration.zero,
    );
  }

  Future<void> close() async {
    await Future.wait([
      products.close(),
      uoms.close(),
      categories.close(),
      taxes.close(),
    ]);
  }
}
