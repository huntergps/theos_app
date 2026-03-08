import 'package:drift/drift.dart' as drift;
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase, clientManager;

import '../../clients/repositories/client_repository.dart';

/// Utility functions for partner operations shared between
/// Fast Sale and Sale Order Form screens.

/// Load authorized payment term IDs for a partner
///
/// Offline-first behavior:
/// 1. If [cachedIds] is provided and not empty, returns cached value when offline
/// 2. If online, fetches fresh data from Odoo
/// 3. Falls back to empty list (meaning "no restrictions") if offline and no cache
///
/// Note: The field `terminos_pagos_ids` is a custom field from l10n_ec_collection_box_pos
/// module and is NOT synced to local SQLite. The caller should store the result
/// in state (e.g., `partnerPaymentTermIds`) for offline access.
///
/// Returns an empty list if:
/// - Offline and no cached data
/// - Partner has no payment term restrictions (terminos_pagos_ids is empty/false)
/// - An error occurs during the request
///
/// Usage:
/// ```dart
/// final termIds = await loadPartnerPaymentTermIds(
///   partnerId: 123,
///   odooClient: ref.read(odooClientProvider),
///   cachedIds: state.partnerPaymentTermIds, // Optional: return this if offline
/// );
/// ```
Future<List<int>> loadPartnerPaymentTermIds({
  required int partnerId,
  required OdooClient? odooClient,
  List<int>? cachedIds,
  String logTag = '[PartnerUtils]',
}) async {
  // Offline: return cached value if available
  if (odooClient == null) {
    if (cachedIds != null && cachedIds.isNotEmpty) {
      logger.d(logTag, 'Offline - returning cached payment terms: $cachedIds');
      return cachedIds;
    }
    logger.d(
      logTag,
      'Offline - no cached payment terms, returning empty (no restrictions)',
    );
    return [];
  }

  // Online: fetch fresh data from Odoo
  try {
    logger.d(logTag, 'Loading payment terms for partner $partnerId from Odoo');

    final result = await odooClient.read(
      model: 'res.partner',
      ids: [partnerId],
      fields: ['terminos_pagos_ids'],
    );

    if (result.isNotEmpty) {
      final ids = result.first['terminos_pagos_ids'];
      // Odoo can return false, null, [] or [1, 2, 3]
      if (ids != null && ids != false && ids is List && ids.isNotEmpty) {
        logger.i(logTag, 'Partner $partnerId authorized payment terms: $ids');
        return ids.cast<int>();
      }
    }

    logger.d(logTag, 'Partner $partnerId has no payment term restrictions');
    return [];
  } catch (e) {
    // On error, fallback to cached value if available
    if (cachedIds != null && cachedIds.isNotEmpty) {
      logger.w(logTag, 'Error loading payment terms, using cached: $e');
      return cachedIds;
    }
    logger.w(logTag, 'Error loading partner payment terms: $e');
    return [];
  }
}

/// Find "Consumidor Final" partner from local database
///
/// Search priority:
/// 1. Partner with VAT = '9999999999999' (most reliable for Ecuador)
/// 2. Partner with name containing 'consumidor final' (case insensitive)
/// 3. First active partner by ID (fallback)
///
/// Returns a tuple of (odooId, name) or null if no partner found.
///
/// Usage:
/// ```dart
/// final result = await findConsumidorFinal();
/// if (result != null) {
///   final (partnerId, partnerName) = result;
///   // Use partnerId and partnerName
/// }
/// ```
Future<(int, String)?> findConsumidorFinal({
  required AppDatabase appDb,
  String logTag = '[PartnerUtils]',
}) async {
  try {

    // 1. Search by VAT 9999999999999 (most reliable for Ecuador)
    final byVat =
        await (appDb.select(appDb.resPartner)
              ..where((t) => t.active.equals(true))
              ..where((t) => t.vat.equals('9999999999999'))
              ..limit(1))
            .getSingleOrNull();

    if (byVat != null) {
      logger.d(
        logTag,
        'Found Consumidor Final by VAT: ${byVat.odooId} - ${byVat.name}',
      );
      return (byVat.odooId, byVat.name);
    }

    // 2. Fallback: search by name containing "consumidor final"
    final activeClients = await clientManager.searchLocal(
      domain: [['active', '=', true]],
      orderBy: 'name asc',
    );
    final byName = activeClients.where((c) {
      final lower = c.name.toLowerCase();
      return lower.contains('consumidor') && lower.contains('final');
    }).firstOrNull;

    if (byName != null) {
      logger.d(logTag, 'Found Consumidor Final by name: ${byName.id} - ${byName.name}');
      return (byName.id, byName.name);
    }

    // 3. Fallback: first active partner
    final firstPartner =
        await (appDb.select(appDb.resPartner)
              ..where((t) => t.active.equals(true))
              ..orderBy([(t) => drift.OrderingTerm.asc(t.odooId)])
              ..limit(1))
            .getSingleOrNull();

    if (firstPartner != null) {
      logger.d(
        logTag,
        'No Consumidor Final found, using first partner: ${firstPartner.odooId} - ${firstPartner.name}',
      );
      return (firstPartner.odooId, firstPartner.name);
    }

    logger.d(logTag, 'No partners found in local database');
    return null;
  } catch (e) {
    logger.e(logTag, 'Error finding Consumidor Final', e);
    return null;
  }
}

