import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/formatting_utils.dart';

/// Configuración para BaseDetailDialog
class DetailDialogConfig {
  /// Título del diálogo
  final String title;

  /// Icono del título (opcional)
  final IconData? icon;

  /// Color del icono
  final Color? iconColor;

  /// Ancho máximo del diálogo
  final double maxWidth;

  /// Alto máximo del diálogo
  final double? maxHeight;

  /// Texto del botón cerrar
  final String closeButtonText;

  /// Si el contenido es scrollable
  final bool scrollable;

  /// Padding del contenido
  final EdgeInsets contentPadding;

  /// Acciones adicionales a mostrar
  final List<DetailDialogAction> actions;

  /// Si mostrar botón de refrescar
  final bool showRefreshButton;

  const DetailDialogConfig({
    required this.title,
    this.icon,
    this.iconColor,
    this.maxWidth = 600,
    this.maxHeight,
    this.closeButtonText = 'Cerrar',
    this.scrollable = true,
    this.contentPadding = const EdgeInsets.all(20),
    this.actions = const [],
    this.showRefreshButton = false,
  });

  /// Copia la configuración con nuevos valores
  DetailDialogConfig copyWith({
    String? title,
    IconData? icon,
    Color? iconColor,
    double? maxWidth,
    double? maxHeight,
    String? closeButtonText,
    bool? scrollable,
    EdgeInsets? contentPadding,
    List<DetailDialogAction>? actions,
    bool? showRefreshButton,
  }) {
    return DetailDialogConfig(
      title: title ?? this.title,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight,
      closeButtonText: closeButtonText ?? this.closeButtonText,
      scrollable: scrollable ?? this.scrollable,
      contentPadding: contentPadding ?? this.contentPadding,
      actions: actions ?? this.actions,
      showRefreshButton: showRefreshButton ?? this.showRefreshButton,
    );
  }
}

/// Acción para diálogo de detalle
class DetailDialogAction {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDestructive;

  const DetailDialogAction({
    required this.label,
    this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });
}

/// Clase base abstracta para diálogos de solo lectura/detalle.
///
/// Implementa la estructura común:
/// - Header con título
/// - Contenido de solo lectura
/// - Footer con botón Cerrar y acciones opcionales
///
/// Uso:
/// ```dart
/// class AdvanceDetailDialog extends BaseDetailDialog {
///   final AdvancePayment advance;
///
///   const AdvanceDetailDialog({super.key, required this.advance});
///
///   @override
///   DetailDialogConfig get config => DetailDialogConfig(
///     title: 'Detalle del Anticipo',
///     actions: [
///       DetailDialogAction(
///         label: 'Aplicar',
///         icon: FluentIcons.accept,
///         isPrimary: true,
///         onPressed: () => _applyAdvance(),
///       ),
///     ],
///   );
///
///   @override
///   Widget buildContent(BuildContext context, WidgetRef ref) {
///     return Column(children: [
///       InfoRow(label: 'Monto', value: advance.amount.toCurrency()),
///       InfoRow(label: 'Fecha', value: advance.date.toDateString()),
///     ]);
///   }
/// }
/// ```
abstract class BaseDetailDialog extends ConsumerWidget {
  const BaseDetailDialog({super.key});

  /// Configuración del diálogo
  DetailDialogConfig get config;

  /// Construye el contenido del diálogo
  Widget buildContent(BuildContext context, WidgetRef ref);

  /// Widget opcional para el header (debajo del título)
  Widget? buildHeader(BuildContext context, WidgetRef ref) => null;

