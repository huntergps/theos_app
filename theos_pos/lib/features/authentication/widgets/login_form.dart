import 'package:fluent_ui/fluent_ui.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/form/form_fields.dart';
import '../services/server_service.dart';

/// Stable semantics for keyboard automation and integration tests.
///
/// These keys identify controls without depending on localized text or on the
/// concrete Fluent UI widget used by the form.
abstract final class LoginFormKeys {
  static const server = ValueKey<String>('login.server');
  static const database = ValueKey<String>('login.database');
  static const apiKey = ValueKey<String>('login.api-key');
  static const username = ValueKey<String>('login.username');
  static const password = ValueKey<String>('login.password');
  static const credentialMode = ValueKey<String>('login.credential-mode');
  static const submit = ValueKey<String>('login.submit');
  static const manageServers = ValueKey<String>('login.manage-servers');
}

enum LoginCredentialMode { password, apiKey }

/// Formulario de acceso aislado de la gestión de sesión y ventanas.
///
/// Mantiene la pantalla de login enfocada en orquestar el flujo; este widget
/// solo representa los campos y reenvía las acciones al propietario.
class LoginForm extends StatelessWidget {
  const LoginForm({
    required this.formKey,
    required this.controller,
    required this.usernameController,
    required this.credentialMode,
    required this.nativePasswordLoginAvailable,
    required this.servers,
    required this.selectedServer,
    required this.spacing,
    required this.showPassword,
    required this.isLoading,
    required this.loadingStage,
    required this.onServerChanged,
    required this.onTogglePassword,
    required this.onCredentialModeChanged,
    required this.onSubmit,
    required this.onManageServers,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final TextEditingController usernameController;
  final LoginCredentialMode credentialMode;
  final bool nativePasswordLoginAvailable;
  final List<ServerConfig> servers;
  final ServerConfig? selectedServer;
  final ThemedSpacing spacing;
  final bool showPassword;
  final bool isLoading;
  final String loadingStage;
  final ValueChanged<ServerConfig?> onServerChanged;
  final VoidCallback onTogglePassword;
  final ValueChanged<LoginCredentialMode> onCredentialModeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onManageServers;

  @override
  Widget build(BuildContext context) {
    final credentialLabel = credentialMode == LoginCredentialMode.password
        ? 'contraseña'
        : 'clave API';
    final visibilityLabel = showPassword
        ? 'Ocultar $credentialLabel'
        : 'Mostrar $credentialLabel';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormComboBox<ServerConfig>(
            key: LoginFormKeys.server,
            label: 'Servidor',
            value: selectedServer,
            items: servers
                .map(
                  (server) => ComboBoxItem(
                    value: server,
                    child: Tooltip(
                      message: '${server.name} (${server.url})',
                      child: Text(
                        '${server.name} (${server.url})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: onServerChanged,
            placeholder: 'Selecciona un servidor',
          ),
          spacing.vertical.md,
          if (selectedServer != null) ...[
            FormTextField(
              key: LoginFormKeys.database,
              label: 'Base de Datos',
              placeholder: selectedServer!.database,
              readOnly: true,
              enabled: false,
            ),
            spacing.vertical.md,
          ],
          if (credentialMode == LoginCredentialMode.password) ...[
            FormTextField(
              key: LoginFormKeys.username,
              label: 'Usuario',
              controller: usernameController,
              placeholder: 'Ingresa tu usuario',
              prefix: Padding(
                padding: EdgeInsets.only(left: spacing.sm),
                child: const Icon(FluentIcons.contact),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Requerido' : null,
            ),
            Padding(
              padding: EdgeInsets.only(top: spacing.xs),
              child: Text(
                'Recordaremos el usuario en este dispositivo; la contraseña no.',
                style: FluentTheme.of(context).typography.caption
                    ?.copyWith(color: FluentTheme.of(context).inactiveColor),
              ),
            ),
            spacing.vertical.md,
          ],
          FormTextField(
            key: credentialMode == LoginCredentialMode.password
                ? LoginFormKeys.password
                : LoginFormKeys.apiKey,
            label: credentialMode == LoginCredentialMode.password
                ? 'Contraseña'
                : 'Clave API',
            controller: controller,
            placeholder: credentialMode == LoginCredentialMode.password
                ? 'Ingresa tu contraseña'
                : 'Ingresa tu clave API',
            obscureText: !showPassword,
            prefix: Padding(
              padding: EdgeInsets.only(left: spacing.sm),
              child: const Icon(FluentIcons.lock),
            ),
            suffix: Semantics(
              button: true,
              label: visibilityLabel,
              child: Tooltip(
                message: visibilityLabel,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    icon: Icon(
                      showPassword ? FluentIcons.view : FluentIcons.hide,
                    ),
                    onPressed: onTogglePassword,
                  ),
                ),
              ),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
          if (nativePasswordLoginAvailable) ...[
            spacing.vertical.sm,
            Align(
              alignment: Alignment.centerRight,
              child: HyperlinkButton(
                key: LoginFormKeys.credentialMode,
                onPressed: () => onCredentialModeChanged(
                  credentialMode == LoginCredentialMode.password
                      ? LoginCredentialMode.apiKey
                      : LoginCredentialMode.password,
                ),
                child: Text(
                  credentialMode == LoginCredentialMode.password
                      ? 'Usar clave API (avanzado)'
                      : 'Usar usuario y contraseña',
                ),
              ),
            ),
          ],
          spacing.vertical.lg,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: LoginFormKeys.submit,
              onPressed: isLoading ? null : onSubmit,
              child: Padding(
                padding: spacing.symmetric.vSm(),
                child: isLoading
                    ? Semantics(
                        liveRegion: true,
                        label: loadingStage.isEmpty
                            ? 'Iniciando sesión'
                            : loadingStage,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: ProgressRing(
                                activeColor: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            if (loadingStage.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  loadingStage,
                                  style: FluentTheme.of(context)
                                      .typography
                                      .caption
                                      ?.copyWith(color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const Text('Entrar'),
              ),
            ),
          ),
          spacing.vertical.ml,
          Center(
            child: HyperlinkButton(
              key: LoginFormKeys.manageServers,
              onPressed: onManageServers,
              child: const Text('Gestionar Servidores'),
            ),
          ),
        ],
      ),
    );
  }
}
