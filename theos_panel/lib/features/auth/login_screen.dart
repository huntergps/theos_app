import 'dart:async';

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
  final _server = TextEditingController();
  final _database = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _serverFocus = FocusNode();
  final _databaseFocus = FocusNode();
  final _loginFocus = FocusNode();
  final _passwordFocus = FocusNode();
  int _profileLookupEpoch = 0;
  Timer? _loginPreferencesDebounce;
  bool _apiKeyMode = false;
  bool _saveCredential = false;

  @override
  void dispose() {
    _server.dispose();
    _database.dispose();
    _login.dispose();
    _password.dispose();
    _serverFocus.dispose();
    _databaseFocus.dispose();
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

  Future<void> _manageServers() async {
    try {
      final selected = await showSavedServerManager(
        context,
        store: ref.read(savedServersStoreProvider),
        initialUrl: _server.text.trim(),
        initialDatabase: _database.text.trim(),
      );
      if (!mounted || selected == null) return;
      // Invalidate an older server lookup before applying the new selection.
      // No password/API key may cross to another server or database.
      ++_profileLookupEpoch;
      _loginPreferencesDebounce?.cancel();
      _server.text = selected.url;
      _database.text = selected.database;
      _login.clear();
      _password.clear();
      _lookupRememberedProfile();
      _scheduleLoginPreferencesSave();
      _loginFocus.requestFocus();
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
    final value = LoginPreferences(
      serverUrl: _server.text.trim(),
      database: _database.text.trim(),
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
    final server = _server.text.trim();
    final database = _database.text.trim();
    if (server.isEmpty || database.isEmpty) return;
    final epoch = ++_profileLookupEpoch;
    final loginBeforeLookup = _login.text;
    unawaited(() async {
      AuthProfile? profile;
      try {
        profile = await ref
            .read(authControllerProvider.notifier)
            .loadProfileFor(server, database);
      } catch (_) {
        return;
      }
      if (!mounted ||
          epoch != _profileLookupEpoch ||
          _server.text.trim() != server ||
          _database.text.trim() != database ||
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      LoginPreferences? remembered;
      try {
        remembered = ref.read(loginPreferencesStoreProvider).load();
      } catch (_) {
        // Tests and embedders may intentionally omit local preferences.
      }
      if (!mounted) return;
      if (remembered != null && !remembered.isEmpty) {
        _server.text = remembered.serverUrl;
        _database.text = remembered.database;
        _login.text = remembered.login;
      }
      final profile = await ref
          .read(authControllerProvider.notifier)
          .loadProfile();
      if (!mounted || profile == null) return;
      final selectedServer = _server.text.trim();
      final selectedDatabase = _database.text.trim();
      final profileMatchesSelection =
          (selectedServer.isEmpty || selectedServer == profile.serverUrl) &&
          (selectedDatabase.isEmpty || selectedDatabase == profile.database);
      if (_server.text.trim().isEmpty) _server.text = profile.serverUrl;
      if (_database.text.trim().isEmpty) _database.text = profile.database;
      if (_login.text.trim().isEmpty && profileMatchesSelection) {
        _login.text = profile.login;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final colors = Theme.of(context).colorScheme;
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
              'Desarrollado por GalapagosTech · 2026',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A macOS window may be wide enough for the compact backdrop while
          // still being too short for the normal form (for example 800x600).
          // Measure height independently from the width breakpoint so the
          // submit action remains reachable without changing the wide layout.
          final compactHeight = constraints.maxHeight < 720;
          final form = _buildLoginForm(
            context,
            state,
            compactHeight: compactHeight,
          );
          // An iPad in portrait can exceed 840px: it still uses the approved
          // stacked composition, not the horizontal two-column arrangement.
          if (constraints.maxWidth >= OrbiTheme.mediumBreakpoint &&
              constraints.maxWidth > constraints.maxHeight) {
            return Stack(
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
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(OrbiTheme.space16),
                              child: Card(
                                color: colors.surface.withValues(alpha: .96),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    OrbiTheme.space24,
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
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              const OrbiAuthBackdrop(key: Key('compact-login-background')),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(OrbiTheme.space16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Card(
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
          );
        },
      ),
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
    final manageServers = TextButton.icon(
      key: const Key('manage-saved-servers'),
      onPressed: state.isBusy ? null : _manageServers,
      icon: const Icon(Icons.dns_outlined, size: 18),
      label: const Text('Gestionar servidores'),
    );
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Use the app preference rather than a login-only Theme override.
          // This preserves one source of truth and the existing scope boundary.
          // A very short desktop window (for example 800x600) has no vertical
          // room to spare, so these two utility actions share one row instead
          // of stacking as two separate rows above the branding block.
          if (compactHeight)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [manageServers, themeToggle],
            )
          else
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
          if (!compactHeight)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: manageServers,
            ),
          TextField(
            controller: _server,
            focusNode: _serverFocus,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _databaseFocus.requestFocus(),
            onChanged: (_) {
              _lookupRememberedProfile();
              _scheduleLoginPreferencesSave();
            },
            decoration: InputDecoration(
              labelText: 'Servidor',
              hintText: 'https://erp.example.com',
              prefixIcon: Icon(Icons.dns_outlined),
              isDense: compactHeight,
              contentPadding: inputPadding,
            ),
            keyboardType: TextInputType.url,
          ),
          SizedBox(height: fieldGap),
          TextField(
            controller: _database,
            focusNode: _databaseFocus,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _loginFocus.requestFocus(),
            onChanged: (_) {
              _lookupRememberedProfile();
              _scheduleLoginPreferencesSave();
            },
            decoration: InputDecoration(
              labelText: 'Base de datos',
              prefixIcon: Icon(Icons.storage_outlined),
              isDense: compactHeight,
              contentPadding: inputPadding,
            ),
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
              subtitle: compactHeight
                  ? null
                  : const Text(
                      'La clave se guarda sólo en el almacén seguro del dispositivo.',
                    ),
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
                  : Text(
                      _apiKeyMode
                          ? 'Guarda la API key sólo en el almacén seguro.'
                          : 'Guarda la contraseña sólo en el almacén seguro.',
                    ),
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
              child: Text(
                state.message!,
                style: TextStyle(color: colors.error),
              ),
            ),
          ],
          SizedBox(height: headerGap),
          FilledButton.icon(
            onPressed: state.isBusy ? null : _submit,
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
    final auth = ref.read(authControllerProvider.notifier);
    LoginPreferencesStore? loginPreferences;
    try {
      loginPreferences = ref.read(loginPreferencesStoreProvider);
    } catch (_) {
      // Embedders/tests may intentionally omit the convenience store.
    }
    final apiKeyMode = _apiKeyMode;
    final persistCredential = _saveCredential;
    final serverUrl = _server.text.trim();
    final database = _database.text.trim();
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
