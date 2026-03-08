import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/services/websocket/odoo_websocket_service.dart';
import '../widgets/dialogs/copyable_info_bar.dart';
import '../widgets/websocket_status_widget.dart';
import '../widgets/server_status_widget.dart';

/// Pantalla de debugging y monitoreo de WebSocket
class WebSocketDebugScreen extends ConsumerStatefulWidget {
  const WebSocketDebugScreen({super.key});

  @override
  ConsumerState<WebSocketDebugScreen> createState() =>
      _WebSocketDebugScreenState();
}

class _WebSocketDebugScreenState extends ConsumerState<WebSocketDebugScreen> {
  final List<Map<String, dynamic>> _messagesLog = [];
  final ScrollController _logScrollController = ScrollController();
  bool _showDetailedLog = false;
  int _messagesReceived = 0;
  int _messagesSent = 0;
  DateTime? _lastActivity;
  Timer? _refreshTimer;
  StreamSubscription<OdooWebSocketEvent>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _setupWebSocketListener();
    // Refresh UI every second to update connection status
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    _refreshTimer?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupWebSocketListener() {
    final wsService = ref.read(odooWebSocketServiceProvider);

    // Use typed event listener
    _notificationSubscription = wsService.addEventListener((event) {
      if (event is OdooRawNotificationEvent && mounted) {
        setState(() {
          _messagesReceived++;
          _lastActivity = DateTime.now();
          _messagesLog.insert(0, {
            'timestamp': DateTime.now(),
            'type': 'received',
            'data': {'type': event.type, 'payload': event.payload},
          });

          // Keep only last 100 messages
          if (_messagesLog.length > 100) {
            _messagesLog.removeRange(100, _messagesLog.length);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wsService = ref.watch(odooWebSocketServiceProvider);
    final isSmallScreen = MediaQuery.of(context).size.width < ScreenBreakpoints.mobileMaxWidth;

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < ScreenBreakpoints.mobileMaxWidth) {
              // En móviles: título arriba, indicador abajo
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Debugging WebSocket'),
                  const SizedBox(height: 8),
                  _buildStatusIndicator(wsService),
                ],
              );
            } else {
              // En pantallas grandes: todo en una fila
              return Row(
                children: [
                  const Text('Debugging WebSocket'),
                  const SizedBox(width: 16),
                  _buildStatusIndicator(wsService),
                ],
              );
            }
          },
        ),
        commandBar: isSmallScreen
            ? null // Ocultar CommandBar en móviles, usaremos botones en el contenido
            : CommandBar(
                mainAxisAlignment: MainAxisAlignment.end,
                primaryItems: [
                  CommandBarButton(
                    icon: const Icon(FluentIcons.plug_connected),
                    label: const Text('Conectar'),
                    onPressed: wsService.isConnected
                        ? null
                        : () => _connectWebSocket(wsService),
                  ),
                  CommandBarButton(
                    icon: const Icon(FluentIcons.sync),
                    label: const Text('Reconectar'),
                    onPressed: () => _reconnectWebSocket(wsService),
                  ),
                  CommandBarButton(
                    icon: const Icon(FluentIcons.clear),
                    label: const Text('Limpiar Log'),
                    onPressed: () => _clearLog(),
                  ),
                ],
              ),
      ),
      children: [
        // Botones de acción rápida para móviles
        if (isSmallScreen) ...[
          _buildMobileQuickActions(context, wsService),
          const SizedBox(height: 16),
        ],

        // Estado general de WebSocket
        Card(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      FluentIcons.plug_connected,
                      color: FluentTheme.of(context).accentColor,
                      size: isSmallScreen ? 18 : 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Estado de Conexión WebSocket',
                        style: FluentTheme.of(context).typography.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const WebSocketStatusWidget(showDetailed: true),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Estadísticas detalladas
        _buildDetailedStats(context, wsService, isSmallScreen),

        const SizedBox(height: 16),

        // Estado del servidor HTTP
        const ServerStatusWidget(showDetailed: true),

        const SizedBox(height: 16),

        // Información de canales disponibles
        _buildAvailableChannelsInfo(context, isSmallScreen),

        const SizedBox(height: 16),

        // Canales suscritos
        _buildSubscribedChannels(context, wsService, isSmallScreen),

        const SizedBox(height: 16),

        // Controles de conexión
        _buildConnectionControls(context, wsService, isSmallScreen),

        const SizedBox(height: 16),

        // Log de mensajes
        _buildMessagesLog(context, isSmallScreen),
      ],
    );
  }

