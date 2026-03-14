import 'package:drift/drift.dart';

import '../../../core/database/repositories/base_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
// Models
import '../../../shared/models/res_device.model.dart';

/// Repository for user-related operations
///
/// Handles: Users, Partners, Devices, Password, IM Status
class UserRepository extends BaseRepository
    with SessionInfoCache, OfflineSupport {
  final AppDatabase _appDb;

  UserRepository({
    required super.odooClient,
    required super.db,
    required AppDatabase appDb,
  }) : _appDb = appDb;

  // ============ Users ============

  /// Get current user from Odoo and cache locally
  /// Falls back to local database when Odoo is offline
  Future<User?> getCurrentUser() async {
    try {
      final sessionInfo = await getSessionInfoCached();
      if (sessionInfo == null) {
        return await userManager.getCurrentUser();
      }

      int? uid = sessionInfo['uid'];
      String? username = sessionInfo['username'];

      if (uid == null && username == null) {
        return await userManager.getCurrentUser();
      }
      if (!isOnline) {
        return await userManager.getCurrentUser();
      }
      final response = await odooClient!.call(
        model: 'res.users',
        method: uid != null ? 'read' : 'search_read',
        kwargs: {
          if (uid != null) 'ids': [uid],
          if (uid == null && username != null)
            'domain': [
              ['login', '=', username],
            ],
          'fields': userManager.odooFields,
          if (uid == null) 'limit': 1,
        },
      );

      if (response is List && response.isNotEmpty) {
        final user = userManager.fromOdoo(response.first);
        await userManager.upsertUser(user);

        return user;
      }
    } catch (e) {
      return await userManager.getCurrentUser();
    }

    // If Odoo returned empty, try local database
    return await userManager.getCurrentUser();
  }

  /// Update user in Odoo and local cache
  Future<bool> updateUser(int userId, Map<String, dynamic> values) async {
    try {
      final success = await odooClient!.write(
        model: 'res.users',
        ids: [userId],
        values: values,
      );

      if (success) {
        final users = await odooClient!.read(
          model: 'res.users',
          ids: [userId],
          fields: userManager.odooFields,
        );
        if (users.isNotEmpty) {
          await userManager.upsertUser(userManager.fromOdoo(users.first));
        }
      }
      return success;
    } catch (e) {
      await queueOfflineOperation('res.users', 'write', userId, values);
      return false;
    }
  }

  // ============ Partners ============

  /// Get partner by ID (offline-first)
  ///
  /// Always fetches fresh data from Odoo when online to ensure
  /// contact fields (vat, phone, email, street) are up-to-date.
  /// Falls back to local cache when offline.
  Future<Client?> getPartner(int partnerId) async {
    final cached = await clientManager.getPartner(partnerId);

    try {
      final fullData = await odooClient!.read(
        model: 'res.partner',
        ids: [partnerId],
        fields: clientManager.odooFields,
      );
      if (fullData.isNotEmpty) {
        final partner = clientManager.fromOdoo(fullData.first);
        await clientManager.upsertLocal(partner);
        return partner;
      }
    } catch (e, stack) {
      logger.e('[UserRepository]', 'Error fetching partner $partnerId: $e');
      logger.d('[UserRepository]', 'Stack: $stack');
    }

    return cached;
  }

  /// Update partner
  Future<bool> updatePartner(int partnerId, Map<String, dynamic> values) async {
    try {
      final success = await odooClient!.write(
        model: 'res.partner',
        ids: [partnerId],
        values: values,
      );

      if (success) {
        final partners = await odooClient!.read(
          model: 'res.partner',
          ids: [partnerId],
          fields: clientManager.odooFields,
        );
        if (partners.isNotEmpty) {
          await clientManager.upsertLocal(clientManager.fromOdoo(partners.first));
        }
      }
      return success;
    } catch (e) {
      await queueOfflineOperation('res.partner', 'write', partnerId, values);
      return false;
    }
  }

  /// Search partners by name/email - OFFLINE-FIRST: searches local database
  Future<List<Map<String, dynamic>>> searchPartners(
    String query, {
    int limit = 20,
  }) async {
    try {
      if (query.isEmpty) return [];

      // OFFLINE-FIRST: Search in local SQLite database
      final appDb = _appDb;
      final pattern = '%${query.toLowerCase()}%';

      final results =
          await (appDb.select(appDb.resPartner)
                ..where((t) => t.active.equals(true))
                ..where(
                  (t) =>
                      t.name.lower().like(pattern) |
                      t.vat.lower().like(pattern) |
                      t.ref.lower().like(pattern) |
                      t.email.lower().like(pattern) |
                      t.phone.like(pattern),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.name)])
                ..limit(limit))
              .get();

      // Convert Drift data to Map format expected by dialogs
      final data = results
          .map(
            (p) => <String, dynamic>{
              'id': p.odooId,
              'name': p.name,
              'display_name': p.displayName ?? p.name,
              'email': p.email,
              'phone': p.phone,
              'mobile': p.mobile,
              'vat': p.vat,
              'ref': p.ref,
              'street': p.street,
              'street2': p.street2,
              'city': p.city,
              'zip': p.zip,
              'country_id': p.countryId != null
                  ? [p.countryId, p.countryName ?? '']
                  : false,
              'state_id': p.stateId != null
                  ? [p.stateId, p.stateName ?? '']
                  : false,
              'property_payment_term_id': p.propertyPaymentTermId != null
                  ? [p.propertyPaymentTermId, p.propertyPaymentTermName ?? '']
                  : false,
              'property_product_pricelist': p.propertyProductPricelist != null
                  ? [
                      p.propertyProductPricelist,
                      p.propertyProductPricelistName ?? '',
                    ]
                  : false,
              'is_company': p.isCompany,
              'parent_id': p.parentId != null
                  ? [p.parentId, p.parentName ?? '']
                  : false,
              'commercial_partner_id': p.commercialPartnerName != null
                  ? [p.odooId, p.commercialPartnerName]
                  : false,
              'lang': p.lang,
              'comment': p.comment,
              'image_128': p.avatar128,
            },
          )
          .toList();

      return data;
    } catch (e) {
      return [];
    }
  }

  // ============ Devices ============

  /// Get all active devices for current user
  Future<List<ResDevice>> getUserDevices({bool includeRevoked = false}) async {
    try {
      final domain = includeRevoked
          ? []
          : [
              ['revoked', '=', false],
            ];

      final data = await odooClient!.searchRead(
        model: 'res.device',
        fields: ResDevice.odooFields,
        domain: domain,
      );

      return data.map((e) => ResDevice.fromOdoo(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Revoke a specific device
  Future<bool> revokeDevice(int deviceId, String password) async {
    try {
      await odooClient!.call(
        model: 'res.device',
        method: 'mobile_revoke_device',
        args: [
          [deviceId],
          password,
        ],
        kwargs: {},
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Revoke all devices except current
  Future<bool> revokeAllDevices(String password) async {
    try {
      await odooClient!.call(
        model: 'res.users',
        method: 'mobile_revoke_all_devices',
        args: [password],
        kwargs: {},
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============ Password Management ============

  /// Change user password
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final result = await odooClient!.call(
        model: 'res.users',
        method: 'change_password',
        args: [oldPassword, newPassword],
        kwargs: {},
      );
      return result == true;
    } catch (e) {
      return false;
    }
  }

  // ============ IM Status ============

  /// Set manual IM status (online, away, busy, offline)
  Future<bool> setManualImStatus(String status) async {
    try {
      if (!['online', 'away', 'busy', 'offline'].contains(status)) {
        throw ArgumentError('Invalid IM status: $status');
      }

      await odooClient!.call(
        model: 'res.users',
        method: 'mobile_set_im_status',
        kwargs: {'status': status},
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // ============ Security Groups (hasGroup) ============

  /// Check if current user belongs to a group by XML ID (offline-first)
  ///
  /// Example: `hasGroup('base.group_user')` or `hasGroup('sales_team.group_sale_manager')`
  ///
  /// Returns true if user belongs to the group, false otherwise.
  /// Works offline by checking the local database.
  Future<bool> hasGroup(String groupXmlId) async {
    try {
      final appDb = _appDb;

      // Get current user
      final currentUser = await (appDb.select(appDb.resUsers)
            ..where((t) => t.isCurrentUser.equals(true)))
          .getSingleOrNull();

      if (currentUser == null || currentUser.groupIds == null) {
        return false;
      }

      // Parse user's group IDs from comma-separated string
      final userGroupIds = currentUser.groupIds!
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toSet();

      if (userGroupIds.isEmpty) {
        return false;
      }

      // Find group by XML ID
      final group = await (appDb.select(appDb.resGroups)
            ..where((t) => t.xmlId.equals(groupXmlId)))
          .getSingleOrNull();

      if (group == null) {
        // Group not found in local database
        return false;
      }

      // Check if user has this group
      return userGroupIds.contains(group.odooId);
    } catch (e) {
      return false;
    }
  }

  /// Check if current user satisfies group restrictions
  ///
  /// Supports comma-separated group XML IDs with optional negation (!)
  /// Example: `hasGroups('base.group_user,base.group_portal,!base.group_system')`
  ///
  /// Returns true if user is member of at least one positive group
  /// AND is NOT member of any negative (!) group.
  Future<bool> hasGroups(String groupSpec) async {
    if (groupSpec == '.') {
      return false;
    }

    final positives = <String>[];
    final negatives = <String>[];

    for (var groupXmlId in groupSpec.split(',')) {
      groupXmlId = groupXmlId.trim();
      if (groupXmlId.startsWith('!')) {
        negatives.add(groupXmlId.substring(1));
      } else {
        positives.add(groupXmlId);
      }
    }

    // Check negatives first (for performance)
    for (final negativeGroup in negatives) {
      if (await hasGroup(negativeGroup)) {
        return false;
      }
    }

    // Check positives
    for (final positiveGroup in positives) {
      if (await hasGroup(positiveGroup)) {
        return true;
      }
    }

    // If no positives specified, return true (only negatives were checked)
    return positives.isEmpty;
  }

  /// Get all groups the current user belongs to
  Future<List<String>> getCurrentUserGroups() async {
    try {
      final appDb = _appDb;

      // Get current user
      final currentUser = await (appDb.select(appDb.resUsers)
            ..where((t) => t.isCurrentUser.equals(true)))
          .getSingleOrNull();

      if (currentUser == null) {
        return [];
      }

      if (currentUser.groupIds == null) {
        return [];
      }

      // Parse user's group IDs
      final userGroupIds = currentUser.groupIds!
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();

      if (userGroupIds.isEmpty) {
        return [];
      }

      // Get group XML IDs from local database
      final groups = await (appDb.select(appDb.resGroups)
            ..where((t) => t.odooId.isIn(userGroupIds)))
          .get();

      final localXmlIds = groups
          .where((g) => g.xmlId != null && g.xmlId!.isNotEmpty)
          .map((g) => g.xmlId!)
          .toList();

      // If we have XML IDs locally, return them
      if (localXmlIds.isNotEmpty) {
        return localXmlIds;
      }

      // Otherwise, try to fetch from Odoo
      return await _fetchGroupXmlIdsFromOdoo(userGroupIds);
    } catch (e) {
      return [];
    }
  }

  /// Fetch XML IDs directly from Odoo for a list of group IDs
  /// Uses ir.model.data to look up external IDs for res.groups records
  Future<List<String>> _fetchGroupXmlIdsFromOdoo(List<int> groupIds) async {
    if (groupIds.isEmpty || odooClient == null) return [];

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

      final xmlIds = <String>[];
      final xmlIdMap = <int, String>{};

      for (final r in result) {
        final resId = r['res_id'] as int;
        final module = r['module'] as String? ?? '';
        final name = r['name'] as String? ?? '';
        if (module.isNotEmpty && name.isNotEmpty && !xmlIdMap.containsKey(resId)) {
          final xmlId = '$module.$name';
          xmlIdMap[resId] = xmlId;
          xmlIds.add(xmlId);
        }
      }

      // Also update local database with the XML IDs for future use
      if (xmlIdMap.isNotEmpty) {
        final appDb = _appDb;
        for (final entry in xmlIdMap.entries) {
          final groupId = entry.key;
          final xmlId = entry.value;
          await (appDb.update(appDb.resGroups)
                ..where((t) => t.odooId.equals(groupId)))
              .write(ResGroupsCompanion(xmlId: Value(xmlId)));
        }
      }

      return xmlIds;
    } catch (e) {
      logger.w('[UserRepo] Error fetching group XML IDs from Odoo: $e');
      return [];
    }
  }
}
