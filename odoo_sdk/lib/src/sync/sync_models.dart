/// Shared models and types for sync operations
library;

/// Phases of a sync operation.
enum SyncPhase {
  /// Counting records on server
  counting,
  /// Downloading records from server
  downloading,
  /// Uploading local changes to server
  uploading,
  /// Resolving conflicts
  resolving,
  /// Completed
  completed,
}

/// Progress information for sync operations.
///
/// Provides detailed progress tracking for model sync operations
/// including phase, record count, and current item being processed.
class SyncProgress {
  /// The model being synced (e.g., 'product.product')
  final String? model;

  /// Total records to sync
  final int total;

  /// Records synced so far
  final int synced;

  /// Current sync phase
  final SyncPhase phase;

  /// Current item being processed (name/identifier)
  final String? currentItem;

  /// Error message if any
  final String? error;

  /// Optional percentage override
  final double? percentage;

  const SyncProgress({
    this.model,
    required this.total,
    required this.synced,
    this.phase = SyncPhase.downloading,
    this.currentItem,
    this.error,
    this.percentage,
  });

  /// Progress as 0.0 - 1.0
  double get progress =>
      percentage ?? (total > 0 ? synced / total : 0.0);

  /// Progress as 0 - 100
  double get progressPercent => progress * 100;

  /// Remaining records to sync
  int get remaining => total - synced;

  /// Whether sync is complete
  bool get isComplete => synced >= total && phase == SyncPhase.completed;

  @override
  String toString() =>
      'SyncProgress(${model ?? "?"}: $synced/$total, phase: $phase)';
}

/// Model sync metadata stored per model
class SyncModelInfo {
  final String modelName;
  final DateTime? lastSyncDate;
  final int syncedCount;
  final int localCount;
  final String? errorMessage;
  final bool wasIncremental;

  const SyncModelInfo({
    required this.modelName,
    this.lastSyncDate,
    this.syncedCount = 0,
    this.localCount = 0,
    this.errorMessage,
    this.wasIncremental = false,
  });

  factory SyncModelInfo.fromJson(Map<String, dynamic> json) {
    return SyncModelInfo(
      modelName: json['modelName'] as String? ?? '',
      lastSyncDate: json['lastSyncDate'] != null
          ? DateTime.tryParse(json['lastSyncDate'] as String)
          : null,
      syncedCount: json['syncedCount'] as int? ?? 0,
      localCount: json['localCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
      wasIncremental: json['wasIncremental'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'syncedCount': syncedCount,
        'localCount': localCount,
        'errorMessage': errorMessage,
        'wasIncremental': wasIncremental,
      };

  SyncModelInfo copyWith({
    String? modelName,
    DateTime? lastSyncDate,
    int? syncedCount,
    int? localCount,
    String? errorMessage,
    bool? wasIncremental,
  }) {
    return SyncModelInfo(
      modelName: modelName ?? this.modelName,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      syncedCount: syncedCount ?? this.syncedCount,
      localCount: localCount ?? this.localCount,
      errorMessage: errorMessage ?? this.errorMessage,
      wasIncremental: wasIncremental ?? this.wasIncremental,
    );
  }

  /// Format last sync date in Odoo format (YYYY-MM-DD HH:MM:SS UTC)
  String? get lastSyncDateOdoo {
    if (lastSyncDate == null) return null;
    final utc = lastSyncDate!.toUtc();
    return '${utc.year}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')} '
        '${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:${utc.second.toString().padLeft(2, '0')}';
  }
}

/// Callback type for sync progress updates
typedef SyncProgressCallback = void Function(SyncProgress progress);

/// Exception thrown when sync is cancelled
class SyncCancelledException implements Exception {
  final String message;
  final int syncedCount;
  SyncCancelledException(this.message, {this.syncedCount = 0});
  @override
  String toString() => message;
}

