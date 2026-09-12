import 'package:flutter/widgets.dart';

import '../../app/theme/orbi_theme.dart';

enum OrbiLayoutSize { compact, medium, wide }

OrbiLayoutSize orbiLayoutSizeFor(double width) {
  if (width < OrbiTheme.compactBreakpoint) return OrbiLayoutSize.compact;
  if (width < OrbiTheme.mediumBreakpoint) return OrbiLayoutSize.medium;
  return OrbiLayoutSize.wide;
}

class OrbiAdaptiveLayout extends StatelessWidget {
  const OrbiAdaptiveLayout({
    super.key,
    required this.compact,
    required this.medium,
    required this.wide,
  });

  final Widget compact;
  final Widget medium;
  final Widget wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (orbiLayoutSizeFor(constraints.maxWidth)) {
          OrbiLayoutSize.compact => compact,
          OrbiLayoutSize.medium => medium,
          OrbiLayoutSize.wide => wide,
        };
      },
    );
  }
}
