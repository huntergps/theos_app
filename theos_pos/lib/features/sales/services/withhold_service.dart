import 'package:theos_pos_core/theos_pos_core.dart'
    show WithholdLine, withholdLineManager, AvailableWithholdTax,
         userManager, UserManagerBusiness;

import '../../../core/services/logger_service.dart';
import '../../../core/services/odoo_service.dart';
import '../../../shared/utils/formatting_utils.dart';

/// Result of withhold authorization validation
class WithholdAuthorizationValidation {
  final bool isValid;
  final String? errorMessage;

  const WithholdAuthorizationValidation._({
    required this.isValid,
    this.errorMessage,
  });

  factory WithholdAuthorizationValidation.valid() =>
      const WithholdAuthorizationValidation._(isValid: true);

  factory WithholdAuthorizationValidation.invalid(String message) =>
      WithholdAuthorizationValidation._(isValid: false, errorMessage: message);
}

/// Servicio para gestionar retenciones en órdenes de venta
class WithholdService {
  final OdooService _odoo;

  WithholdService(this._odoo);

  /// Get the current user's company_id, defaulting to 1 if unavailable
  Future<int> _getUserCompanyId() async {
    try {
      final user = await userManager.getCurrentUser();
      final companyId = user?.companyId;
      if (companyId == null) {
        logger.w('[WithholdService]', 'company_id not available from user, using fallback=1');
        return 1;
      }
      return companyId;
    } catch (e) {
      logger.w('[WithholdService]', 'Error getting company_id, using fallback=1: $e');
      return 1;
    }
  }

  /// Validates a physical withhold authorization number
  ///
  /// Physical withholds require an authorization number with exactly 49 digits.
  /// This is required by SRI Ecuador for physical (non-electronic) withholds.
  ///
  /// Returns [WithholdAuthorizationValidation] with validation result.
  static WithholdAuthorizationValidation validateAuthorization(
      String? authorization) {
    if (authorization == null || authorization.isEmpty) {
      return WithholdAuthorizationValidation.valid(); // Empty is optional
    }

    // Clean the authorization (remove spaces and hyphens)
    final cleaned = authorization.replaceAll(RegExp(r'[\s-]'), '');

    // Must be exactly 49 digits
    if (cleaned.length != 49) {
      return WithholdAuthorizationValidation.invalid(
        'La autorización de retención física debe tener exactamente 49 dígitos. '
        'Tiene ${cleaned.length} dígitos.',
      );
    }

    // Must be all digits
    if (!RegExp(r'^\d{49}$').hasMatch(cleaned)) {
      return WithholdAuthorizationValidation.invalid(
        'La autorización solo debe contener dígitos numéricos.',
      );
    }

    return WithholdAuthorizationValidation.valid();
  }

