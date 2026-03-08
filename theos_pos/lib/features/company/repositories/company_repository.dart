import 'package:odoo_sdk/odoo_sdk.dart'
    hide BaseRepository, SessionInfoCache, OfflineSupport;
import 'package:theos_pos_core/theos_pos_core.dart' show companyManager, userManager, UserManagerBusiness, Company;
import '../../../core/database/repositories/base_repository.dart';

/// Repository for company configuration data
///
/// Handles fetching and caching of company settings including:
/// - Sales configuration (quotation validity, prepayment, etc.)
/// - Company info (name, address, VAT, etc.)
///
/// Supports offline-first pattern with smart cache invalidation
/// based on write_date comparison.
class CompanyRepository extends BaseRepository
    with SessionInfoCache, OfflineSupport {

  CompanyRepository({
    required super.odooClient,
    required super.db,
  });

  /// Get company by ID with cache-first strategy
  ///
  /// Checks local cache first, then validates against server write_date.
  /// Returns cached data if server is unreachable.
  Future<Company?> getCompany(int companyId) async {
    final cached = await companyManager.readLocal(companyId);

    // If offline, return cached data
    if (!isOnline) return cached;

    try {
      final serverData = await odooClient!.searchRead(
        model: 'res.company',
        fields: ['write_date'],
        domain: [
          ['id', '=', companyId],
        ],
        limit: 1,
      );

      if (serverData.isNotEmpty) {
        final serverWriteDate = parseOdooDateTime(
          serverData.first['write_date'],
        );

        if (serverWriteDate != null &&
            (cached?.writeDate == null ||
                serverWriteDate.isAfter(cached!.writeDate!))) {
          return await _fetchAndCacheCompany(companyId);
        }
      }
    } catch (e) {
      // Error checking company, using cache
    }

    return cached;
  }

  /// Get company for current user
  ///
  /// Fetches company from session_info or from cached user.
  /// Auto-refreshes from Odoo if SRI limit is missing (0) and we're online.
  Future<Company?> getCurrentUserCompany() async {
    try {
      // Try to get from session_info first (most up to date)
      final sessionInfo = await getSessionInfoCached();
      if (sessionInfo != null && sessionInfo['company_id'] != null) {
        int companyId;
        if (sessionInfo['company_id'] is int) {
          companyId = sessionInfo['company_id'] as int;
        } else if (sessionInfo['company_id'] is List) {
          companyId = (sessionInfo['company_id'] as List).first as int;
        } else {
          final currentUser = await userManager.getCurrentUser();
          if (currentUser?.companyId == null) return null;
          return await companyManager.readLocal(currentUser!.companyId!);
        }

        // 1. First read from local DB
        var company = await getCompany(companyId);

        // 2. Auto-refresh if SRI limit is 0/null and we're online
        // This handles cases where the limit wasn't synced yet
        if (company != null &&
            (company.saleCustomerInvoiceLimitSri == null ||
                company.saleCustomerInvoiceLimitSri == 0)) {
          try {
            // Fetch from Odoo and save to local DB
            await _fetchAndCacheCompany(companyId);
            // Re-read from local DB (proper offline-first pattern)
            company = await getCompany(companyId);
          } catch (e) {
            // Failed to refresh, continue with cached company
          }
        }

        return company;
      }
    } catch (e) {
      // Error getting company from session, trying cache
    }

    // Fallback to cached user's company
    final currentUser = await userManager.getCurrentUser();
    if (currentUser?.companyId == null) return null;
    return await companyManager.readLocal(currentUser!.companyId!);
  }

  /// Force refresh company data from server
  Future<Company?> refreshCompany(int companyId) async {
    try {
      return await _fetchAndCacheCompany(companyId);
    } catch (e) {
      return await companyManager.readLocal(companyId);
    }
  }

  /// Fetch full company record from Odoo and cache locally
  /// Also fetches sale.order default_get to get default partner/warehouse
  /// Uses separated field groups to handle optional module fields gracefully
  /// Returns null if offline
  Future<Company?> _fetchAndCacheCompany(int companyId) async {
    if (!isOnline) return null;

    // First fetch core fields (always exist in Odoo)
    final coreResponse = await odooClient!.read(
      model: 'res.company',
      ids: [companyId],
      fields: Company.odooFieldsCore,
    );

    if (coreResponse.isEmpty) {
      return null;
    }

    final companyData = Map<String, dynamic>.from(coreResponse.first);

    // Try to fetch sale module fields (may not exist)
    try {
      final saleResponse = await odooClient!.read(
        model: 'res.company',
        ids: [companyId],
        fields: Company.odooFieldsSale,
      );
      if (saleResponse.isNotEmpty) {
        companyData.addAll(Map<String, dynamic>.from(saleResponse.first));
      }
    } catch (e) {
      // Sale module fields not available
    }

    // Try to fetch Ecuador SRI fields (may not exist)
    try {
      final ecuadorSriResponse = await odooClient!.read(
        model: 'res.company',
        ids: [companyId],
        fields: Company.odooFieldsEcuadorSri,
      );
      if (ecuadorSriResponse.isNotEmpty) {
        companyData.addAll(Map<String, dynamic>.from(ecuadorSriResponse.first));
      }
    } catch (e) {
      // Ecuador SRI fields not available
    }

    // Try to fetch Ecuador report fields (may not exist)
    try {
      final ecuadorReportResponse = await odooClient!.read(
        model: 'res.company',
        ids: [companyId],
        fields: Company.odooFieldsEcuadorReport,
      );
      if (ecuadorReportResponse.isNotEmpty) {
        companyData.addAll(
          Map<String, dynamic>.from(ecuadorReportResponse.first),
        );
      }
    } catch (e) {
      // Ecuador report fields not available
    }

    // Try to fetch Pedir module fields (may not exist)
    try {
      final pedirResponse = await odooClient!.read(
        model: 'res.company',
        ids: [companyId],
        fields: Company.odooFieldsPedir,
      );
      if (pedirResponse.isNotEmpty) {
        companyData.addAll(Map<String, dynamic>.from(pedirResponse.first));
      }
    } catch (e) {
      // Pedir module fields not available
    }

    // Try to fetch sale_customer_invoice_limit_sri from ir.config_parameter
    // This is a config_parameter, NOT a field on res.company
    try {
      final sriLimitResponse = await odooClient!.call(
        model: 'ir.config_parameter',
        method: 'get_float',
        kwargs: {'key': 'sale.sale_customer_invoice_limit_sri', 'default': 50.0},
      );
      if (sriLimitResponse != null && sriLimitResponse != false) {
        companyData['sale_customer_invoice_limit_sri'] =
            (sriLimitResponse is int) ? sriLimitResponse.toDouble() : (sriLimitResponse as num).toDouble();
      } else {
        companyData['sale_customer_invoice_limit_sri'] = 50.0;
      }
    } catch (e) {
      companyData['sale_customer_invoice_limit_sri'] = 50.0;
    }

    // Parse company data
    var company = companyManager.fromOdoo(companyData);

    // Fetch sale.order defaults (partner_id, warehouse_id)
    // These come from default_get, not from res.company
    try {
      final saleDefaults = await odooClient!.call(
        model: 'sale.order',
        method: 'default_get',
        kwargs: {
          'fields_list': [
            'partner_id',
            'warehouse_id',
            'pricelist_id',
            'payment_term_id',
          ],
        },
      );

      if (saleDefaults is Map<String, dynamic>) {
        // Extract partner_id
        int? defaultPartnerId;
        String? defaultPartnerName;
        if (saleDefaults['partner_id'] is List &&
            (saleDefaults['partner_id'] as List).isNotEmpty) {
          defaultPartnerId = (saleDefaults['partner_id'] as List)[0] as int?;
          defaultPartnerName = (saleDefaults['partner_id'] as List).length > 1
              ? (saleDefaults['partner_id'] as List)[1] as String?
              : null;
        } else if (saleDefaults['partner_id'] is int) {
          defaultPartnerId = saleDefaults['partner_id'] as int;
        }

        // Extract warehouse_id
        int? defaultWarehouseId;
        String? defaultWarehouseName;
        if (saleDefaults['warehouse_id'] is List &&
            (saleDefaults['warehouse_id'] as List).isNotEmpty) {
          defaultWarehouseId =
              (saleDefaults['warehouse_id'] as List)[0] as int?;
          defaultWarehouseName =
              (saleDefaults['warehouse_id'] as List).length > 1
              ? (saleDefaults['warehouse_id'] as List)[1] as String?
              : null;
        } else if (saleDefaults['warehouse_id'] is int) {
          defaultWarehouseId = saleDefaults['warehouse_id'] as int;
        }

        // Extract pricelist_id
        int? defaultPricelistId;
        String? defaultPricelistName;
        if (saleDefaults['pricelist_id'] is List &&
            (saleDefaults['pricelist_id'] as List).isNotEmpty) {
          defaultPricelistId =
              (saleDefaults['pricelist_id'] as List)[0] as int?;
          defaultPricelistName =
              (saleDefaults['pricelist_id'] as List).length > 1
              ? (saleDefaults['pricelist_id'] as List)[1] as String?
              : null;
        } else if (saleDefaults['pricelist_id'] is int) {
          defaultPricelistId = saleDefaults['pricelist_id'] as int;
        }

        // Extract payment_term_id
        int? defaultPaymentTermId;
        String? defaultPaymentTermName;
        if (saleDefaults['payment_term_id'] is List &&
            (saleDefaults['payment_term_id'] as List).isNotEmpty) {
          defaultPaymentTermId =
              (saleDefaults['payment_term_id'] as List)[0] as int?;
          defaultPaymentTermName =
              (saleDefaults['payment_term_id'] as List).length > 1
              ? (saleDefaults['payment_term_id'] as List)[1] as String?
              : null;
        } else if (saleDefaults['payment_term_id'] is int) {
          defaultPaymentTermId = saleDefaults['payment_term_id'] as int;
        }

        // Update company with defaults
        company = company.copyWith(
          defaultPartnerId: defaultPartnerId,
          defaultPartnerName: defaultPartnerName,
          defaultWarehouseId: defaultWarehouseId,
          defaultWarehouseName: defaultWarehouseName,
          defaultPricelistId: defaultPricelistId ?? company.defaultPricelistId,
          defaultPricelistName:
              defaultPricelistName ?? company.defaultPricelistName,
          defaultPaymentTermId:
              defaultPaymentTermId ?? company.defaultPaymentTermId,
          defaultPaymentTermName:
              defaultPaymentTermName ?? company.defaultPaymentTermName,
        );
      }
    } catch (e) {
      // Continue with company data without sale defaults
    }

    await companyManager.upsertLocal(company);
    return company;
  }

  /// Sync company config on login/app startup
  ///
  /// Call this after successful authentication to ensure
  /// company config is available for offline use.
  /// Does nothing if offline.
  Future<void> syncCurrentUserCompany() async {
    if (!isOnline) return;

    try {
      final sessionInfo = await odooClient!.call(
        model: 'ir.http',
        method: 'session_info',
        kwargs: {},
      );

      if (sessionInfo is Map<String, dynamic>) {
        int? companyId;
        if (sessionInfo['company_id'] is int) {
          companyId = sessionInfo['company_id'] as int;
        } else if (sessionInfo['company_id'] is List &&
            (sessionInfo['company_id'] as List).isNotEmpty) {
          companyId = (sessionInfo['company_id'] as List).first as int;
        }

        if (companyId != null) {
          await _fetchAndCacheCompany(companyId);
        }
      }
    } catch (e) {
      // Non-fatal - we can work with cached data
    }
  }

  /// Get all cached companies (for multi-company scenarios)
  Future<List<Company>> getAllCachedCompanies() async {
    return await companyManager.searchLocal();
  }
}