  /// Build status indicator in header
  Widget _buildStatusIndicator(AppOdooWebSocketService wsService) {
    Color color = Colors.grey;
    IconData icon = FluentIcons.plug_disconnected;
    String text = 'Desconectado';

    if (wsService.isConnected) {
      color = Colors.green;
      icon = FluentIcons.completed;
      text = 'Conectado';
    } else if (wsService.reconnectAttempts > 0) {
      color = Colors.orange;
      icon = FluentIcons.sync;
      text = 'Reconectando...';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build mobile quick actions
  Widget _buildMobileQuickActions(
    BuildContext context,
    AppOdooWebSocketService wsService,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: wsService.isConnected
                  ? null
                  : () => _connectWebSocket(wsService),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.plug_connected, size: 16),
                  SizedBox(width: 4),
                  Text('Conectar'),
                ],
              ),
            ),
            Button(
              onPressed: () => _reconnectWebSocket(wsService),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.sync, size: 16),
                  SizedBox(width: 4),
                  Text('Reconectar'),
                ],
              ),
            ),
            Button(
              onPressed: () => _clearLog(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.clear, size: 16),
                  SizedBox(width: 4),
                  Text('Limpiar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build detailed statistics
  Widget _buildDetailedStats(
    BuildContext context,
    AppOdooWebSocketService wsService,
    bool isSmallScreen,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.chart,
                  color: FluentTheme.of(context).accentColor,
                  size: isSmallScreen ? 18 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estadísticas Detalladas',
                    style: FluentTheme.of(context).typography.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: isSmallScreen ? 8 : 16,
              runSpacing: isSmallScreen ? 8 : 16,
              children: [
                _buildMetric(
                  'Estado',
                  wsService.isConnected ? 'Conectado' : 'Desconectado',
                  wsService.isConnected ? Colors.green : Colors.red,
                  FluentIcons.plug_connected,
                  isSmallScreen: isSmallScreen,
                ),
                _buildMetric(
                  'URL',
                  wsService.connectionUrl ?? 'No disponible',
                  Colors.blue,
                  FluentIcons.link,
                  isSmallScreen: isSmallScreen,
                ),
                _buildMetric(
                  'Último Heartbeat',
                  wsService.lastHeartbeat?.toString().split('.').first ??
                      'Nunca',
                  Colors.purple,
                  FluentIcons.heart,
                  isSmallScreen: isSmallScreen,
                ),
                _buildMetric(
                  'Intentos Reconexión',
                  '${wsService.reconnectAttempts}',
                  Colors.orange,
                  FluentIcons.sync,
                  isSmallScreen: isSmallScreen,
                ),
                _buildMetric(
                  'Mensajes Recibidos',
                  '$_messagesReceived',
                  Colors.green,
                  FluentIcons.mail,
                  isSmallScreen: isSmallScreen,
                ),
                _buildMetric(
                  'Mensajes Enviados',
                  '$_messagesSent',
                  Colors.blue,
                  FluentIcons.send,
                  isSmallScreen: isSmallScreen,
                ),
                _buildMetric(
                  'Última Actividad',
                  _lastActivity?.toString().split('.').first ?? 'Nunca',
                  Colors.teal,
                  FluentIcons.recent,
                  isSmallScreen: isSmallScreen,
                ),
                _buildMetric(
                  'Canales',
                  '${wsService.subscribedChannels.length}',
                  Colors.magenta,
                  FluentIcons.streaming,
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
            if (wsService.lastError != null) ...[
              const SizedBox(height: 16),
              InfoBar(
                title: const Text('Último Error'),
                content: SelectableText(wsService.lastError!),
                severity: InfoBarSeverity.error,
                isLong: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build individual metric
  Widget _buildMetric(
    String title,
    String value,
    Color color,
    IconData icon, {
    bool isSmallScreen = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = isSmallScreen
            ? (constraints.maxWidth - 16) /
                  2.0 // 2 columnas en móviles
            : 200.0; // Ancho fijo en pantallas grandes

        return SizedBox(
          width: width,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  isSmallScreen && value.length > 30
                      ? SelectableText(
                          '${value.substring(0, 30)}...',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        )
                      : SelectableText(
                          value,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 11 : 13,
                          ),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Build available channels information
  Widget _buildAvailableChannelsInfo(BuildContext context, bool isSmallScreen) {
    final channelsInfo = [
      {
        'name': 'collection_config',
        'description': 'Configuración de cajas de cobro',
        'events': ['config_created', 'config_updated', 'config_deleted'],
        'color': Colors.blue,
      },
      {
        'name': 'collection_session',
        'description': 'Sesiones de cobro',
        'events': ['session_created', 'session_updated', 'session_closed'],
        'color': Colors.green,
      },
      {
        'name': 'res.partner',
        'description': 'Notificaciones de usuarios/partners',
        'events': ['partner_created', 'partner_updated'],
        'color': Colors.purple,
      },
      {
        'name': 'mail.channel',
        'description': 'Mensajes de canales de mail',
        'events': ['message_posted', 'channel_joined'],
        'color': Colors.orange,
      },
      {
        'name': 'odoo-activity-res.partner_{id}',
        'description': 'Actividades del partner (incremental sync)',
        'events': ['activity_created', 'activity_updated', 'activity_deleted'],
        'color': Colors.teal,
      },
    ];

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.info,
                  color: FluentTheme.of(context).accentColor,
                  size: isSmallScreen ? 18 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Canales Disponibles en Odoo',
                    style: FluentTheme.of(context).typography.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Patrón: {database}.{channel_name}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            ...channelsInfo.map((channel) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 60,
                      decoration: BoxDecoration(
                        color: channel['color'] as Color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channel['name'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            channel['description'] as String,
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: (channel['events'] as List<String>).map((
                              event,
                            ) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: (channel['color'] as Color).withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (channel['color'] as Color)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  event,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: channel['color'] as Color,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Build subscribed channels section
  Widget _buildSubscribedChannels(
    BuildContext context,
    AppOdooWebSocketService wsService,
    bool isSmallScreen,
  ) {
    final channels = wsService.subscribedChannels;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.streaming,
                  color: FluentTheme.of(context).accentColor,
                  size: isSmallScreen ? 18 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Canales Suscritos',
                    style: FluentTheme.of(context).typography.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${channels.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (channels.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(FluentIcons.streaming, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text('No hay canales suscritos'),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: channels.map((channel) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: FluentTheme.of(
                        context,
                      ).accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: FluentTheme.of(context).accentColor,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          FluentIcons.streaming,
                          size: 14,
                          color: FluentTheme.of(context).accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(channel, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  /// Build connection controls
  Widget _buildConnectionControls(
    BuildContext context,
    AppOdooWebSocketService wsService,
    bool isSmallScreen,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.settings,
                  color: FluentTheme.of(context).accentColor,
                  size: isSmallScreen ? 18 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Controles de Conexión',
                    style: FluentTheme.of(context).typography.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: wsService.isConnected
                      ? null
                      : () => _connectWebSocket(wsService),
                  child: Text(isSmallScreen ? 'Conectar' : 'Conectar'),
                ),
                Button(
                  onPressed: wsService.isConnected
                      ? () => _disconnectWebSocket(wsService)
                      : null,
                  child: Text(isSmallScreen ? 'Desconectar' : 'Desconectar'),
                ),
                Button(
                  onPressed: () => _reconnectWebSocket(wsService),
                  child: Text(isSmallScreen ? 'Reconectar' : 'Reconectar'),
                ),
                Button(
                  onPressed: () => _resetStats(),
                  child: Text(
                    isSmallScreen ? 'Resetear' : 'Resetear Estadísticas',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build messages log
  Widget _buildMessagesLog(BuildContext context, bool isSmallScreen) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  FluentIcons.view_all,
                  color: FluentTheme.of(context).accentColor,
                  size: isSmallScreen ? 18 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Log de Mensajes',
                    style: FluentTheme.of(context).typography.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ToggleSwitch(
                  checked: _showDetailedLog,
                  onChanged: (value) =>
                      setState(() => _showDetailedLog = value),
                  content: const Text('Detallado'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLogContent(context, isSmallScreen),
          ],
        ),
      ),
    );
  }

  /// Build log content
  Widget _buildLogContent(BuildContext context, bool isSmallScreen) {
    if (_messagesLog.isEmpty) {
      return SizedBox(
        height: isSmallScreen ? 150 : 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FluentIcons.view_all,
                size: isSmallScreen ? 36 : 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 8),
              const Text('No hay mensajes registrados'),
            ],
          ),
        ),
      );
    }

    return Container(
      height: isSmallScreen ? 250 : 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        controller: _logScrollController,
        itemCount: _messagesLog.length,
        itemBuilder: (context, index) {
          final message = _messagesLog[index];
          final timestamp = message['timestamp'] as DateTime;
          final type = message['type'] as String;
          final data = message['data'] as Map<String, dynamic>;

          Color typeColor = Colors.blue;
          IconData typeIcon = FluentIcons.mail;

          switch (type) {
            case 'received':
              typeColor = Colors.green;
              typeIcon = FluentIcons.download;
              break;
            case 'sent':
              typeColor = Colors.blue;
              typeIcon = FluentIcons.upload;
              break;
            case 'error':
              typeColor = Colors.red;
              typeIcon = FluentIcons.error;
              break;
          }

          return Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      typeIcon,
                      size: isSmallScreen ? 14 : 16,
                      color: typeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: typeColor,
                        fontSize: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 10 : 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_showDetailedLog) ...[
                  SelectableText(
                    const JsonEncoder.withIndent('  ').convert(data),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: isSmallScreen ? 9 : 11,
                    ),
                  ),
                ] else ...[
                  isSmallScreen
                      ? SelectableText(
                          _summarizeMessage(data).length > 50
                              ? '${_summarizeMessage(data).substring(0, 50)}...'
                              : _summarizeMessage(data),
                          style: const TextStyle(fontSize: 11),
                        )
                      : SelectableText(
                          _summarizeMessage(data),
                          style: const TextStyle(fontSize: 12),
                        ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// Summarize message for non-detailed view
  String _summarizeMessage(Map<String, dynamic> data) {
    if (data.containsKey('error')) {
      return 'Error: ${data['error']}';
    }

    final keys = data.keys.take(3).join(', ');
    return 'Campos: $keys...';
  }

  // WebSocket control methods
  void _connectWebSocket(AppOdooWebSocketService wsService) async {
    try {
      await wsService.connect();
      setState(() {
        _messagesSent++;
        _messagesLog.insert(0, {
          'timestamp': DateTime.now(),
          'type': 'sent',
          'data': {'action': 'connect'},
        });
      });

      if (mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Conexión Iniciada',
          message: 'Se ha iniciado la conexión WebSocket',
        );
      }
    } catch (e) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al conectar',
          message: '$e',
        );
      }
    }
  }

  void _disconnectWebSocket(AppOdooWebSocketService wsService) {
    try {
      wsService.disconnect();
      setState(() {
        _messagesSent++;
        _messagesLog.insert(0, {
          'timestamp': DateTime.now(),
          'type': 'sent',
          'data': {'action': 'disconnect'},
        });
      });

      if (mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Desconectado',
          message: 'WebSocket desconectado exitosamente',
        );
      }
    } catch (e) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al desconectar',
          message: '$e',
        );
      }
    }
  }

  void _reconnectWebSocket(AppOdooWebSocketService wsService) async {
    try {
      wsService.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
      await wsService.connect();
      setState(() {
        _messagesSent += 2;
        _messagesLog.insert(0, {
          'timestamp': DateTime.now(),
          'type': 'sent',
          'data': {'action': 'reconnect'},
        });
      });

      if (mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Reconectado',
          message: 'WebSocket reconectado exitosamente',
        );
      }
    } catch (e) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al reconectar',
          message: '$e',
        );
      }
    }
  }

  void _resetStats() {
    setState(() {
      _messagesReceived = 0;
      _messagesSent = 0;
      _lastActivity = null;
    });

    if (mounted) {
      CopyableInfoBar.showSuccess(
        context,
        title: 'Estadísticas Reseteadas',
        message: 'Las estadísticas han sido reiniciadas',
      );
    }
  }

  void _clearLog() {
    setState(() {
      _messagesLog.clear();
    });

    if (mounted) {
      CopyableInfoBar.showSuccess(
        context,
        title: 'Log Limpiado',
        message: 'El log de mensajes ha sido limpiado',
      );
    }
  }
}
