import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile;

import 'auth_controller.dart';
import 'login_preferences.dart';
import 'saved_servers.dart';
import 'server_manager_dialog.dart';
import '../../app/theme/orbi_theme.dart';
import '../../app/preferences/app_preferences.dart';
import '../../ui/components/orbi_brand.dart';

const String _kApiKeySubtitle =
    'La clave se guarda sólo en el almacén seguro del dispositivo.';
const String _kFooterText = 'Desarrollado por GalapagosTech · 2026';

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
///  - The few constants below cover the parts of a Material TextField or
///    SwitchListTile that TextPainter cannot see (borders, internal padding,
///    the switch control itself). They are not guesses: each one was
///    measured once against this app's actual Material 3 theme — see the
///    "estimated layout-budget metrics keep matching the real widgets" test,
///    which fails immediately if the theme ever changes one of these instead
///    of letting the budget silently drift out from under it.
///  - [kMinInteractiveDimension] (48.0, from package:flutter/material.dart)
///    covers every other fixed-height row here: IconButton, TextButton.icon,
///    a dense/compact TextField or SwitchListTile, and FilledButton.icon —
///    Flutter's own default touch-target size, not something invented here.
const double _kNormalTextFieldHeight = 52.0; // width-independent: our field labels/hints never wrap.
const double _kSwitchTileTitleLineHeight = 24.0; // width-independent: "Usar API key" / "Guardar clave" never wrap.
const double _kSwitchTileVerticalChrome = 16.0; // ListTile's own default top+bottom padding (8+8).
const double _kSwitchTileTextInset = 76.0; // Switch control + ListTile's fixed horizontal padding.

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
    tileWidth - _kSwitchTileTextInset,
    direction,
    textScaleFactor,
  );
  return _kSwitchTileTitleLineHeight +
      subtitleHeight +
      _kSwitchTileVerticalChrome;
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
  required ThemeData theme,
  required TextDirection direction,
  required double textScaleFactor,
  required bool apiKeyMode,
  required String? errorMessage,
  String? serversLoadError,
}) {
  final titleHeight = _measureTextHeight(
    'Acceso a Orbi',
    theme.textTheme.titleLarge,
    contentWidth,
    direction,
    textScaleFactor,
  );
  final subtitleHeight = _measureTextHeight(
    'Conéctate a tu entorno de trabajo',
    theme.textTheme.bodyMedium,
    contentWidth,
    direction,
    textScaleFactor,
  );
  final apiKeySubtitleHeight = _estimateSwitchTileHeight(
    subtitle: _kApiKeySubtitle,
    tileWidth: contentWidth,
    subtitleStyle: theme.textTheme.bodyMedium,
    direction: direction,
    textScaleFactor: textScaleFactor,
  );
  final saveCredentialSubtitleHeight = _estimateSwitchTileHeight(
    subtitle: _saveCredentialSubtitleFor(apiKeyMode),
    tileWidth: contentWidth,
    subtitleStyle: theme.textTheme.bodyMedium,
    direction: direction,
    textScaleFactor: textScaleFactor,
  );
  var total =
      kMinInteractiveDimension + // top-right theme-toggle row
      OrbiTheme.space12 + // gap under that row
      84.0 + // logo height (normal)
      OrbiTheme.space16 +
      titleHeight +
      OrbiTheme.space8 +
      subtitleHeight +
      OrbiTheme.space24 + // headerGap (normal), before the fields
      3 * (_kNormalTextFieldHeight + OrbiTheme.space12) + // server selector + usuario + contraseña, each + its gap
      apiKeySubtitleHeight +
      saveCredentialSubtitleHeight +
      OrbiTheme.space24 + // headerGap (normal), before the submit button
      kMinInteractiveDimension; // submit button
  if (serversLoadError != null) {
    total +=
        OrbiTheme.space8 +
        _measureTextHeight(
          serversLoadError,
          theme.textTheme.bodyMedium,
          contentWidth,
          direction,
          textScaleFactor,
        );
  }
  if (errorMessage != null) {
    total +=
        OrbiTheme.space12 +
        _measureTextHeight(
          errorMessage,
          theme.textTheme.bodyMedium,
          contentWidth,
          direction,
          textScaleFactor,
        );
  }
  return total;
}

