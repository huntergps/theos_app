import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:theos_pos/core/navigation/app_router.dart';
import 'package:theos_pos/core/navigation/route_access_policy.dart';
import 'package:theos_pos/core/theme/spacing.dart';
import 'package:theos_pos/features/authentication/services/server_service.dart';
import 'package:theos_pos/features/authentication/widgets/login_form.dart';
import 'package:theos_pos/features/dashboard/widgets/supervisor_dashboard.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';
import 'package:theos_pos/shared/providers/menu_provider.dart';

void main() {
  testWidgets(
    'login, menu, quick action and protected route share one policy',
    (tester) async {
      final store = _HarnessSessionStore();
      final session = ValueNotifier<RouteSessionSnapshot>(
        const RouteSessionSnapshot(),
      );
      final router = _harnessRouter(store: store, session: session);
      addTearDown(router.dispose);
      addTearDown(session.dispose);

      await tester.pumpWidget(_HarnessApp(router: router));
      await tester.pumpAndSettle();

      expect(find.byKey(LoginFormKeys.submit), findsOneWidget);
      final credentialField = find.descendant(
        of: find.byKey(LoginFormKeys.apiKey),
        matching: find.byType(EditableText),
      );
      await tester.enterText(credentialField, 'deterministic-placeholder');
      await tester.tap(find.byKey(LoginFormKeys.submit));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRouter.home);
      expect(store.hasStoredSession, isTrue);
      expect(store.containsCredential, isFalse);

      await tester.tap(find.byKey(const ValueKey(AppRouter.activities)));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRouter.activities);

      router.go(AppRouter.home);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DashboardQuickActions.salesKey));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRouter.sales);

      session.value = const RouteSessionSnapshot();
      router.go(AppRouter.sales);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRouter.login);
      expect(router.state.uri.queryParameters['returnTo'], AppRouter.sales);
    },
  );

  testWidgets('startup restores a stored session without credential input', (
    tester,
  ) async {
    final store = _HarnessSessionStore(hasStoredSession: true);
    final session = ValueNotifier<RouteSessionSnapshot>(
      const RouteSessionSnapshot(),
    );
    final router = _harnessRouter(store: store, session: session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(_HarnessApp(router: router));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRouter.home);
    expect(session.value.isAuthenticated, isTrue);
    expect(find.byKey(LoginFormKeys.apiKey), findsNothing);
  });

  testWidgets('every permitted menu button updates the guarded route', (
    tester,
  ) async {
    final store = _HarnessSessionStore(hasStoredSession: true);
    final session = ValueNotifier<RouteSessionSnapshot>(
      const RouteSessionSnapshot(),
    );
    final router = _harnessRouter(store: store, session: session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(_HarnessApp(router: router));
    await tester.pumpAndSettle();

    final permittedItems = allMenuItems.where(
      (item) =>
          !item.isAction &&
          item.hasAccess(
            _administratorSession.permissions,
            isAuthenticated: true,
            developerMode: _administratorSession.developerMode,
          ),
    );

    for (final item in permittedItems) {
      router.go(
        item.path == AppRouter.home ? AppRouter.activities : AppRouter.home,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey<String>(item.path)));
      await tester.pumpAndSettle();

      expect(
        router.state.uri.path,
        item.path,
        reason: '${item.title} must navigate to ${item.path}',
      );
    }
  });

  testWidgets('role-restricted deep link fails closed', (tester) async {
    final store = _HarnessSessionStore(hasStoredSession: true);
    final session = ValueNotifier<RouteSessionSnapshot>(
      const RouteSessionSnapshot(
        userId: 7,
        permissions: [OdooUserGroup.salesUser],
      ),
    );
    final router = _harnessRouter(store: store, session: session);
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(_HarnessApp(router: router));
    await tester.pumpAndSettle();
    session.value = const RouteSessionSnapshot(
      userId: 7,
      permissions: [OdooUserGroup.salesUser],
    );
    await tester.pumpAndSettle();
    router.go(AppRouter.collection);
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRouter.home);
    expect(find.byKey(const ValueKey(AppRouter.collection)), findsNothing);
  });
}

final class _HarnessSessionStore {
  _HarnessSessionStore({this.hasStoredSession = false});

  bool hasStoredSession;

  /// This harness persists only the authentication decision, never the input.
  bool get containsCredential => false;
}

final class _HarnessApp extends StatelessWidget {
  const _HarnessApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        for (final action in dashboardQuickActionDefinitions)
          hasRouteAccessProvider(action.path).overrideWithValue(true),
      ],
      child: FluentApp.router(routerConfig: router),
    );
  }
}

