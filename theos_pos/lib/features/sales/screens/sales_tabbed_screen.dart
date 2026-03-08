import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sale_order_tabs_provider.dart';
import 'sale_orders_list_screen.dart';
import 'sale_order_form/sale_order_form_screen.dart';
import 'sale_order_form/pdf_preview_screen.dart';

/// Pantalla principal de ventas con sistema de pestañas
///
/// Similar a Odoo 19.0, permite abrir múltiples órdenes en pestañas separadas.
/// La primera pestaña siempre es el listado de órdenes.
class SalesTabbedScreen extends ConsumerStatefulWidget {
  const SalesTabbedScreen({super.key});

  @override
  ConsumerState<SalesTabbedScreen> createState() => _SalesTabbedScreenState();
}

class _SalesTabbedScreenState extends ConsumerState<SalesTabbedScreen> {
  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(saleOrderTabsProvider);
    final theme = FluentTheme.of(context);

    return TabView(
      currentIndex: tabsState.currentIndex,
      onChanged: (index) {
        ref.read(saleOrderTabsProvider.notifier).setCurrentIndex(index);
      },
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
      closeButtonVisibility: CloseButtonVisibilityMode.always,
      showScrollButtons: true,
      onNewPressed: () {
        ref.read(saleOrderTabsProvider.notifier).openNewOrder();
      },
      onReorder: (oldIndex, newIndex) {
        // Por ahora no permitimos reordenar
      },
      tabs: tabsState.tabs.map((tab) {
        return Tab(
          key: ValueKey(tab.tabId),
          text: _buildTabText(tab, theme),
          icon: _buildTabIcon(tab),
          semanticLabel: tab.title,
          // onClosed null hace que no se muestre el botón de cerrar
          onClosed: tab.type == SaleOrderTabType.list
              ? null
              : () => _handleTabClose(tab),
          body: _buildTabBody(tab),
        );
      }).toList(),
    );
  }

  Widget _buildTabText(SaleOrderTab tab, FluentThemeData theme) {
    final text = tab.title;
    final hasChanges = tab.hasUnsavedChanges;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasChanges)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.accentColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        Text(
          text,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }

  Widget? _buildTabIcon(SaleOrderTab tab) {
    // Si está en modo edición, mostrar icono de edición
    if (tab.isEditing) {
      return const Icon(FluentIcons.edit, size: 14);
    }
    switch (tab.type) {
      case SaleOrderTabType.list:
        return const Icon(FluentIcons.list, size: 14);
      case SaleOrderTabType.view:
        return const Icon(FluentIcons.document, size: 14);
      case SaleOrderTabType.edit:
        return const Icon(FluentIcons.edit, size: 14);
      case SaleOrderTabType.newOrder:
        return const Icon(FluentIcons.add, size: 14);
      case SaleOrderTabType.pdfPreview:
        return const Icon(FluentIcons.pdf, size: 14);
    }
  }

  Widget _buildTabBody(SaleOrderTab tab) {
    switch (tab.type) {
      case SaleOrderTabType.list:
        return const SaleOrdersListContent();

      case SaleOrderTabType.view:
      case SaleOrderTabType.edit:
        if (tab.orderId == null) {
          return const Center(child: Text('Error: ID de orden no válido'));
        }
        // Pantalla unificada - usa key estable para evitar recreación al cambiar modo
        // El modo view/edit se maneja internamente por el form provider
        return SaleOrderFormScreen(
          key: ValueKey('order_${tab.orderId}'),
          orderId: tab.orderId!,
          isNew: false,
          startInEditMode: tab.isEditing || tab.type == SaleOrderTabType.edit,
        );

      case SaleOrderTabType.newOrder:
        return SaleOrderFormScreen(
          key: ValueKey('new_${tab.tabId}'),
          orderId: 0,
          isNew: true,
          startInEditMode: true,
        );

      case SaleOrderTabType.pdfPreview:
        // Estado de carga
        if (tab.isPdfLoading) {
          return _PdfLoadingView(title: tab.title);
        }
        // Estado de error
        if (tab.pdfError != null) {
          return _PdfErrorView(
            title: tab.title,
            error: tab.pdfError!,
            onClose: () => ref.read(saleOrderTabsProvider.notifier).closeTabById(tab.tabId),
          );
        }
        // PDF no disponible (fallback)
        if (tab.pdfBytes == null) {
          return const Center(child: Text('Error: PDF no disponible'));
        }
        // PDF listo
        return PdfPreviewScreen(
          key: ValueKey('pdf_${tab.tabId}'),
          pdfBytes: tab.pdfBytes!,
          title: tab.title,
          filename: tab.pdfFilename ?? 'documento.pdf',
        );
    }
  }

  Future<void> _handleTabClose(SaleOrderTab tab) async {
    if (tab.hasUnsavedChanges) {
      // Mostrar diálogo de confirmación
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Cambios sin guardar'),
          content: Text(
            '¿Deseas cerrar "${tab.title}"?\n\n'
            'Los cambios no guardados se perderán.',
          ),
          actions: [
            Button(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context, false),
            ),
            FilledButton(
              child: const Text('Cerrar sin guardar'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );

      if (result != true) return;
    }

    ref.read(saleOrderTabsProvider.notifier).closeTabById(tab.tabId);
  }
}

/// Contenido del listado de órdenes para usar dentro del TabView
class SaleOrdersListContent extends ConsumerWidget {
  const SaleOrdersListContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SaleOrdersScreen();
  }
}

/// Vista de carga mientras se genera el PDF
class _PdfLoadingView extends StatelessWidget {
  final String title;

  const _PdfLoadingView({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.pdf, size: 24, color: theme.accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.typography.subtitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ProgressRing(),
            const SizedBox(height: 24),
            Text(
              'Generando PDF...',
              style: theme.typography.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Por favor espere',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista de error cuando falla la generación del PDF
class _PdfErrorView extends StatelessWidget {
  final String title;
  final String error;
  final VoidCallback onClose;

  const _PdfErrorView({
    required this.title,
    required this.error,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            Icon(FluentIcons.pdf, size: 24, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.typography.subtitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      content: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.error_badge,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              Text(
                'Error al generar PDF',
                style: theme.typography.subtitle?.copyWith(
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(50)),
                ),
                child: SelectableText(
                  error,
                  style: theme.typography.body,
                ),
              ),
              const SizedBox(height: 24),
              Button(
                onPressed: onClose,
                child: const Text('Cerrar pestaña'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
