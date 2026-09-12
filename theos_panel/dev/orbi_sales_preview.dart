import 'package:flutter/material.dart';

/// Standalone, local-data visual prototype for the Sales vertical.
class OrbiSalesPreview extends StatefulWidget {
  const OrbiSalesPreview({super.key, this.catalogFirst = true});
  final bool catalogFirst;

  @override
  State<OrbiSalesPreview> createState() => _OrbiSalesPreviewState();
}

class _SaleItem {
  _SaleItem(this.name, this.code, this.price, this.stock, this.color);
  final String name;
  final String code;
  final double price;
  final int stock;
  final Color color;
  int quantity = 0;
}

class _OrbiSalesPreviewState extends State<OrbiSalesPreview> {
  final _search = TextEditingController();
  late final List<_SaleItem> _items = [
    _SaleItem(
      'Café molido Orbi 500 g',
      'CAF-500',
      8.90,
      42,
      const Color(0xffd9a066),
    ),
    _SaleItem(
      'Jabón líquido neutro 1 L',
      'HIG-101',
      5.75,
      18,
      const Color(0xff7db9b0),
    ),
    _SaleItem(
      'Caja organizadora mediana',
      'HOG-223',
      12.40,
      9,
      const Color(0xff8da6c4),
    ),
    _SaleItem(
      'Set de vasos vidrio x6',
      'COC-040',
      16.80,
      24,
      const Color(0xffd28f9e),
    ),
    _SaleItem(
      'Toalla algodón gris',
      'HOG-118',
      10.20,
      31,
      const Color(0xffaaa0d1),
    ),
    _SaleItem(
      'Batería alcalina AA x4',
      'ELE-009',
      4.60,
      73,
      const Color(0xffe0bb63),
    ),
  ];
  bool _consultive = false;
  bool _showPin = false;
  String _query = '';

