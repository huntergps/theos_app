import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CollectionSession;

import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/widgets/common/theos_info_bars.dart';

/// Tab para mostrar documentos relacionados con la sesion
/// Incluye ordenes, facturas y retenciones
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
    return TheosInfoBars.info(
      title: 'Documentos',
      message:
          'La lista detallada de documentos estará disponible próximamente. '
          'Por ahora se muestra el resumen con los totales de la sesión.',
    );
  }
}
