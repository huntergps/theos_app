/// Reactive Widgets Library
///
/// Primitive field widgets are provided by [odoo_widgets] package.
/// Domain-specific composite widgets remain local.
///
/// ## Primitive Widgets (from odoo_widgets)
///
/// - [OdooTextField], [OdooNumberField], [OdooDateField]
/// - [OdooBooleanField], [OdooSelectionField], [OdooMultilineField]
/// - [OdooStatusField], [OdooSummaryRow]
/// - [NumberInputBase] — low-level number input
///
/// ## Domain Widgets (local, Riverpod-based)
///
/// - [ReactiveMasterSelector] — master data selector (Riverpod StreamProvider)
/// - [ReactivePartnerCard] — customer info card
/// - [ReactiveCashCountField] — cash counting with denominations
/// - [ReactiveSaleOrderLine] — sale order line editor
/// - [ReactiveSearchBar] — Odoo-style search bar
/// - [ReactiveDataGrid] — reactive data grid
library;

// Config + local theme
export 'reactive_field_base.dart';

// Primitive widgets from odoo_widgets. Domain-specific local widgets keep
// their Reactive* names because they represent Riverpod behavior, not aliases.
export 'package:odoo_widgets/odoo_widgets.dart'
    show
        // Base
        OdooFieldBase,
        // Text
        OdooTextField,
        OdooInlineTextField,
        // Numbers
        OdooNumberField,
        OdooMoneyField,
        OdooPercentField,
        OdooNumberInput,
        NumberInputBase,
        // Date
        OdooDateField,
        OdooDateRangeField,
        // Boolean
        OdooBooleanField,
        OdooTristateBooleanField,
        // Selection
        OdooSelectionField,
        SelectionOption,
        OdooStatusField,
        // Multiline
        OdooMultilineField,
        OdooCollapsibleTextField,
        // Summary
        OdooSummaryRow,
        OdooSummaryHeader,
        OdooSummaryCard,
        // Builders
        OdooContentBuilder,
        OdooRecordBuilder;

// Domain-specific widgets (local, Riverpod-based)
export 'reactive_master_selector.dart';
export 'reactive_partner_card.dart';
export 'reactive_cash_count_field.dart';
export 'reactive_sale_order_line.dart';

// List widgets
export 'reactive_search_bar.dart';
export 'reactive_data_grid.dart';
