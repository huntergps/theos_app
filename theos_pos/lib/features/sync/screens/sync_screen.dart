import 'package:flutter/foundation.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/database_helper_file_ops.dart'
    if (dart.library.js_interop) '../../../core/database/database_helper_file_ops_stub.dart'
    as file_ops;
import '../../../core/database/repositories/repository_providers.dart';
import '../../../shared/providers/offline_queue_provider.dart';
import '../../../shared/utils/platform_process.dart' as platform_process;
import '../providers/sync_provider.dart';
import '../widgets/offline_mode_section.dart';
import '../widgets/stock_changes_section.dart';
import '../widgets/sync_widgets.dart';

/// Screen for manual catalog synchronization
///
/// Uses SyncNotifier provider to persist sync state across navigation.
/// Sync operations continue running even when navigating away from this screen.
class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}


class _SyncScreenState extends ConsumerState<SyncScreen> {
  /// Database path (loaded asynchronously)
  String? _databasePath;

  /// Icon mapping for each sync item
  static final Map<String, IconData> _iconMap = {
    'products': FluentIcons.product,
    'categories': FluentIcons.folder_list,
    'taxes': FluentIcons.money,
    'uom': FluentIcons.calculator,
    'product_uom': FluentIcons.contact_card,
    'pricelists': FluentIcons.tag,
    'payment_terms': FluentIcons.calendar,
    'partners': FluentIcons.people,
    'sale_orders': FluentIcons.shopping_cart,
    // System catalogs
    'users': FluentIcons.contact,
    'groups': FluentIcons.permissions,
    'warehouses': FluentIcons.home,
    'teams': FluentIcons.group,
    'fiscal_positions': FluentIcons.bank,
    'journals': FluentIcons.dictionary,
    // Collection catalogs
    'collection_configs': FluentIcons.settings,
    'cash_out_types': FluentIcons.money,
    // Company configuration
    'company': FluentIcons.org,
    // System reference data
    'countries': FluentIcons.globe,
    'country_states': FluentIcons.map_pin,
    'languages': FluentIcons.locale_language,
    // QWeb Templates
    'qweb_templates': FluentIcons.document_management,
  };