Color loginBrandOverlayColor(ColorScheme colors, double alpha) {
  // Keep the photograph visible while choosing a neutral veil that supports
  // the scheme's actual foreground (white in light mode, dark in dark mode).
  final veil = colors.onPrimary.computeLuminance() > .5
      ? Colors.black
      : Colors.white;
  return veil.withValues(alpha: alpha);
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
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(color: orbiPhotoInk),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OrbiTheme.space8),
              Text(
                'Trabaja con tu equipo desde un solo lugar.',
                style: Theme.of(context).textTheme.bodyLarge
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

  // The database travels with the saved server, not with anything the user
  // types: it is resolved the moment an environment is selected, and never
  // rendered anywhere in this form. See saved_servers.dart and
  // docs/orbi_panel/COORDINATOR_HANDOFF_2026_09_11.md.
  List<SavedServer> _servers = const [];
  SavedServer? _selectedServer;
  String? _serversLoadError;

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
  /// [_serversLoadError]. A store that isn't wired up at all (embedders and
  /// most widget tests never override `sharedPreferencesProvider`) is treated
  /// as "no servers yet", the same convention already used below for
  /// [LoginPreferencesStore].
  void _readServers() {
    try {
      final servers = ref.read(savedServersStoreProvider).load();
      _servers = servers;
      _serversLoadError = null;
      if (_selectedServer != null) {
        _selectedServer = servers.cast<SavedServer?>().firstWhere(
          (server) => server!.id == _selectedServer!.id,
          orElse: () => null,
        );
      }
    } on FormatException catch (error) {
      _servers = const [];
      _selectedServer = null;
      _serversLoadError =
          'No se pudieron leer los servidores guardados: ${error.message}';
    } catch (_) {
      // Tests and embedders may intentionally omit the saved-servers store.
      _servers = const [];
      _selectedServer = null;
      _serversLoadError = null;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la gestión de servidores.'),
        ),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
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
      theme.textTheme.bodySmall,
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
      serversLoadError: _serversLoadError,
    );
    final availableForNormalMode =
        screenSize.height -
        footerHeight -
        devicePadding.top -
        OrbiTheme.space16 * 2 -
        OrbiTheme.space24 * 2;
    final compactHeight = normalModeHeight > availableForNormalMode;
    final form = _buildLoginForm(context, state, compactHeight: compactHeight);
    return Scaffold(
      // Extend the photograph behind the translucent credit strip. SafeArea
      // keeps the form clear of the footer and the device's bottom inset.
      extendBody: true,
      bottomNavigationBar: ColoredBox(
        key: const Key('login-credit-footer'),
        color: colors.surface.withValues(alpha: .72),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(OrbiTheme.space12),
            child: Text(
              _kFooterText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      body: isWideLandscape
          ? Stack(
              fit: StackFit.expand,
              children: [
                const OrbiAuthBackdrop(),
                SafeArea(
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
                              child: Card(
                                // Card's own default margin (4 on every side)
                                // was invisibly eating into the width/height
                                // budget on top of the Padding above, which
                                // already provides the intended spacing.
                                margin: EdgeInsets.zero,
                                color: colors.surface.withValues(alpha: .96),
                                elevation: 2,
                                child: Padding(
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
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(OrbiTheme.space16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Card(
                          margin: EdgeInsets.zero,
                          color: colors.surface.withValues(alpha: .96),
                          elevation: 2,
                          child: Padding(
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
                ),
              ],
            ),
    );
  }

  Widget _buildServerSelector({
    required bool compactHeight,
    required bool busy,
    required EdgeInsetsGeometry? inputPadding,
    required ColorScheme colors,
  }) {
    final hasServers = _servers.isNotEmpty;
    final items = <DropdownMenuItem<String>>[
      for (final server in _servers)
        DropdownMenuItem(
          value: server.id,
          child: Text(server.name, overflow: TextOverflow.ellipsis),
        ),
      const DropdownMenuItem(
        key: Key('manage-servers-option'),
        value: _kManageServersOptionValue,
        child: Text(_kManageServersLabel),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          // A DropdownButtonFormField only honors `initialValue` on its FIRST
          // build (it is a plain FormField, not a controlled widget) — see
          // the migration note on `value` in package:flutter's dropdown.dart.
          // Keying it by the selection forces Flutter to recreate the field
          // (and therefore re-seed initialValue) whenever the selection
          // itself changes, which is exactly when a fresh seed is needed;
          // renaming a server without changing its id keeps the same key and
          // still picks up the new label on the next build, since `items` is
          // rebuilt fresh every time regardless.
          key: ValueKey('server-selector::${_selectedServer?.id}'),
          initialValue: _selectedServer?.id,
          items: items,
          onChanged: busy ? null : _handleServerSelectionChanged,
          // Without this, the field's internal Row sizes itself to the
          // intrinsic width of the selected item/hint text and overflows
          // against the dropdown arrow the moment a server name (or the
          // "Gestionar servidores…" hint) is long enough for a narrow card.
          isExpanded: true,
          hint: Text(
            hasServers ? 'Selecciona un servidor' : 'Ningún servidor guardado',
            overflow: TextOverflow.ellipsis,
          ),
          decoration: InputDecoration(
            labelText: 'Servidor',
            prefixIcon: const Icon(Icons.dns_outlined),
            isDense: compactHeight,
            contentPadding: inputPadding,
          ),
        ),
        if (_serversLoadError != null) ...[
          const SizedBox(height: OrbiTheme.space8),
          Text(_serversLoadError!, style: TextStyle(color: colors.error)),
        ],
      ],
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    AuthViewState state, {
    required bool compactHeight,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fieldGap = compactHeight ? OrbiTheme.space8 : OrbiTheme.space12;
    final headerGap = compactHeight ? OrbiTheme.space12 : OrbiTheme.space24;
    final logoHeight = compactHeight ? 56.0 : 84.0;
    final inputPadding = compactHeight
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : null;
    final themeToggle = IconButton(
      key: const Key('login-theme-toggle'),
      tooltip: theme.brightness == Brightness.dark
          ? 'Cambiar a modo claro'
          : 'Cambiar a modo oscuro',
      icon: Icon(
        theme.brightness == Brightness.dark
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No se pudo guardar el tema.')));
        }
      },
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
      Align(alignment: AlignmentDirectional.centerEnd, child: themeToggle),
      SizedBox(height: compactHeight ? OrbiTheme.space8 : OrbiTheme.space12),
      OrbiBrand(height: logoHeight, color: colors.primary),
      const SizedBox(height: OrbiTheme.space16),
      Text(
        'Acceso a Orbi',
        style: theme.textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: OrbiTheme.space8),
      Text(
        'Conéctate a tu entorno de trabajo',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
      SizedBox(height: headerGap),
    ];
    final fieldsAndToggles = <Widget>[
      _buildServerSelector(
        compactHeight: compactHeight,
        busy: state.isBusy,
        inputPadding: inputPadding,
        colors: colors,
      ),
      SizedBox(height: fieldGap),
      TextField(
        controller: _login,
        focusNode: _loginFocus,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _passwordFocus.requestFocus(),
        decoration: InputDecoration(
          labelText: 'Usuario',
          prefixIcon: Icon(Icons.person_outline),
          isDense: compactHeight,
          contentPadding: inputPadding,
        ),
        onChanged: (_) => _scheduleLoginPreferencesSave(),
        autofillHints: const [AutofillHints.username],
      ),
      SizedBox(height: fieldGap),
      TextField(
        controller: _password,
        focusNode: _passwordFocus,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        obscureText: true,
        decoration: InputDecoration(
          labelText: _apiKeyMode ? 'API key' : 'Contraseña',
          prefixIcon: Icon(Icons.lock_outline),
          isDense: compactHeight,
          contentPadding: inputPadding,
        ),
        autofillHints: const [AutofillHints.password],
      ),
      Material(
        type: MaterialType.transparency,
        child: SwitchListTile.adaptive(
          key: const Key('api-key-mode-toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Usar API key'),
          // Secondary help is omitted only in a tight window; the switch
          // title remains visible and keeps the compact form readable.
          subtitle: compactHeight ? null : const Text(_kApiKeySubtitle),
          visualDensity: compactHeight ? VisualDensity.compact : null,
          value: _apiKeyMode,
          onChanged: (value) => setState(() => _apiKeyMode = value),
        ),
      ),
      Material(
        type: MaterialType.transparency,
        child: SwitchListTile.adaptive(
          key: const Key('save-credential-toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Guardar clave'),
          subtitle: compactHeight
              ? null
              : Text(_saveCredentialSubtitleFor(_apiKeyMode)),
          visualDensity: compactHeight ? VisualDensity.compact : null,
          value: _saveCredential,
          onChanged: (value) => setState(() => _saveCredential = value),
        ),
      ),
      if (state.message != null) ...[
        const SizedBox(height: OrbiTheme.space12),
        Semantics(
          liveRegion: true,
          container: true,
          label: state.message,
          child: Text(state.message!, style: TextStyle(color: colors.error)),
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
          FilledButton.icon(
            onPressed: (state.isBusy || _selectedServer == null)
                ? null
                : _submit,
            icon: state.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(state.isBusy ? 'Conectando…' : 'Iniciar sesión'),
          ),
        ],
      ),
    );
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
