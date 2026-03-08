import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CollectionSession;

import '../../../../../core/theme/spacing.dart';

/// Tab para mostrar documentos relacionados con la sesion
/// Incluye ordenes, facturas y retenciones
///
/// Nota: Actualmente muestra solo resumen de contadores.
/// La lista detallada de documentos requiere implementación de endpoints
/// en el backend para obtener las órdenes y facturas específicas de la sesión.
class DocumentosTab extends StatelessWidget {
  final CollectionSession session;

  const DocumentosTab({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return _buildContent(context, theme);
  }

  Widget _buildContent(BuildContext context, FluentThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de documentos
          _buildSummaryCard(theme),
          const SizedBox(height: Spacing.md),

          // Nota sobre funcionalidad pendiente
          _buildPendingFeatureNote(theme),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(FluentThemeData theme) {
    return Card(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  FluentIcons.document_set,
                  color: theme.accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                'Resumen de Documentos',
                style: theme.typography.subtitle,
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.md,
            runSpacing: Spacing.md,
            children: [
              _buildStatCard(
                theme,
                icon: FluentIcons.shopping_cart,
                label: 'Órdenes de Venta',
                count: session.orderCount,
                color: Colors.blue,
              ),
              _buildStatCard(
                theme,
                icon: FluentIcons.document,
                label: 'Facturas Emitidas',
                count: session.invoiceCount,
                color: Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    FluentThemeData theme, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: Spacing.xs),
          Text(
            label,
            style: theme.typography.caption,
          ),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: theme.typography.title?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingFeatureNote(FluentThemeData theme) {
    return InfoBar(
      title: const Text('Lista detallada pendiente'),
      content: const Text(
        'La visualización detallada de órdenes de venta y facturas asociadas '
        'a esta sesión requiere implementación de endpoints adicionales en el backend.\n\n'
        'Actualmente se muestra el resumen con contadores totales.',
      ),
      severity: InfoBarSeverity.info,
    );
  }
}
