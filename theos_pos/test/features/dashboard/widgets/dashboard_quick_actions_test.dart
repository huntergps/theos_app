import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos/core/navigation/app_router.dart';
import 'package:theos_pos/core/theme/spacing.dart';
import 'package:theos_pos/features/dashboard/widgets/supervisor_dashboard.dart';
import 'package:theos_pos/shared/providers/menu_provider.dart';

void main() {
  testWidgets('only renders actions accepted by the route access provider', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasRouteAccessProvider(AppRouter.fastSale).overrideWithValue(true),
          hasRouteAccessProvider(AppRouter.sales).overrideWithValue(true),
          hasRouteAccessProvider(AppRouter.collection).overrideWithValue(false),
          hasRouteAccessProvider(AppRouter.sync).overrideWithValue(false),
        ],
        child: FluentApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nueva Venta'), findsOneWidget);
    expect(find.text('Ver Ordenes'), findsOneWidget);
    expect(find.text('Punto de Cobro'), findsNothing);
    expect(find.text('Sincronizar'), findsNothing);
  });

  testWidgets('every authorized quick action navigates to its guarded route', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          for (final action in dashboardQuickActionDefinitions)
            hasRouteAccessProvider(action.path).overrideWithValue(true),
        ],
        child: FluentApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    for (final action in dashboardQuickActionDefinitions) {
      router.go(AppRouter.home);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(action.key));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, action.path);
      expect(
        find.byKey(ValueKey<String>('destination:${action.path}')),
        findsOneWidget,
      );
    }
  });
}

GoRouter _router() => GoRouter(
  initialLocation: AppRouter.home,
  routes: [
    GoRoute(
      path: AppRouter.home,
      builder: (context, state) => const ScaffoldPage(
        content: DashboardQuickActions(spacing: ThemedSpacing(1)),
      ),
    ),
    for (final action in dashboardQuickActionDefinitions)
      GoRoute(
        path: action.path,
        builder: (context, state) =>
            SizedBox(key: ValueKey<String>('destination:${action.path}')),
      ),
  ],
);
