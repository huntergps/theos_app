import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show ConnectionStatus, connectionStatusLabel;

import '../../app/theme/orbi_theme.dart';
import '../components/orbi_brand.dart';
import 'workspace_lock_screen.dart';

/// Una entrada de navegación que aporta el catálogo de capacidades activo.
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

/// El contexto de servidor y sesión que pinta [OperationalShell].
final class OperationalContext {
  const OperationalContext({
    required this.server,
    required this.database,
    required this.userLabel,
    required this.companyLabel,
    this.serverTime,
    required this.connectionLabel,
    this.connectionStatus,
    this.connectionLatency,
    this.noticesUnreadCount = 0,
    required this.syncLabel,
  });

  final String server;
  final String database;
  final String userLabel;
  final String companyLabel;
  final String? serverTime;

  /// Texto de conexión heredado, sólo de cadena. Se pinta únicamente cuando
  /// [connectionStatus] es nulo: se conserva para que quien todavía no esté
  /// conectado a una medida real siga enseñando algo, en vez de nada.
  final String connectionLabel;

  /// El estado medido. Cuando existe manda sobre [connectionLabel], para que
  /// los dos no puedan decir cosas distintas.
  final ConnectionStatus? connectionStatus;

  /// Ida y vuelta del último sondeo al servidor. Ausente hasta que
  /// `orbi_runtime` mida algo real: hoy `Json2BackendProbe.probe`
  /// (`orbi_runtime/lib/src/connectivity/json2_backend_probe.dart`) sólo
  /// devuelve si el servidor contestó, nunca cuánto tardó, así que este
  /// campo se queda en `null` — nunca un número inventado aquí.
  final Duration? connectionLatency;

  /// Avisos sin leer, para la campanita de la barra superior. 0 por defecto:
  /// nunca un contador rojo cuando no hay con qué respaldarlo.
  final int noticesUnreadCount;

  final String syncLabel;
}

/// El grupo bajo el que `router.dart` publica «Inicio»: un único destino que
/// no debe verse como un desplegable de un solo hijo (orden del dueño,
/// 13-sep-2026, comparando con `theos_pos`, donde Inicio es de primer nivel).
const _kHomeGroup = 'Workspace';

/// Rutas que ya no se pintan en el menú lateral porque ahora viven en la
/// barra superior: el indicador de avisos y el botón de actividades. Se
/// identifican por ruta y no por grupo porque las cuatro comparten el mismo
/// grupo «Sistema» en `router.dart`.
const _kActivitiesPath = '/activities';
const _kNoticesPath = '/notifications';

/// Rutas que se mudan al pie del panel (patrón `footerItems` de Fluent), en
/// vez de al grupo «Sistema» del menú principal.
const _kSyncPath = '/sync';
const _kQueuePath = '/sync/queue';
const _kSettingsPath = '/settings';

bool _isTopBarDestination(OperationalDestination d) =>
    d.path == _kActivitiesPath || d.path == _kNoticesPath;

bool _isFooterDestination(OperationalDestination d) =>
    d.path == _kSyncPath || d.path == _kQueuePath || d.path == _kSettingsPath;

bool _isGroupedNavDestination(OperationalDestination d) =>
    !_isTopBarDestination(d) && !_isFooterDestination(d);

/// El marco sobre el que se muestra toda la aplicación.
///
/// 🔴 **Es `NavigationView` de Fluent, no un andamiaje propio.** Antes esta
/// clase reimplementaba a mano los tres niveles de navegación —cajón, carril
/// de iconos con desplegable y carril con etiquetas—, unas cuatrocientas
/// líneas que Fluent ya trae y mantiene. La decisión del dueño del 11-sep-2026
/// de usar `fluent_ui` retira esa duplicación.
///
/// Lo que sí se conserva es **dónde están los cortes**, que no son los de
/// Fluent. Salen de la lámina aprobada `round-03/SHELL-01.png`, medidos sobre
/// ella:
///
/// - 1920×1080 → carril con etiquetas.
/// - 1366×1024 → carril de sólo iconos, donde Fluent ya habría abierto el suyo.
/// - vertical a cualquier ancho, y teléfono → sin carril, con hamburguesa.
///
/// La orientación cuenta tanto como el ancho: un iPad vertical de 1024 de
/// ancho **no** lleva carril, igual que el teléfono.
final class OperationalShell extends StatefulWidget {
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
    this.onToggleTheme,
    this.navigationDisplayMode = PaneDisplayMode.auto,
    this.navigationIndicator = const StickyNavigationIndicator(),
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

