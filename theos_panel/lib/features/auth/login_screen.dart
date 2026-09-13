import 'dart:async';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile;

import 'auth_controller.dart';
import 'login_failure_messages.dart';
import 'login_preferences.dart';
import 'pin_login_screen.dart';
import 'session_provenance.dart';
import 'saved_servers.dart';
import 'server_manager_dialog.dart';
import '../../app/theme/orbi_theme.dart';
import '../../app/preferences/app_preferences.dart';
import '../../ui/components/copyable_message.dart';
import '../../ui/components/orbi_brand.dart';

const String _kApiKeySubtitle =
    'La clave se guarda sólo en el almacén seguro del dispositivo.';
const String _kFooterText = 'Desarrollado por GalapagosTech · 2026';

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

String _saveCredentialSubtitleFor(bool apiKeyMode) => apiKeyMode
    ? 'Guarda la API key sólo en el almacén seguro.'
    : 'Guarda la contraseña sólo en el almacén seguro.';

/// The metrics below decide whether the login form's spacious ("normal")
/// styling actually FITS the available height, or whether it must fall back
/// to the tighter ("compact") one instead. They replace a single hand-picked
/// pixel threshold (a flat 720, which lined up with nothing real and left a
/// window between ~720 and ~850 where "normal" was chosen but did not
/// actually fit — see docs/orbi_panel/COORDINATOR_HANDOFF_2026_09_11.md) with
/// a budget built from the same theme/text/spacing values the form actually
/// renders with, so the decision tracks reality instead of a guess.
///
/// Two kinds of numbers feed that budget:
///  - Text heights are measured fresh, every build, with [TextPainter]
///    against the REAL string and the REAL available width. This is what
///    makes the decision genuinely content-driven: a longer translation, a
///    narrower card, or a larger accessibility text scale all change the
///    budget with no code change, because they change how many lines the
///    subtitle/switch descriptions actually wrap to.
///  - The few constants below cover the parts of a Fluent [TextBox]/
///    [PasswordBox]/[ComboBox] or [ToggleSwitch] row that [TextPainter]
///    cannot see (the control's own minimum height, its knob, the
///    [InfoLabel] gap). They replace the Material-3 constants this file used
///    before the Fluent port (12-sep-2026) — see the "estimated layout-budget
///    metrics keep matching the real widgets" test, which fails immediately
///    if the theme ever changes one of these instead of letting the budget
///    silently drift out from under it.
///  - [_kMinInteractiveDimension] (48.0) covers every other fixed-height row
///    here: an [IconButton], a [HyperlinkButton], or a [FilledButton] — a
///    reasonable touch-target size, not tied to any framework constant now
///    that Material's `kMinInteractiveDimension` is gone.
const double _kMinInteractiveDimension = 48.0;
// A field built from InfoLabel (its own body-text label line, plus a 4px
// gap) over a Fluent TextBox/PasswordBox/ComboBox, whose own minimum height
// is 32 at standard density. None of "Servidor"/"Usuario"/"Contraseña"/"API
// key"/"Base de datos" ever wrap, so the label line is a fixed one-line
// height rather than measured per-build.
const double _kFieldLabelLineHeight = 20.0; // typography.body, one line.
const double _kFieldLabelGap = 4.0; // InfoLabel's own spacing under the label.
const double _kControlMinHeight = 32.0; // TextBox/PasswordBox/ComboBox at standard density.
const double _kFieldHeight =
    _kFieldLabelLineHeight + _kFieldLabelGap + _kControlMinHeight;
// A ToggleSwitch row: its own 20px knob sits beside a body-text label of the
// same one-line height, so the row itself never exceeds one text line.
const double _kToggleRowHeight = 20.0;
// Matches the real `Padding(top: OrbiTheme.space4)` between the ToggleSwitch
// row and its subtitle — kept as its own named constant (rather than
// OrbiTheme.space4 inline) so this budget documents every number it depends
// on in one place, the same way the rest of this file does.
const double _kToggleSubtitleGap = OrbiTheme.space4;

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

double _estimateSwitchTileHeight({
  required String subtitle,
  required double tileWidth,
  required TextStyle? subtitleStyle,
  required TextDirection direction,
  required double textScaleFactor,
}) {
  final subtitleHeight = _measureTextHeight(
    subtitle,
    subtitleStyle,
    tileWidth,
    direction,
    textScaleFactor,
  );
  return _kToggleRowHeight + _kToggleSubtitleGap + subtitleHeight;
}

