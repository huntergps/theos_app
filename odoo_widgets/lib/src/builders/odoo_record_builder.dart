import 'package:fluent_ui/fluent_ui.dart';

/// Observes a whole record stream and shows an inline placeholder while loading.
///
/// Unlike [OdooContentBuilder] which is designed for full-page content areas,
/// [OdooRecordBuilder] is compact and suitable for inline use within forms
/// and detail views.
///
/// Usage:
/// ```dart
/// OdooRecordBuilder<Product>(
///   stream: productManager.watch(productId),
///   builder: (context, product) => Text(product.name),
/// )
/// ```
class OdooRecordBuilder<T> extends StatelessWidget {
  /// The stream of record data to observe.
  final Stream<T> stream;

  /// Builder that receives the context and data when available.
  final Widget Function(BuildContext context, T data) builder;

  /// Initial data to show before the stream emits.
  final T? initialData;

  /// Custom widget to show during loading.
  /// Defaults to an inline 48px-high centered [ProgressRing].
  final Widget? loading;

  /// Custom builder for error states.
  /// Defaults to an inline row with error icon and message text.
  final Widget Function(Object error, StackTrace? stack)? errorBuilder;

  const OdooRecordBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.initialData,
    this.loading,
    this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (errorBuilder != null) {
            return errorBuilder!(snapshot.error!, snapshot.stackTrace);
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.error, size: 14, color: Colors.red),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.red, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }

        if (snapshot.hasData) {
          return builder(context, snapshot.data as T);
        }

        return loading ??
            const SizedBox(
              height: 48,
              child: Center(child: ProgressRing(strokeWidth: 2)),
            );
      },
    );
  }
}

/// Extracts a single field from a record stream with bidirectional binding.
///
/// Useful for connecting a reactive stream to an individual form field,
/// so the field automatically updates when the record changes and can
/// write back via [onSave].
///
/// Usage:
/// ```dart
/// OdooFieldConnector<Product, String>(
///   stream: productManager.watch(productId),
///   getValue: (product) => product.name,
///   onSave: (name) => productManager.update(productId, {'name': name}),
///   builder: (context, value, onChanged) => TextBox(
///     controller: TextEditingController(text: value ?? ''),
///     onChanged: onChanged,
///   ),
/// )
/// ```
class OdooFieldConnector<R, V> extends StatelessWidget {
  /// The stream of record data to observe.
  final Stream<R> stream;

  /// Extracts the field value from the record.
  final V Function(R record) getValue;

  /// Called when the field value should be saved back.
  final void Function(V value)? onSave;

  /// Builder that receives the current value and an optional change callback.
  final Widget Function(
      BuildContext context, V? value, ValueChanged<V?>? onChanged) builder;

  /// Initial record data to use before the stream emits.
  final R? initialData;

  const OdooFieldConnector({
    super.key,
    required this.stream,
    required this.getValue,
    this.onSave,
    required this.builder,
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<R>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        final V? value =
            snapshot.hasData ? getValue(snapshot.data as R) : null;

        ValueChanged<V?>? onChanged;
        if (onSave != null) {
          onChanged = (V? newValue) {
            if (newValue != null) {
              onSave!(newValue);
            }
          };
        }

        return builder(context, value, onChanged);
      },
    );
  }
}

/// Stream extensions for building record and field widgets inline.
extension OdooRecordStreamExtension<T> on Stream<T> {
  /// Builds an [OdooRecordBuilder] from this stream.
  ///
  /// Usage:
  /// ```dart
  /// productManager.watch(id).buildRecord(
  ///   builder: (context, product) => Text(product.name),
  /// )
  /// ```
  Widget buildRecord({
    required Widget Function(BuildContext context, T data) builder,
    T? initialData,
    Widget? loading,
    Widget Function(Object error, StackTrace? stack)? errorBuilder,
  }) {
    return OdooRecordBuilder<T>(
      stream: this,
      builder: builder,
      initialData: initialData,
      loading: loading,
      errorBuilder: errorBuilder,
    );
  }

  /// Builds an [OdooFieldConnector] from this stream.
  ///
  /// Usage:
  /// ```dart
  /// productManager.watch(id).connectField<String>(
  ///   getValue: (p) => p.name,
  ///   onSave: (name) => manager.update(id, {'name': name}),
  ///   builder: (context, value, onChanged) => TextBox(
  ///     controller: TextEditingController(text: value ?? ''),
  ///     onChanged: onChanged,
  ///   ),
  /// )
  /// ```
  Widget connectField<V>({
    required V Function(T record) getValue,
    void Function(V value)? onSave,
    required Widget Function(
            BuildContext context, V? value, ValueChanged<V?>? onChanged)
        builder,
    T? initialData,
  }) {
    return OdooFieldConnector<T, V>(
      stream: this,
      getValue: getValue,
      onSave: onSave,
      builder: builder,
      initialData: initialData,
    );
  }
}
