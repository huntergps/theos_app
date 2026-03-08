import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_counter.freezed.dart';

/// Mail notification counters from Odoo 19.0 init_messaging
@freezed
abstract class NotificationCounter with _$NotificationCounter {
  const factory NotificationCounter({
    @Default(0) int inboxCounter,
    @Default(0) int starredCounter,
    @Default(0) int channelsUnreadCounter,
    @Default(0) int activityCounter,
  }) = _NotificationCounter;

  /// Parse from Odoo's init_messaging response
  factory NotificationCounter.fromOdoo(Map<String, dynamic> data) {
    return NotificationCounter(
      inboxCounter: _parseCounter(data['inbox']),
      starredCounter: _parseCounter(data['starred']),
      channelsUnreadCounter: data['initChannelsUnreadCounter'] as int? ?? 0,
      activityCounter: data['activityCounter'] as int? ?? 0,
    );
  }

  static int _parseCounter(dynamic value) {
    if (value == null || value == false) return 0;
    if (value is int) return value;
    if (value is Map && value.containsKey('counter')) {
      return value['counter'] as int? ?? 0;
    }
    return 0;
  }
}
