import 'dart:async';
import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart'
    show
        ClientPolicyTimeSource,
        ConnectionStatus,
        OdooPresence,
        RealtimeStatus,
        connectionStatusLabel,
        realtimeStatusLabel;

import '../../app/theme/orbi_theme.dart';
import '../../features/auth/saved_servers.dart' show ServerEnvironment;
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
    this.odooVersion,
    required this.connectionLabel,
    this.connectionStatus,
    this.connectionLatency,
    this.realtimeStatus,
    this.noticesUnreadCount = 0,
    this.activitiesPendingCount = 0,
    this.routeModeActive = false,
    this.pendingOperationsCount = 0,
    required this.syncLabel,
    this.storageIsVolatile = false,
    this.serverClock,
    this.offlineBlockedMessage,
    this.environment,
    this.deviceName,
    this.cashSessionOpen = false,
    this.sriPending,
  });

  final String server;
  final String database;
  final String userLabel;
  final String companyLabel;

  /// `Odoo <mayor>.<menor>` (`OdooClient.version`, tras `fetchVersion()`).
  /// `null` mientras no se conozca — nunca se inventa una versión ni se
  /// muestra un «sin dato»: el pie simplemente omite el segmento.
  final String? odooVersion;

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

  /// Estado del socket de tiempo real (`app_sync/changed`), pintado como una
  /// segunda píldora junto a [connectionStatus] — hueco 1 de la auditoría de
  /// tiempo real del 14-sep-2026: `RealtimeStatus` (`orbi_runtime`) ya
  /// existía, pero nada en la UI lo leía. `null` cuando no hay coordinador
  /// de tiempo real activo (sesión sin conexión, o composición de pruebas
  /// que no lo compone): en ese caso no se pinta ninguna píldora, nunca un
  /// estado inventado.
  final RealtimeStatus? realtimeStatus;

  /// Avisos sin leer, para la campanita de la barra superior. 0 por defecto:
  /// nunca un contador rojo cuando no hay con qué respaldarlo.
  final int noticesUnreadCount;

  /// Actividades abiertas (no `ActivityStatus.done`), para el contador de la
  /// campana de Actividades — mismo patrón que [noticesUnreadCount].
  final int activitiesPendingCount;

  /// Si la preferencia «Modo Ruta» (Ajustes → Sincronización) está activa.
  /// Cuando lo está, la sincronización remota está en pausa
  /// (`scopeRouteModePauseProvider`, `router.dart`), y la barra superior lo
  /// dice — comparando con `theos_pos`, que ya trae este indicador
  /// (`RouteModeIndicatorBadge`, `main_screen.dart`).
  final bool routeModeActive;

  /// Operaciones en la cola offline (`SyncSnapshot.queuedCount`, la misma
  /// cifra que ya lee `/sync/queue`). 0 por defecto: nunca un badge cuando no
  /// hay nada pendiente.
  final int pendingOperationsCount;

  final String syncLabel;

  /// `true` cuando el navegador cayó a un almacenamiento que NO sobrevive a
  /// cerrar la pestaña (`RuntimeStorageMode.volatile`,
  /// `orbi_runtime/lib/src/storage/runtime_database_owner.dart`). `false`
  /// tanto si es persistente como si todavía no se sabe (`unknown`) — nunca
  /// se avisa de algo que no se ha medido. En escritorio (nativo) siempre es
  /// `false`. `router.dart` es quien traduce el `RuntimeStorageMode` real a
  /// este booleano; este marco sólo lo pinta.
  final bool storageIsVolatile;
  /// Hora del servidor y con qué respaldo, para el reloj del pie
  /// ([_FooterClock]) — `router.dart` la arma desde `ClientPolicyService`
  /// (`orbi_runtime/lib/src/clock/client_policy_service.dart`). `null` deja
  /// el pie con la hora LOCAL cruda, sin etiqueta: el comportamiento de
  /// antes de que existiera esta clase, para cualquier composición que
  /// todavía no tenga sesión de la que sincronizar nada.
  final ServerClockStatus? serverClock;

  /// Límite de sesión sin conexión (decisión del dueño, 14-sep-2026):
  /// no nulo cuando `OfflineAllowanceStore.evaluate` (`orbi_runtime`) dejó
  /// de decir `allowed` MIENTRAS la app seguía abierta sin conexión —
  /// `router.dart` lo revisa cada minuto
  /// (`_OfflineAllowanceBlockNotifier`). El armazón se bloquea con este
  /// mensaje, sin cerrar sesión ni tocar datos locales; vuelve a `null`
  /// solo cuando la próxima sincronización buena lo confirma. `null` es el
  /// caso normal — nunca un bloqueo inventado por este marco.
  final String? offlineBlockedMessage;
  /// Ambiente del servidor activo — «Pruebas» o «Producción», lo dice el
  /// dueño servidor por servidor al guardarlo (`SavedServer.environment`,
  /// `router.dart` lo empareja por URL+base contra los accesos guardados).
  /// `null` cuando no se marcó nada: no se pinta ninguna píldora, nunca se
  /// adivina del nombre del servidor.
  final ServerEnvironment? environment;

  /// Nombre del equipo para el pie, junto a servidor y base
  /// (`DeviceNameStore`, `orbi/device/name` — por INSTALACIÓN, no por
  /// usuario). `null` o vacío no se pinta.
  final String? deviceName;

  /// Si hay una sesión de caja abierta para quien tiene el permiso
  /// `cashier` — mismo lector que ya usa Inicio
  /// (`homeCashSessionsProvider`, `home_dashboard_providers.dart`); este
  /// marco no repite la consulta. `false` por omisión: nunca una píldora de
  /// caja sin haber comprobado una sesión real.
  final bool cashSessionOpen;

  /// Comprobantes electrónicos pendientes del SRI. `null` cuando el
  /// servidor no tiene el campo (`account.move.edi_state`, de
  /// `account_edi` — del que depende `l10n_ec_edi`) o cuando nunca se pudo
  /// contar: nunca una cifra inventada.
  final SriPendingStatus? sriPending;
}

