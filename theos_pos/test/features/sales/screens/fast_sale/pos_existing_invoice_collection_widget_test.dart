import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/adaptive/adaptive_layout_policy.dart';
import 'package:theos_pos/core/database/providers.dart';
import 'package:theos_pos/features/sales/providers/service_providers.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/fast_sale_providers.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_payment_providers.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_payment_tab.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/touch_actions_fab.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  testWidgets(
    'posted invoice button collects only new lines and blocks double tap/retry',
    (tester) async {
      final invoiceLoad = Completer<List<AccountMove>>();
      final collected = <({String operationUuid, List<PaymentLine> lines})>[];
      var queuedReads = 0;
      var reloads = 0;
      final queued = _payment('queued-line', 2);
      final fresh = _payment('fresh-line', 3);
      final tab = FastSaleTabState(
        orderId: 42,
        orderName: 'SO42',
        order: const SaleOrder(
          id: 42,
          name: 'SO42',
          state: SaleOrderState.sale,
          invoiceStatus: InvoiceStatus.invoiced,
        ),
      );
      final gateway = ExistingInvoiceCollectionUiGateway(
        loadInvoices: (_) => invoiceLoad.future,
        loadQueuedLineUuids: (_) async {
          queuedReads++;
          return queuedReads == 1
              ? {'queued-line'}
              : {'queued-line', 'fresh-line'};
        },
        collect:
            ({
              required saleOrderId,
              required invoiceId,
              required collectionSessionId,
              required operatorId,
              required operationUuid,
              required lines,
            }) async {
              expect(saleOrderId, 42);
              expect(invoiceId, 501);
              expect(collectionSessionId, 8);
              expect(operatorId, 23);
              collected.add((operationUuid: operationUuid, lines: lines));
              return 9001;
            },
        reloadPaymentLines: (_) async => reloads++,
      );
      final container = ProviderContainer(
        overrides: [
          fastSaleActiveTabProvider.overrideWithValue(tab),
          posPaymentLinesProvider.overrideWithValue([queued, fresh]),
          posWithholdLinesProvider.overrideWithValue(const []),
          posAvailableJournalsProvider.overrideWith((_) async => const []),
          fastSaleInputCapabilitiesProvider.overrideWithValue(
            const AdaptiveInputCapabilities(touch: true),
          ),
          existingInvoiceCollectionUiGatewayProvider.overrideWithValue(gateway),
          paymentServiceProvider.overrideWith(
            (_) => throw StateError('invoice-creation service was resolved'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(currentSessionProvider.notifier)
          .set(
            const CollectionSession(
              id: 8,
              name: 'Caja 8',
              state: SessionState.opened,
              userId: 23,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FluentApp(home: POSPaymentTab()),
        ),
      );
      await tester.pump();
      expect(find.byType(POSPaymentTab), findsOneWidget);
      expect(find.text('Guardar y Facturar'), findsOneWidget);

      await tester.tap(find.text('Guardar y Facturar'));
      await tester.tap(find.text('Guardar y Facturar'));
      await tester.pump();
      expect(collected, isEmpty);

      invoiceLoad.complete([
        const AccountMove(
          id: 501,
          name: 'FAC/501',
          moveType: 'out_invoice',
          state: 'posted',
          amountResidual: 10,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(collected, hasLength(1));
      expect(collected.single.lines, [fresh]);
      expect(
        collected.single.operationUuid,
        existingInvoiceCollectionOperationUuid(501, [fresh]),
      );
      expect(reloads, 1);

      await tester.tap(find.text('Guardar y Facturar'));
      await tester.pumpAndSettle();
      expect(collected, hasLength(1));
      expect(reloads, 1);
      expect(queuedReads, 2);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

PaymentLine _payment(String uuid, double amount) => PaymentLine(
  lineUuid: uuid,
  type: PaymentLineType.payment,
  date: DateTime(2026, 9, 5),
  amount: amount,
  journalId: 4,
  paymentMethodLineId: 6,
);
