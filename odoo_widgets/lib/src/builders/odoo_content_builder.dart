import 'package:fluent_ui/fluent_ui.dart';

/// Generic widget to handle loading/error/success states of a [Stream].
///
/// State-management agnostic -- accepts any `Stream<T>` instead of AsyncValue.
/// Works with `manager.watchAll()`, `manager.watch(id)`, or any Dart stream.
///
/// Provides consistent UX for async states:
/// - **Loading**: Centered progress indicator with optional message
/// - **Error**: InfoBar with optional retry button
/// - **Data**: Renders content via the builder
///
/// Usage:
/// ```dart
/// OdooContentBuilder<List<Product>>(
///   stream: productManager.watchAll(),
///   builder: (products) => ProductList(products: products),
///   onRetry: () => productManager.syncAll(),
/// )
/// ```
class OdooContentBuilder<T> extends StatelessWidget {
  /// The stream to observe.
  final Stream<T> stream;

  /// Builder that receives the data when available.
  final Widget Function(T data) builder;

  /// Custom widget to show during loading.
  final Widget? loading;

  /// Optional message shown during loading.
  final String? loadingMessage;

  /// Custom builder for error states.
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;

  /// Callback to retry the operation after an error.
  final VoidCallback? onRetry;

  /// Title for the error InfoBar.
  final String errorTitle;

  /// Label for the retry button.
  final String retryLabel;

  /// Initial data to show before the stream emits.
  final T? initialData;

  const OdooContentBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.loading,
    this.loadingMessage,
    this.errorBuilder,
    this.onRetry,
    this.errorTitle = 'Error loading data',
    this.retryLabel = 'Retry',
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildError(context, snapshot.error!, snapshot.stackTrace);
        }

        if (snapshot.hasData) {
          return builder(snapshot.data as T);
        }

        return _buildLoading(context);
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    if (loading != null) {
      return loading!;
    }

    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          if (loadingMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              loadingMessage!,
              style: theme.typography.body?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(
      BuildContext context, Object error, StackTrace? stack) {
    if (errorBuilder != null) {
      return errorBuilder!(error, stack);
    }

    final theme = FluentTheme.of(context);
    final errorMessage = error.toString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InfoBar(
                title: Text(errorTitle),
                content: SelectableText(
                  errorMessage,
                  style: theme.typography.caption,
                ),
                severity: InfoBarSeverity.error,
                isLong: errorMessage.length > 80,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(FluentIcons.refresh, size: 16),
                      const SizedBox(width: 8),
                      Text(retryLabel),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Extension for building content from any Stream.
///
/// Usage:
/// ```dart
/// productManager.watchAll().buildContent(
///   builder: (products) => ProductList(products: products),
///   onRetry: () => productManager.syncAll(),
/// )
/// ```
extension OdooStreamExtension<T> on Stream<T> {
  /// Builds an [OdooContentBuilder] from this stream.
  Widget buildContent({
    required Widget Function(T data) builder,
    Widget? loading,
    String? loadingMessage,
    Widget Function(Object error, StackTrace? stack)? errorBuilder,
    VoidCallback? onRetry,
    String errorTitle = 'Error loading data',
    String retryLabel = 'Retry',
    T? initialData,
  }) {
    return OdooContentBuilder<T>(
      stream: this,
      builder: builder,
      loading: loading,
      loadingMessage: loadingMessage,
      errorBuilder: errorBuilder,
      onRetry: onRetry,
      errorTitle: errorTitle,
      retryLabel: retryLabel,
      initialData: initialData,
    );
  }
}

// ---------------------------------------------------------------------------
// Backward-compatible aliases
// ---------------------------------------------------------------------------

/// @nodoc Deprecated: use [OdooContentBuilder] instead.
typedef AsyncContentBuilder<T> = OdooContentBuilder<T>;

/// @nodoc Deprecated: use [OdooStreamExtension] instead.
extension StreamContentBuilderExtension<T> on Stream<T> {
  /// @nodoc Deprecated: use [OdooStreamExtension.buildContent] instead.
  Widget buildContentLegacy({
    required Widget Function(T data) builder,
    Widget? loading,
    String? loadingMessage,
    Widget Function(Object error, StackTrace? stack)? errorBuilder,
    VoidCallback? onRetry,
    String errorTitle = 'Error loading data',
    String retryLabel = 'Retry',
    T? initialData,
  }) {
    return OdooContentBuilder<T>(
      stream: this,
      builder: builder,
      loading: loading,
      loadingMessage: loadingMessage,
      errorBuilder: errorBuilder,
      onRetry: onRetry,
      errorTitle: errorTitle,
      retryLabel: retryLabel,
      initialData: initialData,
    );
  }
}
