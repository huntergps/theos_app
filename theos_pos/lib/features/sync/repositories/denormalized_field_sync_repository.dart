/// DenormalizedFieldSyncRepository - Actualiza campos denormalizados
///
/// Extraído de CatalogSyncRepository (Fase E2): cuando un producto/cliente/
/// usuario/compañía cambia de nombre, estos métodos propagan el nuevo
/// nombre a las copias denormalizadas en sale_order/sale_order_line/
/// mail_activity (evita joins costosos en las pantallas de venta).
///
/// Consumido desde `notification_provider.dart` cuando llega un push de
/// WebSocket con un cambio de nombre.
library;

import 'package:drift/drift.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Repository for propagating denormalized name fields across tables.
class DenormalizedFieldSyncRepository {
  final AppDatabase _appDb;

  DenormalizedFieldSyncRepository({required AppDatabase appDb})
      : _appDb = appDb;

  /// Update product name in sale order lines
  Future<int> updateSaleOrderLinesProductName(
    int productId,
    String name,
  ) async {
    try {
      return await (_appDb.update(_appDb.saleOrderLine)
            ..where((t) => t.productId.equals(productId)))
          .write(SaleOrderLineCompanion(productName: Value(name)));
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error updating sale order lines product name',
        e,
      );
      return 0;
    }
  }

  /// Update partner fields in sale orders
  Future<int> updateSaleOrdersPartnerFields(
    int partnerId, {
    String? name,
    String? vat,
    String? street,
    String? phone,
    String? email,
    String?
    avatar, // Note: avatar is NOT stored in sale_order table, only in UI state
  }) async {
    try {
      // Note: partnerAvatar is NOT a column in sale_order table
      // It's populated via enrichment from res_partner when loading orders
      // The avatar update is handled separately in updatePartnerFieldsOnly
      return await (_appDb.update(
        _appDb.saleOrder,
      )..where((t) => t.partnerId.equals(partnerId))).write(
        SaleOrderCompanion(
          partnerName: name != null ? Value(name) : const Value.absent(),
          partnerVat: vat != null ? Value(vat) : const Value.absent(),
          partnerStreet: street != null ? Value(street) : const Value.absent(),
          partnerPhone: phone != null ? Value(phone) : const Value.absent(),
          partnerEmail: email != null ? Value(email) : const Value.absent(),
        ),
      );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating sale orders partner fields', e);
      return 0;
    }
  }

  /// Update user name in sale orders
  Future<int> updateSaleOrdersUserName(int userId, String name) async {
    try {
      return await (_appDb.update(_appDb.saleOrder)
            ..where((t) => t.userId.equals(userId)))
          .write(SaleOrderCompanion(userName: Value(name)));
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating sale orders user name', e);
      return 0;
    }
  }

  /// Update user name in activities
  Future<int> updateActivitiesUserName(int userId, String name) async {
    try {
      return await (_appDb.update(_appDb.mailActivityTable)
            ..where((t) => t.userId.equals(userId)))
          .write(MailActivityTableCompanion(userName: Value(name)));
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating activities user name', e);
      return 0;
    }
  }

  /// Update company name in sale orders
  Future<int> updateSaleOrdersCompanyName(int companyId, String name) async {
    try {
      return await (_appDb.update(_appDb.saleOrder)
            ..where((t) => t.companyId.equals(companyId)))
          .write(SaleOrderCompanion(companyName: Value(name)));
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating sale orders company name', e);
      return 0;
    }
  }
}
