import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/fast_sale_providers.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_order_tabs.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';
import 'package:theos_pos/shared/providers/user_provider.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class _TestUserNotifier extends UserNotifier {
  _TestUserNotifier(this.user);
  final User user;

  @override
  User? build() => user;
}

void main() {
  User user(int id, List<String> permissions) => User(
    id: id,
    name: 'User $id',
    login: 'user$id',
    permissions: permissions,
  );

  test('seller defaults to mine and can explicitly select all', () {
    final seller = user(43, const [OdooUserGroup.salesUser]);

    final mine = resolveFastSaleOrderAccess(
      user: seller,
      audience: FastSaleOrderAudience.mine,
      configs: const [],
      sessions: const [],
    );
    final all = resolveFastSaleOrderAccess(
      user: seller,
      audience: FastSaleOrderAudience.all,
      configs: const [],
      sessions: const [],
    );

    expect(mine.sellerUserId, 43);
    expect(all.sellerUserId, isNull);
  });

  test(
    'cashier is scoped by assigned configs and all their cached sessions',
    () {
      final cashier = user(23, const [OdooUserGroup.collectionUser]);
      const assigned = CollectionConfig(
        id: 5,
        name: 'Caja 5',
        code: 'C5',
        companyId: 2,
        userIds: [23],
      );
      const foreign = CollectionConfig(
        id: 6,
        name: 'Caja 6',
        code: 'C6',
        companyId: 3,
        userIds: [99],
      );
      const open = CollectionSession(
        id: 18,
        name: 'S18',
        state: SessionState.opened,
        configId: 5,
      );
      const closed = CollectionSession(
        id: 17,
        name: 'S17',
        state: SessionState.closed,
        configId: 5,
      );
      const unauthorized = CollectionSession(
        id: 99,
        name: 'S99',
        state: SessionState.opened,
        configId: 6,
      );

      final access = resolveFastSaleOrderAccess(
        user: cashier,
        audience: FastSaleOrderAudience.mine,
        configs: const [assigned, foreign],
        sessions: const [open, closed, unauthorized],
      );

      expect(access.sellerUserId, isNull);
      expect(access.companyIds, [2]);
      expect(access.collectionSessionIds, containsAll(<int>[17, 18]));
      expect(access.collectionSessionIds, isNot(contains(99)));
      expect(access.states, ['sale']);
      expect(access.invoiceStatuses, ['to invoice']);
    },
  );

  test('cashier without assigned config fails closed', () {
    final access = resolveFastSaleOrderAccess(
      user: user(23, const [OdooUserGroup.collectionUser]),
      audience: FastSaleOrderAudience.all,
      configs: const [],
      sessions: const [],
    );

    expect(access.companyIds, isEmpty);
  });

  test(
    'refresh syncs online and leaves offline cache immediately usable',
    () async {
      var calls = 0;

      expect(
        await refreshFastSaleOrderHeaders(
          isOnline: false,
          sync: () async {
            calls++;
          },
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(
        await refreshFastSaleOrderHeaders(
          isOnline: true,
          sync: () async {
            calls++;
          },
        ),
        isTrue,
      );
      expect(calls, 1);
    },
  );

  testWidgets('seller scope control is visible while cashier scope is fixed', (
    tester,
  ) async {
    Future<void> pump(User currentUser) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            userProvider.overrideWith(() => _TestUserNotifier(currentUser)),
          ],
          child: const FluentApp(home: POSOrderTabs()),
        ),
      );
      await tester.pump();
    }

    await pump(user(43, const [OdooUserGroup.salesUser]));
    expect(find.text('Mis ventas'), findsOneWidget);

    await pump(user(23, const [OdooUserGroup.collectionUser]));
    expect(find.text('Mis ventas'), findsNothing);
    expect(find.byTooltip('Actualizar órdenes'), findsOneWidget);
  });
}
