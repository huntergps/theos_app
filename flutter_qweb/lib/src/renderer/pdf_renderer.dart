import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../evaluator/expression_evaluator.dart';
import '../models/render_options.dart';
import '../models/template_context.dart';
import '../parser/qweb_node.dart';
import '../parser/qweb_parser.dart';
import 'pdf_layout_renderer.dart';
import 'pdf_text_renderer.dart';
import 'pdf_value_formatter.dart';
import 'qweb_table_renderer.dart';
import 'tax_totals_widget.dart';

/// Debug mode flag - set to false for production
const bool _kDebugPdfRenderer = false;

/// No-op debug print that compiles to nothing when disabled
void _debugPrint(String message) {
  if (_kDebugPdfRenderer) {
    _debugPrint(message);
  }
}

/// Renders QWeb AST to PDF
class QWebPdfRenderer implements QWebTableRendererDelegate {
  final ExpressionEvaluator _evaluator = ExpressionEvaluator();
  final QWebParser _parser = QWebParser();
  late final PdfValueFormatter _valueFormatter;
  late final PdfTextRenderer _textRenderer;
  final PdfLayoutRenderer _layoutRenderer = PdfLayoutRenderer();

  /// Template loader for t-call
  @override
  final QWebNode? Function(String)? templateLoader;

  QWebPdfRenderer({this.templateLoader}) {
    _valueFormatter = PdfValueFormatter(_evaluator);
    _textRenderer = PdfTextRenderer(_evaluator, _valueFormatter);
  }

  /// Current rendering context
  Map<String, dynamic> _context = {};

  /// Render options
  late RenderOptions _options;

  /// Cached primary color (computed once per render)
  PdfColor? _cachedPrimaryColor;

  // --- QWebTableRendererDelegate interface ---

  @override
  ExpressionEvaluator get evaluator => _evaluator;

  @override
  Map<String, dynamic> get context => _context;

  @override
  set context(Map<String, dynamic> value) => _context = value;

  @override
  RenderOptions get options => _options;

  @override
  PdfColor getPrimaryColor() => _getPrimaryColor();

  @override
  List<pw.Widget> renderNode(QWebNode node) => _renderNode(node);

  @override
  String getTextContent(QWebNode node) =>
      _textRenderer.getTextContent(node, _context);

  @override
  String getTextFromNode(QWebNode node) =>
      _textRenderer.getTextFromNode(node, _context);

  @override
  String getTextFromWidget(pw.Widget widget) =>
      _textRenderer.getTextFromWidget(widget);

  @override
  String formatCurrency(double value) =>
      _options.effectiveLocale.formatCurrency(value);

  @override
  pw.TextAlign getAlignment(String? cssClass, {String? cellName}) =>
      _textRenderer.getAlignment(cssClass, cellName: cellName);

  // --- End of delegate interface ---

  /// Get primary color from company, with caching
  PdfColor _getPrimaryColor() {
    if (_cachedPrimaryColor != null) return _cachedPrimaryColor!;

    final company = _context['company'];
    if (company is Map && company['primary_color'] != null) {
      final colorHex = company['primary_color'].toString();
      if (colorHex.startsWith('#') && colorHex.length >= 7) {
        final hex = colorHex.substring(1);
        final intColor = int.tryParse(hex, radix: 16);
        if (intColor != null) {
          _cachedPrimaryColor = PdfColor.fromInt(0xFF000000 | intColor);
          return _cachedPrimaryColor!;
        }
      }
    }
    _cachedPrimaryColor = const PdfColor.fromInt(0xFF17a2b8);
    return _cachedPrimaryColor!;
  }

