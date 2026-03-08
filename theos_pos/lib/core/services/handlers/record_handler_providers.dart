import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model_record_handler.dart';
import '../../../features/clients/services/partner_record_handler.dart';
import '../../../features/prices/services/pricelist_record_handler.dart';
import '../../../features/products/services/product_record_handler.dart';
import '../../../features/taxes/services/tax_record_handler.dart';
import '../../../features/users/services/user_record_handler.dart';
import '../../../features/warehouses/services/warehouse_record_handler.dart';
import '../../../features/sales/services/team_record_handler.dart';

/// Provider for the model record handler registry
///
/// Registers all handlers for different Odoo models.
/// Used by the RelatedRecordResolver to fetch and upsert records.
final modelRecordHandlerRegistryProvider = Provider<ModelRecordHandlerRegistry>(
  (ref) {
    final registry = ModelRecordHandlerRegistry();

    // Products feature handlers
    registry.register(ProductRecordHandler());
    registry.register(UomRecordHandler());

    // Clients feature handlers
    registry.register(PartnerRecordHandler());

    // Taxes/accounting feature handlers
    registry.register(TaxRecordHandler());
    registry.register(FiscalPositionRecordHandler());
    registry.register(PaymentTermRecordHandler());

    // Prices feature handlers
    registry.register(PricelistRecordHandler());

    // Users feature handlers
    registry.register(UserRecordHandler());

    // Core handlers (generic models)
    registry.register(WarehouseRecordHandler());
    registry.register(TeamRecordHandler());

    return registry;
  },
);

/// Helper provider to get a specific handler by model name
final modelRecordHandlerProvider = Provider.family<ModelRecordHandler?, String>(
  (ref, model) {
    final registry = ref.watch(modelRecordHandlerRegistryProvider);
    return registry.getHandler(model);
  },
);
