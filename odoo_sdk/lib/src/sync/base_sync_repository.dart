/// Base class for sync repositories (Generic)
///
/// Provides common functionality:
/// - OdooClient access
/// - Cancellation support
/// - Logging helpers
/// - Date formatting utilities
/// - Many2one field parsing
library;

import '../api/odoo_client.dart';
import '../services/logger_service.dart';
import '../utils/odoo_parsing_utils.dart' show formatOdooDateTime;
import 'sync_models.dart';

/// Base class for sync repositories.
abstract class BaseSyncRepository<DB> {
  final OdooClient? odooClient;
  final DB db;

  /// Flag to request sync cancellation
  bool _cancelRequested = false;

  BaseSyncRepository({required this.db, this.odooClient});

  /// Check if online (has OdooClient)
  bool get isOnline => odooClient != null;

  /// Repository name for logging
  String get logTag;

  // ============================================================
  // CANCELLATION SUPPORT
  // ============================================================

  /// Request cancellation of current sync operation
  void cancelSync() {
    _cancelRequested = true;
  }

  /// Reset the cancellation flag
  void resetCancelFlag() {
    _cancelRequested = false;
  }

  /// Check if cancellation was requested
  bool get isCancelRequested => _cancelRequested;

  /// Check for cancellation and throw if requested
  void checkCancellation(int syncedCount) {
    if (_cancelRequested) {
      throw SyncCancelledException(
        'Sync cancelled by user',
        syncedCount: syncedCount,
      );
    }
  }

  // ============================================================
  // LOGGING HELPERS
  // ============================================================

  void logInfo(String message) {
    logger.i('[$logTag] $message');
  }

  void logWarning(String message) {
    logger.w('[$logTag] $message');
  }

  void logError(String message, [dynamic error, StackTrace? stack]) {
    logger.e('[$logTag] $message', error, stack);
  }

  void logDebug(String message) {
    logger.d('[$logTag] $message');
  }

  // ============================================================
  // DATE FORMATTING
  // ============================================================

  /// Format DateTime to Odoo format (YYYY-MM-DD HH:MM:SS in UTC)
  String formatDateForOdoo(DateTime date) => formatOdooDateTime(date) ?? '';

  /// Parse DateTime from Odoo string
  DateTime? parseDateTime(dynamic value) {
    if (value == null || value == false) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ============================================================
  // ODOO FIELD PARSING
  // ============================================================

  /// Extract ID from Odoo Many2one field ([id, name] or id or false)
  int? extractId(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is List && value.isNotEmpty) return value[0] as int?;
    return null;
  }

  /// Extract name from Odoo Many2one field ([id, name] or string or false)
  String? extractName(dynamic value) {
    if (value == null || value == false) return null;
    if (value is String) return value;
    if (value is List && value.length > 1) return value[1] as String?;
    return null;
  }

  /// Encode list of ints to comma-separated string
  /// Returns empty string '' for empty lists (not null)
  String? encodeIntList(dynamic value) {
    if (value == null || value == false) return null;
    if (value is List) {
      final ints = value.whereType<int>().toList();
      return ints.join(',');
    }
    return null;
  }
}