/// Lo que necesita la píldora «N pendientes SRI»: la última cuenta conocida
/// de comprobantes electrónicos pendientes de autorizar o de anular ante el
/// SRI (`account.move.edi_state` en `to_send`/`to_cancel` —
/// `account_edi/models/account_move.py:18-23`, el módulo genérico del que
/// depende `l10n_ec_edi`), y si esa cuenta es una lectura fresca o la
/// última que se pudo tomar sin conexión.
final class SriPendingStatus {
  const SriPendingStatus({required this.count, this.isLastReading = false});

  /// Siempre mayor que cero: con 0 pendientes, quien arma este contexto
  /// (`router.dart`) pasa `null` en vez de construir una instancia — la
  /// píldora se apaga así, nunca mostrando «0 pendientes SRI».
  final int count;

  /// `true` cuando la cifra viene de la última sincronización con éxito, no
  /// de un sondeo hecho ahora mismo (sin conexión, o sin cliente activo) —
  /// la píldora lo dice como «(última lectura)» para no dar a entender que
  /// se confirmó en este instante.
  final bool isLastReading;
}

/// Lo que necesita el reloj del pie para pintar la hora del servidor en vez
/// de la del equipo: la lectura ya calculada (nunca hace RPC, sólo lee el
/// desfase que ya sincronizó `ClientPolicyService`), en qué zona pintarla y
/// con qué respaldo — para el tooltip y el aviso de reloj atrasado.
final class ServerClockStatus {
  const ServerClockStatus({
    required this.nowServer,
    required this.userTzOffset,
    required this.usesDeviceTzFallback,
    required this.source,
    required this.isEstimated,
    this.rtt,
    this.lastSyncAt,
    this.lastOnlineAt,
    this.clockRollbackSuspected = false,
  });

  /// UTC, con el desfase de `ClientPolicyService` ya aplicado. Lectura pura
  /// —nunca hace red— apta para el tic de 1 segundo del pie.
  final DateTime Function() nowServer;

  /// Desfase de la zona horaria del USUARIO respecto a UTC, para convertir
  /// [nowServer] a hora de pared. Revisión del dueño, 14-sep-2026: ya no
  /// sale de una tabla fija de nombres de zona (Orbi debe funcionar con
  /// cualquier Odoo, no sólo con Ecuador) — `router.dart` lo arma con
  /// `ClientPolicySnapshot.userTzOffset` (el `user_tz_offset_minutes` de
  /// `client_policy()`) cuando el servidor lo trae, o con
  /// `DateTime.now().timeZoneOffset` (la zona del EQUIPO) cuando no —
  /// ver [usesDeviceTzFallback].
  final Duration userTzOffset;

  /// `true` cuando [userTzOffset] es la zona del EQUIPO porque el servidor
  /// no trajo `user_tz_offset_minutes` (módulo viejo sin ese campo, o "el
  /// modelo no existe") — el detalle del reloj lo aclara con "en la zona de
  /// este equipo", para no dar a entender que esa hora la confirmó Odoo.
  final bool usesDeviceTzFallback;

  final ClientPolicyTimeSource source;

  /// Sin conexión, o sin haber sincronizado todavía en ESTA sesión — ver
  /// `ClientPolicyService.isEstimated`.
  final bool isEstimated;

  /// Ida y vuelta de la última sincronización real. `null` cuando nunca
  /// hubo una (nunca se inventa un número).
  final Duration? rtt;

  /// UTC. Cuándo se supo por última vez la hora real del servidor —incluida
  /// la sincronización que confirmó que el servidor no tiene el modelo—.
  final DateTime? lastSyncAt;

