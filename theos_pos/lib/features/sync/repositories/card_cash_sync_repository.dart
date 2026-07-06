/// CardCashSyncRepository - Sync de tarjetas de crédito, cash out y grupos de usuario
///
/// Extraído de CatalogSyncRepository (Fase E2). Nota histórica del archivo
/// original: hay overlap conocido con el sync de Card Brands/Deadlines/Lotes
/// en `payment_service.dart` — NO se consolida en este refactor (señalado en
/// el plan de descomposición para auditoría aparte con integration-engineer).
library;

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

/// Repository for card brand/deadline/lote catalogs, cash-out types
/// (no-op, hardcoded), and per-user group sync.
class CardCashSyncRepository {
  final AppDatabase _appDb;
  final OdooClient? odooClient;

  /// Callback al facade — `syncGroups` sigue siendo un wrapper de una línea
  /// en `CatalogSyncRepository` (delega a `UserSyncRepository`), fuera del
  /// alcance de este split. `syncUserGroups` necesita poblar la tabla de
  /// grupos ANTES de resolver las membresías del usuario.
  final Future<int> Function({int batchSize, DateTime? sinceDate}) syncGroups;

  CardCashSyncRepository({
    required AppDatabase appDb,
    required this.odooClient,
    required this.syncGroups,
  }) : _appDb = appDb;

