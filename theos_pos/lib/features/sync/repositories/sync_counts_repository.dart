/// SyncCountsRepository - Conteos locales y detección de eliminaciones remotas
///
/// Extraído de CatalogSyncRepository (Fase E2): conteo de registros locales
/// por modelo, y sync de registros eliminados en Odoo (tombstones vía
/// sync.deleted.record).
library;

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import 'qweb_template_sync_repository.dart';
import 'sync_scope_domains.dart';

/// Repository for local record counts and deleted-record synchronization.
class SyncCountsRepository {
  final AppDatabase _appDb;
  final OdooClient? odooClient;
  final QwebTemplateSyncRepository _qwebTemplateSync;
  final DateTime Function() _now;

  SyncCountsRepository({
    required this._appDb,
    required this.odooClient,
    required this._qwebTemplateSync,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  bool get isOnline => odooClient != null;

  Future<int> _countRows<T extends drift.HasResultSet, R>(
    drift.ResultSetImplementation<T, R> table,
  ) async {
    final count = drift.countAll();
    final row = await (_appDb.selectOnly(
      table,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> getLocalProductCount() => _countRows(_appDb.productProduct);

  Future<int> getLocalCategoryCount() => _countRows(_appDb.productCategory);

  Future<int> getLocalTaxCount() => _countRows(_appDb.accountTax);

  Future<int> getLocalUomCount() => _countRows(_appDb.uomUom);

  Future<int> getLocalProductUomCount() => _countRows(_appDb.productUom);

  Future<int> getLocalPricelistCount() => _countRows(_appDb.productPricelist);

  Future<int> getLocalPaymentTermCount() =>
      _countRows(_appDb.accountPaymentTerm);

  Future<int> getLocalPartnerCount() => _countRows(_appDb.resPartner);

  Future<int> getLocalSaleOrderCount() => _countRows(_appDb.saleOrder);

  Future<int> getLocalCountForModel(String modelName) async {
    switch (modelName) {
      case 'product.product':
        return getLocalProductCount();
      case 'product.category':
        return getLocalCategoryCount();
      case 'account.tax':
        return getLocalTaxCount();
      case 'uom.uom':
        return getLocalUomCount();
      case 'product.uom':
        return getLocalProductUomCount();
      case 'product.pricelist':
        return getLocalPricelistCount();
      case 'account.payment.term':
        return getLocalPaymentTermCount();
      case 'res.partner':
        return getLocalPartnerCount();
      case 'sale.order':
        return getLocalSaleOrderCount();
      case 'res.users':
        return _countRows(_appDb.resUsers);
      case 'stock.warehouse':
        return _countRows(_appDb.stockWarehouse);
      case 'crm.team':
        return _countRows(_appDb.crmTeam);
      case 'account.fiscal.position':
        return _countRows(_appDb.accountFiscalPosition);
      case 'account.fiscal.position.tax':
        return _countRows(_appDb.accountFiscalPositionTax);
      case 'res.currency':
        return _countRows(_appDb.resCurrency);
      case 'decimal.precision':
        return _countRows(_appDb.decimalPrecision);
      case 'account.journal':
        return _countRows(_appDb.accountJournal);
      case 'account.payment.method.line':
        return _countRows(_appDb.accountPaymentMethodLine);
      case 'account.advance':
        return _countRows(_appDb.accountAdvance);
      case 'account.move':
        return _countRows(_appDb.accountMove);
      case 'collection.config':
        return _countRows(_appDb.collectionConfig);
      case 'res.company':
        return _countRows(_appDb.resCompanyTable);
      case 'res.country':
        return _countRows(_appDb.resCountry);
      case 'res.country.state':
        return _countRows(_appDb.resCountryState);
      case 'res.lang':
        return _countRows(_appDb.resLang);
      case 'res.groups':
        return _countRows(_appDb.resGroups);
      case 'ir.ui.view':
        return _qwebTemplateSync.getLocalTemplateCount();
      case 'account.credit.card.brand':
        return _countRows(_appDb.accountCreditCardBrand);
      case 'account.credit.card.deadline':
        return _countRows(_appDb.accountCreditCardDeadline);
      case 'account.card.lote':
        return _countRows(_appDb.accountCardLote);
      case 'l10n.ec.bank':
        return _countRows(_appDb.resBank);
      case 'l10n_ec.cash.out.type':
        return _countRows(_appDb.cashOutType);
      default:
        logger.w('[CatalogSync] Unknown model for count: $modelName');
        return 0;
    }
  }

  /// Mapping from Odoo model names to local table deletion functions
  static const Map<String, String> _modelToTableMap = {
    'product.product': 'product_product',
    'res.partner': 'res_partner',
    'product.category': 'product_category',
    'account.tax': 'account_tax',
    'uom.uom': 'uom_uom',
    'product.uom': 'product_uom',
    'product.pricelist': 'product_pricelist',
    'account.payment.term': 'account_payment_term',
    'res.users': 'res_users',
    'res.groups': 'res_groups',
    'stock.warehouse': 'stock_warehouse',
    'crm.team': 'crm_team',
    'account.fiscal.position': 'account_fiscal_position',
    'account.fiscal.position.tax': 'account_fiscal_position_tax',
    'res.currency': 'res_currency',
    'decimal.precision': 'decimal_precision',
    'sale.order': 'sale_order',
    'sale.order.line': 'sale_order_line',
    'sale.order.withhold.line': 'sale_order_withhold_line',
    'account.move': 'account_move',
    'account.move.line': 'account_move_line',
    'account.journal': 'account_journal',
    'account.payment.method.line': 'account_payment_method_line',
    'account.advance': 'account_advance',
    'collection.config': 'collection_config',
    'res.company': 'res_company',
    'res.country': 'res_country',
    'res.country.state': 'res_country_state',
    'res.lang': 'res_lang',
    'account.credit.card.brand': 'account_credit_card_brand',
    'account.credit.card.deadline': 'account_credit_card_deadline',
    'account.card.lote': 'account_card_lote',
    'l10n.ec.bank': 'res_bank',
  };

  /// Boolean predicates used by the normal catalog fetches.
  ///
  /// An incremental fetch with `active = true` (or `sale_ok = true`) cannot
  /// see a record after it stops matching that domain. Those changes are not
  /// unlinks, so `sync.deleted.record` does not report them. Querying the
  /// inverse predicate with `active_test = false` turns them into local
  /// tombstones before the watermark is allowed to advance.
  static const Map<String, List<String>> _domainExitFields = {
    'product.product': ['active', 'sale_ok'],
    'res.partner': ['active'],
    'account.tax': ['active'],
    'uom.uom': ['active'],
    'product.pricelist': ['active'],
    'account.payment.term': ['active'],
    'account.journal': ['active'],
    'res.users': ['active'],
    'stock.warehouse': ['active'],
    'crm.team': ['active'],
    'account.fiscal.position': ['active'],
    'res.currency': ['active'],
    'collection.config': ['active'],
    'res.lang': ['active'],
    'account.credit.card.brand': ['active'],
    'account.credit.card.deadline': ['active'],
    'l10n.ec.bank': ['active'],
  };

  /// Sync deleted records from Odoo for a specific model or all tracked models
  ///
  /// Calls sync.deleted.record.get_deleted_since to get IDs of deleted records,
  /// then removes them from the local database.
  ///
  /// Returns the total number of records deleted locally.
  Future<int> syncDeletedRecords({
    String? odooModel,
    String? localModelName,
    DateTime? sinceDate,
  }) async {
    if (!isOnline) return 0;
    if (odooModel != null && !_modelToTableMap.containsKey(odooModel)) {
      logger.d(
        '[CatalogSync] Skipping tombstones for untracked model $odooModel',
      );
      return 0;
    }

    final since = sinceDate ?? DateTime.now().subtract(const Duration(days: 7));
    final sinceStr = since
        .toUtc()
        .toIso8601String()
        .replaceFirst('T', ' ')
        .substring(0, 19);

    int totalDeleted = 0;

    // If specific model requested, only sync that model
    final modelsToSync = odooModel != null
        ? [odooModel]
        : _modelToTableMap.keys.toList();

    for (final model in modelsToSync) {
      logger.d(
        '[CatalogSync] Checking deleted records for $model since $sinceStr',
      );

      try {
        final response = await odooClient!.call(
          model: 'sync.deleted.record',
          method: 'get_deleted_since',
          kwargs: {'model_name': model, 'since_date': sinceStr},
        );

        if (response is! List) {
          throw FormatException(
            'sync.deleted.record returned ${response.runtimeType} for $model',
          );
        }

        if (response.isNotEmpty) {
          final deletedRecords = List<Map<String, dynamic>>.from(response);
          final deletedIds = deletedRecords
              .map((record) => record['record_id'] as int)
              .toList();

          if (deletedIds.isNotEmpty) {
            logger.i(
              '[CatalogSync] Found ${deletedIds.length} deleted $model records',
            );

            final count = await _deleteLocalRecords(model, deletedIds);
            totalDeleted += count;

            logger.i('[CatalogSync] Deleted $count local $model records');
          }
        }

        final scopedDomain = scopedSyncDomainForModel(model, _now());
        totalDeleted += scopedDomain == null
            ? await _syncRecordsLeavingDomain(model, sinceStr)
            : await _syncRecordsLeavingScopedDomain(model, scopedDomain);
      } catch (e, stackTrace) {
        logger.w('[CatalogSync] Error syncing deleted $model: $e');
        Error.throwWithStackTrace(e, stackTrace);
      }
    }

    return totalDeleted;
  }

  /// Reconciles caches whose membership is defined by a non-boolean domain.
  ///
  /// The comparison is intentionally limited to locally cached remote IDs.
  /// This avoids downloading an unbounded history while still detecting rows
  /// that left a rolling window or changed business state. Local/offline work
  /// is removed from the candidate set before any remote comparison.
  Future<int> _syncRecordsLeavingScopedDomain(
    String odooModel,
    List<dynamic> scopeDomain,
  ) async {
    final candidates = await _localScopedCandidateIds(odooModel);
    if (candidates.isEmpty) return 0;

    final protectedIds = await _pendingOfflineRecordIds(
      odooModel,
      candidates.toSet(),
    );
    final eligible = candidates
        .where((id) => !protectedIds.contains(id))
        .toList(growable: false);
    if (eligible.isEmpty) return 0;

    const pageSize = 500;
    var deleted = 0;
    for (var offset = 0; offset < eligible.length; offset += pageSize) {
      final end = (offset + pageSize).clamp(0, eligible.length);
      final page = eligible.sublist(offset, end);
      final response = await odooClient!.call(
        model: odooModel,
        method: 'search_read',
        kwargs: {
          'domain': [
            ['id', 'in', page],
            ...scopeDomain,
          ],
          'fields': ['id'],
          'limit': page.length,
          'order': 'id asc',
        },
      );
      if (response is! List) {
        throw FormatException(
          '$odooModel.search_read returned ${response.runtimeType}',
        );
      }

      final retainedIds = response
          .map((record) => (record as Map<String, dynamic>)['id'] as int)
          .toSet();
      final staleIds = page
          .where((id) => !retainedIds.contains(id))
          .toList(growable: false);
      deleted += await _deleteLocalRecords(odooModel, staleIds);
    }

    if (deleted > 0) {
      logger.i(
        '[CatalogSync] Removed $deleted local $odooModel records outside the cache scope',
      );
    }
    return deleted;
  }

  Future<List<int>> _localScopedCandidateIds(String odooModel) async {
    switch (odooModel) {
      case 'sale.order':
        final orders =
            await (_appDb.select(_appDb.saleOrder)..where(
                  (table) =>
                      table.odooId.isBiggerThanValue(0) &
                      table.isSynced.equals(true) &
                      table.pendingConfirm.equals(false) &
                      table.hasQueuedInvoice.equals(false),
                ))
                .get();
        if (orders.isEmpty) return const [];

        final unsyncedLineOrders = <int>{
          for (final line in await (_appDb.select(
            _appDb.saleOrderLine,
          )..where((table) => table.isSynced.equals(false))).get())
            line.orderId,
          for (final line in await (_appDb.select(
            _appDb.saleOrderWithholdLine,
          )..where((table) => table.isSynced.equals(false))).get())
            line.orderId,
          for (final line in await (_appDb.select(
            _appDb.saleOrderPaymentLine,
          )..where((table) => table.isSynced.equals(false))).get())
            line.orderId,
        };
        return orders
            .where((order) => !unsyncedLineOrders.contains(order.odooId))
            .map((order) => order.odooId)
            .toList(growable: false);

      case 'account.advance':
        return (await (_appDb.select(
              _appDb.accountAdvance,
            )..where((table) => table.odooId.isBiggerThanValue(0))).get())
            .map((record) => record.odooId)
            .toList(growable: false);

      case 'account.card.lote':
        return (await (_appDb.select(
              _appDb.accountCardLote,
            )..where((table) => table.odooId.isBiggerThanValue(0))).get())
            .map((record) => record.odooId)
            .toList(growable: false);

      default:
        return const [];
    }
  }

  Future<Set<int>> _pendingOfflineRecordIds(
    String odooModel,
    Set<int> candidateIds,
  ) async {
    if (candidateIds.isEmpty) return const {};
    final operations = await _appDb.select(_appDb.offlineQueue).get();
    final protectedIds = <int>{};

    for (final operation in operations) {
      if (operation.status == 'completed') continue;
      final recordId = operation.recordId;
      if (operation.model == odooModel &&
          recordId != null &&
          candidateIds.contains(recordId)) {
        protectedIds.add(recordId);
      }
      if (odooModel == 'sale.order') {
        final parentOrderId = operation.parentOrderId;
        if (parentOrderId != null && candidateIds.contains(parentOrderId)) {
          protectedIds.add(parentOrderId);
        }
      }
    }
    return protectedIds;
  }

  Future<int> _syncRecordsLeavingDomain(
    String odooModel,
    String sinceStr,
  ) async {
    final exitFields = _domainExitFields[odooModel];
    final isCreditNote = odooModel == 'account.move';
    if (!isCreditNote && (exitFields == null || exitFields.isEmpty)) return 0;

    final inverseDomain = isCreditNote
        ? <dynamic>[
            ['write_date', '>=', sinceStr],
            ['move_type', '=', 'out_refund'],
            '|',
            '|',
            ['state', '!=', 'posted'],
            [
              'payment_state',
              'not in',
              ['not_paid', 'partial'],
            ],
            ['amount_residual', '<=', 0],
          ]
        : <dynamic>[
            ['write_date', '>=', sinceStr],
            if (exitFields!.length == 1)
              [exitFields.single, '=', false]
            else ...[
              for (var index = 1; index < exitFields.length; index++) '|',
              for (final field in exitFields) [field, '=', false],
            ],
          ];

    const pageSize = 500;
    var offset = 0;
    var deleted = 0;

    while (true) {
      final response = await odooClient!.call(
        model: odooModel,
        method: 'search_read',
        kwargs: {
          'domain': inverseDomain,
          'fields': ['id'],
          'limit': pageSize,
          'offset': offset,
          'order': 'id asc',
        },
        context: const {'active_test': false},
      );
      if (response is! List) {
        throw FormatException(
          '$odooModel.search_read returned ${response.runtimeType}',
        );
      }

      final ids = response
          .map((record) => (record as Map<String, dynamic>)['id'] as int)
          .toList(growable: false);
      deleted += await _deleteLocalRecords(odooModel, ids);

      if (response.length < pageSize) break;
      offset += pageSize;
    }

    if (deleted > 0) {
      logger.i(
        '[CatalogSync] Removed $deleted local $odooModel records that left the sync domain',
      );
    }
    return deleted;
  }

  /// Delete local records by Odoo IDs for a given model
  Future<int> _deleteLocalRecords(String odooModel, List<int> odooIds) async {
    if (odooIds.isEmpty) return 0;

    final safeIds = await _safeDeletionIds(odooModel, odooIds);
    if (safeIds.isEmpty) return 0;

    switch (odooModel) {
      case 'product.product':
        return (_appDb.delete(
          _appDb.productProduct,
        )..where((t) => t.odooId.isIn(safeIds))).go();

      case 'res.partner':
        return (_appDb.delete(
          _appDb.resPartner,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'product.category':
        return (_appDb.delete(
          _appDb.productCategory,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.tax':
        return (_appDb.delete(
          _appDb.accountTax,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'uom.uom':
        return (_appDb.delete(
          _appDb.uomUom,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'product.uom':
        return (_appDb.delete(
          _appDb.productUom,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'product.pricelist':
        return (_appDb.delete(
          _appDb.productPricelist,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.payment.term':
        return (_appDb.delete(
          _appDb.accountPaymentTerm,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'res.users':
        return (_appDb.delete(
          _appDb.resUsers,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'res.groups':
        return (_appDb.delete(
          _appDb.resGroups,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'stock.warehouse':
        return (_appDb.delete(
          _appDb.stockWarehouse,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'crm.team':
        return (_appDb.delete(
          _appDb.crmTeam,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.fiscal.position':
        return (_appDb.delete(
          _appDb.accountFiscalPosition,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.fiscal.position.tax':
        return (_appDb.delete(
          _appDb.accountFiscalPositionTax,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'res.currency':
        return (_appDb.delete(
          _appDb.resCurrency,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'decimal.precision':
        return (_appDb.delete(
          _appDb.decimalPrecision,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'sale.order':
        return _appDb.transaction(() async {
          await (_appDb.delete(
            _appDb.saleOrderPaymentLine,
          )..where((t) => t.orderId.isIn(safeIds))).go();
          await (_appDb.delete(
            _appDb.saleOrderWithholdLine,
          )..where((t) => t.orderId.isIn(safeIds))).go();
          await (_appDb.delete(
            _appDb.saleOrderLine,
          )..where((t) => t.orderId.isIn(safeIds))).go();
          return (_appDb.delete(
            _appDb.saleOrder,
          )..where((t) => t.odooId.isIn(safeIds))).go();
        });

      case 'sale.order.line':
        return (_appDb.delete(
          _appDb.saleOrderLine,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'sale.order.withhold.line':
        return (_appDb.delete(
          _appDb.saleOrderWithholdLine,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.move':
        return _appDb.transaction(() async {
          final protectedIds = await _accountMoveIdsWithOfflineIntent(odooIds);
          final deletableIds = odooIds
              .where((id) => !protectedIds.contains(id))
              .toList(growable: false);
          if (deletableIds.isEmpty) return 0;

          await (_appDb.delete(
            _appDb.accountMoveLine,
          )..where((t) => t.moveId.isIn(deletableIds))).go();
          return (_appDb.delete(
            _appDb.accountMove,
          )..where((t) => t.odooId.isIn(deletableIds))).go();
        });

      case 'account.move.line':
        return (_appDb.delete(
          _appDb.accountMoveLine,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.journal':
        return (_appDb.delete(
          _appDb.accountJournal,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.payment.method.line':
        return (_appDb.delete(
          _appDb.accountPaymentMethodLine,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.advance':
        return (_appDb.delete(
          _appDb.accountAdvance,
        )..where((t) => t.odooId.isIn(safeIds))).go();

      case 'collection.config':
        return (_appDb.delete(
          _appDb.collectionConfig,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'res.company':
        return (_appDb.delete(
          _appDb.resCompanyTable,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'res.country':
        return (_appDb.delete(
          _appDb.resCountry,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'res.country.state':
        return (_appDb.delete(
          _appDb.resCountryState,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'res.lang':
        return (_appDb.delete(
          _appDb.resLang,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.credit.card.brand':
        return (_appDb.delete(
          _appDb.accountCreditCardBrand,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.credit.card.deadline':
        return (_appDb.delete(
          _appDb.accountCreditCardDeadline,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      case 'account.card.lote':
        return (_appDb.delete(
          _appDb.accountCardLote,
        )..where((t) => t.odooId.isIn(safeIds))).go();

      case 'l10n.ec.bank':
        return (_appDb.delete(
          _appDb.resBank,
        )..where((t) => t.odooId.isIn(odooIds))).go();

      default:
        logger.w('[CatalogSync] No local table mapping for model: $odooModel');
        return 0;
    }
  }

  /// Account moves can be referenced by a queued payment wizard even though
  /// the queue row itself belongs to the wizard model. Removing that credit
  /// note while the operation is pending would make the offline intent
  /// impossible to inspect, retry or resolve after a conflict.
  Future<Set<int>> _accountMoveIdsWithOfflineIntent(
    List<int> candidates,
  ) async {
    final candidateIds = candidates.toSet();
    final protectedIds = <int>{};
    final rows = await _appDb.select(_appDb.offlineQueue).get();

    for (final row in rows) {
      // Completed operations are normally removed immediately. Ignore a
      // leftover completed row, but keep pending, in-flight, conflict and
      // dead-letter intents because all remain actionable by the user.
      if (row.status == 'completed') continue;

      if (row.model == 'account.move' &&
          row.recordId != null &&
          candidateIds.contains(row.recordId)) {
        protectedIds.add(row.recordId!);
      }

      try {
        final values = jsonDecode(row.values);
        _collectCreditNoteIds(values, candidateIds, protectedIds);
      } on FormatException {
        logger.w(
          '[CatalogSync] Ignoring malformed offline payload while protecting account.move rows (op=${row.id})',
        );
      }
    }

    if (protectedIds.isNotEmpty) {
      logger.d(
        '[CatalogSync] Preserving ${protectedIds.length} account.move rows referenced by offline operations',
      );
    }
    return protectedIds;
  }

  void _collectCreditNoteIds(
    Object? value,
    Set<int> candidates,
    Set<int> protectedIds,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key == 'credit_note_id') {
          final id = switch (entry.value) {
            final int id => id,
            final List values when values.isNotEmpty && values.first is int =>
              values.first as int,
            _ => null,
          };
          if (id != null && candidates.contains(id)) protectedIds.add(id);
        }
        _collectCreditNoteIds(entry.value, candidates, protectedIds);
      }
    } else if (value is List) {
      for (final item in value) {
        _collectCreditNoteIds(item, candidates, protectedIds);
      }
    }
  }

  Future<List<int>> _safeDeletionIds(
    String odooModel,
    List<int> requestedIds,
  ) async {
    if (!const {
      'sale.order',
      'account.advance',
      'account.card.lote',
    }.contains(odooModel)) {
      return requestedIds;
    }

    final candidates = (await _localScopedCandidateIds(odooModel)).toSet();
    final requested = requestedIds.where(candidates.contains).toSet();
    final protectedIds = await _pendingOfflineRecordIds(odooModel, requested);
    return requested
        .where((id) => !protectedIds.contains(id))
        .toList(growable: false);
  }
}
