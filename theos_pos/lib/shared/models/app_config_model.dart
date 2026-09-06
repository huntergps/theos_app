import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

import 'config_profile.dart';

class AppConfigModel {
  final ThemeMode themeMode;
  final AccentColor accentColor;
  final bool accentColorCustomized;
  final WindowEffect windowEffect;
  final double displayFactor;
  final double titleLargeFactor;
  final double titleFactor;
  final double bodyLargeFactor;
  final double bodyStrongFactor;
  final double bodyFactor;
  final double captionFactor;
  final PaneDisplayMode displayMode;
  final double spacingFactor; // Factor de escala para espaciado (0.5 - 2.0)
  final double? windowWidth;
  final double? windowHeight;
  final double? windowX;
  final double? windowY;
  final bool isMaximized;

  final List<ConfigProfile> profiles;
  final String? activeProfileId;

  // Sync configuration
  final int
  maxSyncRetries; // Máximo de reintentos automáticos para sincronización

  // Notification durations (in seconds)
  final int errorNotificationDuration; // Duración de notificaciones de error
  final int successNotificationDuration; // Duración de notificaciones de éxito
  final int
  warningNotificationDuration; // Duración de notificaciones de advertencia
  final int infoNotificationDuration; // Duración de notificaciones informativas

  // Date format
  final String dateFormat;

  // Developer mode — enables diagnostic routes (DLQ and conflicts)
  final bool developerMode;

  const AppConfigModel({
    required this.themeMode,
    required this.accentColor,
    this.accentColorCustomized = false,
    required this.windowEffect,
    required this.displayFactor,
    required this.titleLargeFactor,
    required this.titleFactor,
    required this.bodyLargeFactor,
    required this.bodyStrongFactor,
    required this.bodyFactor,
    required this.captionFactor,
    required this.displayMode,
    this.spacingFactor = 1.0, // Default: sin escala
    this.windowWidth,
    this.windowHeight,
    this.windowX,
    this.windowY,
    this.isMaximized = false,
    this.profiles = const [],
    this.activeProfileId,
    this.maxSyncRetries = 3, // Default: 3 reintentos
    this.errorNotificationDuration = 10, // Default: 10 segundos para errores
    this.successNotificationDuration = 3, // Default: 3 segundos para éxito
    this.warningNotificationDuration =
        5, // Default: 5 segundos para advertencias
    this.infoNotificationDuration = 3, // Default: 3 segundos para info
    this.dateFormat = 'dd/MM/yyyy', // Default: Ecuador format
    this.developerMode = false, // Default: disabled for production
  });

  factory AppConfigModel.defaultConfig() {
    return AppConfigModel(
      themeMode: ThemeMode.system,
      accentColor: Colors.blue,
      accentColorCustomized: false,
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
      isMaximized: false,
      profiles: [],
      activeProfileId: null,
      maxSyncRetries: 3, // Default: 3 reintentos automáticos
      errorNotificationDuration: 10,
      successNotificationDuration: 3,
      warningNotificationDuration: 5,
      infoNotificationDuration: 3,
      dateFormat: 'dd/MM/yyyy',
      developerMode: false,
    );
  }

  AppConfigModel copyWith({
    ThemeMode? themeMode,
    AccentColor? accentColor,
    bool? accentColorCustomized,
    WindowEffect? windowEffect,
    double? displayFactor,
    double? titleLargeFactor,
    double? titleFactor,
    double? bodyLargeFactor,
    double? bodyStrongFactor,
    double? bodyFactor,
    double? captionFactor,
    PaneDisplayMode? displayMode,
    double? spacingFactor,
    double? windowWidth,
    double? windowHeight,
    double? windowX,
    double? windowY,
    bool? isMaximized,
    List<ConfigProfile>? profiles,
    String? activeProfileId,
    int? maxSyncRetries,
    int? errorNotificationDuration,
    int? successNotificationDuration,
    int? warningNotificationDuration,
    int? infoNotificationDuration,
    String? dateFormat,
    bool? developerMode,
  }) {
    return AppConfigModel(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      accentColorCustomized:
          accentColorCustomized ?? this.accentColorCustomized,
      windowEffect: windowEffect ?? this.windowEffect,
      displayFactor: displayFactor ?? this.displayFactor,
      titleLargeFactor: titleLargeFactor ?? this.titleLargeFactor,
      titleFactor: titleFactor ?? this.titleFactor,
      bodyLargeFactor: bodyLargeFactor ?? this.bodyLargeFactor,
      bodyStrongFactor: bodyStrongFactor ?? this.bodyStrongFactor,
      bodyFactor: bodyFactor ?? this.bodyFactor,
      captionFactor: captionFactor ?? this.captionFactor,
      displayMode: displayMode ?? this.displayMode,
      spacingFactor: spacingFactor ?? this.spacingFactor,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      windowX: windowX ?? this.windowX,
      windowY: windowY ?? this.windowY,
      isMaximized: isMaximized ?? this.isMaximized,
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      maxSyncRetries: maxSyncRetries ?? this.maxSyncRetries,
      errorNotificationDuration:
          errorNotificationDuration ?? this.errorNotificationDuration,
      successNotificationDuration:
          successNotificationDuration ?? this.successNotificationDuration,
      warningNotificationDuration:
          warningNotificationDuration ?? this.warningNotificationDuration,
      infoNotificationDuration:
          infoNotificationDuration ?? this.infoNotificationDuration,
      dateFormat: dateFormat ?? this.dateFormat,
      developerMode: developerMode ?? this.developerMode,
    );
  }
}
