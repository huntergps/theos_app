import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../evaluator/expression_evaluator.dart';
import '../models/render_options.dart';
import '../parser/qweb_node.dart';

/// Represents a section break in the table (line_section or line_subsection).
/// Used to split tables and render section headers separately.
class SectionBreak {
  final String name;
  final double subtotal;
  final bool isSection; // true for section, false for subsection

  SectionBreak({
    required this.name,
    required this.subtotal,
    required this.isSection,
  });
}

/// Delegate interface for callbacks to the parent PDF renderer.
///
/// The table renderer needs to call back into the parent for rendering
/// child nodes, evaluating expressions, and accessing shared helpers.
abstract class QWebTableRendererDelegate {
  ExpressionEvaluator get evaluator;
  Map<String, dynamic> get context;
  set context(Map<String, dynamic> value);
  RenderOptions get options;
  QWebNode? Function(String)? get templateLoader;

  PdfColor getPrimaryColor();
  List<pw.Widget> renderNode(QWebNode node);
  String getTextContent(QWebNode node);
  String getTextFromNode(QWebNode node);
  String getTextFromWidget(pw.Widget widget);
  String formatCurrency(double value);
  pw.TextAlign getAlignment(String? cssClass, {String? cellName});
}

/// Renders HTML <table> elements to PDF table widgets.
///
/// Extracted from [QWebPdfRenderer] to separate table rendering concerns.
/// Uses [QWebTableRendererDelegate] to call back into the parent renderer
/// for shared functionality like node rendering and expression evaluation.
class QWebTableRenderer {
  final QWebTableRendererDelegate _delegate;

  QWebTableRenderer(this._delegate);

  // Convenience accessors
  ExpressionEvaluator get _evaluator => _delegate.evaluator;
  Map<String, dynamic> get _context => _delegate.context;
  set _context(Map<String, dynamic> value) => _delegate.context = value;
  RenderOptions get _options => _delegate.options;

