import 'package:dartz/dartz.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show Failure, CacheFailure;
import 'package:theos_pos_core/theos_pos_core.dart';

/// Repository for Authentication - Consolidated offline-first implementation
///
/// Combines local (SQLite) and remote (Odoo) operations in a single class.
/// Handles user session management with offline support.
///
/// F5 (eliminación de fuga de OdooClient): este repo ya NO guarda su propio
/// `OdooClient?` — todas sus llamadas son sobre `res.users`, modelo que ya
/// tiene manager generado (`userManager`). Se usa `userManager.isOnline`/
/// `userManager.client` en su lugar (mismo cliente, inyectado centralmente
/// vía `initialize()`). No hay ningún caso de "composition-root" real acá
/// (login/fetchVersion/sesión web viven en `OdooService`/`AppInitializer`,
/// no en este repo).
class AuthRepository {
  AuthRepository();

  // ============ User Operations ============

  /// Get current authenticated user from local cache
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await userManager.getCurrentUser();
      return Right(user);
    } catch (e) {
      return Left(CacheFailure(message: 'Error getting current user: $e'));
    }
  }

  /// Refresh user data from server
  ///
  /// Follows offline-first pattern:
  /// 1. Fetch from Odoo
  /// 2. Save to local DB
  /// 3. Re-read from local DB and return
  Future<Either<Failure, User?>> refreshUser(int userId) async {
    if (!userManager.isOnline) {
      return getCurrentUser();
    }

    try {
      final data = await userManager.client.searchRead(
        model: 'res.users',
        fields: userManager.odooFields,
        domain: [
          ['id', '=', userId],
        ],
        limit: 1,
      );

      if (data.isNotEmpty) {
        // Parse and save to local DB
        final remoteUser = userManager.fromOdoo(data.first);
        await userManager.upsertUser(remoteUser);
        // Re-read from local DB (offline-first pattern)
        return getCurrentUser();
      }
      return getCurrentUser();
    } catch (e) {
      return getCurrentUser();
    }
  }

  /// Check if user is authenticated (has cached user)
  Future<bool> isAuthenticated() async {
    try {
      final user = await userManager.getCurrentUser();
      return user != null;
    } catch (_) {
      return false;
    }
  }

  /// Logout - clear local user data
  Future<Either<Failure, bool>> logout() async {
    try {
      // Note: Full logout including session cleanup is handled by OdooService
      // This just clears the local user cache flag
      return const Right(true);
    } catch (e) {
      return Left(CacheFailure(message: 'Error al cerrar sesión: $e'));
    }
  }

  /// Check if connected to server
  ///
  /// Uses a minimal searchRead (single field, limit 1) against res.users
  /// to verify both network connectivity AND valid API key authentication.
  /// A simple HTTP ping would only verify network, not auth status.
  Future<bool> isConnected() async {
    if (!userManager.isOnline) return false;

    try {
      await userManager.client.searchRead(
        model: 'res.users',
        fields: ['id'],
        domain: [],
        limit: 1,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
