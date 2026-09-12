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

  final String syncLabel;
}

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

  /// El ancho a partir del cual el carril enseña etiquetas.
  ///
  /// Entre 1366 (sólo iconos, confirmado en la lámina) y 1920 (con etiquetas,
  /// confirmado) la lámina no da ningún punto, así que 1440 es una
  /// interpolación deliberada, no una medida. Si alguna lámina lo fija, se
  /// cambia por el valor real.
  static const double _expandedBreakpoint = 1440;

  /// 🔴 Aquí había seis colores escritos a mano: tres para el pie y tres para
  /// el estado. Ninguno se decide ya en este fichero. Orden del dueño del
  /// 12-sep-2026: *«no tocar nada del estilo de fluent_ui, sólo escoger los
  /// colores principales en coordinación con Odoo»*.
  ///
  /// Fluent ya trae los tres del significado —éxito, precaución y crítico— y
  /// además los cambia solos entre tema claro y oscuro, cosa que un número
  /// escrito a mano no hace: el pie oscuro fijo se veía bien en claro y se
  /// perdía en oscuro.

  PaneDisplayMode _displayMode(BoxConstraints constraints) {
    // En vertical nunca hay carril permanente, a ningún ancho.
    if (constraints.maxWidth < constraints.maxHeight) {
      return PaneDisplayMode.minimal;
    }
    if (constraints.maxWidth >= _expandedBreakpoint) {
      return PaneDisplayMode.expanded;
    }
    if (constraints.maxWidth >= OrbiTheme.mediumBreakpoint) {
      return PaneDisplayMode.compact;
    }
    return PaneDisplayMode.minimal;
  }

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
      if (locked)
        IgnorePointer(
          key: const Key('operational-shell-interactivity'),
          child: ExcludeSemantics(child: _scaffold(buildContext)),
        )
      else
        _scaffold(buildContext),
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
    builder: (layoutContext, constraints) {
      final mode = _displayMode(constraints);
      final wideFooter =
          constraints.maxWidth >= 600 &&
          constraints.maxWidth >= constraints.maxHeight;
      return Column(
        children: [
          _header(layoutContext),
          Expanded(
            child: NavigationView(
              pane: _pane(mode),
              paneBodyBuilder: (item, _) => child,
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

  /// La cabecera: marca, empresa, usuario y las acciones de sesión.
  ///
  /// Es una fila propia y no el `TitleBar` de Fluent a propósito. Ese widget
  /// es la barra de título de una VENTANA de escritorio —trae controles de
  /// ventana y gestos de arrastre— y en ancho de teléfono revienta la
  /// disposición con una aserción del propio marco, reproducida al aislarlo.
  /// Lo que necesitamos aquí es la cabecera de la aplicación, que es otra cosa
  /// y no depende del sistema operativo.
  Widget _header(BuildContext buildContext) {
    final theme = FluentTheme.of(buildContext);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.micaBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          OrbiBrand(height: 28, color: theme.typography.body?.color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.companyLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: theme.typography.bodyStrong,
            ),
          ),
          // El nombre se calla en estrecho: entre el nombre y poder cerrar
          // sesión, en un teléfono manda el botón.
          if (MediaQuery.sizeOf(buildContext).width >=
              OrbiTheme.compactBreakpoint)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(context.userLabel),
            ),
          if (onLock != null)
            Tooltip(
              message: 'Bloquear',
              child: IconButton(
                key: const Key('lock-button'),
                icon: const Icon(FluentIcons.lock),
                onPressed: onLock,
              ),
            ),
          if (onSwitchUser != null)
            Tooltip(
              message: 'Cambiar de usuario',
              child: IconButton(
                key: const Key('switch-user-button'),
                icon: const Icon(FluentIcons.switch_user),
                onPressed: onSwitchUser,
              ),
            ),
          Tooltip(
            message: 'Cerrar sesión',
            child: IconButton(
              key: const Key('logout-button'),
              icon: const Icon(FluentIcons.sign_out),
              onPressed: onLogout,
            ),
          ),
        ],
      ),
    );
  }

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
  NavigationPane _pane(PaneDisplayMode mode) {
    final grouped = _groupedDestinations();
    final ordered = [for (final entry in grouped.entries) ...entry.value];
    final selected = ordered.indexWhere((d) => d.path == selectedPath);
    final activeGroup = selected < 0 ? null : ordered[selected].group;

    return NavigationPane(
      displayMode: mode,
      selected: selected < 0 ? null : selected,
      items: [
        for (final entry in grouped.entries)
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
              for (final destination in entry.value)
                PaneItem(
                  key: ValueKey(destination.path),
                  icon: Icon(destination.icon),
                  title: Text(destination.label),
                  body: const SizedBox.shrink(),
                  onTap: () => onNavigate(destination.path),
                ),
            ],
          ),
      ],
    );
  }

  /// Los destinos agrupados, conservando el orden en que llegan dentro de cada
  /// grupo y el orden de aparición de los grupos. No se ordena
  /// alfabéticamente: el orden de las áreas lo fija el contrato del marco.
  Map<String, List<OperationalDestination>> _groupedDestinations() {
    final groups = <String, List<OperationalDestination>>{};
    for (final destination in destinations) {
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
                  _contextItem('Servidor', context.server),
                  _footerGap(r),
                  _contextItem('BD', context.database),
                  _footerGap(r),
                  // El valor NO repite la etiqueta: «Hora del servidor: Hora
                  // del servidor no disponible» es lo que llegó a leerse.
                  _contextItem(
                    'Hora servidor',
                    context.serverTime ?? 'sin dato',
                  ),
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
                  Text(context.syncLabel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final status = context.connectionStatus;
    return status == null
        ? context.connectionLabel
        : connectionStatusLabel(status);
  }

  /// Honesto, no decorativo: verde sólo cuando el servidor contestó, rojo en
  /// los tres casos en que algo está roto de verdad, y ámbar sólo mientras no
  /// se haya medido nada.
  Color _connectionColor(ResourceDictionary r) {
    final status = context.connectionStatus;
    if (status != null) return _statusColorForStatus(r, status);
    return _statusColorFor(r, context.connectionLabel);
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
