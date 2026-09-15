import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile;

import '../../app/preferences/app_preferences.dart';
import '../../app/theme/orbi_theme.dart';
import '../../ui/components/orbi_brand.dart';
import 'auth_controller.dart';
import 'legacy_pin_retention_migration.dart';
import 'pin_credential_store.dart';

/// El tamaño de tecla en modo compacto. Fluent no trae una constante
/// equivalente a `kMinInteractiveDimension` de Material — 48px sigue siendo
/// un objetivo táctil razonable, así que se fija aquí como valor propio.
const double _kCompactKeySize = 48.0;

const String _kFooterText = 'Desarrollado por GalapagosTech · 2026';
const String _kTitle = 'Modo vendedor';
const String _kSubtitle = 'Ingresa tu PIN para continuar';
const String _kSalesOnlyTitle = 'Solo ventas';
const String _kSalesOnlyBody =
    'Acceso para realizar ventas en el punto de venta.';
const String _kActivityNotice =
    'Por seguridad, tu actividad quedará registrada.';
const String _kInvalidPinMessage = 'PIN inválido. Intenta nuevamente.';
const String _kLockedTitle = 'Acceso bloqueado';
const String _kLockedBody =
    'Se ha alcanzado el número máximo de intentos. Intenta nuevamente en:';
const String _kNoProfileMessage =
    'Ingresa primero con tu usuario y contraseña para activar el acceso '
    'por PIN.';
const String _kNotEnrolledMessage =
    'Aún no configuraste un PIN de vendedor en este dispositivo. Ingresa '
    'con tu usuario y contraseña para activarlo.';
const String _kDeniedRoleMessage =
    'Este usuario no tiene permiso de vendedor: el acceso por PIN no está '
    'disponible.';

enum _PinPhase { bootstrapping, blocked, entering, verifying, locked }

double _measureTextHeight(
  String text,
  TextStyle? style,
  double maxWidth,
  TextDirection direction,
  double textScaleFactor,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: TextScaler.linear(textScaleFactor),
  )..layout(maxWidth: maxWidth > 0 ? maxWidth : 0);
  return painter.height;
}

