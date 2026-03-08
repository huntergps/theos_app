import 'package:flutter/widgets.dart';

/// Device type for responsive configurations.
enum DeviceType { mobile, tablet, desktop }

/// Extension to get DeviceType from BuildContext.
extension DeviceTypeExtension on BuildContext {
  /// Gets the device type based on screen width.
  DeviceType get deviceType {
    final width = MediaQuery.of(this).size.width;
    if (width < 600) return DeviceType.mobile;
    if (width < 1200) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;
}

/// UI values that vary by device type.
///
/// Usage:
/// ```dart
/// final responsive = ResponsiveValues(context.deviceType);
/// SizedBox(height: responsive.touchTarget);
/// Icon(icon, size: responsive.iconSize);
/// ```
class ResponsiveValues {
  final DeviceType deviceType;

  const ResponsiveValues(this.deviceType);

  /// Minimum touch target size.
  double get touchTarget {
    switch (deviceType) {
      case DeviceType.mobile:
        return 48;
      case DeviceType.tablet:
        return 44;
      case DeviceType.desktop:
        return 32;
    }
  }

  /// Icon size for fields.
  double get iconSize {
    switch (deviceType) {
      case DeviceType.mobile:
        return 20;
      case DeviceType.tablet:
        return 16;
      case DeviceType.desktop:
        return 14;
    }
  }

  /// Label width for inline layout (0 = flexible on mobile).
  double get labelWidth {
    switch (deviceType) {
      case DeviceType.mobile:
        return 0;
      case DeviceType.tablet:
        return 100;
      case DeviceType.desktop:
        return 130;
    }
  }

  /// Whether to use stacked (vertical) layout instead of inline.
  bool get useStackedLayout => deviceType == DeviceType.mobile;

  /// Font size for labels.
  double get labelFontSize {
    switch (deviceType) {
      case DeviceType.mobile:
        return 14;
      case DeviceType.tablet:
        return 13;
      case DeviceType.desktop:
        return 12;
    }
  }

  /// Font size for values.
  double get valueFontSize {
    switch (deviceType) {
      case DeviceType.mobile:
        return 16;
      case DeviceType.tablet:
        return 14;
      case DeviceType.desktop:
        return 14;
    }
  }

  /// Internal field padding.
  double get fieldPadding {
    switch (deviceType) {
      case DeviceType.mobile:
        return 12;
      case DeviceType.tablet:
        return 10;
      case DeviceType.desktop:
        return 8;
    }
  }

  /// Spacing between form fields.
  double get fieldSpacing {
    switch (deviceType) {
      case DeviceType.mobile:
        return 16;
      case DeviceType.tablet:
        return 14;
      case DeviceType.desktop:
        return 12;
    }
  }
}