  /// Render an HTML <table> element to PDF widgets.
  ///
  /// This is the main entry point, called from [QWebPdfRenderer._renderElement]
  /// when a `<table>` tag is encountered.
  List<pw.Widget> renderTable(QWebElementNode node) {
    final tableClass = node.attributes['class'] ?? 'no-class';
    final tableId = node.attributes['id'] ?? node.attributes['name'] ?? '';

    final headerRows = <dynamic>[];
    final bodyRows = <dynamic>[];

    // Check if this is the client/header info table
    // This table contains client information and should have a border
    final isInfoTable = tableClass.contains('o_information_table') ||
        tableClass.contains('oe_information_table') ||
        tableClass.contains('o_report_asset_table') ||
        tableId.contains('informations') ||
        tableId.contains('partner_info');

    // Helper function to collect rows from any QWebNode
    // Returns a mixed list of pw.TableRow and SectionBreak
    List<dynamic> collectRows(QWebNode node, bool isHeader) {
      final rows = <dynamic>[];

      if (node is QWebElementNode) {
        final tag = node.tagName.toLowerCase();
        if (tag == 'tr') {
          rows.add(_buildTableRow(node, isHeader: isHeader));
        } else if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
          for (final child in node.children) {
            rows.addAll(collectRows(child, tag == 'thead'));
          }
        }
      } else if (node is QWebForEachNode) {
        // Handle t-foreach: evaluate the loop and collect rows from each iteration
        final collection = _evaluator.evaluate(node.expression, _context);

        if (collection is List) {
          final originalContext = Map<String, dynamic>.from(_context);
          for (var i = 0; i < collection.length; i++) {
            final item = collection[i];
            // Set loop variables
            _context[node.itemVariable] = item;
            _context[node.indexVariable] = i;
            _context[node.firstVariable] = i == 0;
            _context[node.lastVariable] = i == collection.length - 1;
            _context[node.sizeVariable] = collection.length;
            _context[node.valueVariable] = item;
            _context[node.oddVariable] = i % 2;
            _context[node.evenVariable] = i % 2 == 0;
            _context[node.parityVariable] = i % 2 == 0 ? 'even' : 'odd';

            // Check if this is a section or subsection line
            if (item is Map) {
              final itemMap = Map<String, dynamic>.from(item);
              final displayType = itemMap['display_type'];
              final isSection = displayType == 'line_section';
              final isSubsection = displayType == 'line_subsection';

              if (isSection || isSubsection) {
                // Get section subtotal
                final priceField = _context['price_field'] ?? 'price_subtotal';
                double sectionTotal = 0.0;
                final sectionTotals = itemMap['section_totals'];
                if (sectionTotals is num) {
                  sectionTotal = sectionTotals.toDouble();
                } else {
                  final subtotal = itemMap[priceField];
                  if (subtotal is num) {
                    sectionTotal = subtotal.toDouble();
                  }
                }

                // Add section break marker instead of TableRow
                rows.add(SectionBreak(
                  name: itemMap['name']?.toString() ?? '',
                  subtotal: sectionTotal,
                  isSection: isSection,
                ));
                continue; // Skip normal row processing for sections
              }
            }

            // Collect rows from child
            rows.addAll(collectRows(node.child, isHeader));
          }
          _context = originalContext;
        }
      } else if (node is QWebIfNode) {
        // Handle t-if
        final condition =
            _evaluator.evaluateCondition(node.condition, _context);

        if (condition) {
          rows.addAll(collectRows(node.thenBranch, isHeader));
        } else if (node.elseBranch != null) {
          rows.addAll(collectRows(node.elseBranch!, isHeader));
        }
      } else if (node is QWebFragmentNode) {
        for (final child in node.children) {
          rows.addAll(collectRows(child, isHeader));
        }
      } else if (node is QWebSetNode) {
        // Handle t-set: evaluate and store variable in context
        final value = _evaluator.evaluate(node.expression, _context);
        _context[node.variableName] = value;
        // t-set doesn't produce rows, just affects context
      } else if (node is QWebSetContentNode) {
        // Handle t-set with content
        _context[node.variableName] =
            node.children.map(_delegate.getTextContent).join('');
      } else if (node is QWebDynamicAttrsNode) {
        // Handle dynamic attributes - process child to find tr elements
        rows.addAll(collectRows(node.child, isHeader));
      } else if (node is QWebCallNode) {
        // Handle t-call - load and process the called template
        if (_delegate.templateLoader != null) {
          final templateNode =
              _delegate.templateLoader!(node.templateName);
          if (templateNode != null) {
            // Process t-set children FIRST - these set context variables for the template
            for (final child in node.children) {
              if (child is QWebSetNode) {
                // Execute t-set immediately to set context variables
                final value =
                    _evaluator.evaluate(child.expression, _context);
                _context[child.variableName] = value;
              }
            }

            rows.addAll(collectRows(templateNode, isHeader));
          }
        }
      } else if (node is QWebEscNode ||
          node is QWebOutNode ||
          node is QWebFieldNode) {
        // These produce text content, not rows - skip them in table context
      } else if (node is QWebAttNode) {
        // Attribute nodes don't produce rows
      }

      return rows;
    }

    // Process table children
    for (final child in node.children) {
      if (child is QWebElementNode) {
        final tag = child.tagName.toLowerCase();
        if (tag == 'thead') {
          headerRows.addAll(collectRows(child, true));
        } else if (tag == 'tbody' || tag == 'tfoot') {
          bodyRows.addAll(collectRows(child, false));
        } else if (tag == 'tr') {
          bodyRows.add(_buildTableRow(child, isHeader: false));
        }
      } else {
        // Handle control flow nodes directly in table
        bodyRows.addAll(collectRows(child, false));
      }
    }

    // Separate header TableRows from body items (which may include SectionBreak)
    final headerTableRows = headerRows.whereType<pw.TableRow>().toList();