  /// Widget opcional para el footer (arriba de los botones)
  Widget? buildFooter(BuildContext context, WidgetRef ref) => null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: config.maxWidth,
        maxHeight: config.maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(config.title, style: theme.typography.subtitle),
          ),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header opcional
          if (buildHeader(context, ref) != null) ...[
            buildHeader(context, ref)!,
            const Divider(),
          ],
          // Contenido
          if (config.scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: config.contentPadding,
                child: buildContent(context, ref),
              ),
            )
          else
            Padding(
              padding: config.contentPadding,
              child: buildContent(context, ref),
            ),
          // Footer opcional
          if (buildFooter(context, ref) != null) ...[
            const Divider(),
            buildFooter(context, ref)!,
          ],
        ],
      ),
      actions: [
        // Acciones configuradas
        ...config.actions.map((action) {
          if (action.isPrimary) {
            return FilledButton(
              onPressed: action.onPressed,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action.icon != null) ...[
                    Icon(action.icon, size: 14),
                    const SizedBox(width: 8),
                  ],
                  Text(action.label),
                ],
              ),
            );
          }

          if (action.isDestructive) {
            return Button(
              onPressed: action.onPressed,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(Colors.red),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action.icon != null) ...[
                    Icon(action.icon, size: 14, color: Colors.red),
                    const SizedBox(width: 8),
                  ],
                  Text(action.label),
                ],
              ),
            );
          }

          return Button(
            onPressed: action.onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action.icon != null) ...[
                  Icon(action.icon, size: 14),
                  const SizedBox(width: 8),
                ],
                Text(action.label),
              ],
            ),
          );
        }),
        // Botón cerrar
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(config.closeButtonText),
        ),
      ],
    );
  }
}

/// Versión simplificada de BaseDetailDialog usando builder pattern
///
/// Uso:
/// ```dart
/// SimpleDetailDialog(
///   config: DetailDialogConfig(title: 'Detalles'),
///   builder: (context, ref) => Column(children: [...]),
/// )
/// ```
class SimpleDetailDialog extends ConsumerWidget {
  final DetailDialogConfig config;
  final Widget Function(BuildContext context, WidgetRef ref) builder;
  final Widget Function(BuildContext context, WidgetRef ref)? headerBuilder;
  final Widget Function(BuildContext context, WidgetRef ref)? footerBuilder;

  const SimpleDetailDialog({
    super.key,
    required this.config,
    required this.builder,
    this.headerBuilder,
    this.footerBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: config.maxWidth,
        maxHeight: config.maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      title: Text(config.title, style: theme.typography.subtitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headerBuilder != null) ...[
            headerBuilder!(context, ref),
            const Divider(),
          ],
          if (config.scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: config.contentPadding,
                child: builder(context, ref),
              ),
            )
          else
            Padding(
              padding: config.contentPadding,
              child: builder(context, ref),
            ),
          if (footerBuilder != null) ...[
            const Divider(),
            footerBuilder!(context, ref),
          ],
        ],
      ),
      actions: [
        ...config.actions.map((action) => Button(
              onPressed: action.onPressed,
              child: Text(action.label),
            )),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(config.closeButtonText),
        ),
      ],
    );
  }
}

