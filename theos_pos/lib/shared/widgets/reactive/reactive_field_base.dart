/// Reactive field configuration — delegates to odoo_widgets
///
/// This file re-exports field config from odoo_widgets and local theme utilities.
/// The backward-compatible typedef [ReactiveFieldConfig] = [OdooFieldConfig]
/// ensures existing code continues to work without changes.
library;

// Config from odoo_widgets (ReactiveFieldConfig is a typedef for OdooFieldConfig)
export 'package:odoo_widgets/odoo_widgets.dart'
    show OdooFieldConfig, ReactiveFieldConfig;

// Local theme utilities (Spacing, ThemedSpacing, ResponsiveValues, etc.)
export '../../../core/theme/spacing.dart';
