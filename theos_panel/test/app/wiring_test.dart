import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/bootstrap.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/features/auth/route_access_policy.dart';

void main() {
  test('reduced-motion falls back to platform accessibility features', () {
    expect(
      bootstrapDisableAnimations(
        mediaQueryDisableAnimations: null,
        platformDisableAnimations: true,
      ),
      isTrue,
    );
    expect(
      bootstrapDisableAnimations(
        mediaQueryDisableAnimations: false,
        platformDisableAnimations: true,
      ),
      isFalse,
    );
  });

  testWidgets('bootstrap content crossfades with overlapping surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      const FluentApp(
        home: BootstrapAnimatedContent(
          phaseKey: 'splash',
          child: ColoredBox(
            key: ValueKey('splash-surface'),
            color: Color(0xFFFF0000),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      const FluentApp(
        home: BootstrapAnimatedContent(
          phaseKey: 'application',
          child: ColoredBox(
            key: ValueKey('application-surface'),
            color: Color(0xFF00FF00),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('splash-surface')), findsOneWidget);
    expect(find.byKey(const ValueKey('application-surface')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('splash-surface')), findsNothing);
    expect(find.byKey(const ValueKey('application-surface')), findsOneWidget);
  });

  testWidgets('bootstrap renders before FluentApp provides Directionality', (
    tester,
  ) async {
    // Production mounts BootstrapAnimatedContent above FluentApp. Keep this
    // exact topology covered: a directional Stack alignment crashes the real
    // runner before it can paint the splash or login surface.
    await tester.pumpWidget(
      const BootstrapAnimatedContent(
        phaseKey: 'splash',
        child: ColoredBox(color: Color(0xFF008080)),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  test('splash budget waits only for the remaining fast-start time', () async {
    final delays = <Duration>[];

    await ensureMinimumSplashDuration(
      elapsed: const Duration(milliseconds: 400),
      delay: (duration) {
        delays.add(duration);
        return Future<void>.value();
      },
    );

    expect(delays, [const Duration(milliseconds: 800)]);
  });

  test('slow initialization does not add another splash delay', () async {
    var delayCalled = false;

    await ensureMinimumSplashDuration(
      elapsed: const Duration(milliseconds: 1201),
      delay: (duration) {
        delayCalled = true;
        return Future<void>.value();
      },
    );

    expect(delayCalled, isFalse);
  });

  test('route policy keeps shell available without capabilities', () {
    const policy = RouteAccessPolicy();
    expect(policy.allows('/', authenticated: true, capabilities: null), isTrue);
    expect(
      policy.allows('/sales', authenticated: true, capabilities: null),
      isFalse,
    );
  });

  test('business menu permissions are capability based', () {
    final snapshot = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: const ['seller', 'notifications'],
    );
    const policy = RouteAccessPolicy();
    expect(
      policy.allows('/sales', authenticated: true, capabilities: snapshot),
      isTrue,
    );
    expect(
      policy.allows('/collection', authenticated: true, capabilities: snapshot),
      isFalse,
    );
    expect(
      policy.allows(
        '/notifications',
        authenticated: true,
        capabilities: snapshot,
      ),
      isTrue,
    );
  });

  test('default composition has no service masquerading as configured', () {
    const composition = OrbiSessionComposition();
    expect(composition.home, isNull);
    expect(composition.sync, isNull);
    expect(composition.notifications, isNull);
    expect(composition.documents, isNull);
    expect(composition.runtime, isNull);
  });
}