  /// Obtiene los impuestos de retención disponibles para ventas
  ///
  /// Retorna impuestos con tax_group_id.l10n_ec_type en:
  /// - withhold_vat_sale: Retención de IVA
  /// - withhold_income_sale: Retención de Renta (IR)
  Future<List<AvailableWithholdTax>> getAvailableWithholdTaxes() async {
    try {
      // Buscar impuestos de retención para ventas
      final companyId = await _getUserCompanyId();
      final taxes = await _odoo.call(
        model: 'account.tax',
        method: 'search_read',
        kwargs: {
          'domain': [
            ['tax_group_id.l10n_ec_type', 'in', ['withhold_vat_sale', 'withhold_income_sale']],
            ['active', '=', true],
            ['company_id', '=', companyId],
          ],
          'fields': ['id', 'name', 'amount', 'tax_group_id', 'description'],
          'order': 'sequence, name',
        },
      );

      if (taxes == null || taxes is! List) {
        return [];
      }

      // Caché de grupos de impuesto para evitar consultas repetidas
      final groupCache = <int, String>{};

      // Obtener el tipo de cada grupo de impuesto
      final result = <AvailableWithholdTax>[];
      for (final taxData in taxes) {
        final tax = taxData as Map<String, dynamic>;

        // Obtener el tipo del grupo de impuesto
        final taxGroupId = tax['tax_group_id'];
        int? groupId;
        if (taxGroupId is List && taxGroupId.isNotEmpty) {
          groupId = taxGroupId[0] as int;
        } else if (taxGroupId is int) {
          groupId = taxGroupId;
        }

        if (groupId == null) continue;

        // Obtener l10n_ec_type del grupo (usar caché si ya lo tenemos)
        String? l10nEcType = groupCache[groupId];
        if (l10nEcType == null) {
          final groupData = await _odoo.call(
            model: 'account.tax.group',
            method: 'search_read',
            kwargs: {
              'domain': [['id', '=', groupId]],
              'fields': ['l10n_ec_type'],
              'limit': 1,
            },
          );

          if (groupData is List && groupData.isNotEmpty) {
            l10nEcType = (groupData[0] as Map<String, dynamic>)['l10n_ec_type'] as String?;
            if (l10nEcType != null) {
              groupCache[groupId] = l10nEcType;
            }
          }
        }

        tax['tax_group_l10n_ec_type'] = l10nEcType;

        // Generar nombre en español basado en el porcentaje y tipo
        final percent = (tax['amount'] as num).toDouble().abs();
        final percentStr = percent == percent.truncateToDouble()
            ? percent.toInt().toString()
            : percent.toFixed(2);

        String spanishName;
        if (l10nEcType == 'withhold_vat_sale') {
          spanishName = '$percentStr% Ret. IVA';
        } else if (l10nEcType == 'withhold_income_sale') {
          spanishName = '$percentStr% Ret. de la Fuente';
        } else {
          // Usar el nombre original si no podemos determinar el tipo
          spanishName = tax['name'] as String;
        }
        tax['spanish_name'] = spanishName;

        result.add(AvailableWithholdTax.fromOdoo(tax));
      }

      return result;
    } catch (e, st) {
      logger.e('[WithholdService]', 'Error getting withhold taxes', e, st);
      return [];
    }
  }

  /// Obtiene las líneas de retención existentes de una orden de venta
  ///
  /// Obtiene las líneas y enriquece con información del impuesto (porcentaje, tipo)
  Future<List<WithholdLine>> getWithholdLines(int saleOrderId) async {
    try {
      final lines = await _odoo.call(
        model: 'sale.order.withhold.line',
        method: 'search_read',
        kwargs: {
          'domain': [['sale_id', '=', saleOrderId]],
          'fields': ['id', 'tax_id', 'taxsupport_code', 'base', 'amount', 'notes'],
          'order': 'sequence, id',
        },
      );

      if (lines == null || lines is! List || lines.isEmpty) {
        return [];
      }

      // Get unique tax IDs to fetch tax info
      final taxIds = <int>{};
      for (final line in lines) {
        final taxId = line['tax_id'];
        if (taxId is List && taxId.isNotEmpty) {
          taxIds.add(taxId[0] as int);
        } else if (taxId is int) {
          taxIds.add(taxId);
        }
      }

      // Fetch tax info (percent and group type)
      final taxInfoMap = <int, Map<String, dynamic>>{};
      if (taxIds.isNotEmpty) {
        final taxes = await _odoo.call(
          model: 'account.tax',
          method: 'search_read',
          kwargs: {
            'domain': [['id', 'in', taxIds.toList()]],
            'fields': ['id', 'name', 'amount', 'tax_group_id'],
          },
        );

        if (taxes is List) {
          // Get group types
          final groupIds = <int>{};
          for (final tax in taxes) {
            final groupId = tax['tax_group_id'];
            if (groupId is List && groupId.isNotEmpty) {
              groupIds.add(groupId[0] as int);
            }
          }

          final groupTypes = <int, String>{};
          if (groupIds.isNotEmpty) {
            final groups = await _odoo.call(
              model: 'account.tax.group',
              method: 'search_read',
              kwargs: {
                'domain': [['id', 'in', groupIds.toList()]],
                'fields': ['id', 'l10n_ec_type'],
              },
            );
            if (groups is List) {
              for (final g in groups) {
                groupTypes[g['id'] as int] = g['l10n_ec_type'] as String? ?? '';
              }
            }
          }

          // Build tax info map
          for (final tax in taxes) {
            final taxId = tax['id'] as int;
            final groupId = tax['tax_group_id'];
            int? gId;
            if (groupId is List && groupId.isNotEmpty) {
              gId = groupId[0] as int;
            }
            taxInfoMap[taxId] = {
              'name': tax['name'],
              'amount': tax['amount'],
              'l10n_ec_type': gId != null ? groupTypes[gId] : null,
            };
          }
        }
      }

      // Map lines with enriched tax info
      final result = <WithholdLine>[];
      for (final lineData in lines) {
        final line = lineData as Map<String, dynamic>;

        // Get tax ID
        final taxIdData = line['tax_id'];
        final int taxId;
        if (taxIdData is List && taxIdData.isNotEmpty) {
          taxId = taxIdData[0] as int;
        } else {
          taxId = taxIdData as int;
        }

        // Get enriched tax info
        final taxInfo = taxInfoMap[taxId];
        final taxPercent = (taxInfo?['amount'] as num?)?.toDouble() ?? 0.0;
        final l10nEcType = taxInfo?['l10n_ec_type'] as String?;

        // Add enriched data to line
        line['tax_percent'] = taxPercent.abs() / 100; // Convert to decimal
        line['tax_group_l10n_ec_type'] = l10nEcType;

        result.add(withholdLineManager.fromOdoo(line));
      }

      logger.d('[WithholdService]', 'Got ${result.length} withhold lines for order $saleOrderId');
      return result;
    } catch (e, st) {
      logger.e('[WithholdService]', 'Error getting withhold lines for order $saleOrderId', e, st);
      return [];
    }
  }

