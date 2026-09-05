import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_pos/features/sales/providers/sale_orders_list_providers.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';
import 'package:theos_pos/shared/widgets/reactive/reactive_search_bar.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  SaleOrder order(
    int id, {
    required int userId,
    required SaleOrderState state,
    required DateTime date,
    String? partnerName,
    bool isSynced = true,
  }) {
    return SaleOrder(
      id: id,
      name: 'S$id',
      state: state,
      userId: userId,
      partnerName: partnerName,
      dateOrder: date,
      isSynced: isSynced,
    );
  }

  User user(int id, List<String> permissions) => User(
    id: id,
    name: 'User $id',
    login: 'user$id',
    permissions: permissions,
  );

  final orders = [
    order(
      1,
      userId: 14,
      state: SaleOrderState.draft,
      date: DateTime(2026, 1, 1),
      partnerName: 'Alpha',
    ),
    order(
      2,
      userId: 14,
      state: SaleOrderState.sale,
      date: DateTime(2026, 3, 1),
      partnerName: 'Beta',
    ),
    order(
      3,
      userId: 60,
      state: SaleOrderState.sale,
      date: DateTime(2026, 2, 1),
      partnerName: 'Gamma',
    ),
  ];

  const myOrders = SearchFacet(
    id: 'my_orders',
    label: 'Vendedor',
    value: 'Mis cotizaciones',
  );

  test('default sort is newest first', () {
    final result = applySaleOrderFilters(
      orders: orders,
      searchState: const ReactiveSearchBarState(),
    );

    expect(result.map((item) => item.id), [2, 3, 1]);
  });

  test('my orders scopes a salesperson to their assigned orders', () {
    final result = applySaleOrderFilters(
      orders: orders,
      searchState: const ReactiveSearchBarState(facets: [myOrders]),
      currentUser: user(60, [OdooUserGroup.salesUser]),
    );

    expect(result.map((item) => item.id), [3]);
  });

  test('my orders does not hide data for manager or API service identity', () {
    final managerResult = applySaleOrderFilters(
      orders: orders,
      searchState: const ReactiveSearchBarState(facets: [myOrders]),
      currentUser: user(60, [
        OdooUserGroup.salesUser,
        OdooUserGroup.salesManager,
      ]),
    );
    final serviceResult = applySaleOrderFilters(
      orders: orders,
      searchState: const ReactiveSearchBarState(facets: [myOrders]),
      currentUser: user(60, [OdooUserGroup.internalUser]),
    );

    expect(managerResult, hasLength(3));
    expect(serviceResult, hasLength(3));
  });

  test('state filter can be ignored when deriving consistent badge counts', () {
    const state = ReactiveSearchBarState(
      query: 'a',
      facets: [
        myOrders,
        SearchFacet(id: 'sale', label: 'Estado', value: 'Orden de venta'),
      ],
    );
    final visible = applySaleOrderFilters(
      orders: orders,
      searchState: state,
      currentUser: user(14, [OdooUserGroup.salesUser]),
    );
    final badgeScope = applySaleOrderFilters(
      orders: orders,
      searchState: state,
      currentUser: user(14, [OdooUserGroup.salesUser]),
      includeStateFilter: false,
    );

    expect(visible.map((item) => item.id), [2]);
    expect(badgeScope.map((item) => item.id), [2, 1]);
  });

  test('list rows and badges are built from one consistent snapshot', () {
    const state = ReactiveSearchBarState(
      facets: [
        myOrders,
        SearchFacet(id: 'sale', label: 'Estado', value: 'Orden de venta'),
      ],
    );
    final snapshot = buildSaleOrdersListSnapshot(
      orders: orders,
      searchState: state,
      currentUser: user(14, [OdooUserGroup.salesUser]),
    );

    expect(snapshot.visibleOrders.map((item) => item.id), [2]);
    expect(snapshot.countsByState['all'], 2);
    expect(snapshot.countsByState['draft'], 1);
    expect(snapshot.countsByState['sale'], 1);
    expect(
      snapshot.visibleOrders.length,
      snapshot.countsByState['sale'],
      reason: 'the selected state count must match the visible list',
    );
  });

  test('snapshot tracks unsynced orders without changing filter semantics', () {
    final withUnsynced = [
      ...orders,
      order(
        4,
        userId: 14,
        state: SaleOrderState.cancel,
        date: DateTime(2026, 4, 1),
        isSynced: false,
      ),
    ];

    final snapshot = buildSaleOrdersListSnapshot(
      orders: withUnsynced,
      searchState: const ReactiveSearchBarState(),
    );

    expect(snapshot.visibleOrders, hasLength(4));
    expect(snapshot.countsByState['all'], 4);
    expect(snapshot.unsyncedCount, 1);
  });

  test(
    'database stream failures propagate to rows and both counters',
    () async {
      final failure = StateError('local database unavailable');
      final container = ProviderContainer(
        overrides: [
          saleOrdersListSnapshotProvider.overrideWith(
            (ref) => Stream<SaleOrdersListSnapshot>.error(failure),
          ),
        ],
      );
      addTearDown(container.dispose);
      final rowSubscription = container.listen(
        filteredSaleOrdersProvider,
        (_, _) {},
      );
      final countSubscription = container.listen(
        saleOrdersCountProvider,
        (_, _) {},
      );
      final unsyncedSubscription = container.listen(
        unsyncedOrdersCountProvider,
        (_, _) {},
      );
      addTearDown(rowSubscription.close);
      addTearDown(countSubscription.close);
      addTearDown(unsyncedSubscription.close);

      await expectLater(
        container.read(saleOrdersListSnapshotProvider.future),
        throwsA(same(failure)),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(filteredSaleOrdersProvider).hasError, isTrue);
      expect(container.read(saleOrdersCountProvider).hasError, isTrue);
      expect(container.read(unsyncedOrdersCountProvider).hasError, isTrue);
    },
  );
}
