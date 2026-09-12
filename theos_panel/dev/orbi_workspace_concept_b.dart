import 'package:flutter/material.dart';

enum ConceptRole { seller, cashier, supervisor, warehouse }

extension on ConceptRole {
  String get label => switch (this) {
    ConceptRole.seller => 'Vendedor',
    ConceptRole.cashier => 'Cajero',
    ConceptRole.supervisor => 'Supervisor',
    ConceptRole.warehouse => 'Bodega',
  };
}

class OrbiWorkspaceConceptB extends StatefulWidget {
  const OrbiWorkspaceConceptB({super.key});
  @override
  State<OrbiWorkspaceConceptB> createState() => _OrbiWorkspaceConceptBState();
}

class _OrbiWorkspaceConceptBState extends State<OrbiWorkspaceConceptB> {
  ConceptRole role = ConceptRole.seller;
  int selected = 0;

  List<_NavItem> get nav => switch (role) {
    ConceptRole.seller => const [
      _NavItem('Inicio', Icons.grid_view_outlined),
      _NavItem('Ventas', Icons.point_of_sale_outlined),
      _NavItem('Clientes', Icons.people_outline),
      _NavItem('Productos', Icons.inventory_2_outlined),
    ],
    ConceptRole.cashier => const [
      _NavItem('Inicio', Icons.grid_view_outlined),
      _NavItem('Caja', Icons.account_balance_wallet_outlined),
      _NavItem('Ventas', Icons.receipt_long_outlined),
      _NavItem('Sync', Icons.sync_outlined),
    ],
    ConceptRole.supervisor => const [
      _NavItem('Inicio', Icons.grid_view_outlined),
      _NavItem('Aprobaciones', Icons.fact_check_outlined),
      _NavItem('Ventas', Icons.point_of_sale_outlined),
      _NavItem('Caja', Icons.account_balance_wallet_outlined),
    ],
    ConceptRole.warehouse => const [
      _NavItem('Inicio', Icons.grid_view_outlined),
      _NavItem('Entregas', Icons.local_shipping_outlined),
      _NavItem('Productos', Icons.inventory_2_outlined),
      _NavItem('Sync', Icons.sync_outlined),
    ],
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final compact = c.maxWidth < 600;
      final tablet = c.maxWidth >= 600 && c.maxWidth < 1000;
      final index = selected.clamp(0, nav.length - 1) as int;
      return Scaffold(
        backgroundColor: const Color(0xfff5f7f8),
        bottomNavigationBar: compact
            ? _BottomNav(nav: nav, selected: index, onTap: _select)
            : null,
        body: Column(
          children: [
            _Header(
              role: role,
              compact: compact,
              onRole: (v) => setState(() {
                role = v!;
                selected = 0;
              }),
            ),
            Expanded(
              child: Row(
                children: [
                  if (!compact)
                    _SideNav(
                      nav: nav,
                      selected: index,
                      rail: tablet,
                      onTap: _select,
                    ),
                  Expanded(
                    child: _Workspace(
                      role: role,
                      active: nav[index].label,
                      compact: compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  void _select(int value) => setState(() => selected = value);
}

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.role,
    required this.compact,
    required this.onRole,
  });
  final ConceptRole role;
  final bool compact;
  final ValueChanged<ConceptRole?> onRole;
  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    color: const Color(0xff202b31),
    child: Row(
      children: [
        const Icon(Icons.hexagon, color: Color(0xff54d0c1), size: 27),
        if (!compact) ...[
          const SizedBox(width: 10),
          const Text(
            'ORBI',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ],
        const Spacer(),
        if (!compact)
          const _HeaderStatus(label: 'Online', icon: Icons.cloud_done_outlined),
        if (!compact) const SizedBox(width: 10),
        const Badge(
          label: Text('3'),
          child: Icon(Icons.notifications_none, color: Colors.white),
        ),
        const SizedBox(width: 12),
        DropdownButtonHideUnderline(
          child: DropdownButton<ConceptRole>(
            value: role,
            dropdownColor: const Color(0xff28363d),
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            onChanged: onRole,
            items: ConceptRole.values
                .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                .toList(),
          ),
        ),
      ],
    ),
  );
}

class _HeaderStatus extends StatelessWidget {
  const _HeaderStatus({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16, color: const Color(0xff8ee6d9)),
    label: Text(label),
    backgroundColor: const Color(0xff304a4c),
    labelStyle: const TextStyle(color: Colors.white),
  );
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.nav,
    required this.selected,
    required this.rail,
    required this.onTap,
  });
  final List<_NavItem> nav;
  final int selected;
  final bool rail;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => Container(
    width: rail ? 84 : 232,
    color: const Color(0xff202b31),
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      children: [
        for (var i = 0; i < nav.length; i++)
          Tooltip(
            message: nav[i].label,
            child: ListTile(
              selected: i == selected,
              selectedTileColor: const Color(0xff315d5e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              leading: Icon(nav[i].icon, color: Colors.white70),
              title: rail
                  ? null
                  : Text(
                      nav[i].label,
                      style: const TextStyle(color: Colors.white),
                    ),
              onTap: () => onTap(i),
            ),
          ),
      ],
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.nav,
    required this.selected,
    required this.onTap,
  });
  final List<_NavItem> nav;
  final int selected;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selected,
    onDestinationSelected: onTap,
    destinations: nav
        .map((n) => NavigationDestination(icon: Icon(n.icon), label: n.label))
        .toList(),
  );
}

class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.role,
    required this.active,
    required this.compact,
  });
  final ConceptRole role;
  final String active;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final title = active == 'Inicio' ? 'Buenos días, ${role.label}' : active;
    final cta = switch (role) {
      ConceptRole.seller => 'Nueva venta',
      ConceptRole.cashier => 'Abrir caja',
      ConceptRole.supervisor => 'Revisar aprobaciones',
      ConceptRole.warehouse => 'Validar entrega',
    };
    return SingleChildScrollView(
      padding: EdgeInsets.all(compact ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xff202b31),
            ),
          ),
          const SizedBox(height: 6),
          Text(_subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trabajo prioritario',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(cta),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _UrgentCard(role: role),
          const SizedBox(height: 22),
          if (role == ConceptRole.supervisor) ...[
            _Pipeline(compact: compact),
            const SizedBox(height: 22),
          ],
          Text(
            'Acciones contextuales',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in _actions)
                _Action(label: item.$1, detail: item.$2, icon: item.$3),
            ],
          ),
        ],
      ),
    );
  }

  String get _subtitle => switch (role) {
    ConceptRole.seller =>
      'Ventas recientes y clientes que requieren seguimiento.',
    ConceptRole.cashier => 'Controla cobros y el estado de tu turno.',
    ConceptRole.supervisor => 'Excepciones del día en una sola vista.',
    ConceptRole.warehouse => 'Despachos listos para la última validación.',
  };
  List<(String, String, IconData)> get _actions => switch (role) {
    ConceptRole.seller => [
      ('Clientes', '12 seguimientos', Icons.people_outline),
      ('Productos', 'Catálogo local', Icons.inventory_2_outlined),
    ],
    ConceptRole.cashier => [
      ('Cobros', '6 pendientes', Icons.payments_outlined),
      ('Sync', '2 en cola', Icons.sync_outlined),
    ],
    ConceptRole.supervisor => [
      ('Ventas', '48 hoy', Icons.trending_up),
      ('Caja', '1 diferencia', Icons.account_balance_wallet_outlined),
    ],
    ConceptRole.warehouse => [
      ('Productos', 'Stock actualizado', Icons.inventory_2_outlined),
      ('Rutas', '3 entregas hoy', Icons.route_outlined),
    ],
  };
}

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({required this.role});
  final ConceptRole role;
  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xffe5f4f1),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xffb8e8df),
            child: Icon(Icons.priority_high, color: Color(0xff145c5c)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(switch (role) {
              ConceptRole.seller => 'Borrador SO-1042 · Cliente ficticio',
              ConceptRole.cashier => 'Factura SO-1042 · Cobro pendiente',
              ConceptRole.supervisor =>
                'Crédito SO-1042 · Aprobación requerida',
              ConceptRole.warehouse => 'Pedido SO-1042 · Entrega hoy',
            }, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          OutlinedButton(onPressed: () {}, child: const Text('Continuar')),
        ],
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.detail,
    required this.icon,
  });
  final String label, detail;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: Card(
      child: ListTile(
        minVerticalPadding: 14,
        leading: Icon(icon, color: const Color(0xff167d79)),
        title: Text(label),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right),
      ),
    ),
  );
}

class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estado del día',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: compact ? 18 : 44,
            runSpacing: 14,
            children: const [
              Text('48 ventas\nconfirmadas'),
              Text('6 cobros\npendientes'),
              Text('3 aprobaciones\nabiertas'),
              Text('2 operaciones\nen cola'),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff167d79)),
    ),
    home: const OrbiWorkspaceConceptB(),
  ),
);
