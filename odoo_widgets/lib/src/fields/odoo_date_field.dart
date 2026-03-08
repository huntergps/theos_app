import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import '../base/odoo_field_base.dart';
import '../config/odoo_field_config.dart';
import '../theme/responsive.dart';

/// A date field with date picker.
///
/// Usage:
/// ```dart
/// OdooDateField(
///   config: OdooFieldConfig(
///     label: 'Order Date',
///     isEditing: isEditMode,
///     prefixIcon: FluentIcons.calendar,
///   ),
///   value: dateOrder,
///   onChanged: (date) => updateField('date_order', date),
/// )
///
/// // Stream mode — auto-refreshes:
/// OdooDateField(
///   config: OdooFieldConfig(label: 'Date', isEditing: true),
///   stream: dateStream,
///   onChanged: (date) => manager.updateField(id, 'date_order', date),
/// )
/// ```
class OdooDateField extends OdooFieldBase<DateTime> {
  final String dateFormat;
  final bool showTime;
  final DateTime? minDate;
  final DateTime? maxDate;
  final String locale;
  final String selectDateTitle;
  final String cancelLabel;
  final String acceptLabel;

  const OdooDateField({
    super.key,
    required super.config,
    required super.value,
    super.onChanged,
    super.stream,
    this.dateFormat = 'dd/MM/yyyy',
    this.showTime = false,
    this.minDate,
    this.maxDate,
    this.locale = 'es',
    this.selectDateTitle = 'Select date',
    this.cancelLabel = 'Cancel',
    this.acceptLabel = 'Accept',
  });

  @override
  String formatValue(DateTime? value) {
    if (value == null) return '-';
    final pattern = showTime ? '$dateFormat HH:mm' : dateFormat;
    return DateFormat(pattern, locale).format(value.toLocal());
  }

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, DateTime? effectiveValue) {
    final responsive = ResponsiveValues(context.deviceType);
    return buildViewLayout(
      context,
      theme,
      effectiveValue: effectiveValue,
      inline: true,
      labelWidth: responsive.labelWidth,
    );
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, DateTime? effectiveValue) {
    return buildInlineEditLayout(
      context,
      theme,
      child: _DatePickerInput(
        value: effectiveValue,
        showTime: showTime,
        minDate: minDate,
        maxDate: maxDate,
        onChanged: onChanged,
        dateFormat: dateFormat,
        locale: locale,
        selectDateTitle: selectDateTitle,
        cancelLabel: cancelLabel,
        acceptLabel: acceptLabel,
      ),
    );
  }
}

class _DatePickerInput extends StatelessWidget {
  final DateTime? value;
  final bool showTime;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<DateTime?>? onChanged;
  final String dateFormat;
  final String locale;
  final String selectDateTitle;
  final String cancelLabel;
  final String acceptLabel;

  const _DatePickerInput({
    required this.value,
    required this.showTime,
    this.minDate,
    this.maxDate,
    this.onChanged,
    required this.dateFormat,
    required this.locale,
    required this.selectDateTitle,
    required this.cancelLabel,
    required this.acceptLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final pattern = showTime ? '$dateFormat h:mm a' : dateFormat;
    final displayText = value != null
        ? DateFormat(pattern, locale).format(value!.toLocal())
        : '-';

    return HoverButton(
      onPressed: () => _showDatePicker(context),
      builder: (context, states) {
        final isHovered = states.isHovered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isHovered
                ? theme.accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: theme.typography.body?.copyWith(
                    color: theme.accentColor,
                  ),
                ),
              ),
              if (isHovered)
                Icon(FluentIcons.calendar,
                    size: 12, color: theme.accentColor),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = value ?? now;

    final selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => _DatePickerDialog(
        initialDate: initialDate,
        minDate: minDate,
        maxDate: maxDate,
        showTime: showTime,
        title: selectDateTitle,
        cancelLabel: cancelLabel,
        acceptLabel: acceptLabel,
      ),
    );

    if (selectedDate != null) {
      onChanged?.call(selectedDate);
    }
  }
}

class _DatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool showTime;
  final String title;
  final String cancelLabel;
  final String acceptLabel;

  const _DatePickerDialog({
    required this.initialDate,
    this.minDate,
    this.maxDate,
    required this.showTime,
    required this.title,
    required this.cancelLabel,
    required this.acceptLabel,
  });

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _selectedDate;
  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _hour = widget.initialDate.hour;
    _minute = widget.initialDate.minute;
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DatePicker(
            selected: _selectedDate,
            onChanged: (date) {
              setState(() {
                _selectedDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  _hour,
                  _minute,
                );
              });
            },
          ),
          if (widget.showTime) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  child: NumberBox<int>(
                    value: _hour,
                    min: 0,
                    max: 23,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _hour = value);
                      }
                    },
                    mode: SpinButtonPlacementMode.none,
                  ),
                ),
                const Text(' : '),
                SizedBox(
                  width: 60,
                  child: NumberBox<int>(
                    value: _minute,
                    min: 0,
                    max: 59,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _minute = value);
                      }
                    },
                    mode: SpinButtonPlacementMode.none,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        Button(
          child: Text(widget.cancelLabel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          child: Text(widget.acceptLabel),
          onPressed: () {
            final result = DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _hour,
              _minute,
            );
            Navigator.of(context).pop(result);
          },
        ),
      ],
    );
  }
}

/// A date range field for selecting start and end dates.
class OdooDateRangeField extends StatelessWidget {
  final OdooFieldConfig config;
  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?>? onStartChanged;
  final ValueChanged<DateTime?>? onEndChanged;
  final String dateFormat;
  final String locale;
  final String fromLabel;
  final String toLabel;

  const OdooDateRangeField({
    super.key,
    required this.config,
    this.startDate,
    this.endDate,
    this.onStartChanged,
    this.onEndChanged,
    this.dateFormat = 'dd/MM/yyyy',
    this.locale = 'es',
    this.fromLabel = 'From',
    this.toLabel = 'To',
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (!config.isEditing) {
      final formatter = DateFormat(dateFormat, locale);
      final startText =
          startDate != null ? formatter.format(startDate!) : '-';
      final endText = endDate != null ? formatter.format(endDate!) : '-';

      return Row(
        children: [
          if (config.prefixIcon != null) ...[
            Icon(config.prefixIcon, size: 14),
            const SizedBox(width: 8),
          ],
          Expanded(
            child:
                Text('$startText - $endText', style: theme.typography.body),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OdooDateField(
            config: OdooFieldConfig(label: fromLabel, isEditing: true),
            value: startDate,
            onChanged: onStartChanged,
            maxDate: endDate,
            dateFormat: dateFormat,
            locale: locale,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OdooDateField(
            config: OdooFieldConfig(label: toLabel, isEditing: true),
            value: endDate,
            onChanged: onEndChanged,
            minDate: startDate,
            dateFormat: dateFormat,
            locale: locale,
          ),
        ),
      ],
    );
  }
}

/// Backward-compatible aliases.
typedef ReactiveDateField = OdooDateField;
typedef ReactiveDateRangeField = OdooDateRangeField;