  /// Si el puesto está bloqueado. Puramente de presentación: el estado es de
  /// quien nos usa, para que sobreviva a lo que se reconstruya alrededor.
  final bool locked;

  /// Bloquea el puesto. Ausente significa que este marco no ofrece bloqueo,
  /// nunca un botón que la persona no pueda usar.
  final VoidCallback? onLock;

  /// Revalida la misma identidad para salir de [locked]. Obligatorio siempre
  /// que haya [onLock]: un bloqueo sin salida deja a alguien encerrado.
  final Future<bool> Function(String password)? onUnlock;

  /// Cierra el acceso de la identidad actual para que entre otra persona. Es
  /// una acción distinta de bloquear y de cerrar sesión.
  final VoidCallback? onSwitchUser;

  /// Alterna claro/oscuro desde la barra superior. Ausente esconde el botón
  /// —nunca uno que no responda—: se queda en `null` hasta que quien
  /// instancie este marco (`router.dart`) lo conecte a su propio `ThemeMode`.
  final VoidCallback? onToggleTheme;

  /// El modo del carril, elegido en Ajustes (orden del dueño, 13-sep-2026:
  /// fluent_ui se puede parametrizar, como hace su propia app de ejemplo en
  /// `example/lib/screens/settings.dart`). Este marco no traduce nombres de
  /// preferencia: quien lo instancia (`router.dart`) ya entrega el
  /// `PaneDisplayMode` de Fluent. Por defecto `auto`, que es lo que este
  /// marco usaba antes de ser parametrizable — Fluent sigue resolviendo ese
  /// modo por el ancho, tal como documenta [_OperationalShellState._pane].
  final PaneDisplayMode navigationDisplayMode;

  /// El indicador de selección del carril, también elegido en Ajustes. Por
  /// defecto `StickyNavigationIndicator`, el mismo que trae `NavigationPane`
  /// cuando no se especifica ninguno.
  final Widget navigationIndicator;

  /// 🔴 Aquí había seis colores escritos a mano: tres para el pie y tres para
  /// el estado. Ninguno se decide ya en este fichero. Orden del dueño del
  /// 12-sep-2026: *«no tocar nada del estilo de fluent_ui, sólo escoger los
  /// colores principales en coordinación con Odoo»*.
  ///
  /// Fluent ya trae los tres del significado —éxito, precaución y crítico— y
  /// además los cambia solos entre tema claro y oscuro, cosa que un número
  /// escrito a mano no hace: el pie oscuro fijo se veía bien en claro y se
  /// perdía en oscuro.

  @override
  State<OperationalShell> createState() => _OperationalShellState();
}

class _OperationalShellState extends State<OperationalShell> {
  @override
  Widget build(BuildContext buildContext) => Stack(
    children: [
      // El marco sigue montado aunque esté bloqueado: un borrador a medio
      // escribir no puede perderse porque alguien pulsara «Bloquear». Sólo se
      // suprime su interactividad; nada de debajo se reconstruye ni se tira.
      // Los envoltorios de bloqueo se ponen SÓLO al bloquear. Dejarlos
      // siempre puestos, aunque no hicieran nada, mete un nodo de semántica
      // por encima de la navegación de Fluent y el marco lanza una aserción
      // propia al recorrer el árbol de accesibilidad en anchos de teléfono.
      if (widget.locked)
        IgnorePointer(
          key: const Key('operational-shell-interactivity'),
          child: ExcludeSemantics(child: _scaffold(buildContext)),
        )
      else
        _scaffold(buildContext),
      if (widget.locked)
        Positioned.fill(
          child: WorkspaceLockScreen(
            userLabel: widget.context.userLabel,
            pendingSummary: widget.context.syncLabel,
            onUnlock: widget.onUnlock!,
            onSwitchUser: widget.onSwitchUser,
          ),
        ),
    ],
  );

  Widget _scaffold(BuildContext buildContext) => LayoutBuilder(
    builder: (layoutContext, constraints) {
      final wideFooter =
          constraints.maxWidth >= 600 &&
          constraints.maxWidth >= constraints.maxHeight;
      return Column(
        children: [
          _topBar(layoutContext, constraints.maxWidth),
          Expanded(
            child: NavigationView(
              pane: _pane(),
              // En modo estrecho el contenido llega con su propia barra: sin
              // ella no hay NINGUNA forma de abrir el menú (ver
              // [_minimalTopBar]).
              // El modo lo decide Fluent (`PaneDisplayMode.auto`); aquí sólo se
              // lee el que eligió.
              paneBodyBuilder: (item, _) => Builder(
                builder: (context) =>
                    NavigationView.of(context).displayMode ==
                        PaneDisplayMode.minimal
                    ? Column(
                        children: [
                          _minimalTopBar(),
                          Expanded(child: widget.child),
                        ],
                      )
                    : widget.child,
              ),
            ),
          ),
          if (wideFooter)
            _contextFooter(layoutContext)
          else
            _compactContextButton(layoutContext),
        ],
      );
    },
  );

