import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/orders/orders_contracts.dart';
import 'package:theos_panel/features/warehouse/warehouse_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

final class _Operations implements WarehouseOperationPort {
  int? validated;
  bool? backorderConfirmed;
  WarehouseValidationResult? validationResult;

  @override
  Future<WarehouseValidationResult> validatePicking({
    required int pickingId,
  }) async {
    validated = pickingId;
    return validationResult ??
        const WarehouseValidationResult(
          state: WarehouseValidationState.completed,
          message: 'Entrega validada.',
        );
  }

  @override
  Future<WarehouseValidationResult> resolveBackorder({
    required WarehouseValidationResult pending,
    required bool confirm,
  }) async {
    backorderConfirmed = confirm;
    return const WarehouseValidationResult(
      state: WarehouseValidationState.completed,
      message: 'Backorder confirmado; entrega parcial validada.',
    );
  }
}

final class _Repository implements OrderRepository {
  _Repository({this.pending = true, this.refreshError});

  final bool pending;
  final Object? refreshError;
  final _updates = StreamController<OrderSnapshot>.broadcast();

  @override
  Stream<OrderSnapshot> watch(OrderQuery query) {
    scheduleMicrotask(
      () => _updates.add(
        OrderSnapshot(
          status: OrderLoadStatus.data,
          totalCount: 1,
          items: [
            OrderListItem(
              localId: '1',
              title: 'ORBI-E2E-FSC',
              companyId: 1,
              authorId: 9,
              businessState: SaleOrderState.sale,
              syncState: OperationSyncState.synced,
              pickingIds: const [7],
              pendingCollection: pending,
            ),
          ],
          refreshError: refreshError,
        ),
      ),
    );
    return _updates.stream;
  }

  @override
  Future<void> refresh(OrderQuery query) async {}

  Future<void> dispose() => _updates.close();
}

void main() {
  testWidgets('warehouse locks delivery while payment is pending', (
    tester,
  ) async {
    final repository = _Repository();
    final operations = _Operations();
    addTearDown(repository.dispose);
    final capabilities = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: const ['warehouse'],
    );
    await tester.pumpWidget(
      FluentApp(theme: OrbiFluentTheme.light,
        home: WarehouseScreen(
          repository: repository,
          operations: operations,
          policy: OrderFilterPolicy(userId: 34, capabilities: capabilities),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bodega'), findsOneWidget);
    expect(
      find.text('Entrega bloqueada: se requiere cobro completo.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('warehouse validates a paid picking through the injected port', (
    tester,
  ) async {
    final repository = _Repository(pending: false);
    final operations = _Operations();
    addTearDown(repository.dispose);
    final capabilities = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: const ['warehouse'],
    );
    await tester.pumpWidget(
      FluentApp(theme: OrbiFluentTheme.light,
        home: WarehouseScreen(
          repository: repository,
          operations: operations,
          policy: OrderFilterPolicy(userId: 34, capabilities: capabilities),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validar entrega'));
    await tester.pumpAndSettle();
    expect(operations.validated, 7);
    expect(find.text('Entrega validada.'), findsOneWidget);
  });

  testWidgets('warehouse exposes explicit backorder confirmation', (
    tester,
  ) async {
    final repository = _Repository(pending: false);
    final operations = _Operations()
      ..validationResult = const WarehouseValidationResult(
        state: WarehouseValidationState.backorderRequired,
        message: 'Faltan unidades.',
        action: {'res_id': 17},
      );
    addTearDown(repository.dispose);
    final capabilities = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: const ['warehouse'],
    );
    await tester.pumpWidget(
      FluentApp(theme: OrbiFluentTheme.light,
        home: WarehouseScreen(
          repository: repository,
          operations: operations,
          policy: OrderFilterPolicy(userId: 34, capabilities: capabilities),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validar entrega'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar backorder'), findsOneWidget);
    expect(find.text('Cerrar sin backorder'), findsOneWidget);
    await tester.tap(find.byKey(const Key('backorder-confirm-button')));
    await tester.pumpAndSettle();
    expect(operations.backorderConfirmed, isTrue);
    expect(
      find.text('Backorder confirmado; entrega parcial validada.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'warehouse shows a refresh-error warning instead of going silently '
    'empty, and keeps showing the locally cached list underneath',
    (tester) async {
      // 🔴 Causa raíz medida en Mepriga (14-sep-2026): antes,
      // `ScopeOrderRepository.refresh` se tragaba CUALQUIER fallo del
      // refresco en línea (`catch (_) {}`) y Bodega quedaba vacía sin decir
      // por qué. Ahora el error viaja en `OrderSnapshot.refreshError` y la
      // pantalla lo cuenta sin apagar lo que sí hay en el equipo.
      final repository = _Repository(
        pending: false,
        refreshError: Exception('conexión perdida'),
      );
      final operations = _Operations();
      addTearDown(repository.dispose);
      final capabilities = CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime(2026),
        permissions: const ['warehouse'],
      );
      await tester.pumpWidget(
        FluentApp(
          theme: OrbiFluentTheme.light,
          home: WarehouseScreen(
            repository: repository,
            operations: operations,
            policy: OrderFilterPolicy(userId: 34, capabilities: capabilities),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('warehouse-refresh-error')), findsOneWidget);
      expect(
        find.textContaining('No se pudo actualizar desde Odoo'),
        findsWidgets,
      );
      expect(find.textContaining('conexión perdida'), findsOneWidget);
      expect(
        find.textContaining('Se muestra lo guardado en el equipo'),
        findsOneWidget,
      );
      // The locally cached order is still there: a refresh error is not a
      // reason to hide what the device already has.
      expect(find.text('ORBI-E2E-FSC'), findsOneWidget);
    },
  );
}
