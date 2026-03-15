/// UserSyncRepository - Sync de configuración de usuario usando GenericSyncRepository
///
/// Maneja sincronización de:
/// - Users (res.users)
/// - Warehouses (stock.warehouse)
/// - Sales Teams (crm.team)
/// - Fiscal Positions (account.fiscal.position)
/// - Fiscal Position Tax Mappings (account.fiscal.position.tax)
/// - Currencies (res.currency)
/// - Decimal Precision (decimal.precision)
/// - Journals (account.journal)
/// - Card Brands/Deadlines/Lotes (pos.card.*)
/// - Payment Method Lines (account.payment.method.line)
/// - Banks (res.bank)
/// - Partner Banks (res.partner.bank)
/// - Advances (account.advance)
/// - Credit Notes (account.move)
/// - Collection Configs (collection.config)
/// - Company (res.company)
/// - Countries/States (res.country, res.country.state)
/// - Languages (res.lang)
/// - Cash Out Types (l10n_ec.cash.out.type)
/// - Groups (res.groups)
library;

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import 'package:theos_pos_core/theos_pos_core.dart' hide OdooClient, DatabaseHelper;
// ignore: implementation_imports
import 'package:theos_pos_core/src/models/config/currency.model.dart';
import '../../../core/database/database_helper.dart';

/// Repository for syncing user-related configuration data from Odoo.
///
/// Uses GenericSyncRepository to eliminate repetitive pagination/progress code.
class UserSyncRepository {
  final OdooClient? odooClient;
  final DatabaseHelper db;
  final GenericSyncRepository _syncRepo;

  // Managers — global singletons (don't capture DB)
  final UserManager _userManager = userManager;
  final WarehouseManager _warehouseManager = warehouseManager;
  final SalesTeamManager _teamManager = salesTeamManager;
  final FiscalPositionManager _fiscalPositionManager = fiscalPositionManager;
  final CurrencyManager _currencyManager = currencyManager;
  final DecimalPrecisionManager _decimalPrecisionManager = decimalPrecisionManager;
  final BankManager _bankManager = bankManager;
  final PartnerBankManager _partnerBankManager = partnerBankManager;

  // Managers that need the current DB — created on demand via getters
  // to avoid stale references after server switch.
  FiscalPositionTaxManager get _fiscalPositionTaxManager => FiscalPositionTaxManager(_currentDb);
  JournalManager get _journalManager => JournalManager(_currentDb);
  PaymentMethodLineManager get _paymentMethodLineManager => PaymentMethodLineManager(_currentDb);
  AdvanceManager get _advanceManager => advanceManager;
  CreditNoteManager get _creditNoteManager => CreditNoteManager(_currentDb);
  CollectionConfigManager get _collectionConfigManager => collectionConfigManager;
  CountryManager get _countryManager => CountryManager(_currentDb);
  CountryStateManager get _countryStateManager => CountryStateManager(_currentDb);
  LanguageManager get _languageManager => LanguageManager(_currentDb);

  /// Always access the CURRENT database via DatabaseHelper to avoid
  /// stale references after server switch ("connection was closed" bug).
  // ignore: deprecated_member_use_from_same_package
  AppDatabase get _currentDb => DatabaseHelper.db;

  UserSyncRepository({
    required this.db,
    this.odooClient,
  })  : _syncRepo = GenericSyncRepository(odooClient: odooClient);

  bool get isOnline => odooClient != null;

  void cancelSync() => _syncRepo.cancelSync();
  void resetCancelFlag() => _syncRepo.resetCancelFlag();

  // ═══════════════════════════════════════════════════════════════════════════
  // Users Sync (uses UserManager)
  // ═══════════════════════════════════════════════════════════════════════════

  static const _userFields = [
    'id',
    'name',
    'login',
    'active',
    'email',
    'lang',
    'tz',
    'signature',
    'partner_id',
    'company_id',
    'company_ids',
    'notification_type',
    'property_warehouse_id',
    'sale_team_id',
    'avatar_128',
    'write_date',
  ];

