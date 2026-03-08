/// Reactive Widgets Library
///
/// Primitive field widgets are provided by [odoo_widgets] package.
/// Domain-specific composite widgets remain local.
///
/// ## Primitive Widgets (from odoo_widgets)
///
/// - [ReactiveTextField] / [OdooTextField]
/// - [ReactiveNumberField] / [OdooNumberField]
/// - [ReactiveMoneyField] / [OdooMoneyField]
/// - [ReactivePercentField] / [OdooPercentField]
/// - [ReactiveDateField] / [OdooDateField]
/// - [ReactiveBooleanField] / [OdooBooleanField]
/// - [ReactiveSelectionField] / [OdooSelectionField]
/// - [ReactiveMultilineField] / [OdooMultilineField]
/// - [ReactiveStatusField] / [OdooStatusField]
/// - [ReactiveSummaryRow] / [OdooSummaryRow]
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

// Primitive widgets from odoo_widgets (with backward-compatible Reactive* typedefs)
// NOTE: ReactiveMasterSelector / ReactiveRelatedField NOT exported here
// because the local versions (Riverpod-based) take precedence.
export 'package:odoo_widgets/odoo_widgets.dart'
    show
        // Base
        OdooFieldBase,
        // Text
        OdooTextField,
        ReactiveTextField,
        OdooInlineTextField,
        ReactiveInlineTextField,
        // Numbers
        OdooNumberField,
        ReactiveNumberField,
        OdooMoneyField,
        ReactiveMoneyField,
        OdooPercentField,
        ReactivePercentField,
        OdooNumberInput,
        ReactiveNumberInput,
        NumberInputBase,
        // Date
        OdooDateField,
        ReactiveDateField,
        OdooDateRangeField,
        ReactiveDateRangeField,
        // Boolean
        OdooBooleanField,
        ReactiveBooleanField,
        OdooTristateBooleanField,
        ReactiveTristateBooleanField,
        // Selection
        OdooSelectionField,
        ReactiveSelectionField,
        SelectionOption,
        OdooStatusField,
        ReactiveStatusField,
        // Multiline
        OdooMultilineField,
        ReactiveMultilineField,
        OdooCollapsibleTextField,
        ReactiveCollapsibleTextField,
        // Summary
        OdooSummaryRow,
        ReactiveSummaryRow,
        OdooSummaryHeader,
        ReactiveSummaryHeader,
        OdooSummaryCard,
        ReactiveSummaryCard,
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
