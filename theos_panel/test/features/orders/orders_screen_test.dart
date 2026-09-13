import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/features/orders/orders_contracts.dart';
import 'package:theos_panel/features/orders/orders_screen.dart';

final class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository(this.records);
  final List<OrderListItem> records;
  final _streams = <String, StreamController<OrderSnapshot>>{};
  final queries = <OrderQuery>[];
  Object? failure;

  String key(OrderQuery query) =>
      '${query.companyId}|${query.authorFilter}|${query.text}|${query.states.join(',')}|${query.workQueue}';

  @override
  Stream<OrderSnapshot> watch(OrderQuery query) {
    queries.add(query);
    final controller = _streams.putIfAbsent(
      key(query),
      () => StreamController<OrderSnapshot>.broadcast(),
    );
    Future<void>.microtask(() => _emit(query));
    return controller.stream;
  }

  @override
  Future<void> refresh(OrderQuery query) async => _emit(query);

  Future<void> _emit(OrderQuery query) async {
    final controller = _streams[key(query)];
    if (controller == null) return;
    if (failure != null) {
      controller.add(
        OrderSnapshot(
          status: OrderLoadStatus.error,
          query: query,
          error: failure,
        ),
      );
      return;
    }
    final items = records
        .where((item) {
          if (item.companyId != query.companyId) return false;
          if (query.authorFilter != null &&
              item.authorId != query.authorFilter) {
            return false;
          }
          if (query.states.isNotEmpty &&
              !query.states.contains(item.businessState)) {
            return false;
          }
          if (query.workQueue == OrderWorkQueue.cashierPending &&
              !item.pendingCollection &&
              !item.pendingInvoicing) {
            return false;
          }
          if (query.text != null &&
              !item.title.toLowerCase().contains(query.text!.toLowerCase())) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
    controller.add(
      OrderSnapshot(
        status: items.isEmpty ? OrderLoadStatus.empty : OrderLoadStatus.data,
        items: items,
        totalCount: items.length,
        query: query,
      ),
    );
  }

  void emitLate(OrderQuery query, OrderSnapshot snapshot) =>
      _streams[key(query)]?.add(snapshot);

  Future<void> dispose() async {
    for (final stream in _streams.values) {
      await stream.close();
    }
  }
}

CapabilitySnapshot capabilities(Iterable<String> permissions) =>
    CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: permissions,
    );

List<OrderListItem> orders() => const [
  OrderListItem(
    localId: 'o-1',
    title: 'Venta Sebastián',
    companyId: 1,
    authorId: 7,
    businessState: SaleOrderState.sale,
    syncState: OperationSyncState.queued,
    fiscalState: FiscalState.submitted,
    pendingCollection: true,
  ),
  OrderListItem(
    localId: 'o-2',
    title: 'Venta Jacqueline',
    companyId: 1,
    authorId: 8,
    businessState: SaleOrderState.sale,
    syncState: OperationSyncState.synced,
    fiscalState: FiscalState.authorized,
    pendingInvoicing: true,
  ),
  OrderListItem(
    localId: 'o-3',
    title: 'Otra empresa',
    companyId: 2,
    authorId: 7,
    businessState: SaleOrderState.sale,
    syncState: OperationSyncState.synced,
  ),
  OrderListItem(
    localId: 'o-4',
    title: 'Venta sin pendiente',
    companyId: 1,
    authorId: 9,
    businessState: SaleOrderState.sale,
    syncState: OperationSyncState.synced,
  ),
];