  Future<int> syncUsers({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'res.users',
        fields: _userFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: batchSize,
        fromOdoo: _userManager.fromOdoo,
        upsertLocal: _userManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Warehouses Sync (uses WarehouseManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncWarehouses({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _warehouseManager.odooModel,
        fields: _warehouseManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _warehouseManager.fromOdoo,
        upsertLocal: _warehouseManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sales Teams Sync (uses TeamManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncTeams({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _teamManager.odooModel,
        fields: _teamManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        order: 'sequence asc',
        fromOdoo: _teamManager.fromOdoo,
        upsertLocal: _teamManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Fiscal Position Sync (uses FiscalPositionManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncFiscalPositions({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _fiscalPositionManager.odooModel,
        fields: _fiscalPositionManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        order: 'sequence asc',
        fromOdoo: _fiscalPositionManager.fromOdoo,
        upsertLocal: _fiscalPositionManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Fiscal Position Tax Mapping Sync (uses FiscalPositionTaxManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncFiscalPositionTaxMappings({
    int limit = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _fiscalPositionTaxManager.odooModel,
        fields: _fiscalPositionTaxManager.odooFields,
        batchSize: limit,
        order: 'id asc',
        fromOdoo: _fiscalPositionTaxManager.fromOdoo,
        upsertLocal: _fiscalPositionTaxManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  /// Get fiscal position tax mappings for a specific position
  Future<List<AccountFiscalPositionTaxData>> getFiscalPositionTaxMappings(
    int positionId,
  ) async {
    return (_currentDb.select(_currentDb.accountFiscalPositionTax)
          ..where((t) => t.positionId.equals(positionId)))
        .get();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Currency Sync (uses CurrencyManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncCurrencies({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _currencyManager.odooModel,
        fields: _currencyManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        fromOdoo: _currencyManager.fromOdoo,
        upsertLocal: _currencyManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Decimal Precision Sync (uses DecimalPrecisionManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncDecimalPrecision() async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _decimalPrecisionManager.odooModel,
        fields: _decimalPrecisionManager.odooFields,
        batchSize: 100,
        fromOdoo: _decimalPrecisionManager.fromOdoo,
        upsertLocal: _decimalPrecisionManager.upsertLocal,
      ),
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Journal Sync (uses JournalManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncJournals({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _journalManager.odooModel,
        fields: _journalManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _journalManager.fromOdoo,
        upsertLocal: _journalManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Payment Method Line Sync (uses PaymentMethodLineManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncPaymentMethodLines({
    int limit = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _paymentMethodLineManager.odooModel,
        fields: _paymentMethodLineManager.odooFields,
        batchSize: limit,
        fromOdoo: _paymentMethodLineManager.fromOdoo,
        upsertLocal: _paymentMethodLineManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Bank Sync (uses BankManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncBanks({
    int limit = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    // res.bank was removed in Odoo 19.2
    if (odooClient != null && !odooClient!.version.hasBankModel) return 0;

    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _bankManager.odooModel,
        fields: _bankManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _bankManager.fromOdoo,
        upsertLocal: _bankManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Partner Bank Sync (uses PartnerBankManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncPartnerBanks({
    int limit = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _partnerBankManager.odooModel,
        fields: _partnerBankManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        fromOdoo: _partnerBankManager.fromOdoo,
        upsertLocal: _partnerBankManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Advances Sync (uses AdvanceManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncAdvances({
    int limit = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _advanceManager.odooModel,
        fields: _advanceManager.odooFields,
        domain: [
          ['state', '=', 'posted'],
          ['amount_available', '>', 0],
        ],
        batchSize: limit,
        order: 'date desc',
        fromOdoo: _advanceManager.fromOdoo,
        upsertLocal: _advanceManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Credit Notes Sync (uses CreditNoteManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncCreditNotes({
    int limit = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _creditNoteManager.odooModel,
        fields: _creditNoteManager.odooFields,
        domain: _creditNoteManager.creditNoteDomain,
        batchSize: limit,
        order: 'invoice_date desc',
        fromOdoo: _creditNoteManager.fromOdoo,
        upsertLocal: _creditNoteManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Collection Config Sync (uses CollectionConfigManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncCollectionConfigs({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _collectionConfigManager.odooModel,
        fields: _collectionConfigManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _collectionConfigManager.fromOdoo,
        upsertLocal: _collectionConfigManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Company Sync
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncCompany({
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (!isOnline) return 0;

    try {
      // Get current user's company from local database
      final currentUser = await (_currentDb.select(_currentDb.resUsers)
            ..where((t) => t.isCurrentUser.equals(true)))
          .getSingleOrNull();

      if (currentUser == null || currentUser.companyId == null) return 0;
      final companyId = currentUser.companyId!;

      // Fetch company with extended fields
      final companyData = await odooClient!.read(
        model: 'res.company',
        ids: [companyId],
        fields: Company.odooFields,
      );

      if (companyData.isEmpty) return 0;

      final company = companyManager.fromOdoo(companyData.first);
      await companyManager.upsertLocal(company);

      onProgress?.call(SyncProgress(
        total: 1,
        synced: 1,
        currentItem: company.name,
      ));

      return 1;
    } catch (e) {
      logger.e('[UserSync] Error syncing company: $e');
      onProgress?.call(SyncProgress(total: 0, synced: 0, error: e.toString()));
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Countries Sync (uses CountryManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncCountries({
    int limit = 300,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _countryManager.odooModel,
        fields: _countryManager.odooFields,
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _countryManager.fromOdoo,
        upsertLocal: _countryManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Country States Sync (uses CountryStateManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncCountryStates({
    int limit = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _countryStateManager.odooModel,
        fields: _countryStateManager.odooFields,
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _countryStateManager.fromOdoo,
        upsertLocal: _countryStateManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Languages Sync (uses LanguageManager)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncLanguages({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: _languageManager.odooModel,
        fields: _languageManager.odooFields,
        domain: [
          ['active', '=', true]
        ],
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _languageManager.fromOdoo,
        upsertLocal: _languageManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Groups Sync
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> syncGroups({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (!isOnline) return 0;

    // Groups sync requires special handling for XML IDs
    int syncedCount = 0;
    int totalRecords = 0;

    try {
      final domain = sinceDate != null
          ? [
              ['write_date', '>', odoo.formatOdooDateTime(sinceDate)]
            ]
          : <List<dynamic>>[];

      totalRecords = await odooClient!
              .searchCount(model: 'res.groups', domain: domain) ??
          0;

      onProgress?.call(SyncProgress(
        total: totalRecords,
        synced: 0,
        currentItem: 'Iniciando...',
      ));

      if (totalRecords == 0) return 0;

      int offset = 0;
      bool hasMore = true;

      while (hasMore) {
        if (_syncRepo.isCancelRequested) {
          return syncedCount;
        }

        final groups = await odooClient!.searchRead(
          model: 'res.groups',
          domain: domain,
          fields: ['id', 'name', 'full_name', 'share', 'implied_ids', 'write_date'],
          limit: batchSize,
          offset: offset,
          order: 'id asc',
        );

        if (groups.isEmpty) {
          hasMore = false;
          break;
        }

        // Fetch external IDs for this batch
        final groupIds = groups.map((g) => g['id'] as int).toList();
        final xmlIds = await _fetchGroupXmlIds(groupIds);

        for (final g in groups) {
          final odooId = g['id'] as int;
          final impliedIds = g['implied_ids'] is List
              ? (g['implied_ids'] as List).map((e) => e.toString()).join(',')
              : null;

          final companion = ResGroupsCompanion(
            odooId: Value(odooId),
            name: Value(g['name'] as String? ?? ''),
            fullName: Value(g['full_name'] as String?),
            xmlId: Value(xmlIds[odooId]),
            impliedIds: Value(impliedIds),
            share: Value(g['share'] as bool? ?? false),
            writeDate: Value(odoo.parseOdooDateTime(g['write_date'])),
          );

          await _upsert(_currentDb.resGroups, odooId, companion);
          syncedCount++;

          if (syncedCount % 20 == 0) {
            onProgress?.call(SyncProgress(
              total: totalRecords,
              synced: syncedCount,
              currentItem: g['full_name'] as String? ?? g['name'] as String? ?? '',
            ));
          }
        }

        if (groups.length < batchSize) {
          hasMore = false;
        } else {
          offset += batchSize;
        }
      }

      onProgress?.call(SyncProgress(total: totalRecords, synced: syncedCount));
      return syncedCount;
    } catch (e) {
      logger.e('[UserSync] Error syncing groups: $e');
      onProgress?.call(SyncProgress(
        total: totalRecords,
        synced: syncedCount,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Fetch XML IDs for groups using get_external_id method
  Future<Map<int, String>> _fetchGroupXmlIds(List<int> groupIds) async {
    if (groupIds.isEmpty) return {};

    try {
      // get_external_id() operates on the recordset (self) — no args needed.
      // Pass IDs via `ids:` so JSON-2 builds the recordset correctly.
      final result = await odooClient!.call(
        model: 'res.groups',
        method: 'get_external_id',
        ids: groupIds,
      );

      final xmlIds = <int, String>{};
      if (result is Map) {
        for (final entry in result.entries) {
          final groupId = int.tryParse(entry.key.toString());
          final xmlId = entry.value as String?;
          if (groupId != null && xmlId != null && xmlId.isNotEmpty) {
            xmlIds[groupId] = xmlId;
          }
        }
      }

      // Fallback if needed
      if (xmlIds.isEmpty) {
        return _fetchGroupXmlIdsFromIrModelData(groupIds);
      }

      return xmlIds;
    } catch (e) {
      logger.w('[UserSync] Error fetching group XML IDs: $e');
      return _fetchGroupXmlIdsFromIrModelData(groupIds);
    }
  }

  /// Fallback method using ir.model.data
  Future<Map<int, String>> _fetchGroupXmlIdsFromIrModelData(
    List<int> groupIds,
  ) async {
    try {
      final result = await odooClient!.searchRead(
        model: 'ir.model.data',
        domain: [
          ['model', '=', 'res.groups'],
          ['res_id', 'in', groupIds],
        ],
        fields: ['res_id', 'module', 'name'],
        limit: groupIds.length * 2,
      );

      final xmlIds = <int, String>{};
      for (final r in result) {
        final resId = r['res_id'] as int;
        final module = r['module'] as String? ?? '';
        final name = r['name'] as String? ?? '';
        if (module.isNotEmpty && name.isNotEmpty && !xmlIds.containsKey(resId)) {
          xmlIds[resId] = '$module.$name';
        }
      }
      return xmlIds;
    } catch (e) {
      logger.w('[UserSync] Error fetching group XML IDs from ir.model.data: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generic upsert helper for Drift tables
  Future<void> _upsert<T extends Table, D>(
    TableInfo<T, D> table,
    int odooId,
    Insertable<D> companion,
  ) async {
    // First try to find existing record
    final existing = await (_currentDb.select(table)
          ..where((t) => (t as dynamic).odooId.equals(odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_currentDb.update(table)
            ..where((t) => (t as dynamic).odooId.equals(odooId)))
          .write(companion);
    } else {
      await _currentDb.into(table).insert(companion);
    }
  }

}
