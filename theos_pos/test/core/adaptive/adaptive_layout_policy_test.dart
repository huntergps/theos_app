import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:theos_pos/core/adaptive/adaptive_layout_policy.dart';

void main() {
  group('AdaptiveEnvironment size classes', () {
    test('uses compact, medium, and expanded breakpoint boundaries', () {
      expect(_environment(width: 599).sizeClass, AdaptiveSizeClass.compact);
      expect(_environment(width: 600).sizeClass, AdaptiveSizeClass.medium);
      expect(_environment(width: 839).sizeClass, AdaptiveSizeClass.medium);
      expect(_environment(width: 840).sizeClass, AdaptiveSizeClass.expanded);
    });

    test('classifies by available width instead of device orientation', () {
      expect(
        _environment(width: 768, height: 1024).sizeClass,
        AdaptiveSizeClass.medium,
      );
      expect(
        _environment(width: 1024, height: 768).sizeClass,
        AdaptiveSizeClass.expanded,
      );
    });

    testWidgets('fromContext reads the current app window size', (
      tester,
    ) async {
      late AdaptiveEnvironment environment;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(700, 1000)),
          child: Builder(
            builder: (context) {
              environment = AdaptiveEnvironment.fromContext(
                context,
                inputs: const AdaptiveInputCapabilities(touch: true),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(environment.width, 700);
      expect(environment.height, 1000);
      expect(environment.sizeClass, AdaptiveSizeClass.medium);
      expect(environment.inputs.touch, isTrue);
    });
  });

  group('AdaptiveUiPolicy target scenarios', () {
    test('Android phone is compact and touch-first', () {
      final policy = AdaptiveUiPolicy(
        _environment(
          width: 412,
          height: 915,
          inputs: const AdaptiveInputCapabilities(touch: true, camera: true),
        ),
      );

      expect(policy.navigation, AdaptiveNavigation.bottomBar);
      expect(policy.dialogPresentation, AdaptiveDialogPresentation.fullScreen);
      expect(policy.contentColumns, 1);
      expect(policy.minimumInteractiveExtent, 48);
      expect(policy.supportsBarcodeCapture, isTrue);
      expect(policy.usesSplitView, isFalse);
    });

    test(
      'iPad portrait uses medium navigation without assuming orientation',
      () {
        final policy = AdaptiveUiPolicy(
          _environment(
            width: 768,
            height: 1024,
            inputs: const AdaptiveInputCapabilities(touch: true, camera: true),
          ),
        );

        expect(policy.navigation, AdaptiveNavigation.rail);
        expect(policy.dialogPresentation, AdaptiveDialogPresentation.modal);
        expect(policy.contentColumns, 2);
        expect(policy.minimumInteractiveExtent, 48);
        expect(policy.usesSplitView, isFalse);
      },
    );

    test('iPad landscape and Android large tablet can use split view', () {
      final policy = AdaptiveUiPolicy(
        _environment(
          width: 1024,
          height: 768,
          inputs: const AdaptiveInputCapabilities(touch: true),
        ),
      );

      expect(policy.navigation, AdaptiveNavigation.pane);
      expect(policy.contentColumns, 3);
      expect(policy.usesSplitView, isTrue);
      expect(policy.usesCompactVisualDensity, isFalse);
    });

    test('desktop enables pointer and keyboard accelerators', () {
      final policy = AdaptiveUiPolicy(
        _environment(
          width: 1440,
          height: 900,
          inputs: const AdaptiveInputCapabilities(
            precisePointer: true,
            hardwareKeyboard: true,
            barcodeScanner: true,
          ),
        ),
      );

      expect(policy.navigation, AdaptiveNavigation.pane);
      expect(policy.minimumInteractiveExtent, 32);
      expect(policy.supportsHover, isTrue);
      expect(policy.enablesKeyboardAccelerators, isTrue);
      expect(policy.supportsBarcodeCapture, isTrue);
      expect(policy.usesCompactVisualDensity, isTrue);
    });

    test('web remains width- and capability-driven', () {
      final policy = AdaptiveUiPolicy(
        _environment(
          width: 800,
          height: 900,
          runtime: AdaptiveRuntime.web,
          inputs: const AdaptiveInputCapabilities(
            touch: true,
            precisePointer: true,
            hardwareKeyboard: true,
          ),
        ),
      );

      expect(policy.environment.runtime, AdaptiveRuntime.web);
      expect(policy.navigation, AdaptiveNavigation.rail);
      expect(policy.minimumInteractiveExtent, 44);
      expect(policy.supportsHover, isTrue);
      expect(policy.enablesKeyboardAccelerators, isTrue);
      expect(policy.usesCompactVisualDensity, isFalse);
    });
  });
}

AdaptiveEnvironment _environment({
  required double width,
  double height = 800,
  AdaptiveRuntime runtime = AdaptiveRuntime.native,
  AdaptiveInputCapabilities inputs = const AdaptiveInputCapabilities(),
}) {
  return AdaptiveEnvironment(
    width: width,
    height: height,
    runtime: runtime,
    inputs: inputs,
  );
}
