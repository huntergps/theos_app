import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile;

import 'auth_controller.dart';
import 'login_failure_messages.dart';
import 'login_preferences.dart';
import 'pin_login_screen.dart';
import 'saved_servers.dart';
import 'server_manager_dialog.dart';
import '../../app/theme/orbi_theme.dart';
import '../../app/preferences/app_preferences.dart';
import '../../ui/components/copyable_message.dart';
import '../../ui/components/orbi_brand.dart';

const String _kApiKeySubtitle =
    'La clave se guarda sólo en el almacén seguro del dispositivo.';
const String _kFooterText = 'Desarrollado por GalapagosTech · 2026';

/// El corte que decide panel de marca + formulario lado a lado, en vez de la
/// tarjeta apilada de siempre.
///
/// A propósito NO es `OrbiTheme.mediumBreakpoint` (840px): ese es el corte
/// para que un formulario interno pase a dos columnas
/// (`odoo_widgets/lib/src/listing/orbi_form.dart`), un criterio distinto de
/// partir la pantalla ENTERA en dos. Éste es el ancho "expandido" que
/// `NavigationView` de fluent_ui ya usa para su propio modo abierto (orden
/// del dueño, 13-sep-2026: «a partir del ancho expandido de Fluent»; ver
/// `fluent_ui-4.16.1/lib/src/controls/navigation/navigation_view/view.dart`,
/// «Width >= 1008px: Open mode»).
const double _kExpandedPaneBreakpoint = 1008.0;

/// Shown when the saved-servers store cannot be read at all.
///
/// The FormatException's own text used to be interpolated into this line.
/// That is an internal detail on a screen anyone can see, and the rule that
/// governs the sign-in failures governs this one too: explaining is not
/// dumping. What the person gets is what to DO; the copy button carries it to
/// whoever can fix it.
const CopyableMessage _kServersUnreadableMessage = CopyableMessage(
  title: 'No se pudieron leer los servidores guardados',
  body:
      'La lista de entornos de este dispositivo quedó ilegible. Abre '
      '«Gestionar servidores…» y vuelve a crear el entorno que uses; si te '
      'pasa otra vez, copia este mensaje y mándaselo a tu administrador.',
  severity: OrbiMessageSeverity.error,
);

// Sentinel item inside the server dropdown that opens the manager dialog
// instead of selecting an environment. It can never collide with a real
// SavedServer.id (those are timestamp-based, see server_manager_dialog.dart).
const String _kManageServersOptionValue = '__manage_servers__';
const String _kManageServersLabel = 'Gestionar servidores…';

const String _kSaveCredentialSubtitle =
    'Recuerda el acceso en este equipo, también después de cerrar sesión. '
    'Quien use este equipo podrá entrar con tu usuario.';

/// Presents a login failure the way a failed sign-in deserves: a bordered,
/// tinted block with an icon, a headline saying WHAT happened, a second line
/// saying WHAT TO DO — and a button that puts the whole thing on the
/// clipboard. Instead of the one red sentence the owner saw ("No se pudo
/// iniciar sesión. Revisa los datos e inténtalo de nuevo.").
///
/// It is a thin adapter over [CopyableMessagePanel]: the copy affordance, the
/// tones and the four-severity vocabulary are shared with every other
/// transient message in the app rather than reinvented per screen.
///
/// It carries NO duration. A sign-in failure is anchored to the form that
/// produced it and stays until the next attempt replaces it — nothing to
/// read against a countdown while you reach for the copy button. The
/// configurable durations apply to the floating messages, which are not
/// anchored to anything.
///
/// Why this and NOT a `flutter_local_notifications` system banner: see the
/// note on [_LoginScreenState._refineLastFailure].
class LoginFailurePanel extends StatelessWidget {
  const LoginFailurePanel({super.key, required this.failure});

  final LoginFailureMessage failure;

  /// The clipboard payload for [failure] — headline, guidance and the moment
  /// it happened. Exposed so a test can assert what actually gets pasted.
  static CopyableMessage messageFor(
    LoginFailureMessage failure, {
    DateTime? occurredAt,
  }) => CopyableMessage(
    title: failure.title,
    body: failure.guidance,
    severity: orbiSeverityFor(failure.severity),
    occurredAt: occurredAt,
  );

  @override
  Widget build(BuildContext context) =>
      CopyableMessagePanel(message: messageFor(failure));
}

double loginOverlayContrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + .05) / (darker + .05);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _BrandingPane extends StatelessWidget {
  const _BrandingPane();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(OrbiTheme.space32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const OrbiBrand(height: 220, color: orbiPhotoInk),
              const SizedBox(height: OrbiTheme.space24),
              Text(
                'Ventas, caja y operaciones',
                style: FluentTheme.of(context).typography.title
                    ?.copyWith(color: orbiPhotoInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OrbiTheme.space8),
              Text(
                'Trabaja con tu equipo desde un solo lugar.',
                style: FluentTheme.of(context).typography.bodyLarge
                    ?.copyWith(color: orbiPhotoInk),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _loginFocus = FocusNode();
  final _passwordFocus = FocusNode();
  // Identidad estable del bloque de campos/interruptores a través de las dos
  // arquitecturas que _buildLoginForm alterna según el teclado (ver ahí). Sin
  // esta GlobalKey, alternar envoltorios reconstruiría el subárbol entero —
  // Usuario y Contraseña incluidos — cada vez que abre o cierra el teclado:
  // EditableText perdería el `_lastBottomViewInset` con el que detecta la
  // apertura del teclado y JAMÁS se traería solo a la vista (el mecanismo
  // que hace que "el campo con foco se lleva a la vista solo" deje de
  // funcionar). Con la key, Flutter REPARENTA el mismo Element/State al
  // cambiar de envoltorio en vez de destruirlo y crear uno nuevo.
  final _fieldsColumnKey = GlobalKey();
  // Misma razón que _fieldsColumnKey, pero para la cabecera: sin esta key,
  // alternar de arquitectura al abrir/cerrar el teclado destruiría y
  // recrearía el AnimatedSize de la cabecera, perdiendo su animación en
  // curso — el logo/título saltarían de tamaño de golpe en vez de subir en
  // transición (orden del dueño, 12-sep-2026).
  final _headerKey = GlobalKey();
  int _profileLookupEpoch = 0;
  // Aparte de `_profileLookupEpoch` (que sólo guarda contra el precargado del
  // nombre de usuario): «Recordar la llave tras salir» hace su propia
  // consulta asíncrona por servidor+base+login, y necesita su propio guardián
  // para no aplicar una respuesta tardía tras haber cambiado de servidor o
  // de usuario mientras tanto.
  int _credentialLookupEpoch = 0;
  // Sólo dispara la BÚSQUEDA de una llave guardada mientras se teclea — ya
  // NO guarda preferencias (bug B, auditoría de router+login, 14-sep-2026):
  // guardar a cada tecla dejaba grabado un usuario a medio escribir
  // («soleda.jinez») si el operador pulsaba «Iniciar sesión» antes de que el
  // siguiente carácter llegara a disparar este temporizador. Buscar SÍ puede
  // seguir siendo de lectura continua: nunca escribe nada.
  Timer? _credentialLookupDebounce;
  bool _apiKeyMode = false;
  bool _saveCredential = false;
  bool _passwordVisible = false;

  /// El perfil de (servidor, base, usuario) elegidos AHORA MISMO, sólo si su
  /// llave sigue en el almacén — decisión del dueño, 13-sep-2026: «Recordar
  /// la llave tras salir» (`W04-el-navegador-tambien-guarda.md`). `null` en
  /// cualquier otra combinación, incluida una plataforma que no ofrezca el
  /// concepto en absoluto.
  AuthProfile? _rememberedCredential;

  /// ACC-02's door, opened from here. Toggled purely by local widget state —
  /// deliberately NOT a GoRoute: `/login` is the one pre-authentication path
  /// RouteAccessPolicy and its own reachability tests know about
  /// (route_access_policy_area_test.dart), and PIN only ever makes sense as a
  /// sibling of this very form, never as an address someone could type or
  /// bookmark on its own. See pin_login_screen.dart's class doc: it never
  /// imports app/router, so this screen owns the way back exactly like it
  /// owns the way in.
  bool _pinMode = false;

  // The database travels with the saved server, not with anything the user
  // types: it is resolved the moment an environment is selected, and never
  // rendered anywhere in this form. See saved_servers.dart and
  // docs/orbi_panel/COORDINATOR_HANDOFF_2026_09_11.md.
  List<SavedServer> _servers = const [];
  SavedServer? _selectedServer;
  bool _serversUnreadable = false;

  /// A connection failure refined with what `connectivity_plus` actually
  /// observed — see [_refineLastFailure]. Kept next to [_refinedFrom], the
  /// controller message it was derived from, so a NEW failure can never be
  /// shown wearing the previous one's explanation.
  LoginFailureMessage? _refinedFailure;
  String? _refinedFrom;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _loginFocus.dispose();
    _passwordFocus.dispose();
    _credentialLookupDebounce?.cancel();
    super.dispose();
  }

  /// Sólo BUSCA si ya hay una llave guardada para lo que se lleva tecleado —
  /// nunca guarda nada (ver el comentario de `_credentialLookupDebounce`).
  /// Guardar la preferencia de usuario/servidor pasó a ser una acción
  /// explícita: al elegir servidor, al autocompletar un login recordado, y
  /// al pulsar «Iniciar sesión» (`_saveLoginPreferences` desde `_selectServer`,
  /// `_lookupRememberedProfile` y `_submit`).
  void _scheduleCredentialLookup() {
    _credentialLookupDebounce?.cancel();
    _credentialLookupDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_lookupStoredCredential());
    });
  }

  /// Busca si (servidor, base, usuario elegidos AHORA) tiene una llave
  /// guardada — «Recordar la llave tras salir», decisión del dueño,
  /// 13-sep-2026. Sólo LEE, nunca escribe preferencias: por eso puede seguir
  /// corriendo en cada tecla (vía `_scheduleCredentialLookup`, cada 400 ms de
  /// inactividad al teclear) sin arriesgarse a grabar un usuario a medias.
  Future<void> _lookupStoredCredential() async {
    final server = _selectedServer;
    final login = _login.text.trim();
    if (server == null || login.isEmpty) {
      if (_rememberedCredential != null) {
        setState(() => _rememberedCredential = null);
      }
      return;
    }
    final epoch = ++_credentialLookupEpoch;
    AuthProfile? remembered;
    try {
      remembered = await ref
          .read(authControllerProvider.notifier)
          .findRememberedCredential(server.url, server.database, login);
    } catch (_) {
      remembered = null;
    }
    if (!mounted ||
        epoch != _credentialLookupEpoch ||
        _selectedServer?.id != server.id ||
        _login.text.trim() != login) {
      return;
    }
    setState(() {
      final wasRemembered = _rememberedCredential != null;
      _rememberedCredential = remembered;
      // Hallazgo visual (14-sep-2026): tras cerrar sesión con «Guardar
      // clave» puesta, esta pantalla mostraba «Clave guardada en este
      // equipo.» con el interruptor «Guardar clave» APAGADO — sugería
      // falsamente que había que volver a activarlo para que la próxima
      // salida la recordara. En cuanto se detecta una credencial recordada
      // para el servidor/base/usuario elegidos, el interruptor se enciende
      // solo. Sólo en la transición "no había" → "hay": si la persona lo
      // apaga a mano después (sin cambiar de usuario), un login posterior
      // con contraseña la des-recuerda (`NativeAuthService.login`,
      // `persistCredential: false`) y no se vuelve a encender solo mientras
      // el debounce de teclear siga viendo la misma credencial recordada.
      if (remembered != null && !wasRemembered) {
        _saveCredential = true;
      }
    });
  }

  /// «Olvidar la clave guardada»: revoca en el servidor si hay red y borra
  /// siempre la copia local. Tras esto, la pantalla vuelve a pedir la
  /// contraseña para este usuario, como si nunca se hubiera guardado nada.
  Future<void> _forgetStoredCredential() async {
    final remembered = _rememberedCredential;
    if (remembered == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .forgetStoredCredential(remembered);
    if (!mounted) return;
    setState(() => _rememberedCredential = null);
  }

  /// Reads the saved-servers store into [_servers]/[_selectedServer]. Pure
  /// field assignment, no `setState`: safe to call directly from `initState`
  /// (before the first build) and wrap in `setState(_readServers)` anywhere
  /// else. Corrupt local data is reported, never silently discarded — see
  /// [_serversUnreadable]. A store that isn't wired up at all (embedders and
  /// most widget tests never override `sharedPreferencesProvider`) is treated
  /// as "no servers yet", the same convention already used below for
  /// [LoginPreferencesStore].
  void _readServers() {
    try {
      final servers = ref.read(savedServersStoreProvider).load();
      _servers = servers;
      _serversUnreadable = false;
      if (_selectedServer != null) {
        _selectedServer = servers.cast<SavedServer?>().firstWhere(
          (server) => server!.id == _selectedServer!.id,
          orElse: () => null,
        );
      }
    } on FormatException {
      _servers = const [];
      _selectedServer = null;
      _serversUnreadable = true;
    } catch (_) {
      // Tests and embedders may intentionally omit the saved-servers store.
      _servers = const [];
      _selectedServer = null;
      _serversUnreadable = false;
    }
  }

  SavedServer? _findServer(String url, String database) {
    if (url.isEmpty || database.isEmpty) return null;
    String normalizedUrl;
    try {
      normalizedUrl = SavedServersStore.normalizeUrl(url);
    } catch (_) {
      normalizedUrl = url;
    }
    for (final server in _servers) {
      if (server.url == normalizedUrl && server.database == database) {
        return server;
      }
    }
    return null;
  }

  void _selectServer(SavedServer server) {
    if (_selectedServer?.id == server.id) return;
    // Invalidate an older server lookup before applying the new selection.
    // No password/API key may cross to another server or database.
    ++_profileLookupEpoch;
    ++_credentialLookupEpoch;
    _credentialLookupDebounce?.cancel();
    setState(() {
      _selectedServer = server;
      _login.clear();
      _password.clear();
      _rememberedCredential = null;
    });
    _lookupRememberedProfile();
    // Elegir servidor es una acción explícita del operador, no algo tecleado
    // a medias: se guarda de inmediato, sin esperar el debounce de escritura.
    unawaited(_saveLoginPreferences());
    _scheduleCredentialLookup();
    _loginFocus.requestFocus();
  }

  void _handleServerSelectionChanged(String? value) {
    if (value == null) return;
    if (value == _kManageServersOptionValue) {
      unawaited(_openServerManager());
      return;
    }
    for (final server in _servers) {
      if (server.id == value) {
        _selectServer(server);
        return;
      }
    }
  }

  Future<void> _openServerManager() async {
    try {
      final selected = await showSavedServerManager(
        context,
        store: ref.read(savedServersStoreProvider),
        initialUrl: _selectedServer?.url ?? '',
        initialDatabase: _selectedServer?.database ?? '',
      );
      if (!mounted) return;
      setState(_readServers);
      if (selected != null) _selectServer(selected);
    } catch (_) {
      if (!mounted) return;
      final preferences = ref.read(
        appPreferencesProvider(ref.read(preferencesScopeProvider)),
      );
      showCopyableMessage(
        context,
        const CopyableMessage(
          title: 'No se pudo abrir la gestión de servidores',
          body: 'Vuelve a intentarlo en unos segundos.',
          severity: OrbiMessageSeverity.warning,
        ),
        durations: preferences.snapshot.messageDurations,
      );
    }
  }

  Future<void> _saveLoginPreferences({LoginPreferencesStore? store}) async {
    final server = _selectedServer;
    final value = LoginPreferences(
      serverUrl: server?.url ?? '',
      database: server?.database ?? '',
      login: _login.text.trim(),
    );
    if (value.isEmpty) return;
    try {
      final LoginPreferencesStore preferences =
          store ?? ref.read(loginPreferencesStoreProvider);
      await preferences.save(value);
    } catch (_) {
      // Login preferences are an optional convenience and never block login.
    }
  }

  void _lookupRememberedProfile() {
    final server = _selectedServer;
    if (server == null) return;
    final epoch = ++_profileLookupEpoch;
    final loginBeforeLookup = _login.text;
    unawaited(() async {
      AuthProfile? profile;
      try {
        profile = await ref
            .read(authControllerProvider.notifier)
            .loadProfileFor(server.url, server.database);
      } catch (_) {
        return;
      }
      if (!mounted ||
          epoch != _profileLookupEpoch ||
          _selectedServer?.id != server.id ||
          _login.text != loginBeforeLookup) {
        return;
      }
      if (profile != null) {
        _login.text = profile.login;
        // Un login restaurado COMPLETO, no algo a medio teclear: se guarda
        // de inmediato, igual que la elección de servidor que lo disparó.
        unawaited(_saveLoginPreferences());
        unawaited(_lookupStoredCredential());
      }
    }());
  }

  @override
  void initState() {
    super.initState();
    _readServers();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      LoginPreferences? remembered;
      try {
        remembered = ref.read(loginPreferencesStoreProvider).load();
      } catch (_) {
        // Tests and embedders may intentionally omit local preferences.
      }
      if (!mounted) return;
      if (remembered != null && !remembered.isEmpty) {
        final match = _findServer(remembered.serverUrl, remembered.database);
        if (match != null) {
          setState(() {
            _selectedServer = match;
            _login.text = remembered!.login;
          });
        }
      }
      final profile = await ref
          .read(authControllerProvider.notifier)
          .loadProfile();
      if (!mounted || profile == null) return;
      if (_selectedServer == null) {
        final match = _findServer(profile.serverUrl, profile.database);
        if (match != null) {
          setState(() {
            _selectedServer = match;
            if (_login.text.trim().isEmpty) _login.text = profile.login;
          });
        }
      } else if (_selectedServer!.url == profile.serverUrl &&
          _selectedServer!.database == profile.database &&
          _login.text.trim().isEmpty) {
        setState(() => _login.text = profile.login);
      }
      // El servidor y el usuario ya quedaron precargados arriba (si los
      // había); ahora sí se puede saber si además hay una llave guardada
      // para mostrar «Clave guardada en este equipo» desde el primer frame,
      // sin esperar a que el operador toque algo.
      unawaited(_lookupStoredCredential());
    });
  }

  /// Returns to the credentials form. Shared by ACC-02's three ways out
  /// (granted, cancelled, "use credentials instead") so none of them can
  /// diverge from the others.
  void _leavePinMode() {
    if (!mounted) return;
    setState(() => _pinMode = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_pinMode) {
      // PinLoginScreen owns its own Scaffold/background — it is a sibling
      // screen, not a section nested inside this one's Card. Once it grants
      // access, authControllerProvider becomes authenticated/restored and
      // orbi_app.dart's own `ref.watch(orbiRouterProvider)` swaps in the
      // authenticated router on its own, the same way a normal credentials
      // login already does without an explicit navigation call here.
      return PinLoginScreen(
        onSellerAccessGranted: _leavePinMode,
        onCancel: _leavePinMode,
        onUseCredentials: _leavePinMode,
      );
    }
    final state = ref.watch(authControllerProvider);
    final theme = FluentTheme.of(context);
    // Decide the two-column-vs-stacked branch below from the STABLE
    // window/screen size, never from the body's LayoutBuilder constraints.
    // Those constraints shrink whenever Scaffold.resizeToAvoidBottomInset
    // reacts to MediaQuery.viewInsets, and on a fixed-size desktop/web window
    // there is no software keyboard to explain a change there — yet focusing
    // a field was reported to reflow the whole form (subtitles and the
    // "manage servers" row jumping). Using MediaQuery.sizeOf makes that
    // decision immune to whatever nudges the inset, by construction,
    // regardless of the exact platform cause. Real keyboard avoidance (when
    // it legitimately applies, e.g. on a phone) still works: the scrollable
    // middle section reacts to the live body constraints in
    // _buildLoginForm, independently of this decision.
    final screenSize = MediaQuery.sizeOf(context);
    // An iPad in portrait can exceed 840px: it still uses the approved
    // stacked composition, not the horizontal two-column arrangement.
    final isWideLandscape =
        screenSize.width >= _kExpandedPaneBreakpoint &&
        screenSize.width > screenSize.height;
    // No hand-picked height budget decides a "compact" styling anymore
    // (orden del dueño, 12-sep-2026: «el estilo lo determina fluent_ui»).
    // The form always renders at its one spacious styling — OrbiForm/
    // OrbiField, the project's standard form — and the middle section
    // (fields, toggles, messages) scrolls internally via a LayoutBuilder-
    // driven SingleChildScrollView whenever the real, measured content does
    // not fit; the header and the submit button never move.
    final form = _buildLoginForm(context, state);
    // 🔴 REVOCADO 12-sep-2026 (orden del dueño: «fluent_ui no tiene pie
    // translúcido, todo está ya determinado por fluent_ui», «fluent_ui tiene
    // sus widgets, los cuales se heredan para tener widgets reactivos»). The
    // footer used to be a Stack layer overlapping the photo so the photo
    // would continue behind it (docs/orbi_panel/COORDINATOR_HANDOFF_2026_09_11.md,
    // commit b45483e). That requirement is revoked: the footer now goes in
    // ScaffoldPage's own `bottomBar` slot, its own row BELOW the content —
    // no Acrylic, no text over the photo, no hand-rolled translucency. Style
    // is the plain caption/secondary-text combo already used everywhere
    // else off the photo.
    //
    // ScaffoldPage lays its `bottomBar` out inside a plain Column whose
    // default crossAxisAlignment is `center` — so a bar that does not force
    // its own width shrinks to its content (here, the caption text) and
    // ends up centered as a narrow island instead of spanning the screen
    // (orden del dueño, 12-sep-2026: «el pie no está en todo el formulario,
    // se ve mal»). The SizedBox below is what actually fixes that; the
    // SafeArea/Padding/Text inside it never would have on their own.
    // With the software keyboard open there is no room left for the credit
    // line, and phones don't have one to spare (orden del dueño, 12-sep-2026:
    // el pie sigue ocupando una franja encima del teclado). This only decides
    // WHETHER the footer paints — it changes no height math, so the field
    // that has focus is never rebuilt by this branch (the pending-focus test
    // above stays green).
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final footer = SizedBox(
      key: const Key('login-credit-footer'),
      width: double.infinity,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(OrbiTheme.space12),
          child: Text(
            _kFooterText,
            textAlign: TextAlign.center,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ),
      ),
    );
    return ScaffoldPage(
      // ScaffoldPage's own default padding is 24px top, painted with
      // scaffoldBackgroundColor UNDER the content — with a photo backdrop
      // that shows as a solid strip above it. The photo must start at the
      // very top of the screen instead.
      padding: EdgeInsets.zero,
      bottomBar: keyboardOpen ? null : footer,
      content: isWideLandscape
          ? Stack(
              fit: StackFit.expand,
              children: [
                const OrbiAuthBackdrop(),
                // bottom: false — bottomBar now sits in its own row BELOW
                // this content area and already reserves the device's
                // bottom inset via its own SafeArea (see `footer` above).
                // Reserving it again here would shrink the card for no
                // reason: this content area no longer touches that inset.
                SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        children: [
                          const Expanded(child: _BrandingPane()),
                          SizedBox(
                            width: 440,
                            child: Padding(
                              padding: const EdgeInsets.all(OrbiTheme.space16),
                              // Card, not Acrylic: the same opaque surface
                              // ContentDialog itself paints with
                              // (theme.menuColor) — see
                              // orbi-fluent-ui-ya-decide-el-estilo. Acrylic is
                              // translucent by design, which is exactly what
                              // made the card unreadable over the photo.
                              child: Card(
                                backgroundColor: theme.menuColor,
                                padding: const EdgeInsets.all(
                                  OrbiTheme.space24,
                                ),
                                child: form,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                const OrbiAuthBackdrop(key: Key('compact-login-background')),
                // See the wide-landscape branch's own comment: bottom:false
                // because bottomBar already reserves the device's bottom
                // inset in its own row, below this content area.
                SafeArea(
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(OrbiTheme.space16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Card(
                          backgroundColor: theme.menuColor,
                          padding: const EdgeInsets.all(OrbiTheme.space24),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// El contenido del campo "Servidor" — sin su etiqueta: la pone
  /// [OrbiField] desde donde se usa (ver `_buildLoginForm`), como cualquier
  /// otro campo del formulario estándar.
  Widget _buildServerSelectorField({required bool busy}) {
    final hasServers = _servers.isNotEmpty;
    // ComboBox is a CONTROLLED widget (driven by `value`, unlike
    // DropdownButtonFormField's FormField-only `initialValue`), so the
    // ValueKey-per-selection trick the Material version needed to force a
    // fresh seed no longer applies: a rename or a new selection is picked up
    // on the very next build regardless.
    final items = <ComboBoxItem<String>>[
      for (final server in _servers)
        ComboBoxItem(
          value: server.id,
          child: Text(server.name, overflow: TextOverflow.ellipsis),
        ),
      const ComboBoxItem(
        key: Key('manage-servers-option'),
        value: _kManageServersOptionValue,
        child: Text(_kManageServersLabel),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ComboBox<String>(
          value: _selectedServer?.id,
          items: items,
          onChanged: busy ? null : _handleServerSelectionChanged,
          // Without this, the field's internal Row sizes itself to the
          // intrinsic width of the selected item/hint text and overflows
          // against the dropdown arrow the moment a server name (or the
          // "Gestionar servidores…" hint) is long enough for a narrow card.
          isExpanded: true,
          placeholder: Text(
            hasServers ? 'Selecciona un servidor' : 'Ningún servidor guardado',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_serversUnreadable) ...[
          const SizedBox(height: OrbiTheme.space8),
          const CopyableMessagePanel(
            key: Key('servers-load-error-panel'),
            message: _kServersUnreadableMessage,
          ),
        ],
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context, AuthViewState state) {
    final theme = FluentTheme.of(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Duración/curva del tema de Fluent, no números inventados — y cero
    // cuando el sistema pide menos movimiento (orden del dueño, 12-sep-2026:
    // usar la duración y curva del tema; `disableAnimationsOf` en cero).
    final animationDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : theme.fastAnimationDuration;
    final animationCurve = theme.animationCurve;
    final themeToggle = Tooltip(
      message: theme.brightness == Brightness.dark
          ? 'Cambiar a modo claro'
          : 'Cambiar a modo oscuro',
      child: IconButton(
        key: const Key('login-theme-toggle'),
        icon: Icon(
          theme.brightness == Brightness.dark
              ? FluentIcons.sunny
              : FluentIcons.clear_night,
        ),
        onPressed: () async {
          final dark = theme.brightness != Brightness.dark;
          final preferences = ref.read(
            appPreferencesProvider(ref.read(preferencesScopeProvider)),
          );
          try {
            await preferences.setTheme(
              dark ? PreferenceThemeMode.dark : PreferenceThemeMode.light,
            );
          } catch (_) {
            if (!context.mounted) return;
            showCopyableMessage(
              context,
              const CopyableMessage(
                title: 'No se pudo guardar el tema',
                body:
                    'El cambio se ve ahora, pero no quedará guardado para la '
                    'próxima vez que abras Orbi. Vuelve a intentarlo.',
                severity: OrbiMessageSeverity.warning,
              ),
              durations: preferences.snapshot.messageDurations,
            );
          }
        },
      ),
    );
    // ACC-02's way in. Placed in the SAME row as the theme toggle, not as a
    // row of its own, to keep the header compact.
    final pinModeButton = Tooltip(
      message: 'Modo vendedor (PIN)',
      child: IconButton(
        key: const Key('login-pin-mode-button'),
        icon: const Icon(FluentIcons.pin),
        onPressed: () => setState(() => _pinMode = true),
      ),
    );
    // Con el teclado abierto la cabecera se encoge en vez de quedarse fija a
    // su tamaño de siempre (orden del dueño, 12-sep-2026: «¿No se debería
    // reducir el tamaño de la cabecera y subirla en transición hasta que se
    // vean los TextEdit?»): el logo baja de 84 a 32px, el subtítulo se
    // oculta y el título pasa a `typography.subtitle`. El AnimatedSize
    // exterior interpola el alto TOTAL resultante (logo+título+subtítulo)
    // entre un build y el siguiente; adentro cada pieza cambia de golpe a su
    // valor final, pero como el contenedor todavía se está expandiendo o
    // encogiendo, el efecto visible es el logo/título subiendo o bajando
    // junto con el resto de la tarjeta — no un salto.
    //
    // 🔴 Esto NO desmonta el subárbol de los campos: header es un widget
    // aparte, nunca envuelve a fieldsColumn (ver _fieldsColumnKey), así que
    // animar la cabecera no puede robarle el foco a Usuario/Contraseña.
    final headerChild = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Use the app preference rather than a login-only Theme override.
        // This preserves one source of truth and the existing scope
        // boundary. Choosing an environment used to need a second,
        // separate header row ("Gestionar servidores"). That control now
        // lives inside the server selector itself (see
        // _buildServerSelectorField), so this row only ever holds the
        // theme toggle.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [pinModeButton, themeToggle],
        ),
        SizedBox(height: keyboardOpen ? OrbiTheme.space8 : OrbiTheme.space12),
        // 🔴 NO envolver esto en su propio AnimatedSize: un AnimatedSize
        // anidado DENTRO de otro (el exterior) se reinicia a mitad del
        // layout del padre y Flutter lo rechaza con «A RenderAnimatedSize
        // was mutated in its own performLayout implementation» — se
        // reprodujo justo con `disableAnimations` (duración cero fuerza
        // los dos layouts al mismo frame). El AnimatedSize EXTERIOR ya
        // interpola el alto total; el logo cambia de tamaño de golpe pero
        // el efecto visible sigue siendo el logo "entrando/saliendo" del
        // recorte mientras el contenedor crece o encoge.
        OrbiBrand(height: keyboardOpen ? 32.0 : 84.0, color: theme.accentColor),
        SizedBox(height: keyboardOpen ? OrbiTheme.space8 : OrbiTheme.space16),
        AnimatedDefaultTextStyle(
          duration: animationDuration,
          curve: animationCurve,
          textAlign: TextAlign.center,
          style:
              (keyboardOpen
                  ? theme.typography.subtitle
                  : theme.typography.title) ??
              const TextStyle(),
          child: const Text('Acceso a Orbi'),
        ),
        // Mismo motivo que el logo: sin AnimatedSize propio, el colapso lo
        // hace el exterior.
        if (!keyboardOpen)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: OrbiTheme.space8),
              Text(
                'Conéctate a tu entorno de trabajo',
                style: theme.typography.body?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        SizedBox(height: keyboardOpen ? OrbiTheme.space12 : OrbiTheme.space24),
      ],
    );
    // 🔴 Con duración cero, NO usar AnimatedSize: `RenderAnimatedSize`
    // reinicia su animación DENTRO de su propio `performLayout`, y con
    // duración cero `AnimationController.forward()` se completa de forma
    // SÍNCRONA en el mismo layout pass — Flutter lo rechaza con «A
    // RenderAnimatedSize was mutated in its own performLayout
    // implementation». Se reprodujo justo cuando el teclado abre y
    // `header` se reparenta (ver `_headerKey`) EN EL MISMO frame en que
    // también cambia de tamaño. Sin nada que animar (duración cero), un
    // `KeyedSubtree` cambia de tamaño igual de instantáneo, sin el
    // controlador de animación de por medio.
    final header = animationDuration == Duration.zero
        ? KeyedSubtree(key: _headerKey, child: headerChild)
        : AnimatedSize(
            key: _headerKey,
            duration: animationDuration,
            curve: animationCurve,
            alignment: Alignment.topCenter,
            child: headerChild,
          );
    // Servidor, Usuario y Contraseña/API key son el formulario estándar del
    // proyecto (orden del dueño, 12-sep-2026: «los formularios también de
    // manera similar») — la misma pareja OrbiForm/OrbiField que ya usa
    // server_manager_dialog.dart, no un layout hecho a mano campo por campo.
    // Los dos ToggleSwitch quedan fuera de la sección porque OrbiField exige
    // una etiqueta encima de cada campo y ninguno de los dos la necesita (su
    // propio `content` ya nombra la opción); van justo debajo, con el mismo
    // ritmo vertical que separa a los campos entre sí (ver los SizedBox de
    // abajo y OrbiTheme.space16, que iguala el runSpacing interno de
    // OrbiForm).
    final fieldsAndToggles = <Widget>[
      OrbiForm(
        sections: [
          OrbiFormSection(
            // Sin título de sección: el acceso a Orbi es una sola sección y
            // "Acceso a Orbi" ya está en el título de la pantalla — repetir
            // el nombre de la sección no aportaba nada (orden del dueño,
            // 12-sep-2026).
            fields: [
              OrbiField(
                label: 'Servidor',
                child: _buildServerSelectorField(busy: state.isBusy),
              ),
              OrbiField(
                label: 'Usuario',
                child: TextBox(
                  controller: _login,
                  focusNode: _loginFocus,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  prefix: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: OrbiTheme.space8),
                    child: Icon(FluentIcons.contact, size: 16),
                  ),
                  onChanged: (_) => _scheduleCredentialLookup(),
                  autofillHints: const [AutofillHints.username],
                ),
              ),
              OrbiField(
                label: _apiKeyMode ? 'API key' : 'Contraseña',
                // «Recordar la llave tras salir» (decisión del dueño,
                // 13-sep-2026): con una llave guardada para este
                // servidor+base+usuario, el propio `hint` de OrbiField —la
                // ranura que el formulario estándar ya trae para esto,
                // ninguna nueva— dice que no hace falta escribir nada.
                hint: _rememberedCredential != null
                    ? 'Clave guardada en este equipo.'
                    : null,
                // TextBox+obscureText rather than PasswordBox: PasswordBox
                // has no `autofillHints` (comprobado en
                // fluent_ui-4.16.1/lib/src/controls/form/password_box.dart),
                // and keeping the platform's password manager (el del
                // iPhone del dueño) working matters more here than
                // PasswordBox's own reveal-button affordance — la
                // reponemos a mano abajo, con `suffix`, sin perder
                // autofillHints.
                child: TextBox(
                  controller: _password,
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  obscureText: !_passwordVisible,
                  prefix: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: OrbiTheme.space8),
                    child: Icon(FluentIcons.lock, size: 16),
                  ),
                  suffix: Tooltip(
                    message: _passwordVisible
                        ? 'Ocultar clave'
                        : 'Mostrar clave',
                    child: IconButton(
                      key: const Key('login-password-reveal'),
                      icon: Icon(
                        _passwordVisible
                            ? FluentIcons.hide3
                            : FluentIcons.red_eye,
                        size: 16,
                      ),
                      onPressed: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                  autofillHints: const [AutofillHints.password],
                ),
              ),
            ],
          ),
        ],
      ),
      if (_rememberedCredential != null)
        Align(
          alignment: Alignment.centerRight,
          child: HyperlinkButton(
            key: const Key('forget-stored-credential-button'),
            onPressed: state.isBusy ? null : _forgetStoredCredential,
            child: const Text('Olvidar la clave guardada'),
          ),
        ),
      Column(
        key: const Key('api-key-toggle-block'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ToggleSwitch(
            key: const Key('api-key-mode-toggle'),
            checked: _apiKeyMode,
            onChanged: (value) => setState(() => _apiKeyMode = value),
            content: const Text('Usar API key'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: OrbiTheme.space4),
            child: Text(
              _kApiKeySubtitle,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: OrbiTheme.space16),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ToggleSwitch(
            key: const Key('save-credential-toggle'),
            checked: _saveCredential,
            onChanged: (value) => setState(() => _saveCredential = value),
            content: const Text('Guardar clave'),
          ),
          Padding(
            padding: const EdgeInsets.only(top: OrbiTheme.space4),
            child: Text(
              _kSaveCredentialSubtitle,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
        ],
      ),
      if (state.message != null) ...[
        const SizedBox(height: OrbiTheme.space12),
        // A message the mapping recognises is drawn as a real panel; anything
        // else (the handful of sentences the controller still writes by hand)
        // keeps the plain treatment rather than being dressed up as a
        // classified cause it is not.
        if (_failureFor(state.message) case final LoginFailureMessage failure)
          LoginFailurePanel(
            key: const Key('login-failure-panel'),
            failure: failure,
          )
        else
          Semantics(
            liveRegion: true,
            container: true,
            label: state.message,
            child: Text(
              state.message!,
              style: TextStyle(color: theme.resources.systemFillColorCritical),
            ),
          ),
      ],
    ];
    final submitButton = FilledButton(
      onPressed: (state.isBusy || _selectedServer == null) ? null : _submit,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          state.isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Icon(FluentIcons.signin, size: 16),
          const SizedBox(width: 8),
          Text(state.isBusy ? 'Conectando…' : 'Iniciar sesión'),
        ],
      ),
    );
    // El mismo widget (misma GlobalKey) en las dos arquitecturas de abajo:
    // sin ella, Flutter destruiría y recrearía TextBox/EditableText —
    // perdiendo el estado con el que EditableText detecta que abrió el
    // teclado — cada vez que _buildLoginForm cambia de envoltorio (ver el
    // comentario de _fieldsColumnKey).
    final fieldsColumn = Column(
      key: _fieldsColumnKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: fieldsAndToggles,
    );
    // Con el teclado del sistema abierto, ScaffoldPage le resta al contenido
    // el alto del teclado. La arquitectura de abajo (encabezado y botón
    // FIJOS, sólo el bloque de campos en un Flexible+SingleChildScrollView)
    // entonces le quita casi todo el alto al Flexible de en medio —
    // "Usuario" y "Contraseña" quedaban aplastados a unos pocos píxeles
    // (reporte del dueño, iPhone, 12-sep-2026). Con el teclado abierto la
    // tarjeta ENTERA (encabezado, campos, interruptores, mensajes y botón)
    // pasa a ser un solo Column dentro de un único SingleChildScrollView,
    // sin nada fijo — así el campo con foco se trae solo a la vista
    // (EditableText hace su propio scrollIntoView dentro de un Scrollable
    // ancestro) y el botón se alcanza desplazando.
    //
    // Sin teclado (el caso de escritorio, y el de un teléfono antes de tocar
    // un campo) se mantiene la arquitectura de siempre: header y botón
    // pinneados, sólo el medio se ajusta. Un solo Column-scroll también ahí
    // rompería el contrato ya probado de "el botón siempre visible sin
    // desplazar" en ventanas de escritorio bajas (800x600, 900x670,
    // 1280x600): sin la merma REAL de un teclado, esas ventanas no tienen
    // margen para que la tarjeta entera quepa sin desplazar, y antes de
    // ahora nunca hacía falta — es exactamente lo que
    // "en pantallas anchas horizontales... se ve igual que hoy" pide
    // conservar.
    if (keyboardOpen) {
      return AutofillGroup(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              fieldsColumn,
              const SizedBox(height: OrbiTheme.space24),
              submitButton,
            ],
          ),
        ),
      );
    }
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: fieldsColumn,
            ),
          ),
          const SizedBox(height: OrbiTheme.space24),
          submitButton,
        ],
      ),
    );
  }

  /// What the form should actually show for [message].
  ///
  /// Prefers the connectivity-refined verdict when it was derived from this
  /// very message; otherwise decodes the controller's message as it stands.
  LoginFailureMessage? _failureFor(String? message) {
    if (message == null) return null;
    if (_refinedFailure != null && _refinedFrom == message) {
      return _refinedFailure;
    }
    return decodeLoginFailureMessage(message);
  }

  /// Turns "no se pudo conectar" — which blames nobody and helps nobody —
  /// into the measured answer.
  ///
  /// Our code has always treated any failed connection as "you are offline"
  /// without ever checking. `connectivity_plus` (already a declared
  /// dependency of `orbi_runtime`, reached here through its
  /// `ConnectivityMonitor` adapter so this package needs no new dependency)
  /// answers the one question that separates the two: does this DEVICE have a
  /// transport right now? With a transport, the server is the one not
  /// answering; without one, the person needs to fix their wifi and nothing
  /// else will help. When the probe cannot be consulted at all we keep the
  /// ambiguous message — a guess here would send someone to reboot a router
  /// that was never the problem.
  ///
  /// 🔴 And the part that is deliberately NOT done here: no system
  /// notification is raised. `SystemNotificationPresenter` and
  /// `RuntimeNotificationInbox` are both bound to an ACTIVE session scope
  /// (they refuse work, by design, when `sessions.active` is null or the
  /// scope key does not match), and during a failed sign-in there is no
  /// session at all — the durable inbox literally cannot hold this event.
  /// Even if it could, an OS banner for a mistyped password would be noise:
  /// the person is looking straight at the form. The error belongs IN the
  /// form, stated seriously — which is what [LoginFailurePanel] does.
  Future<void> _refineLastFailure(String? message) async {
    final decoded = decodeLoginFailureMessage(message);
    if (decoded == null ||
        decoded.cause != LoginFailureCause.serverUnreachable) {
      if (_refinedFailure != null && mounted) {
        setState(() {
          _refinedFailure = null;
          _refinedFrom = null;
        });
      }
      return;
    }
    bool? hasNetwork;
    try {
      hasNetwork = await ref.read(networkPresenceProbeProvider)();
    } catch (_) {
      // The probe itself misbehaved. Stay honest: the ambiguous message
      // stands. (The probe is inert by default and answers null on its own
      // when it cannot look — see networkPresenceProbeProvider.)
      hasNetwork = null;
    }
    if (!mounted) return;
    setState(() {
      _refinedFailure = refineConnectionFailure(decoded, hasNetwork);
      _refinedFrom = message;
    });
  }

  Future<void> _submit() async {
    final selected = _selectedServer;
    if (selected == null) return;
    final auth = ref.read(authControllerProvider.notifier);
    LoginPreferencesStore? loginPreferences;
    try {
      loginPreferences = ref.read(loginPreferencesStoreProvider);
    } catch (_) {
      // Embedders/tests may intentionally omit the convenience store.
    }
    final apiKeyMode = _apiKeyMode;
    final persistCredential = _saveCredential;
    final serverUrl = selected.url;
    final database = selected.database;
    final login = _login.text.trim();
    final secret = _password.text;
    // Bug B (auditoría de router+login, 14-sep-2026): el usuario que se
    // recuerda tiene que ser EXACTAMENTE el que se manda a entrar, tecleado
    // hasta este instante — nunca uno a medias que el debounce de teclear
    // dejó pendiente. Se cancela ese debounce y se guarda ANTES del intento,
    // así el guardado no depende de que esta pantalla siga viva después: con
    // el router ya arreglado (bug A) sigue viva, pero este guardado no debe
    // volver a depender de ese hecho.
    _credentialLookupDebounce?.cancel();
    if (loginPreferences != null) {
      await _saveLoginPreferences(store: loginPreferences);
      if (!mounted) return;
    }
    // «Recordar la llave tras salir» (decisión del dueño, 13-sep-2026): con
    // el campo Contraseña vacío y una llave guardada para este servidor,
    // base y usuario, entra con ELLA — nunca hace falta escribir nada. En
    // cuanto el operador teclea algo, manda lo que escribió (decisión
    // explícita del dueño: «si el usuario escribe una contraseña, manda la
    // contraseña»), sin importar que hubiera una llave guardada.
    final remembered = _rememberedCredential;
    final usingStoredCredential = secret.isEmpty && remembered != null;
    if (usingStoredCredential) {
      await auth.loginWithStoredCredential(remembered);
    } else if (apiKeyMode) {
      await auth.loginWithApiKey(
        serverUrl: serverUrl,
        database: database,
        login: login,
        apiKey: secret,
        persistCredential: persistCredential,
      );
    } else {
      await auth.login(
        serverUrl: serverUrl,
        database: database,
        login: login,
        password: secret,
        persistCredential: persistCredential,
      );
    }
    if (!mounted) return;
    final status = auth.currentState.status;
    final succeeded =
        status == AuthControllerStatus.authenticated ||
        status == AuthControllerStatus.restored;
    if (!succeeded) {
      await _refineLastFailure(auth.currentState.message);
      if (!mounted) return;
      if (usingStoredCredential) {
        // La llave pudo haber vencido y ya se borró sola
        // (`loginWithStoredCredential`) — se refresca para que el aviso y
        // el enlace «Olvidar» desaparezcan si ya no queda nada que ofrecer.
        unawaited(_lookupStoredCredential());
      }
    }
    // El usuario/servidor ya quedó guardado ANTES del intento, arriba —
    // tanto si entró como si no (ver el comentario de ahí): nada que
    // guardar aquí de nuevo.
    _password.clear();
    TextInput.finishAutofillContext(shouldSave: succeeded);
  }
}
