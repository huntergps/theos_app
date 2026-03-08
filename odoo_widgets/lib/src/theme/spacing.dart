import 'package:flutter/widgets.dart';

/// Centralized spacing system for consistent visual alignment.
///
/// Based on a 4px grid scale for alignment with modern grid systems.
/// Supports dynamic scaling via [ThemedSpacing].
///
/// Static usage (unscaled base values):
/// ```dart
/// SizedBox(height: Spacing.lg)
/// EdgeInsets.all(Spacing.md)
/// ```
///
/// Dynamic usage (with scaling):
/// ```dart
/// final spacing = ThemedSpacing(1.2);
/// SizedBox(height: spacing.lg)
/// Padding(padding: spacing.all.md)
/// ```
abstract final class Spacing {
  /// 0px - No spacing
  static const double none = 0;

  /// 2px - Minimum spacing
  static const double xxs = 2;

  /// 4px - Extra small spacing
  static const double xs = 4;

  /// 8px - Small spacing
  static const double sm = 8;

  /// 12px - Medium-small spacing
  static const double ms = 12;

  /// 16px - Medium spacing (base)
  static const double md = 16;

  /// 20px - Medium-large spacing
  static const double ml = 20;

  /// 24px - Large spacing
  static const double lg = 24;

  /// 32px - Extra large spacing
  static const double xl = 32;

  /// 48px - Extra extra large spacing
  static const double xxl = 48;

  /// 64px - Maximum spacing
  static const double xxxl = 64;

  /// Preconfigured EdgeInsets (static, unscaled)
  static const EdgeInsetsAll all = EdgeInsetsAll._(1.0);
  static const EdgeInsetsSymmetric symmetric = EdgeInsetsSymmetric._(1.0);
  static const EdgeInsetsOnly only = EdgeInsetsOnly._();

  /// Preconfigured vertical SizedBox (static)
  static const SizedBoxVertical vertical = SizedBoxVertical._(1.0);

  /// Preconfigured horizontal SizedBox (static)
  static const SizedBoxHorizontal horizontal = SizedBoxHorizontal._(1.0);
}

/// Scaled spacing values.
///
/// Usage:
/// ```dart
/// final spacing = ThemedSpacing(1.2);
/// SizedBox(height: spacing.lg)
/// Padding(padding: spacing.all.md)
/// ```
class ThemedSpacing {
  final double factor;

  const ThemedSpacing(this.factor);

  double get none => Spacing.none;
  double get xxs => Spacing.xxs * factor;
  double get xs => Spacing.xs * factor;
  double get sm => Spacing.sm * factor;
  double get ms => Spacing.ms * factor;
  double get md => Spacing.md * factor;
  double get ml => Spacing.ml * factor;
  double get lg => Spacing.lg * factor;
  double get xl => Spacing.xl * factor;
  double get xxl => Spacing.xxl * factor;
  double get xxxl => Spacing.xxxl * factor;

  EdgeInsetsAll get all => EdgeInsetsAll._(factor);
  EdgeInsetsSymmetric get symmetric => EdgeInsetsSymmetric._(factor);
  EdgeInsetsOnly get only => const EdgeInsetsOnly._();

  SizedBoxVertical get vertical => SizedBoxVertical._(factor);
  SizedBoxHorizontal get horizontal => SizedBoxHorizontal._(factor);
}

/// EdgeInsets with equal padding on all sides.
class EdgeInsetsAll {
  final double _factor;
  const EdgeInsetsAll._(this._factor);

  EdgeInsets get none => EdgeInsets.zero;
  EdgeInsets get xs => EdgeInsets.all(Spacing.xs * _factor);
  EdgeInsets get sm => EdgeInsets.all(Spacing.sm * _factor);
  EdgeInsets get ms => EdgeInsets.all(Spacing.ms * _factor);
  EdgeInsets get md => EdgeInsets.all(Spacing.md * _factor);
  EdgeInsets get ml => EdgeInsets.all(Spacing.ml * _factor);
  EdgeInsets get lg => EdgeInsets.all(Spacing.lg * _factor);
  EdgeInsets get xl => EdgeInsets.all(Spacing.xl * _factor);
  EdgeInsets get xxl => EdgeInsets.all(Spacing.xxl * _factor);
}

/// Symmetric EdgeInsets.
class EdgeInsetsSymmetric {
  final double _factor;
  const EdgeInsetsSymmetric._(this._factor);

