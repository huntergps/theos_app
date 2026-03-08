import 'package:fluent_ui/fluent_ui.dart';

// =============================================================================
// MODEL STATUS BAR - Generic visual step indicator like Odoo (Chevron/Arrow style)
// Can be used with any model (sale.order, collection.session, etc.)
// =============================================================================

/// Represents a step in the status bar
class StatusStep<T> {
  final String label;
  final T value;
  final Color? color; // Optional custom color for this step

  const StatusStep({required this.label, required this.value, this.color});
}

/// Generic status bar widget that works with any enum or value type
class ModelStatusBar<T> extends StatelessWidget {
  final T currentValue;
  final List<StatusStep<T>> steps;
  final double height;
  final double fontSize;

  const ModelStatusBar({
    super.key,
    required this.currentValue,
    required this.steps,
    this.height = 23,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final currentIndex = steps.indexWhere((s) => s.value == currentValue);

    // Check screen width to determine if it's desktop or mobile/tablet
    // 600 is a common breakpoint for tablets.
    // If width > 600 (or other value preferred for "desktop"), use 30, else 23.
    // Or check if user provided a specific height override.
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop =
        screenWidth >
        600; // Using 600 as simplified breakpoint or import constants if available
    final responsiveHeight = isDesktop ? 30.0 : 23.0;

    return Container(
      height: responsiveHeight,
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(6),
      ),
      // Clip to ensure the first and last items follow the container's border radius
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = currentValue == step.value;
          final isPast = index < currentIndex;
          final isFirst = index == 0;
          final isLast = index == steps.length - 1;

          return Expanded(
            child: _ChevronStep(
              label: step.label,
              isActive: isActive,
              isPast: isPast,
              isFirst: isFirst,
              isLast: isLast,
              accentColor: step.color ?? theme.accentColor,
              fontSize: fontSize,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Chevron step widget with arrow shape
class _ChevronStep extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isPast;
  final bool isFirst;
  final bool isLast;
  final Color accentColor;
  final double fontSize;

  const _ChevronStep({
    required this.label,
    required this.isActive,
    required this.isPast,
    required this.isFirst,
    required this.isLast,
    required this.accentColor,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Determine colors based on state
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    if (isActive) {
      backgroundColor = accentColor;
      textColor = Colors.white;
      borderColor = accentColor;
    } else if (isPast) {
      backgroundColor = theme.resources.subtleFillColorSecondary;
      textColor = theme.resources.textFillColorPrimary;
      borderColor = theme.resources.controlStrokeColorDefault;
    } else {
      backgroundColor = theme.resources.subtleFillColorSecondary;
      textColor = theme.resources.textFillColorTertiary;
      borderColor = theme.resources.controlStrokeColorDefault;
    }

    const arrowWidth = 12.0;

    return CustomPaint(
      painter: _ChevronPainter(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        isFirst: isFirst,
        isLast: isLast,
        arrowWidth: arrowWidth,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          // Add padding on the left if not first (to account for the indentation)
          left: isFirst ? 12 : 12 + arrowWidth / 2,
          // Add padding on the right if not last (to account for the arrow point)
          right: isLast ? 12 : 12 + arrowWidth / 2,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

// Custom painter for chevron/arrow shape
class _ChevronPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final bool isFirst;
  final bool isLast;
  final double arrowWidth;

  _ChevronPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.isFirst,
    required this.isLast,
    required this.arrowWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    final w = size.width;
    final h = size.height;

    // 1. Top Edge
    // Start at top-left
    if (isFirst) {
      path.moveTo(0, 0);
    } else {
      path.moveTo(0, 0);
    }

    // Draw to top-right
    if (isLast) {
      path.lineTo(w, 0);
    } else {
      path.lineTo(w - arrowWidth, 0);
    }

    // 2. Right Edge
    if (isLast) {
      // Flat right edge
      path.lineTo(w, h);
    } else {
      // Arrow point
      path.lineTo(w, h / 2);
      path.lineTo(w - arrowWidth, h);
    }

    // 3. Bottom Edge
    // Draw to bottom-left
    if (isFirst) {
      path.lineTo(0, h);
    } else {
      path.lineTo(0, h);
    }

    // 4. Left Edge
    if (isFirst) {
      // Flat left edge
      path.lineTo(0, 0);
    } else {
      // Indented arrow
      path.lineTo(arrowWidth, h / 2);
      path.lineTo(0, 0);
    }

    path.close();

    // Draw fill
    canvas.drawPath(path, paint);

    // Draw border
    // Note: If you want adjacent borders to overlap perfectly without double thickness, logic might need adjustment.
    // But for now, drawing the stroke around the path is standard.
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast;
  }
}
