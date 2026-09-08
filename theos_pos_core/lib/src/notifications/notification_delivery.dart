import 'notification_contracts.dart';

import 'dart:convert';

class NotificationDelivery {
  final String entryId;
  final NotificationScope scope;
  final int revision;
  final NotificationChannel channel;
  final NotificationDeliveryState state;
  final int attempts;
  final DateTime? nextAttemptAt;
  final int? systemId;
  final DateTime? leaseExpiresAt;
  final String? errorKey;

  NotificationDelivery({
    required this.entryId,
    required this.scope,
    required this.revision,
    required this.channel,
    required this.state,
    this.attempts = 0,
    this.nextAttemptAt,
    this.systemId,
    this.leaseExpiresAt,
    this.errorKey,
  }) {
    if (entryId.isEmpty || revision < 0 || attempts < 0) {
      throw ArgumentError('delivery identity and counters must be valid');
    }
  }

  String get dedupeKey =>
      jsonEncode([scope.scopeKey, entryId, revision, channel.name]);
}
