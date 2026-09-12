import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'pin_credential_store.dart';

/// The missing half of ACC-02: `PinCredentialStore` already knows how to
/// enroll, verify and forget a seller PIN, but until this widget nothing
/// ever called `enroll` — so nobody could configure one on this device (see
/// `docs/orbi_panel/PENDIENTES.md`, "El enrolamiento del PIN no existe").
///
/// This is the "seguridad" slice of CFG-01
/// (`docs/orbi_panel/APPROVED_SCREEN_INDEX.md`: "Configurar apariencia,
/// modalidad, offline y seguridad"), embedded in the already-authenticated
/// Settings screen rather than a new top-level route — CFG-01 itself has no
/// approved visual baseline yet
/// (`docs/orbi_panel/VISUAL_COVERAGE.md`: "Sin lámina identificada"), so this
/// does not invent that screen, only the one piece of it this defect needs.
///
/// The PIN enrolled here is scoped to the CURRENT Workspace identity
/// (`pinScopeKeyFor`, the exact key `PinLoginScreen` verifies against) and
/// never raises capabilities beyond
/// `ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md` §6.2's ceiling: "PIN → como
/// máximo, capacidades de vendedor". Enrolling, changing or removing it is
/// entirely local — it never talks to Odoo.
class PinEnrollmentSection extends ConsumerStatefulWidget {
  const PinEnrollmentSection({super.key});

  @override
  ConsumerState<PinEnrollmentSection> createState() =>
      _PinEnrollmentSectionState();
}

class _PinEnrollmentSectionState extends ConsumerState<PinEnrollmentSection> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _editingOpen = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    // Settings is only reachable while authenticated (RouteAccessPolicy), so
    // this is defensive, not the expected path — never a broken form with no
    // identity to scope the PIN under.
    if (profile == null) return const SizedBox.shrink();
    final store = ref.watch(pinCredentialStoreProvider);
    final scopeKey = pinScopeKeyFor(
      profile.serverUrl,
      profile.database,
      profile.login,
    );
    final enrolled = store.isEnrolled(scopeKey);
    final typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const Text('Seguridad'),
        const SizedBox(height: 8),
        if (!enrolled || _editingOpen)
          _form(context, store: store, scopeKey: scopeKey, enrolled: enrolled)
        else
          _status(context),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _notice!,
              key: const Key('pin-enroll-notice'),
              style: typography.caption,
            ),
          ),
      ],
    );
  }

  Widget _status(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const ListTile(
        key: Key('pin-enroll-status'),
        contentPadding: EdgeInsets.zero,
        leading: Icon(FluentIcons.contact_lock),
        title: Text('PIN de vendedor configurado'),
        subtitle: Text(
          'Puedes usarlo para entrar directo a Ventas en este dispositivo.',
        ),
      ),
      Row(
        children: [
          OutlinedButton(
            key: const Key('pin-enroll-change-button'),
            onPressed: () => setState(() {
              _editingOpen = true;
              _error = null;
              _notice = null;
            }),
            child: const Text('Cambiar PIN'),
          ),
          const SizedBox(width: 8),
          HyperlinkButton(
            key: const Key('pin-enroll-remove-button'),
            onPressed: _busy ? null : _confirmRemove,
            child: const Text('Quitar PIN'),
          ),
        ],
      ),
    ],
  );

  Widget _form(
    BuildContext context, {
    required PinCredentialStore store,
    required String scopeKey,
    required bool enrolled,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        enrolled
            ? 'Define un nuevo PIN de acceso rápido a Ventas en este '
                  'dispositivo.'
            : 'Configura un PIN de acceso rápido a Ventas en este '
                  'dispositivo. No sustituye tu usuario y contraseña ni '
                  'añade permisos.',
      ),
      const SizedBox(height: 8),
      InfoLabel(
        label: 'Nuevo PIN',
        child: TextBox(
          key: const Key('pin-enroll-new-field'),
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: kSellerPinLength,
        ),
      ),
      const SizedBox(height: 8),
      InfoLabel(
        label: 'Confirmar PIN',
        child: TextBox(
          key: const Key('pin-enroll-confirm-field'),
          controller: _confirmController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: kSellerPinLength,
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            _error!,
            key: const Key('pin-enroll-error'),
            style: TextStyle(color: FluentTheme.of(context).resources.systemFillColorCritical),
          ),
        ),
      Row(
        children: [
          FilledButton(
            key: const Key('pin-enroll-submit'),
            onPressed: _busy ? null : () => _submit(store, scopeKey),
            child: Text(_busy ? 'Guardando…' : 'Guardar PIN'),
          ),
          if (enrolled) ...[
            const SizedBox(width: 8),
            HyperlinkButton(
              key: const Key('pin-enroll-cancel'),
              onPressed: _busy ? null : _cancelEditing,
              child: const Text('Cancelar'),
            ),
          ],
        ],
      ),
    ],
  );

  void _cancelEditing() => setState(() {
    _editingOpen = false;
    _error = null;
    _pinController.clear();
    _confirmController.clear();
  });

  Future<void> _submit(PinCredentialStore store, String scopeKey) async {
    final pin = _pinController.text;
    final confirm = _confirmController.text;
    final validation = validateSellerPin(pin);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'Los PIN ingresados no coinciden');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.enroll(scopeKey, pin);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _editingOpen = false;
        _notice = 'PIN guardado.';
        _pinController.clear();
        _confirmController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar el PIN. Intenta nuevamente.';
      });
    }
  }

  Future<void> _confirmRemove() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;
    final store = ref.read(pinCredentialStoreProvider);
    final scopeKey = pinScopeKeyFor(
      profile.serverUrl,
      profile.database,
      profile.login,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Quitar PIN'),
        content: const Text(
          'Ya no podrás entrar directo a Ventas con este PIN desde este '
          'dispositivo.',
        ),
        actions: [
          HyperlinkButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('pin-enroll-remove-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    await store.forget(scopeKey);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _notice = 'PIN eliminado.';
    });
  }
}
