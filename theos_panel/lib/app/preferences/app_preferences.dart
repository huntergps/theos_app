// Preferences are intentionally non-secret. Credentials remain in runtime's
// secure credential boundary.

import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/auth_controller.dart';

import '../../ui/components/copyable_message.dart';

final class PreferencesScope {
  const PreferencesScope({required this.appId, required this.scopeKey});

  final String appId;
  final String scopeKey;

  @override
  bool operator ==(Object other) =>
      other is PreferencesScope &&
      other.appId == appId &&
      other.scopeKey == scopeKey;

  @override
  int get hashCode => Object.hash(appId, scopeKey);
}

enum PreferenceThemeMode { system, light, dark }

enum PreferenceDensity { standard, compact }

/// Espejo propio de `PaneDisplayMode` de fluent_ui (ver el ejemplo oficial,
/// `example/lib/screens/settings.dart`). Un `enum` propio y no el de Fluent
/// directamente, igual que `PreferenceThemeMode` no es `ThemeMode`: así una
/// preferencia guardada nunca se rompe si Fluent renombra o reordena el suyo.
enum PreferenceNavigationDisplayMode { auto, expanded, compact, minimal, top }

/// Espejo propio de `NavigationIndicators` del ejemplo de fluent_ui, que
/// decide entre `StickyNavigationIndicator` y `EndNavigationIndicator` en
/// `NavigationPane.indicator`.
enum PreferenceNavigationIndicator { sticky, end }

final class AppPreferencesSnapshot {
  const AppPreferencesSnapshot({
    this.themeMode = PreferenceThemeMode.system,
    this.accentSeed = 0xFF007E82,
    this.density = PreferenceDensity.standard,
    this.navigationDisplayMode = PreferenceNavigationDisplayMode.auto,
    this.navigationIndicator = PreferenceNavigationIndicator.sticky,
    this.textScale = 1,
    this.routeMode = false,
    this.syncRetries = 3,
    this.notificationCategories = const {},
    this.messageDurations = const MessageDurations(),
  });

  final PreferenceThemeMode themeMode;
  final int accentSeed;
  final PreferenceDensity density;
  final PreferenceNavigationDisplayMode navigationDisplayMode;
  final PreferenceNavigationIndicator navigationIndicator;
  final double textScale;
  final bool routeMode;
  final int syncRetries;
  final Map<String, bool> notificationCategories;

  /// How long a transient message of each severity stays on screen. See
  /// [MessageDurations] for why an error defaults to "until dismissed".
  final MessageDurations messageDurations;

  AppPreferencesSnapshot copyWith({
    PreferenceThemeMode? themeMode,
    int? accentSeed,
    PreferenceDensity? density,
    PreferenceNavigationDisplayMode? navigationDisplayMode,
    PreferenceNavigationIndicator? navigationIndicator,
    double? textScale,
    bool? routeMode,
    int? syncRetries,
    Map<String, bool>? notificationCategories,
    MessageDurations? messageDurations,
  }) => AppPreferencesSnapshot(
    themeMode: themeMode ?? this.themeMode,
    accentSeed: accentSeed ?? this.accentSeed,
    density: density ?? this.density,
    navigationDisplayMode: navigationDisplayMode ?? this.navigationDisplayMode,
    navigationIndicator: navigationIndicator ?? this.navigationIndicator,
    textScale: _scale(textScale ?? this.textScale),
    routeMode: routeMode ?? this.routeMode,
    syncRetries: _retries(syncRetries ?? this.syncRetries),
    notificationCategories: Map.unmodifiable(
      notificationCategories ?? this.notificationCategories,
    ),
    messageDurations: messageDurations ?? this.messageDurations,
  );

  /// Se llamaba `materialThemeMode` cuando la raíz era Material. `ThemeMode`
  /// no es de Material: lo usan las dos raíces, y el nombre viejo hacía pensar
  /// que había que cambiarlo al migrar a Fluent.
  ThemeMode get appThemeMode => switch (themeMode) {
    PreferenceThemeMode.system => ThemeMode.system,
    PreferenceThemeMode.light => ThemeMode.light,
    PreferenceThemeMode.dark => ThemeMode.dark,
  };

