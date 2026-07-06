/// ClientManager extensions - Business methods beyond generated CRUD
///
/// The base ClientManager is generated in client.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/clients/client.model.dart';

/// Extension methods for ClientManager
extension ClientManagerBusiness on ClientManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  /// Get partner by Odoo ID (alias for readLocal)
  Future<Client?> getPartner(int odooId) => readLocal(odooId);

  /// Get partner by VAT (Ecuador tax ID)
  Future<Client?> getPartnerByVat(String vat) async {
    if (vat.isEmpty) return null;

    final result = await (_db.select(_db.resPartner)
          ..where((t) => t.vat.equals(vat)))
        .getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Watch a partner's data reactively (for credit info, etc.)
  Stream<Client?> watchPartner(int odooId) {
    return (_db.select(_db.resPartner)
          ..where((t) => t.odooId.equals(odooId)))
        .watchSingleOrNull()
        .map((result) => result != null ? fromDrift(result) : null);
  }

  /// Search partners by name, VAT, or email
  Future<List<Client>> searchPartners({
    String? query,
    int limit = 20,
  }) async {
    if (query == null || query.isEmpty) {
      final results = await (_db.select(_db.resPartner)..limit(limit)).get();
      return results.map(fromDrift).toList();
    }

    final pattern = '%${query.toLowerCase()}%';
    final results = await (_db.select(_db.resPartner)
          ..where(
            (t) =>
                t.name.lower().like(pattern) |
                t.vat.like(pattern) |
                t.email.lower().like(pattern),
          )
          ..limit(limit))
        .get();
    return results.map(fromDrift).toList();
  }

  /// Get all partners from local database
  Future<List<Client>> getAllPartners({int? limit}) async {
    final query = _db.select(_db.resPartner);
    if (limit != null) {
      query.limit(limit);
    }
    final results = await query.get();
    return results.map(fromDrift).toList();
  }

  /// Get partner by UUID
  ///
  /// Used for offline-first partner creation
  Future<Client?> getPartnerByUuid(String uuid) async {
    final query = _db.select(_db.resPartner)
      ..where((t) => t.partnerUuid.equals(uuid));
    final result = await query.getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Check if VAT is unique (for creation validation)
  ///
  /// Returns error message if VAT exists, null if unique
  Future<String?> checkVatUniqueness(String? vat, {int? excludeOdooId}) async {
    if (vat == null || vat.isEmpty) return null;

    final query = _db.select(_db.resPartner)
      ..where((t) => t.vat.equals(vat));

    if (excludeOdooId != null) {
      query.where((t) => t.odooId.equals(excludeOdooId).not());
    }

    final existing = await query.getSingleOrNull();

    if (existing != null) {
      return 'El número de Identificación Tributaria $vat ya está registrado para otro contacto: ${existing.name}';
    }
    return null;
  }

  /// Update partner ID by UUID after sync
  Future<void> updatePartnerIdByUuid(String partnerUuid, int newOdooId) async {
    await (_db.update(_db.resPartner)
          ..where((t) => t.partnerUuid.equals(partnerUuid)))
        .write(
      ResPartnerCompanion(
        odooId: drift.Value(newOdooId),
        isSynced: const drift.Value(true),
      ),
    );
  }

  /// Propaga el ID real de Odoo a los registros locales que todavía
  /// referencian el ID negativo temporal de un partner creado offline.
  ///
  /// [updatePartnerIdByUuid] solo actualiza la fila `res_partner` en sí —
  /// NO toca otros registros locales que ya guardaron ese ID negativo como
  /// foreign key (ej. una `sale.order` creada para este cliente antes de
  /// que el partner se sincronizara). Sin esta cascada, esas órdenes
  /// quedan con `partner_id` negativo para siempre y su propio sync falla
  /// de forma permanente en Odoo (ID de partner inválido).
  ///
  /// Ver también `OfflineQueueDataSource.updatePartnerIdInPendingOperations`
  /// para el mismo reemplazo dentro de operaciones YA encoladas.
  Future<void> updatePartnerIdInDependents(
    int oldPartnerId,
    int newPartnerId,
  ) async {
    if (oldPartnerId == newPartnerId) return;

    await (_db.update(_db.saleOrder)
          ..where((t) => t.partnerId.equals(oldPartnerId)))
        .write(SaleOrderCompanion(partnerId: drift.Value(newPartnerId)));

    await (_db.update(_db.accountPaymentTable)
          ..where((t) => t.partnerId.equals(oldPartnerId)))
        .write(AccountPaymentCompanion(partnerId: drift.Value(newPartnerId)));
  }

  /// Insert a partner created offline (with UUID and not synced)
  Future<void> insertOfflinePartner({
    required int localOdooId,
    required String name,
    required String partnerUuid,
    String? vat,
    String? email,
    String? phone,
    String? mobile,
    String? street,
    String? city,
    int? countryId,
    String? countryName,
  }) async {
    await _db.into(_db.resPartner).insert(
          ResPartnerCompanion.insert(
            odooId: localOdooId,
            name: name,
            vat: drift.Value(vat),
            email: drift.Value(email),
            phone: drift.Value(phone),
            mobile: drift.Value(mobile),
            street: drift.Value(street),
            city: drift.Value(city),
            countryId: drift.Value(countryId),
            countryName: drift.Value(countryName),
            partnerUuid: drift.Value(partnerUuid),
            isSynced: const drift.Value(false),
          ),
        );
  }

  /// Get unsynced partners
  Future<List<Client>> getUnsyncedPartners() async {
    final query = _db.select(_db.resPartner)
      ..where((t) => t.isSynced.equals(false));
    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }
}
