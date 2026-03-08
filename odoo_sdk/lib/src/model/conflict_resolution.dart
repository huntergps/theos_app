/// Conflict Resolution System
///
/// Provides types and utilities for handling sync conflicts between
/// local changes and server changes.
library;

import 'package:meta/meta.dart';

/// Strategy for resolving sync conflicts.
enum SyncConflictStrategy {
  /// Server changes always win (discard local changes).
  serverWins,

  /// Local changes always win (overwrite server).
  localWins,

  /// Most recent write wins (based on write_date).
  lastWriteWins,

  /// Merge non-conflicting fields, ask user for conflicting ones.
  merge,

  /// Always ask user to choose.
  askUser,

  /// Create a copy for manual resolution later.
  createCopy,
}

/// Information about a sync conflict.
@immutable
class SyncConflict<T> {
  /// The record ID.
  final int recordId;

  /// The Odoo model name.
  final String model;

  /// Local version of the record.
  final T localRecord;

  /// Server version of the record.
  final T serverRecord;

  /// Local write timestamp (if available).
  final DateTime? localWriteDate;

  /// Server write timestamp.
  final DateTime? serverWriteDate;

  /// List of fields that have different values.
  final List<String> conflictingFields;

  const SyncConflict({
    required this.recordId,
    required this.model,
    required this.localRecord,
    required this.serverRecord,
    this.localWriteDate,
    this.serverWriteDate,
    this.conflictingFields = const [],
  });

  /// Check if local version is newer based on write dates.
  bool get isLocalNewer {
    if (localWriteDate == null || serverWriteDate == null) return false;
    return localWriteDate!.isAfter(serverWriteDate!);
  }

  /// Check if server version is newer based on write dates.
  bool get isServerNewer {
    if (localWriteDate == null || serverWriteDate == null) return true;
    return serverWriteDate!.isAfter(localWriteDate!);
  }
}

/// Result of conflict resolution.
@immutable
class ConflictResolution<T> {
  /// The resolved record to save.
  final T resolvedRecord;

  /// The action taken.
  final ConflictAction action;

  /// Whether to also update the server.
  final bool updateServer;

  /// Optional message describing the resolution.
  final String? message;

  const ConflictResolution({
    required this.resolvedRecord,
    required this.action,
    this.updateServer = false,
    this.message,
  });

  /// Create resolution that accepts local version.
  factory ConflictResolution.acceptLocal(T localRecord) {
    return ConflictResolution(
      resolvedRecord: localRecord,
      action: ConflictAction.acceptedLocal,
      updateServer: true,
      message: 'Local changes preserved and pushed to server',
    );
  }

  /// Create resolution that accepts server version.
  factory ConflictResolution.acceptServer(T serverRecord) {
    return ConflictResolution(
      resolvedRecord: serverRecord,
      action: ConflictAction.acceptedServer,
      updateServer: false,
      message: 'Server version accepted, local changes discarded',
    );
  }

  /// Create resolution with merged record.
  factory ConflictResolution.merged(T mergedRecord) {
    return ConflictResolution(
      resolvedRecord: mergedRecord,
      action: ConflictAction.merged,
      updateServer: true,
      message: 'Records merged',
    );
  }

  /// Create resolution that skips the record (deferred for later).
  factory ConflictResolution.skipped(T currentRecord) {
    return ConflictResolution(
      resolvedRecord: currentRecord,
      action: ConflictAction.skipped,
      updateServer: false,
      message: 'Conflict resolution deferred',
    );
  }
}

/// Action taken to resolve a conflict.
enum ConflictAction {
  /// Local version was accepted.
  acceptedLocal,

  /// Server version was accepted.
  acceptedServer,

  /// Records were merged.
  merged,

  /// Resolution was skipped/deferred.
  skipped,

  /// A copy was created.
  copiedForReview,
}

/// Handler for conflict resolution.
///
/// Implement this to provide custom conflict resolution logic.
abstract class ConflictHandler<T> {
  /// Called when a conflict is detected during sync.
  ///
  /// Return a [ConflictResolution] to indicate how to resolve the conflict.
  Future<ConflictResolution<T>> resolveConflict(SyncConflict<T> conflict);

  /// Get the default strategy for this handler.
  SyncConflictStrategy get defaultStrategy;
}

