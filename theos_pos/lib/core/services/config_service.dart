import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:uuid/uuid.dart';
import '../../shared/models/app_config_model.dart';
import '../../shared/models/config_profile.dart';

part 'config_service.g.dart';

@Riverpod(keepAlive: true)
class ConfigService extends _$ConfigService {
  @override
  AppConfigModel build() {
    _loadConfig();
    return AppConfigModel.defaultConfig();
  }

  static const _keyThemeMode = 'theme_mode';
  static const _keyAccentColor = 'accent_color';
  static const _keyWindowEffect = 'window_effect';
  static const _keyDisplayFactor = 'display_factor';
  static const _keyTitleLargeFactor = 'title_large_factor';
  static const _keyTitleFactor = 'title_factor';
  static const _keyBodyLargeFactor = 'body_large_factor';
  static const _keyBodyStrongFactor = 'body_strong_factor';
  static const _keyBodyFactor = 'body_factor';
  static const _keyCaptionFactor = 'caption_factor';
  static const _keyDisplayMode = 'display_mode';
  static const _keySpacingFactor = 'spacing_factor';
  static const _keyWindowWidth = 'window_width';
  static const _keyWindowHeight = 'window_height';
  static const _keyWindowX = 'window_x';
  static const _keyWindowY = 'window_y';
  static const _keyIsMaximized = 'window_is_maximized';
  static const _keyProfiles = 'config_profiles';
  static const _keyActiveProfileId = 'active_profile_id';
  static const _keyMaxSyncRetries = 'max_sync_retries';
  static const _keyErrorNotificationDuration = 'error_notification_duration';
  static const _keySuccessNotificationDuration =
      'success_notification_duration';
  static const _keyWarningNotificationDuration =
      'warning_notification_duration';
  static const _keyInfoNotificationDuration = 'info_notification_duration';
  static const _keyDateFormat = 'date_format';

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeString = prefs.getString(_keyThemeMode);
    final themeMode = ThemeMode.values.firstWhere(
      (e) => e.toString() == themeModeString,
      orElse: () => ThemeMode.system,
    );

    final accentColorValue = prefs.getInt(_keyAccentColor);
    AccentColor accentColor = Colors.blue;
    if (accentColorValue != null) {
      for (final color in Colors.accentColors) {
        if (color.toARGB32() == accentColorValue) {
          accentColor = color;
          break;
        }
      }
    }

    final windowEffectString = prefs.getString(_keyWindowEffect);
    final windowEffect = WindowEffect.values.firstWhere(
      (e) => e.toString() == windowEffectString,
      orElse: () => WindowEffect.disabled,
    );

    final displayModeString = prefs.getString(_keyDisplayMode);
    final displayMode = PaneDisplayMode.values.firstWhere(
      (e) => e.toString() == displayModeString,
      orElse: () => PaneDisplayMode.compact,
    );

    // Load Profiles
    List<ConfigProfile> profiles = [];
    final profilesJson = prefs.getStringList(_keyProfiles);
    if (profilesJson != null) {
      profiles = profilesJson
          .map((e) => ConfigProfile.fromJson(jsonDecode(e)))
          .toList();
    } else {
      // Create default profiles if none exist
      profiles = _createDefaultProfiles();
      _saveProfiles(profiles); // Save defaults immediately
    }

    String? activeProfileId = prefs.getString(_keyActiveProfileId);

    // Validate that the active profile actually exists
    if (activeProfileId != null) {
      final profileExists = profiles.any((p) => p.id == activeProfileId);
      if (!profileExists) {
        activeProfileId = null;
        await prefs.remove(_keyActiveProfileId);
      }
    }

