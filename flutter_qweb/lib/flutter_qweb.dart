/// Flutter QWeb - A Dart implementation of Odoo's QWeb template engine
///
/// This library provides a complete QWeb template engine for Flutter,
/// enabling offline PDF report generation compatible with Odoo reports.
///
/// ## Features
///
/// - **QWeb Template Parsing**: Full support for QWeb directives
///   - `t-if`, `t-elif`, `t-else` - Conditional rendering
///   - `t-foreach`, `t-as` - Loop iteration
///   - `t-esc`, `t-out`, `t-raw` - Output expressions
///   - `t-field` - Field rendering with formatting
///   - `t-set`, `t-value` - Variable assignment
///   - `t-call` - Template inclusion
///   - `t-att-*`, `t-attf-*` - Dynamic attributes
///
/// - **Expression Evaluation**: Python-like expressions
///   - Dot notation: `doc.partner_id.name`
///   - Comparisons: `qty > 0`, `state == 'sale'`
///   - Logical operators: `and`, `or`, `not`
///   - Arithmetic: `price * qty`, `total + tax`
///   - Built-in functions: `len()`, `str()`, `int()`, `float()`
///
/// - **PDF Generation**: Direct PDF output
///   - Page formats: A4, Letter, Legal, custom sizes
///   - Margins, headers, footers
///   - Company branding (logo, contact info)
///   - DPI and orientation settings
///
/// - **Odoo Integration**: Sync templates from Odoo
///   - Fetch consolidated templates with inheritance
///   - Paper format configuration
///   - Report action metadata
///
/// ## Basic Usage
///
/// ```dart
/// import 'package:flutter_qweb/flutter_qweb.dart';
///
/// final engine = QWebReportEngine();
///
/// final pdfBytes = await engine.renderToPdf(
///   xml: '''
///     <div>
///       <h1><t t-esc="doc.name"/></h1>
///       <t t-foreach="doc.lines" t-as="line">
///         <p><t t-esc="line.product"/> - <t t-esc="line.quantity"/></p>
///       </t>
///       <p>Total: <t t-esc="doc.total"/></p>
///     </div>
///   ''',
///   data: {
///     'doc': {
///       'name': 'SO001',
///       'lines': [
///         {'product': 'Widget A', 'quantity': 10},
///         {'product': 'Widget B', 'quantity': 5},
///       ],
///       'total': 1500.00,
///     },
///   },
///   company: CompanyInfo(
///     name: 'My Company',
///     vat: '1234567890',
///     email: 'info@company.com',
///   ),
///   options: RenderOptions.a4(title: 'Sales Order'),
/// );
/// ```
library;

// Main API
export 'src/qweb_report_engine.dart';

// Models
export 'src/models/cached_template.dart';
export 'src/models/paper_format.dart';
export 'src/models/render_options.dart';
export 'src/models/report_action.dart';
export 'src/models/report_locale.dart';
export 'src/models/report_model_config.dart';
export 'src/models/report_result.dart';
export 'src/models/template_context.dart';

// Parser
export 'src/parser/qweb_parser.dart';
export 'src/parser/qweb_node.dart';

// Evaluator
export 'src/evaluator/expression_evaluator.dart';

// Renderer
export 'src/renderer/pdf_renderer.dart';

// Reports
export 'src/services/report_service.dart';
export 'src/services/report_template_sanitizer.dart';

// Odoo Integration
export 'src/odoo/odoo_template_service.dart';
// NOTE: OdooClientAdapter moved to odoo_model_manager package
// Import from: package:odoo_model_manager/odoo_model_manager.dart
