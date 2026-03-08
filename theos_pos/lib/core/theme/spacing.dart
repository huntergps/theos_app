import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../services/config_service.dart';

/// Provider que expone el factor de espaciado actual
final spacingFactorProvider = Provider<double>((ref) {
  return ref.watch(configServiceProvider).spacingFactor;
});

// ============================================================================
// RESPONSIVE SYSTEM - Device-aware spacing and sizing
// ============================================================================

/// Tipo de dispositivo para configuraciones responsivas
enum DeviceType { mobile, tablet, desktop }

/// Extension para obtener DeviceType desde BuildContext
extension DeviceTypeExtension on BuildContext {
  /// Obtiene el tipo de dispositivo basado en el ancho de pantalla
  DeviceType get deviceType {
    final width = MediaQuery.of(this).size.width;
    if (width < ScreenBreakpoints.mobileMaxWidth) return DeviceType.mobile;
    if (width < ScreenBreakpoints.tabletMaxWidth) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;
}

/// Valores de UI que varían según el tipo de dispositivo
///
/// Uso:
/// ```dart
/// final responsive = ResponsiveValues(context.deviceType);
/// SizedBox(height: responsive.touchTarget);
/// Icon(icon, size: responsive.iconSize);
/// ```
class ResponsiveValues {
  final DeviceType deviceType;

  const ResponsiveValues(this.deviceType);

  /// Tamaño mínimo de touch target (Material: 48px mobile, 44px tablet, 32px desktop)
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

  /// Tamaño de iconos en campos
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

  /// Ancho de labels en layout inline (0 = flexible en mobile)
  double get labelWidth {
    switch (deviceType) {
      case DeviceType.mobile:
        return 0; // Full width labels on mobile
      case DeviceType.tablet:
        return 100;
      case DeviceType.desktop:
        return 130;
    }
  }

  /// Si debe usar layout stacked (vertical) en lugar de inline
  bool get useStackedLayout => deviceType == DeviceType.mobile;

  /// Tamaño de fuente para labels
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

  /// Tamaño de fuente para valores
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

  /// Padding interno de campos
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

  /// Espaciado entre campos en formularios
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

/// Sistema de espaciado centralizado para mantener consistencia visual
///
/// Basado en escala de 4px para alineacion con grid systems modernos.
/// Soporta escalado dinamico mediante [spacingFactor].
///
/// Uso estatico (valores base sin escalar):
/// ```dart
/// SizedBox(height: Spacing.lg)
/// EdgeInsets.all(Spacing.md)
/// ```
///
/// Uso dinamico (con escalado del perfil):
/// ```dart
/// // En un ConsumerWidget
/// final spacing = ref.watch(themedSpacingProvider);
/// SizedBox(height: spacing.lg)
/// Padding(padding: spacing.all.md)
/// ```
abstract final class Spacing {
  // ============================================================================
  // BASE VALUES - Escala de 4px (sin escalar)
  // ============================================================================

  /// 0px - Sin espaciado
  static const double none = 0;

  /// 2px - Espaciado minimo (para padding interno de elementos interactivos)
  static const double xxs = 2;

  /// 4px - Espaciado extra pequeno
  static const double xs = 4;

  /// 8px - Espaciado pequeno
  static const double sm = 8;

  /// 12px - Espaciado medio-pequeno
  static const double ms = 12;

  /// 16px - Espaciado medio (base)
  static const double md = 16;

  /// 20px - Espaciado medio-grande
  static const double ml = 20;

  /// 24px - Espaciado grande
  static const double lg = 24;

  /// 32px - Espaciado extra grande
  static const double xl = 32;

  /// 48px - Espaciado extra extra grande
  static const double xxl = 48;

  /// 64px - Espaciado maximo
  static const double xxxl = 64;

  // ============================================================================
  // STATIC EDGE INSETS - Atajos para EdgeInsets comunes (sin escalar)
  // ============================================================================

  /// EdgeInsets preconfigurados (estaticos, sin escala)
  static const EdgeInsetsAll all = EdgeInsetsAll._(1.0);
  static const EdgeInsetsSymmetric symmetric = EdgeInsetsSymmetric._(1.0);
  static const EdgeInsetsOnly only = EdgeInsetsOnly._();

  // ============================================================================
  // STATIC SIZED BOXES - Widgets de espaciado preconfigurados (sin escalar)
  // ============================================================================

  /// SizedBox vertical preconfigurados (estaticos)
  static const SizedBoxVertical vertical = SizedBoxVertical._(1.0);

  /// SizedBox horizontal preconfigurados (estaticos)
  static const SizedBoxHorizontal horizontal = SizedBoxHorizontal._(1.0);
}

/// Provider que expone un ThemedSpacing con el factor del perfil actual
final themedSpacingProvider = Provider<ThemedSpacing>((ref) {
  final factor = ref.watch(spacingFactorProvider);
  return ThemedSpacing(factor);
});

/// Clase que proporciona valores de espaciado escalados
///
/// Usar con el provider [themedSpacingProvider] para obtener valores
/// que respetan el factor de espaciado del perfil actual.
class ThemedSpacing {
  final double factor;

  const ThemedSpacing(this.factor);

  // Valores escalados
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

  /// EdgeInsets escalados
  EdgeInsetsAll get all => EdgeInsetsAll._(factor);
  EdgeInsetsSymmetric get symmetric => EdgeInsetsSymmetric._(factor);
  EdgeInsetsOnly get only => const EdgeInsetsOnly._();

  /// SizedBox escalados
  SizedBoxVertical get vertical => SizedBoxVertical._(factor);
  SizedBoxHorizontal get horizontal => SizedBoxHorizontal._(factor);
}

/// EdgeInsets con padding en todos los lados
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

/// EdgeInsets simetricos
class EdgeInsetsSymmetric {
  final double _factor;
  const EdgeInsetsSymmetric._(this._factor);

  /// Horizontal only
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

  /// Vertical only
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

  /// Both directions
  EdgeInsets both({double h = Spacing.md, double v = Spacing.md}) =>
      EdgeInsets.symmetric(horizontal: h * _factor, vertical: v * _factor);
}

/// EdgeInsets en direcciones especificas
class EdgeInsetsOnly {
  const EdgeInsetsOnly._();

  EdgeInsets left(double value) => EdgeInsets.only(left: value);
  EdgeInsets right(double value) => EdgeInsets.only(right: value);
  EdgeInsets top(double value) => EdgeInsets.only(top: value);
  EdgeInsets bottom(double value) => EdgeInsets.only(bottom: value);
}

/// SizedBox verticales (altura)
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

/// SizedBox horizontales (ancho)
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

/// Extension para facilitar el uso de gaps en Rows y Columns
extension SpacingWidgetExtension on num {
  /// Crea un SizedBox con altura especifica
  SizedBox get verticalSpace => SizedBox(height: toDouble());

  /// Crea un SizedBox con ancho especifico
  SizedBox get horizontalSpace => SizedBox(width: toDouble());

  /// Crea un SizedBox cuadrado
  SizedBox get squareSpace => SizedBox.square(dimension: toDouble());
}

/// Extension para aplicar factor de escala a valores numericos
extension ScaledSpacingExtension on num {
  /// Escala el valor por el factor dado
  double scaled(double factor) => toDouble() * factor;
}
