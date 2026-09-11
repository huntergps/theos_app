import 'package:flutter/material.dart';

import '../components/orbi_brand.dart';

/// A navigation entry supplied by the active capability catalog.
final class OperationalDestination {
  const OperationalDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.group,
  });

  final String label;
  final String path;
  final IconData icon;
  final String group;
}

/// Server and session context rendered by [OperationalShell].
final class OperationalContext {
  const OperationalContext({
    required this.server,
    required this.database,
    required this.userLabel,
    required this.companyLabel,
    this.serverTime,
    required this.connectionLabel,
    required this.syncLabel,
  });

  final String server;
  final String database;
  final String userLabel;
  final String companyLabel;
  final String? serverTime;
  final String connectionLabel;
  final String syncLabel;
}

/// Shared operational frame. It deliberately owns no router, provider, or data
/// source: callers provide destinations and handle navigation/capabilities.
final class OperationalShell extends StatelessWidget {
  const OperationalShell({
    super.key,
    required this.child,
    required this.destinations,
    required this.selectedPath,
    required this.onNavigate,
    required this.context,
    required this.onLogout,
  });

  final Widget child;
  final List<OperationalDestination> destinations;
  final String selectedPath;
  final ValueChanged<String> onNavigate;
  final OperationalContext context;
  final VoidCallback onLogout;

  bool _isDesktop(BoxConstraints constraints) =>
      constraints.maxWidth >= 1200 &&
      constraints.maxWidth >= constraints.maxHeight;

  @override
  Widget build(BuildContext buildContext) => LayoutBuilder(
    builder: (buildContext, constraints) {
      final desktop = _isDesktop(constraints);
      final footer =
          constraints.maxWidth >= 600 &&
          constraints.maxWidth >= constraints.maxHeight;
      return Scaffold(
        drawer: desktop ? null : _navigationDrawer(buildContext),
        appBar: _appBar(buildContext, desktop),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (desktop) _sidebar(buildContext),
                    Expanded(child: child),
                  ],
                ),
              ),
              if (footer)
                _contextFooter(buildContext)
              else
                _compactContextButton(buildContext),
            ],
          ),
        ),
      );
    },
  );

  PreferredSizeWidget _appBar(BuildContext context, bool desktop) => AppBar(
    automaticallyImplyLeading: !desktop,
    titleSpacing: desktop ? 20 : null,
    title: Row(
      children: [
        OrbiBrand(height: 32, color: Theme.of(context).colorScheme.onSurface),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            this.context.companyLabel,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    ),
    actions: [
      if (desktop)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Center(child: Text(this.context.userLabel)),
        ),
      IconButton(
        key: const Key('logout-button'),
        tooltip: 'Cerrar sesión',
        icon: const Icon(Icons.logout),
        onPressed: onLogout,
      ),
    ],
  );

  Widget _sidebar(BuildContext context) => SizedBox(
    width: 256,
    child: Semantics(
      container: true,
      label: 'Navegación principal',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: _navigationTiles(context),
        ),
      ),
    ),
  );

  Widget _navigationDrawer(BuildContext context) => Drawer(
    child: SafeArea(
      child: Builder(
        builder: (drawerContext) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
              child: Text(
                this.context.companyLabel,
                style: Theme.of(drawerContext).textTheme.titleMedium,
              ),
            ),
            ..._navigationTiles(drawerContext),
          ],
        ),
      ),
    ),
  );

  List<Widget> _navigationTiles(BuildContext context) {
    final grouped = <String, List<OperationalDestination>>{};
    for (final destination in destinations) {
      grouped.putIfAbsent(destination.group, () => []).add(destination);
    }
    return [
      for (final entry in grouped.entries) ...[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 4),
          child: Text(entry.key, style: Theme.of(context).textTheme.labelLarge),
        ),
        for (final destination in entry.value)
          Semantics(
            container: true,
            button: true,
            selected: destination.path == selectedPath,
            label: destination.label,
            child: ListTile(
              selected: destination.path == selectedPath,
              leading: Icon(destination.icon, semanticLabel: ''),
              title: Text(destination.label),
              onTap: () {
                final scaffold = Scaffold.maybeOf(context);
                if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
                onNavigate(destination.path);
              },
            ),
          ),
      ],
    ];
  }

  Widget _contextFooter(BuildContext context) => Semantics(
    container: true,
    label: 'Información de conexión',
    child: SizedBox(
      width: double.infinity,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Wrap(
            spacing: 20,
            runSpacing: 4,
            children: [
              _contextItem('Servidor', this.context.server),
              _contextItem('BD', this.context.database),
              _contextItem(
                'Hora del servidor',
                this.context.serverTime ?? 'Hora del servidor no disponible',
              ),
              _contextItem('Estado', this.context.connectionLabel),
              _contextItem('Sincronización', this.context.syncLabel),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _contextItem(String label, String value) => Text('$label: $value');

  Widget _compactContextButton(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: IconButton(
      key: const Key('operational-context-button'),
      tooltip: 'Detalle de conexión',
      icon: const Icon(Icons.info_outline),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _contextFooter(context),
          ),
        ),
      ),
    ),
  );
}
