import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

/// Adaptadores de formulario que envuelven los widgets Reactive* para uso simplificado.
///
/// Estos widgets son para formularios simples donde no se necesita el modo vista.
/// Para formularios con modo vista/edición, usar los widgets Reactive* directamente.

/// Campo de texto para formularios
///
/// Uso con value:
/// ```dart
/// FormTextField(
///   label: 'Nombre',
///   value: _name,
///   onChanged: (v) => setState(() => _name = v),
/// )
/// ```
///
/// Uso con controller:
/// ```dart
/// FormTextField(
///   label: 'Clave API',
///   controller: _apiKeyController,
///   obscureText: true,
///   validator: (v) => v?.isEmpty ?? true ? 'Requerido' : null,
/// )
/// ```
class FormTextField extends StatelessWidget {
  final String label;
  final String? value;
  final TextEditingController? controller;
  final ValueChanged<String?>? onChanged;
  final String? placeholder;
  final bool isRequired;
  final bool readOnly;
  final bool obscureText;
  final int maxLines;
  final TextInputType keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final AutovalidateMode? autovalidateMode;
  final bool enabled;

  const FormTextField({
    super.key,
    required this.label,
    this.value,
    this.controller,
    this.onChanged,
    this.placeholder,
    this.isRequired = false,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.suffix,
    this.validator,
    this.autovalidateMode,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: isRequired ? '$label *' : label,
      child: validator != null
          ? TextFormBox(
              controller: controller,
              initialValue: controller == null ? value : null,
              onChanged: onChanged,
              placeholder: placeholder,
              readOnly: readOnly,
              obscureText: obscureText,
              maxLines: maxLines,
              keyboardType: keyboardType,
              prefix: prefix,
              suffix: suffix,
              validator: validator,
              autovalidateMode: autovalidateMode,
              enabled: enabled,
            )
          : TextBox(
              controller: controller ?? TextEditingController(text: value),
              onChanged: onChanged,
              placeholder: placeholder,
              readOnly: readOnly,
              obscureText: obscureText,
              maxLines: maxLines,
              keyboardType: keyboardType,
              prefix: prefix,
              suffix: suffix,
              enabled: enabled,
            ),
    );
  }
}

/// Campo numérico para formularios
///
/// Uso:
/// ```dart
/// FormNumberField(
///   label: 'Cantidad',
///   value: _qty,
///   onChanged: (v) => setState(() => _qty = v ?? 0),
///   min: 0,
///   max: 100,
/// )
/// ```
class FormNumberField extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final String? placeholder;
  final bool isRequired;
  final int decimals;
  final double? min;
  final double? max;
  final bool showButtons;

  const FormNumberField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.placeholder,
    this.isRequired = false,
    this.decimals = 2,
    this.min,
    this.max,
    this.showButtons = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPatternDigits(
      locale: 'es',
      decimalDigits: decimals,
    );

    return InfoLabel(
      label: isRequired ? '$label *' : label,
      child: showButtons
          ? NumberBox<double>(
              value: value,
              onChanged: onChanged,
              placeholder: placeholder,
              smallChange: 1,
              min: min,
              max: max,
              mode: SpinButtonPlacementMode.inline,
            )
          : TextBox(
              controller: TextEditingController(
                text: value != null ? formatter.format(value!) : '',
              ),
              placeholder: placeholder,
              keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
              onChanged: (text) {
                if (text.isEmpty) {
                  onChanged?.call(null);
                  return;
                }
                final parsed = double.tryParse(text.replaceAll(',', '.'));
                if (parsed != null) {
                  var clamped = parsed;
                  if (min != null && clamped < min!) clamped = min!;
                  if (max != null && clamped > max!) clamped = max!;
                  onChanged?.call(clamped);
                }
              },
            ),
    );
  }
}

