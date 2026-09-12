import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'orbi_operations_preview.dart';
import 'orbi_sales_preview.dart';

/// Orbi visual gallery entry point. Everything here is fixture-only and safe to discard.
void main() => runApp(const OrbiDesignPreviewApp());

class OrbiDesignPreviewApp extends StatefulWidget {
  const OrbiDesignPreviewApp({super.key});
  @override
  State<OrbiDesignPreviewApp> createState() => _OrbiDesignPreviewAppState();
}

class _OrbiDesignPreviewAppState extends State<OrbiDesignPreviewApp> {
  ThemeMode _theme = ThemeMode.light;
  bool _alternativeB = false;
  String _area = 'Ventas';
  int _selected = 0;
  final _nav = const [
    _Nav('Ventas', Icons.point_of_sale_outlined),
    _Nav('Caja', Icons.account_balance_wallet_outlined),
    _Nav('Bodega', Icons.inventory_2_outlined),
    _Nav('Aprobaciones', Icons.fact_check_outlined),
  ];

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    themeMode: _theme,
    theme: _themeData(Brightness.light),
    darkTheme: _themeData(Brightness.dark),
    home: LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 600,
            medium = c.maxWidth >= 600 && c.maxWidth < 980;
        final body = _area == 'Ventas'
            ? OrbiSalesPreview(catalogFirst: !_alternativeB)
            : OrbiOperationsPreview(area: _area);
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          bottomNavigationBar: compact ? _bottom() : null,
          body: Row(
            children: [
              if (!compact) _sideNav(context, medium),
              Expanded(
                child: Column(
                  children: [
                    _header(context, compact),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  ThemeData _themeData(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff007e82),
      brightness: b,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Arial',
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      inputDecorationTheme: const InputDecorationTheme(isDense: true),
    );
  }

  Widget _header(BuildContext context, bool compact) => Container(
    height: 72,
    padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 28),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: SvgPicture.asset('assets/images/orbi_logo.svg'),
        ),
        if (!compact) ...[
          const SizedBox(width: 10),
          const Text(
            'ORBI',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 24),
          Text(_area, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_area == 'Ventas') ...[
            const SizedBox(width: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('A · Tabla')),
                ButtonSegment(value: true, label: Text('B · Catálogo')),
              ],
              selected: {_alternativeB},
              onSelectionChanged: (v) =>
                  setState(() => _alternativeB = v.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ],
        ],
        const Spacer(),
        if (!compact)
          const Chip(
            avatar: Icon(
              Icons.cloud_done_outlined,
              size: 16,
              color: Color(0xff177c74),
            ),
            label: Text('Online'),
          ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {},
          tooltip: 'Notificaciones',
          icon: const Badge(
            label: Text('3'),
            child: Icon(Icons.notifications_none),
          ),
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xffdcefed),
          child: Text(
            compact ? 'AM' : 'AM',
            style: const TextStyle(
              color: Color(0xff07595b),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => setState(
            () => _theme = _theme == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.light,
          ),
          tooltip: 'Cambiar tema',
          icon: Icon(
            _theme == ThemeMode.light
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
          ),
        ),
      ],
    ),
  );

  Widget _sideNav(BuildContext context, bool medium) => Container(
    width: medium ? 82 : 224,
    color: Theme.of(context).colorScheme.surface,
    padding: EdgeInsets.fromLTRB(medium ? 10 : 16, 24, medium ? 10 : 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!medium)
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 24),
            child: Text(
              'ESPACIO DE TRABAJO',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: Colors.grey,
              ),
            ),
          ),
        for (var i = 0; i < _nav.length; i++) _navTile(context, i, medium),
        const Spacer(),
        if (!medium) const Divider(),
        if (!medium)
          const Padding(
            padding: EdgeInsets.only(left: 10, top: 12),
            child: Text(
              'Sesión simulada · Ana Morales',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
      ],
    ),
  );
  Widget _navTile(BuildContext context, int i, bool compact) {
    final item = _nav[i], active = i == _selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Tooltip(
        message: item.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _selected = i;
            _area = item.label;
          }),
          child: Container(
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
            decoration: BoxDecoration(
              color: active ? const Color(0xffdcefed) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: compact
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  color: active
                      ? const Color(0xff007e82)
                      : Colors.grey.shade600,
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? const Color(0xff07595b) : null,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottom() => NavigationBar(
    selectedIndex: _selected,
    onDestinationSelected: (i) => setState(() {
      _selected = i;
      _area = _nav[i].label;
    }),
    destinations: _nav
        .map((n) => NavigationDestination(icon: Icon(n.icon), label: n.label))
        .toList(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
}

class _Nav {
  const _Nav(this.label, this.icon);
  final String label;
  final IconData icon;
}