    state = AppConfigModel(
      themeMode: themeMode,
      accentColor: accentColor,
      windowEffect: windowEffect,
      displayFactor: prefs.getDouble(_keyDisplayFactor) ?? 1.0,
      titleLargeFactor: prefs.getDouble(_keyTitleLargeFactor) ?? 1.0,
      titleFactor: prefs.getDouble(_keyTitleFactor) ?? 1.0,
      bodyLargeFactor: prefs.getDouble(_keyBodyLargeFactor) ?? 1.0,
      bodyStrongFactor: prefs.getDouble(_keyBodyStrongFactor) ?? 1.0,
      bodyFactor: prefs.getDouble(_keyBodyFactor) ?? 1.0,
      captionFactor: prefs.getDouble(_keyCaptionFactor) ?? 1.0,
      displayMode: displayMode,
      spacingFactor: prefs.getDouble(_keySpacingFactor) ?? 1.0,
      windowWidth: prefs.getDouble(_keyWindowWidth),
      windowHeight: prefs.getDouble(_keyWindowHeight),
      windowX: prefs.getDouble(_keyWindowX),
      windowY: prefs.getDouble(_keyWindowY),
      isMaximized: prefs.getBool(_keyIsMaximized) ?? false,
      profiles: profiles,
      activeProfileId: activeProfileId,
      maxSyncRetries: prefs.getInt(_keyMaxSyncRetries) ?? 3,
      errorNotificationDuration:
          prefs.getInt(_keyErrorNotificationDuration) ?? 10,
      successNotificationDuration:
          prefs.getInt(_keySuccessNotificationDuration) ?? 3,
      warningNotificationDuration:
          prefs.getInt(_keyWarningNotificationDuration) ?? 5,
      infoNotificationDuration: prefs.getInt(_keyInfoNotificationDuration) ?? 3,
      dateFormat: prefs.getString(_keyDateFormat) ?? 'dd/MM/yyyy',
    );
  }

  List<ConfigProfile> _createDefaultProfiles() {
    return [
      ConfigProfile(
        id: 'phone',
        name: 'Teléfono',
        themeMode: ThemeMode.system,
        accentColor: Colors.blue,
        windowEffect: WindowEffect.disabled,
        displayFactor: 0.8,
        titleLargeFactor: 0.9,
        titleFactor: 0.9,
        bodyLargeFactor: 1.0,
        bodyStrongFactor: 1.0,
        bodyFactor: 1.0,
        captionFactor: 1.0,
        displayMode: PaneDisplayMode.auto,
        spacingFactor: 0.8,
        isDefault: true,
      ),
      ConfigProfile(
        id: 'tablet',
        name: 'Tablet / iPad',
        themeMode: ThemeMode.system,
        accentColor: Colors.teal,
        windowEffect: WindowEffect.disabled,
        displayFactor: 1.0,
        titleLargeFactor: 1.0,
        titleFactor: 1.0,
        bodyLargeFactor: 1.1,
        bodyStrongFactor: 1.1,
        bodyFactor: 1.1,
        captionFactor: 1.1,
        displayMode: PaneDisplayMode.compact,
        spacingFactor: 1.0,
        isDefault: true,
      ),
      ConfigProfile(
        id: 'desktop',
        name: 'Escritorio',
        themeMode: ThemeMode.dark,
        accentColor: Colors.orange,
        windowEffect: WindowEffect.mica,
        displayFactor: 1.2,
        titleLargeFactor: 1.2,
        titleFactor: 1.2,
        bodyLargeFactor: 1.2,
        bodyStrongFactor: 1.2,
        bodyFactor: 1.2,
        captionFactor: 1.2,
        displayMode: PaneDisplayMode.compact,
        spacingFactor: 1.2,
        isDefault: true,
      ),
      ConfigProfile(
        id: 'web',
        name: 'Web',
        themeMode: ThemeMode.light,
        accentColor: Colors.purple,
        windowEffect: WindowEffect.disabled,
        displayFactor: 1.0,
        titleLargeFactor: 1.0,
        titleFactor: 1.0,
        bodyLargeFactor: 1.0,
        bodyStrongFactor: 1.0,
        bodyFactor: 1.0,
        captionFactor: 1.0,
        displayMode: PaneDisplayMode.compact,
        spacingFactor: 1.0,
        isDefault: true,
      ),
    ];
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, state.themeMode.toString());
    await prefs.setInt(_keyAccentColor, state.accentColor.toARGB32());
    await prefs.setString(_keyWindowEffect, state.windowEffect.toString());
    await prefs.setDouble(_keyDisplayFactor, state.displayFactor);
    await prefs.setDouble(_keyTitleLargeFactor, state.titleLargeFactor);
    await prefs.setDouble(_keyTitleFactor, state.titleFactor);
    await prefs.setDouble(_keyBodyLargeFactor, state.bodyLargeFactor);
    await prefs.setDouble(_keyBodyStrongFactor, state.bodyStrongFactor);
    await prefs.setDouble(_keyBodyFactor, state.bodyFactor);
    await prefs.setDouble(_keyCaptionFactor, state.captionFactor);
    await prefs.setString(_keyDisplayMode, state.displayMode.toString());
    await prefs.setDouble(_keySpacingFactor, state.spacingFactor);
    await prefs.setInt(_keyMaxSyncRetries, state.maxSyncRetries);
    await prefs.setInt(
      _keyErrorNotificationDuration,
      state.errorNotificationDuration,
    );
    await prefs.setInt(
      _keySuccessNotificationDuration,
      state.successNotificationDuration,
    );
    await prefs.setInt(
      _keyWarningNotificationDuration,
      state.warningNotificationDuration,
    );
    await prefs.setInt(
      _keyInfoNotificationDuration,
      state.infoNotificationDuration,
    );
    await prefs.setString(_keyDateFormat, state.dateFormat);

    if (state.windowWidth != null) {
      await prefs.setDouble(_keyWindowWidth, state.windowWidth!);
    }
    if (state.windowHeight != null) {
      await prefs.setDouble(_keyWindowHeight, state.windowHeight!);
    }
    if (state.windowX != null) {
      await prefs.setDouble(_keyWindowX, state.windowX!);
    }
    if (state.windowY != null) {
      await prefs.setDouble(_keyWindowY, state.windowY!);
    }
    await prefs.setBool(_keyIsMaximized, state.isMaximized);
    if (state.activeProfileId != null) {
      await prefs.setString(_keyActiveProfileId, state.activeProfileId!);
    } else {
      await prefs.remove(_keyActiveProfileId);
    }

    // Also save profiles whenever config is saved, just in case
    await _saveProfiles(state.profiles);
  }

  Future<void> _saveProfiles(List<ConfigProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = profiles.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyProfiles, profilesJson);
  }

  // --- Profile Management ---

  void createProfile(String name) {
    final newId = const Uuid().v4();
    final newProfile = ConfigProfile(
      id: newId,
      name: name,
      themeMode: state.themeMode,
      accentColor: state.accentColor,
      windowEffect: state.windowEffect,
      displayFactor: state.displayFactor,
      titleLargeFactor: state.titleLargeFactor,
      titleFactor: state.titleFactor,
      bodyLargeFactor: state.bodyLargeFactor,
      bodyStrongFactor: state.bodyStrongFactor,
      bodyFactor: state.bodyFactor,
      captionFactor: state.captionFactor,
      displayMode: state.displayMode,
      spacingFactor: state.spacingFactor,
      isDefault: false,
    );

    final updatedProfiles = [...state.profiles, newProfile];
    state = state.copyWith(
      profiles: updatedProfiles,
      activeProfileId: newId, // Automatically switch to new profile
    );
    _saveProfiles(updatedProfiles);
    _saveConfig(); // Save active ID
  }

  void updateProfile(ConfigProfile profile) {
    final updatedProfiles = state.profiles
        .map((p) => p.id == profile.id ? profile : p)
        .toList();
    state = state.copyWith(profiles: updatedProfiles);
    _saveProfiles(updatedProfiles);
  }

  void deleteProfile(String id) {
    final updatedProfiles = state.profiles.where((p) => p.id != id).toList();

    // If deleting active profile, unset active ID
    String? newActiveId = state.activeProfileId;
    if (state.activeProfileId == id) {
      newActiveId = null;
    }

    state = state.copyWith(
      profiles: updatedProfiles,
      activeProfileId: newActiveId,
    );
    _saveProfiles(updatedProfiles);
    _saveConfig();
  }

  void applyProfile(ConfigProfile profile) {
    state = state.copyWith(
      themeMode: profile.themeMode,
      accentColor: profile.accentColor,
      windowEffect: profile.windowEffect,
      displayFactor: profile.displayFactor,
      titleLargeFactor: profile.titleLargeFactor,
      titleFactor: profile.titleFactor,
      bodyLargeFactor: profile.bodyLargeFactor,
      bodyStrongFactor: profile.bodyStrongFactor,
      bodyFactor: profile.bodyFactor,
      captionFactor: profile.captionFactor,
      displayMode: profile.displayMode,
      spacingFactor: profile.spacingFactor,
      activeProfileId: profile.id,
    );
    _saveConfig();
  }

  void resetCurrentProfile() {
    if (state.activeProfileId == null) return;

    final activeId = state.activeProfileId!;
    final profile = state.profiles.firstWhere((p) => p.id == activeId);

    ConfigProfile? defaultProfile;

    if (profile.isDefault) {
      // If it's a default profile, reset to factory defaults
      final defaults = _createDefaultProfiles();
      try {
        defaultProfile = defaults.firstWhere((p) => p.id == activeId);
      } catch (_) {
        // Should not happen for default profiles
      }
    }

    // If we found a default to reset to (or if we want to reset custom profiles to some baseline,
    // but for now let's only reset default profiles to their factory state.
    // For custom profiles, maybe we just don't do anything or reset to "Phone" defaults?
    // The user requirement implies resetting to "default values".
    // If I modify a custom profile, "reset" might be ambiguous.
    // Let's assume "Reset" means "Reset to factory defaults" if it's a factory profile.
    // If it's a custom profile, maybe we can't reset it easily without a "baseline".
    // Let's implement it for default profiles first.

    if (defaultProfile != null) {
      // Apply default values
      applyProfile(defaultProfile);
      // Also update the profile in the list (applyProfile only updates state, not the list item if it changed)
      updateProfile(defaultProfile);
    }
  }

  void resetTypography() {
    state = state.copyWith(
      displayFactor: 1.0,
      titleLargeFactor: 1.0,
      titleFactor: 1.0,
      bodyLargeFactor: 1.0,
      bodyStrongFactor: 1.0,
      bodyFactor: 1.0,
      captionFactor: 1.0,
    );
    _saveConfig();
    _updateActiveProfile();
  }

  void resetSpacing() {
    state = state.copyWith(spacingFactor: 1.0);
    _saveConfig();
    _updateActiveProfile();
  }

  // --- Helper to update active profile ---
  void _updateActiveProfile() {
    if (state.activeProfileId != null) {
      final index = state.profiles.indexWhere(
        (p) => p.id == state.activeProfileId,
      );
      if (index != -1) {
        final updatedProfile = state.profiles[index].copyWith(
          themeMode: state.themeMode,
          accentColor: state.accentColor,
          windowEffect: state.windowEffect,
          displayFactor: state.displayFactor,
          titleLargeFactor: state.titleLargeFactor,
          titleFactor: state.titleFactor,
          bodyLargeFactor: state.bodyLargeFactor,
          bodyStrongFactor: state.bodyStrongFactor,
          bodyFactor: state.bodyFactor,
          captionFactor: state.captionFactor,
          displayMode: state.displayMode,
          spacingFactor: state.spacingFactor,
        );

        final updatedProfiles = List<ConfigProfile>.from(state.profiles);
        updatedProfiles[index] = updatedProfile;

        state = state.copyWith(profiles: updatedProfiles);
        _saveProfiles(updatedProfiles);
      }
    }
  }

  // --- Individual Setters ---

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveConfig();
    _updateActiveProfile();
  }

  void setAccentColor(AccentColor color) {
    state = state.copyWith(accentColor: color);
    _saveConfig();
    _updateActiveProfile();
  }

  void setWindowEffect(WindowEffect effect) {
    state = state.copyWith(windowEffect: effect);
    _saveConfig();
    _updateActiveProfile();
  }

  void setDisplayFactor(double factor) {
    state = state.copyWith(displayFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setTitleLargeFactor(double factor) {
    state = state.copyWith(titleLargeFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setTitleFactor(double factor) {
    state = state.copyWith(titleFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setBodyLargeFactor(double factor) {
    state = state.copyWith(bodyLargeFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setBodyStrongFactor(double factor) {
    state = state.copyWith(bodyStrongFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setBodyFactor(double factor) {
    state = state.copyWith(bodyFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setCaptionFactor(double factor) {
    state = state.copyWith(captionFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setDisplayMode(PaneDisplayMode mode) {
    state = state.copyWith(displayMode: mode);
    _saveConfig();
    _updateActiveProfile();
  }

  void setSpacingFactor(double factor) {
    state = state.copyWith(spacingFactor: factor);
    _saveConfig();
    _updateActiveProfile();
  }

  void setMaxSyncRetries(int retries) {
    if (retries < 1) return; // Mínimo 1 reintento
    if (retries > 10) return; // Máximo 10 reintentos
    state = state.copyWith(maxSyncRetries: retries);
    _saveConfig();
  }

  void setErrorNotificationDuration(int seconds) {
    if (seconds < 1) return; // Mínimo 1 segundo
    if (seconds > 60) return; // Máximo 60 segundos
    state = state.copyWith(errorNotificationDuration: seconds);
    _saveConfig();
  }

  void setSuccessNotificationDuration(int seconds) {
    if (seconds < 1) return;
    if (seconds > 30) return;
    state = state.copyWith(successNotificationDuration: seconds);
    _saveConfig();
  }

  void setWarningNotificationDuration(int seconds) {
    if (seconds < 1) return;
    if (seconds > 30) return;
    state = state.copyWith(warningNotificationDuration: seconds);
    _saveConfig();
  }

  void setInfoNotificationDuration(int seconds) {
    if (seconds < 1) return;
    if (seconds > 30) return;
    state = state.copyWith(infoNotificationDuration: seconds);
    _saveConfig();
  }

  void updateWindowPosition(double width, double height, double x, double y, {bool? isMaximized}) {
    state = state.copyWith(
      windowWidth: width,
      windowHeight: height,
      windowX: x,
      windowY: y,
      isMaximized: isMaximized,
    );
    _saveConfig();
  }

  void setDateFormat(String format) {
    state = state.copyWith(dateFormat: format);
    _saveConfig();
  }
}