String _formatCountdown(Duration remaining) {
  final clamped = remaining.isNegative ? Duration.zero : remaining;
  final hours = clamped.inHours.remainder(24).toString().padLeft(2, '0');
  final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// ACC-02 — the seller's PIN door. Restricted by construction: the only way
/// this screen can reach an authenticated state is
/// [AuthNotifier.restoreForSellerPin], which clamps capabilities to
/// seller-only before this widget ever sees them — see
/// pin_capability_limiter.dart and docs/orbi_panel/APPROVED_SCREEN_INDEX.md.
class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({
    super.key,
    this.equipmentLabel,
    this.onSellerAccessGranted,
    this.onCancel,
    this.onUseCredentials,
  });

  /// Device/point label such as "Mostrador 02" in ACC-02. Left `null` hides
  /// the "Equipo" line rather than inventing a point/session Orbi does not
  /// have a binding for yet (see NAVIGATION_CAPABILITY_MATRIX.md).
  final String? equipmentLabel;

  /// Fired once [AuthNotifier.restoreForSellerPin] leaves
  /// `authControllerProvider` authenticated/restored with seller-only
  /// capabilities already applied.
  final VoidCallback? onSellerAccessGranted;

  /// Fired from the locked state's "Entendido" acknowledgement and from the
  /// "not enrolled"/"no profile" states' way out. Routing itself is owned by
  /// the caller — this screen never imports app/router.
  final VoidCallback? onCancel;

  /// Offered as the way out of the "not enrolled" state. Optional: a caller
  /// that has not wired Workspace credentials yet may omit it.
  final VoidCallback? onUseCredentials;

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  _PinPhase _phase = _PinPhase.bootstrapping;
  String _pin = '';
  String? _scopeKey;
  String? _blockedMessage;
  String? _errorMessage;
  Duration _remaining = Duration.zero;
  Timer? _countdownTimer;
  Timer? _invalidPinResetTimer;

  /// Los usuarios de esta base con PIN enrolado y retenido, para el
  /// selector «elegir entre los usuarios con PIN de este equipo para esa
  /// base» (decisión del dueño, 14-sep-2026). Un solo elemento cuando sólo
  /// hay un usuario — el selector no se muestra ([_buildUserSelector]) pero
  /// [_selectedProfile] sigue siendo ese único perfil.
  List<AuthProfile> _candidates = const [];
  AuthProfile? _selectedProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _invalidPinResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final notifier = ref.read(authControllerProvider.notifier);
    final profile = await notifier.loadProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() {
        _phase = _PinPhase.blocked;
        _blockedMessage = _kNoProfileMessage;
      });
      return;
    }
    PinCredentialStore? store;
    try {
      store = ref.read(pinCredentialStoreProvider);
    } catch (_) {
      // Embedders/tests may intentionally omit the PIN store.
    }
    if (store == null) {
      setState(() {
        _scopeKey = pinScopeKeyFor(
          profile.serverUrl,
          profile.database,
          profile.login,
        );
        _phase = _PinPhase.blocked;
        _blockedMessage = _kNotEnrolledMessage;
      });
      return;
    }
    // Migración de una sola vez (decisión del dueño, 14-sep-2026): quien
    // enroló su PIN ANTES de que existiera la retención no tiene la bandera
    // y, sin esto, nunca aparecería en el selector de abajo aunque su PIN
    // siga enrolado y su llave siga en el almacén — ver
    // legacy_pin_retention_migration.dart. `sharedPreferencesProvider`
    // siempre está sobreescrito en producción y en las pruebas de esta
    // pantalla (igual que lo lee `pinCredentialStoreProvider`).
    await migrateLegacyPinRetention(
      preferences: ref.read(sharedPreferencesProvider),
      notifier: notifier,
      pinCredentialStore: store,
      serverUrl: profile.serverUrl,
      database: profile.database,
    );
    // Selector «elegir entre los usuarios con PIN de este equipo para esa
    // base» (decisión del dueño, 14-sep-2026): candidatos = perfiles de
    // ESTA base (servidor+base del último perfil) cuya llave está retenida
    // para el PIN Y que además tienen un PIN de 4 dígitos enrolado en este
    // equipo — la retención por sí sola no basta, un usuario puede haber
    // retenido la llave sin haber configurado nunca un PIN.
    var candidates = await notifier.pinRetainedProfilesFor(
      profile.serverUrl,
      profile.database,
    );
    final resolvedStore = store;
    candidates = candidates
        .where(
          (p) => resolvedStore.isEnrolled(
            pinScopeKeyFor(p.serverUrl, p.database, p.login),
          ),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      // Compatibilidad: un PIN enrolado ANTES de que existiera la
      // retención (o un servicio embebido que no implementa el selector,
      // como el de las pruebas de esta pantalla) no aparece en
      // `pinRetainedProfilesFor`. Sigue ofreciendo el ÚLTIMO perfil, como
      // hacía esta pantalla antes del selector, si su propio PIN está
      // enrolado.
      final legacyScopeKey = pinScopeKeyFor(
        profile.serverUrl,
        profile.database,
        profile.login,
      );
      if (resolvedStore.isEnrolled(legacyScopeKey)) {
        candidates = [profile];
      }
    }
    if (candidates.isEmpty) {
      setState(() {
        _scopeKey = pinScopeKeyFor(
          profile.serverUrl,
          profile.database,
          profile.login,
        );
        _phase = _PinPhase.blocked;
        _blockedMessage = _kNotEnrolledMessage;
      });
      return;
    }
    final preselected = candidates.length == 1
        ? candidates.first
        : candidates.firstWhere(
            (p) => p.login == profile.login,
            orElse: () => candidates.first,
          );
    final scopeKey = pinScopeKeyFor(
      preselected.serverUrl,
      preselected.database,
      preselected.login,
    );
    final attempts = resolvedStore.readAttempts(scopeKey);
    final now = DateTime.now();
    setState(() {
      _candidates = candidates;
      _selectedProfile = preselected;
      _scopeKey = scopeKey;
      if (attempts.isLockedAt(now)) {
        _startLockout(attempts.lockedUntil!);
      } else {
        _phase = _PinPhase.entering;
      }
    });
  }

  /// Cambia a quién se le está verificando el PIN, desde el selector —
  /// nunca mientras se está verificando o bloqueado. El PIN tecleado hasta
  /// ahora y cualquier error se descartan: son de la persona anterior.
  void _onSelectCandidate(String? login) {
    if (login == null || _phase != _PinPhase.entering) return;
    final profile = _candidates.firstWhere(
      (p) => p.login == login,
      orElse: () => _selectedProfile!,
    );
    if (profile.login == _selectedProfile?.login) return;
    final scopeKey = pinScopeKeyFor(
      profile.serverUrl,
      profile.database,
      profile.login,
    );
    PinCredentialStore? store;
    try {
      store = ref.read(pinCredentialStoreProvider);
    } catch (_) {
      // Embedders/tests may intentionally omit the PIN store.
    }
    setState(() {
      _selectedProfile = profile;
      _scopeKey = scopeKey;
      _pin = '';
      _errorMessage = null;
    });
    final attempts = store?.readAttempts(scopeKey);
    if (attempts != null && attempts.isLockedAt(DateTime.now())) {
      setState(() => _startLockout(attempts.lockedUntil!));
    }
  }

  void _startLockout(DateTime until) {
    _countdownTimer?.cancel();
    _phase = _PinPhase.locked;
    _remaining = until.difference(DateTime.now());
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = until.difference(DateTime.now());
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (left <= Duration.zero) {
        timer.cancel();
        setState(() {
          _phase = _PinPhase.entering;
          _pin = '';
          _remaining = Duration.zero;
        });
        return;
      }
      setState(() => _remaining = left);
    });
  }

  void _onDigit(String digit) {
    if (_phase != _PinPhase.entering || _pin.length >= kSellerPinLength) {
      return;
    }
    setState(() {
      _errorMessage = null;
      _pin += digit;
    });
    if (_pin.length == kSellerPinLength) unawaited(_submit());
  }

  void _onBackspace() {
    if (_phase != _PinPhase.entering || _pin.isEmpty) return;
    // Si venía de un PIN inválido, borrar es "ya estoy reintentando": se
    // cancela el temporizador de limpieza de _submit para que no le borre
    // el dígito que la persona ACABA de dejar, 700ms después, por su cuenta.
    _invalidPinResetTimer?.cancel();
    setState(() {
      _errorMessage = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submit() async {
    final scopeKey = _scopeKey;
    if (scopeKey == null || _phase != _PinPhase.entering) return;
    if (_pin.length != kSellerPinLength) return;
    PinCredentialStore? store;
    try {
      store = ref.read(pinCredentialStoreProvider);
    } catch (_) {
      // No store: nothing to verify against.
    }
    if (store == null) return;
    setState(() => _phase = _PinPhase.verifying);
    final ok = store.verify(scopeKey, _pin);
    if (!ok) {
      final next = await store.registerFailure(scopeKey);
      if (!mounted) return;
      final now = DateTime.now();
      if (next.isLockedAt(now)) {
        setState(() {
          _pin = '';
          _startLockout(next.lockedUntil!);
        });
        return;
      }
      // El resultado "inválido" ya se sabe: apaga el progreso YA (no hay
      // razón para que el botón siga con la rueda de carga ni para que la
      // tecla de borrar se vea desactivada mientras el mensaje rojo ya está
      // en pantalla). El PIN de 4 dígitos se conserva un instante para que
      // se vean los puntos en rojo, como en la lámina ACC-02, y el propio
      // temporizador de abajo lo limpia — sin tocar la lógica de intentos
      // ni de bloqueo, que ya corrió arriba (`registerFailure`).
      setState(() {
        _errorMessage = _kInvalidPinMessage;
        _phase = _PinPhase.entering;
      });
      _invalidPinResetTimer?.cancel();
      _invalidPinResetTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _pin = '';
          _errorMessage = null;
        });
      });
      return;
    }
    await store.clearAttempts(scopeKey);
    final selected = _selectedProfile;
    if (selected == null) return;
    await ref
        .read(authControllerProvider.notifier)
        .loginWithSellerPin(selected);
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    final succeeded =
        state.status == AuthControllerStatus.authenticated ||
        state.status == AuthControllerStatus.restored;
    if (succeeded) {
      widget.onSellerAccessGranted?.call();
      // The real navigation away from this screen is the caller's job (see
      // the class doc: this widget never imports app/router). If it is
      // still mounted after the callback returns — a caller that hasn't
      // navigated yet, or a test — it must not stay stuck showing the
      // "verifying" spinner forever, so it settles back to a normal,
      // re-enterable keypad rather than an indefinitely animating one.
      if (mounted) {
        setState(() {
          _phase = _PinPhase.entering;
          _pin = '';
        });
      }
      return;
    }
    setState(() {
      _phase = _PinPhase.entering;
      _pin = '';
      _errorMessage = state.status == AuthControllerStatus.error
          ? (state.message ?? _kDeniedRoleMessage)
          : _kDeniedRoleMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final typography = theme.typography;
    final direction = Directionality.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final devicePadding = MediaQuery.paddingOf(context);
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(14) / 14;
    final footerTextHeight = _measureTextHeight(
      _kFooterText,
      typography.caption,
      math.max(screenSize.width - OrbiTheme.space12 * 2, 0),
      direction,
      textScaleFactor,
    );
    final footerHeight =
        footerTextHeight + OrbiTheme.space12 * 2 + devicePadding.bottom;
    final isWideLandscape =
        screenSize.width >= OrbiTheme.mediumBreakpoint &&
        screenSize.width > screenSize.height;
    // Lámina ACC-02: sólo en teléfono «Entrar» sale de la rejilla y pasa a
    // ocupar todo el ancho debajo — desktop, tablet horizontal Y tablet
    // vertical lo mantienen dentro de la rejilla junto al 0.
    final phoneWidth = screenSize.width < OrbiTheme.compactBreakpoint;
    final cardWidth = isWideLandscape ? 720.0 : math.min(screenSize.width - OrbiTheme.space16 * 2, 480.0);
    final contentWidth = cardWidth - OrbiTheme.space24 * 2;
    final keypadWidth = isWideLandscape ? contentWidth * 0.55 : contentWidth;
    final normalHeight = _estimateNormalModeHeight(
      keypadWidth: keypadWidth,
      infoWidth: isWideLandscape ? contentWidth * 0.4 : contentWidth,
      stackedInfo: !isWideLandscape,
      phoneWidth: phoneWidth,
      theme: theme,
      direction: direction,
      textScaleFactor: textScaleFactor,
      equipmentLabel: widget.equipmentLabel,
      message: _currentMessage,
    );
    final availableForNormalMode =
        screenSize.height -
        footerHeight -
        devicePadding.top -
        OrbiTheme.space16 * 2 -
        OrbiTheme.space24 * 2;
    final compact = normalHeight > availableForNormalMode;
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
    final footer = SafeArea(
      key: const Key('pin-login-credit-footer'),
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(OrbiTheme.space12),
        child: Text(
          _kFooterText,
          textAlign: TextAlign.center,
          style: typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
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
      bottomBar: footer,
      content: Stack(
        fit: StackFit.expand,
        children: [
          const OrbiAuthBackdrop(),
          // 🔴 Ya NO bottom:false (revocado 15-sep-2026): el pie de abajo
          // reserva el inset del dispositivo DENTRO de su propia franja
          // (ver `footer`), pero eso sólo hace la franja gris más alta — no
          // deja aire visible entre la tarjeta y el pie. En un teléfono con
          // indicador de inicio, el margen de arriba (que SÍ reservaba su
          // inset aquí) quedaba más grande que el de abajo, y la tarjeta
          // parecía tocar el pie. Reservando el inset de abajo también
          // aquí, `Center` reparte el mismo aire a los dos lados — el costo
          // es que la tarjeta puede achicarse unos pocos px de más en un
          // dispositivo con esa franja, que es lo correcto.
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(OrbiTheme.space16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardWidth),
                  // Card, not Acrylic: the same opaque surface ContentDialog
                  // itself paints with (theme.menuColor) — see
                  // orbi-fluent-ui-ya-decide-el-estilo. Acrylic is
                  // translucent by design, which is exactly what made the
                  // card unreadable over the photo.
                  child: Card(
                    backgroundColor: theme.menuColor,
                    padding: EdgeInsets.all(
                      compact ? OrbiTheme.space12 : OrbiTheme.space24,
                    ),
                    child: _buildBody(
                      context,
                      isWideLandscape: isWideLandscape,
                      compact: compact,
                      phoneWidth: phoneWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? get _currentMessage => switch (_phase) {
    _PinPhase.blocked => _blockedMessage,
    _PinPhase.locked => _kLockedBody,
    _ => _errorMessage,
  };

  Widget _buildBody(
    BuildContext context, {
    required bool isWideLandscape,
    required bool compact,
    required bool phoneWidth,
  }) {
    if (_phase == _PinPhase.bootstrapping) {
      return const SizedBox(
        height: 200,
        child: Center(child: ProgressRing()),
      );
    }
    if (_phase == _PinPhase.blocked) {
      return _buildBlocked(context);
    }
    if (_phase == _PinPhase.locked) {
      return _buildLocked(context, compact: compact);
    }
    final header = _buildHeader(context, compact: compact);
    final keypad = _buildKeypad(context, compact: compact, phoneWidth: phoneWidth);
    final info = _buildInfoPanel(context);
    final infoGap = compact ? OrbiTheme.space12 : OrbiTheme.space24;
    // Mirrors login_screen.dart's own safety net: [compact] only tunes
    // padding/spacing for the comfortable case. It is a styling heuristic,
    // not the thing that prevents an overflow — that guarantee comes from
    // keeping the header pinned and letting everything below it (the keypad
    // and, when stacked, the info panel) scroll on a window too short for
    // even the compact styling to fit without it.
    final middle = isWideLandscape
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 55, child: keypad),
              const SizedBox(width: OrbiTheme.space24),
              Expanded(
                flex: 40,
                child: Padding(
                  padding: const EdgeInsets.only(top: OrbiTheme.space8),
                  child: info,
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [keypad, SizedBox(height: infoGap), info],
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        // Antes no había NADA aquí: los puntos del PIN (fin del header)
        // quedaban pegados a la primera fila del teclado. La lámina ACC-02
        // deja aire claro entre ambos — el mismo que ya separa el subtítulo
        // de los puntos, así el ritmo vertical es consistente.
        SizedBox(height: compact ? OrbiTheme.space12 : OrbiTheme.space24),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(child: middle),
        ),
      ],
    );
  }

  Widget _buildBlocked(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(FluentIcons.shop, size: 64, color: theme.accentColor),
        const SizedBox(height: OrbiTheme.space16),
        Text(
          _kTitle,
          style: theme.typography.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: OrbiTheme.space8),
        Text(
          _blockedMessage ?? _kNoProfileMessage,
          style: theme.typography.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: OrbiTheme.space24),
        FilledButton(
          key: const Key('pin-use-credentials'),
          onPressed: widget.onUseCredentials ?? widget.onCancel,
          child: const Text('Ingresar con usuario y contraseña'),
        ),
      ],
    );
  }

  Widget _buildLocked(BuildContext context, {required bool compact}) {
    final theme = FluentTheme.of(context);
    final critical = theme.resources.systemFillColorCritical;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(FluentIcons.lock, size: 64, color: critical),
        const SizedBox(height: OrbiTheme.space16),
        Text(
          _kLockedTitle,
          style: theme.typography.title?.copyWith(color: critical),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: OrbiTheme.space8),
        Text(
          _kLockedBody,
          style: theme.typography.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: OrbiTheme.space16),
        Semantics(
          liveRegion: true,
          label: 'Tiempo restante ${_formatCountdown(_remaining)}',
          child: Text(
            _formatCountdown(_remaining),
            key: const Key('pin-lockout-countdown'),
            style: theme.typography.subtitle?.copyWith(
              color: critical,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: OrbiTheme.space24),
        OutlinedButton(
          key: const Key('pin-locked-acknowledge'),
          onPressed: widget.onCancel,
          child: const Text('Entendido'),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, {required bool compact}) {
    final theme = FluentTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          FluentIcons.shop,
          size: compact ? 48 : 64,
          color: theme.accentColor,
        ),
        SizedBox(height: compact ? OrbiTheme.space8 : OrbiTheme.space16),
        Text(
          _kTitle,
          style: theme.typography.title,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: OrbiTheme.space8),
        Text(
          _kSubtitle,
          style: theme.typography.body?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        if (_candidates.length > 1) ...[
          SizedBox(height: compact ? OrbiTheme.space8 : OrbiTheme.space16),
          _buildUserSelector(context),
        ],
        SizedBox(height: compact ? OrbiTheme.space12 : OrbiTheme.space24),
        _buildDots(context),
        if (_errorMessage != null) ...[
          const SizedBox(height: OrbiTheme.space8),
          Semantics(
            liveRegion: true,
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: theme.resources.systemFillColorCritical,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  /// «Elegir entre los usuarios con PIN de este equipo para esa base»
  /// (decisión del dueño, 14-sep-2026). Sólo se llama cuando hay más de un
  /// candidato — con uno solo, [_selectedProfile] ya viene preseleccionado
  /// y este selector no aporta nada. `ComboBox` en vez de un widget propio:
  /// fluent_ui ya decide el estilo (orden del dueño, 12-sep-2026).
  Widget _buildUserSelector(BuildContext context) {
    final selected = _selectedProfile;
    return ComboBox<String>(
      key: const Key('pin-user-selector'),
      value: selected?.login,
      isExpanded: true,
      onChanged: _phase == _PinPhase.entering ? _onSelectCandidate : null,
      items: [
        for (final candidate in _candidates)
          ComboBoxItem<String>(
            key: Key('pin-user-option-${candidate.login}'),
            value: candidate.login,
            child: Text(
              (candidate.name != null && candidate.name!.trim().isNotEmpty)
                  ? '${candidate.name} (${candidate.login})'
                  : candidate.login,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildDots(BuildContext context) {
    final theme = FluentTheme.of(context);
    final invalid = _errorMessage != null;
    final critical = theme.resources.systemFillColorCritical;
    return Row(
      key: const Key('pin-dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kSellerPinLength; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length
                    ? (invalid ? critical : theme.accentColor)
                    : Colors.transparent,
                border: Border.all(
                  color: invalid
                      ? critical
                      : theme.resources.controlStrongStrokeColorDefault,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildKeypad(
    BuildContext context, {
    required bool compact,
    required bool phoneWidth,
  }) {
    final size = compact ? _kCompactKeySize : 64.0;
    final gap = compact ? OrbiTheme.space8 : OrbiTheme.space12;
    // En teléfono la lámina ACC-02 saca «Entrar» de la rejilla y lo pone a
    // todo el ancho debajo; la celda que le tocaría junto al 0 queda vacía
    // (no se recentra el par backspace/0) para que sigan alineados con las
    // columnas 1 y 2 de las filas de arriba.
    final rows = phoneWidth
        ? const <List<String?>>[
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['back', '0', null],
          ]
        : const <List<String?>>[
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['back', '0', 'enter'],
          ];
    final busy = _phase == _PinPhase.verifying;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final key in row) ...[
                _buildKey(context, key, size: size, busy: busy),
                if (key != row.last) SizedBox(width: gap),
              ],
            ],
          ),
          if (row != rows.last || phoneWidth) SizedBox(height: gap),
        ],
        if (phoneWidth)
          SizedBox(
            width: double.infinity,
            height: size,
            child: FilledButton(
              key: const Key('pin-key-enter'),
              onPressed: (busy || _pin.length != kSellerPinLength)
                  ? null
                  : () => unawaited(_submit()),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
          ),
      ],
    );
  }

  Widget _buildKey(
    BuildContext context,
    String? key, {
    required double size,
    required bool busy,
  }) {
    // Celda vacía: sólo en teléfono, donde «Entrar» ya no comparte fila con
    // el 0 (ver _buildKeypad). Mantiene la alineación de columnas.
    if (key == null) {
      return SizedBox(width: size, height: size);
    }
    final theme = FluentTheme.of(context);
    if (key == 'back') {
      return SizedBox(
        width: size,
        height: size,
        child: Tooltip(
          message: 'Borrar',
          // Button estándar de Fluent (borde y fondo del tema), no
          // IconButton — misma familia de widget que las teclas numéricas
          // (orden del dueño: rejilla pareja con la lámina ACC-02).
          child: Button(
            key: const Key('pin-key-backspace'),
            onPressed: busy ? null : _onBackspace,
            // FluentIcons no trae un glifo de retroceso de teclado (⌫)
            // literal — se revisó la clase entera. erase_tool («borrar») es
            // el que más se le acerca dentro del set y ya se usaba aquí.
            child: const Icon(FluentIcons.erase_tool),
          ),
        ),
      );
    }
    if (key == 'enter') {
      return SizedBox(
        width: size,
        height: size,
        child: FilledButton(
          key: const Key('pin-key-enter'),
          // Sin relleno propio: «Entrar» comparte celda de tamaño fijo con
          // el resto de la rejilla, y FittedBox encoge el texto para que
          // quepa en vez de desbordar con textos grandes de accesibilidad.
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          onPressed: (busy || _pin.length != kSellerPinLength)
              ? null
              : () => unawaited(_submit()),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const FittedBox(child: Text('Entrar')),
        ),
      );
    }
    // Button estándar de Fluent: trae borde y fondo del tema por omisión,
    // del mismo tamaño en toda la rejilla (orden del dueño, lámina ACC-02).
    // Antes era OutlinedButton con CircleBorder, casi sin contorno visible.
    return SizedBox(
      width: size,
      height: size,
      child: Button(
        key: Key('pin-key-$key'),
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(theme.typography.subtitle),
        ),
        onPressed: busy ? null : () => _onDigit(key),
        child: Text(key),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    final theme = FluentTheme.of(context);
    final secondary = theme.resources.textFillColorSecondary;
    final equipmentLabel = widget.equipmentLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (equipmentLabel != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(FluentIcons.pc1, color: theme.accentColor),
              const SizedBox(width: OrbiTheme.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Equipo',
                      style: theme.typography.caption?.copyWith(
                        color: secondary,
                      ),
                    ),
                    Text(equipmentLabel, style: theme.typography.bodyStrong),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OrbiTheme.space16),
          // El Divider por omisión de Fluent pinta con
          // `dividerStrokeColorDefault`, que en oscuro es blanco al 8% de
          // opacidad — contraste ~1.3:1 contra el fondo de la tarjeta,
          // prácticamente invisible. Se reusa el mismo recurso de trazo
          // fuerte que ya usan los puntos del PIN (~5:1 en claro y oscuro).
          Divider(
            style: DividerThemeData(
              decoration: BoxDecoration(
                color: theme.resources.controlStrongStrokeColorDefault,
              ),
            ),
          ),
          const SizedBox(height: OrbiTheme.space16),
        ],
        Text(_kSalesOnlyTitle, style: theme.typography.bodyStrong),
        const SizedBox(height: OrbiTheme.space8),
        Text(_kSalesOnlyBody, style: theme.typography.body),
        const SizedBox(height: OrbiTheme.space16),
        InfoBar(
          title: const Text(_kActivityNotice),
          severity: InfoBarSeverity.info,
        ),
      ],
    );
  }
}

/// The height the normal (non-compact) styling needs for the header,
/// four-row keypad and (when stacked, i.e. not wide-landscape) the info
/// panel beneath it. Compared against the height actually available; see
/// [_PinLoginScreenState.build]. Mirrors login_screen.dart's own
/// `_estimateNormalModeContentHeight`: if you add content to [PinLoginScreen]
/// that changes with width/text-scale, extend THIS budget, not the test that
/// watches it (see the "estimated layout-budget metrics keep matching the
/// real widgets" test in pin_login_screen_test.dart).
double _estimateNormalModeHeight({
  required double keypadWidth,
  required double infoWidth,
  required bool stackedInfo,
  required bool phoneWidth,
  required FluentThemeData theme,
  required TextDirection direction,
  required double textScaleFactor,
  String? equipmentLabel,
  String? message,
}) {
  final typography = theme.typography;
  final titleHeight = _measureTextHeight(
    _kTitle,
    typography.title,
    keypadWidth,
    direction,
    textScaleFactor,
  );
  final subtitleHeight = _measureTextHeight(
    _kSubtitle,
    typography.body,
    keypadWidth,
    direction,
    textScaleFactor,
  );
  var total =
      64.0 + // header icon (normal)
      OrbiTheme.space16 +
      titleHeight +
      OrbiTheme.space8 +
      subtitleHeight +
      OrbiTheme.space24 + // gap before the dot row
      16.0 + // dot row (16px circles)
      OrbiTheme.space24 + // gap before the keypad
      4 * 64.0 +
      3 * OrbiTheme.space12; // four 64px rows, three gaps between them
  if (phoneWidth) {
    // ACC-02 en teléfono: «Entrar» sale de la rejilla y se suma como un
    // botón extra de ancho completo debajo de las cuatro filas.
    total += OrbiTheme.space12 + 64.0;
  }
  if (stackedInfo) {
    total += OrbiTheme.space24;
    if (equipmentLabel != null) {
      total +=
          _measureTextHeight(
            'Equipo\n$equipmentLabel',
            typography.body,
            infoWidth - 32,
            direction,
            textScaleFactor,
          ) +
          OrbiTheme.space16;
    }
    total +=
        _measureTextHeight(
          _kSalesOnlyTitle,
          typography.bodyStrong,
          infoWidth,
          direction,
          textScaleFactor,
        ) +
        OrbiTheme.space8 +
        _measureTextHeight(
          _kSalesOnlyBody,
          typography.body,
          infoWidth,
          direction,
          textScaleFactor,
        ) +
        OrbiTheme.space16 +
        _measureTextHeight(
          _kActivityNotice,
          typography.caption,
          infoWidth - 26,
          direction,
          textScaleFactor,
        );
  }
  if (message != null) {
    total +=
        OrbiTheme.space8 +
        _measureTextHeight(
          message,
          typography.body,
          keypadWidth,
          direction,
          textScaleFactor,
        );
  }
  return total;
}