  Map<String, dynamic> toJson() => {
    'version': 1,
    'theme': themeMode.name,
    'accentSeed': accentSeed,
    'density': density.name,
    'navigationDisplayMode': navigationDisplayMode.name,
    'navigationIndicator': navigationIndicator.name,
    'textScale': textScale,
    'routeMode': routeMode,
    'syncRetries': syncRetries,
    'notificationCategories': notificationCategories,
    'messageDurations': messageDurations.toJson(),
  };

  factory AppPreferencesSnapshot.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('unknown preference version');
    }
    final theme = PreferenceThemeMode.values.where(
      (item) => item.name == json['theme'],
    );
    final scale = json['textScale'];
    final categories = json['notificationCategories'];
    final density = PreferenceDensity.values.where(
      (item) => item.name == json['density'],
    );
    if (theme.isEmpty ||
        scale is! num ||
        json['accentSeed'] is! int ||
        density.isEmpty ||
        json['routeMode'] is! bool ||
        json['syncRetries'] is! int ||
        categories is! Map) {
      throw const FormatException('invalid preference payload');
    }
    return AppPreferencesSnapshot(
      themeMode: theme.first,
      accentSeed: json['accentSeed'] as int,
      density: density.first,
      textScale: scale.toDouble(),
      routeMode: json['routeMode'] as bool,
      syncRetries: json['syncRetries'] as int,
      notificationCategories: {
        for (final entry in categories.entries)
          if (entry.key is String && entry.value is bool)
            entry.key as String: entry.value as bool,
      },
      // Read leniently and left out of the strict checks above ON PURPOSE:
      // preferences written before message durations existed carry no such
      // key, and `version` is still 1. Demanding it would make every existing
      // installation throw FormatException and silently lose its theme,
      // accent and text scale on the next start.
      messageDurations: MessageDurations.fromJson(json['messageDurations']),
      // Igual de leniente y por el mismo motivo: preferencias guardadas antes
      // de que existiera este par de campos, o un valor que quedó de un
      // `enum` que luego cambió de nombre, caen al valor por defecto en vez
      // de tirar toda la preferencia guardada por la borda.
      navigationDisplayMode: _navigationDisplayModeFrom(
        json['navigationDisplayMode'],
      ),
      navigationIndicator: _navigationIndicatorFrom(
        json['navigationIndicator'],
      ),
    );
  }

  static PreferenceNavigationDisplayMode _navigationDisplayModeFrom(
    Object? value,
  ) {
    if (value is! String) return PreferenceNavigationDisplayMode.auto;
    final matches = PreferenceNavigationDisplayMode.values.where(
      (item) => item.name == value,
    );
    return matches.isEmpty
        ? PreferenceNavigationDisplayMode.auto
        : matches.first;
  }

  static PreferenceNavigationIndicator _navigationIndicatorFrom(Object? value) {
    if (value is! String) return PreferenceNavigationIndicator.sticky;
    final matches = PreferenceNavigationIndicator.values.where(
      (item) => item.name == value,
    );
    return matches.isEmpty
        ? PreferenceNavigationIndicator.sticky
        : matches.first;
  }

  // Keep the user-selected scale usable for low-vision and magnification
  // workflows; layouts must reflow instead of shrinking text to fit.
  static double _scale(double value) => value.clamp(0.85, 2.0).toDouble();
  static int _retries(int value) => value.clamp(0, 10);
}

final class AppPreferencesStore {
  AppPreferencesStore({required this.preferences, required this.scope});

  final SharedPreferences preferences;
  final PreferencesScope scope;

  String get key =>
      'orbi/preferences/${jsonEncode([scope.appId, scope.scopeKey])}';