    // Check if this is the main products table
    final isMainTable = tableClass.contains('o_main_table');

    // For main tables with sections, we need to split the table at section breaks
    if (isMainTable && bodyRows.any((r) => r is SectionBreak)) {
      return _buildTableWithSections(
        headerTableRows: headerTableRows,
        bodyItems: bodyRows,
        tableClass: tableClass,
      );
    }

    // Regular table (no sections or not main table)
    final allTableRows = [
      ...headerTableRows,
      ...bodyRows.whereType<pw.TableRow>(),
    ];

    if (allTableRows.isEmpty) {
      return [];
    }

    // Determine column widths based on table type
    Map<int, pw.TableColumnWidth>? columnWidths;
    if (isMainTable && allTableRows.isNotEmpty) {
      final columnCount = allTableRows.first.children.length;
      // Column structure: Codigo, Descripcion, Cantidad, P.Unitario, [Descuento], [Impuestos], SubTotal
      // With discount and taxes: 7 columns
      // Without: 5 columns
      if (columnCount >= 4) {
        columnWidths = {
          0: const pw.FixedColumnWidth(50), // Codigo - fixed width
          1: const pw.FlexColumnWidth(
              3), // Descripcion - flexible, takes remaining space
        };
        // Adjust widths based on number of columns
        if (columnCount == 7) {
          // With discount and taxes
          columnWidths[2] = const pw.FixedColumnWidth(50); // Cantidad
          columnWidths[3] = const pw.FixedColumnWidth(60); // P.Unitario
          columnWidths[4] = const pw.FixedColumnWidth(60); // Descuento
          columnWidths[5] = const pw.FixedColumnWidth(60); // Impuestos
          columnWidths[6] = const pw.FixedColumnWidth(65); // SubTotal
        } else if (columnCount == 6) {
          // With either discount or taxes
          columnWidths[2] = const pw.FixedColumnWidth(50); // Cantidad
          columnWidths[3] = const pw.FixedColumnWidth(60); // P.Unitario
          columnWidths[4] =
              const pw.FixedColumnWidth(60); // Descuento/Impuestos
          columnWidths[5] = const pw.FixedColumnWidth(65); // SubTotal
        } else {
          // Standard: Codigo, Descripcion, Cantidad, P.Unitario, SubTotal
          columnWidths[2] = const pw.FixedColumnWidth(50); // Cantidad
          columnWidths[3] = const pw.FixedColumnWidth(60); // P.Unitario
          columnWidths[4] = const pw.FixedColumnWidth(65); // SubTotal
        }
      }
    }

