import 'package:drift/drift.dart';
// Hide BaseRepository from core - we use the specialized one from theos_pos
import 'package:odoo_sdk/odoo_sdk.dart' hide BaseRepository;
import '../../../core/database/database_helper.dart' show DatabaseHelper;
import '../../../core/database/repositories/base_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase, ResPartnerCompanion, Company, Client, clientManager, ClientManagerBusiness, companyManager, userManager, UserManagerBusiness, paymentTermManager, pricelistManager;

/// Repository for Client/Partner operations with offline-first pattern
///
/// Like Odoo's res.partner model, this repository handles:
/// - Reading clients from local database first (offline-first)
/// - Syncing with Odoo when online for fresh credit data
/// - Creating clients offline with queue for later sync
/// - Updating client fields (phone, email for invoicing)
///
/// **Offline-First Pattern:**
/// 1. Always try local database first
/// 2. If online and data is stale, refresh from Odoo
/// 3. Cache results locally for future use
/// 4. Queue offline creates/updates for later sync
///
/// Usage:
/// ```dart
/// final repository = ref.read(clientRepositoryProvider);
///
/// // Get client by ID (offline-first)
/// final client = await repository?.getById(123);
///
/// // Search clients
/// final clients = await repository?.search('john', limit: 20);
///
/// // Refresh credit data from Odoo
/// final refreshed = await repository?.refreshCreditData(123);
/// ```
class ClientRepository extends BaseRepository with OfflineSupport<DatabaseHelper> {
  /// Cache for company data
  Company? _cachedCompany;

  /// Database instance (typed for Drift operations)
  final AppDatabase _db;

  ClientRepository({
    required super.odooClient,
    required super.db,
    required AppDatabase appDb,
  }) : _db = appDb;

  // ============ READ OPERATIONS (Offline-First) ============

  /// Get client by ID
  ///
  /// Offline-first: Returns cached data, optionally refreshes from Odoo.
  Future<Client?> getById(int clientId) async {
    try {
      // 1. Get from local database
      final localClient = await _getFromLocal(clientId);

      // 2. Data is returned from cache; caller can use refreshCreditData() for fresh data

      return localClient;
    } catch (e) {
      logger.e('[ClientRepository]', 'Error getting client $clientId: $e');
      return null;
    }
  }

  /// Search clients by query (name, VAT, email)
  ///
  /// Offline-first: Returns local results, enriched with Odoo data if online.
  Future<List<Client>> search(String? query, {int limit = 20}) async {
    try {
      // 1. Get local results
      final localResults = await _searchLocal(query, limit: limit);

      // 2. If online and have query, fetch from Odoo for fresh data
      if (query != null && query.length >= 2) {
        try {
          final odooResults = await _searchOdoo(query, limit: limit);
          // Merge results, preferring Odoo data for existing clients
          return _mergeResults(localResults, odooResults);
        } catch (e) {
          logger.w('[ClientRepository]', 'Online search failed: $e');
          // Fall through to return local results
        }
      }

      return localResults;
    } catch (e) {
      logger.e('[ClientRepository]', 'Error searching clients: $e');
      return [];
    }
  }

  /// Refresh credit data from Odoo
  ///
  /// Forces a fetch from Odoo to get the latest credit information.
  /// Returns the updated client, or throws if offline or client not found.
  Future<Client> refreshCreditData(int clientId) async {
    if (!isOnline) {
      throw OfflineException();
    }

    final response = await odooClient!.searchRead(
      model: 'res.partner',
      domain: [
        ['id', '=', clientId]
      ],
      fields: _creditFields,
      limit: 1,
    );

    if (response.isEmpty) {
      throw ClientNotFoundException(clientId);
    }

    // Parse and save to local DB
    final client = clientManager.fromOdoo(response.first);
    await _saveToLocal(client);

    logger.d('[ClientRepository]', 'Refreshed credit data for client $clientId');
    return client;
  }

  // ============ WRITE OPERATIONS ============