/// Campo monetario para formularios
///
/// Uso:
/// ```dart
/// FormMoneyField(
///   label: 'Precio',
///   value: _price,
///   onChanged: (v) => setState(() => _price = v ?? 0),
///   currencySymbol: '\$',
/// )
/// ```
class FormMoneyField extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final String currencySymbol;
  final bool isRequired;
  final int decimals;
  final bool readOnly;

  const FormMoneyField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.currencySymbol = '\$',
    this.isRequired = false,
    this.decimals = 2,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'es',
      symbol: '',
      decimalDigits: decimals,
    );

    return InfoLabel(
      label: isRequired ? '$label *' : label,
      child: TextBox(
        controller: TextEditingController(
          text: value != null ? formatter.format(value!) : '',
        ),
        placeholder: '0.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: readOnly,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(currencySymbol),
        ),
        onChanged: readOnly
            ? null
            : (text) {
                if (text.isEmpty) {
                  onChanged?.call(null);
                  return;
                }
                final cleaned = text
                    .replaceAll(currencySymbol, '')
                    .replaceAll(' ', '')
                    .replaceAll(',', '.');
                final parsed = double.tryParse(cleaned);
                onChanged?.call(parsed);
              },
      ),
    );
  }
}

/// Campo de porcentaje para formularios
///
/// Uso:
/// ```dart
/// FormPercentField(
///   label: 'Descuento',
///   value: _discount,
///   onChanged: (v) => setState(() => _discount = v ?? 0),
/// )
/// ```
class FormPercentField extends StatelessWidget {
  final String label;
  final double? value;
  final ValueChanged<double?>? onChanged;
  final bool isRequired;
  final int decimals;
  final double? min;
  final double? max;

  const FormPercentField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.isRequired = false,
    this.decimals = 2,
    this.min = 0,
    this.max = 100,
  });

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: isRequired ? '$label *' : label,
      child: TextBox(
        controller: TextEditingController(
          text: value != null ? value!.toStringAsFixed(decimals) : '',
        ),
        placeholder: '0.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        suffix: const Padding(
          padding: EdgeInsets.only(right: 10),
          child: Text('%'),
        ),
        onChanged: (text) {
          if (text.isEmpty) {
            onChanged?.call(null);
            return;
          }
          final parsed = double.tryParse(text.replaceAll(',', '.'));
          if (parsed != null) {
            var clamped = parsed;
            if (min != null && clamped < min!) clamped = min!;
            if (max != null && clamped > max!) clamped = max!;
            onChanged?.call(clamped);
          }
        },
      ),
    );
  }
}

/// Selector de fecha para formularios
///
/// Uso:
/// ```dart
/// FormDatePicker(
///   label: 'Fecha de entrega',
///   value: _deliveryDate,
///   onChanged: (v) => setState(() => _deliveryDate = v),
/// )
/// ```
class FormDatePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final bool isRequired;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool showTime;
  final String dateFormat;

  const FormDatePicker({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.isRequired = false,
    this.minDate,
    this.maxDate,
    this.showTime = false,
    this.dateFormat = 'dd/MM/yyyy',
  });

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: isRequired ? '$label *' : label,
      child: showTime
          ? _buildDateTimePicker(context)
          : DatePicker(
              selected: value,
              onChanged: onChanged,
              startDate: minDate,
              endDate: maxDate,
            ),
    );
  }

  Widget _buildDateTimePicker(BuildContext context) {
    final theme = FluentTheme.of(context);
    final formatter = DateFormat('$dateFormat HH:mm', 'es');

    return Button(
      onPressed: () => _showDateTimePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null
                    ? formatter.format(value!)
                    : 'Seleccionar fecha y hora',
                style: value == null
                    ? TextStyle(color: theme.inactiveColor)
                    : null,
              ),
            ),
            Icon(
              FluentIcons.calendar,
              size: 14,
              color: theme.inactiveColor,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDateTimePicker(BuildContext context) async {
    final date = await showDialog<DateTime>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DatePicker(
              selected: value ?? DateTime.now(),
              onChanged: (d) => Navigator.of(context).pop(d),
              startDate: minDate,
              endDate: maxDate,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (date != null) {
      // Conservar hora existente o usar hora actual
      final hour = value?.hour ?? DateTime.now().hour;
      final minute = value?.minute ?? DateTime.now().minute;
      onChanged?.call(DateTime(date.year, date.month, date.day, hour, minute));
    }
  }
}

/// Selector dropdown para formularios
///
/// Uso:
/// ```dart
/// FormComboBox<String>(
///   label: 'Estado',
///   value: _status,
///   items: [
///     ComboBoxItem(value: 'draft', child: Text('Borrador')),
///     ComboBoxItem(value: 'confirmed', child: Text('Confirmado')),
///   ],
///   onChanged: (v) => setState(() => _status = v),
/// )
/// ```
class FormComboBox<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<ComboBoxItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? placeholder;
  final bool isRequired;
  final bool isExpanded;

  const FormComboBox({
    super.key,
    required this.label,
    this.value,
    required this.items,
    this.onChanged,
    this.placeholder,
    this.isRequired = false,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: isRequired ? '$label *' : label,
      child: ComboBox<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        placeholder: placeholder != null ? Text(placeholder!) : null,
        isExpanded: isExpanded,
      ),
    );
  }
}

