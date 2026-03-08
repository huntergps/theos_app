import 'package:fluent_ui/fluent_ui.dart';

/// Banner informativo para mostrar estado de conexión o sincronización
class SyncInfoBanner extends StatelessWidget {
  final String title;
  final String content;
  final InfoBarSeverity severity;
  final EdgeInsetsGeometry padding;

  const SyncInfoBanner({
    super.key,
    required this.title,
    required this.content,
    this.severity = InfoBarSeverity.info,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  /// Banner para mostrar estado sin conexión
  factory SyncInfoBanner.offline() {
    return const SyncInfoBanner(
      title: 'Sin conexion',
      content: 'Conecte al servidor Odoo para sincronizar datos',
      severity: InfoBarSeverity.warning,
    );
  }

  /// Banner para mostrar sincronización en progreso
  factory SyncInfoBanner.syncing({String? currentItem}) {
    return SyncInfoBanner(
      title: 'Sincronizacion en progreso',
      content: currentItem != null
          ? 'Sincronizando: $currentItem'
          : 'Puede navegar a otras pantallas, la sincronizacion continuara en segundo plano',
      severity: InfoBarSeverity.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: InfoBar(
        title: Text(title),
        content: Text(content),
        severity: severity,
        isLong: true,
      ),
    );
  }
}

/// Widget que muestra banners condicionales basados en el estado
class SyncStatusBanners extends StatelessWidget {
  final bool isOnline;
  final bool isAnySyncing;
  final String? currentSyncingItem;
  final String Function(String)? getItemDescription;

  const SyncStatusBanners({
    super.key,
    required this.isOnline,
    required this.isAnySyncing,
    this.currentSyncingItem,
    this.getItemDescription,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Banner de sin conexión
        if (!isOnline) SyncInfoBanner.offline(),

        // Banner de sincronización en progreso
        if (isAnySyncing)
          SyncInfoBanner.syncing(
            currentItem: currentSyncingItem != null && getItemDescription != null
                ? getItemDescription!(currentSyncingItem!)
                : null,
          ),
      ],
    );
  }
}