  /// Update a client field in Odoo
  ///
  /// Used for updating phone/email for electronic invoicing (Ecuador).
  /// Uses updateWithOfflineFallback for offline support.
  Future<bool> updateField({
    required int clientId,
    required String field,
    required dynamic value,
  }) async {
    return updateWithOfflineFallback(
      model: 'res.partner',
      recordId: clientId,
      values: {field: value},
      updateLocally: (id, values) async {
        await _updateLocalField(id, field, value);
      },
    );
  }

  /// Legacy direct update (throws if offline)
  Future<bool> updateFieldDirect({
    required int clientId,
    required String field,
    required dynamic value,
  }) async {
    if (!isOnline) {
      throw OfflineException();
    }

    final success = await odooClient!.write(
      model: 'res.partner',
      ids: [clientId],
      values: {field: value},
    );

    if (success) {
      // Update local database
      await _updateLocalField(clientId, field, value);
    }

    return success;
  }

  // ============ HELPER OPERATIONS ============

  /// Get company configuration
  Future<Company?> getCompany() async {
    if (_cachedCompany != null) return _cachedCompany;
    // Get current user's company via datasources
    final currentUser = await userManager.getCurrentUser();
    if (currentUser?.companyId == null) return null;
    _cachedCompany = await companyManager.readLocal(currentUser!.companyId!);
    return _cachedCompany;
  }

  /// Clear cached data
  void clearCache() {
    _cachedCompany = null;
  }

  // ============ INTERNAL: LOCAL DATABASE OPERATIONS ============

  Future<Client?> _getFromLocal(int clientId) async {
    return clientManager.getPartner(clientId);
  }

  Future<List<Client>> _searchLocal(String? query, {int limit = 20}) async {
    return clientManager.searchPartners(query: query, limit: limit);
  }

  Future<void> _saveToLocal(Client client) async {
    await clientManager.upsertLocal(client);
  }

  Future<void> _updateLocalField(int clientId, String field, dynamic value) async {
    // Map field name to database column
    final db = _db;
    final update = <String, dynamic>{};

    switch (field) {
      case 'phone':
        update['phone'] = value;
        break;
      case 'mobile':
        update['mobile'] = value;
        break;
      case 'email':
        update['email'] = value;
        break;
      case 'street':
        update['street'] = value;
        break;
      // Add more fields as needed
    }

    if (update.isNotEmpty) {
      await (db.update(db.resPartner)..where((t) => t.odooId.equals(clientId)))
          .write(ResPartnerCompanion(
        phone: field == 'phone' ? Value(value as String?) : const Value.absent(),
        mobile: field == 'mobile' ? Value(value as String?) : const Value.absent(),
        email: field == 'email' ? Value(value as String?) : const Value.absent(),
        street: field == 'street' ? Value(value as String?) : const Value.absent(),
      ));
    }
  }

  // ============ INTERNAL: ODOO OPERATIONS ============

  Future<List<Client>> _searchOdoo(String query, {int limit = 20}) async {
    if (!isOnline) return [];

    final response = await odooClient!.searchRead(
      model: 'res.partner',
      fields: _allFields,
      domain: [
        '|',
        '|',
        ['name', 'ilike', query],
        ['vat', 'ilike', query],
        ['email', 'ilike', query],
      ],
      limit: limit,
    );

    final clients = <Client>[];
    for (final data in response) {
      final client = clientManager.fromOdoo(data);
      // Save to local DB for caching
      await _saveToLocal(client);
      clients.add(client);
    }

    return clients;
  }

  /// Merge local and Odoo results, preferring Odoo data
  List<Client> _mergeResults(List<Client> local, List<Client> odoo) {
    final merged = <int, Client>{};

    // Add local results first
    for (final client in local) {
      merged[client.id] = client;
    }

    // Override with Odoo results (fresher data)
    for (final client in odoo) {
      merged[client.id] = client;
    }

    return merged.values.toList();
  }

  // ============ LOCAL → MAP CONVERSION ============

