import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/config_service.dart';

/// A reusable cell widget for displaying dates in a DataGrid.
/// Uses the global date format from ConfigService if no format is provided.
class TheosDateCell extends ConsumerWidget {
  final DateTime? value;
  final String? format;
  final AlignmentGeometry alignment;
  final TextStyle? style;
  final String placeholder;

  const TheosDateCell({
    super.key,
    required this.value,
    this.format,
    this.alignment = Alignment.centerLeft,
    this.style,
    this.placeholder = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String formattedValue = placeholder;

    if (value != null) {
      final config = ref.watch(configServiceProvider);
      final dateFormat = format ?? config.dateFormat;
      formattedValue = DateFormat(dateFormat, 'es').format(value!.toLocal());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: alignment,
      child: Text(
        formattedValue,
        style: style,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
