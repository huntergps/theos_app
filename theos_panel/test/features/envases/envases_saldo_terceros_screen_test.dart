import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_saldo_terceros_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

EnvasesPartnerBalanceRow _row({
  int id = 1,
  int partnerId = 20,
  String partnerName = 'Cliente Demo',
  int productId = 10,
  String productName = 'Jaba 12',
  int warehouseId = 3,
  String warehouseName = 'Guayaquil',
  String role = 'custodia_cliente',
  double quantity = 4,
}) => EnvasesPartnerBalanceRow(
  id: id,
  locationId: 8,
  locationName: 'Custodia clientes',
  warehouseId: warehouseId,
  warehouseName: warehouseName,
  role: role,
  partnerId: partnerId,
  partnerName: partnerName,
  productId: productId,
  productName: productName,
  companyId: 1,
  quantity: quantity,
);

Widget _host(Stream<EnvasesSaldoTercerosSnapshot?> snapshots) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesSaldoTercerosScreen(snapshots: snapshots),
);

void main() {
  testWidgets(
    'shows balance rows from the cache, never touching the network',
    (tester) async {
      final controller = StreamController<EnvasesSaldoTercerosSnapshot?>();
      addTearDown(controller.close);
      await tester.pumpWidget(_host(controller.stream));
      controller.add(
        EnvasesSaldoTercerosSnapshot(
          rows: [_row()],
          cachedAt: DateTime.utc(2026, 9, 14),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cliente Demo'), findsOneWidget);
      expect(find.text('Jaba 12'), findsOneWidget);
      expect(find.textContaining('Guayaquil'), findsWidgets);
    },
  );

  testWidgets('never shows the raw envases_rol Selection value', (
    tester,
  ) async {
    final controller = StreamController<EnvasesSaldoTercerosSnapshot?>();
    addTearDown(controller.close);
    await tester.pumpWidget(_host(controller.stream));
    controller.add(
      EnvasesSaldoTercerosSnapshot(
        rows: [
          _row(role: 'custodia_cliente'),
          _row(
            id: 2,
            role: 'custodia_proveedor',
            partnerId: 21,
            partnerName: 'Proveedor Demo',
          ),
        ],
        cachedAt: DateTime.utc(2026, 9, 14),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('custodia_cliente'), findsNothing);
    expect(find.textContaining('custodia_proveedor'), findsNothing);
  });

  testWidgets(
    'groups a row with no partner under "Sin tercero identificado" instead of hiding it',
    (tester) async {
      final controller = StreamController<EnvasesSaldoTercerosSnapshot?>();
      addTearDown(controller.close);
      await tester.pumpWidget(_host(controller.stream));
      controller.add(
        EnvasesSaldoTercerosSnapshot(
          rows: [
            EnvasesPartnerBalanceRow(
              id: 3,
              locationId: 8,
              locationName: 'Custodia clientes',
              warehouseId: 3,
              warehouseName: 'Guayaquil',
              role: 'custodia_cliente',
              partnerId: null,
              partnerName: null,
              productId: 10,
              productName: 'Jaba 12',
              companyId: 1,
              quantity: 2,
            ),
          ],
          cachedAt: DateTime.utc(2026, 9, 14),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin tercero identificado'), findsOneWidget);
      expect(find.text('Jaba 12'), findsOneWidget);
    },
  );

  testWidgets('shows a clear empty state with zero rows', (tester) async {
    final controller = StreamController<EnvasesSaldoTercerosSnapshot?>();
    addTearDown(controller.close);
    await tester.pumpWidget(_host(controller.stream));
    controller.add(
      EnvasesSaldoTercerosSnapshot(
        rows: const [],
        cachedAt: DateTime.utc(2026, 9, 14),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin saldos'), findsOneWidget);
  });
}
