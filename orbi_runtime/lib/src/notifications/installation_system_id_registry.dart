import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show NotificationChannel, NotificationSystemIdAllocator;

import 'system_notification_presenter.dart';

/// Installation-wide, non-secret registry for plugin notification IDs.
///
/// The complete state is one JSON value. Mutations are serialized in-process
/// and the value is written before an allocated ID is returned.
final class NotificationSystemIdRegistry
    implements NotificationSystemIdAllocator, SystemIdPort {
  NotificationSystemIdRegistry({
    required this.preferences,
    required String appId,
    required String installationId,
  }) : _storageKey = _storageKeyFor(appId, installationId);

  static const _version = 1;
  static const _firstId = 1;
  static const _maxPluginId = 0x7fffffff;

  final SharedPreferences preferences;
  final String _storageKey;
  static final _queues = <String, Future<void>>{};

  @override
  Future<int> allocate({
    required String scopeKey,
    required String entryId,
    required String channel,
  }) => _serialized(() async {
    final state = _read();
    final key = _mappingKey(scopeKey, entryId, channel);
    final existing = state.mappings[key];
    if (existing != null) return existing;
    final next = state.nextId;
    if (next > _maxPluginId) {
      throw StateError('notification system ID space exhausted');
    }
    final updated = _RegistryState(
      nextId: next + 1,
      mappings: {...state.mappings, key: next},
    );
    await _write(updated);
    return next;
  });

  @override
  Future<int?> lookup({
    required String scopeKey,
    required String entryId,
    required NotificationChannel channel,
  }) => _serialized(() {
    final state = _read(allowMissing: true);
    return state.mappings[_mappingKey(scopeKey, entryId, channel.name)];
  });

  Future<T> _serialized<T>(FutureOr<T> Function() operation) {
    final result = Completer<T>();
    final previous = _queues[_storageKey] ?? Future<void>.value();
    late final Future<void> next;
    next = previous.then<void>((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    }, onError: (Object error, StackTrace stackTrace) {});
    _queues[_storageKey] = next;
    next.whenComplete(() {
      if (identical(_queues[_storageKey], next)) {
        _queues.remove(_storageKey);
      }
    });
    return result.future;
  }

  _RegistryState _read({bool allowMissing = false}) {
    final raw = preferences.getString(_storageKey);
    if (raw == null) {
      if (allowMissing) return const _RegistryState.empty();
      return const _RegistryState.empty();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != _version ||
          decoded['nextId'] is! int ||
          decoded['mappings'] is! Map<String, dynamic>) {
        throw const FormatException('invalid registry shape');
      }
      final nextId = decoded['nextId'] as int;
      final rawMappings = decoded['mappings'] as Map<String, dynamic>;
      if (nextId < _firstId || nextId > _maxPluginId + 1) {
        throw const FormatException('invalid next ID');
      }
      final mappings = <String, int>{};
      for (final entry in rawMappings.entries) {
        if (entry.value is! int ||
            (entry.value as int) < _firstId ||
            (entry.value as int) > _maxPluginId ||
            mappings.containsValue(entry.value)) {
          throw const FormatException('invalid or duplicate ID');
        }
        mappings[entry.key] = entry.value as int;
      }
      if (mappings.values.any((id) => id >= nextId)) {
        throw const FormatException('next ID overlaps mapping');
      }
      return _RegistryState(nextId: nextId, mappings: mappings);
    } catch (error) {
      throw StateError('notification system ID registry is corrupt: $error');
    }
  }

  Future<void> _write(_RegistryState state) async {
    final encoded = jsonEncode({
      'version': _version,
      'nextId': state.nextId,
      'mappings': state.mappings,
    });
    if (!await preferences.setString(_storageKey, encoded)) {
      throw StateError('notification system ID registry could not persist');
    }
  }

  static String _storageKeyFor(String appId, String installationId) {
    _validate(appId, 'appId');
    _validate(installationId, 'installationId');
    return 'orbi/notifications/system_ids/${jsonEncode([appId, installationId])}';
  }

  static String _mappingKey(String scopeKey, String entryId, String channel) {
    _validate(scopeKey, 'scopeKey');
    _validate(entryId, 'entryId');
    _validate(channel, 'channel');
    return jsonEncode([scopeKey, entryId, channel]);
  }

  static void _validate(String value, String name) {
    if (value.trim().isEmpty) throw ArgumentError.value(value, name);
  }
}

final class _RegistryState {
  const _RegistryState({required this.nextId, required this.mappings});
  const _RegistryState.empty() : nextId = 1, mappings = const {};

  final int nextId;
  final Map<String, int> mappings;
}