  /// Render a parsed QWeb AST to PDF bytes
  Future<Uint8List> render({
    required QWebNode ast,
    required TemplateContext context,
    RenderOptions options = const RenderOptions(),
  }) async {
    _context = context.toEvaluationContext();
    _options = options;
    _cachedPrimaryColor = null; // Reset cache for new render

    final theme = pw.ThemeData.withFont(
      base: _options.font ?? pw.Font.helvetica(),
      bold: _options.boldFont ?? pw.Font.helveticaBold(),
      italic: _options.italicFont ?? pw.Font.helveticaOblique(),
      boldItalic: _options.boldItalicFont ?? pw.Font.helveticaBoldOblique(),
    );

    final pdf = pw.Document(
      theme: theme,
      title: options.title,
      author: options.author,
    );

    // Build PDF content
    final content = _renderNode(ast);
    final widgets = <pw.Widget>[];

    // Add document title at the beginning
    final locale = _options.effectiveLocale;
    final documentTitle = _layoutRenderer.buildDocumentTitle(
      context: _context,
      getPrimaryColor: _getPrimaryColor,
      locale: locale,
    );
    if (documentTitle != null) {
      widgets.add(documentTitle);
    }

    // Add rendered content from QWeb template
    widgets.addAll(content.whereType<pw.Widget>());

    // Add payment terms section if available
    final paymentTermsWidget = _layoutRenderer.buildPaymentTermsSection(
      context: _context,
      options: _options,
      locale: locale,
    );
    if (paymentTermsWidget != null) {
      widgets.add(paymentTermsWidget);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: options.pageFormat,
        margin: pw.EdgeInsets.only(
          top: options.marginTop,
          bottom: options.marginBottom,
          left: options.marginLeft,
          right: options.marginRight,
        ),
        header: options.includeHeader
            ? (ctx) => _layoutRenderer.buildHeader(
                  context: _context,
                  options: _options,
                  getPrimaryColor: _getPrimaryColor,
                )
            : null,
        footer: options.includeFooter
            ? (ctx) => _layoutRenderer.buildFooter(
                  ctx: ctx,
                  context: _context,
                  options: _options,
                  locale: locale,
                )
            : null,
        build: (ctx) => widgets,
      ),
    );

