import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../core/services/websocket/odoo_websocket_service.dart';

/// Widget que muestra el estado de la conexión WebSocket
/// Puede mostrarse en modo compacto o detallado
class WebSocketStatusWidget extends ConsumerWidget {
  final bool showDetailed;

  const WebSocketStatusWidget({super.key, this.showDetailed = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wsService = ref.watch(odooWebSocketServiceProvider);

    if (showDetailed) {
      return _buildDetailedView(context, wsService);
    } else {
      return _buildCompactView(context, wsService);
    }
  }

  /// Vista compacta para barra de estado
  Widget _buildCompactView(
    BuildContext context,
    AppOdooWebSocketService wsService,
  ) {
    final isConnected = wsService.isConnected;
    final color = isConnected ? Colors.green : Colors.red;
    final icon = isConnected ? FluentIcons.completed : FluentIcons.error_badge;
    final text = isConnected ? 'Tiempo Real' : 'Sin Conexión';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Vista detallada con toda la información
  Widget _buildDetailedView(
    BuildContext context,
    AppOdooWebSocketService wsService,
  ) {
    final isConnected = wsService.isConnected;
    final color = isConnected ? Colors.green : Colors.red;

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isConnected ? FluentIcons.completed : FluentIcons.error_badge,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Estado de WebSocket',
                style: FluentTheme.of(context).typography.subtitle,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Estado de conexión
          _buildInfoSection('Información de Conexión', [
            _buildInfoRow(
              'Estado',
              isConnected ? 'Conectado' : 'Desconectado',
              color,
            ),
            _buildInfoRow('Conectando', wsService.isConnected ? 'No' : 'Sí'),
            _buildInfoRow('URL', wsService.connectionUrl ?? 'N/A'),
            if (wsService.lastError != null)
              _buildInfoRow('Último Error', wsService.lastError!, Colors.red),
          ]),

          const SizedBox(height: 12),

          // Canales suscritos
          _buildInfoSection('Canales Suscritos', [
            _buildInfoRow(
              'Total',
              wsService.subscribedChannels.length.toString(),
            ),
            ...wsService.subscribedChannels.map(
              (channel) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $channel', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // Heartbeat
          _buildInfoSection('Heartbeat', [
            _buildInfoRow(
              'Último Heartbeat',
              wsService.lastHeartbeat?.toString() ?? 'N/A',
            ),
            _buildInfoRow('Intervalo', '30 segundos'),
          ]),

          const SizedBox(height: 12),

          // Reconexión
          _buildInfoSection('Reconexión', [
            _buildInfoRow('Intentos', '${wsService.reconnectAttempts} / 5'),
          ]),

          const SizedBox(height: 12),

          // Últimas notificaciones
          _buildInfoSection('Última Notificación', [
            if (wsService.lastNotification != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: SelectableText(
                  _formatJson(wsService.lastNotification!),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ] else
              const Text('Sin notificaciones recientes'),
          ]),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: valueColor),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatJson(Map<String, dynamic> json) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }
}