/// Campo booleano (checkbox) para formularios
///
/// Uso:
/// ```dart
/// FormCheckbox(
///   label: 'Activo',
///   value: _isActive,
///   onChanged: (v) => setState(() => _isActive = v ?? false),
/// )
/// ```
class FormCheckbox extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String? content;

  const FormCheckbox({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: label,
      child: Checkbox(
        checked: value ?? false,
        onChanged: onChanged,
        content: content != null ? Text(content!) : null,
      ),
    );
  }
}

/// Campo toggle para formularios
///
/// Uso:
/// ```dart
/// FormToggleSwitch(
///   label: 'Notificaciones',
///   value: _notifyEnabled,
///   onChanged: (v) => setState(() => _notifyEnabled = v),
/// )
/// ```
class FormToggleSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? checkedLabel;
  final String? uncheckedLabel;

  const FormToggleSwitch({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.checkedLabel,
    this.uncheckedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InfoLabel(
      label: label,
      child: Row(
        children: [
          ToggleSwitch(
            checked: value,
            onChanged: onChanged,
          ),
          if (checkedLabel != null || uncheckedLabel != null) ...[
            const SizedBox(width: 8),
            Text(value ? (checkedLabel ?? '') : (uncheckedLabel ?? '')),
          ],
        ],
      ),
    );
  }
}

/// Campo de selección con botón que abre diálogo
///
/// Uso:
/// ```dart
/// FormSelectionField(
///   label: 'Cliente',
///   displayValue: _selectedPartner?.name ?? 'Seleccionar cliente',
///   isPlaceholder: _selectedPartner == null,
///   onTap: () => _showPartnerDialog(),
///   onClear: _selectedPartner != null ? () => setState(() => _selectedPartner = null) : null,
/// )
/// ```
class FormSelectionField extends StatelessWidget {
  final String label;
  final String displayValue;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final bool isRequired;
  final bool isPlaceholder;
  final IconData icon;

  const FormSelectionField({
    super.key,
    required this.label,
    required this.displayValue,
    this.onTap,
    this.onClear,
    this.isRequired = false,
    this.isPlaceholder = false,
    this.icon = FluentIcons.chevron_down,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return InfoLabel(
      label: isRequired ? '$label *' : label,
      child: Button(
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayValue,
                  style: isPlaceholder
                      ? TextStyle(color: theme.inactiveColor)
                      : null,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onClear != null && !isPlaceholder) ...[
                IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 12),
                  onPressed: onClear,
                ),
              ],
              Icon(icon, size: 12, color: theme.inactiveColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección de formulario con título y línea de acento
///
/// Uso:
/// ```dart
/// FormSection(title: 'Información General'),
/// // ... campos del formulario ...
/// FormSection(title: 'Configuración'),
/// // ... más campos ...
/// ```
class FormSection extends StatelessWidget {
  final String title;
  final IconData? icon;

  const FormSection({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.accentColor, width: 2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: theme.accentColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

