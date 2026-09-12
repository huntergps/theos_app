import 'package:flutter/material.dart';

import '../../app/theme/orbi_theme.dart';
import '../components/orbi_brand.dart';
import 'workspace_lock_screen.dart';

/// The three permanent-navigation tiers `OperationalShell` renders, chosen
/// purely from the window's width and orientation (never a user setting —
/// `docs/orbi_panel/reports/ESQUELETO_FLUENT_2026_09_12.md` recommends
/// against a `PaneDisplayMode`-style user choice: "que el ancho decida").
enum _NavMode {
  /// No permanent rail at all: a `Drawer` behind the app bar's hamburger.
  hidden,

  /// Icon-only rail. A grouped destination collapses to one icon that opens
  /// a flyout with its children, mirroring `fluent_ui`'s own `useFlyout`
  /// behaviour for `PaneDisplayMode.compact`
  /// (`navigation_view/pane_items.dart`) rather than nesting a submenu
  /// inside a ~56px-wide rail item.
  compact,

  /// Full labeled rail. The group containing the current route expands
  /// inline; every other multi-destination group collapses to a single row
  /// (its own name, its first destination's icon, a chevron) that jumps to
  /// its first destination — exactly what the lámina draws for "Ventas" vs.
  /// "Caja"/"Bodega"/"Envases"/"Sistema" on the 1920px desktop view.
  expanded,
}

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
    this.locked = false,
    this.onLock,
    this.onUnlock,
    this.onSwitchUser,
  }) : assert(
         onLock == null || onUnlock != null,
         'onUnlock is required whenever onLock is provided: a shell that '
         'can be locked must always be able to be unlocked.',
       );

  final Widget child;
  final List<OperationalDestination> destinations;
  final String selectedPath;
  final ValueChanged<String> onNavigate;
  final OperationalContext context;
  final VoidCallback onLogout;

  /// Whether the workspace is currently locked (ACC-03, "bloquear"). Purely
  /// presentational: the caller owns this state so it survives whatever
  /// else rebuilds around the shell (this widget "owns no router, provider,
  /// or data source").
  final bool locked;

  /// Locks the workspace. Absent means the shell does not offer locking at
  /// all — never a button the user cannot actually use.
  final VoidCallback? onLock;

  /// Revalidates the same identity to leave [locked]. Required whenever
  /// [onLock] is provided (see the constructor assertion): a lock without an
  /// unlock path would strand the operator.
  final Future<bool> Function(String password)? onUnlock;

  /// Ends the current identity's Workspace access so a different person can
  /// enter. Distinct action from locking and from [onLogout] — see
  /// ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md §8.
  final VoidCallback? onSwitchUser;

  /// Three render tiers for the permanent navigation, matching what the
  /// approved lámina `visual_baselines/approved/round-03/SHELL-01.png`
  /// actually shows at its four device sizes — not Fluent's own
  /// `PaneDisplayMode.auto` cutoffs (`≤640 → minimal`, `≥1008 → expanded` per
  /// `fluent_ui-4.16.1`'s `view.dart:541-543`), which the lámina's own
  /// author deliberately did not copy: at 1366×1024 landscape (iPad
  /// horizontal) the lámina shows the ICON-ONLY rail, not the labeled one
  /// Fluent's own threshold would already have opened.
  ///
  /// Anchors actually measured on the lámina, landscape only:
  /// - 1920×1080 → full labeled rail, active area's children shown inline.
  /// - 1366×1024 → icon-only rail, no labels.
  /// - 1024×1366 (portrait) and 390×844 (phone) → no permanent rail at all.
  ///
  /// [_compactBreakpoint] reuses `OrbiTheme.mediumBreakpoint` (840): the
  /// same "wide" cutoff `login_screen.dart`, `pin_login_screen.dart` and
  /// `collection_screen.dart` already use, safely below the 1366 anchor.
  /// [_expandedBreakpoint] has no lámina data point between 1366 (icon-only)
  /// and 1920 (labeled) — 1440 is a deliberate interpolation (a common
  /// laptop width, comfortably above the confirmed icon-only anchor), not a
  /// measured cutoff. If a lámina ever fixes this precisely, replace it.
  static const double _expandedBreakpoint = 1440;

  _NavMode _navMode(BoxConstraints constraints) {
    // Portrait never gets a permanent rail, at any width: the 1024-wide
    // portrait iPad in the lámina still falls back to the hidden drawer,
    // exactly like the 390-wide phone — this mirrors the same
    // width-AND-orientation gate `login_screen.dart`, `pin_login_screen.dart`
    // and `collection_session_hub_screen.dart` already use for "wide".
    if (constraints.maxWidth < constraints.maxHeight) return _NavMode.hidden;
    if (constraints.maxWidth >= _expandedBreakpoint) return _NavMode.expanded;
    if (constraints.maxWidth >= OrbiTheme.mediumBreakpoint) {
      return _NavMode.compact;
    }
    return _NavMode.hidden;
  }

  @override
  Widget build(BuildContext buildContext) => Stack(
    children: [
      // The real shell stays mounted even while locked: a draft mid-edit or
      // an in-flight form must never be discarded just because someone
      // pressed "Bloquear". Only its interactivity and semantics are
      // suppressed; nothing underneath is rebuilt, disposed or reset.
      IgnorePointer(
        ignoring: locked,
        child: ExcludeSemantics(
          excluding: locked,
          child: _scaffold(buildContext),
        ),
      ),
      if (locked)
        Positioned.fill(
          child: WorkspaceLockScreen(
            userLabel: context.userLabel,
            pendingSummary: context.syncLabel,
            onUnlock: onUnlock!,
            onSwitchUser: onSwitchUser,
          ),
        ),
    ],
  );

  Widget _scaffold(BuildContext buildContext) => LayoutBuilder(
    builder: (buildContext, constraints) {
      final mode = _navMode(constraints);
      final footer =
          constraints.maxWidth >= 600 &&
          constraints.maxWidth >= constraints.maxHeight;
      return Scaffold(
        drawer: mode == _NavMode.hidden
            ? _navigationDrawer(buildContext)
            : null,
        appBar: _appBar(buildContext, mode),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (mode == _NavMode.expanded) _sidebar(buildContext),
                    if (mode == _NavMode.compact) _compactRail(buildContext),
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

  PreferredSizeWidget _appBar(BuildContext context, _NavMode mode) => AppBar(
    automaticallyImplyLeading: mode == _NavMode.hidden,
    titleSpacing: mode == _NavMode.hidden ? null : 20,
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
      if (mode != _NavMode.hidden)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: Center(child: Text(this.context.userLabel)),
        ),
      if (onLock != null)
        IconButton(
          key: const Key('lock-button'),
          tooltip: 'Bloquear',
          icon: const Icon(Icons.lock_outline),
          onPressed: onLock,
        ),
      if (onSwitchUser != null)
        IconButton(
          key: const Key('switch-user-button'),
          tooltip: 'Cambiar de usuario',
          icon: const Icon(Icons.switch_account_outlined),
          onPressed: onSwitchUser,
        ),
      IconButton(
        key: const Key('logout-button'),
        tooltip: 'Cerrar sesión',
        icon: const Icon(Icons.logout),
        onPressed: onLogout,
      ),
    ],
  );

  /// Every destination bucketed by `group`, in the order the caller supplied
  /// them (`router.dart`'s own stable group order, per
  /// `SHELL_AND_INTERACTION_SPEC.md`: "Éste es también el orden estable de
  /// grupos").
  Map<String, List<OperationalDestination>> _groupedDestinations() {
    final grouped = <String, List<OperationalDestination>>{};
    for (final destination in destinations) {
      grouped.putIfAbsent(destination.group, () => []).add(destination);
    }
    return grouped;
  }

  /// Whether [group] contains (or is a prefix-ancestor of) [selectedPath] —
  /// the same rule `RouteAccessPolicy` itself uses for a nested screen under
  /// an area's own route.
  bool _isGroupActive(List<OperationalDestination> group) => group.any(
    (d) => selectedPath == d.path || selectedPath.startsWith('${d.path}/'),
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
          children: _expandedTiles(context),
        ),
      ),
    ),
  );

  /// Full labeled rail. A group of exactly one destination renders exactly
  /// as it always has (header + tile) — untouched, zero collapse risk. A
  /// group of two or more collapses to a single row naming the GROUP (not
  /// whichever destination happens to be first) when it does not contain
  /// the current route, and expands inline — header, then every child tile,
  /// same markup as before — when it does. This is what the lámina draws:
  /// "Ventas" expanded because the shown screen is one of its own, "Caja"/
  /// "Bodega"/"Envases"/"Sistema" collapsed to one row each.
  List<Widget> _expandedTiles(BuildContext context) {
    final tiles = <Widget>[];
    for (final entry in _groupedDestinations().entries) {
      final group = entry.value;
      if (group.length == 1) {
        tiles
          ..add(_groupHeader(context, entry.key))
          ..add(_destinationTile(context, group.single));
        continue;
      }
      if (_isGroupActive(group)) {
        tiles.add(_groupHeader(context, entry.key));
        for (final destination in group) {
          tiles.add(_destinationTile(context, destination));
        }
      } else {
        tiles.add(_collapsedGroupTile(context, entry.key, group));
      }
    }
    return tiles;
  }

  Widget _groupHeader(BuildContext context, String label) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 4),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _destinationTile(
    BuildContext context,
    OperationalDestination destination,
  ) => Semantics(
    container: true,
    button: true,
    selected: destination.path == selectedPath,
    label: destination.label,
    child: ListTile(
      selected: destination.path == selectedPath,
      leading: Icon(destination.icon, semanticLabel: ''),
      title: Text(destination.label),
      onTap: () => _navigate(context, destination.path),
    ),
  );

  /// The single row an inactive multi-destination group collapses to: the
  /// GROUP's own name (never the first child's label, which would misname
  /// e.g. Envases as "Dashboard"), that first child's icon, and a chevron —
  /// tapping opens that first destination, which is what makes the group
  /// active and expands it on the next build.
  Widget _collapsedGroupTile(
    BuildContext context,
    String group,
    List<OperationalDestination> children,
  ) => Semantics(
    container: true,
    button: true,
    label: group,
    child: ListTile(
      leading: Icon(children.first.icon, semanticLabel: ''),
      title: Text(group),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _navigate(context, children.first.path),
    ),
  );

  void _navigate(BuildContext context, String path) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
    onNavigate(path);
  }

  /// Icon-only rail (`_NavMode.compact`). Never nests a group's children
  /// inside the ~56px-wide column — that is exactly the "uncomfortable with
  /// a mouse, impossible with a finger" trap
  /// `ESQUELETO_FLUENT_2026_09_12.md` flags. Instead it mirrors `fluent_ui`'s
  /// own resolution for `PaneDisplayMode.compact`
  /// (`navigation_view/pane_items.dart`, `useFlyout`): one destination per
  /// icon, or for a group, one icon that opens a flyout menu of its
  /// children anchored to its right. Group header labels are not shown at
  /// all here, matching Fluent hiding `PaneItemHeader` in compact.
  Widget _compactRail(BuildContext context) => SizedBox(
    width: 72,
    child: Semantics(
      container: true,
      label: 'Navegación principal',
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            for (final entry in _groupedDestinations().entries)
              entry.value.length == 1
                  ? _compactTile(
                      context,
                      icon: entry.value.single.icon,
                      label: entry.value.single.label,
                      selected: entry.value.single.path == selectedPath,
                      onTap: () => _navigate(context, entry.value.single.path),
                    )
                  : _compactGroupTile(context, entry.key, entry.value),
          ],
        ),
      ),
    ),
  );

  Widget _compactTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Tooltip(
      message: label,
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected
              ? Theme.of(context).colorScheme.secondaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              height: 48,
              child: Icon(icon, semanticLabel: ''),
            ),
          ),
        ),
      ),
    ),
  );

  /// The compact-mode flyout: `showMenu` anchored to the tapped icon's own
  /// right edge, positioned from its `RenderBox` — Material's equivalent of
  /// `fluent_ui`'s anchored flyout, not a re-implementation of it.
  Widget _compactGroupTile(
    BuildContext context,
    String group,
    List<OperationalDestination> children,
  ) => Builder(
    builder: (tileContext) => _compactTile(
      context,
      icon: children.first.icon,
      label: group,
      selected: _isGroupActive(children),
      onTap: () async {
        final box = tileContext.findRenderObject() as RenderBox;
        final overlay =
            Overlay.of(tileContext).context.findRenderObject() as RenderBox;
        final topRight = box.localToGlobal(
          box.size.topRight(Offset.zero),
          ancestor: overlay,
        );
        final bottomRight = box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlay,
        );
        final path = await showMenu<String>(
          context: tileContext,
          position: RelativeRect.fromRect(
            Rect.fromPoints(topRight, bottomRight),
            Offset.zero & overlay.size,
          ),
          items: [
            for (final destination in children)
              PopupMenuItem<String>(
                value: destination.path,
                child: Row(
                  children: [
                    Icon(destination.icon, size: 20),
                    const SizedBox(width: 12),
                    Text(destination.label),
                  ],
                ),
              ),
          ],
        );
        if (path != null && tileContext.mounted) {
          _navigate(tileContext, path);
        }
      },
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

  /// The drawer (phone/portrait) never collapses a group: Material's own
  /// convention there is inline expansion and there is room to spare — see
  /// the class doc on [_NavMode.hidden]'s sibling comment above `_navMode`.
  List<Widget> _navigationTiles(BuildContext context) {
    final grouped = _groupedDestinations();
    return [
      for (final entry in grouped.entries) ...[
        _groupHeader(context, entry.key),
        for (final destination in entry.value)
          _destinationTile(context, destination),
      ],
    ];
  }

  /// Fixed, theme-independent dark tone — the lámina's footer stays dark in
  /// its light-theme desktop view too, so this is deliberately not
  /// `colorScheme.surfaceContainerHighest` (which would go pale in light
  /// mode and read as "half of a gray page" rather than the lámina's own
  /// "one dark strip, light text").
  static const _footerBackground = Color(0xFF1B1D1F);
  static const _footerForeground = Colors.white;
  static const _footerMuted = Colors.white70;

  /// A single horizontal strip — never `Wrap`, which used to fold this into
  /// three stacked lines of gray-on-gray and was a real part of "parece
  /// rota". `SingleChildScrollView` is the safety net for a window too
  /// narrow to fit everything (never truncate information silently); it is
  /// not the lámina's own affordance, which assumes desktop width.
  Widget _contextFooter(BuildContext context) => Semantics(
    container: true,
    label: 'Información de conexión',
    child: Container(
      width: double.infinity,
      color: _footerBackground,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _contextItem('Servidor', this.context.server),
              _footerGap(),
              _contextItem('BD', this.context.database),
              _footerGap(),
              // El valor NO repite la etiqueta: «Hora del servidor: Hora del
              // servidor no disponible» es lo que se leía en pantalla. Y el
              // nombre corto es el que fija el contrato del pie en
              // SHELL_AND_INTERACTION_SPEC.md.
              _contextItem(
                'Hora servidor',
                this.context.serverTime ?? 'sin dato',
              ),
              _footerGap(),
              _statusDot(_statusColorFor(this.context.connectionLabel)),
              const SizedBox(width: 6),
              Text(
                this.context.connectionLabel,
                style: const TextStyle(color: _footerForeground),
              ),
              _footerGap(),
              const Icon(
                Icons.notifications_outlined,
                size: 14,
                color: _footerMuted,
              ),
              const SizedBox(width: 4),
              Text(
                this.context.syncLabel,
                style: const TextStyle(color: _footerForeground),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _footerGap() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 10),
    child: Text('·', style: TextStyle(color: _footerMuted)),
  );

  Widget _statusDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  /// Honest, not decorative: green only for a label this shell actually
  /// knows means connected. Today's `connectionLabel` is always the "sin
  /// verificar" placeholder (see `router.dart` — wiring real connectivity is
  /// its own tracked defect, not something to fake green here), so this
  /// renders amber for that case rather than inventing a status the app has
  /// not verified. The rule is ready for the day that binding lands.
  Color _statusColorFor(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('conectado')) return Colors.green;
    if (normalized.contains('sin conexión') || normalized.contains('error')) {
      return Colors.red;
    }
    return Colors.amber;
  }

  Widget _contextItem(String label, String value) => Text(
    '$label: $value',
    style: const TextStyle(color: _footerForeground),
  );

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
