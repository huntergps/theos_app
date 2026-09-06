import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/shared/screens/main_screen.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required double topInset,
    Brightness brightness = Brightness.light,
    double? viewPaddingTop,
    PaneDisplayMode? displayMode,
  }) async {
    const bodyKey = ValueKey<String>('shell-body');
    await tester.pumpWidget(
      FluentApp(
        theme: FluentThemeData(brightness: Brightness.light),
        darkTheme: FluentThemeData(brightness: Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(1024, 768),
            padding: EdgeInsets.only(top: topInset),
            viewPadding: EdgeInsets.only(top: viewPaddingTop ?? topInset),
          ),
          child: NavigationView(
            titleBar: const SingleInsetTitleBar(
              key: appShellHeaderKey,
              content: Text('Caja POS', key: appShellHeaderContentKey),
            ),
            pane: displayMode == null
                ? null
                : NavigationPane(
                    displayMode: displayMode,
                    selected: 0,
                    items: [
                      PaneItem(
                        icon: const Icon(FluentIcons.home),
                        title: const Text('Inicio'),
                        body: const ColoredBox(
                          key: bodyKey,
                          color: Color(0xFF00AA00),
                        ),
                      ),
                    ],
                  ),
            content: displayMode == null
                ? const ColoredBox(key: bodyKey, color: Color(0xFF00AA00))
                : null,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('top inset expands header and only offsets its content', (
    tester,
  ) async {
    await pumpShell(tester, topInset: 24);

    final backgroundRect = tester.getRect(find.byKey(appShellHeaderKey));
    final contentRect = tester.getRect(find.byKey(appShellHeaderContentKey));
    final bodyRect = tester.getRect(find.byKey(const ValueKey('shell-body')));
    final navigationRect = tester.getRect(find.byType(NavigationView));
    final headerColor = tester
        .widget<ColoredBox>(
          find.descendant(
            of: find.byKey(appShellHeaderKey),
            matching: find.byType(ColoredBox),
          ),
        )
        .color;
    final theme = FluentTheme.of(
      tester.element(find.byKey(appShellHeaderContentKey)),
    );

    expect(backgroundRect.top, 0);
    expect(backgroundRect.height, appShellHeaderHeight + 24);
    expect(contentRect.top, greaterThanOrEqualTo(24));
    expect(bodyRect.top, backgroundRect.bottom);
    expect(backgroundRect.left, navigationRect.left);
    expect(backgroundRect.right, navigationRect.right);
    expect(headerColor, theme.scaffoldBackgroundColor);
    expect(headerColor, isNot(const Color(0xFF000000)));
  });

  testWidgets('zero inset keeps desktop header at its base height', (
    tester,
  ) async {
    await pumpShell(tester, topInset: 0, brightness: Brightness.dark);

    final backgroundRect = tester.getRect(find.byKey(appShellHeaderKey));
    final contentRect = tester.getRect(find.byKey(appShellHeaderContentKey));
    final bodyRect = tester.getRect(find.byKey(const ValueKey('shell-body')));
    final navigationRect = tester.getRect(find.byType(NavigationView));
    final headerColor = tester
        .widget<ColoredBox>(
          find.descendant(
            of: find.byKey(appShellHeaderKey),
            matching: find.byType(ColoredBox),
          ),
        )
        .color;
    final theme = FluentTheme.of(
      tester.element(find.byKey(appShellHeaderContentKey)),
    );

    expect(
      backgroundRect,
      Rect.fromLTWH(navigationRect.left, 0, navigationRect.width, 50),
    );
    expect(contentRect.top, 0);
    expect(bodyRect.top, 50);
    expect(headerColor, theme.scaffoldBackgroundColor);
  });

  testWidgets('compact pane offsets body by the effective header', (
    tester,
  ) async {
    await pumpShell(tester, topInset: 24, displayMode: PaneDisplayMode.compact);
    final headerRect = tester.getRect(find.byKey(appShellHeaderKey));
    final bodyRect = tester.getRect(find.byKey(const ValueKey('shell-body')));

    expect(headerRect.height, 74);
    expect(bodyRect.top, headerRect.bottom);
  });

  testWidgets('an already consumed safe inset is not applied twice', (
    tester,
  ) async {
    await pumpShell(tester, topInset: 0, viewPaddingTop: 24);

    final headerRect = tester.getRect(find.byKey(appShellHeaderKey));
    final contentRect = tester.getRect(find.byKey(appShellHeaderContentKey));
    final bodyRect = tester.getRect(find.byKey(const ValueKey('shell-body')));

    expect(headerRect.height, 50);
    expect(contentRect.top, 0);
    expect(bodyRect.top, 50);
  });
}
