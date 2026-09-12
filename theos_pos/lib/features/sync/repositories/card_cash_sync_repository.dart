/// Sync de catálogos de tarjetas, retiros de caja y permisos del usuario.
library;

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

import '../../../shared/constants/user_groups.dart';
import 'sync_scope_domains.dart';

/// A permission snapshot could not be resolved completely.
///
/// No local membership is published when this exception is thrown.
class PermissionSnapshotSyncException implements Exception {
  final int userId;
  final String message;
  final Object? cause;

  const PermissionSnapshotSyncException({
    required this.userId,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'Permission snapshot for user $userId failed: $message';
}

/// Repository for card brand/deadline/lote catalogs, cash-out types
/// (no-op, hardcoded), and per-user group sync.
class CardCashSyncRepository {
  final AppDatabase _appDb;
  final OdooClient? odooClient;

  CardCashSyncRepository({required this._appDb, required this.odooClient});

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
        domain.add(['write_date', '>=', formatOdooDateTime(sinceDate)]);
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

      if (result is! List) {
        throw FormatException(
          'account.credit.card.brand.search_read returned ${result.runtimeType}',
        );
      }

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

        final existing = await (_appDb.select(
          _appDb.accountCreditCardBrand,
        )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

        if (existing != null) {
          await (_appDb.update(
            _appDb.accountCreditCardBrand,
          )..where((t) => t.id.equals(existing.id))).write(companion);
        } else {
          await _appDb.into(_appDb.accountCreditCardBrand).insert(companion);
        }
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card brands');
      onProgress?.call(
        SyncProgress(
          model: 'account.credit.card.brand',
          total: count,
          synced: count,
          phase: SyncPhase.completed,
        ),
      );
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card brands: $e');
      rethrow;
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
        domain.add(['write_date', '>=', formatOdooDateTime(sinceDate)]);
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

      if (result is! List) {
        throw FormatException(
          'account.credit.card.deadline.search_read returned ${result.runtimeType}',
        );
      }

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
          months: Value(d['meses'] as int? ?? 0),
          kind: Value(d['type'] is String ? d['type'] as String : 'current'),
          hasInterest: Value(d['interes'] as bool? ?? false),
          active: Value(d['active'] as bool? ?? true),
          writeDate: Value(writeDate ?? DateTime.now()),
        );

        final existing = await (_appDb.select(
          _appDb.accountCreditCardDeadline,
        )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();

        if (existing != null) {
          await (_appDb.update(
            _appDb.accountCreditCardDeadline,
          )..where((t) => t.id.equals(existing.id))).write(companion);
        } else {
          await _appDb.into(_appDb.accountCreditCardDeadline).insert(companion);
        }
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card deadlines');
      onProgress?.call(
        SyncProgress(
          model: 'account.credit.card.deadline',
          total: count,
          synced: count,
          phase: SyncPhase.completed,
        ),
      );
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card deadlines: $e');
      rethrow;
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
      final domain = cardLoteSyncScope();
      if (sinceDate != null) {
        domain.add(['write_date', '>=', formatOdooDateTime(sinceDate)]);
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

      if (result is! List) {
        throw FormatException(
          'account.card.lote.search_read returned ${result.runtimeType}',
        );
      }

      int count = 0;
      for (final data in result) {
        final record = cardLoteManager.fromOdoo(data as Map<String, dynamic>);
        await cardLoteManager.upsertLocal(record);
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card lotes');
      onProgress?.call(
        SyncProgress(
          model: 'account.card.lote',
          total: count,
          synced: count,
          phase: SyncPhase.completed,
        ),
      );
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card lotes: $e');
      rethrow;
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
    // groups_id on res.users is restricted via external API (both read and
    // search_read return HTTP 500). Use has_group() as the reliable approach.
    if (userId == null || odooClient == null) return 0;
    return _syncUserGroupsViaHasGroup(userId);
  }

  /// Resolves every known membership before publishing one local snapshot.
  ///
  /// `res.users.has_group` is a read-only recordset method in Odoo 19/20, so
  /// [userId] is sent through JSON-2 `ids` and `group_ext_id` as a kwarg.
  Future<int> _syncUserGroupsViaHasGroup(int userId) async {
    final membershipResults = await Future.wait(
      kKnownTheosUserGroups.map((xmlId) async {
        final dynamic result;
        try {
          result = await odooClient!.call(
            model: 'res.users',
            method: 'has_group',
            ids: [userId],
            kwargs: {'group_ext_id': xmlId},
          );
        } catch (error) {
          throw PermissionSnapshotSyncException(
            userId: userId,
            message: 'could not resolve $xmlId',
            cause: error,
          );
        }
        if (result is! bool) {
          throw PermissionSnapshotSyncException(
            userId: userId,
            message: '$xmlId returned ${result.runtimeType}, expected bool',
          );
        }
        return (xmlId: xmlId, isMember: result);
      }),
    );
    final matchedXmlIds = membershipResults
        .where((entry) => entry.isMember)
        .map((entry) => entry.xmlId)
        .toList(growable: false);
    final remoteGroups = await _fetchKnownGroups(userId, matchedXmlIds);
    final matchedGroupIds = matchedXmlIds
        .map((xmlId) => remoteGroups[xmlId]!['id']! as int)
        .toList(growable: false);

    await _appDb.transaction(() async {
      for (final xmlId in matchedXmlIds) {
        final group = remoteGroups[xmlId]!;
        final odooId = group['id']! as int;
        final companion = ResGroupsCompanion(
          odooId: Value(odooId),
          name: Value(group['name'] as String? ?? xmlId),
          fullName: Value(group['full_name'] as String?),
          xmlId: Value(xmlId),
          share: Value(group['share'] as bool? ?? false),
        );
        final updatedGroup = await (_appDb.update(
          _appDb.resGroups,
        )..where((table) => table.odooId.equals(odooId))).write(companion);
        if (updatedGroup == 0) {
          await _appDb.into(_appDb.resGroups).insert(companion);
        }
      }
      final updated =
          await (_appDb.update(
            _appDb.resUsers,
          )..where((table) => table.odooId.equals(userId))).write(
            ResUsersCompanion(groupIds: Value(matchedGroupIds.join(','))),
          );
      if (updated != 1) {
        throw PermissionSnapshotSyncException(
          userId: userId,
          message: 'local user was not found',
        );
      }
    });

    logger.d(
      '[CatalogSync] Published ${matchedGroupIds.length} groups for user '
      '$userId: $matchedXmlIds',
    );
    return matchedGroupIds.length;
  }

  /// Loads only the security groups consumed by the app. Login must not wait
  /// for Odoo's complete group catalog.
  Future<Map<String, Map<String, dynamic>>> _fetchKnownGroups(
    int userId,
    List<String> xmlIds,
  ) async {
    if (xmlIds.isEmpty) return const {};

    final localGroups = await (_appDb.select(
      _appDb.resGroups,
    )..where((table) => table.xmlId.isIn(xmlIds))).get();
    final resultByXmlId = <String, Map<String, dynamic>>{
      for (final group in localGroups)
        if (group.xmlId != null)
          group.xmlId!: {
            'id': group.odooId,
            'name': group.name,
            'full_name': group.fullName,
            'share': group.share,
          },
    };
    final unresolvedXmlIds = xmlIds
        .where((xmlId) => !resultByXmlId.containsKey(xmlId))
        .toList(growable: false);
    if (unresolvedXmlIds.isEmpty) return resultByXmlId;

    // A normal user cannot read ir.model.data in Odoo 19.5. Resolve only the
    // effective groups of this exact user, then ask res.groups for their
    // external IDs through the public recordset API.
    final dynamic userRows = await odooClient!.read(
      model: 'res.users',
      ids: [userId],
      fields: ['id', 'all_group_ids'],
    );
    if (userRows is! List || userRows.length != 1) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'res.users/read returned an invalid identity response',
      );
    }
    final userRow = userRows.single;
    if (userRow is! Map || userRow['id'] != userId) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'res.users/read returned a different user identity',
      );
    }
    final rawGroupIds = userRow['all_group_ids'];
    if (rawGroupIds is! List) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'res.users/read returned invalid all_group_ids',
      );
    }
    final effectiveGroupIds = <int>{};
    for (final rawGroupId in rawGroupIds) {
      if (rawGroupId is! int || rawGroupId <= 0) {
        throw PermissionSnapshotSyncException(
          userId: userId,
          message: 'res.users/read returned invalid group IDs',
        );
      }
      effectiveGroupIds.add(rawGroupId);
    }
    if (effectiveGroupIds.isEmpty) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'res.users/read returned no effective groups',
      );
    }

    final externalIds = await odooClient!.call(
      model: 'res.groups',
      method: 'get_external_id',
      ids: effectiveGroupIds.toList(growable: false),
      kwargs: const <String, dynamic>{},
    );
    if (externalIds is! Map) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'res.groups/get_external_id returned invalid data',
      );
    }
    final groupIdByXmlId = <String, int>{};
    for (final entry in externalIds.entries) {
      final groupId = entry.key is int
          ? entry.key as int
          : int.tryParse(entry.key.toString());
      final xmlId = entry.value;
      if (groupId == null || groupId <= 0 || xmlId is! String) {
        throw PermissionSnapshotSyncException(
          userId: userId,
          message: 'res.groups/get_external_id returned invalid IDs',
        );
      }
      if (unresolvedXmlIds.contains(xmlId)) {
        groupIdByXmlId[xmlId] = groupId;
      }
    }

    final missingExternalIds = unresolvedXmlIds
        .where((xmlId) => !groupIdByXmlId.containsKey(xmlId))
        .toList();
    if (missingExternalIds.isNotEmpty) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'missing Odoo groups: ${missingExternalIds.join(', ')}',
      );
    }

    final dynamic groups = await odooClient!.searchRead(
      model: 'res.groups',
      domain: [
        ['id', 'in', groupIdByXmlId.values.toList()],
      ],
      fields: ['id', 'name', 'full_name', 'share'],
      limit: groupIdByXmlId.length,
    );
    if (groups is! List) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'res.groups/search_read returned invalid data',
      );
    }
    final groupById = {
      for (final group in groups)
        if (group['id'] is int) group['id']! as int: group,
    };
    final missingGroups = groupIdByXmlId.entries
        .where((entry) => !groupById.containsKey(entry.value))
        .map((entry) => entry.key)
        .toList();
    if (missingGroups.isNotEmpty) {
      throw PermissionSnapshotSyncException(
        userId: userId,
        message: 'unreadable Odoo groups: ${missingGroups.join(', ')}',
      );
    }
    resultByXmlId.addAll({
      for (final entry in groupIdByXmlId.entries)
        entry.key: groupById[entry.value]!,
    });
    return resultByXmlId;
  }
}