  /// Guarda las líneas de retención en una orden de venta
  ///
  /// Elimina las líneas existentes y crea las nuevas
  Future<bool> saveWithholdLines(int saleOrderId, List<WithholdLine> lines) async {
    try {
      // Primero eliminar las líneas existentes
      final existingLines = await _odoo.call(
        model: 'sale.order.withhold.line',
        method: 'search_read',
        kwargs: {
          'domain': [['sale_id', '=', saleOrderId]],
          'fields': ['id'],
        },
      );

      if (existingLines is List && existingLines.isNotEmpty) {
        final existingIds = existingLines.map((l) => (l as Map<String, dynamic>)['id'] as int).toList();
        await _odoo.call(
          model: 'sale.order.withhold.line',
          method: 'unlink',
          kwargs: {'ids': existingIds},
        );
      }

      // Crear las nuevas líneas
      if (lines.isNotEmpty) {
        for (final line in lines) {
          final vals = withholdLineManager.toOdoo(line);
          vals['sale_id'] = saleOrderId;

          await _odoo.call(
            model: 'sale.order.withhold.line',
            method: 'create',
            kwargs: {'vals_list': [vals]},
          );
        }
      }

      logger.d('[WithholdService] Saved ${lines.length} withhold lines for order $saleOrderId');
      return true;
    } catch (e, st) {
      logger.e('[WithholdService]', 'Error saving withhold lines for order $saleOrderId', e, st);
      return false;
    }
  }

  /// Calcula el total de retenciones de una orden
  Future<double> getTotalWithholdAmount(int saleOrderId) async {
    try {
      final order = await _odoo.call(
        model: 'sale.order',
        method: 'search_read',
        kwargs: {
          'domain': [['id', '=', saleOrderId]],
          'fields': ['retenido_amount'],
          'limit': 1,
        },
      );

      if (order is List && order.isNotEmpty) {
        return ((order[0] as Map<String, dynamic>)['retenido_amount'] as num?)?.toDouble() ?? 0.0;
      }

      return 0.0;
    } catch (e, st) {
      logger.e('[WithholdService]', 'Error getting total withhold for order $saleOrderId', e, st);
      return 0.0;
    }
  }
}