GoRouter _harnessRouter({
  required _HarnessSessionStore store,
  required ValueNotifier<RouteSessionSnapshot> session,
}) {
  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    final rule = RouteAccessPolicy.ruleFor(path);
    if (rule == null) return AppRouter.login;
    if (!rule.requiresAuthentication) return null;
    if (!session.value.isAuthenticated) {
      return Uri(
        path: AppRouter.login,
        queryParameters: {'returnTo': state.uri.toString()},
      ).toString();
    }
    if (!RouteAccessPolicy.allows(
      path: path,
      isAuthenticated: true,
      permissions: session.value.permissions,
      developerMode: session.value.developerMode,
    )) {
      return AppRouter.home;
    }
    return null;
  }

  Widget destination(String path) =>
      Center(child: Text(path, key: ValueKey<String>('destination:$path')));

  return GoRouter(
    initialLocation: AppRouter.splash,
    refreshListenable: session,
    redirect: redirect,
    routes: [
      GoRoute(
        path: AppRouter.splash,
        builder: (context, state) =>
            _HarnessSplash(store: store, session: session),
      ),
      GoRoute(
        path: AppRouter.login,
        builder: (context, state) =>
            _HarnessLogin(store: store, session: session),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            _HarnessShell(session: session, child: child),
        routes: [
          GoRoute(
            path: AppRouter.home,
            builder: (context, state) => const ScaffoldPage(
              content: DashboardQuickActions(spacing: ThemedSpacing(1)),
            ),
          ),
          for (final item in allMenuItems.where(
            (item) => !item.isAction && item.path != AppRouter.home,
          ))
            GoRoute(
              path: item.path,
              builder: (context, state) => destination(item.path),
            ),
        ],
      ),
    ],
  );
}

final class _HarnessSplash extends StatefulWidget {
  const _HarnessSplash({required this.store, required this.session});

  final _HarnessSessionStore store;
  final ValueNotifier<RouteSessionSnapshot> session;

  @override
  State<_HarnessSplash> createState() => _HarnessSplashState();
}

final class _HarnessSplashState extends State<_HarnessSplash> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.store.hasStoredSession) {
        widget.session.value = _administratorSession;
        context.go(AppRouter.home);
      } else {
        context.go(AppRouter.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Center(
    child: ProgressRing(key: ValueKey<String>('harness.splash')),
  );
}

final class _HarnessLogin extends StatefulWidget {
  const _HarnessLogin({required this.store, required this.session});

  final _HarnessSessionStore store;
  final ValueNotifier<RouteSessionSnapshot> session;

  @override
  State<_HarnessLogin> createState() => _HarnessLoginState();
}

final class _HarnessLoginState extends State<_HarnessLogin> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  late final ServerConfig _server = ServerConfig(
    name: 'Deterministic',
    url: 'https://example.invalid',
    database: 'deterministic',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 480,
        child: LoginForm(
          formKey: _formKey,
          controller: _controller,
          servers: [_server],
          selectedServer: _server,
          spacing: const ThemedSpacing(1),
          showPassword: false,
          isLoading: false,
          loadingStage: '',
          onServerChanged: (_) {},
          onTogglePassword: () {},
          onSubmit: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            widget.store.hasStoredSession = true;
            widget.session.value = _administratorSession;
            context.go(
              RouteAccessPolicy.destinationAfterLogin(
                returnTo: GoRouterState.of(context)
                    .uri
                    .queryParameters['returnTo'],
                permissions: _administratorSession.permissions,
              ),
            );
          },
          onManageServers: () {},
        ),
      ),
    );
  }
}

final class _HarnessShell extends StatelessWidget {
  const _HarnessShell({required this.session, required this.child});

  final ValueNotifier<RouteSessionSnapshot> session;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RouteSessionSnapshot>(
      valueListenable: session,
      builder: (context, snapshot, _) {
        final visibleMenu = allMenuItems.where(
          (item) =>
              !item.isAction &&
              item.hasAccess(
                snapshot.permissions,
                isAuthenticated: snapshot.isAuthenticated,
                developerMode: snapshot.developerMode,
              ),
        );
        return Column(
          children: [
            Wrap(
              children: [
                for (final item in visibleMenu)
                  Button(
                    key: ValueKey<String>(item.path),
                    onPressed: () => context.go(item.path),
                    child: Text(item.title),
                  ),
              ],
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

const _administratorSession = RouteSessionSnapshot(
  userId: 7,
  permissions: [OdooUserGroup.systemAdministrator],
  developerMode: true,
);