/// Widget helper para mostrar información en filas dentro de diálogos de detalle
///
/// Uso:
/// ```dart
/// DetailInfoRow(label: 'Cliente', value: order.partnerName)
/// DetailInfoRow.money(label: 'Total', amount: order.total)
/// DetailInfoRow.date(label: 'Fecha', date: order.dateOrder)
/// ```
class DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final bool isHighlighted;
  final Widget? trailing;

  const DetailInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.isHighlighted = false,
    this.trailing,
  });

  /// Constructor para valores monetarios
  factory DetailInfoRow.money({
    Key? key,
    required String label,
    required double amount,
    String currencySymbol = '\$',
    bool isHighlighted = false,
  }) {
    return DetailInfoRow(
      key: key,
      label: label,
      value: amount.toCurrency(symbol: currencySymbol),
      isHighlighted: isHighlighted,
      valueStyle: const TextStyle(fontWeight: FontWeight.w600),
    );
  }

  /// Constructor para fechas
  factory DetailInfoRow.date({
    Key? key,
    required String label,
    required DateTime date,
    String format = 'dd/MM/yyyy',
    bool showTime = false,
  }) {
    final dateStr = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
    final timeStr = showTime
        ? ' ${date.hour.toString().padLeft(2, '0')}:'
            '${date.minute.toString().padLeft(2, '0')}'
        : '';
    return DetailInfoRow(
      key: key,
      label: label,
      value: '$dateStr$timeStr',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: labelStyle ??
                  theme.typography.body?.copyWith(
                    color: theme.inactiveColor,
                  ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  theme.typography.body?.copyWith(
                    fontWeight: isHighlighted ? FontWeight.w600 : null,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Sección dentro de un diálogo de detalle
///
/// Uso:
/// ```dart
/// DetailSection(
///   title: 'Información General',
///   children: [
///     DetailInfoRow(label: 'Nombre', value: 'Producto A'),
///     DetailInfoRow(label: 'Código', value: 'PROD001'),
///   ],
/// )
/// ```
class DetailSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final bool showDivider;

  const DetailSection({
    super.key,
    this.title,
    required this.children,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title!,
              style: theme.typography.bodyStrong,
            ),
          ),
        ...children,
        if (showDivider) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// =============================================================================
// ASYNC DETAIL DIALOG - Para diálogos que cargan datos asíncronamente
// =============================================================================

/// Diálogo de detalle con carga asíncrona de datos.
///
/// Maneja automáticamente estados de loading, error y data.
///
/// Uso:
/// ```dart
/// AsyncDetailDialog<Payment>(
///   config: DetailDialogConfig(title: 'Detalle del Cobro'),
///   asyncValue: ref.watch(paymentDetailProvider(id)),
///   onRefresh: () => ref.invalidate(paymentDetailProvider(id)),
///   notFoundMessage: 'Cobro no encontrado',
///   contentBuilder: (context, ref, payment) => Column(
///     children: [
///       DetailInfoRow(label: 'Monto', value: payment.amount.toCurrency()),
///     ],
///   ),
/// )
/// ```
class AsyncDetailDialog<T> extends ConsumerWidget {
  final DetailDialogConfig config;
  final AsyncValue<T?> asyncValue;
  final Widget Function(BuildContext context, WidgetRef ref, T data) contentBuilder;
  final Widget Function(BuildContext context, WidgetRef ref)? headerBuilder;
  final Widget Function(BuildContext context, WidgetRef ref, T data)? footerBuilder;
  final VoidCallback? onRefresh;
  final String notFoundMessage;
  final String errorPrefix;

  const AsyncDetailDialog({
    super.key,
    required this.config,
    required this.asyncValue,
    required this.contentBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.onRefresh,
    this.notFoundMessage = 'Registro no encontrado',
    this.errorPrefix = 'Error',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: config.maxWidth,
        maxHeight: config.maxHeight ?? MediaQuery.of(context).size.height * 0.9,
      ),
      title: Row(
        children: [
          if (config.icon != null) ...[
            Icon(config.icon, size: 24, color: config.iconColor ?? theme.accentColor),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(config.title, style: theme.typography.subtitle)),
          if (config.showRefreshButton && onRefresh != null)
            IconButton(
              icon: const Icon(FluentIcons.refresh, size: 16),
              onPressed: onRefresh,
            ),
        ],
      ),
      content: asyncValue.when(
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.error, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('$errorPrefix: $e', style: theme.typography.body),
              if (onRefresh != null) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: onRefresh,
                  child: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
        data: (data) {
          if (data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.search, size: 48, color: theme.inactiveColor),
                  const SizedBox(height: 12),
                  Text(notFoundMessage, style: theme.typography.body),
                ],
              ),
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header opcional
              if (headerBuilder != null) ...[
                headerBuilder!(context, ref),
                const Divider(),
              ],
              // Contenido
              if (config.scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: config.contentPadding,
                    child: contentBuilder(context, ref, data),
                  ),
                )
              else
                Padding(
                  padding: config.contentPadding,
                  child: contentBuilder(context, ref, data),
                ),
              // Footer opcional
              if (footerBuilder != null) ...[
                const Divider(),
                footerBuilder!(context, ref, data),
              ],
            ],
          );
        },
      ),
      actions: [
        // Acciones configuradas
        ...config.actions.map((action) {
          if (action.isPrimary) {
            return FilledButton(
              onPressed: action.onPressed,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action.icon != null) ...[
                    Icon(action.icon, size: 14),
                    const SizedBox(width: 8),
                  ],
                  Text(action.label),
                ],
              ),
            );
          }

          if (action.isDestructive) {
            return Button(
              onPressed: action.onPressed,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(Colors.red),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (action.icon != null) ...[
                    Icon(action.icon, size: 14, color: Colors.red),
                    const SizedBox(width: 8),
                  ],
                  Text(action.label),
                ],
              ),
            );
          }

          return Button(
            onPressed: action.onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action.icon != null) ...[
                  Icon(action.icon, size: 14),
                  const SizedBox(width: 8),
                ],
                Text(action.label),
              ],
            ),
          );
        }),
        // Botón cerrar
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(config.closeButtonText),
        ),
      ],
    );
  }
}