/// Default conflict handler that uses a fixed strategy.
class DefaultConflictHandler<T> implements ConflictHandler<T> {
  @override
  final SyncConflictStrategy defaultStrategy;

  /// Function to merge records (optional, for merge strategy).
  final T Function(T local, T server)? mergeFunction;

  /// Function to get write date from record.
  final DateTime? Function(T record)? getWriteDate;

  const DefaultConflictHandler({
    this.defaultStrategy = SyncConflictStrategy.serverWins,
    this.mergeFunction,
    this.getWriteDate,
  });

  @override
  Future<ConflictResolution<T>> resolveConflict(SyncConflict<T> conflict) async {
    switch (defaultStrategy) {
      case SyncConflictStrategy.serverWins:
        return ConflictResolution.acceptServer(conflict.serverRecord);

      case SyncConflictStrategy.localWins:
        return ConflictResolution.acceptLocal(conflict.localRecord);

      case SyncConflictStrategy.lastWriteWins:
        if (conflict.isLocalNewer) {
          return ConflictResolution.acceptLocal(conflict.localRecord);
        } else {
          return ConflictResolution.acceptServer(conflict.serverRecord);
        }

      case SyncConflictStrategy.merge:
        if (mergeFunction != null) {
          final merged = mergeFunction!(
            conflict.localRecord,
            conflict.serverRecord,
          );
          return ConflictResolution.merged(merged);
        }
        // Fallback to server wins if no merge function
        return ConflictResolution.acceptServer(conflict.serverRecord);

      case SyncConflictStrategy.askUser:
      case SyncConflictStrategy.createCopy:
        // These require user interaction, skip for now
        return ConflictResolution.skipped(conflict.localRecord);
    }
  }
}

/// Mixin that provides conflict detection utilities.
mixin ConflictDetection<T> {
  /// Compare two records and return list of conflicting field names.
  List<String> detectConflictingFields(
    T local,
    T server,
    Map<String, dynamic> Function(T) toMap,
    List<String> fieldsToCompare,
  ) {
    final localMap = toMap(local);
    final serverMap = toMap(server);
    final conflicts = <String>[];

    for (final field in fieldsToCompare) {
      final localValue = localMap[field];
      final serverValue = serverMap[field];

      if (!_areEqual(localValue, serverValue)) {
        conflicts.add(field);
      }
    }

    return conflicts;
  }

  bool _areEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_areEqual(a[i], b[i])) return false;
      }
      return true;
    }

    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_areEqual(a[key], b[key])) return false;
      }
      return true;
    }

    return a == b;
  }
}

/// Statistics about conflicts during sync.
@immutable
class ConflictStats {
  /// Number of conflicts detected.
  final int totalConflicts;

  /// Number resolved by accepting local.
  final int acceptedLocal;

  /// Number resolved by accepting server.
  final int acceptedServer;

  /// Number resolved by merging.
  final int merged;

  /// Number skipped for later resolution.
  final int skipped;

  const ConflictStats({
    this.totalConflicts = 0,
    this.acceptedLocal = 0,
    this.acceptedServer = 0,
    this.merged = 0,
    this.skipped = 0,
  });

  ConflictStats copyWith({
    int? totalConflicts,
    int? acceptedLocal,
    int? acceptedServer,
    int? merged,
    int? skipped,
  }) {
    return ConflictStats(
      totalConflicts: totalConflicts ?? this.totalConflicts,
      acceptedLocal: acceptedLocal ?? this.acceptedLocal,
      acceptedServer: acceptedServer ?? this.acceptedServer,
      merged: merged ?? this.merged,
      skipped: skipped ?? this.skipped,
    );
  }

  /// Add stats from a conflict resolution.
  ConflictStats addResolution(ConflictAction action) {
    return copyWith(
      totalConflicts: totalConflicts + 1,
      acceptedLocal: action == ConflictAction.acceptedLocal
          ? acceptedLocal + 1
          : acceptedLocal,
      acceptedServer: action == ConflictAction.acceptedServer
          ? acceptedServer + 1
          : acceptedServer,
      merged: action == ConflictAction.merged ? merged + 1 : merged,
      skipped: action == ConflictAction.skipped ? skipped + 1 : skipped,
    );
  }

  @override
  String toString() =>
      'ConflictStats(total: $totalConflicts, local: $acceptedLocal, '
      'server: $acceptedServer, merged: $merged, skipped: $skipped)';
}
