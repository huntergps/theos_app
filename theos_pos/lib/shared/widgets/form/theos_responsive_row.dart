import 'package:fluent_ui/fluent_ui.dart';

/// A layout widget that displays children in a Row on desktop and Column on mobile.
class TheosResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double breakpoint;

  const TheosResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 12,
    this.breakpoint = 800,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > breakpoint;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                children
                    .map((child) {
                      return Expanded(child: child);
                    })
                    .expand((element) {
                      // Add spacing between elements
                      return [element, SizedBox(width: spacing)];
                    })
                    .toList()
                  ..removeLast(), // Remove the last spacer
          );
        } else {
          return Column(
            children: children.map((child) {
              return Padding(
                padding: EdgeInsets.only(bottom: runSpacing),
                child: child,
              );
            }).toList(),
          );
        }
      },
    );
  }
}
