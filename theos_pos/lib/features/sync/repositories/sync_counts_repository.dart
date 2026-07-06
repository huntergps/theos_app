/// SyncCountsRepository - Conteos locales y detección de eliminaciones remotas
///
/// Extraído de CatalogSyncRepository (Fase E2): conteo de registros locales
/// por modelo, y sync de registros eliminados en Odoo (tombstones vía
/// sync.deleted.record).
library;

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import 'qweb_template_sync_repository.dart';

/// Repository for local record counts and deleted-record synchronization.
class SyncCountsRepository {
  final AppDatabase _appDb;
  final OdooClient? odooClient;
  final QwebTemplateSyncRepository _qwebTemplateSync;

  SyncCountsRepository({
    required AppDatabase appDb,
    required this.odooClient,
    required QwebTemplateSyncRepository qwebTemplateSync,
  })  : _appDb = appDb,
        _qwebTemplateSync = qwebTemplateSync;

  bool get isOnline => odooClient != null;

  Future<int> getLocalProductCount() async =>
      (await _appDb.select(_appDb.productProduct).get()).length;

  Future<int> getLocalCategoryCount() async =>
      (await _appDb.select(_appDb.productCategory).get()).length;

  Future<int> getLocalTaxCount() async =>
      (await _appDb.select(_appDb.accountTax).get()).length;

  Future<int> getLocalUomCount() async =>
      (await _appDb.select(_appDb.uomUom).get()).length;

  Future<int> getLocalProductUomCount() async =>
      (await _appDb.select(_appDb.productUom).get()).length;

  Future<int> getLocalPricelistCount() async =>
      (await _appDb.select(_appDb.productPricelist).get()).length;

  Future<int> getLocalPaymentTermCount() async =>
      (await _appDb.select(_appDb.accountPaymentTerm).get()).length;

  Future<int> getLocalPartnerCount() async =>
      (await _appDb.select(_appDb.resPartner).get()).length;

  Future<int> getLocalSaleOrderCount() async =>
      (await _appDb.select(_appDb.saleOrder).get()).length;

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
        return (await _appDb.select(_appDb.resUsers).get()).length;
      case 'stock.warehouse':
        return (await _appDb.select(_appDb.stockWarehouse).get()).length;
      case 'crm.team':
        return (await _appDb.select(_appDb.crmTeam).get()).length;
      case 'account.fiscal.position':
        return (await _appDb.select(_appDb.accountFiscalPosition).get()).length;
      case 'account.fiscal.position.tax':
        return (await _appDb.select(_appDb.accountFiscalPositionTax).get()).length;
      case 'res.currency':
        return (await _appDb.select(_appDb.resCurrency).get()).length;
      case 'decimal.precision':
        return (await _appDb.select(_appDb.decimalPrecision).get()).length;
      case 'account.journal':
        return (await _appDb.select(_appDb.accountJournal).get()).length;
      case 'account.payment.method.line':
        return (await _appDb.select(_appDb.accountPaymentMethodLine).get()).length;
      case 'account.advance':
        return (await _appDb.select(_appDb.accountAdvance).get()).length;
      case 'account.move':
        return (await _appDb.select(_appDb.accountMove).get()).length;
      case 'collection.config':
        return (await _appDb.select(_appDb.collectionConfig).get()).length;
      case 'res.company':
        return (await _appDb.select(_appDb.resCompanyTable).get()).length;
      case 'res.country':
        return (await _appDb.select(_appDb.resCountry).get()).length;
      case 'res.country.state':
        return (await _appDb.select(_appDb.resCountryState).get()).length;
      case 'res.lang':
        return (await _appDb.select(_appDb.resLang).get()).length;
      case 'res.groups':
        return (await _appDb.select(_appDb.resGroups).get()).length;
      case 'ir.ui.view':
        return _qwebTemplateSync.getLocalTemplateCount();
      case 'account.credit.card.brand':
        return (await _appDb.select(_appDb.accountCreditCardBrand).get()).length;
      case 'account.credit.card.deadline':
        return (await _appDb.select(_appDb.accountCreditCardDeadline).get()).length;
      case 'account.card.lote':
        return (await _appDb.select(_appDb.accountCardLote).get()).length;
      case 'res.bank':
        return (await _appDb.select(_appDb.resBank).get()).length;
      case 'l10n_ec.cash.out.type':
        return (await _appDb.select(_appDb.cashOutType).get()).length;
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
    'product.pricelist': 'product_pricelist',
    'account.payment.term': 'account_payment_term',
    'sale.order': 'sale_order',
    'sale.order.line': 'sale_order_line',
    'sale.order.withhold.line': 'sale_order_withhold_line',
    'account.move': 'account_move',
    'account.move.line': 'account_move_line',
    'account.journal': 'account_journal',
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

    final since = sinceDate ?? DateTime.now().subtract(const Duration(days: 7));
    final sinceStr = since.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

    int totalDeleted = 0;

    // If specific model requested, only sync that model
    final modelsToSync = odooModel != null
        ? [odooModel]
        : _modelToTableMap.keys.toList();

    for (final model in modelsToSync) {
      try {
        logger.d('[CatalogSync] Checking deleted records for $model since $sinceStr');

        final response = await odooClient!.call(
          model: 'sync.deleted.record',
          method: 'get_deleted_since',
          kwargs: {
            'model_name': model,
            'since_date': sinceStr,
          },
        );

        if (response == null || response is! List || response.isEmpty) {
          continue;
        }

        final deletedRecords = List<Map<String, dynamic>>.from(response);
        final deletedIds = deletedRecords
            .map((r) => r['record_id'] as int)
            .toList();

        if (deletedIds.isEmpty) continue;

        logger.i('[CatalogSync] Found ${deletedIds.length} deleted $model records');

        // Delete from local database based on model
        final count = await _deleteLocalRecords(model, deletedIds);
        totalDeleted += count;

        logger.i('[CatalogSync] Deleted $count local $model records');
      } catch (e) {
        logger.w('[CatalogSync] Error syncing deleted $model: $e');
      }
    }

    return totalDeleted;
  }

  /// Delete local records by Odoo IDs for a given model
  Future<int> _deleteLocalRecords(String odooModel, List<int> odooIds) async {
    if (odooIds.isEmpty) return 0;

    switch (odooModel) {
      case 'product.product':
        return (_appDb.delete(_appDb.productProduct)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'res.partner':
        return (_appDb.delete(_appDb.resPartner)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'product.category':
        return (_appDb.delete(_appDb.productCategory)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.tax':
        return (_appDb.delete(_appDb.accountTax)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'uom.uom':
        return (_appDb.delete(_appDb.uomUom)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'product.pricelist':
        return (_appDb.delete(_appDb.productPricelist)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.payment.term':
        return (_appDb.delete(_appDb.accountPaymentTerm)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'sale.order':
        return (_appDb.delete(_appDb.saleOrder)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'sale.order.line':
        return (_appDb.delete(_appDb.saleOrderLine)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.move':
        // Also delete related lines first
        for (final moveId in odooIds) {
          await (_appDb.delete(_appDb.accountMoveLine)
                ..where((t) => t.moveId.equals(moveId)))
              .go();
        }
        return (_appDb.delete(_appDb.accountMove)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.move.line':
        return (_appDb.delete(_appDb.accountMoveLine)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.journal':
        return (_appDb.delete(_appDb.accountJournal)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      default:
        logger.w('[CatalogSync] No local table mapping for model: $odooModel');
        return 0;
    }
  }
}