    return pdf.save();
  }

  /// Render from XML string directly
  Future<Uint8List> renderFromXml({
    required String xml,
    required TemplateContext context,
    RenderOptions options = const RenderOptions(),
  }) async {
    final ast = _parser.parse(xml);
    return render(ast: ast, context: context, options: options);
  }

  /// Render a QWeb node to PDF widgets
  List<pw.Widget> _renderNode(QWebNode node) {
    return switch (node) {
      QWebTextNode() => _renderText(node),
      QWebElementNode() => _renderElement(node),
      QWebFragmentNode() => _renderFragment(node),
      QWebIfNode() => _renderIf(node),
      QWebForEachNode() => _renderForEach(node),
      QWebSetNode() => _renderSet(node),
      QWebSetContentNode() => _renderSetContent(node),
      QWebEscNode() => _renderEsc(node),
      QWebOutNode() => _renderOut(node),
      QWebFieldNode() => _renderField(node),
      QWebCallNode() => _renderCall(node),
      QWebDynamicAttrsNode() => _renderDynamicAttrs(node),
      QWebAttNode() => _renderAtt(node),
    };
  }

  /// Render text node
  List<pw.Widget> _renderText(QWebTextNode node) {
    var text = node.text.trim();
    if (text.isEmpty) return [];

    // Strip DOCTYPE if present
    if (text.contains('<!DOCTYPE')) {
      text = text
          .replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '')
          .trim();
    }
    if (text.isEmpty) return [];

    // Check for interpolation {{expr}}
    final interpolated = _textRenderer.interpolate(text, _context);
    if (interpolated.isEmpty) return [];

    return [
      pw.Text(interpolated,
          style: pw.TextStyle(fontSize: _options.baseFontSize))
    ];
  }

  /// Render HTML/XML element
  List<pw.Widget> _renderElement(QWebElementNode node) {
    // Check visibility classes
    final cssClass = node.attributes['class'] ?? '';
    if (cssClass.contains('d-none') ||
        cssClass.contains('d-print-none') ||
        node.attributes['style']?.contains('display: none') == true) {
      return [];
    }

    // Check for so_total_summary - replace with TaxTotalsWidget
    final elementName = node.attributes['name'] ?? '';
    if (elementName == 'so_total_summary') {
      final widget = TaxTotalsWidget(
        context: _context,
        options: _options,
      );
      final result = widget.render();
      if (result != null) {
        return result;
      }
    }

    final tag = node.tagName.toLowerCase();
    final children = node.children.expand(_renderNode).toList();

    // Map HTML tags to PDF widgets
    switch (tag) {
      case 'script':
      case 'style':
      case 'head':
      case 'meta':
      case 'link':
      case 'noscript':
      case 'title':
        return [];

      case 'div':
      case 'section':
      case 'article':
        // Handle Bootstrap row
        if (cssClass.contains('row')) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children.map((c) => pw.Expanded(child: c)).toList(),
            )
          ];
        }

        // Process inline styles (border, padding, margin)
        final styleStr = node.attributes['style'] ?? '';
        final hasBorder = styleStr.contains('border');
        final hasPadding = styleStr.contains('padding');
        final hasMargin = styleStr.contains('margin');

        // Build the content widget
        pw.Widget contentWidget;

        // Handle text alignment classes
        if (cssClass.contains('text-end') ||
            cssClass.contains('text-right')) {
          contentWidget = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: children,
          );
        } else if (cssClass.contains('text-center')) {
          contentWidget = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: children,
          );
        } else {
          contentWidget = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          );
        }

        // If there are inline styles, wrap in Container
        if (hasBorder || hasPadding || hasMargin) {
          final styleInfo = _textRenderer.parseInlineStyles(styleStr);

          // Build decoration if there's a border
          pw.BoxDecoration? decoration;
          if (styleInfo['borderColor'] != null &&
              styleInfo['borderWidth'] != null) {
            final borderWidth = (styleInfo['borderWidth'] as double) > 1.0
                ? 0.5
                : (styleInfo['borderWidth'] as double);
            final borderColor = PdfColors.grey600;

            decoration = pw.BoxDecoration(
              border: pw.Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            );
          }

          // Build padding
          pw.EdgeInsets? padding;
          if (styleInfo['padding'] != null) {
            final paddingValue = styleInfo['padding'] as double;
            final reducedPadding = paddingValue / 2;
            padding = pw.EdgeInsets.all(reducedPadding);
          } else if (styleInfo['paddingTop'] != null ||
              styleInfo['paddingBottom'] != null ||
              styleInfo['paddingLeft'] != null ||
              styleInfo['paddingRight'] != null) {
            padding = pw.EdgeInsets.only(
              top: ((styleInfo['paddingTop'] as double?) ?? 0) / 2,
              bottom: ((styleInfo['paddingBottom'] as double?) ?? 0) / 2,
              left: ((styleInfo['paddingLeft'] as double?) ?? 0) / 2,
              right: ((styleInfo['paddingRight'] as double?) ?? 0) / 2,
            );
          }

          // Build margin
          pw.EdgeInsets? margin;
          if (styleInfo['marginBottom'] != null) {
            final marginValue = styleInfo['marginBottom'] as double;
            margin = pw.EdgeInsets.only(
              bottom: marginValue > 10 ? marginValue / 2 : marginValue,
            );
          }

          final styledContent = pw.DefaultTextStyle(
            style: const pw.TextStyle(
              color: PdfColors.grey700,
            ),
            child: contentWidget,
          );

          return [
            pw.Container(
              padding: padding,
              margin: margin,
              decoration: decoration,
              child: styledContent,
            )
          ];
        }

        // No inline styles, return content as-is
        return [contentWidget];

      case 'span':
      case 'p':
        if (children.isEmpty) return [];

        // Handle alignment and style classes
        final align = _textRenderer.getAlignment(cssClass);
        final isBold = cssClass.contains('fw-bold') ||
            cssClass.contains('font-weight-bold') ||
            cssClass.contains('bold');
        final isItalic =
            cssClass.contains('fst-italic') || cssClass.contains('italic');
        final isMuted = cssClass.contains('text-muted');

        final style = pw.TextStyle(
          fontWeight: isBold ? pw.FontWeight.bold : null,
          fontStyle: isItalic ? pw.FontStyle.italic : null,
          color: isMuted ? PdfColors.grey600 : null,
          fontSize: _options.baseFontSize,
        );

        // Check if this span has t-options (for widget formatting with t-out)
        final hasTOptions = node.attributes.containsKey('t-options') ||
            (node.attributes.containsKey('t_options'));
        String? tOptionsStr;
        if (hasTOptions) {
          tOptionsStr =
              node.attributes['t-options'] ?? node.attributes['t_options'];
        }

        // If span has t-out with t-options, format the value
        if (hasTOptions && tOptionsStr != null && children.length == 1) {
          final child = children.first;
          if (child is pw.Text) {
            try {
              return [
                pw.DefaultTextStyle(
                    style: style, textAlign: align, child: child)
              ];
            } catch (e) {
              // Fallback to normal rendering
            }
          }
        }

        if (children.length == 1) {
          return [
            pw.DefaultTextStyle(
                style: style, textAlign: align, child: children.first)
          ];
        }

        return [
          pw.DefaultTextStyle(
              style: style,
              textAlign: align,
              child: pw.Wrap(children: children))
        ];

      case 'strong':
      case 'b':
        return [
          pw.DefaultTextStyle(
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            child: children.length == 1
                ? children.first
                : pw.Row(children: children),
          )
        ];

      case 'em':
      case 'i':
        return [
          pw.DefaultTextStyle(
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            child: children.length == 1
                ? children.first
                : pw.Row(children: children),
          )
        ];

      case 'h1':
        return [
          pw.Text(
            _textRenderer.getTextContent(node, _context),
            style:
                pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
        ];

      case 'h2':
        return [
          pw.Text(
            _textRenderer.getTextContent(node, _context),
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: _getPrimaryColor(),
            ),
          ),
          pw.SizedBox(height: 10),
        ];

      case 'h3':
        return [
          pw.Text(
            _textRenderer.getTextContent(node, _context),
            style:
                pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
        ];

      case 'h4':
        return [
          pw.Text(
            _textRenderer.getTextContent(node, _context),
            style:
                pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
        ];

      case 'br':
        return [pw.SizedBox(height: 8)];

      case 'hr':
        return [
          pw.Divider(thickness: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
        ];

      case 'table':
        return QWebTableRenderer(this).renderTable(node);

      case 'thead':
      case 'tbody':
      case 'tfoot':
        return children;

      case 'ul':
        return [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: node.children.expand((child) {
              final items = _renderNode(child);
              return items.map((item) => pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('• ',
                          style:
                              pw.TextStyle(fontSize: _options.baseFontSize)),
                      pw.Expanded(child: item),
                    ],
                  ));
            }).toList(),
          )
        ];

      case 'ol':
        var index = 0;
        return [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: node.children.expand((child) {
              index++;
              final items = _renderNode(child);
              return items.map((item) => pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('$index. ',
                          style:
                              pw.TextStyle(fontSize: _options.baseFontSize)),
                      pw.Expanded(child: item),
                    ],
                  ));
            }).toList(),
          )
        ];

      case 'li':
        return children;

      case 'img':
        return _renderImage(node);

      case 'a':
        return [
          pw.Text(
            _textRenderer.getTextContent(node, _context),
            style: const pw.TextStyle(
              color: PdfColors.blue,
              decoration: pw.TextDecoration.underline,
            ),
          )
        ];

      case 'row':
        return [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children.map((c) => pw.Expanded(child: c)).toList(),
          )
        ];

      case 'col':
        return [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          )
        ];

      case 'root':
        return children;

      default:
        return children;
    }
  }

  /// Render image
  List<pw.Widget> _renderImage(QWebElementNode node) {
    return [pw.SizedBox(height: 50)];
  }

  /// Render fragment (multiple children)
  List<pw.Widget> _renderFragment(QWebFragmentNode node) {
    return node.children.expand(_renderNode).toList();
  }

  /// Render conditional (t-if)
  List<pw.Widget> _renderIf(QWebIfNode node) {
    final condition = _evaluator.evaluateCondition(node.condition, _context);

    // DEBUG: Log collapse_prices and price_field conditions
    if (node.condition.contains('collapse_prices') ||
        node.condition.contains('price_field ==')) {
      _debugPrint(
          '  [RENDER_IF] Subtotal cell condition: "${node.condition}" => $condition');
    }

    // Debug: Log t-if conditions for cell content
    if (node.condition.contains('display_type') ||
        node.condition.contains('product_type') ||
        node.condition.contains('display_discount') ||
        node.condition.contains('display_taxes')) {
      final lineData = _context['line'];
      if (lineData is Map) {
        _debugPrint(
            '   -> line.display_type: ${lineData['display_type']} (${lineData['display_type'].runtimeType})');
      }
      if (node.condition.contains('display_discount') ||
          node.condition.contains('display_taxes')) {
        _debugPrint(
            '   -> context.display_discount: ${_context['display_discount']}');
      }
      if (condition) {
        if (node.thenBranch is QWebFragmentNode) {
          final frag = node.thenBranch as QWebFragmentNode;
          _debugPrint('   -> thenBranch fragment with ${frag.children.length} children');
        } else if (node.thenBranch is QWebElementNode) {
          final elem = node.thenBranch as QWebElementNode;
          _debugPrint(
              '   -> thenBranch element: <${elem.tagName}> with ${elem.children.length} children');
        }
      }
    }

    if (condition) {
      return _renderNode(node.thenBranch);
    } else if (node.elseBranch != null) {
      return _renderNode(node.elseBranch!);
    }

    return [];
  }

  /// Render loop (t-foreach)
  List<pw.Widget> _renderForEach(QWebForEachNode node) {
    final collection = _evaluator.evaluate(node.expression, _context);

    if (collection == null) {
      return [];
    }

    final items = collection is List
        ? collection
        : collection is Map
            ? collection.entries.toList()
            : collection is int
                ? List.generate(collection, (i) => i)
                : [collection];

    final results = <pw.Widget>[];
    final originalContext = Map<String, dynamic>.from(_context);

    // Log foreach iteration for debugging
    if (node.expression.contains('lines_to_report') ||
        node.expression.contains('order_line')) {
      if (items.isNotEmpty && items[0] is Map) {
        final firstItem = items[0] as Map;
        _debugPrint(
            '   -> First item keys: ${firstItem.keys.take(10).join(", ")}...');
        final firstName = firstItem['name']?.toString() ?? '';
        _debugPrint(
            '   -> First item name: ${firstName.length > 40 ? firstName.substring(0, 40) : firstName}...');
      }
    }

    for (var i = 0; i < items.length; i++) {
      final item = items[i];

      // Set loop variables (matching Odoo's QWeb)
      _context[node.itemVariable] = item;
      _context[node.indexVariable] = i;
      _context[node.firstVariable] = i == 0;
      _context[node.lastVariable] = i == items.length - 1;
      _context[node.sizeVariable] = items.length;
      _context[node.valueVariable] = item;
      // Odoo-compatible additions (note: *_odd is int 0/1, not bool)
      _context[node.oddVariable] = i % 2; // 0 or 1, matching Odoo
      _context[node.evenVariable] = i % 2 == 0;
      _context[node.parityVariable] = i % 2 == 0 ? 'even' : 'odd';

      // Render child for this iteration
      results.addAll(_renderNode(node.child));
    }

    // Restore context
    _context = originalContext;

    return results;
  }

  /// Render variable assignment (t-set with t-value)
  List<pw.Widget> _renderSet(QWebSetNode node) {
    final value = _evaluator.evaluate(node.expression, _context);

    // Debug: trace t-set for description-related variables
    if (node.variableName.contains('line_name') ||
        node.variableName == 'lines' ||
        node.expression.contains('find') ||
        node.expression.contains('split')) {
      _debugPrint('  [T-SET] ${node.variableName} = "${node.expression}"');
    }

    // Debug tax_totals specifically
    if (node.variableName == 'tax_totals' ||
        node.expression.contains('tax_totals')) {
      _debugPrint(
          '  [T-SET TAX_TOTALS] ${node.variableName} = "${node.expression}"');
      if (value is Map) {
        if (value.containsKey('subtotals')) {
          _debugPrint('   -> has subtotals');
        }
      }
    }

    // Debug display_taxes and display_discount
    if (node.variableName == 'display_taxes' ||
        node.variableName == 'display_discount' ||
        node.variableName == 'hide_taxes_details' ||
        node.variableName == 'lines_to_report' ||
        node.expression.contains('_has_taxes') ||
        node.expression.contains('display_taxes') ||
        node.expression.contains('display_discount') ||
        node.expression.contains('_get_order_lines_to_report')) {
      _debugPrint('  [T-SET] ${node.variableName} = $value');
      if (value is List) {
        if (value.isNotEmpty && value.first is Map) {
          final firstLine = value.first as Map;
          _debugPrint(
              '   -> First line discount: ${firstLine['discount']}, discount_amount: ${firstLine['discount_amount']}');
          _debugPrint(
              '   -> First line tax_amount: ${firstLine['tax_amount']}, price_tax: ${firstLine['price_tax']}');
        }
      }
    }

    _context[node.variableName] = value;
    return [];
  }

  /// Render variable assignment with content
  List<pw.Widget> _renderSetContent(QWebSetContentNode node) {
    final content =
        node.children.map((n) => _textRenderer.getTextContent(n, _context)).join('');
    _context[node.variableName] = content;
    return [];
  }

  /// Render escaped output (t-esc)
  List<pw.Widget> _renderEsc(QWebEscNode node) {
    final value = _evaluator.evaluate(node.expression, _context);
    if (value == null) return [];
    // Ensure single line - remove any newlines or extra whitespace
    final cleanValue = value.toString().replaceAll('\n', ' ').trim();
    return [
      pw.Text(
        cleanValue,
        style: pw.TextStyle(fontSize: _options.baseFontSize),
        maxLines: 1,
      )
    ];
  }

  /// Render raw output (t-out)
  List<pw.Widget> _renderOut(QWebOutNode node) {
    // Handle body injection for t-call (magic variable '0')
    if (node.expression == '0') {
      final body = _context['0'];

      if (body is QWebBody) {
        // Execute body in captured context
        final savedContext = _context;
        _context = body.context;
        try {
          return body.nodes.expand(_renderNode).toList();
        } finally {
          _context = savedContext;
        }
      } else if (body is List<QWebNode>) {
        // Fallback for legacy/simple lists
        return body.expand(_renderNode).toList();
      }
    }

    final value = _evaluator.evaluate(node.expression, _context);

    // If value is null/false, render default children (Odoo behavior)
    if (value == null || value == false) {
      if (node.children.isNotEmpty) {
        return node.children.expand(_renderNode).toList();
      }
      return [];
    }

    // If value is a node list (rare but possible), render it
    if (value is List<QWebNode>) {
      return value.expand(_renderNode).toList();
    }

    // Debug: trace t-out for description-related expressions
    if (node.expression.contains('line_name') ||
        node.expression.contains('lines') ||
        node.expression.contains("'\\n'.join")) {
      _debugPrint('  [T-OUT] ${node.expression} => $value');
    }

    // Format numeric values to 2 decimal places
    String formattedValue;
    if (value is double) {
      formattedValue = value.toStringAsFixed(2);
    } else if (value is num &&
        _valueFormatter.isMonetaryFieldName(node.expression)) {
      formattedValue = value.toDouble().toStringAsFixed(2);
    } else {
      formattedValue = value.toString();
    }

    return [
      pw.Text(formattedValue,
          style: pw.TextStyle(fontSize: _options.baseFontSize))
    ];
  }

  /// Render field with formatting (t-field)
  List<pw.Widget> _renderField(QWebFieldNode node) {
    final value = _evaluator.evaluate(node.expression, _context);

    // Debug: trace price_subtotal specifically
    if (node.expression.contains('price_subtotal') ||
        node.expression.contains('price_total')) {
      _debugPrint(
          '   -> Context keys: ${_context.keys.where((k) => k.contains('price') || k.contains('line')).take(10).toList()}');
    }

    if (value == null) return [];

    // Parse options if present
    Map<String, dynamic>? options;
    if (node.options != null) {
      options = _valueFormatter.parseOptions(node.options!, _context);
    }

    // Auto-detect monetary fields if no widget specified
    if (options == null || !options.containsKey('widget')) {
      final expression = node.expression.toLowerCase();
      final isMonetaryField =
          _valueFormatter.isMonetaryFieldName(expression);

      if (isMonetaryField && value is num) {
        options ??= <String, dynamic>{};
        options['widget'] = 'monetary';

        // Try to get currency from context
        final currency = _valueFormatter.getCurrencyFromContext(
            node.expression, _context);
        if (currency != null) {
          options['display_currency'] = currency;
        }
      }
    }

    final formatted = _evaluator.formatValue(value, options, _context);
    // Ensure single line
    final cleanFormatted = formatted.toString().replaceAll('\n', ' ').trim();
    return [
      pw.Text(
        cleanFormatted,
        style: pw.TextStyle(fontSize: _options.baseFontSize),
        maxLines: 1,
      )
    ];
  }

  /// Render template call (t-call)
  List<pw.Widget> _renderCall(QWebCallNode node) {
    _debugPrint(
        '  t-call: "${node.templateName}" (has templateLoader: ${templateLoader != null})');

    if (templateLoader == null) {
      return node.children.expand(_renderNode).toList();
    }

    final templateName = node.templateName;
    final templateNode = templateLoader!(templateName);

    if (templateNode == null) {
      return [
        pw.Text(
          'Template not found: $templateName',
          style: const pw.TextStyle(color: PdfColors.red),
        )
      ];
    }

    _debugPrint(
        '  t-call: Template LOADED: $templateName (${templateNode.runtimeType})');

    // Process t-set children FIRST - these set context variables for the template
    final bodyChildren = <QWebNode>[];
    for (final child in node.children) {
      if (child is QWebSetNode) {
        final value = _evaluator.evaluate(child.expression, _context);

        // Debug tax_totals specifically
        if (child.variableName == 'tax_totals' ||
            child.expression.contains('tax_totals')) {
          _debugPrint(
              '  [T-CALL T-SET] ${child.variableName} = "${child.expression}"');
          if (_context.containsKey('doc')) {
            final doc = _context['doc'];
            if (doc is Map) {
              if (doc.containsKey('tax_totals')) {
                _debugPrint('   -> doc has tax_totals');
              }
            }
          }
          if (value is Map) {
            if (value.containsKey('subtotals')) {
              _debugPrint('   -> value has subtotals');
            }
          }
        }

        _context[child.variableName] = value;
      } else {
        bodyChildren.add(child);
      }
    }

    // Store caller's children in context variable '0' for body injection
    final capturedContext = Map<String, dynamic>.from(_context);
    final previousBody = _context['0'];
    _context['0'] = QWebBody(bodyChildren, capturedContext);

    try {
      return _renderNode(templateNode);
    } finally {
      if (previousBody != null) {
        _context['0'] = previousBody;
      } else {
        _context.remove('0');
      }
    }
  }

  /// Render dynamic attributes
  List<pw.Widget> _renderDynamicAttrs(QWebDynamicAttrsNode node) {
    for (final entry in node.formatAttrs.entries) {
      final interpolated =
          _textRenderer.interpolateFormat(entry.value, _context);
      _context['__attr_${entry.key}'] = interpolated;
    }

    for (final entry in node.dynamicAttrs.entries) {
      final value = _evaluator.evaluate(entry.value, _context);
      _context['__attr_${entry.key}'] = value;
    }

    return _renderNode(node.child);
  }

  /// Render attribute expression
  List<pw.Widget> _renderAtt(QWebAttNode node) {
    return _renderNode(node.child);
  }
}

/// Helper class to capture body context for t-call
class QWebBody {
  final List<QWebNode> nodes;
  final Map<String, dynamic> context;

  QWebBody(this.nodes, this.context);
}
