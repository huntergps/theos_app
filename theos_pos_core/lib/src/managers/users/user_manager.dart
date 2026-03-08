/// UserManager extensions - Business methods beyond generated CRUD
///
/// The base UserManager is generated in user.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/users/user.model.dart';

/// Extension methods for UserManager
extension UserManagerBusiness on UserManager {
  /// Get user by login
  Future<User?> getByLogin(String login) async {
    final db = database as AppDatabase;
    final query = db.select(db.resUsers)
      ..where((t) => t.login.equals(login));
    final result = await query.getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Get current user
  Future<User?> getCurrentUser() async {
    final db = database as AppDatabase;
    final query = db.select(db.resUsers)
      ..where((t) => t.isCurrentUser.equals(true));
    final result = await query.getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Set a user as the current user
  Future<void> setCurrentUser(int userId) async {
    final db = database as AppDatabase;
    await db.customStatement('UPDATE res_users SET is_current_user = 0');
    await (db.update(db.resUsers)
          ..where((t) => t.odooId.equals(userId)))
        .write(const ResUsersCompanion(isCurrentUser: drift.Value(true)));
  }

  /// Upsert a user, optionally setting as current user
  Future<void> upsertUser(User user, {bool isCurrent = true}) async {
    final db = database as AppDatabase;
    if (isCurrent) {
      await (db.update(db.resUsers)
            ..where((tbl) => tbl.isCurrentUser.equals(true)))
          .write(const ResUsersCompanion(isCurrentUser: drift.Value(false)));
    }

    // Use the generated upsertLocal which handles insert/update
    await upsertLocal(user);

    if (isCurrent) {
      await (db.update(db.resUsers)
            ..where((t) => t.odooId.equals(user.id)))
          .write(ResUsersCompanion(isCurrentUser: drift.Value(isCurrent)));
    }
  }

  /// Get user by Odoo ID (alias for readLocal)
  Future<User?> getUser(int odooId) => readLocal(odooId);

  /// Get all users from local database
  Future<List<User>> getAllUsers() async {
    final db = database as AppDatabase;
    final results = await db.select(db.resUsers).get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get users by list of Odoo IDs
  Future<List<User>> getUsersByOdooIds(List<int> odooIds) async {
    if (odooIds.isEmpty) return [];
    final db = database as AppDatabase;
    final results = await (db.select(db.resUsers)
          ..where((tbl) => tbl.odooId.isIn(odooIds)))
        .get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Clear the is_current_user flag from all users (used during logout)
  ///
  /// Returns the number of users that were cleared
  Future<int> clearCurrentUser() async {
    final db = database as AppDatabase;
    return await (db.update(db.resUsers)
          ..where((tbl) => tbl.isCurrentUser.equals(true)))
        .write(const ResUsersCompanion(isCurrentUser: drift.Value(false)));
  }

  /// Clear all users (useful for data purge/reset)
  Future<void> clearAllUsers() async {
    final db = database as AppDatabase;
    await db.delete(db.resUsers).go();
  }

  /// Check if a user exists locally by Odoo ID
  Future<bool> userExists(int odooId) async {
    final db = database as AppDatabase;
    final result = await (db.select(db.resUsers)
          ..where((tbl) => tbl.odooId.equals(odooId))
          ..limit(1))
        .getSingleOrNull();
    return result != null;
  }

  /// Get user count
  Future<int> getUserCount() async {
    final db = database as AppDatabase;
    final count = await (db.selectOnly(db.resUsers)
          ..addColumns([db.resUsers.id.count()]))
        .map((row) => row.read(db.resUsers.id.count()))
        .getSingleOrNull();
    return count ?? 0;
  }
}