  /// UTC. Cuándo se habló con el servidor por última vez CON ÉXITO
  /// (`source == server`). `null` si nunca ocurrió en ningún momento de la
  /// vida de esta instalación.
  final DateTime? lastOnlineAt;

  final bool clockRollbackSuspected;
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
    this.clockTickInterval = const Duration(seconds: 1),
    this.now = DateTime.now,
    this.presence,
    this.onPresenceChanged,
    this.onOpenPreferences,
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

  /// Cada cuánto avanza el reloj del pie ancho ([_FooterClock]). `null`
  /// apaga el temporizador y deja el reloj fijo en la hora en que se pintó
  /// — lo que usan las pruebas de este marco, porque un `Timer.periodic`
  /// vivo nunca deja terminar a `tester.pumpAndSettle()` (ver la nota en
  /// [_FooterClock]). El valor de producción, 1 segundo, es el por omisión:
  /// `router.dart` no lo sobreescribe.
  final Duration? clockTickInterval;

  /// De dónde saca la hora el reloj del pie ([_FooterClock]). `DateTime.now`
  /// por omisión — el único motivo para inyectar otra cosa es una prueba:
  /// `pump(duration)` sólo adelanta el reloj falso de `Timer`
  /// (`AutomatedTestWidgetsFlutterBinding`, vía `FakeAsync`), nunca
  /// `DateTime.now()`, que sigue leyendo el reloj real del sistema. Sin este
  /// gancho, ninguna prueba podría comprobar que el reloj avanza sin
  /// depender de que pase un segundo de verdad.
  @visibleForTesting
  final DateTime Function() now;

  /// El estado de presencia del usuario (`res.users.manual_im_status`,
  /// `False`→`OdooPresence.online`). `null` cuando no se conoce todavía —
  /// nunca se pinta un punto adivinado. Quien instancie este marco
  /// (`router.dart`) es responsable de leerlo; este widget sólo lo muestra.
  final OdooPresence? presence;

  /// Cambia la presencia. `null` esconde el submenú «Estado» por completo
  /// — es el caso de un servidor sin `mobile_set_im_status`
  /// (`l10n_ec_collection_box_pos/models/res_users.py:253-283`), donde
  /// ofrecerlo sería un control que nunca responde.
  final ValueChanged<OdooPresence>? onPresenceChanged;

