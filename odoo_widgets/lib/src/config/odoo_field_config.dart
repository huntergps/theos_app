import 'package:flutter/widgets.dart';

/// Configuration for Odoo field widgets.
///
/// Provides common properties for all Odoo fields.
class OdooFieldConfig {
  /// Field label displayed above or beside the field.
  final String label;

  /// Whether the field is in edit mode.
  final bool isEditing;

  /// Whether the field is required.
  final bool isRequired;

  /// Whether the field is enabled (can be disabled even in edit mode).
  final bool isEnabled;

  /// Hint text shown when value is empty.
  final String? hint;

  /// Help text shown below the field.
  final String? helpText;

  /// Error message to display.
  final String? errorMessage;

  /// Icon to show before the field.
  final IconData? prefixIcon;

  /// Compact mode - reduced padding for space-constrained layouts.
  final bool isCompact;

  const OdooFieldConfig({
    required this.label,
    this.isEditing = false,
    this.isRequired = false,
    this.isEnabled = true,
    this.hint,
    this.helpText,
    this.errorMessage,
    this.prefixIcon,
    this.isCompact = false,
  });

  OdooFieldConfig copyWith({
    String? label,
    bool? isEditing,
    bool? isRequired,
    bool? isEnabled,
    String? hint,
    String? helpText,
    String? errorMessage,
    IconData? prefixIcon,
    bool? isCompact,
  }) {
    return OdooFieldConfig(
      label: label ?? this.label,
      isEditing: isEditing ?? this.isEditing,
      isRequired: isRequired ?? this.isRequired,
      isEnabled: isEnabled ?? this.isEnabled,
      hint: hint ?? this.hint,
      helpText: helpText ?? this.helpText,
      errorMessage: errorMessage ?? this.errorMessage,
      prefixIcon: prefixIcon ?? this.prefixIcon,
      isCompact: isCompact ?? this.isCompact,
    );
  }
}

/// Backward-compatible alias.
typedef ReactiveFieldConfig = OdooFieldConfig;