/// Update a partner field with automatic rollback on failure
///
/// This utility function handles the optimistic update pattern:
/// 1. Caller updates local state immediately with [newValue]
/// 2. This function sends the update to Odoo
/// 3. On failure, caller should revert using [onRevert] callback
///
/// Returns true if update was successful, false otherwise.
///
/// Usage:
/// ```dart
/// // Update local state immediately
/// state = state.copyWith(partnerPhone: newPhone);
///
/// final success = await updatePartnerField(
///   partnerId: partnerId,
///   fieldName: 'phone',
///   newValue: newPhone,
///   partnerRepo: ref.read(partnerRepositoryProvider)!,
///   onSuccess: () => logger.i('Phone updated'),
///   onFailure: (error) {
///     state = state.copyWith(partnerPhone: oldPhone); // Revert
///     logger.w('Failed to update phone: $error');
///   },
/// );
/// ```
Future<bool> updatePartnerField({
  required int partnerId,
  required String fieldName,
  required dynamic newValue,
  required ClientRepository partnerRepo,
  void Function()? onSuccess,
  void Function(String error)? onFailure,
  String logTag = '[PartnerUtils]',
}) async {
  try {
    final success = await partnerRepo.updatePartnerField(
      partnerId: partnerId,
      field: fieldName,
      value: newValue,
    );

    if (success) {
      logger.i(logTag, 'Partner $fieldName updated: $newValue');
      onSuccess?.call();
      return true;
    } else {
      final error = 'No se pudo actualizar $fieldName del cliente';
      logger.w(logTag, 'Failed to update partner $fieldName');
      onFailure?.call(error);
      return false;
    }
  } catch (e) {
    // Extract clean error message
    final errorMsg = e.toString().replaceFirst('Exception: ', '');
    logger.e(logTag, 'Error updating partner $fieldName: $e');
    onFailure?.call(errorMsg);
    return false;
  }
}

/// Partner data record for local database operations
///
/// Used by both FastSale and SaleOrderForm for consistent partner data handling.
typedef PartnerLocalData = ({
  int id,
  String name,
  String? vat,
  String? phone,
  String? email,
  String? street,
  String? avatar,
});

/// Load complete partner data from local database (Drift)
///
/// This is an offline-first operation that never hits the network.
/// Use this when you need to quickly load partner data for display.
///
/// For fresh data from Odoo, use ClientRepository.searchPartners instead.
///
/// Returns null if partner not found in local database.
///
/// Usage:
/// ```dart
/// final data = await loadPartnerDataFromLocal(partnerId: 123);
/// if (data != null) {
///   // use data
/// }
/// ```
Future<PartnerLocalData?> loadPartnerDataFromLocal({
  required AppDatabase appDb,
  required int partnerId,
  String logTag = '[PartnerUtils]',
}) async {
  try {
    final db = appDb;
    final partner = await (db.select(
      db.resPartner,
    )..where((t) => t.odooId.equals(partnerId))).getSingleOrNull();

    if (partner == null) {
      logger.d(logTag, 'Partner $partnerId not found in local database');
      return null;
    }

    logger.d(
      logTag,
      'Loaded partner from local DB: ${partner.name}, vat=${partner.vat}',
    );

    return (
      id: partner.odooId,
      name: partner.name,
      vat: partner.vat,
      phone: partner.phone,
      email: partner.email,
      street: partner.street,
      avatar: partner.avatar128,
    );
  } catch (e) {
    logger.w(logTag, 'Error loading partner data for $partnerId: $e');
    return null;
  }
}
