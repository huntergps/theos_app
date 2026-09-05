import 'package:flutter/widgets.dart';

import '../constants/app_constants.dart';

/// Clase de ventana calculada exclusivamente desde el ancho disponible.
enum AdaptiveSizeClass { compact, medium, expanded }

/// Superficie donde se ejecuta la app, sin inferir capacidades desde ella.
enum AdaptiveRuntime { native, web }

/// Patron de navegacion recomendado para la clase de ventana actual.
enum AdaptiveNavigation { bottomBar, rail, pane }

/// Presentacion recomendada para formularios y flujos modales.
enum AdaptiveDialogPresentation { fullScreen, modal }

/// Capacidades de entrada observadas por la composicion de la aplicacion.
///
/// Son datos explicitos para que las politicas no dependan de
/// `Platform.isAndroid`, `Platform.isIOS` o del host que ejecuta las pruebas.
class AdaptiveInputCapabilities {
  const AdaptiveInputCapabilities({
    this.touch = false,
    this.precisePointer = false,
    this.hardwareKeyboard = false,
    this.camera = false,
    this.barcodeScanner = false,
  });

  final bool touch;
  final bool precisePointer;
  final bool hardwareKeyboard;
  final bool camera;
  final bool barcodeScanner;

  /// La captura puede usar camara o un lector dedicado/keyboard wedge.
  bool get supportsBarcodeCapture => camera || barcodeScanner;
}

/// Snapshot tipado del espacio y las capacidades disponibles.
class AdaptiveEnvironment {
  const AdaptiveEnvironment({
    required this.width,
    required this.height,
    required this.inputs,
    this.runtime = AdaptiveRuntime.native,
  }) : assert(width >= 0),
       assert(height >= 0);

  /// Captura el tamano actual de la ventana; las capacidades siguen siendo
  /// explicitas porque no pueden inferirse de forma fiable desde la plataforma.
  factory AdaptiveEnvironment.fromContext(
    BuildContext context, {
    required AdaptiveInputCapabilities inputs,
    AdaptiveRuntime runtime = AdaptiveRuntime.native,
  }) {
    final size = MediaQuery.sizeOf(context);
    return AdaptiveEnvironment(
      width: size.width,
      height: size.height,
      inputs: inputs,
      runtime: runtime,
    );
  }

  final double width;
  final double height;
  final AdaptiveRuntime runtime;
  final AdaptiveInputCapabilities inputs;

  AdaptiveSizeClass get sizeClass {
    if (width < ScreenBreakpoints.compactMaxWidth) {
      return AdaptiveSizeClass.compact;
    }
    if (width < ScreenBreakpoints.mediumMaxWidth) {
      return AdaptiveSizeClass.medium;
    }
    return AdaptiveSizeClass.expanded;
  }

  bool get runsInBrowser => runtime == AdaptiveRuntime.web;
}

/// Decide como debe presentarse la UI a partir de capacidades, no de marcas de
/// dispositivo. Las pantallas pueden adoptar estas politicas incrementalmente.
class AdaptiveUiPolicy {
  const AdaptiveUiPolicy(this.environment);

  final AdaptiveEnvironment environment;

  AdaptiveNavigation get navigation {
    return switch (environment.sizeClass) {
      AdaptiveSizeClass.compact => AdaptiveNavigation.bottomBar,
      AdaptiveSizeClass.medium => AdaptiveNavigation.rail,
      AdaptiveSizeClass.expanded => AdaptiveNavigation.pane,
    };
  }

  AdaptiveDialogPresentation get dialogPresentation {
    return environment.sizeClass == AdaptiveSizeClass.compact
        ? AdaptiveDialogPresentation.fullScreen
        : AdaptiveDialogPresentation.modal;
  }

  int get contentColumns {
    return switch (environment.sizeClass) {
      AdaptiveSizeClass.compact => 1,
      AdaptiveSizeClass.medium => 2,
      AdaptiveSizeClass.expanded => 3,
    };
  }

  bool get usesSplitView => environment.sizeClass == AdaptiveSizeClass.expanded;

  bool get supportsHover => environment.inputs.precisePointer;

  bool get enablesKeyboardAccelerators => environment.inputs.hardwareKeyboard;

  bool get supportsBarcodeCapture => environment.inputs.supportsBarcodeCapture;

  bool get usesCompactVisualDensity =>
      environment.inputs.precisePointer && !environment.inputs.touch;

  double get minimumInteractiveExtent {
    final inputs = environment.inputs;
    if (inputs.touch && !inputs.precisePointer) {
      return InteractionSizes.touch;
    }
    if (inputs.touch) {
      return InteractionSizes.hybrid;
    }
    if (inputs.precisePointer) {
      return InteractionSizes.pointer;
    }
    return InteractionSizes.hybrid;
  }
}