  /// Convert a Client to a Map matching the Odoo searchRead response format.
  ///
  /// Many2One fields are returned as [id, name] or false, matching Odoo convention.
  Map<String, dynamic> _clientToSearchMap(Client c) => <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'vat': c.vat ?? false,
        'street': c.street ?? false,
        'phone': c.phone ?? false,
        'email': c.email ?? false,
        'property_payment_term_id': c.propertyPaymentTermId != null
            ? [c.propertyPaymentTermId, c.propertyPaymentTermName ?? '']
            : false,
        'property_product_pricelist': c.propertyProductPricelistId != null
            ? [c.propertyProductPricelistId, c.propertyProductPricelistName ?? '']
            : false,
      };

  // ============ FIELD DEFINITIONS ============

  static const _creditFields = [
    'id',
    'name',
    'credit_limit',
    'credit',
    'credit_to_invoice',
    'allow_over_credit',
    'use_partner_credit_limit',
    'total_overdue',
    'unpaid_invoices_count',
    // 'oldest_overdue_days', // Custom field - may not exist
  ];

  static const _allFields = [
    'id',
    'name',
    'display_name',
    'ref',
    'vat',
    'email',
    'phone',
    'street',
    'street2',
    'city',
    'zip',
    'country_id',
    'state_id',
    'avatar_128',
    'is_company',
    'active',
    'parent_id',
    'commercial_partner_id',
    'property_product_pricelist',
    'property_payment_term_id',
    'lang',
    'comment',
    'write_date',
    // Credit fields
    'credit_limit',
    'credit',
    'credit_to_invoice',
    'allow_over_credit',
    'use_partner_credit_limit',
    'total_overdue',
    'unpaid_invoices_count',
    // Ecuador fields
    'dias_max_factura_posterior',
    'tipo_cliente',
    'canal_cliente',
    // Ranking
    'customer_rank',
    'supplier_rank',
    // Check Acceptance
    'acepta_cheques',
    // Invoice Configuration
    'emitir_factura_fecha_posterior',
    'no_invoice',
    'last_day_to_invoice',
    // External ID
    'external_id',
    // Geolocation
    'partner_latitude',
    'partner_longitude',
    // Custom Payments
    'can_use_custom_payments',
  ];

  /// Update a single field of a partner
  Future<bool> updatePartnerField({
    required int partnerId,
    required String field,
    required dynamic value,
  }) async {
    try {
      if (odooClient == null) return false;
      await odooClient!.write(model: 'res.partner', ids: [partnerId], values: {field: value});

      // Update local database if needed
      // This is a simplified version - you may want to refresh the partner from Odoo
      return true;
    } catch (e) {
      logger.e('[ClientRepository]', 'Error updating partner field $field', e);
      return false;
    }
  }

  /// Search partners - offline-first
  ///
  /// Tries local database first, then fetches from Odoo if online.
  Future<List<Map<String, dynamic>>> searchPartners({
    int? partnerId,
    String? query,
    int limit = 20,
  }) async {
    try {
      // Try local first
      final localClients = partnerId != null
          ? [await clientManager.getPartner(partnerId)].whereType<Client>().toList()
          : await clientManager.searchPartners(query: query, limit: limit);

      if (localClients.isNotEmpty) {
        // Convert Client objects to Map format matching Odoo Many2One response
        final localMaps = localClients.map((c) => _clientToSearchMap(c)).toList();

        // If offline, return local results
        if (odooClient == null) return localMaps;
      }

      // Try server if available
      if (odooClient == null) return [];

      final domain = <dynamic>[];
      if (partnerId != null) {
        domain.add(['id', '=', partnerId]);
      }
      if (query != null && query.isNotEmpty) {
        domain.add(['name', 'ilike', query]);
      }

      final result = await odooClient!.searchRead(
        model: 'res.partner',
        domain: domain,
        fields: [
          'id', 'name', 'vat', 'street', 'phone', 'email',
          'property_payment_term_id', 'property_product_pricelist',
        ],
        limit: limit,
      );

      return result.cast<Map<String, dynamic>>();
    } catch (e) {
      logger.e('[ClientRepository]', 'Error searching partners', e);
      // On server error, fall back to local
      try {
        final localClients = partnerId != null
            ? [await clientManager.getPartner(partnerId)].whereType<Client>().toList()
            : await clientManager.searchPartners(query: query, limit: limit);
        return localClients.map((c) => _clientToSearchMap(c)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Get payment terms - offline-first
  ///
  /// Tries local database first, then fetches from Odoo if online.
  Future<List<dynamic>> getPaymentTerms() async {
    try {
      // Try local first
      final localTerms = await paymentTermManager.searchLocal(domain: [
        ['active', '=', true],
      ]);
      if (localTerms.isNotEmpty) {
        final localMaps = localTerms.map((t) => <String, dynamic>{
          'id': t.id,
          'name': t.name,
        }).toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

        // If offline, return local results
        if (odooClient == null) return localMaps;
      }

      // Try server if available
      if (odooClient == null) return [];
      final result = await odooClient!.searchRead(
        model: 'account.payment.term',
        domain: [['active', '=', true]],
        fields: ['id', 'name'],
        order: 'name',
      );
      return result;
    } catch (e) {
      logger.e('[ClientRepository]', 'Error getting payment terms', e);
      // On server error, fall back to local
      try {
        final localTerms = await paymentTermManager.searchLocal(domain: [
          ['active', '=', true],
        ]);
        return localTerms.map((t) => <String, dynamic>{
          'id': t.id,
          'name': t.name,
        }).toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      } catch (_) {
        return [];
      }
    }
  }

  /// Get pricelists - offline-first
  ///
  /// Tries local database first, then fetches from Odoo if online.
  Future<List<dynamic>> getPricelists() async {
    try {
      // Try local first
      final localPricelists = await pricelistManager.searchLocal(domain: [
        ['active', '=', true],
      ]);
      if (localPricelists.isNotEmpty) {
        final localMaps = localPricelists.map((p) => <String, dynamic>{
          'id': p.id,
          'name': p.name,
        }).toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

        // If offline, return local results
        if (odooClient == null) return localMaps;
      }

      // Try server if available
      if (odooClient == null) return [];
      final result = await odooClient!.searchRead(
        model: 'product.pricelist',
        domain: [['active', '=', true]],
        fields: ['id', 'name'],
        order: 'name',
      );
      return result;
    } catch (e) {
      logger.e('[ClientRepository]', 'Error getting pricelists', e);
      // On server error, fall back to local
      try {
        final localPricelists = await pricelistManager.searchLocal(domain: [
          ['active', '=', true],
        ]);
        return localPricelists.map((p) => <String, dynamic>{
          'id': p.id,
          'name': p.name,
        }).toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      } catch (_) {
        return [];
      }
    }
  }

  /// Get salespeople - offline-first
  ///
  /// Tries local database first (internal users), then fetches from Odoo if online.
  Future<List<dynamic>> getSalespeople() async {
    try {
      // Try local first - get all locally cached users (internal users are synced)
      final localUsers = await userManager.getAllUsers();
      if (localUsers.isNotEmpty) {
        final localMaps = localUsers.map((u) => <String, dynamic>{
          'id': u.id,
          'name': u.name,
        }).toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

        // If offline, return local results
        if (odooClient == null) return localMaps;
      }

      // Try server if available
      if (odooClient == null) return [];
      final result = await odooClient!.searchRead(
        model: 'res.users',
        domain: [
          ['active', '=', true],
          ['share', '=', false],
        ],
        fields: ['id', 'name'],
        order: 'name',
      );
      return result;
    } catch (e) {
      logger.e('[ClientRepository]', 'Error getting salespeople', e);
      // On server error, fall back to local
      try {
        final localUsers = await userManager.getAllUsers();
        return localUsers.map((u) => <String, dynamic>{
          'id': u.id,
          'name': u.name,
        }).toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      } catch (_) {
        return [];
      }
    }
  }
}

// ============ EXCEPTIONS ============

/// Exception thrown when offline and operation requires connection
class OfflineException implements Exception {
  @override
  String toString() => 'OfflineException: No hay conexión con Odoo';
}

/// Exception thrown when a client is not found
class ClientNotFoundException implements Exception {
  final int clientId;

  ClientNotFoundException(this.clientId);

  @override
  String toString() => 'ClientNotFoundException: Client $clientId not found';
}
