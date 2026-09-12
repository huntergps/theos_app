import 'package:flutter/material.dart';

/// Standalone visual harness for the operational shell proposal.
///
/// This file deliberately owns only fake data and local navigation state. It
/// does not import providers, auth, Odoo, or production screens.
enum GalleryRole { seller, cashier, warehouse, supervisor }

extension on GalleryRole {
  String get label => switch (this) {
    GalleryRole.seller => 'Vendedor',
    GalleryRole.cashier => 'Cajero',
    GalleryRole.warehouse => 'Bodega',
    GalleryRole.supervisor => 'Supervisor',
  };
}

class OperationalShellGallery extends StatefulWidget {
  const OperationalShellGallery({super.key});

  @override
  State<OperationalShellGallery> createState() =>
      _OperationalShellGalleryState();
}

class _OperationalShellGalleryState extends State<OperationalShellGallery> {
  GalleryRole _role = GalleryRole.seller;
  int _destination = 0;

  List<_Destination> get _destinations => switch (_role) {
    GalleryRole.seller => const [
      _Destination('Inicio', Icons.home_outlined),
      _Destination('Ventas', Icons.point_of_sale_outlined),
      _Destination('Clientes', Icons.people_outline),
      _Destination('Productos', Icons.inventory_2_outlined),
    ],
    GalleryRole.cashier => const [
      _Destination('Inicio', Icons.home_outlined),
      _Destination('Caja', Icons.account_balance_wallet_outlined),
      _Destination('Ventas', Icons.receipt_long_outlined),
      _Destination('Sincronización', Icons.sync_outlined),
    ],
    GalleryRole.warehouse => const [
      _Destination('Inicio', Icons.home_outlined),
      _Destination('Bodega', Icons.warehouse_outlined),
      _Destination('Productos', Icons.inventory_2_outlined),
      _Destination('Sincronización', Icons.sync_outlined),
    ],
    GalleryRole.supervisor => const [
      _Destination('Inicio', Icons.home_outlined),
      _Destination('Aprobaciones', Icons.fact_check_outlined),
      _Destination('Ventas', Icons.point_of_sale_outlined),
      _Destination('Caja', Icons.account_balance_wallet_outlined),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final medium = width >= 600 && width < 1000;
    final destinations = _destinations;
    final selected = _destination.clamp(0, destinations.length - 1) as int;
    if (selected != _destination) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _destination = selected);
      });
    }

    final body = _Dashboard(role: _role, destination: destinations[selected]);
    return Scaffold(
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: _select,
              destinations: destinations
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _Header(role: _role, onRoleChanged: _changeRole),
            Expanded(
              child: Row(
                children: [
                  if (!compact)
                    _Navigation(
                      destinations: destinations,
                      selectedIndex: selected,
                      compact: medium,
                      onSelected: _select,
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1440),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 16 : 32,
                            compact ? 20 : 28,
                            compact ? 16 : 32,
                            32,
                          ),
                          child: body,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _select(int index) => setState(() => _destination = index);

  void _changeRole(GalleryRole? role) {
    if (role == null) return;
    setState(() {
      _role = role;
      _destination = 0;
    });
  }
}

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Header extends StatelessWidget {
  const _Header({required this.role, required this.onRoleChanged});
  final GalleryRole role;
  final ValueChanged<GalleryRole?> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Material(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.hexagon_outlined, color: colors.primary, size: 30),
            const SizedBox(width: 10),
            const Text(
              'Orbi ERP',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            if (!compact)
              Text(
                'Panel de operaciones',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const Spacer(),
            if (!compact) ...[
              const Chip(
                avatar: Icon(Icons.cloud_done_outlined, size: 17),
                label: Text('Online'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Avisos: 3 pendientes',
                onPressed: () {},
                icon: const Badge(
                  label: Text('3'),
                  child: Icon(Icons.notifications_none),
                ),
              ),
            ],
            if (compact)
              PopupMenuButton<GalleryRole>(
                tooltip: 'Cambiar rol',
                initialValue: role,
                onSelected: onRoleChanged,
                itemBuilder: (context) => GalleryRole.values
                    .map(
                      (item) =>
                          PopupMenuItem(value: item, child: Text(item.label)),
                    )
                    .toList(),
                icon: const Icon(Icons.more_horiz),
              )
            else
              DropdownButtonHideUnderline(
                child: DropdownButton<GalleryRole>(
                  value: role,
                  onChanged: onRoleChanged,
                  items: GalleryRole.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.destinations,
    required this.selectedIndex,
    required this.compact,
    required this.onSelected,
  });
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool compact;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.selected,
        destinations: destinations
            .map(
              (item) => NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              ),
            )
            .toList(),
      );
    }
    return SizedBox(
      width: 248,
      child: NavigationDrawer(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 20, 16, 10),
            child: Text(
              'OPERACIONES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          for (final item in destinations)
            NavigationDrawerDestination(
              icon: Icon(item.icon),
              label: Text(item.label),
            ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.role, required this.destination});
  final GalleryRole role;
  final _Destination destination;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 600
        ? 2
        : 1;
    final cta = switch (role) {
      GalleryRole.seller => 'Nueva venta',
      GalleryRole.cashier => 'Abrir caja',
      GalleryRole.warehouse => 'Ver entregas',
      GalleryRole.supervisor => 'Revisar aprobaciones',
    };
    final intro = switch (role) {
      GalleryRole.seller => 'Tus ventas y clientes de hoy.',
      GalleryRole.cashier => 'Control de turno y cobros pendientes.',
      GalleryRole.warehouse => 'Despachos listos para validar.',
      GalleryRole.supervisor =>
        'Excepciones y métricas que requieren atención.',
    };
    return ListView(
      shrinkWrap: true,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(intro, style: Theme.of(context).textTheme.bodyLarge),
              ],
            );
            final action = FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: Text(cta),
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [heading, const SizedBox(height: 16), action],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: heading),
                      action,
                    ],
                  );
          },
        ),
        const SizedBox(height: 24),
        if (role == GalleryRole.supervisor) _MetricsGrid(columns: columns),
        if (role == GalleryRole.supervisor) const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (role) {
                  GalleryRole.seller => 'Continuar trabajando',
                  GalleryRole.cashier => 'Cobros pendientes',
                  GalleryRole.warehouse => 'Despachos por validar',
                  GalleryRole.supervisor => 'Solicitudes recientes',
                }, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                _ResumeRow(role: role),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Accesos destacados',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: width < 600 ? 2.6 : 2.2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final item in _quickItems(role))
              Card(
                color: colors.surfaceContainerLow,
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(item.icon, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<_QuickItem> _quickItems(GalleryRole role) => switch (role) {
    GalleryRole.seller => const [
      _QuickItem('Clientes', Icons.people_outline),
      _QuickItem('Productos', Icons.inventory_2_outlined),
    ],
    GalleryRole.cashier => const [
      _QuickItem('Ventas pendientes', Icons.receipt_long_outlined),
      _QuickItem('Sincronización', Icons.sync_outlined),
    ],
    GalleryRole.warehouse => const [
      _QuickItem('Productos', Icons.inventory_2_outlined),
      _QuickItem('Sincronización', Icons.sync_outlined),
    ],
    GalleryRole.supervisor => const [
      _QuickItem('Ventas', Icons.point_of_sale_outlined),
      _QuickItem('Caja', Icons.account_balance_wallet_outlined),
    ],
  };
}

class _QuickItem {
  const _QuickItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.role});
  final GalleryRole role;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = switch (role) {
        GalleryRole.seller => 'Borrador · Cliente ficticio',
        GalleryRole.cashier => 'Factura #SO-1042 · Cobro pendiente',
        GalleryRole.warehouse => 'Pedido #SO-1042 · Entrega hoy',
        GalleryRole.supervisor => 'Crédito #SO-1042 · Revisión requerida',
      };
      final detail = ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.schedule)),
        title: Text(title),
        subtitle: const Text('Actualizado hace 8 min · dato ficticio'),
      );
      if (constraints.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            detail,
            FilledButton(onPressed: () {}, child: const Text('Continuar')),
          ],
        );
      }
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.schedule)),
        title: Text(title),
        subtitle: const Text('Actualizado hace 8 min · dato ficticio'),
        trailing: FilledButton(
          onPressed: () {},
          child: const Text('Continuar'),
        ),
      );
    },
  );
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: columns,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 2.1,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    children: const [
      _Metric(
        label: 'Ventas del día',
        value: '\$12,480',
        icon: Icons.trending_up,
      ),
      _Metric(label: 'Pendientes', value: '8', icon: Icons.pending_actions),
      _Metric(
        label: 'Aprobaciones',
        value: '3',
        icon: Icons.fact_check_outlined,
      ),
      _Metric(
        label: 'Sincronización',
        value: 'Al día',
        icon: Icons.cloud_done_outlined,
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(value, style: Theme.of(context).textTheme.titleLarge),
      subtitle: Text(label),
    ),
  );
}

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF007E82)),
      useMaterial3: true,
    ),
    home: const OperationalShellGallery(),
  ),
);
