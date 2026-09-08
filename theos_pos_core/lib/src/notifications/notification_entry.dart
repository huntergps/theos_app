import 'notification_contracts.dart';

import 'dart:convert';

class NotificationEntry {
  final String id;
  final NotificationScope scope;
  final String sourceKey;
  final int revision;
  final NotificationKind kind;
  final NotificationSeverity severity;
  final String titleKey;
  final String bodyKey;
  final Map<String, String> args;
  final String? fallbackText;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final DateTime? resolvedAt;
  final NotificationTarget? target;
  final NotificationOrigin origin;
  final DateTime? expiresAt;

  NotificationEntry({
    required this.id,
    required this.scope,
    required this.sourceKey,
    required this.revision,
    required this.kind,
    required this.severity,
    required this.titleKey,
    required this.bodyKey,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    required this.origin,
    Map<String, String> args = const {},
    this.fallbackText,
    this.readAt,
    this.archivedAt,
    this.resolvedAt,
    this.target,
    this.expiresAt,
  }) : args = Map.unmodifiable(args) {
    if (id.isEmpty ||
        sourceKey.isEmpty ||
        titleKey.isEmpty ||
        bodyKey.isEmpty ||
        revision < 0) {
      throw ArgumentError('entry identity and text must be valid');
    }
  }

  String get dedupeKey =>
      jsonEncode([scope.scopeKey, scope.partitionKey, sourceKey]);
  bool sameRevision(NotificationEntry other) =>
      dedupeKey == other.dedupeKey && revision == other.revision;
}