/// The height the NORMAL (non-compact) styling needs for the whole card
/// content — header through the submit button — at [contentWidth]. Compared
/// against the height actually available; see [_LoginScreenState.build].
///
/// The form now has THREE field-shaped rows, not four: the database field is
/// gone (it travels with the chosen saved server instead of being typed), and
/// the "Gestionar servidores" link no longer gets its own header row — it is
/// a menu entry inside the server selector itself. Both of those used to add
/// their own term to this budget; dropping either without dropping the term
/// here is exactly the kind of drift the "estimated layout-budget metrics
/// keep matching the real widgets" test exists to catch.
double _estimateNormalModeContentHeight({
  required double contentWidth,
  required FluentThemeData theme,
  required TextDirection direction,
  required double textScaleFactor,
  required bool apiKeyMode,
  required String? errorMessage,
  bool serversUnreadable = false,
}) {
  final typography = theme.typography;
  final titleHeight = _measureTextHeight(
    'Acceso a Orbi',
    typography.title,
    contentWidth,
    direction,
    textScaleFactor,
  );
  final subtitleHeight = _measureTextHeight(
    'Conéctate a tu entorno de trabajo',
    typography.body,
    contentWidth,
    direction,
    textScaleFactor,
  );
  final apiKeySubtitleHeight = _estimateSwitchTileHeight(
    subtitle: _kApiKeySubtitle,
    tileWidth: contentWidth,
    subtitleStyle: typography.caption,
    direction: direction,
    textScaleFactor: textScaleFactor,
  );
  final saveCredentialSubtitleHeight = _estimateSwitchTileHeight(
    subtitle: _saveCredentialSubtitleFor(apiKeyMode),
    tileWidth: contentWidth,
    subtitleStyle: typography.caption,
    direction: direction,
    textScaleFactor: textScaleFactor,
  );
  var total =
      _kMinInteractiveDimension + // top-right theme-toggle row
      OrbiTheme.space12 + // gap under that row
      84.0 + // logo height (normal)
      OrbiTheme.space16 +
      titleHeight +
      OrbiTheme.space8 +
      subtitleHeight +
      OrbiTheme.space24 + // headerGap (normal), before the fields
      3 * (_kFieldHeight + OrbiTheme.space12) + // server selector + usuario + contraseña, each + its gap
      apiKeySubtitleHeight +
      OrbiTheme.space12 + // gap between the "Usar API key" and "Guardar clave" toggle blocks (see fieldsAndToggles)
      saveCredentialSubtitleHeight +
      OrbiTheme.space24 + // headerGap (normal), before the submit button
      _kControlMinHeight; // submit button
  if (serversUnreadable) {
    // It renders as the same panel the sign-in failures use, so it costs the
    // same chrome — not one wrapped line.
    total +=
        OrbiTheme.space8 +
        _failurePanelHeight(
          title: _kServersUnreadableMessage.title,
          body: _kServersUnreadableMessage.body,
          theme: theme,
          contentWidth: contentWidth,
          direction: direction,
          textScaleFactor: textScaleFactor,
        );
  }
  if (errorMessage != null) {
    total +=
        OrbiTheme.space12 +
        estimateLoginFailurePanelHeight(
          message: errorMessage,
          theme: theme,
          contentWidth: contentWidth,
          direction: direction,
          textScaleFactor: textScaleFactor,
        );
  }
  return total;
}

/// Chrome [LoginFailurePanel] adds around its two text blocks: the padding on
/// both sides, its one-pixel border, the leading icon and the gap after it.
/// Measured against the widget itself by the "estimated layout-budget metrics"
/// test, same as every other constant in this budget.
// The gap plus the action row. The button is a Fluent [Button], whose own
// minimum height clusters around [_kControlMinHeight] the same as every
// other single-row Fluent control in this file's budget (TextBox, PasswordBox,
// ComboBox, ToggleSwitch). Pinned by "the action row is the height the
// layout budget assumes" in test/ui/copyable_message_test.dart.
const double _kFailurePanelActionRowHeight =
    OrbiTheme.space4 + _kControlMinHeight;
const double _kFailurePanelVerticalChrome =
    OrbiTheme.space12 * 2 + 2 + // padding top+bottom + 1px border each side
    _kFailurePanelActionRowHeight;
const double _kFailurePanelTextInset =
    OrbiTheme.space12 * 2 + 2 + 20 + OrbiTheme.space12; // padding + border + icon + gap