  /// Help items data
  static const List<_HelpItemData> _helpItems = [
    _HelpItemData(
      icon: FluentIcons.sync,
      title: 'Sincronizar Todo',
      description: 'Sincroniza todos los catalogos de forma incremental',
    ),
    _HelpItemData(
      icon: FluentIcons.refresh,
      title: 'Forzar Sync Completo',
      description: 'Descarga todos los registros desde cero',
    ),
    _HelpItemData(
      icon: FluentIcons.delete,
      title: 'Vaciar Tablas',
      description: 'Elimina todos los datos locales de los catalogos',
    ),
    _HelpItemData(
      icon: FluentIcons.product,
      title: 'Productos',
      description: 'Productos, precios, codigos de barras',
    ),
    _HelpItemData(
      icon: FluentIcons.people,
      title: 'Clientes/Proveedores',
      description: 'Contactos con RUC, direccion, email',
    ),
    _HelpItemData(
      icon: FluentIcons.shopping_cart,
      title: 'Ordenes de Venta',
      description: 'Ordenes existentes con sus lineas',
    ),
    _HelpItemData(
      icon: FluentIcons.back,
      title: 'Segundo plano',
      description:
          'La sincronizacion continua aunque navegue a otras pantallas',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Load database path and refresh local counts when entering the screen
    Future.microtask(() {
      if (!mounted) return;
      _loadDatabasePath();
      ref.read(syncProvider.notifier).refreshLocalCounts();
      ref.read(offlineQueueProvider.notifier).refresh();
    });
  }

  Future<void> _loadDatabasePath() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() => _databasePath = 'Web/Memory Database');
      }
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      // Use the actual database name from DatabaseHelper
      final currentDbName = DatabaseHelper.currentDatabaseName ?? 'theos_pos_db';
      final dbPath = '${directory.path}/$currentDbName.sqlite';
      if (mounted) {
        setState(() {
          _databasePath = dbPath;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _databasePath = 'Unknown';
        });
      }
    }
  }

  Future<void> _copyDatabasePath() async {
    if (_databasePath != null) {
      await Clipboard.setData(ClipboardData(text: _databasePath!));
      if (mounted) {
        context.showSyncSuccess('Ruta copiada al portapapeles');
      }
    }
  }

  Future<void> _openDatabaseFolder() async {
    if (!kIsWeb && _databasePath != null && defaultTargetPlatform == TargetPlatform.macOS) {
      final directory = _databasePath!.substring(
        0,
        _databasePath!.lastIndexOf('/'),
      );
      await platform_process.openDirectory(directory);
    }
  }

  String _getItemDescription(String name) {
    final item = SyncNotifier.syncItems.firstWhere(
      (i) => i.name == name,
      orElse: () => SyncNotifier.syncItems.first,
    );
    return item.description;
  }

  Future<void> _handleForceFullSync() async {
    final confirmed = await SyncDialogs.confirmForceFullSync(context);
    if (!confirmed || !mounted) return;

    // 1. First process offline queue (Local → Odoo)
    final queueNotifier = ref.read(offlineQueueProvider.notifier);
    final queueResult = await queueNotifier.processQueue();

    // 2. Then force full sync catalogs (Odoo → Local)
    await ref.read(syncProvider.notifier).forceFullSyncAll();

    if (mounted) {
      if (queueResult.synced > 0 || queueResult.failed > 0) {
        context.showSyncSuccess(
          'Sincronizacion completa finalizada. Cola: ${queueResult.synced} OK, ${queueResult.failed} errores',
        );
      } else {
        context.showSyncSuccess('Sincronizacion completa finalizada');
      }
    }
  }

  Future<void> _handleSyncAll() async {
    final confirmed = await SyncDialogs.confirmSyncAll(context);
    if (!confirmed || !mounted) return;

    // 1. First process offline queue (Local → Odoo)
    final queueNotifier = ref.read(offlineQueueProvider.notifier);
    final queueResult = await queueNotifier.processQueue();

    // 2. Then sync catalogs (Odoo → Local)
    await ref.read(syncProvider.notifier).syncAll();

    if (mounted) {
      if (queueResult.synced > 0 || queueResult.failed > 0) {
        context.showSyncSuccess(
          'Sincronizacion completada. Cola: ${queueResult.synced} OK, ${queueResult.failed} errores',
        );
      } else {
        context.showSyncSuccess('Sincronizacion completada');
      }
    }
  }

  Future<void> _handleClearAllTables() async {
    final confirmed = await SyncDialogs.confirmClearAllTables(context);
    if (!confirmed || !mounted) return;

    try {
      final results = await ref.read(syncProvider.notifier).clearAllTables();
      if (mounted) {
        final total = results.values.fold<int>(0, (sum, count) => sum + count);
        context.showSyncSuccess('Se eliminaron $total registros locales');
      }
    } catch (e) {
      if (mounted) {
        context.showSyncError('Error al vaciar tablas: $e');
      }
    }
  }

  Future<void> _handleClearTable(
    String itemName,
    String description,
    int localCount,
  ) async {
    final confirmed = await SyncDialogs.confirmClearTable(
      context: context,
      description: description,
      localCount: localCount,
    );
    if (!confirmed || !mounted) return;

    try {
      final count = await ref.read(syncProvider.notifier).clearTable(itemName);
      if (mounted) {
        context.showSyncSuccess(
          'Se eliminaron $count registros de $description',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSyncError('Error al vaciar tabla: $e');
      }
    }
  }

  Future<void> _handleDeleteDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('¿Eliminar Base de Datos?'),
        content: const Text(
          'Esta acción eliminará todos los datos locales y la aplicación se cerrará o reiniciará. '
          'Perderá cualquier cambio no sincronizado.\n\n'
          'Use esto solo si tiene problemas graves de sincronización o base de datos corrupta.',
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Colors.red)),
            child: const Text('Eliminar Todo'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: ProgressRing()),
        );
      }

      // Close DB connection and reset providers
      ref.read(databaseHelperProvider.notifier).set(null);
      await DatabaseHelper.closeAndReset();

      // Delete files
      if (_databasePath != null) {
        await file_ops.deleteFileAt(_databasePath!);
        // Try to delete journal files too
        await file_ops.deleteFileAt('$_databasePath-journal');
        await file_ops.deleteFileAt('$_databasePath-shm');
        await file_ops.deleteFileAt('$_databasePath-wal');
      }

      // Re-initialize database and providers
      await DatabaseHelper.initialize();
      if (mounted) {
        ref.read(databaseHelperProvider.notifier).set(DatabaseHelper.instance);
      }

      if (mounted) {
        Navigator.pop(context); // Close loading

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => ContentDialog(
            title: const Text('Base de datos eliminada'),
            content: const Text(
              'La base de datos ha sido eliminada y recreada correctamente. '
              'Puede continuar utilizando la aplicación.',
            ),
            actions: [
              FilledButton(
                child: const Text('Entendido'),
                onPressed: () {
                  Navigator.pop(context);
                  // Reset path display
                  setState(() {
                    _databasePath = null;
                  });
                  // Trigger reload
                  _loadDatabasePath();
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Close loading if open
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.settings.name != null);
        context.showSyncError('Error al eliminar base de datos: $e');

        // Try to recover by re-initializing anyway
        try {
          await DatabaseHelper.initialize();
          ref
              .read(databaseHelperProvider.notifier)
              .set(DatabaseHelper.instance);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final syncState = ref.watch(syncProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    final catalogSync = ref.watch(catalogSyncRepositoryProvider);
    final isOnline = catalogSync?.isOnline ?? false;

    return ScaffoldPage.scrollable(
      header: PageHeader(
        title: const Text('Sincronizacion de Datos'),
        commandBar: _SyncCommandBar(
          isAnySyncing: syncState.isAnySyncing,
          isOnline: isOnline,
          onCancel: () {
            syncNotifier.cancelSync();
            if (context.mounted) {
              context.showSyncError('Sincronizacion cancelada');
            }
          },
          onClearAll: _handleClearAllTables,
          onForceSync: _handleForceFullSync,
          onSyncAll: _handleSyncAll,
        ),
      ),
      children: [
        // Database path display
        _DatabasePathDisplay(
          databasePath: _databasePath,
          onCopy: _copyDatabasePath,
          onOpenFolder: _openDatabaseFolder,
          onDelete: _handleDeleteDatabase,
        ),
        const SizedBox(height: 16),

        // Status banners
        SyncStatusBanners(
          isOnline: isOnline,
          isAnySyncing: syncState.isAnySyncing,
          currentSyncingItem: syncState.currentSyncingItem,
          getItemDescription: _getItemDescription,
        ),

        // Offline Mode Toggle Section (FASE 4)
        const SizedBox(height: 24),
        Card(
          padding: const EdgeInsets.all(16),
          child: const OfflineModeSection(),
        ),
        const SizedBox(height: 16),

        // Stock Changes Section (M7 FASE 3)
        const StockChangesSection(),
        const Divider(),
        const SizedBox(height: 16),

        // Info text
        _SyncDescription(theme: theme),
        const SizedBox(height: 24),

        // Sync items grid
        _SyncItemsGrid(
          syncState: syncState,
          isOnline: isOnline,
          iconMap: _iconMap,
          onSync: (itemName) {
            if (!isOnline) {
              context.showSyncError(
                'Sin conexion a Odoo. Conecte al servidor primero.',
              );
              return;
            }
            syncNotifier.syncItem(itemName);
          },
          onForceSync: (itemName) {
            if (!isOnline) {
              context.showSyncError(
                'Sin conexion a Odoo. Conecte al servidor primero.',
              );
              return;
            }
            syncNotifier.forceFullSyncItem(itemName);
          },
          onClear: (itemName, description, localCount) {
            _handleClearTable(itemName, description, localCount);
          },
          onCancel: (itemName, description) {
            syncNotifier.cancelItemSync(itemName);
            context.showSyncError('Sincronizacion de $description cancelada');
          },
        ),

        const SizedBox(height: 32),

        // Help section
        _HelpSection(helpItems: _helpItems),
      ],
    );
  }
}

/// Barra de comandos superior
class _SyncCommandBar extends StatelessWidget {
  final bool isAnySyncing;
  final bool isOnline;
  final VoidCallback onCancel;
  final VoidCallback onClearAll;
  final VoidCallback onForceSync;
  final VoidCallback onSyncAll;

  const _SyncCommandBar({
    required this.isAnySyncing,
    required this.isOnline,
    required this.onCancel,
    required this.onClearAll,
    required this.onForceSync,
    required this.onSyncAll,
  });

  @override
  Widget build(BuildContext context) {
    return CommandBar(
      mainAxisAlignment: MainAxisAlignment.end,
      primaryItems: [
        if (isAnySyncing)
          CommandBarButton(
            icon: const Icon(FluentIcons.cancel),
            label: const Text('Cancelar'),
            onPressed: onCancel,
          ),
        if (!isAnySyncing) ...[
          CommandBarButton(
            icon: const Icon(FluentIcons.delete),
            label: const Text('Vaciar Tablas'),
            onPressed: onClearAll,
          ),
          CommandBarButton(
            icon: const Icon(FluentIcons.refresh),
            label: const Text('Forzar Sync Completo'),
            onPressed: isOnline ? onForceSync : null,
          ),
          CommandBarButton(
            icon: const Icon(FluentIcons.sync),
            label: const Text('Sincronizar Todo'),
            onPressed: isOnline ? onSyncAll : null,
          ),
        ],
      ],
    );
  }
}

/// Descripción de la pantalla de sincronización
class _SyncDescription extends StatelessWidget {
  final FluentThemeData theme;

  const _SyncDescription({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sincronice los catalogos maestros desde el servidor Odoo. '
      'Los datos se guardaran localmente para uso offline. '
      'La sincronizacion incremental solo descarga registros modificados.',
      style: theme.typography.body?.copyWith(
        color: theme.resources.textFillColorSecondary,
      ),
    );
  }
}

/// Grid de items de sincronización
class _SyncItemsGrid extends StatelessWidget {
  final SyncScreenState syncState;
  final bool isOnline;
  final Map<String, IconData> iconMap;
  final void Function(String itemName) onSync;
  final void Function(String itemName) onForceSync;
  final void Function(String itemName, String description, int localCount)
  onClear;
  final void Function(String itemName, String description) onCancel;

  const _SyncItemsGrid({
    required this.syncState,
    required this.isOnline,
    required this.iconMap,
    required this.onSync,
    required this.onForceSync,
    required this.onClear,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth > ScreenBreakpoints.tabletSmallWidth
            ? 3
            : constraints.maxWidth > ScreenBreakpoints.mobileMaxWidth
            ? 2
            : 1;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: SyncNotifier.syncItems.map((itemDef) {
            final state = syncState.getItemState(itemDef.name);
            final cardWidth =
                (constraints.maxWidth - (crossAxisCount - 1) * 16) /
                crossAxisCount;

            return SizedBox(
              width: cardWidth.clamp(200.0, 400.0),
              child: SyncItemCard(
                name: itemDef.name,
                description: itemDef.description,
                icon: iconMap[itemDef.name] ?? FluentIcons.sync,
                state: state,
                isOnline: isOnline,
                isSyncingAll: syncState.isSyncingAll,
                onSync: () => onSync(itemDef.name),
                onForceSync: () => onForceSync(itemDef.name),
                onClear: () => onClear(
                  itemDef.name,
                  itemDef.description,
                  state.localCount,
                ),
                onCancel: () => onCancel(itemDef.name, itemDef.description),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Sección de ayuda
class _HelpSection extends StatelessWidget {
  final List<_HelpItemData> helpItems;

  const _HelpSection({required this.helpItems});

  @override
  Widget build(BuildContext context) {
    return Expander(
      header: const Text('Ayuda'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: helpItems
            .map(
              (item) => SyncHelpItem(
                icon: item.icon,
                title: item.title,
                description: item.description,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Datos para un item de ayuda
class _HelpItemData {
  final IconData icon;
  final String title;
  final String description;

  const _HelpItemData({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Widget para mostrar la ruta de la base de datos con opciones de copia
class _DatabasePathDisplay extends StatelessWidget {
  final String? databasePath;
  final VoidCallback onCopy;
  final VoidCallback onOpenFolder;
  final VoidCallback onDelete;

  const _DatabasePathDisplay({
    required this.databasePath,
    required this.onCopy,
    required this.onOpenFolder,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: theme.resources.cardBackgroundFillColorDefault,
      child: Row(
        children: [
          Icon(
            FluentIcons.database,
            size: 16,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'Base de datos:',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: databasePath != null
                ? Text(
                    databasePath!,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorPrimary,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : const ProgressRing(strokeWidth: 2),
          ),
          if (databasePath != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Copiar ruta',
              child: IconButton(
                icon: const Icon(FluentIcons.copy, size: 14),
                onPressed: onCopy,
              ),
            ),
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux))
              Tooltip(
                message: 'Abrir carpeta',
                child: IconButton(
                  icon: const Icon(
                    FluentIcons.open_folder_horizontal,
                    size: 14,
                  ),
                  onPressed: onOpenFolder,
                ),
              ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Eliminar Base de Datos (Reset)',
              child: IconButton(
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(Colors.red),
                ),
                icon: const Icon(FluentIcons.delete, size: 14),
                onPressed: onDelete,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