  Future<AppPreferencesSnapshot> load() async {
    final raw = preferences.getString(key);
    if (raw == null) {
      // A first-time user inherits only the explicitly chosen login theme.
      // Never copy another user's preferences or override a saved user theme.
      if (scope.scopeKey != 'anonymous') {
        final loginKey =
            'orbi/preferences/${jsonEncode([scope.appId, 'anonymous'])}';
        final loginRaw = preferences.getString(loginKey);
        if (loginRaw != null) {
          try {
            final login = AppPreferencesSnapshot.fromJson(
              jsonDecode(loginRaw) as Map<String, dynamic>,
            );
            return AppPreferencesSnapshot(themeMode: login.themeMode);
          } catch (_) {
            // Corrupt non-secret preferences do not block authentication.
          }
        }
      }
      return const AppPreferencesSnapshot();
    }
    try {
      return AppPreferencesSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppPreferencesSnapshot();
    }
  }

  Future<void> save(AppPreferencesSnapshot snapshot) async {
    if (!await preferences.setString(key, jsonEncode(snapshot.toJson()))) {
      throw StateError('preferences could not be persisted');
    }
  }
}

final class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController(this.store);

  final AppPreferencesStore store;
  AppPreferencesSnapshot _snapshot = const AppPreferencesSnapshot();
  bool _loaded = false;

  AppPreferencesSnapshot get snapshot => _snapshot;
  bool get loaded => _loaded;

  Future<void> load() async {
    _snapshot = await store.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppPreferencesSnapshot next) async {
    await store.save(next);
    _snapshot = next;
    notifyListeners();
  }

  Future<void> setTheme(PreferenceThemeMode mode) =>
      update(_snapshot.copyWith(themeMode: mode));

  Future<void> setTextScale(double scale) =>
      update(_snapshot.copyWith(textScale: scale));

  Future<void> setAccentSeed(int seed) =>
      update(_snapshot.copyWith(accentSeed: seed));

  Future<void> setDensity(PreferenceDensity density) =>
      update(_snapshot.copyWith(density: density));

  Future<void> setNavigationDisplayMode(PreferenceNavigationDisplayMode mode) =>
      update(_snapshot.copyWith(navigationDisplayMode: mode));

  Future<void> setNavigationIndicator(
    PreferenceNavigationIndicator indicator,
  ) => update(_snapshot.copyWith(navigationIndicator: indicator));

  Future<void> setRouteMode(bool enabled) =>
      update(_snapshot.copyWith(routeMode: enabled));

  Future<void> setSyncRetries(int retries) =>
      update(_snapshot.copyWith(syncRetries: retries));

  Future<void> setMessageDurations(MessageDurations durations) =>
      update(_snapshot.copyWith(messageDurations: durations));

  Future<void> setMessageDuration(OrbiMessageSeverity severity, int seconds) =>
      setMessageDurations(
        _snapshot.messageDurations.copyWithSeverity(severity, seconds),
      );

  Future<void> setNotificationCategory(String category, bool enabled) => update(
    _snapshot.copyWith(
      notificationCategories: {
        ..._snapshot.notificationCategories,
        category: enabled,
      },
    ),
  );
}

final appPreferencesProvider =
    Provider.family<AppPreferencesController, PreferencesScope>((ref, scope) {
      final controller = AppPreferencesController(
        AppPreferencesStore(
          preferences: ref.watch(sharedPreferencesProvider),
          scope: scope,
        ),
      );
      controller.load();
      ref.onDispose(controller.dispose);
      return controller;
    });

final preferencesScopeProvider = Provider<PreferencesScope>((ref) {
  final profile = ref.watch(authControllerProvider).profile;
  return PreferencesScope(
    appId: 'theos_panel',
    scopeKey: profile == null
        ? 'anonymous'
        : '${profile.serverUrl}|${profile.database}|${profile.userId}',
  );
});

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider'),
);

/// This is called only from a user gesture; startup never requests permission.
final class NotificationPermissionAction {
  NotificationPermissionAction(this.presenter);

  final SystemNotificationPresenter presenter;

  Future<PermissionState> requestFromUserGesture() =>
      presenter.requestPermissionFromUserAction();
}