  /// Abre las preferencias PERSONALES del usuario de Odoo desde «Mis
  /// preferencias» del menú del avatar — no la configuración de la app
  /// (`SettingsScreen`, que sigue viviendo en `/settings`, alcanzable desde
  /// «Configuración» del carril o del pie, con `onNavigate`). `null` cuando
  /// quien instancia este marco no tiene con qué construir el diálogo
  /// (por ejemplo, sin sesión con base local): en ese caso «Mis
  /// preferencias» cae de vuelta a `onNavigate('/settings')`, el
  /// comportamiento de antes de que existiera este parámetro — nunca un
  /// botón que no responda.
  ///
  /// 🔴 Antes «Mis preferencias» y «Configuración» llamaban las dos a
  /// `onNavigate('/settings')` — la MISMA cadena, indistinguible en
  /// `router.dart`. Interceptar esa cadena para abrir el diálogo apagaba
  /// TAMBIÉN «Configuración» (medido el 13-sep-2026). Este parámetro es la
  /// separación real: dos disparadores, dos caminos.
  final VoidCallback? onOpenPreferences;

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
  Widget build(BuildContext buildContext) {
    // El bloqueo local (`locked`, una decisión del operador) manda sobre el
    // bloqueo por límite de sesión sin conexión: son mutuamente excluyentes
    // en la práctica y, si coincidieran alguna vez, seguir pidiendo la
    // contraseña del puesto es lo más seguro.
    final offlineBlockedMessage = widget.context.offlineBlockedMessage;
    final blocked = widget.locked || offlineBlockedMessage != null;
    return Stack(
      children: [
        // El marco sigue montado aunque esté bloqueado: un borrador a medio
        // escribir no puede perderse porque alguien pulsara «Bloquear». Sólo
        // se suprime su interactividad; nada de debajo se reconstruye ni se
        // tira. Los envoltorios de bloqueo se ponen SÓLO al bloquear.
        // Dejarlos siempre puestos, aunque no hicieran nada, mete un nodo de
        // semántica por encima de la navegación de Fluent y el marco lanza
        // una aserción propia al recorrer el árbol de accesibilidad en
        // anchos de teléfono.
        if (blocked)
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
          )
        else if (offlineBlockedMessage != null)
          Positioned.fill(
            child: _OfflineAllowanceOverlay(message: offlineBlockedMessage),
          ),
      ],
    );
  }

  Widget _scaffold(BuildContext buildContext) => LayoutBuilder(
    builder: (layoutContext, constraints) {
      final wideFooter =
          constraints.maxWidth >= 600 &&
          constraints.maxWidth >= constraints.maxHeight;
      // Base opaca de todo el armazón. Sin esto, cualquier tramo del marco
      // que ninguna capa interna pinte (medido en el botón compacto de
      // conexión: un `Align` sin fondo propio) deja ver el lienzo de Flutter
      // transparente y, debajo, la página HTML (`web/index.html`).
      return ColoredBox(
        color: FluentTheme.of(layoutContext).micaBackgroundColor,
        child: Column(
          children: [
            _topBar(layoutContext, constraints.maxWidth),
            // Persistente mientras dure el almacenamiento volátil — no es un
            // aviso transitorio (`showCopyableMessage`) porque el riesgo no
            // desaparece a los pocos segundos, sigue mientras la pestaña
            // siga abierta así. `InfoBar` es el mismo widget que ya usa el
            // resto de la app para avisos incrustados (por ejemplo
            // `home_dashboard_view.dart`), nunca una superficie propia.
            if (widget.context.storageIsVolatile)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: InfoBar(
                  key: const Key('shell-volatile-storage-warning'),
                  title: const Text(
                    'Este navegador no está guardando datos en el equipo',
                  ),
                  content: const Text(
                    'Lo que no se haya enviado a Odoo se perderá al cerrar '
                    'la pestaña.',
                  ),
                  severity: InfoBarSeverity.warning,
                ),
              ),
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
        ),
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
              // Textos sólo con sitio: por debajo del mismo corte que ya usa
              // `_UserAvatarMenu.wide` (`OrbiTheme.mediumBreakpoint`, 840),
              // Fluent oculta la etiqueta de cada botón y deja sólo el ícono
              // — el modo nativo de `CommandBarButton` para esto
              // (`showLabel` en `commandbar.dart`, sólo `true` en modo
              // `inPrimary`, nunca en `inPrimaryCompact`). Antes theos_pos
              // condicionaba cada `Text` a mano; aquí basta un booleano.
              isCompact: availableWidth < OrbiTheme.mediumBreakpoint,
              overflowBehavior: CommandBarOverflowBehavior.dynamicOverflow,
              overflowItemBuilder: (onPressed) => CommandBarButton(
                key: const Key('shell-topbar-overflow'),
                icon: const Icon(FluentIcons.more),
                tooltip: 'Más acciones',
                onPressed: onPressed,
              ),
              primaryItems: [
                // Comparando con `theos_pos` (`RouteModeIndicatorBadge`,
                // `main_screen.dart`): mientras el Modo Ruta está activo, la
                // sincronización remota está en pausa y conviene que se note
                // de un vistazo. Lleva a Sincronización, donde está el
                // interruptor.
                if (ctx.routeModeActive)
                  CommandBarButton(
                    key: const Key('shell-route-mode-button'),
                    icon: const Icon(FluentIcons.car),
                    label: const Text('Modo Ruta'),
                    tooltip:
                        'Modo Ruta activo. La sincronización remota está '
                        'suspendida.',
                    onPressed: () => widget.onNavigate(_kSyncPath),
                  ),
                // Comparando con `theos_pos` (el badge naranja de
                // «N pendientes», `main_screen.dart`): cuántas operaciones
                // esperan enviarse al servidor. Lleva a la cola offline.
                if (ctx.pendingOperationsCount > 0)
                  CommandBarButton(
                    key: const Key('shell-pending-ops-button'),
                    icon: const Icon(FluentIcons.cloud_upload),
                    label: Text(
                      ctx.pendingOperationsCount == 1
                          ? '1 pendiente'
                          : '${ctx.pendingOperationsCount} pendientes',
                    ),
                    tooltip:
                        '${ctx.pendingOperationsCount} '
                        '${ctx.pendingOperationsCount == 1 ? 'operación' : 'operaciones'} '
                        'pendientes de enviar al servidor',
                    onPressed: () => widget.onNavigate(_kQueuePath),
                  ),
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
                    // Contador rojo, mismo patrón que Avisos — antes
                    // Actividades no tenía forma de anunciar cuántas había
                    // sin entrar.
                    icon: _badgedIcon(
                      FluentIcons.clock,
                      ctx.activitiesPendingCount,
                    ),
                    label: const Text('Actividades'),
                    tooltip: 'Actividades pendientes',
                    onPressed: () => widget.onNavigate(_kActivitiesPath),
                  ),
                // Ambiente del servidor — nunca los dos a la vez, y ninguno
                // cuando el dueño no lo marcó (orden del dueño, 14-sep-2026).
                if (ctx.environment != null)
                  _InfoPillCommandBarItem(
                    key: const Key('shell-environment-pill'),
                    label: ctx.environment == ServerEnvironment.production
                        ? 'Producción'
                        : 'Pruebas',
                    color: (r) =>
                        ctx.environment == ServerEnvironment.production
                        ? r.systemFillColorCritical
                        : r.systemFillColorCaution,
                  ),
                if (ctx.cashSessionOpen)
                  _InfoPillCommandBarItem(
                    key: const Key('shell-cash-session-pill'),
                    label: 'Caja abierta',
                    color: (r) => r.systemFillColorSuccess,
                  ),
                if ((ctx.sriPending?.count ?? 0) > 0)
                  _InfoPillCommandBarItem(
                    key: const Key('shell-sri-pending-pill'),
                    label: ctx.sriPending!.isLastReading
                        ? '${ctx.sriPending!.count} pendientes SRI '
                              '(última lectura)'
                        : '${ctx.sriPending!.count} pendientes SRI',
                    color: (r) => r.systemFillColorCaution,
                  ),
                _ConnectivityCommandBarItem(
                  key: const Key('shell-connectivity-pill'),
                  context: ctx,
                ),
                if (ctx.realtimeStatus != null)
                  _RealtimeStatusCommandBarItem(
                    key: const Key('shell-realtime-pill'),
                    status: ctx.realtimeStatus!,
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
            onOpenPreferences:
                widget.onOpenPreferences ??
                () => widget.onNavigate(_kSettingsPath),
            onLock: widget.onLock,
            onSwitchUser: widget.onSwitchUser,
            onLogout: widget.onLogout,
            presence: widget.presence,
            onPresenceChanged: widget.onPresenceChanged,
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
  //
  // Íconos en vez de «Servidor:»/«BD:», como en el pie de `theos_pos`
  // (`server_info_bar.dart`): el contenido de la izquierda va en su propio
  // scroll horizontal, y el reloj queda FUERA de ese scroll, en un `Row`
  // exterior — un `Spacer` dentro de un `SingleChildScrollView` revienta
  // (ancho sin límite), así que empujar el reloj a la derecha exige que el
  // contenido desplazable y el reloj sean dos hijos distintos del mismo
  // `Row`, no todo dentro del scroll.
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: DefaultTextStyle(
            style: theme.typography.caption ?? const TextStyle(),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Semantics(
                      label: 'Información de conexión',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Sin dato no se muestra: nunca un «Odoo: sin
                          // dato» inventado mientras `fetchVersion()` no
                          // haya resuelto o el servidor no responda.
                          if (ctx.odooVersion != null &&
                              ctx.odooVersion!.isNotEmpty) ...[
                            _iconValue(
                              FluentIcons.server_enviroment,
                              'Odoo ${ctx.odooVersion}',
                              r,
                            ),
                            _footerGap(r),
                          ],
                          _iconValue(FluentIcons.globe, ctx.server, r),
                          _footerGap(r),
                          _iconValue(FluentIcons.database, ctx.database, r),
                          // Junto a servidor y base, como pidió el dueño
                          // (14-sep-2026). Vacío/`null` no se pinta: nunca un
                          // segmento de más cuando `DeviceNameStore` todavía
                          // no resolvió nada.
                          if (ctx.deviceName != null &&
                              ctx.deviceName!.isNotEmpty) ...[
                            _footerGap(r),
                            _iconValue(
                              FluentIcons.device_run,
                              ctx.deviceName!,
                              r,
                            ),
                          ],
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
                const SizedBox(width: 12),
                _FooterClock(
                  tickInterval: widget.clockTickInterval,
                  iconColor: r.textFillColorSecondary,
                  now: widget.now,
                  serverClock: widget.context.serverClock,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconValue(IconData icon, String value, ResourceDictionary r) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: r.textFillColorSecondary),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _footerGap(ResourceDictionary r) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: Text('·', style: TextStyle(color: r.textFillColorSecondary)),
  );

  Widget _statusDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

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

  Widget _compactContextButton(BuildContext buildContext) {
    // Mismo fondo que [_contextFooter]: en estrecho esta fila reemplaza al
    // pie, y sin este color se leía como un hueco vacío en vez de un pie.
    final r = FluentTheme.of(buildContext).resources;
    return ColoredBox(
      color: r.solidBackgroundFillColorTertiary,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Tooltip(
          message: 'Detalle de conexión',
          child: IconButton(
            key: const Key('operational-context-button'),
            icon: const Icon(FluentIcons.info),
            // En estrecho el pie no cabe, así que se pide. Un diálogo y no
            // una hoja inferior porque Fluent no trae hoja inferior y
            // fabricarse una sería justo el andamiaje propio que esta
            // migración vino a quitar.
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
      ),
    );
  }
}

/// El bloqueo por límite de sesión sin conexión (decisión del dueño,
/// 14-sep-2026) — ver [OperationalContext.offlineBlockedMessage]. A
/// diferencia de [WorkspaceLockScreen], no pide ninguna contraseña: se quita
/// sola en cuanto vuelve la conexión y la próxima sincronización confirma
/// que el plazo ya no está vencido. «Cerrar sesión» sigue disponible porque
/// es la única acción de [OperationalShell] que no depende de la red.
class _OfflineAllowanceOverlay extends StatelessWidget {
  const _OfflineAllowanceOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ColoredBox(
      color: theme.micaBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.plug_disconnected,
                  size: 40,
                  color: theme.resources.textFillColorPrimary,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  key: const Key('shell-offline-allowance-message'),
                  textAlign: TextAlign.center,
                  style: theme.typography.body,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

/// Misma mecánica que [_ConnectivityCommandBarItem] (subclasificar
/// `CommandBarItem` es el propio mecanismo de extensión de Fluent), pero
/// para el estado del socket de tiempo real — hueco 1 de la auditoría de
/// tiempo real del 14-sep-2026.
class _RealtimeStatusCommandBarItem extends CommandBarItem {
  const _RealtimeStatusCommandBarItem({super.key, required this.status});

  final RealtimeStatus status;

  @override
  Widget build(BuildContext buildContext, CommandBarItemDisplayMode mode) {
    final pill = _RealtimeStatusPill(key: key, status: status);
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

/// Cuatro lecturas, ni una más (texto fijado en [realtimeStatusLabel],
/// `orbi_runtime`): "conectado" (verde), "reconectando" (ámbar, cubre tanto
/// la primera conexión como un reintento tras caerse), "caído" (rojo, el
/// aparato no tiene red) y "no disponible en este servidor" (ámbar, NUNCA
/// rojo — orden del dueño, 14-sep-2026: un servidor sin el módulo de tiempo
/// real no es un error, la app sigue funcionando sólo con sincronización
/// periódica).
class _RealtimeStatusPill extends StatelessWidget {
  const _RealtimeStatusPill({super.key, required this.status});

  final RealtimeStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
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
            realtimeStatusLabel(status),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _color(ResourceDictionary r) => switch (status) {
    RealtimeStatus.live => r.systemFillColorSuccess,
    RealtimeStatus.connecting => r.systemFillColorCaution,
    RealtimeStatus.retrying => r.systemFillColorCaution,
    RealtimeStatus.offline => r.systemFillColorCritical,
    // Nunca rojo: no es un error, es un servidor sin el módulo.
    RealtimeStatus.disabled => r.systemFillColorCaution,
  };
}

/// Píldora de sólo lectura para la barra superior, reutilizada por ambiente,
/// caja abierta y pendientes del SRI — mismo mecanismo de extensión de
/// `CommandBarItem` que [_ConnectivityCommandBarItem] y
/// [_RealtimeStatusCommandBarItem], factorizado en un solo sitio para no
/// repetir tres veces más la conmutación primario/desbordamiento.
class _InfoPillCommandBarItem extends CommandBarItem {
  const _InfoPillCommandBarItem({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color Function(ResourceDictionary) color;

  @override
  Widget build(BuildContext buildContext, CommandBarItemDisplayMode mode) {
    final pill = _InfoPill(key: key, label: label, color: color);
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

/// El mismo dibujo que [_ConnectivityPill]/[_RealtimeStatusPill] (punto de
/// color + texto), pero con la etiqueta y el color como parámetros — nada
/// que decidir aquí, sólo pintar lo que ya decidió quien construye el
/// [OperationalContext].
class _InfoPill extends StatelessWidget {
  const _InfoPill({super.key, required this.label, required this.color});

  final String label;
  final Color Function(ResourceDictionary) color;

  @override
  Widget build(BuildContext buildContext) {
    final theme = FluentTheme.of(buildContext);
    final resolved = color(theme.resources);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolved),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: resolved, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: resolved, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// El avatar y su menú, en la barra superior.
///
/// Junta lo que antes estaba repartido: el rótulo de usuario que vivía suelto
/// en el pie del panel, y Bloquear/Cambiar de usuario/Cerrar sesión que eran
/// `PaneItemAction` del mismo pie (orden del dueño, 13-sep-2026, comparando
/// con `theos_pos`: ver `theos_pos/lib/shared/screens/main_screen.dart`,
/// `_UserAvatarMenu`). Sin foto de perfil todavía: `OperationalContext` no
/// trae ninguna, y no se inventa una aquí.
///
/// La presencia (En línea/Ausente/No molestar/Desconectado) sí se replica,
/// igual que en `theos_pos`: `mobile_set_im_status`
/// (`l10n_ec_collection_box_pos/models/res_users.py:253-283`) es un método
/// custom del proyecto, accesible por JSON-2 con Bearer — el camino web con
/// cookie de sesión no es el único, sólo el que trae el core de Odoo.
class _UserAvatarMenu extends StatefulWidget {
  const _UserAvatarMenu({
    required this.userLabel,
    required this.companyLabel,
    required this.wide,
    required this.onOpenPreferences,
    required this.onLogout,
    this.onLock,
    this.onSwitchUser,
    this.presence,
    this.onPresenceChanged,
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
  final OdooPresence? presence;
  final ValueChanged<OdooPresence>? onPresenceChanged;

  @override
  State<_UserAvatarMenu> createState() => _UserAvatarMenuState();
}

class _UserAvatarMenuState extends State<_UserAvatarMenu> {
  final _controller = FlyoutController();

  /// Copia local para el cambio optimista: al elegir un estado en el
  /// submenú, el punto del avatar cambia en el acto, sin esperar a que
  /// `router.dart` reciba la confirmación del servidor y reconstruya este
  /// widget con la presencia real. [didUpdateWidget] la resincroniza cuando
  /// [OperationalShell.presence] sí cambia por fuera (la respuesta llegó,
  /// u otra pestaña/dispositivo cambió el estado).
  OdooPresence? _optimisticPresence;

  @override
  void initState() {
    super.initState();
    _optimisticPresence = widget.presence;
  }

  @override
  void didUpdateWidget(_UserAvatarMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presence != widget.presence) {
      _optimisticPresence = widget.presence;
    }
  }

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
              // Orden de theos_pos (`UserProfileBar`,
              // `main_screen.dart:829-867`): la empresa arriba en negrita, el
              // nombre debajo — antes iba al revés.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.companyLabel,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    widget.userLabel,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
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
                // Sin punto cuando la presencia no se conoce todavía — nunca
                // uno adivinado (mismo criterio que `_badgedIcon`: nada de
                // adorno sin un dato real detrás).
                if (_optimisticPresence != null)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      key: const Key('shell-presence-dot'),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _presenceColor(context, _optimisticPresence!),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: FluentTheme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
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
          // Ausente si `onPresenceChanged` es nulo: un servidor sin
          // `mobile_set_im_status` (falta, por ejemplo, en Mepriga) no debe
          // ofrecer un control que nunca va a responder.
          if (widget.onPresenceChanged != null)
            MenuFlyoutSubItem(
              key: const Key('shell-presence-submenu'),
              text: const Text('Estado'),
              leading: Icon(
                FluentIcons.status_circle_outer,
                color: _optimisticPresence == null
                    ? FluentTheme.of(context).inactiveColor
                    : _presenceColor(context, _optimisticPresence!),
                size: 14,
              ),
              items: (context) => OdooPresence.values.map((status) {
                final isSelected = _optimisticPresence == status;
                return MenuFlyoutItem(
                  key: Key('shell-presence-option-${status.name}'),
                  leading: Icon(
                    FluentIcons.status_circle_outer,
                    color: _presenceColor(context, status),
                    size: 14,
                  ),
                  text: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(FluentIcons.check_mark, size: 12),
                        )
                      else
                        const SizedBox(width: 16),
                      Text(_presenceLabel(status)),
                    ],
                  ),
                  closeAfterClick: false,
                  onPressed: _closeThenRun(() {
                    // Cambio optimista: el punto del avatar responde ya,
                    // sin esperar la vuelta del servidor. El guardado y la
                    // cola son responsabilidad de quien nos instancie.
                    setState(() => _optimisticPresence = status);
                    widget.onPresenceChanged!(status);
                  }),
                );
              }).toList(),
            ),
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

/// El reloj del pie ancho: hora del SERVIDOR cuando `router.dart` compone un
/// [ServerClockStatus] (`OperationalContext.serverClock`), o la hora LOCAL
/// cruda del dispositivo cuando no hay ninguno —el comportamiento de este
/// archivo hasta el 14-sep-2026, cuando ni Orbi ni `theos_pos` medían un
/// desfase real (`theos_pos` fija `serverTimeOffset` en cero siempre,
/// `theos_pos/lib/shared/providers/server_info_provider.dart:161`).
/// [ServerClockStatus.nowServer] nunca hace RPC: es una lectura local del
/// desfase que ya sincronizó `ClientPolicyService` en otro momento (al
/// entrar, al volver a primer plano, o cada 15 minutos) — el tic de este
/// widget sólo la vuelve a leer, nunca la actualiza por su cuenta.
///
/// El latido es un parámetro, no una constante: en producción
/// [OperationalShell.clockTickInterval] vale 1 segundo por omisión, y las
/// pruebas de este marco lo apagan pasando `null`, porque un
/// `Timer.periodic` vivo nunca deja terminar a `tester.pumpAndSettle()`
/// (mismo defecto medido el 13-sep-2026 que ya evitaba este archivo antes de
/// que este widget existiera). Con `null` el reloj se queda fijo en la hora
/// en que se montó — no tiquetea, pero tampoco dejar de responder es un
/// requisito de una etiqueta que sólo se ve en el pie.
class _FooterClock extends StatefulWidget {
  const _FooterClock({
    required this.tickInterval,
    required this.iconColor,
    required this.now,
    required this.serverClock,
  });

  final Duration? tickInterval;
  final Color iconColor;
  final DateTime Function() now;
  final ServerClockStatus? serverClock;

  @override
  State<_FooterClock> createState() => _FooterClockState();
}

class _FooterClockState extends State<_FooterClock> {
  late DateTime _time;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _time = widget.now();
    _schedule();
  }

  @override
  void didUpdateWidget(_FooterClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tickInterval != widget.tickInterval) {
      _timer?.cancel();
      _schedule();
    }
  }

  void _schedule() {
    final interval = widget.tickInterval;
    if (interval == null) return;
    _timer = Timer.periodic(interval, (_) {
      if (mounted) setState(() => _time = widget.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = widget.serverClock;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(FluentIcons.date_time, size: 14, color: widget.iconColor),
        const SizedBox(width: 5),
        Text(clock == null ? _formatLocalClock(_time) : _formatServerClock(clock)),
        if (clock?.clockRollbackSuspected ?? false) ...[
          const SizedBox(width: 6),
          Icon(
            FluentIcons.warning,
            size: 14,
            color: FluentTheme.of(context).resources.systemFillColorCaution,
          ),
        ],
      ],
    );
    if (clock == null) return row;
    return Tooltip(message: _serverClockTooltip(clock, widget.now), child: row);
  }
}

String _formatLocalClock(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String _formatServerClock(ServerClockStatus clock) =>
    _formatLocalClock(clock.nowServer().add(clock.userTzOffset));

/// El texto del tooltip/detalle del reloj — las redacciones fijas que pidió
/// el dueño, nunca una interpolación libre sobre lo que diga el servidor.
String _serverClockTooltip(ServerClockStatus clock, DateTime Function() deviceNow) {
  final parts = <String>[];
  if (clock.source == ClientPolicyTimeSource.device && clock.lastOnlineAt == null) {
    parts.add('Hora del equipo: este servidor no informa su hora');
  } else if (clock.isEstimated) {
    final last = clock.lastOnlineAt;
    if (last == null) {
      parts.add('Hora estimada sin conexión');
    } else {
      final local = last.add(clock.userTzOffset);
      parts.add(
        'Hora estimada sin conexión · última conexión '
        '${_formatLocalClock(local)}',
      );
    }
  } else {
    parts.add('Hora del servidor');
    final lastSyncAt = clock.lastSyncAt;
    if (lastSyncAt != null) {
      final minutes = deviceNow().toUtc().difference(lastSyncAt).inMinutes;
      parts.add('sincronizada hace $minutes min');
    }
    final rtt = clock.rtt;
    if (rtt != null) parts.add('latencia ${rtt.inMilliseconds} ms');
  }
  // Revisión del dueño, 14-sep-2026: cuando el servidor no trae
  // `user_tz_offset_minutes` (módulo viejo, o "el modelo no existe"), la
  // hora que se ve usa la zona del EQUIPO, no una que Odoo haya confirmado
  // — el detalle lo dice para que nadie lo confunda con un dato del
  // servidor.
  if (clock.usesDeviceTzFallback) {
    parts.add('en la zona de este equipo');
  }
  if (clock.clockRollbackSuspected) {
    parts.add(
      'La hora de este equipo retrocedió; revisa la fecha y hora del sistema.',
    );
  }
  return parts.join(' · ');
}

/// Etiquetas del submenú «Estado» y del punto del avatar. Las mismas cuatro
/// de `theos_pos` (`theos_pos/lib/shared/models/im_status.dart:17,19,21,23`)
/// y de Odoo web — no un nombre propio de Orbi: es la palabra que el usuario
/// ya reconoce de ahí.
String _presenceLabel(OdooPresence presence) => switch (presence) {
  OdooPresence.online => 'En línea',
  OdooPresence.away => 'Ausente',
  OdooPresence.busy => 'No molestar',
  OdooPresence.offline => 'Desconectado',
};

/// Tokens de Fluent, nunca hex literales — a diferencia de `theos_pos`
/// (`shared/models/im_status.dart`), que fija `AppColors.success`
/// (`0xFF28A745`), `.warning` (`0xFFFFC800`) y `.danger` (`0xFFDC3545`) a
/// mano, más un gris (`0xFF6C757D`, alfa .75) para desconectado. Mapeo al
/// token más cercano: los tres primeros son exactamente los mismos
/// `resources` de significado que ya usa el pie
/// (`_OperationalShellState._statusColorForStatus`); `Colors.grey` es el
/// nombrado de `fluent_ui` para el cuarto — `ResourceDictionary` no trae un
/// tono semántico de "desconectado".
Color _presenceColor(BuildContext context, OdooPresence presence) {
  final r = FluentTheme.of(context).resources;
  return switch (presence) {
    OdooPresence.online => r.systemFillColorSuccess,
    OdooPresence.away => r.systemFillColorCaution,
    OdooPresence.busy => r.systemFillColorCritical,
    OdooPresence.offline => Colors.grey,
  };
}

const appShellHeaderHeight = 50.0;