  /// Sync card brands (account.credit.card.brand) from Odoo to local DB.
  ///
  /// Reads all active card brands and upserts into [AccountCreditCardBrand].
  /// CardBrand is a simple DTO (not @OdooModel) so we use raw DB operations.
  Future<int> syncCardBrands({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (odooClient == null) return 0;
    try {
      final domain = <List<dynamic>>[
        ['active', '=', true],
      ];
      if (sinceDate != null) {
        domain.add(['write_date', '>=', sinceDate.toIso8601String()]);
      }

      final result = await odooClient!.call(
        model: 'account.credit.card.brand',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name', 'code', 'active', 'write_date'],
          'limit': batchSize,
          'order': 'name asc',
        },
      );

      if (result == null || result is! List) return 0;

      int count = 0;
      for (final b in result) {
        final odooId = b['id'] as int;
        final writeDateRaw = b['write_date'];
        final writeDate = writeDateRaw is String
            ? DateTime.tryParse(writeDateRaw)
            : null;
        final companion = AccountCreditCardBrandCompanion(
          odooId: Value(odooId),
          name: Value(b['name'] as String? ?? ''),
          code: Value(b['code'] as String?),
          active: Value(b['active'] as bool? ?? true),
          writeDate: Value(writeDate ?? DateTime.now()),
        );

        final existing = await (_appDb.select(_appDb.accountCreditCardBrand)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_appDb.update(_appDb.accountCreditCardBrand)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _appDb.into(_appDb.accountCreditCardBrand).insert(companion);
        }
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card brands');
      onProgress?.call(SyncProgress(model: 'account.credit.card.brand', total: count, synced: count, phase: SyncPhase.completed));
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card brands: $e');
      return 0;
    }
  }

  /// Sync card deadlines (account.credit.card.deadline) from Odoo to local DB.
  ///
  /// Reads all active card deadlines and upserts into [AccountCreditCardDeadline].
  Future<int> syncCardDeadlines({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (odooClient == null) return 0;
    try {
      final domain = <List<dynamic>>[
        ['active', '=', true],
      ];
      if (sinceDate != null) {
        domain.add(['write_date', '>=', sinceDate.toIso8601String()]);
      }

      final result = await odooClient!.call(
        model: 'account.credit.card.deadline',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name', 'meses', 'active', 'write_date'],
          'limit': batchSize,
          'order': 'name asc',
        },
      );

      if (result == null || result is! List) return 0;

      int count = 0;
      for (final d in result) {
        final odooId = d['id'] as int;
        final writeDateRaw = d['write_date'];
        final writeDate = writeDateRaw is String
            ? DateTime.tryParse(writeDateRaw)
            : null;
        final companion = AccountCreditCardDeadlineCompanion(
          odooId: Value(odooId),
          name: Value(d['name'] as String? ?? ''),
          deadlineDays: Value(d['meses'] as int? ?? 0),
          active: Value(d['active'] as bool? ?? true),
          writeDate: Value(writeDate ?? DateTime.now()),
        );

        final existing = await (_appDb.select(_appDb.accountCreditCardDeadline)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_appDb.update(_appDb.accountCreditCardDeadline)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _appDb.into(_appDb.accountCreditCardDeadline).insert(companion);
        }
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card deadlines');
      onProgress?.call(SyncProgress(model: 'account.credit.card.deadline', total: count, synced: count, phase: SyncPhase.completed));
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card deadlines: $e');
      return 0;
    }
  }

  /// Sync card lotes (account.card.lote) from Odoo to local DB.
  ///
  /// Uses [cardLoteManager] which has full @OdooModel support.
  /// Only syncs open lotes (active transactions) to keep local DB lean.
  Future<int> syncCardLotes({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (odooClient == null) return 0;
    try {
      final domain = <List<dynamic>>[
        ['state', '=', 'open'],
      ];
      if (sinceDate != null) {
        domain.add(['write_date', '>=', sinceDate.toIso8601String()]);
      }

      final result = await odooClient!.call(
        model: 'account.card.lote',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': cardLoteManager.odooFields,
          'limit': batchSize,
          'order': 'id desc',
        },
      );

      if (result == null || result is! List) return 0;

      int count = 0;
      for (final data in result) {
        final record = cardLoteManager.fromOdoo(data as Map<String, dynamic>);
        await cardLoteManager.upsertLocal(record);
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card lotes');
      onProgress?.call(SyncProgress(model: 'account.card.lote', total: count, synced: count, phase: SyncPhase.completed));
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card lotes: $e');
      return 0;
    }
  }

  /// Sync cash out types — no-op, types are hardcoded.
  ///
  /// CashOutType in theos_pos_core is a static class with predefined constants
  /// (expense, withhold, refund, commission, invoice, general, security, other).
  /// These are not Odoo records — they're client-side classifications.
  /// No sync needed.
  Future<int> syncCashOutTypes({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    // CashOutType is hardcoded in cash_out.model.dart — nothing to sync.
    logger.d('[CatalogSync]', 'Cash out types are hardcoded, no sync needed');
    return 0;
  }

  /// Sync user groups for a specific user
  ///
  /// Fetches the user's group memberships from Odoo and updates the local
  /// user record, then ensures all referenced groups exist in the local
  /// res_groups table.
  Future<int> syncUserGroups([
    int? userId,
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  ]) async {
    // First ensure groups table is populated
    await syncGroups(batchSize: batchSize, sinceDate: sinceDate);

    // Then fetch the specific user's group memberships from Odoo.
    // groups_id on res.users is restricted via external API (both read and
    // search_read return HTTP 500). Use has_group() as the reliable approach.
    if (userId != null && odooClient != null) {
      await _syncUserGroupsViaHasGroup(userId);
    }
    return 0;
  }

  /// Check each known group XML ID via has_group() method.
  /// This works even when groups_id field is restricted via external API.
  /// In JSON-2 API, kwargs are spread into the body, so group_ext_id
  /// becomes a top-level parameter as Odoo expects.
  Future<void> _syncUserGroupsViaHasGroup(int userId) async {
    const knownGroups = [
      'base.group_system',
      'base.group_user',
      'account.group_account_manager',
      'sales_team.group_sale_salesman',
      'sales_team.group_sale_manager',
      'l10n_ec_collection_box.group_collection_user',
      'l10n_ec_collection_box.group_collection_manager',
    ];

    try {
      final matchedXmlIds = <String>[];
      final matchedGroupIds = <int>[];
      final appDb = _appDb;

      for (final xmlId in knownGroups) {
        try {
          final result = await odooClient!.call(
            model: 'res.users',
            method: 'has_group',
            ids: [userId],
            kwargs: {'group_ext_id': xmlId},
          );
          if (result == true) {
            matchedXmlIds.add(xmlId);
            // Find local group ID by xml_id
            final localGroup = await (appDb.select(appDb.resGroups)
                  ..where((t) => t.xmlId.equals(xmlId))
                  ..limit(1))
                .getSingleOrNull();
            if (localGroup != null) {
              matchedGroupIds.add(localGroup.odooId);
            }
          }
        } catch (e) {
          logger.w('[CatalogSync] has_group check failed for $xmlId: $e');
        }
      }

      if (matchedGroupIds.isNotEmpty) {
        final groupIdsStr = matchedGroupIds.join(',');
        await (appDb.update(appDb.resUsers)
              ..where((t) => t.odooId.equals(userId)))
            .write(ResUsersCompanion(groupIds: Value(groupIdsStr)));
        logger.d('[CatalogSync] Updated user $userId with ${matchedGroupIds.length} groups: $matchedXmlIds');
      } else {
        logger.w('[CatalogSync] No groups matched for user $userId');
      }
    } catch (e) {
      logger.e('[CatalogSync] has_group sync failed: $e');
    }
  }
}