  List<_SaleItem> get _filtered => _items
      .where(
        (item) => '${item.name} ${item.code}'.toLowerCase().contains(
          _query.toLowerCase(),
        ),
      )
      .toList();
  List<_SaleItem> get _cart =>
      _items.where((item) => item.quantity > 0).toList();
  double get _subtotal =>
      _cart.fold(0, (sum, item) => sum + item.price * item.quantity);
  double get _tax => _subtotal * .12;
  double get _total => _subtotal + _tax;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final compact = c.maxWidth < 600;
      final medium = c.maxWidth >= 600 && c.maxWidth < 980;
      return Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 28,
              compact ? 16 : 26,
              compact ? 16 : 28,
              18,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hero(context, compact),
                const SizedBox(height: 18),
                Expanded(
                  child: compact ? _compact(context) : _wide(context, medium),
                ),
              ],
            ),
          ),
          if (_showPin) _pinOverlay(context),
        ],
      );
    },
  );

  Widget _hero(BuildContext context, bool compact) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ventas',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              'Pedido nuevo · borrador local #SO-1048',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      if (!compact) ...[
        const Chip(
          avatar: Icon(
            Icons.cloud_done_outlined,
            size: 16,
            color: Color(0xff177c74),
          ),
          label: Text('Online · sincronizado'),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 10),
      ],
      IconButton(
        tooltip: 'PIN de vendedor (simulado)',
        onPressed: () => setState(() => _showPin = true),
        icon: const Icon(Icons.lock_outline),
      ),
    ],
  );

  Widget _wide(BuildContext context, bool medium) => widget.catalogFirst
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: medium ? 5 : 4, child: _catalog(context)),
            const SizedBox(width: 16),
            Expanded(
              flex: medium ? 5 : 4,
              child: _order(context, showCustomer: !medium),
            ),
            if (!medium) ...[
              const SizedBox(width: 16),
              SizedBox(width: 270, child: _CustomerPanel()),
            ],
          ],
        )
      : _denseTable(context);

  Widget _denseTable(BuildContext context) => _Panel(
    title: 'Mis ventas · Tabla operativa',
    subtitle: 'Pedidos recientes y acciones pendientes · alternativa A',
    icon: Icons.table_rows_outlined,
    child: Column(
      children: [
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar orden, cliente o vendedor',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: 6,
            itemBuilder: (_, i) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xffdcefed),
                child: Text(
                  'SO',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xff07595b),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                '#SO-${1048 - i} · Cliente ${i + 1}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Hoy · Ana Morales · ${i + 1} ítems'),
              trailing: const Text(
                'Pendiente',
                style: TextStyle(color: Color(0xffa25b12), fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _compact(BuildContext context) => ListView(
    children: [
      // Sin alto fijo: el contenido del cliente (RUC, vendedor, bloqueo) no
      // cabía en 286px y desbordaba la columna en pantallas de teléfono.
      const _CustomerPanel(),
      const SizedBox(height: 12),
      SizedBox(height: 500, child: _catalog(context)),
      const SizedBox(height: 12),
      SizedBox(height: 580, child: _order(context, showCustomer: false)),
    ],
  );

  Widget _catalog(BuildContext context) => _Panel(
    title: 'Catálogo',
    subtitle: 'Buscar por código, producto o escanear',
    icon: Icons.inventory_2_outlined,
    child: Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar producto…',
            suffixIcon: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.qr_code_scanner),
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _filtered.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = _filtered[i];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${item.code} · ${item.stock} disponibles'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(
                      height: 28,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => item.quantity++),
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xff007e82),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _order(BuildContext context, {required bool showCustomer}) => _Panel(
    title: 'Pedido',
    subtitle: '${_cart.length} productos · precios Lista general',
    icon: Icons.receipt_long_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCustomer)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Cliente seleccionado · Laura Méndez',
              style: TextStyle(
                color: Color(0xff07595b),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Modo de venta',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Mostrador')),
                ButtonSegment(value: true, label: Text('Consultiva')),
              ],
              selected: {_consultive},
              onSelectionChanged: (v) => setState(() => _consultive = v.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _cart.isEmpty
              ? const Center(
                  child: Text(
                    'Agrega productos para comenzar',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _cart.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _cart[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('\$${item.price.toStringAsFixed(2)} c/u'),
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => setState(
                                () => item.quantity = (item.quantity - 1).clamp(
                                  0,
                                  99,
                                ),
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => item.quantity++),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                            Text(
                              '\$${(item.quantity * item.price).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(),
        _money('Subtotal', _subtotal),
        _money('IVA 12%', _tax),
        const SizedBox(height: 5),
        _money('Total', _total, strong: true),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _cart.isEmpty
                ? null
                : () => _snack(
                    context,
                    'Venta guardada localmente · pendiente de sincronizar',
                  ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Guardar y continuar'),
          ),
        ),
      ],
    ),
  );

  Widget _money(String label, double value, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
            fontSize: strong ? 18 : 14,
          ),
        ),
      ],
    ),
  );

  Widget _pinOverlay(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: Colors.black45,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PIN de vendedor',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text('Prototipo · no autentica contra un servidor'),
                const SizedBox(height: 18),
                const TextField(
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    hintText: '••••',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showPin = false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        setState(() => _showPin = false);
                        _snack(
                          context,
                          'Vendedor Ana M. activo · sesión simulada',
                        );
                      },
                      child: const Text('Entrar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
}

class _CustomerPanel extends StatelessWidget {
  const _CustomerPanel();
  @override
  Widget build(BuildContext context) => _Panel(
    title: 'Contexto comercial',
    subtitle: 'Cliente, condiciones y siguiente bloqueo',
    icon: Icons.person_outline,
    expandChild: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Color(0xffdcefed),
            child: Text(
              'LM',
              style: TextStyle(
                color: Color(0xff07595b),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Text(
            'Laura Méndez',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            'RUC 0912345678001 · Cliente frecuente',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(Icons.chevron_right),
        ),
        const Divider(),
        _info('Vendedor', 'Ana Morales'),
        _info('Almacén', 'Matriz · Quito'),
        _info('Término', 'Contado'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xfffff4df),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xffa25b12)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Próximo bloqueo: confirmar datos fiscales antes de facturar.',
                  style: TextStyle(fontSize: 12, color: Color(0xff754714)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.expandChild = true,
  });
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  final bool expandChild;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xff007e82), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (expandChild) Expanded(child: child) else child,
      ],
    ),
  );
}