/// The height the rendered error costs the form.
///
/// A failure that carries guidance is TWO text blocks inside a padded panel,
/// not the single wrapped line the old flat `Text` was — so the budget has to
/// ask [decodeLoginFailureMessage] what it is actually about to draw, or the
/// compact/normal decision starts under-counting exactly when something has
/// gone wrong and the form is at its tallest.
double estimateLoginFailurePanelHeight({
  required String message,
  required FluentThemeData theme,
  required double contentWidth,
  required TextDirection direction,
  required double textScaleFactor,
}) {
  final failure = decodeLoginFailureMessage(message);
  if (failure == null) {
    return _measureTextHeight(
      message,
      theme.typography.body,
      contentWidth,
      direction,
      textScaleFactor,
    );
  }
  return _failurePanelHeight(
    title: failure.title,
    body: failure.guidance,
    theme: theme,
    contentWidth: contentWidth,
    direction: direction,
    textScaleFactor: textScaleFactor,
  );
}

/// What one [CopyableMessagePanel] costs at [contentWidth].
double _failurePanelHeight({
  required String title,
  required String body,
  required FluentThemeData theme,
  required double contentWidth,
  required TextDirection direction,
  required double textScaleFactor,
}) {
  final textWidth = contentWidth - _kFailurePanelTextInset;
  return _kFailurePanelVerticalChrome +
      _measureTextHeight(
        title,
        theme.typography.bodyStrong,
        textWidth,
        direction,
        textScaleFactor,
      ) +
      OrbiTheme.space4 +
      _measureTextHeight(
        body,
        theme.typography.caption,
        textWidth,
        direction,
        textScaleFactor,
      );
}

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
  int _profileLookupEpoch = 0;
  Timer? _loginPreferencesDebounce;
  bool _apiKeyMode = false;
  bool _saveCredential = false;

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
    _loginPreferencesDebounce?.cancel();
    super.dispose();
  }

  void _scheduleLoginPreferencesSave() {
    _loginPreferencesDebounce?.cancel();
    _loginPreferencesDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_saveLoginPreferences());
    });
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
    _loginPreferencesDebounce?.cancel();
    setState(() {
      _selectedServer = server;
      _login.clear();
      _password.clear();
    });
    _lookupRememberedProfile();
    _scheduleLoginPreferencesSave();
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
        _scheduleLoginPreferencesSave();
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
    final direction = Directionality.of(context);
    // Decide compact-vs-normal (and the two-column-vs-stacked branch below)
    // from the STABLE window/screen size, never from the body's LayoutBuilder
    // constraints. Those constraints shrink whenever
    // Scaffold.resizeToAvoidBottomInset reacts to MediaQuery.viewInsets, and
    // on a fixed-size desktop/web window there is no software keyboard to
    // explain a change there — yet focusing a field was reported to reflow
    // the whole form (subtitles and the "manage servers" row jumping). Using
    // MediaQuery.sizeOf makes that decision immune to whatever nudges the
    // inset, by construction, regardless of the exact platform cause. Real
    // keyboard avoidance (when it legitimately applies, e.g. on a phone)
    // still works: the scrollable middle section reacts to the live body
    // constraints in _buildLoginForm, independently of this decision.
    final screenSize = MediaQuery.sizeOf(context);
    final devicePadding = MediaQuery.paddingOf(context);
    // TextPainter wants a scale factor, not the TextScaler object.
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(14) / 14;
    final footerTextHeight = _measureTextHeight(
      _kFooterText,
      theme.typography.caption,
      math.max(screenSize.width - OrbiTheme.space12 * 2, 0),
      direction,
      textScaleFactor,
    );
    final footerHeight =
        footerTextHeight + OrbiTheme.space12 * 2 + devicePadding.bottom;
    // An iPad in portrait can exceed 840px: it still uses the approved
    // stacked composition, not the horizontal two-column arrangement.
    final isWideLandscape =
        screenSize.width >= OrbiTheme.mediumBreakpoint &&
        screenSize.width > screenSize.height;
    // Both branches wrap the card in the same space16 outer padding and, for
    // this fits-or-not check, the same space24 "normal" card padding.
    final contentWidth = isWideLandscape
        ? 440.0 - OrbiTheme.space16 * 2 - OrbiTheme.space24 * 2
        : math.min(screenSize.width - OrbiTheme.space16 * 2, 520.0) -
              OrbiTheme.space24 * 2;
    final normalModeHeight = _estimateNormalModeContentHeight(
      contentWidth: contentWidth,
      theme: theme,
      direction: direction,
      textScaleFactor: textScaleFactor,
      apiKeyMode: _apiKeyMode,
      errorMessage: state.message,
      serversUnreadable: _serversUnreadable,
    );
    final availableForNormalMode =
        screenSize.height -
        footerHeight -
        devicePadding.top -
        OrbiTheme.space16 * 2 -
        OrbiTheme.space24 * 2;
    final compactHeight = normalModeHeight > availableForNormalMode;
    final form = _buildLoginForm(context, state, compactHeight: compactHeight);
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
      key: const Key('login-credit-footer'),
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
    );
    return ScaffoldPage(
      // ScaffoldPage's own default padding is 24px top, painted with
      // scaffoldBackgroundColor UNDER the content — with a photo backdrop
      // that shows as a solid strip above it. The photo must start at the
      // very top of the screen instead.
      padding: EdgeInsets.zero,
      bottomBar: footer,
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
                                // Was hardcoded to space24 regardless of
                                // compactHeight, unlike the narrow branch
                                // below. That mismatch alone both starved
                                // the "manage servers" + theme-toggle row
                                // of width (a RenderFlex overflow) and ate
                                // vertical budget the submit button needed
                                // on a short-but-wide desktop window.
                                padding: EdgeInsets.all(
                                  compactHeight
                                      ? OrbiTheme.space12
                                      : OrbiTheme.space24,
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
                          padding: EdgeInsets.all(
                            compactHeight
                                ? OrbiTheme.space12
                                : OrbiTheme.space24,
                          ),
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

  Widget _buildServerSelector({
    required bool compactHeight,
    required bool busy,
  }) {
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
      children: [
        InfoLabel(
          label: 'Servidor',
          child: ComboBox<String>(
            value: _selectedServer?.id,
            items: items,
            onChanged: busy ? null : _handleServerSelectionChanged,
            // Without this, the field's internal Row sizes itself to the
            // intrinsic width of the selected item/hint text and overflows
            // against the dropdown arrow the moment a server name (or the
            // "Gestionar servidores…" hint) is long enough for a narrow card.
            isExpanded: true,
            placeholder: Text(
              hasServers
                  ? 'Selecciona un servidor'
                  : 'Ningún servidor guardado',
              overflow: TextOverflow.ellipsis,
            ),
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

  Widget _buildLoginForm(
    BuildContext context,
    AuthViewState state, {
    required bool compactHeight,
  }) {
    final theme = FluentTheme.of(context);
    final fieldGap = compactHeight ? OrbiTheme.space8 : OrbiTheme.space12;
    final headerGap = compactHeight ? OrbiTheme.space12 : OrbiTheme.space24;
    final logoHeight = compactHeight ? 56.0 : 84.0;
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
    // row of its own: this row's height (_kMinInteractiveDimension) is
    // already part of _estimateNormalModeContentHeight's fixed budget, and a
    // second affordance stacked below it would grow the real form without
    // growing that estimate, silently drifting the compact/normal boundary
    // the CASE 1-3 tests below pin down. Sharing the row keeps that budget
    // true with no new term to add or forget.
    final pinModeButton = Tooltip(
      message: 'Modo vendedor (PIN)',
      child: IconButton(
        key: const Key('login-pin-mode-button'),
        icon: const Icon(FluentIcons.pin),
        onPressed: () => setState(() => _pinMode = true),
      ),
    );
    // The submit button (and the header above it) must never end up behind
    // the translucent credit footer, no matter how short the window is. Only
    // the fields+toggles in between are allowed to scroll: they sit in a
    // Flexible+shrinkWrap section that keeps its natural height while there
    // is room, and only clamps (turning scrollable) once the window is too
    // short — the header and the button stay pinned and fully visible either
    // way. See docs/orbi_panel/COORDINATOR_HANDOFF_2026_09_11.md for why the
    // footer itself must stay translucent/extendBody rather than be removed.
    final header = <Widget>[
      // Use the app preference rather than a login-only Theme override.
      // This preserves one source of truth and the existing scope boundary.
      // Choosing an environment used to need a second, separate header row
      // ("Gestionar servidores"). That control now lives inside the server
      // selector itself (see _buildServerSelector), so this row only ever
      // holds the theme toggle, in both compact and normal styling.
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [pinModeButton, themeToggle],
      ),
      SizedBox(height: compactHeight ? OrbiTheme.space8 : OrbiTheme.space12),
      OrbiBrand(height: logoHeight, color: theme.accentColor),
      const SizedBox(height: OrbiTheme.space16),
      Text(
        'Acceso a Orbi',
        style: theme.typography.title,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: OrbiTheme.space8),
      Text(
        'Conéctate a tu entorno de trabajo',
        style: theme.typography.body?.copyWith(
          color: theme.resources.textFillColorSecondary,
        ),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: headerGap),
    ];
    final fieldsAndToggles = <Widget>[
      _buildServerSelector(compactHeight: compactHeight, busy: state.isBusy),
      SizedBox(height: fieldGap),
      InfoLabel(
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
          onChanged: (_) => _scheduleLoginPreferencesSave(),
          autofillHints: const [AutofillHints.username],
        ),
      ),
      SizedBox(height: fieldGap),
      InfoLabel(
        label: _apiKeyMode ? 'API key' : 'Contraseña',
        // TextBox+obscureText rather than PasswordBox: PasswordBox has no
        // `autofillHints`, and keeping password managers working matters
        // more here than PasswordBox's reveal-button affordance.
        child: TextBox(
          controller: _password,
          focusNode: _passwordFocus,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          obscureText: true,
          prefix: const Padding(
            padding: EdgeInsets.symmetric(horizontal: OrbiTheme.space8),
            child: Icon(FluentIcons.lock, size: 16),
          ),
          autofillHints: const [AutofillHints.password],
        ),
      ),
      SizedBox(height: fieldGap),
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
          // Secondary help is omitted only in a tight window; the switch
          // label remains visible and keeps the compact form readable.
          if (!compactHeight)
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
      // Was missing entirely: the two toggle blocks sat flush against each
      // other. See _estimateNormalModeContentHeight for the matching budget
      // term this gap adds.
      SizedBox(height: fieldGap),
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
          if (!compactHeight)
            Padding(
              padding: const EdgeInsets.only(top: OrbiTheme.space4),
              child: Text(
                _saveCredentialSubtitleFor(_apiKeyMode),
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
        ],
      ),
      // La sesión que el arranque encontró y decidió NO adoptar. Va ARRIBA
      // del mensaje de error y ABAJO de los campos: es una salida rápida, no
      // el camino principal — quien no sea esa persona tiene el formulario
      // justo encima, ya relleno y listo.
      if (ref.watch(offeredSessionProvider) case final OfferedSession offer)
        ...[
          const SizedBox(height: OrbiTheme.space12),
          _OfferedSessionCard(
            key: const Key('offered-session-card'),
            offer: offer,
            onContinue: _continueWithOfferedSession,
          ),
        ],
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
              style: TextStyle(
                color: theme.resources.systemFillColorCritical,
              ),
            ),
          ),
      ],
    ];
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...header,
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: fieldsAndToggles,
              ),
            ),
          ),
          SizedBox(height: headerGap),
          FilledButton(
            onPressed: (state.isBusy || _selectedServer == null)
                ? null
                : _submit,
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
          ),
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

  /// Acepta la sesión que ya estaba abierta. El atajo del dueño, intacto:
  /// sigue siendo un clic. Lo único que cambió es que lo da una persona.
  Future<void> _continueWithOfferedSession() async {
    await ref.read(authControllerProvider.notifier).restore();
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
    if (apiKeyMode) {
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
    }
    if (succeeded) {
      if (loginPreferences != null) {
        await _saveLoginPreferences(store: loginPreferences);
      }
      if (!mounted) return;
    }
    _password.clear();
    TextInput.finishAutofillContext(shouldSave: succeeded);
  }
}

/// La oferta de una sesión ajena, en la propia pantalla de acceso.
///
/// Deliberadamente NO es un botón suelto: nombra a la persona y dice la
/// consecuencia. «Continuar con la sesión abierta» no deja ver a quién estás a
/// punto de suplantar; «Continuar como jacqueline.rizo» sí.
class _OfferedSessionCard extends StatelessWidget {
  const _OfferedSessionCard({
    super.key,
    required this.offer,
    required this.onContinue,
  });

  final OfferedSession offer;
  final Future<void> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    // Un aviso con color por significado se hace con InfoBar y su
    // InfoBarSeverity, nunca pintado a mano: aquí es "info" porque es un
    // hecho que conviene notar, no una advertencia ni un error. Nada de
    // color, borde o relleno propio — todo lo resuelve el tema.
    return Semantics(
      container: true,
      label: '${offer.actionLabel}. ${offer.explanation}',
      child: ExcludeSemantics(
        child: InfoBar(
          title: Text(offer.explanation),
          isLong: true,
          action: OutlinedButton(
            key: const Key('continue-offered-session'),
            onPressed: () => onContinue(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.contact, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    offer.actionLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
