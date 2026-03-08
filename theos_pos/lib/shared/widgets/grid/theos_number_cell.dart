import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

/// A generic cell widget for displaying numbers in a DataGrid.
/// Supports currency, integers, and custom decimal places.
class TheosNumberCell extends StatelessWidget {
  final num value;
  final bool isBold;
  final String? currencySymbol;
  final int? decimalPlaces;
  final AlignmentGeometry alignment;
  final TextStyle? style;

  const TheosNumberCell({
    super.key,
    required this.value,
    this.isBold = false,
    this.currencySymbol,
    this.decimalPlaces,
    this.alignment = Alignment.centerRight,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    String formattedValue;

    if (currencySymbol != null) {
      // Currency formatting
      final format = NumberFormat.currency(
        symbol: currencySymbol,
        decimalDigits: decimalPlaces ?? 2,
      );
      formattedValue = format.format(value);
    } else {
      // General number formatting
      if (decimalPlaces != null) {
        final format = NumberFormat.decimalPatternDigits(
          decimalDigits: decimalPlaces!,
        );
        formattedValue = format.format(value);
      } else {
        // Auto-detect: integer or decimal
        if (value is int || value == value.roundToDouble()) {
          formattedValue = NumberFormat.decimalPattern().format(value);
        } else {
          formattedValue = NumberFormat.decimalPatternDigits(
            decimalDigits: 2,
          ).format(value);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: alignment,
      child: Text(
        formattedValue,
        style:
            style ??
            (isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
      ),
    );
  }
}
