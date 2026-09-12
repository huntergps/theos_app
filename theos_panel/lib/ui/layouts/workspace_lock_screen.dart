import 'package:flutter/material.dart';

import '../../app/theme/orbi_theme.dart';
import '../components/orbi_brand.dart';

/// Full-screen surface [OperationalShell] shows while the workspace is
/// locked (ACC-03, "bloquear"). It is a privacy gate, not a new
/// authentication: the screen it covers stays mounted underneath it, so a
/// draft mid-edit and the offline queue are never touched by locking or
/// unlocking — see `docs/orbi_panel/decisions/
/// B01-paridad-fiscal-offline-identidad-y-numeracion.md` on why the queue
/// must never move to another identity, and
/// `docs/orbi_panel/ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md` §8 on why
/// "bloquear operador" must stay a distinct action from "cerrar Workspace".
///
/// It deliberately never reuses the login photographic backdrop
/// (`UI_COHERENCE_RULES.md`: access and shell serve different functions) and
/// never shows server/database details (`SHELL_AND_INTERACTION_SPEC.md`:
/// those never appear on a locked screen).
class WorkspaceLockScreen extends StatefulWidget {
  const WorkspaceLockScreen({
    super.key,
    required this.userLabel,
    required this.pendingSummary,
    required this.onUnlock,
    this.onSwitchUser,
  });

  /// Identity currently locked. Never the server or database.
  final String userLabel;

  /// Reassurance text about locally preserved state (e.g. the shell's own
  /// sync label, "3 pendientes"). Always sourced from the same context the
  /// footer already renders; never invented here.
  final String pendingSummary;

  /// Revalidates the same identity. Returning `false` must never clear any
  /// existing session/profile state — only this screen's own attempt state.
  /// The caller is responsible for not routing a failed attempt through
  /// whatever tears down the authenticated session on a real login failure.
  ///
  /// It must also not require a network: `attemptWorkspaceUnlock` checks the
  /// password against a derivation kept in this device's secure store first
  /// and only falls back to the server, so an operator who locked the screen
  /// with no signal can still get back to their own half-finished work.
  final Future<bool> Function(String password) onUnlock;

  /// Escape hatch for a genuinely different person taking over the device.
  /// Distinct from unlocking: unlocking resumes the same identity exactly
  /// where it left off, this one ends it. See ORBI_PRODUCT_ARCHITECTURE_AND
  /// _UX_SPEC.md §8, "distinguir bloquear operador, cerrar Workspace y
  /// desautorizar dispositivo".
  final VoidCallback? onSwitchUser;

  @override
  State<WorkspaceLockScreen> createState() => _WorkspaceLockScreenState();
}

class _WorkspaceLockScreenState extends State<WorkspaceLockScreen> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Ingresa tu contraseña para desbloquear.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    var unlocked = false;
    try {
      unlocked = await widget.onUnlock(password);
    } catch (_) {
      unlocked = false;
    }
    if (!mounted) return;
    if (unlocked) {
      _passwordController.clear();
      return;
    }
    setState(() {
      _submitting = false;
      // Connectivity is no longer the first thing to suspect: the unlock
      // check runs against a derivation kept on this device when there is one
      // (`WorkspaceUnlockStore`), so the usual cause is simply a wrong
      // password. The second sentence names the one case where the network
      // genuinely is the obstacle — a password changed on the server, whose
      // new value only this device's next online attempt can learn.
      _error =
          'No se pudo verificar la contraseña. Si la cambiaste hace poco, '
          'vuelve a intentarlo con conexión.';
    });
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(OrbiTheme.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: OrbiBrand(
                    height: 56,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: OrbiTheme.space24),
                Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: '',
                ),
                const SizedBox(height: OrbiTheme.space12),
                Text(
                  'Sesión bloqueada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: OrbiTheme.space8),
                Text(
                  widget.userLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: OrbiTheme.space8),
                Text(
                  'Tu trabajo local sigue igual: ${widget.pendingSummary}. '
                  'Nadie puede continuar en tu nombre hasta que ingreses tu '
                  'contraseña.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: OrbiTheme.space24),
                TextField(
                  key: const Key('workspace-lock-password'),
                  controller: _passwordController,
                  obscureText: true,
                  autofocus: true,
                  enabled: !_submitting,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: OrbiTheme.space8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: OrbiTheme.space16),
                FilledButton(
                  key: const Key('workspace-unlock-button'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Desbloquear'),
                ),
                if (widget.onSwitchUser != null) ...[
                  const SizedBox(height: OrbiTheme.space8),
                  TextButton(
                    key: const Key('workspace-lock-switch-user-button'),
                    onPressed: _submitting ? null : widget.onSwitchUser,
                    child: const Text('Cambiar de usuario'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
