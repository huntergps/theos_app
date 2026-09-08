import 'dart:convert';

enum NotificationKind { activity, approval, sync, system }

enum NotificationSeverity { info, attention, error }

enum NotificationOrigin { local, poll, futurePush }

enum NotificationChannel { system }

enum NotificationDeliveryState {
  pending,
  claimed,
  shown,
  denied,
  unsupported,
  failed,
  cancelled,
}

enum NotificationCapability { show, schedule, actions, cancel, launchHandling }

enum NotificationPermission { supported, unsupported, denied, granted }

class NotificationScope {
  final String scopeKey;
  final String partitionKey;
  final int? companyId;

  const NotificationScope._({
    required this.scopeKey,
    required this.partitionKey,
    this.companyId,
  });

  factory NotificationScope({
    required String scopeKey,
    required String partitionKey,
    int? companyId,
  }) {
    if (scopeKey.isEmpty) throw ArgumentError.value(scopeKey, 'scopeKey');
    if (partitionKey != 'global' && !partitionKey.startsWith('company:')) {
      throw ArgumentError.value(partitionKey, 'partitionKey');
    }
    if (partitionKey == 'global' && companyId != null) {
      throw ArgumentError.value(companyId, 'companyId');
    }
    if (partitionKey.startsWith('company:')) {
      final parsed = int.tryParse(partitionKey.substring('company:'.length));
      if (parsed == null || parsed <= 0 || companyId != parsed) {
        throw ArgumentError('company partition and companyId must match');
      }
    } else if (companyId != null) {
      throw ArgumentError.value(companyId, 'companyId');
    }
    return NotificationScope._(
      scopeKey: scopeKey,
      partitionKey: partitionKey,
      companyId: companyId,
    );
  }

  bool get isGlobal => partitionKey == 'global';
}

class NotificationTarget {
  final String type;
  final String reference;

  const NotificationTarget._({required this.type, required this.reference});

  factory NotificationTarget({
    required String type,
    required String reference,
  }) {
    if (type.isEmpty || reference.isEmpty)
      throw ArgumentError('target fields must be non-empty');
    return NotificationTarget._(type: type, reference: reference);
  }
}

class NotificationPreferences {
  final bool systemEnabled;
  final Set<NotificationKind> mutedKinds;

  NotificationPreferences({
    this.systemEnabled = true,
    Set<NotificationKind> mutedKinds = const {},
  }) : mutedKinds = Set.unmodifiable(mutedKinds);
  bool allows(NotificationKind kind) =>
      systemEnabled && !mutedKinds.contains(kind);
}

class NotificationCapabilities {
  final Set<NotificationCapability> supported;
  final NotificationPermission permission;

  NotificationCapabilities({
    Set<NotificationCapability> supported = const {},
    this.permission = NotificationPermission.supported,
  }) : supported = Set.unmodifiable(supported);
  bool supports(NotificationCapability capability) =>
      supported.contains(capability);
}

class NotificationEvent {
  final NotificationScope scope;
  final String sourceKey;
  final int revision;
  final NotificationKind kind;
  final NotificationSeverity severity;
  final String titleKey;
  final String bodyKey;
  final NotificationTarget? target;
  final DateTime occurredAt;

  const NotificationEvent._({
    required this.scope,
    required this.sourceKey,
    required this.revision,
    required this.kind,
    required this.severity,
    required this.titleKey,
    required this.bodyKey,
    required this.occurredAt,
    this.target,
  });

  factory NotificationEvent({
    required NotificationScope scope,
    required String sourceKey,
    required int revision,
    required NotificationKind kind,
    required NotificationSeverity severity,
    required String titleKey,
    required String bodyKey,
    required DateTime occurredAt,
    NotificationTarget? target,
  }) {
    if (sourceKey.isEmpty ||
        titleKey.isEmpty ||
        bodyKey.isEmpty ||
        revision < 0) {
      throw ArgumentError('event identity and text must be valid');
    }
    return NotificationEvent._(
      scope: scope,
      sourceKey: sourceKey,
      revision: revision,
      kind: kind,
      severity: severity,
      titleKey: titleKey,
      bodyKey: bodyKey,
      occurredAt: occurredAt,
      target: target,
    );
  }

  String get dedupeKey =>
      jsonEncode([scope.scopeKey, scope.partitionKey, sourceKey]);
}
