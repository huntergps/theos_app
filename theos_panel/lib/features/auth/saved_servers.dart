import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/preferences/app_preferences.dart';

/// Non-secret connection metadata used to restore a server choice at login.
///
/// Credentials are intentionally not part of this model or its persisted form.
final class SavedServer {
  SavedServer({
    required this.id,
    required String name,
    required String url,
    required String database,
  }) : name = _requiredText(name, 'name'),
       url = SavedServersStore.normalizeUrl(url),
       database = _requiredText(database, 'database') {
    if (id.trim().isEmpty) {
      throw const FormatException('El ID del servidor no puede estar vacío');
    }
  }

  final String id;
  final String name;
  final String url;
  final String database;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'database': database,
  };

  static String _requiredText(String value, String field) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw FormatException('El campo $field no puede estar vacío');
    }
    return trimmed;
  }
}

final class SavedServersStore {
  SavedServersStore(this.preferences);

  static const key = 'orbi/login/servers/v1';

  final SharedPreferences preferences;
  Future<void> _mutationTail = Future<void>.value();

  List<SavedServer> load() {
    final raw = preferences.getString(key);
    if (raw == null) return <SavedServer>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          decoded['servers'] is! List) {
        throw const FormatException('Invalid saved servers payload');
      }
      final servers = <SavedServer>[];
      for (final item in decoded['servers'] as List) {
        if (item is! Map) {
          throw const FormatException('Invalid saved server entry');
        }
        final map = item.cast<String, dynamic>();
        if (map['id'] is! String ||
            map['name'] is! String ||
            map['url'] is! String ||
            map['database'] is! String) {
          throw const FormatException('Invalid saved server entry');
        }
        servers.add(
          SavedServer(
            id: map['id'] as String,
            name: map['name'] as String,
            url: map['url'] as String,
            database: map['database'] as String,
          ),
        );
      }
      _ensureNoDuplicates(servers);
      return List<SavedServer>.unmodifiable(servers);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid saved servers payload: $error');
    }
  }

  Future<void> upsert(SavedServer server) => _enqueue(() async {
    final servers = load().toList();
    final index = servers.indexWhere((item) => item.id == server.id);
    final duplicate = servers.indexWhere(
      (item) =>
          item.id != server.id &&
          item.url == server.url &&
          item.database == server.database,
    );
    if (duplicate != -1) {
      throw const FormatException(
        'Ya existe un servidor guardado con esta URL y base de datos',
      );
    }
    if (index == -1) {
      servers.add(server);
    } else {
      servers[index] = server;
    }
    await _persist(servers);
  });

  Future<void> remove(String id) => _enqueue(() async {
    final servers = load().where((server) => server.id != id).toList();
    await _persist(servers);
  });

  static String? validateUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'La URL no puede estar vacía';
    try {
      final uri = Uri.parse(trimmed);
      if (!uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return 'La URL debe ser absoluta y usar HTTP o HTTPS';
      }
      final decodedHost = Uri.decodeComponent(uri.host);
      final hasWhitespace = decodedHost.runes.any(
        (rune) => rune <= 32 || rune == 127,
      );
      final hasInvalidPort =
          uri.port > 65535 ||
          (uri.port == 0 && RegExp(r':0(?:/|$)').hasMatch(uri.authority));
      if (uri.host.isEmpty ||
          hasWhitespace ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          hasInvalidPort) {
        return 'La URL debe tener un host válido, sin credenciales, consulta ni fragmento';
      }
      return null;
    } catch (_) {
      return 'La URL no es válida';
    }
  }

  static String normalizeUrl(String value) {
    final error = validateUrl(value);
    if (error != null) throw FormatException(error);
    final uri = Uri.parse(value.trim());
    var path = uri.path;
    while (path.isNotEmpty && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          path: path,
        )
        .toString();
  }

  Future<void> _persist(List<SavedServer> servers) async {
    final ok = await preferences.setString(
      key,
      jsonEncode({
        'version': 1,
        'servers': servers.map((server) => server.toJson()).toList(),
      }),
    );
    if (!ok) throw StateError('Saved servers could not be persisted');
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _mutationTail.then((_) => action());
    _mutationTail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  static void _ensureNoDuplicates(List<SavedServer> servers) {
    final keys = <String>{};
    final ids = <String>{};
    for (final server in servers) {
      if (!ids.add(server.id)) {
        throw const FormatException(
          'Hay servidores guardados con IDs duplicados',
        );
      }
      final identity = '${server.url}\u0000${server.database}';
      if (!keys.add(identity)) {
        throw const FormatException('Hay servidores guardados duplicados');
      }
    }
  }
}

final savedServersStoreProvider = Provider<SavedServersStore>(
  (ref) => SavedServersStore(ref.watch(sharedPreferencesProvider)),
);
