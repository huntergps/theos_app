/// Reactive form widgets for Odoo Flutter apps.
///
/// State-management agnostic — works with any state solution
/// (Riverpod, Bloc, GetX, vanilla streams, etc.)
///
/// Built on Fluent UI for desktop-first Odoo apps.
library;

// Theme
export 'src/theme/spacing.dart';
export 'src/theme/responsive.dart';

// Config
export 'src/config/odoo_field_config.dart';

// Base
export 'src/base/odoo_field_base.dart';
export 'src/base/number_input_base.dart';

// Fields
export 'src/fields/odoo_text_field.dart';
export 'src/fields/odoo_number_field.dart';
export 'src/fields/odoo_date_field.dart';
export 'src/fields/odoo_boolean_field.dart';
export 'src/fields/odoo_selection_field.dart';
export 'src/fields/odoo_multiline_field.dart';

// Composite
export 'src/composite/odoo_master_selector.dart';
export 'src/composite/odoo_summary_row.dart';

// Builders
export 'src/builders/odoo_content_builder.dart';
export 'src/builders/odoo_record_builder.dart';
