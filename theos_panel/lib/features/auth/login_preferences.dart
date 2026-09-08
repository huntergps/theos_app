import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/preferences/app_preferences.dart';

/// Non-secret values used to restore the last login form.
///
/// Passwords and API keys deliberately remain outside this store.
final class LoginPreferences {
  const LoginPreferences({
    this.serverUrl = '',
    this.database = '',
    this.login = '',
  });

  final String serverUrl;
  final String database;
  final String login;

  bool get isEmpty => serverUrl.isEmpty && database.isEmpty && login.isEmpty;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'serverUrl': serverUrl,
    'database': database,
    'login': login,
  };

  factory LoginPreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['serverUrl'] is! String ||
        json['database'] is! String ||
        json['login'] is! String) {
      throw const FormatException('Invalid login preferences');
    }
    return LoginPreferences(
      serverUrl: (json['serverUrl'] as String).trim(),
      database: (json['database'] as String).trim(),
      login: (json['login'] as String).trim(),
    );
  }
}

final class LoginPreferencesStore {
  const LoginPreferencesStore(this.preferences);

  final SharedPreferences preferences;

  static const key = 'orbi/login/last-selection/v1';

  LoginPreferences load() {
    final raw = preferences.getString(key);
    if (raw == null) return const LoginPreferences();
    try {
      return LoginPreferences.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return const LoginPreferences();
    }
  }

  Future<void> save(LoginPreferences value) async {
    final saved = await preferences.setString(key, jsonEncode(value.toJson()));
    if (!saved) throw StateError('Login preferences could not be persisted');
  }
}

final loginPreferencesStoreProvider = Provider<LoginPreferencesStore>(
  (ref) => LoginPreferencesStore(ref.watch(sharedPreferencesProvider)),
);
