import 'package:flutter/material.dart';

/// Concept A is an isolated visual exploration. It deliberately owns its
/// sample data and theme so it cannot change the production panel.
enum ConceptRole { seller, cashier, supervisor, warehouse }

extension on ConceptRole {
  String get label => switch (this) {
    ConceptRole.seller => 'Vendedor',
    ConceptRole.cashier => 'Cajero',
    ConceptRole.supervisor => 'Supervisor',
    ConceptRole.warehouse => 'Bodega',
  };

  String get greeting => switch (this) {
    ConceptRole.seller => 'Convierte oportunidades en ventas',
    ConceptRole.cashier => 'Caja lista para atender',
    ConceptRole.supervisor => 'Todo el equipo, bajo control',
    ConceptRole.warehouse => 'Inventario claro, despachos a tiempo',
  };
}

class OrbiWorkspaceConceptA extends StatefulWidget {
  const OrbiWorkspaceConceptA({super.key});

  @override
  State<OrbiWorkspaceConceptA> createState() => _OrbiWorkspaceConceptAState();
}

class _OrbiWorkspaceConceptAState extends State<OrbiWorkspaceConceptA> {
  ConceptRole role = ConceptRole.seller;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _conceptTheme,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if (width < 600) return _mobile(context);
          if (width < 1000) return _tablet(context);
          return _desktop(context);
        },
      ),
    );
  }

  Widget _mobile(BuildContext context) => Scaffold(
    backgroundColor: _C.background,
    appBar: _mobileAppBar(context),
    body: _body(context, compact: true),
    bottomNavigationBar: NavigationBar(
      key: const Key('concept-bottom-navigation'),
      selectedIndex: 0,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.point_of_sale_outlined),
          label: 'Ventas',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Bodega',
        ),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Más'),
      ],
    ),
  );

  PreferredSizeWidget _mobileAppBar(BuildContext context) => AppBar(
    backgroundColor: _C.background,
    titleSpacing: 16,
    title: const Text(
      'Orbi ERP',
      style: TextStyle(fontWeight: FontWeight.w800),
    ),
    actions: [
      _roleMenu(context),
      IconButton(
        tooltip: 'Notificaciones',
        onPressed: () {},
        icon: const Icon(Icons.notifications_none),
      ),
      const SizedBox(width: 8),
    ],
  );

  Widget _tablet(BuildContext context) => Scaffold(
    backgroundColor: _C.background,
    body: Row(
      children: [
        NavigationRail(
          key: const Key('concept-navigation-rail'),
          selectedIndex: 0,
          labelType: NavigationRailLabelType.selected,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.grid_view_outlined),
              label: Text('Inicio'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              label: Text('Ventas'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.inventory_2_outlined),
              label: Text('Bodega'),
            ),
          ],
        ),
        Expanded(
          child: Column(
            children: [
              _header(context),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _desktop(BuildContext context) => Scaffold(
    backgroundColor: _C.background,
    body: Row(
      children: [
        SizedBox(width: 240, child: _drawer()),
        Expanded(
          child: Column(
            children: [
              _header(context),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _drawer() => Container(
    key: const Key('concept-navigation-drawer'),
    color: _C.surface,
    padding: const EdgeInsets.fromLTRB(20, 28, 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            _BrandMark(),
            SizedBox(width: 10),
            Text(
              'Orbi ERP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 34),
        const Text(
          'OPERACIONES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: _C.muted,
          ),
        ),
        const SizedBox(height: 10),
        _navItem(Icons.grid_view_outlined, 'Inicio', true),
        _navItem(Icons.point_of_sale_outlined, 'Ventas', false),
        _navItem(Icons.inventory_2_outlined, 'Inventario', false),
        _navItem(Icons.people_outline, 'Clientes', false),
        const Spacer(),
        const Divider(color: _C.border),
        _navItem(Icons.settings_outlined, 'Configuración', false),
      ],
    ),
  );

  Widget _navItem(IconData icon, String label, bool selected) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: selected ? _C.tealSoft : null,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: Icon(icon, color: selected ? _C.teal : _C.muted),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? _C.tealDeep : _C.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: () {},
      ),
    ),
  );

  Widget _header(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: const BoxDecoration(
      color: _C.surface,
      border: Border(bottom: BorderSide(color: _C.border)),
    ),
    child: Row(
      children: [
        const Text(
          'Panel de operaciones',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        _roleMenu(context),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          radius: 18,
          backgroundColor: _C.tealSoft,
          child: Text(
            'AM',
            style: TextStyle(color: _C.tealDeep, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _roleMenu(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<ConceptRole>(
      key: const Key('concept-role-selector'),
      value: role,
      icon: const Icon(Icons.keyboard_arrow_down, size: 18),
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      selectedItemBuilder: (_) => ConceptRole.values
          .map(
            (r) => Center(
              child: Text(
                r.label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          )
          .toList(),
      items: ConceptRole.values
          .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
          .toList(),
      onChanged: (value) => value == null ? null : setState(() => role = value),
    ),
  );

  Widget _body(BuildContext context, {bool compact = false}) {
    final side = _sideColumn();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 28,
        compact ? 8 : 24,
        compact ? 16 : 28,
        32,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(compact),
            const SizedBox(height: 20),
            _metrics(),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, c) {
                final twoColumns = c.maxWidth >= 680;
                if (!twoColumns)
                  return Column(
                    children: [
                      _priorityQueue(),
                      const SizedBox(height: 16),
                      side,
                    ],
                  );
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 8, child: _priorityQueue()),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: side),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _quickActions(),
          ],
        ),
      ),
    );
  }

  Widget _hero(bool compact) => Container(
    padding: EdgeInsets.all(compact ? 18 : 22),
    decoration: BoxDecoration(
      color: _C.tealDeep,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Buenos días, Andrea',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                role.greeting,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Martes, 9 de septiembre · 24 tareas activas',
                style: TextStyle(color: Color(0xFFB7DFDC), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Nueva venta'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _C.tealDeep,
            minimumSize: const Size(48, 48),
          ),
        ),
      ],
    ),
  );

  Widget _metrics() => SingleChildScrollView(
    key: const Key('concept-kpi-strip'),
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _metric(
          'Ventas del día',
          '\$12,480',
          '+12.4%',
          Icons.trending_up,
          _C.teal,
        ),
        const SizedBox(width: 12),
        _metric(
          'Pedidos pendientes',
          '18',
          '6 urgentes',
          Icons.schedule,
          _C.orange,
        ),
        const SizedBox(width: 12),
        _metric(
          'Stock crítico',
          '7 SKU',
          'Reponer hoy',
          Icons.warning_amber,
          _C.red,
        ),
      ],
    ),
  );

  Widget _metric(
    String label,
    String value,
    String detail,
    IconData icon,
    Color color,
  ) => SizedBox(
    width: 196,
    child: _panel(
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: .11),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _C.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _priorityQueue() => _panel(
    key: const Key('concept-priority-queue'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Cola prioritaria', '8 tareas requieren atención'),
        const SizedBox(height: 8),
        ...[
          (
            'Pedido #1048',
            'Pago pendiente · hace 8 min',
            _C.orange,
            Icons.payment_outlined,
          ),
          (
            'Stock bajo: Café Orbi 1kg',
            'Bodega Norte · 7 unidades',
            _C.red,
            Icons.inventory_2_outlined,
          ),
          (
            'Cotización #882',
            'Esperando aprobación · María Ruiz',
            _C.teal,
            Icons.description_outlined,
          ),
          (
            'Despacho #330',
            'Listo para recoger · muelle 2',
            _C.blue,
            Icons.local_shipping_outlined,
          ),
        ].map((item) => _task(item.$1, item.$2, item.$3, item.$4)),
      ],
    ),
  );

  Widget _task(String title, String subtitle, Color color, IconData icon) =>
      Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: .11),
            child: Icon(icon, size: 18, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: _C.muted),
          ),
          trailing: const Icon(Icons.chevron_right, size: 20, color: _C.muted),
          onTap: () {},
        ),
      );

  Widget _sideColumn() => Column(
    key: const Key('concept-side-column'),
    children: [
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Alertas', 'Ver todo'),
            const SizedBox(height: 10),
            const _Alert(
              icon: Icons.warning_amber,
              color: _C.red,
              text: '7 productos bajo mínimo',
            ),
            const _Alert(
              icon: Icons.lock_clock,
              color: _C.orange,
              text: '2 cierres de caja pendientes',
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Actividad reciente', 'Últimas 2 h'),
            const SizedBox(height: 10),
            const Text(
              'Carlos registró una venta · hace 4 min',
              style: TextStyle(fontSize: 12, color: _C.ink),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bodega confirmó recepción · hace 18 min',
              style: TextStyle(fontSize: 12, color: _C.ink),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _quickActions() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Acciones rápidas', 'Atajos del equipo'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _action(Icons.person_add_alt_1, 'Nuevo cliente'),
          _action(Icons.add_box_outlined, 'Registrar producto'),
          _action(Icons.receipt_long_outlined, 'Ver reportes'),
          _action(Icons.swap_horiz, 'Transferir stock'),
        ],
      ),
    ],
  );

  Widget _action(IconData icon, String label) => SizedBox(
    width: 190,
    child: _panel(
      child: Row(
        children: [
          Icon(icon, color: _C.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _sectionTitle(String title, String action) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      const Spacer(),
      Flexible(
        child: Text(
          action,
          textAlign: TextAlign.end,
          style: const TextStyle(
            fontSize: 11,
            color: _C.teal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );

  Widget _panel({Key? key, required Widget child}) => Container(
    key: key,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _C.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _C.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .035),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  static final _conceptTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _C.teal,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: _C.background,
    visualDensity: VisualDensity.standard,
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: _C.teal,
      borderRadius: BorderRadius.circular(9),
    ),
    child: const Icon(Icons.hub_outlined, color: Colors.white, size: 18),
  );
}

class _Alert extends StatelessWidget {
  const _Alert({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

abstract final class _C {
  static const background = Color(0xFFF7F6F1);
  static const surface = Color(0xFFFFFEFB);
  static const border = Color(0xFFE4E1D8);
  static const ink = Color(0xFF1C2928);
  static const muted = Color(0xFF687674);
  static const teal = Color(0xFF007E82);
  static const tealDeep = Color(0xFF07595B);
  static const tealSoft = Color(0xFFDCEFED);
  static const orange = Color(0xFFB76D16);
  static const red = Color(0xFFB34238);
  static const blue = Color(0xFF3B6B9B);
}

void main() => runApp(const MaterialApp(home: OrbiWorkspaceConceptA()));