  /// La barra superior, siempre visible sea cual sea el modo del carril.
  ///
  /// Va como HERMANA de `NavigationView`, no como su `titleBar`: Fluent
  /// dibuja el botón que abre el panel mínimo DENTRO de su propia
  /// `TitleBar`, y esa barra revienta a ancho de teléfono (ver la nota de
  /// [_minimalTopBar]). Quedando fuera, esta barra nunca toca ese camino y
  /// puede mostrarse siempre, incluso en teléfono — que es justo lo que pide
  /// la lámina de referencia (`14.png`: la barra corre por encima del carril
  /// y del contenido, en todos los anchos).
  ///
  /// Las acciones van en un `CommandBar` con `dynamicOverflow`: en angosto,
  /// Fluent mueve solo las que no caben a un menú «…», nunca las recorta
  /// (orden del dueño, 13-sep-2026). El bloque de usuario/avatar queda fuera
  /// del `CommandBar` a propósito — es la acción más importante y no debe
  /// competir por espacio con el resto.
  ///
  /// [availableWidth] llega medido por el `LayoutBuilder` de [_scaffold], no
  /// se relee con `MediaQuery.sizeOf`. Medido el 13-sep-2026 contra el
  /// router real (`router_company_label_test.dart`): `tester.binding.
  /// setSurfaceSize`, que ya usan las pruebas de nivel de router de este
  /// paquete, mueve las restricciones de diseño —por eso `NavigationPane`
  /// resuelve bien su propio modo— pero NO actualiza `MediaQuery.sizeOf`,
  /// que se quedaba en los 800×600 por omisión de `flutter_test` y escondía
  /// la empresa siempre. El ancho de layout es además la medida correcta:
  /// importa cuánto sitio tiene el marco, no el de la ventana entera.
  Widget _topBar(BuildContext context, double availableWidth) {
    final theme = FluentTheme.of(context);
    final ctx = widget.context;
    final hasActivities = widget.destinations.any(
      (d) => d.path == _kActivitiesPath,
    );
    final hasNotices = widget.destinations.any((d) => d.path == _kNoticesPath);

    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.only(start: 8, end: 8),
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CommandBar(
              overflowBehavior: CommandBarOverflowBehavior.dynamicOverflow,
              overflowItemBuilder: (onPressed) => CommandBarButton(
                key: const Key('shell-topbar-overflow'),
                icon: const Icon(FluentIcons.more),
                tooltip: 'Más acciones',
                onPressed: onPressed,
              ),
              primaryItems: [
                if (hasNotices)
                  CommandBarButton(
                    key: const Key('shell-notices-button'),
                    icon: _badgedIcon(
                      FluentIcons.ringer,
                      ctx.noticesUnreadCount,
                    ),
                    label: const Text('Avisos'),
                    tooltip: 'Avisos',
                    onPressed: () => widget.onNavigate(_kNoticesPath),
                  ),
                if (hasActivities)
                  CommandBarButton(
                    key: const Key('shell-activities-button'),
                    icon: const Icon(FluentIcons.clock),
                    label: const Text('Actividades'),
                    tooltip: 'Actividades pendientes',
                    onPressed: () => widget.onNavigate(_kActivitiesPath),
                  ),
                _ConnectivityCommandBarItem(
                  key: const Key('shell-connectivity-pill'),
                  context: ctx,
                ),
                if (widget.onToggleTheme != null)
                  CommandBarButton(
                    key: const Key('shell-theme-toggle'),
                    icon: Icon(
                      theme.brightness == Brightness.dark
                          ? FluentIcons.sunny
                          : FluentIcons.clear_night,
                    ),
                    label: Text(
                      theme.brightness == Brightness.dark ? 'Claro' : 'Oscuro',
                    ),
                    tooltip: 'Cambiar tema',
                    onPressed: widget.onToggleTheme,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _UserAvatarMenu(
            userLabel: ctx.userLabel,
            companyLabel: ctx.companyLabel,
            wide: availableWidth >= OrbiTheme.mediumBreakpoint,
            onOpenPreferences: () => widget.onNavigate(_kSettingsPath),
            onLock: widget.onLock,
            onSwitchUser: widget.onSwitchUser,
            onLogout: widget.onLogout,
          ),
        ],
      ),
    );
  }

