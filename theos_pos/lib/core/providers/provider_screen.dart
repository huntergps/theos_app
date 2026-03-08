import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Base class for screens that need to initialize a provider on mount
///
/// This standardizes the pattern of:
/// 1. Using Future.microtask to initialize providers after the constructor
/// 2. Re-initializing when widget parameters change
///
/// ## Usage
/// ```dart
/// class MyScreen extends ProviderInitializedScreen {
///   final int itemId;
///
///   const MyScreen({required this.itemId, super.key});
///
///   @override
///   void onInitialize(WidgetRef ref) {
///     ref.read(myNotifierProvider.notifier).loadItem(itemId);
///   }
///
///   @override
///   bool shouldReinitialize(covariant MyScreen oldWidget) {
///     return oldWidget.itemId != itemId;
///   }
///
///   @override
///   Widget buildContent(BuildContext context, WidgetRef ref) {
///     final state = ref.watch(myNotifierProvider);
///     // Build your UI...
///   }
/// }
/// ```
abstract class ProviderInitializedScreen extends ConsumerStatefulWidget {
  const ProviderInitializedScreen({super.key});

  @override
  ProviderInitializedScreenState createState();
}

abstract class ProviderInitializedScreenState<T extends ProviderInitializedScreen>
    extends ConsumerState<T> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        _initialize();
      }
    });
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shouldReinitialize(oldWidget)) {
      _initialize();
    }
  }

  void _initialize() {
    onInitialize(ref);
    _initialized = true;
  }

  /// Whether the screen has been initialized
  bool get initialized => _initialized;

  /// Called after the first frame to initialize providers
  ///
  /// Override this to load initial data, set up listeners, etc.
  void onInitialize(WidgetRef ref);

  /// Whether to reinitialize when widget parameters change
  ///
  /// Override this to compare relevant parameters.
  /// Default returns false (no reinitialization on update).
  bool shouldReinitialize(covariant T oldWidget) => false;

  /// Build the screen content
  ///
  /// Override this instead of build() to ensure proper initialization.
  Widget buildContent(BuildContext context, WidgetRef ref);

  @override
  Widget build(BuildContext context) => buildContent(context, ref);
}

/// Simplified mixin for screens that just need initialization
///
/// Use this when you want to keep using ConsumerStatefulWidget directly
/// but need the initialization pattern.
///
/// ## Usage
/// ```dart
/// class MyScreen extends ConsumerStatefulWidget {
///   const MyScreen({super.key});
///
///   @override
///   ConsumerState<MyScreen> createState() => _MyScreenState();
/// }
///
/// class _MyScreenState extends ConsumerState<MyScreen>
///     with ProviderInitializationMixin<MyScreen> {
///   @override
///   void onProviderInit() {
///     ref.read(myProvider.notifier).initialize();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     // Your build...
///   }
/// }
/// ```
mixin ProviderInitializationMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _providerInitialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        onProviderInit();
        _providerInitialized = true;
      }
    });
  }

  /// Whether the provider has been initialized
  bool get providerInitialized => _providerInitialized;

  /// Called after the first frame
  void onProviderInit();

  /// Override in subclass to reinitialize on parameter changes
  void onParametersChanged(covariant T oldWidget) {}

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    onParametersChanged(oldWidget);
  }
}
