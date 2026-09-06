import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show ConnectivityStatus, ServerConnectionState;

import '../../core/constants/app_colors.dart';
import '../../core/services/platform/server_connectivity_service.dart';
import '../../features/sync/providers/offline_mode_providers.dart'
    show offlineModeConfigProvider;

/// Widget que muestra el estado de conexión del servidor Odoo
/// Puede mostrarse en modo compacto (para barra de estado) o detallado
class ServerStatusWidget extends ConsumerWidget {
  final bool showDetailed;
  final bool showLatency;

  const ServerStatusWidget({
    super.key,
    this.showDetailed = false,
    this.showLatency = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if offline mode is manually enabled
    final offlineModeConfig = ref.watch(offlineModeConfigProvider);
    final isOfflineModeManual = offlineModeConfig.maybeWhen(
      data: (config) => config.isEnabled,
      orElse: () => false,
    );

    // If offline mode is manually enabled, show that instead of server status
    if (isOfflineModeManual) {
      return _buildOfflineModeView(context);
    }

    // Watch the stream provider for reactive updates
    final statusAsync = ref.watch(connectivityStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (showDetailed) {
          return _buildDetailedView(context, status);
        } else {
          return _buildCompactView(context, status);
        }
      },
      loading: () => _buildCompactView(
        context,
        const ConnectivityStatus(), // Default status while loading
      ),
      error: (_, _) => _buildCompactView(
        context,
        const ConnectivityStatus(serverState: ServerConnectionState.unknown),
      ),
    );
  }

  /// Vista cuando el modo offline está activado manualmente
  Widget _buildOfflineModeView(BuildContext context) {
    final color = FluentTheme.of(context).accentColor;
    return Semantics(
      label: 'Modo Offline',
      child: Tooltip(
        message: 'Modo offline activado manualmente.\nLos datos se guardan localmente.',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.cloud_download, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                'Modo Offline',
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vista compacta para barra de estado
  Widget _buildCompactView(BuildContext context, ConnectivityStatus status) {
    final (color, icon, text) = _getStatusDisplay(status);

    return Semantics(
      label: text,
      child: Tooltip(
        message: _getTooltipMessage(status),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              if (showLatency && status.latencyMs != null) ...[
                const SizedBox(width: 4),
                Text(
                  '${status.latencyMs}ms',
                  style: TextStyle(color: color.withValues(alpha: 0.7)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Vista detallada con toda la información
  Widget _buildDetailedView(BuildContext context, ConnectivityStatus status) {
    final (color, icon, text) = _getStatusDisplay(status);

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Estado del Servidor',
                style: FluentTheme.of(context).typography.subtitle,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  text,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Details
          _buildDetailRow(
            context,
            'Estado HTTP',
            _getServerStateText(status.serverState),
            _getServerStateColor(status.serverState),
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            context,
            'Sesión',
            status.sessionValid ? 'Válida' : 'Expirada',
            status.sessionValid ? AppColors.success : AppColors.danger,
          ),

          if (status.latencyMs != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              'Latencia',
              '${status.latencyMs} ms',
              _getLatencyColor(status.latencyMs!),
            ),
          ],

          if (status.consecutiveFailures > 0) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              'Fallos consecutivos',
              '${status.consecutiveFailures}',
              AppColors.warning,
            ),
          ],

          if (status.lastOnlineAt != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              context,
              'Última vez online',
              _formatDateTime(status.lastOnlineAt!),
              AppColors.textSecondary,
            ),
          ],

          if (status.lastError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                status.lastError!.length > 100
                    ? '${status.lastError!.substring(0, 100)}...'
                    : status.lastError!,
                style: FluentTheme.of(context).typography.caption
                    ?.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: FluentTheme.of(context).resources.textFillColorSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }

  (Color, IconData, String) _getStatusDisplay(ConnectivityStatus status) {
    if (!status.hasNetwork) {
      return (AppColors.textSecondary, FluentIcons.globe, 'Sin Red');
    }

    return switch (status.serverState) {
      ServerConnectionState.online => (
        AppColors.success,
        FluentIcons.cloud,
        'Online',
      ),
      ServerConnectionState.degraded => (
        AppColors.warning,
        FluentIcons.warning,
        'Degradado',
      ),
      ServerConnectionState.unreachable => (
        AppColors.danger,
        FluentIcons.cloud_not_synced,
        'Inalcanzable',
      ),
      ServerConnectionState.maintenance => (
        AppColors.warning,
        FluentIcons.repair,
        'Mantenimiento',
      ),
      ServerConnectionState.sessionExpired => (
        AppColors.danger,
        FluentIcons.lock,
        'Sesión Expirada',
      ),
      ServerConnectionState.unknown => (
        AppColors.textSecondary,
        FluentIcons.sync,
        'Verificando...',
      ),
    };
  }

  String _getServerStateText(ServerConnectionState state) {
    return switch (state) {
      ServerConnectionState.online => 'En línea',
      ServerConnectionState.degraded => 'Degradado',
      ServerConnectionState.unreachable => 'Inalcanzable',
      ServerConnectionState.maintenance => 'En mantenimiento',
      ServerConnectionState.sessionExpired => 'Sesión expirada',
      ServerConnectionState.unknown => 'Desconocido',
    };
  }

  Color _getServerStateColor(ServerConnectionState state) {
    return switch (state) {
      ServerConnectionState.online => AppColors.success,
      ServerConnectionState.degraded => AppColors.warning,
      ServerConnectionState.unreachable => AppColors.danger,
      ServerConnectionState.maintenance => AppColors.warning,
      ServerConnectionState.sessionExpired => AppColors.danger,
      ServerConnectionState.unknown => AppColors.textSecondary,
    };
  }

  Color _getLatencyColor(int latencyMs) {
    if (latencyMs < 100) return AppColors.success;
    if (latencyMs < 300) return AppColors.warning;
    return AppColors.danger;
  }

  String _getTooltipMessage(ConnectivityStatus status) {
    final buffer = StringBuffer();

    buffer.writeln('Servidor: ${_getServerStateText(status.serverState)}');
    if (status.latencyMs != null) {
      buffer.writeln('Latencia: ${status.latencyMs}ms');
    }

    if (status.consecutiveFailures > 0) {
      buffer.writeln('Fallos: ${status.consecutiveFailures}');
    }

    return buffer.toString().trim();
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Hace ${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Widget combinado que muestra el estado autenticado del servidor.
class ConnectionStatusBar extends ConsumerWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [ServerStatusWidget(showLatency: true), SizedBox(width: 8)],
    );
  }
}