void main() {
  test(
    'filter is restored per scope and invalid permission falls back safely',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesOrderFilterStore(preferences);
      await store.write('scope-a', OrderFilter.all);
      final repository = _FakeOrderRepository(orders())..failure = null;
      addTearDown(repository.dispose);
      final seller = OrderController(
        repository: repository,
        policy: OrderFilterPolicy(
          userId: 7,
          capabilities: capabilities(['seller', 'orders.view_all']),
        ),
        filterStore: store,
        scopeKey: 'scope-a',
      );
      addTearDown(seller.dispose);
      expect(seller.filter, OrderFilter.all);
      final cashier = OrderController(
        repository: repository,
        policy: OrderFilterPolicy(
          userId: 9,
          capabilities: capabilities(['cashier']),
        ),
        filterStore: store,
        scopeKey: 'scope-a',
      );
      addTearDown(cashier.dispose);
      expect(cashier.filter, OrderFilter.cashierPending);
    },
  );

  testWidgets(
    'seller starts in mine, can select all, and preserves query on resize/refresh',
    (tester) async {
      final repository = _FakeOrderRepository(orders());
      addTearDown(repository.dispose);
      final policy = OrderFilterPolicy(
        userId: 7,
        capabilities: capabilities(['seller', 'orders.view_all']),
      );
      final size = ValueNotifier(const Size(599, 600));
      addTearDown(size.dispose);
      await tester.pumpWidget(
        FluentApp(
          home: ValueListenableBuilder<Size>(
            valueListenable: size,
            builder: (context, value, child) => SizedBox(
              width: value.width,
              height: value.height,
              child: child,
            ),
            child: OrdersScreen(repository: repository, policy: policy),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mis ventas'), findsOneWidget);
      expect(find.text('Todas'), findsOneWidget);
      expect(find.text('Venta Sebastián'), findsOneWidget);
      expect(find.text('Venta Jacqueline'), findsNothing);
      await tester.tap(find.text('Todas'));
      await tester.pump();
      expect(repository.queries.last.authorFilter, isNull);
      expect(find.text('Venta Jacqueline'), findsOneWidget);
      await tester.tap(find.byKey(const Key('orders-refresh-button')));
      await tester.pump();
      for (final viewport in const [
        Size(1440, 900),
        Size(1180, 820),
        Size(820, 1180),
        Size(390, 844),
      ]) {
        size.value = viewport;
        await tester.pump();
        expect(find.text('Venta Jacqueline'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      size.value = const Size(599, 600);
      await tester.pump();
      expect(find.text('Venta Jacqueline'), findsOneWidget);
      expect(repository.queries.last.authorFilter, isNull);
      // La ficha ahora trae más líneas (Vendedor/Subtotal/Impuestos), así que
      // a 600 px de alto la segunda fila ya no cabe sin desplazar: hay que
      // llevarla a la vista antes de tocarla, en vez de asumir que ya está.
      await tester.ensureVisible(find.text('Venta Jacqueline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Venta Jacqueline'));
      await tester.pumpAndSettle();
      expect(find.text('Estado comercial: sale'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'cashier sees collection/invoicing pending without seller author filter',
    () async {
      final repository = _FakeOrderRepository(orders());
      addTearDown(repository.dispose);
      final policy = OrderFilterPolicy(
        userId: 99,
        capabilities: capabilities(['cashier']),
      );
      final controller = OrderController(
        repository: repository,
        policy: policy,
      );
      addTearDown(controller.dispose);
      await controller.changes.first;
      expect(controller.filter, OrderFilter.cashierPending);
      expect(repository.queries.last.authorFilter, isNull);
      expect(repository.queries.last.companyId, 1);
      expect(repository.queries.last.states, contains(SaleOrderState.sale));
      expect(repository.queries.last.workQueue, OrderWorkQueue.cashierPending);
      expect(controller.snapshot.totalCount, 2);
      expect(
        controller.snapshot.items
            .where((item) => item.pendingCollection)
            .length,
        1,
      );
      expect(
        controller.snapshot.items.where((item) => item.pendingInvoicing).length,
        1,
      );
    },
  );

  test('seller filter and query survive a local refresh', () async {
    final repository = _FakeOrderRepository(orders());
    addTearDown(repository.dispose);
    final controller = OrderController(
      repository: repository,
      policy: OrderFilterPolicy(
        userId: 7,
        capabilities: capabilities(['seller', 'orders.view_all']),
      ),
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    controller.setFilter(OrderFilter.all);
    await Future<void>.delayed(Duration.zero);
    await controller.refresh();
    expect(controller.filter, OrderFilter.all);
    expect(controller.query.authorFilter, isNull);
    expect(controller.snapshot.query?.companyId, 1);
    expect(controller.snapshot.totalCount, 3);
  });

  testWidgets('order error is visible and does not become empty', (
    tester,
  ) async {
    final repository = _FakeOrderRepository(orders())
      ..failure = StateError('offline');
    addTearDown(repository.dispose);
    final policy = OrderFilterPolicy(
      userId: 7,
      capabilities: capabilities(['seller']),
    );
    await tester.pumpWidget(
      FluentApp(
        home: OrdersScreen(repository: repository, policy: policy),
      ),
    );
    await tester.pump();
    expect(find.text('No se pudieron cargar las órdenes.'), findsOneWidget);
    expect(find.text('Sin órdenes'), findsNothing);
  });

  test(
    'late response from an old filter cannot overwrite the new filter',
    () async {
      final repository = _FakeOrderRepository(orders());
      addTearDown(repository.dispose);
      final controller = OrderController(
        repository: repository,
        policy: OrderFilterPolicy(
          userId: 7,
          capabilities: capabilities(['seller', 'orders.view_all']),
        ),
      );
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      final oldQuery = repository.queries.first;
      controller.setFilter(OrderFilter.all);
      final newQuery = repository.queries.last;
      repository.emitLate(
        oldQuery,
        OrderSnapshot(
          status: OrderLoadStatus.data,
          items: [orders().first],
          totalCount: 1,
          query: oldQuery,
        ),
      );
      repository.emitLate(
        newQuery,
        OrderSnapshot(
          status: OrderLoadStatus.data,
          items: orders().sublist(0, 2),
          totalCount: 2,
          query: newQuery,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.totalCount, 3);
      expect(controller.snapshot.query?.authorFilter, isNull);
    },
  );

  // 🔴 La prueba que exige el encargo: el contador de cada chip rápido tiene
  // que salir de contar filas reales de la base local por estado, con el
  // mismo ámbito (dueño, texto) que la consulta activa — no un número fijo ni
  // el tamaño de la página cargada.
  test('las cuentas de los filtros rápidos por estado son las filas reales, no un adorno', () async {
    final repository = _FakeOrderRepository([
      for (var i = 0; i < 3; i++)
        OrderListItem(
          localId: 'q-$i',
          title: 'Cotización $i',
          companyId: 1,
          authorId: 7,
          businessState: SaleOrderState.draft,
          syncState: OperationSyncState.synced,
        ),
      for (var i = 0; i < 2; i++)
        OrderListItem(
          localId: 's-$i',
          title: 'Confirmada $i',
          companyId: 1,
          authorId: 7,
          businessState: SaleOrderState.sale,
          syncState: OperationSyncState.synced,
        ),
    ]);
    addTearDown(repository.dispose);
    final controller = OrderController(
      repository: repository,
      policy: OrderFilterPolicy(
        userId: 7,
        capabilities: capabilities(['seller', 'orders.view_all']),
      ),
    );
    addTearDown(controller.dispose);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.statusCounts[SaleOrderState.draft], 3);
    expect(controller.statusCounts[SaleOrderState.sale], 2);
    expect(controller.statusCounts[SaleOrderState.waitingApproval], 0);

    // Filtrar por un estado deja el mismo contador (no se recalcula al
    // filtrar) y acota la lista a ese estado.
    controller.setSelectedState(SaleOrderState.draft);
    await Future<void>.delayed(Duration.zero);
    expect(controller.snapshot.totalCount, 3);
    expect(controller.query.states, {SaleOrderState.draft});

    // Tocar el mismo estado otra vez lo quita, igual que un `ToggleButton`
    // que se puede desmarcar.
    controller.setSelectedState(SaleOrderState.draft);
    expect(controller.selectedState, isNull);
  });

  // 🔴 La otra prueba que exige el encargo: el aviso de pendiente de subir es
  // el mismo `syncState` que ya trae cada fila — una orden encolada lo
  // muestra, una ya sincronizada no.
  testWidgets(
    'una orden con operación pendiente en la cola muestra el icono de pendiente de subir, y la que no, no',
    (tester) async {
      final repository = _FakeOrderRepository(orders());
      addTearDown(repository.dispose);
      final policy = OrderFilterPolicy(
        userId: 7,
        capabilities: capabilities(['seller', 'orders.view_all']),
      );
      await tester.pumpWidget(
        FluentApp(
          home: OrdersScreen(repository: repository, policy: policy),
        ),
      );
      await tester.pumpAndSettle();

      // Filtro inicial del vendedor: «Mis ventas» (autor 7) — sólo o-1, que
      // está en cola.
      expect(find.text('Venta Sebastián'), findsOneWidget);
      expect(find.byIcon(FluentIcons.cloud_upload), findsOneWidget);

      // Con «Todas» entran también o-2 y o-4 (sincronizadas): el icono sigue
      // apareciendo sólo una vez, la de o-1 — las sincronizadas no lo traen.
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('Venta Sebastián'), findsOneWidget);
      expect(find.text('Venta Jacqueline'), findsOneWidget);
      expect(find.byIcon(FluentIcons.cloud_upload), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // 🔴 La prueba que pidió el equipo tras autorizar tocar
  // `runtime_order_reader.dart`: Vendedor, Subtotal e Impuestos ya los
  // calculó Odoo y viven en la fila — la pantalla los muestra, no los
  // recalcula.
  testWidgets(
    'una orden local con subtotal, impuestos y vendedor conocidos muestra las tres columnas',
    (tester) async {
      final repository = _FakeOrderRepository(const [
        OrderListItem(
          localId: 'o-amounts',
          title: 'Venta con importes',
          companyId: 1,
          authorId: 7,
          businessState: SaleOrderState.sale,
          syncState: OperationSyncState.synced,
          sellerName: 'Aldas Romero Erik Andres',
          amountUntaxed: 100,
          amountTax: 15,
          amountTotal: 115,
        ),
      ]);
      addTearDown(repository.dispose);
      final policy = OrderFilterPolicy(
        userId: 7,
        capabilities: capabilities(['seller', 'orders.view_all']),
      );
      await tester.pumpWidget(
        FluentApp(
          home: OrdersScreen(repository: repository, policy: policy),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aldas Romero Erik Andres'), findsOneWidget);
      expect(find.text('100.00'), findsOneWidget);
      expect(find.text('15.00'), findsOneWidget);
      expect(find.text('115.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // 🔴 Mientras la fila no traiga un importe real, la celda dice «—» — nunca
  // «0.00», que se leería como «esta orden no cobra nada» en vez de «este
  // dato todavía no llegó».
  testWidgets('una orden sin subtotal ni impuestos muestra guion, nunca cero', (
    tester,
  ) async {
    final repository = _FakeOrderRepository(const [
      OrderListItem(
        localId: 'o-sin-importes',
        title: 'Venta sin importes',
        companyId: 1,
        authorId: 7,
        businessState: SaleOrderState.sale,
        syncState: OperationSyncState.synced,
      ),
    ]);
    addTearDown(repository.dispose);
    final policy = OrderFilterPolicy(
      userId: 7,
      capabilities: capabilities(['seller', 'orders.view_all']),
    );
    await tester.pumpWidget(
      FluentApp(
        home: OrdersScreen(repository: repository, policy: policy),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Venta sin importes'), findsOneWidget);
    // Vendedor, Subtotal, Impuestos, Total (y otras columnas sin dato) en
    // guion — lo que importa es que ninguna caiga en «0.00».
    expect(find.text('—'), findsWidgets);
    expect(find.text('0.00'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