  EdgeInsets hNone() => const EdgeInsets.symmetric(horizontal: Spacing.none);
  EdgeInsets hXs() =>
      EdgeInsets.symmetric(horizontal: Spacing.xs * _factor);
  EdgeInsets hSm() =>
      EdgeInsets.symmetric(horizontal: Spacing.sm * _factor);
  EdgeInsets hMs() =>
      EdgeInsets.symmetric(horizontal: Spacing.ms * _factor);
  EdgeInsets hMd() =>
      EdgeInsets.symmetric(horizontal: Spacing.md * _factor);
  EdgeInsets hLg() =>
      EdgeInsets.symmetric(horizontal: Spacing.lg * _factor);
  EdgeInsets hXl() =>
      EdgeInsets.symmetric(horizontal: Spacing.xl * _factor);

  EdgeInsets vNone() => const EdgeInsets.symmetric(vertical: Spacing.none);
  EdgeInsets vXs() =>
      EdgeInsets.symmetric(vertical: Spacing.xs * _factor);
  EdgeInsets vSm() =>
      EdgeInsets.symmetric(vertical: Spacing.sm * _factor);
  EdgeInsets vMs() =>
      EdgeInsets.symmetric(vertical: Spacing.ms * _factor);
  EdgeInsets vMd() =>
      EdgeInsets.symmetric(vertical: Spacing.md * _factor);
  EdgeInsets vLg() =>
      EdgeInsets.symmetric(vertical: Spacing.lg * _factor);
  EdgeInsets vXl() =>
      EdgeInsets.symmetric(vertical: Spacing.xl * _factor);

  EdgeInsets both({double h = Spacing.md, double v = Spacing.md}) =>
      EdgeInsets.symmetric(horizontal: h * _factor, vertical: v * _factor);
}

/// Directional EdgeInsets.
class EdgeInsetsOnly {
  const EdgeInsetsOnly._();

  EdgeInsets left(double value) => EdgeInsets.only(left: value);
  EdgeInsets right(double value) => EdgeInsets.only(right: value);
  EdgeInsets top(double value) => EdgeInsets.only(top: value);
  EdgeInsets bottom(double value) => EdgeInsets.only(bottom: value);
}

/// Vertical SizedBox (height).
class SizedBoxVertical {
  final double _factor;
  const SizedBoxVertical._(this._factor);

  SizedBox get none => const SizedBox.shrink();
  SizedBox get xs => SizedBox(height: Spacing.xs * _factor);
  SizedBox get sm => SizedBox(height: Spacing.sm * _factor);
  SizedBox get ms => SizedBox(height: Spacing.ms * _factor);
  SizedBox get md => SizedBox(height: Spacing.md * _factor);
  SizedBox get ml => SizedBox(height: Spacing.ml * _factor);
  SizedBox get lg => SizedBox(height: Spacing.lg * _factor);
  SizedBox get xl => SizedBox(height: Spacing.xl * _factor);
  SizedBox get xxl => SizedBox(height: Spacing.xxl * _factor);
}

/// Horizontal SizedBox (width).
class SizedBoxHorizontal {
  final double _factor;
  const SizedBoxHorizontal._(this._factor);

  SizedBox get none => const SizedBox.shrink();
  SizedBox get xs => SizedBox(width: Spacing.xs * _factor);
  SizedBox get sm => SizedBox(width: Spacing.sm * _factor);
  SizedBox get ms => SizedBox(width: Spacing.ms * _factor);
  SizedBox get md => SizedBox(width: Spacing.md * _factor);
  SizedBox get ml => SizedBox(width: Spacing.ml * _factor);
  SizedBox get lg => SizedBox(width: Spacing.lg * _factor);
  SizedBox get xl => SizedBox(width: Spacing.xl * _factor);
  SizedBox get xxl => SizedBox(width: Spacing.xxl * _factor);
}

/// Extension for gap widgets in Rows and Columns.
extension SpacingWidgetExtension on num {
  SizedBox get verticalSpace => SizedBox(height: toDouble());
  SizedBox get horizontalSpace => SizedBox(width: toDouble());
  SizedBox get squareSpace => SizedBox.square(dimension: toDouble());
}

/// Extension for scaling numeric values.
extension ScaledSpacingExtension on num {
  double scaled(double factor) => toDouble() * factor;
}
