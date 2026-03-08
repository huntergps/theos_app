/// Line Preprocessor - Pre-processes record lines for QWeb report generation.
///
/// Extracted from [ReportService] to separate line preprocessing logic
/// from template management, report generation orchestration, and file handling.
library;

import 'package:flutter/foundation.dart';

import '../models/report_locale.dart';
import '../models/report_model_config.dart';

class _PreprocessorLogger {
  void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('$tag $message');
    }
  }
}

final _log = _PreprocessorLogger();

/// Pre-processes record lines and builds evaluation contexts for QWeb
/// PDF report generation.
class LinePreprocessor {
  /// Pre-processes a line for report generation, ensuring all necessary fields
  /// and methods are present.
  ///
  /// This method normalizes lines from any document type (sale orders, invoices,
  /// etc.) to ensure consistent rendering in QWeb templates. It is idempotent.
  void preprocessLine(
    Map<String, dynamic> line, {
    Map<String, dynamic>? taxTotals,
    ReportLocale? locale,
  }) {
    // Add _has_taxes method (returns true if line has taxes)
    if (line['_has_taxes'] == null) {
      line['_has_taxes'] = () {
        final taxIds = line['tax_ids'];
        if (taxIds is List && taxIds.isNotEmpty) return true;
        final taxId = line['tax_id'];
        if (taxId is List && taxId.isNotEmpty) return true;
        final taxAmount = line['tax_amount'];
        if (taxAmount is num && taxAmount > 0) return true;
        final priceTax = line['price_tax'];
        if (priceTax is num && priceTax > 0) return true;
        final displayType = line['display_type'];
        if (displayType == 'line_section' ||
            displayType == 'line_subsection') {
          return false;
        }
        return false;
      };
    }

    // Ensure common fields have defaults
    line['discount'] ??= 0.0;
    line['price_unit'] ??= 0.0;
    line['product_uom_qty'] ??=
        (line['quantity'] as num?)?.toDouble() ?? 0.0;
    line['quantity'] ??=
        (line['product_uom_qty'] as num?)?.toDouble() ?? 0.0;
    line['price_subtotal'] ??= 0.0;
    line['price_total'] ??= 0.0;
    if (line['display_type'] == null || line['display_type'] == false) {
      line['display_type'] = 'product';
    }
    line['is_downpayment'] ??= false;
    line['collapse_composition'] ??= false;
    line['collapse_prices'] ??= false;
    line['product_type'] ??= 'product';

    // Compute tax_amount if not present
    if (line['tax_amount'] == null) {
      final subtotal = (line['price_subtotal'] as num?)?.toDouble() ?? 0.0;
      final total = (line['price_total'] as num?)?.toDouble() ?? 0.0;
      line['tax_amount'] = total - subtotal;
    }

    // Compute discount_amount if not present or if it's 0 but discount > 0
    final existingDiscountAmount =
        (line['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final discount = (line['discount'] as num?)?.toDouble() ?? 0.0;
    if (line['discount_amount'] == null ||
        (existingDiscountAmount == 0.0 && discount > 0)) {
      final priceUnit = (line['price_unit'] as num?)?.toDouble() ?? 0.0;
      final qty = (line['product_uom_qty'] as num?)?.toDouble() ??
          (line['quantity'] as num?)?.toDouble() ??
          0.0;
      if (discount > 0 && qty > 0) {
        line['discount_amount'] = priceUnit * qty * discount / 100.0;
      } else {
        line['discount_amount'] = 0.0;
      }
    }

    // Ensure formatted fields exist
    final effectiveLocale = locale ?? const ReportLocale();

    String formatCurrency(double amount) {
      return effectiveLocale.formatCurrency(amount);
    }

    String formatDecimal(double amount) {
      return amount
          .toStringAsFixed(effectiveLocale.decimalPlaces)
          .replaceAll('.', effectiveLocale.decimalSeparator);
    }

    final priceUnit = (line['price_unit'] as num?)?.toDouble() ?? 0.0;
    final priceSubtotal =
        (line['price_subtotal'] as num?)?.toDouble() ?? 0.0;
    final priceTotal = (line['price_total'] as num?)?.toDouble() ?? 0.0;
    final priceTax = (line['price_tax'] as num?)?.toDouble() ??
        (line['tax_amount'] as num?)?.toDouble() ??
        0.0;
    final discountAmt =
        (line['discount_amount'] as num?)?.toDouble() ?? 0.0;

    line['formatted_price_unit'] ??= formatCurrency(priceUnit);
    line['formatted_price_subtotal'] ??= formatCurrency(priceSubtotal);
    line['formatted_price_total'] ??= formatCurrency(priceTotal);
    line['formatted_discount'] ??= formatDecimal(discount);
    line['formatted_discount_amount'] ??= formatCurrency(discountAmt);
    line['formatted_price_tax'] ??= formatCurrency(priceTax);
    line['formatted_tax_amount'] ??= formatCurrency(priceTax);

    // Update tax_ids with correct names from tax_totals
    String taxNamesFromTotals = '';

    if (taxTotals != null) {
      final groupsBySubtotal = taxTotals['groups_by_subtotal'];

      List<dynamic>? groups;
      if (groupsBySubtotal is Map && groupsBySubtotal.isNotEmpty) {
        final firstKey = groupsBySubtotal.keys.first;
        groups = groupsBySubtotal[firstKey] as List?;
      }

      if (groups != null && groups.isNotEmpty) {
        final groupNames = groups
            .map((g) => g is Map ? (g['group_name'] ?? '') : '')
            .where((n) => n.toString().isNotEmpty)
            .toList();
        if (groupNames.isNotEmpty) {
          taxNamesFromTotals = groupNames.join(', ');

          final taxIds = line['tax_ids'];
          if (taxIds is List && taxIds.isNotEmpty) {
            for (var i = 0; i < taxIds.length; i++) {
              if (taxIds[i] is Map) {
                final groupName = i < groupNames.length
                    ? groupNames[i]
                    : groupNames.first;
                (taxIds[i] as Map)['name'] = groupName;
                (taxIds[i] as Map)['tax_label'] = groupName;
              }
            }
          }
        }
      }
    }

    // Set tax_names
    if (line['tax_names'] == null || taxNamesFromTotals.isNotEmpty) {
      if (taxNamesFromTotals.isNotEmpty) {
        line['tax_names'] = taxNamesFromTotals;
      } else {
        final taxIds = line['tax_ids'];
        if (taxIds is List && taxIds.isNotEmpty) {
          final names = taxIds
              .map(
                  (t) => t is Map ? (t['name'] ?? t['tax_label'] ?? '') : '')
              .where((n) => n.isNotEmpty)
              .toList();
          line['tax_names'] = names.join(', ');
        } else {
          line['tax_names'] = '';
        }
      }
    }

    // Extract product code from name if default_code and barcode are empty
    final productId = line['product_id'];
    if (productId is Map) {
      final defaultCode = productId['default_code']?.toString() ?? '';
      final barcode = productId['barcode']?.toString() ?? '';
      if (defaultCode.isEmpty && barcode.isEmpty) {
        final productName = productId['name']?.toString() ?? '';
        final bracketMatch =
            RegExp(r'^\[([^\]]+)\]').firstMatch(productName);
        if (bracketMatch != null) {
          productId['default_code'] = bracketMatch.group(1);
        } else {
          final parenMatch =
              RegExp(r'^\(([^)]+)\)').firstMatch(productName);
          if (parenMatch != null) {
            productId['default_code'] = parenMatch.group(1);
          }
        }
      }
    }

    // Add with_context method (returns same object, for template compatibility)
    if (line['with_context'] == null) {
      line['with_context'] = ([Map<String, dynamic>? ctx]) => line;
    }
  }

  /// Process a list of records for report generation.
  ///
  /// Returns the processed records with lines preprocessed,
  /// display_discount/display_taxes calculated, tax_totals enriched, etc.
  List<Map<String, dynamic>> processRecords({
    required List<Map<String, dynamic>> records,
    required ReportLocale locale,
    required ReportModelConfig modelConfig,
  }) {
    return records.map((record) {
      final r = Map<String, dynamic>.from(record);

      // Extract tax_totals for line preprocessing
      final originalTaxTotals = r['tax_totals'];
      final taxTotalsMap = originalTaxTotals is Map
          ? Map<String, dynamic>.from(originalTaxTotals)
          : null;

      // Find raw lines using config-driven field names
      List<Map<String, dynamic>> rawLines = [];
      String? foundLineField;
      for (final fieldName in modelConfig.lineFields) {
        final fieldValue = r[fieldName];
        if (fieldValue is List && fieldValue.isNotEmpty) {
          rawLines = fieldValue.map((line) {
            if (line is Map) return Map<String, dynamic>.from(line);
            return <String, dynamic>{};
          }).toList();
          foundLineField = fieldName;
          break;
        }
      }

      // Pre-process raw lines
      for (final line in rawLines) {
        preprocessLine(line, taxTotals: taxTotalsMap, locale: locale);
      }

      // === Implement Odoo's _get_order_lines_to_report() ===
      List<Map<String, dynamic>> getOrderLinesToReport() {
        final downPaymentLines = rawLines.where((line) {
          final isDownpayment = line['is_downpayment'] == true;
          final displayType = line['display_type'];
          return isDownpayment && displayType == false;
        }).toList();

        bool showLine(Map<String, dynamic> line) {
          final isDownpayment = line['is_downpayment'] == true;

          if (isDownpayment) {
            final displayType = line['display_type'];
            if (displayType != false && displayType != null) {
              return downPaymentLines.isNotEmpty;
            }
            return downPaymentLines.contains(line);
          }

          final displayType = line['display_type'];
          if (displayType == 'line_section') {
            return true;
          }

          final parentLine = line['parent_id'];
          if (parentLine is Map) {
            if (parentLine['collapse_composition'] == true) {
              return false;
            }
            final grandparentLine = parentLine['parent_id'];
            if (grandparentLine is Map &&
                grandparentLine['collapse_composition'] == true) {
              return false;
            }
          }

          return true;
        }

        return rawLines.where(showLine).toList();
      }

      // Compute and store lines_to_report
      List<Map<String, dynamic>> linesToReport;
      if (rawLines.isNotEmpty) {
        linesToReport = getOrderLinesToReport();
        r['lines_to_report'] = linesToReport;
        if (foundLineField != null) {
          r[foundLineField] = rawLines;
        }
      } else {
        final existingLines = r['lines_to_report'];
        if (existingLines is List && existingLines.isNotEmpty) {
          linesToReport = existingLines.map((line) {
            if (line is Map) return Map<String, dynamic>.from(line);
            return <String, dynamic>{};
          }).toList();
        } else {
          linesToReport = <Map<String, dynamic>>[];
        }
        if (linesToReport.isNotEmpty) {
          r['lines_to_report'] = linesToReport;
        }
      }

      // Pre-process ALL lines for consistent normalization
      for (final line in linesToReport) {
        preprocessLine(line, taxTotals: taxTotalsMap, locale: locale);
      }

      // Calculate display_discount and display_taxes
      final hasDiscount = linesToReport.any((line) {
        final discount = line['discount'] as num? ?? 0.0;
        final discountAmount = line['discount_amount'] as num? ?? 0.0;
        return discount > 0 || discountAmount > 0;
      });

      final hasTaxes = linesToReport.any((line) {
        final hasTaxesMethod = line['_has_taxes'];
        if (hasTaxesMethod is Function) {
          return hasTaxesMethod() == true;
        }
        final taxAmount = line['tax_amount'] as num? ?? 0.0;
        final priceTax = line['price_tax'] as num? ?? 0.0;
        return taxAmount > 0 || priceTax > 0;
      });

      r['display_discount'] = hasDiscount;
      r['display_taxes'] = hasTaxes;

      // === DIAGNOSTIC LOGGING ===
      _log.d('[LinePreprocessor]', '=== PDF LINE DEBUG ===');
      _log.d('[LinePreprocessor]', 'hasDiscount: $hasDiscount');
      _log.d('[LinePreprocessor]', 'hasTaxes: $hasTaxes');
      _log.d('[LinePreprocessor]',
          'linesToReport count: ${linesToReport.length}');
      for (int i = 0; i < linesToReport.length && i < 3; i++) {
        final line = linesToReport[i];
        _log.d('[LinePreprocessor]',
            'Line $i: ${line['name'] ?? line['product_id']?['name'] ?? 'N/A'}');
        _log.d('[LinePreprocessor]',
            '  display_type: ${line['display_type']}');
        _log.d('[LinePreprocessor]', '  discount: ${line['discount']}');
        _log.d('[LinePreprocessor]',
            '  formatted_discount: ${line['formatted_discount']}');
        _log.d('[LinePreprocessor]',
            '  price_subtotal: ${line['price_subtotal']}');
        _log.d('[LinePreprocessor]',
            '  formatted_price_subtotal: ${line['formatted_price_subtotal']}');
        _log.d('[LinePreprocessor]', '  tax_names: ${line['tax_names']}');
        _log.d('[LinePreprocessor]',
            '  collapse_prices: ${line['collapse_prices']}');
        _log.d('[LinePreprocessor]',
            '  collapse_composition: ${line['collapse_composition']}');
      }
      _log.d('[LinePreprocessor]',
          'company_price_include: ${r['company_price_include']}');
      _log.d('[LinePreprocessor]', '=== END PDF LINE DEBUG ===');

      // Odoo methods mocking as closures
      r['_get_order_lines_to_report'] = () => linesToReport;
      r['_get_move_lines_to_report'] = () => linesToReport;
      r['invoice_line_ids'] = linesToReport;
      r['get_portal_url'] = () => '';
      r['with_context'] = ([Map<String, dynamic>? ctx]) => r;

      // Calculate total discount from processed lines
      final totalDiscountAmount =
          linesToReport.fold<double>(0.0, (sum, line) {
        final discountAmt =
            (line['discount_amount'] as num?)?.toDouble() ?? 0.0;
        return sum + discountAmt;
      });
      final amountUntaxed =
          (r['amount_untaxed'] as num?)?.toDouble() ?? 0.0;
      final amountUndiscounted = amountUntaxed + totalDiscountAmount;

      // Update tax_totals with correct discount values
      if (r['tax_totals'] is Map) {
        final taxTotals = r['tax_totals'] as Map<String, dynamic>;
        taxTotals['has_discounts'] = hasDiscount || totalDiscountAmount > 0;
        taxTotals['amount_undiscounted_currency'] = amountUndiscounted;
        taxTotals['discount_amount_currency'] = totalDiscountAmount;
      }

      // Ensure tax_totals is present
      if (r['tax_totals'] == null) {
        final amountTax = (r['amount_tax'] as num?)?.toDouble() ?? 0.0;
        final amountTotal =
            (r['amount_total'] as num?)?.toDouble() ?? 0.0;

        final subtotalLabel = modelConfig.subtotalLabel.isNotEmpty
            ? modelConfig.subtotalLabel
            : locale.labelSubtotal;
        final taxGroupLabel = modelConfig.defaultTaxGroupName ??
            locale.defaultTaxGroupLabel ??
            'Tax';

        r['tax_totals'] = {
          'amount_untaxed': amountUntaxed,
          'amount_total': amountTotal,
          'total_amount_currency': amountTotal,
          'formatted_amount_total': locale.formatCurrency(amountTotal),
          'formatted_amount_untaxed': locale.formatCurrency(amountUntaxed),
          'has_discounts': hasDiscount || totalDiscountAmount > 0,
          'amount_undiscounted_currency': amountUndiscounted,
          'discount_amount_currency': totalDiscountAmount,
          'subtotals': [
            {
              'name': subtotalLabel,
              'amount': amountUntaxed,
              'base_amount_currency': amountUntaxed,
              'formatted_amount': locale.formatCurrency(amountUntaxed),
              'tax_groups': [
                if (amountTax > 0)
                  {
                    'group_name': taxGroupLabel,
                    'tax_group_amount': amountTax,
                    'tax_amount_currency': amountTax,
                    'base_amount_currency': amountUntaxed,
                    'display_base_amount_currency': amountUntaxed,
                    'formatted_tax_group_amount':
                        locale.formatCurrency(amountTax),
                    'group_key': 1,
                  },
              ],
            },
          ],
          'groups_by_subtotal': {
            subtotalLabel: [
              if (amountTax > 0)
                {
                  'group_name': taxGroupLabel,
                  'tax_group_amount': amountTax,
                  'tax_amount_currency': amountTax,
                  'formatted_tax_group_amount':
                      locale.formatCurrency(amountTax),
                  'group_key': 1,
                },
            ],
          },
        };
      }

      return r;
    }).toList();
  }

  /// Build the evaluation context for QWeb template rendering.
  Map<String, dynamic> buildContext({
    required List<Map<String, dynamic>> processedRecords,
    required Map<String, dynamic> companyMap,
    required Map<String, dynamic>? user,
    required String docModel,
  }) {
    final docTaxTotals = processedRecords.isNotEmpty
        ? processedRecords.first['tax_totals']
        : null;

    return {
      'docs': processedRecords,
      if (processedRecords.isNotEmpty) 'doc': processedRecords.first,
      if (processedRecords.isNotEmpty) 'o': processedRecords.first,
      if (docTaxTotals != null) 'tax_totals': docTaxTotals,
      'doc_ids': processedRecords.map((r) => r['id']).toList(),
      'doc_model': docModel,
      if (processedRecords.isNotEmpty)
        'currency_id': processedRecords.first['currency_id'],
      'user': user ?? {},
      'company': companyMap,
      'res_company': companyMap,
      'is_html_empty': (String? html) =>
          html == null || html.trim().isEmpty,
      'display_taxes': processedRecords.any((r) {
        if (r['display_taxes'] == true) return true;
        final linesToReport = r['lines_to_report'] as List?;
        if (linesToReport != null) {
          return linesToReport.any((line) {
            if (line is Map) {
              final hasTaxesMethod = line['_has_taxes'];
              if (hasTaxesMethod is Function) {
                return hasTaxesMethod() == true;
              }
              final taxAmount = line['tax_amount'] as num? ?? 0.0;
              final priceTax = line['price_tax'] as num? ?? 0.0;
              return taxAmount > 0 || priceTax > 0;
            }
            return false;
          });
        }
        return true;
      }),
      'hide_taxes_details': false,
      'price_field': 'price_subtotal',
      'display_discount': processedRecords.any((r) {
        if (r['display_discount'] == true) return true;
        final linesToReport = r['lines_to_report'] as List?;
        if (linesToReport != null) {
          return linesToReport.any((line) {
            if (line is Map) {
              final discount = line['discount'] as num? ?? 0.0;
              final discountAmount = line['discount_amount'] as num? ?? 0.0;
              return discount > 0 || discountAmount > 0;
            }
            return false;
          });
        }
        return false;
      }),
      'is_pro_forma': false,
      'is_proforma': false,
      'report_type': 'pdf',
      'lines_to_report': processedRecords.isNotEmpty
          ? (processedRecords.first['lines_to_report'] ??
              processedRecords.first['order_line'] ??
              [])
          : [],
    };
  }

  /// Enrich company map for Odoo template compatibility.
  Map<String, dynamic> enrichCompanyMap(Map<String, dynamic>? company) {
    final companyMap =
        company != null ? Map<String, dynamic>.from(company) : <String, dynamic>{};
    if (!companyMap.containsKey('partner_id')) {
      companyMap['partner_id'] = {
        'name': companyMap['name'],
        'street': companyMap['street'],
        'street2': companyMap['street2'],
        'city': companyMap['city'],
        'state_id': companyMap['state_id'],
        'zip': companyMap['zip'],
        'country_id': companyMap['country_id'],
        'phone': companyMap['phone'],
        'email': companyMap['email'],
        'vat': companyMap['vat'],
      };
    }
    return companyMap;
  }
}