  /// Un icono con una insignia numérica arriba a la derecha, sólo cuando
  /// [count] es positivo — nunca un círculo rojo vacío de adorno.
  Widget _badgedIcon(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  /// La única forma de abrir el menú cuando el carril está escondido.
  ///
  /// 🔴 Sin esto la aplicación **encierra a la persona en la pantalla en la
  /// que esté**: en vertical o en teléfono no hay carril, ni hamburguesa, ni
  /// nada que abra el menú. Medido abriéndola a 500 de ancho.
  ///
  /// La causa es de diseño de Fluent: el botón que abre el panel lo dibuja él
  /// **dentro de su barra de título**, y esa barra —que es la de una ventana
  /// de escritorio— revienta a ancho de teléfono con una aserción del propio
  /// marco. Sin barra de título, Fluent coloca ese botón **dentro del panel**,
  /// que es justo lo que está escondido. El botón queda inalcanzable.
  ///
  /// Va dentro del cuerpo, no encima de todo, porque tiene que ser
  /// descendiente del `NavigationView` para poder abrirlo. Ya no lleva el
  /// nombre de la empresa: eso lo dice ahora [_topBar], que está siempre
  /// visible, y repetirlo aquí lo duplicaba en pantalla.
  Widget _minimalTopBar() => Builder(
    builder: (context) {
      final theme = FluentTheme.of(context);
      return Container(
        height: 44,
        padding: const EdgeInsets.only(left: 4, right: 12),
        decoration: BoxDecoration(
          color: theme.micaBackgroundColor,
          border: Border(
            bottom: BorderSide(
              color: theme.resources.dividerStrokeColorDefault,
            ),
          ),
        ),
        child: Row(
          children: [
            Tooltip(
              message: 'Menú',
              child: IconButton(
                key: const Key('operational-menu-button'),
                icon: const Icon(FluentIcons.global_nav_button),
                onPressed: () =>
                    NavigationView.of(context).isMinimalPaneOpen = true,
              ),
            ),
          ],
        ),
      );
    },
  );

  /// La cabecera del panel: sólo la marca.
  ///
  /// Va en `NavigationPane.header` y no en una fila propia por encima de todo.
  /// La empresa ya NO se repite aquí (orden del dueño, 13-sep-2026, comparando
  /// con `theos_pos`, donde el panel sólo lleva el logo): ahora vive siempre
  /// en [_topBar], y enseñarla en los dos sitios la duplicaba en pantalla —el
  /// mismo motivo por el que antes ya se ocultaba en el carril mínimo.
  Widget _paneHeader() => Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: OrbiBrand(
        height: 24,
        color: FluentTheme.of(context).typography.body?.color,
      ),
    ),
  );

  /// El menú, con sus grupos.
  ///
  /// Cada área es un `PaneItemExpander` **sin cuerpo propio**: pulsarlo abre y
  /// cierra el grupo, no navega a ningún sitio, porque un área no es una
  /// pantalla. Fluent excluye de la cuenta de selección los que no tienen
  /// cuerpo, así que el índice del destino elegido coincide con su posición
  /// en la lista de destinos y no hay que llevar dos numeraciones en paralelo.
  ///
  /// En el carril de sólo iconos, Fluent enseña los hijos en un desplegable
  /// por sí solo. Eso es exactamente lo que dibuja la lámina, y no hay que
  /// escribirlo: era una de las cuatrocientas líneas que esta migración quitó.
  ///
  /// Tres rutas ya no pasan por aquí como el resto: «Actividades» y «Avisos»
  /// viven ahora en [_topBar] (mismo grupo «Sistema» en `router.dart`, pero
  /// duplicarlas en el menú lateral las mostraba dos veces); «Sincronización»
  /// y «Configuración» se pintan en el pie del panel, con el patrón
  /// `footerItems` de Fluent (orden del dueño, 13-sep-2026). Y el grupo
  /// «Workspace» —hoy sólo «Inicio»— se pinta de primer nivel, sin el
  /// desplegable de un solo hijo que tenía antes.
  NavigationPane _pane() {
    final navDestinations = widget.destinations
        .where(_isGroupedNavDestination)
        .toList(growable: false);
    final footerDestinations = widget.destinations
        .where(_isFooterDestination)
        .toList(growable: false);
    final grouped = _groupedDestinations(navDestinations);
    final ordered = [
      for (final entry in grouped.entries) ...entry.value,
      ...footerDestinations,
    ];
    final selectedIndex = ordered.indexWhere(
      (d) => d.path == widget.selectedPath,
    );
    final activeGroup = selectedIndex < 0 ? null : ordered[selectedIndex].group;

    final items = <NavigationPaneItem>[];
    for (final entry in grouped.entries) {
      if (entry.key == _kHomeGroup) {
        for (final destination in entry.value) {
          items.add(_navPaneItem(destination));
        }
      } else {
        items.add(
          PaneItemExpander(
            key: ValueKey('grupo-${entry.key}'),
            // El icono del grupo es el de su primer destino: sin icono, en el
            // carril estrecho el área se vuelve invisible.
            icon: Icon(entry.value.first.icon),
            title: Text(entry.key),
            // El grupo de la pantalla que se está viendo nace abierto: cerrado
            // obligaría a abrirlo para saber dónde se está.
            initiallyExpanded: entry.key == activeGroup,
            items: [
              for (final destination in entry.value) _navPaneItem(destination),
            ],
          ),
        );
      }
    }

    return NavigationPane(
      // Sin cortes propios: en modo `auto` el ancho en que el menú se oculta,
      // se vuelve de iconos o se abre lo decide Fluent (orden del dueño,
      // 13-sep-2026). El modo en sí ya es parametrizable desde Ajustes —quien
      // instancia este marco decide si en vez de `auto` se fija `expanded`,
      // `compact`, `minimal` o `top`.
      displayMode: widget.navigationDisplayMode,
      indicator: widget.navigationIndicator,
      selected: selectedIndex < 0 ? null : selectedIndex,
      header: _paneHeader(),
      footerItems: [
        for (final destination in footerDestinations) _navPaneItem(destination),
      ],
      items: items,
    );
  }

  PaneItem _navPaneItem(OperationalDestination destination) => PaneItem(
    key: ValueKey(destination.path),
    icon: Icon(destination.icon),
    title: Text(destination.label),
    body: const SizedBox.shrink(),
    onTap: () => widget.onNavigate(destination.path),
  );

  /// Los destinos agrupados, conservando el orden en que llegan dentro de cada
  /// grupo y el orden de aparición de los grupos. No se ordena
  /// alfabéticamente: el orden de las áreas lo fija el contrato del marco.
  Map<String, List<OperationalDestination>> _groupedDestinations(
    List<OperationalDestination> source,
  ) {
    final groups = <String, List<OperationalDestination>>{};
    for (final destination in source) {
      groups.putIfAbsent(destination.group, () => []).add(destination);
    }
    return groups;
  }

  // La semántica va DENTRO del desplazamiento, no envolviéndolo: envolviendo
  // un scroll horizontal con un contenedor semántico, el árbol de
  // accesibilidad se recorre antes de que termine la disposición y el marco
  // lanza una aserción propia. Se ve sólo en anchos de teléfono.
  Widget _contextFooter(BuildContext buildContext) {
    // Todo el color sale del tema: el pie ya no lleva un fondo oscuro fijo,
    // que se veía bien en tema claro y se perdía en oscuro.
    final theme = FluentTheme.of(buildContext);
    final r = theme.resources;
    final ctx = widget.context;
    return ColoredBox(
      color: r.solidBackgroundFillColorTertiary,
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Semantics(
            label: 'Información de conexión',
            child: DefaultTextStyle(
              style: theme.typography.caption ?? const TextStyle(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _contextItem('Servidor', ctx.server),
                  _footerGap(r),
                  _contextItem('BD', ctx.database),
                  _footerGap(r),
                  // Causa raíz de «Hora servidor: sin dato» (medido
                  // 13-sep-2026): `router.dart` nunca llenó `serverTime` —el
                  // campo existía pero nadie lo llenaba. Y no hay de dónde
                  // sacar la hora real del servidor: `Json2BackendProbe`
                  // (`orbi_runtime/lib/src/connectivity/json2_backend_probe.dart:26-49`)
                  // sólo confirma que el servidor contestó, nunca trae su
                  // reloj, y `theos_pos` tampoco lo tiene —su
                  // `_syncServerTime` fija el desfase en CERO siempre
                  // (`theos_pos/lib/shared/providers/server_info_provider.dart:161`),
                  // así que su «hora servidor» YA ES la hora local, sólo que
                  // mal etiquetada. Aquí se opta por lo honesto: si no llega
                  // una hora real, se enseña la del dispositivo, con una
                  // etiqueta que no finge ser la del servidor.
                  if (ctx.serverTime != null)
                    _contextItem('Hora servidor', ctx.serverTime!)
                  else
                    _contextItem('Hora', _formatLocalClock(DateTime.now())),
                  _footerGap(r),
                  _statusDot(_connectionColor(r)),
                  const SizedBox(width: 6),
                  Text(_connectionText()),
                  _footerGap(r),
                  Icon(
                    FluentIcons.ringer,
                    size: 14,
                    color: r.textFillColorSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(ctx.syncLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sin `intl` y sin `Timer.periodic` a propósito: un reloj que tiquetea
  /// solo mantiene el pie reconstruyéndose cada segundo, y
  /// `tester.pumpAndSettle()` —que usa toda la batería de pruebas de este
  /// marco— nunca termina mientras haya un temporizador periódico vivo
  /// (vuelve a programar un fotograma en cada disparo). Se muestra la hora
  /// del dispositivo en el momento en que se pinta el pie, que ya se
  /// refresca solo cada vez que algo más en el marco cambia.
  String _formatLocalClock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  Widget _footerGap(ResourceDictionary r) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Text('·', style: TextStyle(color: r.textFillColorSecondary)),
  );

  Widget _statusDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _contextItem(String label, String value) => Text('$label: $value');

  /// Lo que el pie enseña de verdad: el estado medido cuando lo hay, con la
  /// redacción fija de cada caso, y nunca la cadena de quien nos usa una vez
  /// existe una medida, para que las dos no puedan decir cosas distintas.
  String _connectionText() {
    final status = widget.context.connectionStatus;
    return status == null
        ? widget.context.connectionLabel
        : connectionStatusLabel(status);
  }

  /// Honesto, no decorativo: verde sólo cuando el servidor contestó, rojo en
  /// los tres casos en que algo está roto de verdad, y ámbar sólo mientras no
  /// se haya medido nada.
  Color _connectionColor(ResourceDictionary r) {
    final status = widget.context.connectionStatus;
    if (status != null) return _statusColorForStatus(r, status);
    return _statusColorFor(r, widget.context.connectionLabel);
  }

  Color _statusColorForStatus(ResourceDictionary r, ConnectionStatus status) =>
      switch (status) {
        ConnectionStatus.online => r.systemFillColorSuccess,
        ConnectionStatus.offline => r.systemFillColorCritical,
        ConnectionStatus.backendUnreachable => r.systemFillColorCritical,
        ConnectionStatus.backendUnauthorized => r.systemFillColorCritical,
        ConnectionStatus.unknown => r.systemFillColorCaution,
      };

  /// Resguardo heredado, sólo para quien todavía no pase un estado medido.
  /// Adivinar un color a partir de un texto libre es justo la fragilidad que
  /// el estado tipado vino a retirar: no amplíes esta lista, conecta a quien
  /// llama.
  Color _statusColorFor(ResourceDictionary r, String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('conectado')) return r.systemFillColorSuccess;
    if (normalized.contains('sin conexión') || normalized.contains('error')) {
      return r.systemFillColorCritical;
    }
    return r.systemFillColorCaution;
  }

  Widget _compactContextButton(BuildContext buildContext) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Tooltip(
      message: 'Detalle de conexión',
      child: IconButton(
        key: const Key('operational-context-button'),
        icon: const Icon(FluentIcons.info),
        // En estrecho el pie no cabe, así que se pide. Un diálogo y no una
        // hoja inferior porque Fluent no trae hoja inferior y fabricarse una
        // sería justo el andamiaje propio que esta migración vino a quitar.
        onPressed: () => showDialog<void>(
          context: buildContext,
          builder: (dialogContext) => ContentDialog(
            title: const Text('Detalle de conexión'),
            content: _contextFooter(dialogContext),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// La píldora de conectividad de [OperationalShell._topBar], como un
/// `CommandBarItem` propio: en primario se ve como una píldora de color, y en
/// el desbordamiento («…») se ve igual pero con el espaciado de un renglón de
/// menú. Subclasificar `CommandBarItem` es el propio mecanismo de extensión
/// de Fluent (ver la documentación de la clase en `fluent_ui`), no un
/// andamiaje inventado aquí.
class _ConnectivityCommandBarItem extends CommandBarItem {
  const _ConnectivityCommandBarItem({super.key, required this.context});

  final OperationalContext context;

  @override
  Widget build(BuildContext buildContext, CommandBarItemDisplayMode mode) {
    final pill = _ConnectivityPill(key: key, context: context);
    switch (mode) {
      case CommandBarItemDisplayMode.inPrimary:
      case CommandBarItemDisplayMode.inPrimaryCompact:
        return CommandBarItemInPrimary(child: pill);
      case CommandBarItemDisplayMode.inSecondary:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: pill,
        );
    }
  }
}

/// El texto exacto lo pidió el dueño (13-sep-2026): «En línea 349 ms», «Sin
/// conexión», «Servidor no responde». No es el mismo vocabulario que
/// [connectionStatusLabel] —el del pie de abajo, más formal («Conectado»,
/// «Red sin servidor»)— porque la píldora de la barra superior es la lectura
/// rápida de un vistazo, y el pie es el detalle. Los dos estados que el dueño
/// no nombró (sin verificar, servidor sin autorizar) sí reutilizan
/// [connectionStatusLabel], para no inventar un vocabulario paralelo donde no
/// hizo falta.
class _ConnectivityPill extends StatelessWidget {
  const _ConnectivityPill({super.key, required this.context});

  final OperationalContext context;

  @override
  Widget build(BuildContext buildContext) {
    final theme = FluentTheme.of(buildContext);
    final color = _color(theme.resources);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _label(),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _label() {
    final status = context.connectionStatus;
    if (status == null) return context.connectionLabel;
    switch (status) {
      case ConnectionStatus.online:
        final latency = context.connectionLatency;
        return latency == null
            ? 'En línea'
            : 'En línea ${latency.inMilliseconds} ms';
      case ConnectionStatus.offline:
        return 'Sin conexión';
      case ConnectionStatus.backendUnreachable:
        return 'Servidor no responde';
      case ConnectionStatus.backendUnauthorized:
      case ConnectionStatus.unknown:
        return connectionStatusLabel(status);
    }
  }

  Color _color(ResourceDictionary r) {
    final status = context.connectionStatus;
    if (status == null) return r.systemFillColorCaution;
    switch (status) {
      case ConnectionStatus.online:
        return r.systemFillColorSuccess;
      case ConnectionStatus.offline:
      case ConnectionStatus.backendUnreachable:
      case ConnectionStatus.backendUnauthorized:
        return r.systemFillColorCritical;
      case ConnectionStatus.unknown:
        return r.systemFillColorCaution;
    }
  }
}

/// El avatar y su menú, en la barra superior.
///
/// Junta lo que antes estaba repartido: el rótulo de usuario que vivía suelto
/// en el pie del panel, y Bloquear/Cambiar de usuario/Cerrar sesión que eran
/// `PaneItemAction` del mismo pie (orden del dueño, 13-sep-2026, comparando
/// con `theos_pos`: ver `theos_pos/lib/shared/screens/main_screen.dart`,
/// `_UserAvatarMenu`). No hay foto ni estado de presencia: `OperationalContext`
/// no trae ninguno de los dos, y no se inventa ninguno aquí.
///
/// La presencia (En línea/Ausente/No molestar) que sí tiene `theos_pos` NO se
/// replica: `res.users.manual_im_status` no es un campo `user_writeable` en
/// Odoo 20 (`dev_odoo20/odoo/addons/mail/models/res_users.py:66-69`), y
/// `res.users._has_field_access` exige sudo o el grupo «Access Rights» para
/// escribir cualquier campo del propio usuario que no lleve esa marca
/// (`dev_odoo20/odoo/odoo/addons/base/models/res_users.py:588-598`). El único
/// camino que Odoo ofrece para cambiarla es el controlador de sesión web
/// `/mail/set_manual_im_status` (`dev_odoo20/odoo/addons/mail/controllers/im_status.py:9-13`,
/// `auth="user"`, cookie de sesión) — no el `/json/2/<modelo>/<método>` con
/// Bearer que usa todo este cliente. Ponerla aquí sería un menú de adorno
/// para cualquier vendedor que no sea administrador.
class _UserAvatarMenu extends StatefulWidget {
  const _UserAvatarMenu({
    required this.userLabel,
    required this.companyLabel,
    required this.wide,
    required this.onOpenPreferences,
    required this.onLogout,
    this.onLock,
    this.onSwitchUser,
  });

  final String userLabel;
  final String companyLabel;

  /// Si hay sitio para el nombre y la empresa junto al avatar. Llega ya
  /// calculado por [OperationalShell._topBar] a partir del ancho de layout
  /// (ver la nota allí sobre por qué no se usa `MediaQuery.sizeOf` aquí).
  final bool wide;
  final VoidCallback onOpenPreferences;
  final VoidCallback onLogout;
  final VoidCallback? onLock;
  final VoidCallback? onSwitchUser;

  @override
  State<_UserAvatarMenu> createState() => _UserAvatarMenuState();
}

class _UserAvatarMenuState extends State<_UserAvatarMenu> {
  final _controller = FlyoutController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _initialsColor(String seed) {
    if (seed.isEmpty) return Colors.grey;
    final random = Random(seed.hashCode);
    return Color.fromARGB(
      255,
      30 + random.nextInt(200),
      30 + random.nextInt(200),
      30 + random.nextInt(200),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.userLabel.isNotEmpty
        ? widget.userLabel[0].toUpperCase()
        : 'U';

    return FlyoutTarget(
      controller: _controller,
      child: GestureDetector(
        key: const Key('shell-avatar-button'),
        // Sin esto, tocar el hueco entre el nombre (corto, "erik") y la
        // empresa (más larga, alineados ambos a la derecha con
        // `CrossAxisAlignment.end`) no llega a ningún párrafo pintado, y
        // `deferToChild` (el comportamiento por omisión de `GestureDetector`)
        // no cuenta eso como un toque. Medido el 13-sep-2026 con el router
        // real (`workspace_switch_user_router_test.dart`): `tester.tap`
        // apunta al CENTRO de todo el renglón —texto más avatar—, y ese
        // centro cae justo en ese hueco cuando los dos textos no miden lo
        // mismo. `opaque` hace que toda la fila responda, no sólo el texto o
        // el cuadro del avatar.
        behavior: HitTestBehavior.opaque,
        onTap: _openMenu,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.wide) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.userLabel,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    widget.companyLabel,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _initialsColor(widget.userLabel),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔴 `MenuFlyoutItem.closeAfterClick` (el valor por omisión de Fluent)
  /// cierra el menú con `Navigator.of(context).maybePop()`. Eso funciona
  /// para una acción simple, pero «Cambiar de usuario» abre OTRO diálogo de
  /// confirmación desde la misma pulsada, y ahí `maybePop()` deja el
  /// renglón del menú vivo en el árbol —`isOpen` del controlador ya dice
  /// `false`, pero el widget sigue montado— probablemente porque una nueva
  /// ruta empuja al navegador antes de que la transición de salida del
  /// `maybePop` termine de resolverse. El síntoma, aislado el 13-sep-2026
  /// contra el propio `_UserAvatarMenu` sin `router.dart` de por medio: al
  /// cancelar el diálogo, la siguiente pulsada sobre el avatar cae en la
  /// cortina del menú viejo (que se cierra sola) en vez de abrir uno nuevo.
  /// `FlyoutController.forceClose()` saca la ruta del navegador al
  /// instante, sin esperar una transición — es lo correcto aquí: el renglón
  /// que se pulsó ya va a desaparecer de todas formas tras la acción.
  VoidCallback? _closeThenRun(VoidCallback? action) {
    if (action == null) return null;
    return () {
      _controller.forceClose();
      action();
    };
  }

  void _openMenu() {
    _controller.showFlyout(
      autoModeConfiguration: FlyoutAutoConfiguration(
        preferredMode: FlyoutPlacementMode.bottomRight,
      ),
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            key: const Key('shell-preferences-item'),
            leading: const Icon(FluentIcons.settings),
            text: const Text('Mis preferencias'),
            closeAfterClick: false,
            onPressed: _closeThenRun(widget.onOpenPreferences),
          ),
          if (widget.onLock != null)
            MenuFlyoutItem(
              key: const Key('lock-button'),
              leading: const Icon(FluentIcons.lock),
              text: const Text('Bloquear'),
              closeAfterClick: false,
              onPressed: _closeThenRun(widget.onLock),
            ),
          if (widget.onSwitchUser != null)
            MenuFlyoutItem(
              key: const Key('switch-user-button'),
              leading: const Icon(FluentIcons.switch_user),
              text: const Text('Cambiar de usuario'),
              closeAfterClick: false,
              onPressed: _closeThenRun(widget.onSwitchUser),
            ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            key: const Key('logout-button'),
            leading: const Icon(FluentIcons.sign_out),
            text: const Text('Cerrar sesión'),
            closeAfterClick: false,
            onPressed: _closeThenRun(widget.onLogout),
          ),
        ],
      ),
    );
  }
}

const appShellHeaderHeight = 50.0;
