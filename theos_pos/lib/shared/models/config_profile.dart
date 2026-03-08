import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';

class ConfigProfile {
  final String id;
  final String name;
  final ThemeMode themeMode;
  final AccentColor accentColor;
  final WindowEffect windowEffect;
  final double displayFactor;
  final double titleLargeFactor;
  final double titleFactor;
  final double bodyLargeFactor;
  final double bodyStrongFactor;
  final double bodyFactor;
  final double captionFactor;
  final PaneDisplayMode displayMode;
  final double spacingFactor;
  final bool isDefault;

  const ConfigProfile({
    required this.id,
    required this.name,
    required this.themeMode,
    required this.accentColor,
    required this.windowEffect,
    required this.displayFactor,
    required this.titleLargeFactor,
    required this.titleFactor,
    required this.bodyLargeFactor,
    required this.bodyStrongFactor,
    required this.bodyFactor,
    required this.captionFactor,
    this.displayMode = PaneDisplayMode.compact,
    this.spacingFactor = 1.0,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'themeMode': themeMode.toString(),
      'accentColor': accentColor.toARGB32(),
      'windowEffect': windowEffect.toString(),
      'displayFactor': displayFactor,
      'titleLargeFactor': titleLargeFactor,
      'titleFactor': titleFactor,
      'bodyLargeFactor': bodyLargeFactor,
      'bodyStrongFactor': bodyStrongFactor,
      'bodyFactor': bodyFactor,
      'captionFactor': captionFactor,
      'displayMode': displayMode.toString(),
      'spacingFactor': spacingFactor,
      'isDefault': isDefault,
    };
  }

  factory ConfigProfile.fromJson(Map<String, dynamic> json) {
    // Helper to parse AccentColor from int value
    AccentColor parseAccentColor(int value) {
      for (final color in Colors.accentColors) {
        if (color.toARGB32() == value) return color;
      }
      return Colors.blue;
    }

    // Helper to parse Enum from string
    T parseEnum<T>(List<T> values, String str, T defaultValue) {
      return values.firstWhere(
        (e) => e.toString() == str,
        orElse: () => defaultValue,
      );
    }

    return ConfigProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      themeMode: parseEnum(
        ThemeMode.values,
        json['themeMode'],
        ThemeMode.system,
      ),
      accentColor: parseAccentColor(json['accentColor'] as int),
      windowEffect: parseEnum(
        WindowEffect.values,
        json['windowEffect'],
        WindowEffect.disabled,
      ),
      displayFactor: (json['displayFactor'] as num).toDouble(),
      titleLargeFactor: (json['titleLargeFactor'] as num).toDouble(),
      titleFactor: (json['titleFactor'] as num).toDouble(),
      bodyLargeFactor: (json['bodyLargeFactor'] as num).toDouble(),
      bodyStrongFactor: (json['bodyStrongFactor'] as num).toDouble(),
      bodyFactor: (json['bodyFactor'] as num).toDouble(),
      captionFactor: (json['captionFactor'] as num).toDouble(),
      displayMode: parseEnum(
        PaneDisplayMode.values,
        json['displayMode'] ?? '',
        PaneDisplayMode.compact,
      ),
      spacingFactor: (json['spacingFactor'] as num?)?.toDouble() ?? 1.0,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  ConfigProfile copyWith({
    String? id,
    String? name,
    ThemeMode? themeMode,
    AccentColor? accentColor,
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
    bool? isDefault,
  }) {
    return ConfigProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
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
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
