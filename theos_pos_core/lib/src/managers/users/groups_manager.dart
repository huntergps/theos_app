/// GroupsManager - Manager for res.groups model
///
/// Read-only manager for security groups data synced from Odoo.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

/// Lightweight data class for security group
class SecurityGroup {
  final int odooId;
  final String name;
  final String? fullName;
  final int? categoryId;
  final String? categoryName;
  final DateTime? writeDate;

  const SecurityGroup({
    required this.odooId,
    required this.name,
    this.fullName,
    this.categoryId,
    this.categoryName,
    this.writeDate,
  });
}

/// Manager for res.groups model
class GroupsManager {
  final AppDatabase _db;

  GroupsManager(this._db);

  String get odooModel => 'res.groups';

  List<String> get odooFields => [
        'id',
        'name',
        'full_name',
        'category_id',
        'write_date',
      ];

  /// Convert Odoo data to domain model
  SecurityGroup fromOdoo(Map<String, dynamic> data) {
    return SecurityGroup(
      odooId: data['id'] as int,
      name: data['name'] as String? ?? '',
      fullName: data['full_name'] as String?,
      categoryId: odoo.extractMany2oneId(data['category_id']),
      categoryName: odoo.extractMany2oneName(data['category_id']),
      writeDate: odoo.parseOdooDateTime(data['write_date']),
    );
  }

  /// Upsert group to local database
  Future<void> upsertLocal(SecurityGroup record) async {
    final companion = ResGroupsCompanion(
      odooId: Value(record.odooId),
      name: Value(record.name),
      fullName: Value(record.fullName),
      categoryId: Value(record.categoryId),
      categoryName: Value(record.categoryName),
      writeDate: Value(record.writeDate),
    );

    final existing = await (_db.select(_db.resGroups)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.resGroups)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.resGroups).insert(companion);
    }
  }

  /// Get group by Odoo ID
  Future<ResGroup?> getById(int odooId) async {
    return (_db.select(_db.resGroups)..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
  }

  /// Get groups by IDs
  Future<List<ResGroup>> getByIds(List<int> odooIds) async {
    return (_db.select(_db.resGroups)
          ..where((t) => t.odooId.isIn(odooIds))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Get all groups
  Future<List<ResGroup>> getAll() async {
    return (_db.select(_db.resGroups)
          ..orderBy([(t) => OrderingTerm.asc(t.fullName)]))
        .get();
  }

  /// Check if user has a specific group by XML ID.
  ///
  /// Looks up the group by its [groupXmlId] (e.g. 'base.group_user') in the
  /// ResGroups table, then checks if the group's odooId is present in the
  /// user's `groupIds` field (stored as JSON array or comma-separated string).
  Future<bool> userHasGroup(int userId, String groupXmlId) async {
    // 1. Find the group by xmlId
    final group = await (_db.select(_db.resGroups)
          ..where((t) => t.xmlId.equals(groupXmlId)))
        .getSingleOrNull();

    if (group == null) return false;

    // 2. Get the user
    final user = await (_db.select(_db.resUsers)
          ..where((t) => t.odooId.equals(userId)))
        .getSingleOrNull();

    if (user == null || user.groupIds == null) return false;

    // 3. Parse groupIds (supports JSON array [1,2,3] and comma-separated "1,2,3")
    final raw = user.groupIds!.trim();
    final List<int> userGroupIds;

    if (raw.startsWith('[')) {
      // JSON array format
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          userGroupIds = decoded.map<int>((e) => e is int ? e : int.parse('$e')).toList();
        } else {
          return false;
        }
      } catch (_) {
        return false;
      }
    } else {
      // Comma-separated format
      userGroupIds = raw
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    }

    // 4. Check if the group's odooId is in the user's group list
    return userGroupIds.contains(group.odooId);
  }
}