    // All tables have light grey borders (matching Odoo's soft border style)
    final tableWidget = pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: columnWidths,
      children: allTableRows,
    );

    // Info table (client info): wrap with border and add spacing after
    if (isInfoTable) {
      return [
        pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: tableWidget,
        ),
      ];
    }

    // For main table: minimal spacing before (separates from document header info)
    // and no spacing after so it connects directly to totals table
    if (isMainTable) {
      return [
        pw.SizedBox(
            height: 5), // Reduced spacing between info section and lines table
        tableWidget,
      ];
    }

    // Other tables: add spacing after
    return [
      tableWidget,
      pw.SizedBox(height: 16),
    ];
  }

  /// Build a table with section breaks.
  /// Sections are rendered as full-width containers between table segments.
  List<pw.Widget> _buildTableWithSections({
    required List<pw.TableRow> headerTableRows,
    required List<dynamic> bodyItems,
    required String tableClass,
  }) {
    final widgets = <pw.Widget>[];
    final currentSegmentRows = <pw.TableRow>[];
    var isFirstSegment = true;

    // Determine column count from header
    int columnCount = 7; // Default
    if (headerTableRows.isNotEmpty) {
      columnCount = headerTableRows.first.children.length;
    }

    // Build column widths based on column count
    final columnWidths = _getMainTableColumnWidths(columnCount);

    // Helper to flush current segment as a table
    void flushSegment({bool includeHeader = false}) {
      if (currentSegmentRows.isEmpty && !includeHeader) return;

      final rows = <pw.TableRow>[];
      if (includeHeader && isFirstSegment) {
        rows.addAll(headerTableRows);
      }
      rows.addAll(currentSegmentRows);

      if (rows.isNotEmpty) {
        widgets.add(pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: columnWidths,
          children: rows,
        ));
      }
      currentSegmentRows.clear();
    }

    // Add initial spacing
    widgets.add(pw.SizedBox(height: 5));

    // Process body items
    for (final item in bodyItems) {
      if (item is SectionBreak) {
        // Flush current segment before section
        flushSegment(includeHeader: isFirstSegment);
        isFirstSegment = false;

        // Create section header widget (full-width)
        final sectionWidget = _buildSectionWidget(
          item,
          columnCount: columnCount,
        );
        widgets.add(sectionWidget);
      } else if (item is pw.TableRow) {
        currentSegmentRows.add(item);
      }
    }

    // Flush remaining rows
    if (currentSegmentRows.isNotEmpty) {
      flushSegment(includeHeader: isFirstSegment);
    }

    return widgets;
  }

  /// Get column widths for main table based on column count.
  Map<int, pw.TableColumnWidth> _getMainTableColumnWidths(int columnCount) {
    final columnWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(50), // Codigo
      1: const pw.FlexColumnWidth(3), // Descripcion
    };

    if (columnCount == 7) {
      columnWidths[2] = const pw.FixedColumnWidth(50); // Cantidad
      columnWidths[3] = const pw.FixedColumnWidth(60); // P.Unitario
      columnWidths[4] = const pw.FixedColumnWidth(60); // Descuento
      columnWidths[5] = const pw.FixedColumnWidth(60); // Impuestos
      columnWidths[6] = const pw.FixedColumnWidth(65); // SubTotal
    } else if (columnCount == 6) {
      columnWidths[2] = const pw.FixedColumnWidth(50);
      columnWidths[3] = const pw.FixedColumnWidth(60);
      columnWidths[4] = const pw.FixedColumnWidth(60);
      columnWidths[5] = const pw.FixedColumnWidth(65);
    } else {
      columnWidths[2] = const pw.FixedColumnWidth(50);
      columnWidths[3] = const pw.FixedColumnWidth(60);
      columnWidths[4] = const pw.FixedColumnWidth(65);
    }

    return columnWidths;
  }

  /// Build a section header widget (spans full width).
  pw.Widget _buildSectionWidget(SectionBreak section,
      {required int columnCount}) {
    final bgColor = section.isSection
        ? const PdfColor.fromInt(0xFFE9ECEF) // Light gray for sections
        : const PdfColor.fromInt(
            0xFFF8F9FA); // Very light gray for subsections

    final fontWeight =
        section.isSection ? pw.FontWeight.bold : pw.FontWeight.normal;
    final fontSize = _options.baseFontSize - 1;

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              section.name, // Keep original case (don't uppercase)
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: fontWeight,
                color: PdfColors.black,
              ),
            ),
          ),
          pw.Text(
            _delegate.formatCurrency(section.subtotal),
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a table row from a <tr> element.
  pw.TableRow _buildTableRow(QWebElementNode rowNode,
      {required bool isHeader}) {
    final cells = <pw.Widget>[];
    final primaryColor = _delegate.getPrimaryColor();

    for (final cellNode in rowNode.children) {
      // Handle QWebIfNode (cells with t-if)
      if (cellNode is QWebIfNode) {
        final condition =
            _evaluator.evaluateCondition(cellNode.condition, _context);
        if (condition) {
          // Process the thenBranch which should contain the <th> or <td>
          final thenBranch = cellNode.thenBranch;
          if (thenBranch is QWebElementNode) {
            final cellTag = thenBranch.tagName.toLowerCase();
            if (cellTag == 'th' || cellTag == 'td') {
              final cellIsHeader = cellTag == 'th' || isHeader;
              final cellName = thenBranch.attributes['name'] ?? '';
              final align = _delegate.getAlignment(
                  thenBranch.attributes['class'],
                  cellName: cellName);

              // Try to extract text directly from nodes first (handles nested conditions better)
              final hasMultipleChildren = thenBranch.children.length > 1;
              final hasConditionalChild = thenBranch.children.length == 1 &&
                  thenBranch.children.first is QWebIfNode;

              if (hasMultipleChildren || hasConditionalChild) {
                final rawTexts = thenBranch.children
                    .map(_delegate.getTextFromNode)
                    .toList();
                final cellText = rawTexts
                    .where((t) => t.isNotEmpty && t != 'Text')
                    .join(' ');
                if (cellText.isNotEmpty) {
                  cells.add(_buildCellWidget(
                    cellText: cellText,
                    cellIsHeader: cellIsHeader,
                    isHeader: isHeader,
                    align: align,
                  ));
                } else {
                  // Fallback to rendering widgets
                  final cellWidgets = _delegate.renderNode(thenBranch);
                  cells.add(_buildCellFromWidgets(
                    cellWidgets: cellWidgets,
                    cellIsHeader: cellIsHeader,
                    isHeader: isHeader,
                    align: align,
                  ));
                }
              } else {
                // Single non-conditional child, render normally
                final cellWidgets = _delegate.renderNode(thenBranch);

                // Use default styling for normal rows
                final textColor = cellIsHeader && isHeader
                    ? PdfColors.white
                    : PdfColors.black;
                final fontWeight =
                    cellIsHeader ? pw.FontWeight.bold : pw.FontWeight.normal;

                cells.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.DefaultTextStyle(
                      style: pw.TextStyle(
                        fontWeight: fontWeight,
                        fontSize: cellIsHeader
                            ? _options.baseFontSize
                            : _options.baseFontSize - 1,
                        color: textColor,
                      ),
                      textAlign: align,
                      child: cellWidgets.isEmpty
                          ? pw.Text('')
                          : cellWidgets.length == 1
                              ? cellWidgets.first
                              : pw.Column(children: cellWidgets),
                    ),
                  ),
                );
              }
            }
          } else if (thenBranch is QWebDynamicAttrsNode) {
            // Handle dynamic attributes wrapper - extract the actual element
            final innerNode = thenBranch.child;
            if (innerNode is QWebElementNode) {
              final cellTag = innerNode.tagName.toLowerCase();
              if (cellTag == 'th' || cellTag == 'td') {
                final cellIsHeader = cellTag == 'th' || isHeader;
                final cellName = innerNode.attributes['name'] ?? '';
                final align = _delegate.getAlignment(
                    innerNode.attributes['class'],
                    cellName: cellName);

                // Extract text directly from nodes (handles nested conditions better)
                final rawTexts = innerNode.children
                    .map(_delegate.getTextFromNode)
                    .toList();
                final cellText = rawTexts
                    .where((t) => t.isNotEmpty && t != 'Text')
                    .join(' ');

                if (cellText.isNotEmpty) {
                  cells.add(_buildCellWidget(
                    cellText: cellText,
                    cellIsHeader: cellIsHeader,
                    isHeader: isHeader,
                    align: align,
                  ));
                } else {
                  // Fallback to rendering widgets
                  final cellWidgets = _delegate.renderNode(innerNode);
                  cells.add(_buildCellFromWidgets(
                    cellWidgets: cellWidgets,
                    cellIsHeader: cellIsHeader,
                    isHeader: isHeader,
                    align: align,
                  ));
                }
              }
            }
          } else if (thenBranch is QWebFragmentNode) {
            // Fragment might contain the cell element
            for (final child in thenBranch.children) {
              if (child is QWebElementNode) {
                final cellTag = child.tagName.toLowerCase();
                if (cellTag == 'th' || cellTag == 'td') {
                  final cellWidgets = _delegate.renderNode(child);

                  final cellIsHeader = cellTag == 'th' || isHeader;
                  final cellName = child.attributes['name'] ?? '';
                  final align = _delegate.getAlignment(
                      child.attributes['class'],
                      cellName: cellName);

                  // Use default styling for normal rows
                  final textColor = cellIsHeader && isHeader
                      ? PdfColors.white
                      : PdfColors.black;
                  final fontWeight =
                      cellIsHeader ? pw.FontWeight.bold : pw.FontWeight.normal;

                  cells.add(
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.DefaultTextStyle(
                        style: pw.TextStyle(
                          fontWeight: fontWeight,
                          fontSize: cellIsHeader
                              ? _options.baseFontSize
                              : _options.baseFontSize - 1,
                          color: textColor,
                        ),
                        textAlign: align,
                        child: () {
                          // Try to extract text directly from nodes first
                          if (child.children.length > 1) {
                            final extractedText = child.children
                                .map(_delegate.getTextFromNode)
                                .where((t) => t.isNotEmpty && t != 'Text')
                                .join(' ');
                            if (extractedText.isNotEmpty) {
                              return pw.Text(
                                extractedText,
                                style: pw.TextStyle(
                                  fontWeight: fontWeight,
                                  fontSize: cellIsHeader
                                      ? _options.baseFontSize
                                      : _options.baseFontSize - 1,
                                  color: textColor,
                                ),
                                textAlign: align,
                              );
                            }
                          }
                          // Fallback to rendering widgets
                          return cellWidgets.isEmpty
                              ? pw.Text('')
                              : cellWidgets.length == 1
                                  ? cellWidgets.first
                                  : pw.Text(
                                      cellWidgets
                                          .map((w) =>
                                              _delegate.getTextFromWidget(w))
                                          .where((t) =>
                                              t.isNotEmpty && t != 'Text')
                                          .join(' '),
                                      style: pw.TextStyle(
                                        fontWeight: fontWeight,
                                        fontSize: cellIsHeader
                                            ? _options.baseFontSize
                                            : _options.baseFontSize - 1,
                                        color: textColor,
                                      ),
                                      textAlign: align,
                                    );
                        }(),
                      ),
                    ),
                  );
                }
              }
            }
          }
        } else {
          // condition is false, no cell added
        }
      } else if (cellNode is QWebElementNode) {
        final cellTag = cellNode.tagName.toLowerCase();
        if (cellTag == 'th' || cellTag == 'td') {
          final cellIsHeader = cellTag == 'th' || isHeader;
          final cellName = cellNode.attributes['name'] ?? '';
          final align = _delegate.getAlignment(cellNode.attributes['class'],
              cellName: cellName);

          // For cells, try to extract text directly from nodes first
          // This is more reliable than extracting from rendered widgets
          // Handle cells with t-if conditions (like quantity cell) or multiple children
          final hasMultipleChildren = cellNode.children.length > 1;
          final hasConditionalChild = cellNode.children.length == 1 &&
              cellNode.children.first is QWebIfNode;

          if (hasMultipleChildren || hasConditionalChild) {
            final cellText = cellNode.children
                .map(_delegate.getTextFromNode)
                .where((t) => t.isNotEmpty && t != 'Text')
                .join(' ');
            if (cellText.isNotEmpty) {
              cells.add(_buildCellWidget(
                cellText: cellText,
                cellIsHeader: cellIsHeader,
                isHeader: isHeader,
                align: align,
              ));
            } else {
              // Fallback to rendering widgets
              final cellWidgets = _delegate.renderNode(cellNode);
              cells.add(_buildCellFromWidgets(
                cellWidgets: cellWidgets,
                cellIsHeader: cellIsHeader,
                isHeader: isHeader,
                align: align,
              ));
            }
          } else {
            // Single child, render normally
            final cellWidgets = _delegate.renderNode(cellNode);
            final singleCellText = cellWidgets
                .map((w) => _delegate.getTextFromWidget(w))
                .where((t) => t.isNotEmpty)
                .join(' ');

            // Use default styling for normal rows
            final textColor =
                cellIsHeader && isHeader ? PdfColors.white : PdfColors.black;
            final fontWeight =
                cellIsHeader ? pw.FontWeight.bold : pw.FontWeight.normal;

            cells.add(
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.DefaultTextStyle(
                  style: pw.TextStyle(
                    fontWeight: fontWeight,
                    fontSize: cellIsHeader
                        ? _options.baseFontSize
                        : _options.baseFontSize - 1,
                    color: textColor,
                  ),
                  textAlign: align,
                  child: cellWidgets.isEmpty
                      ? pw.Text('')
                      : cellWidgets.length == 1
                          ? cellWidgets.first
                          : pw.Text(
                              singleCellText,
                              style: pw.TextStyle(
                                fontWeight: fontWeight,
                                fontSize: cellIsHeader
                                    ? _options.baseFontSize
                                    : _options.baseFontSize - 1,
                                color: textColor,
                              ),
                              textAlign: align,
                            ),
                ),
              ),
            );
          }
        }
      }
    }

    // Determine row decoration (background color)
    // Header rows get primary color background
    pw.BoxDecoration? decoration;

    if (isHeader) {
      decoration = pw.BoxDecoration(color: primaryColor);
    }

    return pw.TableRow(
      decoration: decoration,
      children: cells,
    );
  }

  /// Helper: build a cell widget with text content.
  pw.Widget _buildCellWidget({
    required String cellText,
    required bool cellIsHeader,
    required bool isHeader,
    required pw.TextAlign align,
  }) {
    final textColor =
        cellIsHeader && isHeader ? PdfColors.white : PdfColors.black;
    final fontWeight =
        cellIsHeader ? pw.FontWeight.bold : pw.FontWeight.normal;

    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.DefaultTextStyle(
        style: pw.TextStyle(
          fontWeight: fontWeight,
          fontSize: cellIsHeader
              ? _options.baseFontSize
              : _options.baseFontSize - 1,
          color: textColor,
        ),
        textAlign: align,
        child: pw.Text(
          cellText,
          style: pw.TextStyle(
            fontWeight: fontWeight,
            fontSize: cellIsHeader
                ? _options.baseFontSize
                : _options.baseFontSize - 1,
            color: textColor,
          ),
          textAlign: align,
        ),
      ),
    );
  }

  /// Helper: build a cell widget from rendered child widgets (fallback).
  pw.Widget _buildCellFromWidgets({
    required List<pw.Widget> cellWidgets,
    required bool cellIsHeader,
    required bool isHeader,
    required pw.TextAlign align,
  }) {
    final textColor =
        cellIsHeader && isHeader ? PdfColors.white : PdfColors.black;
    final fontWeight =
        cellIsHeader ? pw.FontWeight.bold : pw.FontWeight.normal;
    final fallbackText = cellWidgets
        .map((w) => _delegate.getTextFromWidget(w))
        .where((t) => t.isNotEmpty)
        .join(' ');

    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.DefaultTextStyle(
        style: pw.TextStyle(
          fontWeight: fontWeight,
          fontSize: cellIsHeader
              ? _options.baseFontSize
              : _options.baseFontSize - 1,
          color: textColor,
        ),
        textAlign: align,
        child: cellWidgets.isEmpty
            ? pw.Text('')
            : cellWidgets.length == 1
                ? cellWidgets.first
                : pw.Text(
                    fallbackText,
                    style: pw.TextStyle(
                      fontWeight: fontWeight,
                      fontSize: cellIsHeader
                          ? _options.baseFontSize
                          : _options.baseFontSize - 1,
                      color: textColor,
                    ),
                    textAlign: align,
                  ),
      ),
    );
  }
}
