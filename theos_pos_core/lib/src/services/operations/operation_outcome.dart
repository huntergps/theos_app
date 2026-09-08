class CapabilitySnapshot {
  final String scopeKey;
  final int companyId;
  final int? pointId;
  final int revision;
  final DateTime fetchedAt;
  final Set<String> permissions;
  final Set<String> counterPolicies;
  final Set<String> offlineOperations;

  CapabilitySnapshot({
    required String scopeKey,
    required int companyId,
    required int revision,
    required DateTime fetchedAt,
    this.pointId,
    Iterable<String> permissions = const [],
    Iterable<String> counterPolicies = const [],
    Iterable<String> offlineOperations = const [],
  }) : scopeKey = _nonEmpty(scopeKey, 'scopeKey'),
       companyId = _positive(companyId, 'companyId'),
       revision = _nonNegative(revision, 'revision'),
       fetchedAt = fetchedAt.toUtc(),
       permissions = Set.unmodifiable(permissions),
       counterPolicies = Set.unmodifiable(counterPolicies),
       offlineOperations = Set.unmodifiable(offlineOperations) {
    if (pointId != null) _positive(pointId!, 'pointId');
  }
}

/// State of the local/remote transport for a business operation.
enum OperationSyncState { localOnly, queued, sending, synced, conflict, failed }

/// Fiscal lifecycle is deliberately independent from transport synchronization.
enum FiscalState { emittedLocal, submitted, authorized, rejected }

enum PendingActionType { approval, sync, fiscalSubmission, conflictResolution }

class EntityReference {
  final String localId;
  final int? remoteId;

  EntityReference({required String localId, int? remoteId})
    : localId = _nonEmpty(localId, 'localId'),
      remoteId = remoteId {
    if (remoteId != null) _positive(remoteId, 'remoteId');
  }
}

class PendingAction {
  final PendingActionType type;
  final EntityReference entity;
  final Map<String, String> context;

  PendingAction({
    required this.type,
    required this.entity,
    Map<String, String> context = const {},
  }) : context = Map.unmodifiable(context);
}

class OperationIssue {
  final String code;
  final String messageKey;
  final Map<String, String> args;
  final String? field;
  final bool retryable;

  OperationIssue({
    required String code,
    required String messageKey,
    Map<String, String> args = const {},
    this.field,
    this.retryable = false,
  }) : code = _nonEmpty(code, 'code'),
       messageKey = _nonEmpty(messageKey, 'messageKey'),
       args = Map.unmodifiable(args);
}

/// Outcome contract shared by UI and runtime; it is not an Odoo response.
class OperationOutcome<TBusinessState extends Enum> {
  final String commandId;
  final EntityReference entity;
  final TBusinessState businessState;
  final OperationSyncState syncState;
  final FiscalState? fiscalState;
  final PendingAction? pendingAction;
  final List<OperationIssue> issues;

  OperationOutcome({
    required String commandId,
    required this.entity,
    required this.businessState,
    required this.syncState,
    this.fiscalState,
    this.pendingAction,
    Iterable<OperationIssue> issues = const [],
  }) : commandId = _nonEmpty(commandId, 'commandId'),
       issues = List.unmodifiable(issues);

  bool get hasIssues => issues.isNotEmpty;
}

String _nonEmpty(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty)
    throw ArgumentError.value(value, name, 'Must not be empty');
  return trimmed;
}

int _positive(int value, String name) {
  if (value <= 0) throw ArgumentError.value(value, name, 'Must be positive');
  return value;
}

int _nonNegative(int value, String name) {
  if (value < 0) throw ArgumentError.value(value, name, 'Must not be negative');
  return value;
}
