import 'package:fluent_ui/fluent_ui.dart';

import 'envases_form_layout.dart';

/// Barra de acciones de un formulario de envases: avisos de error/cola sin
/// conexión, la ayuda de qué falta cuando el botón principal está
/// deshabilitado, y el par cancelar/confirmar.
///
/// En escritorio/iPad horizontal va alineado a la DERECHA del contenido,
/// nunca a todo el ancho — 🔴 la barra gris a todo el ancho, pegada al
/// fondo, de la queja del dueño (14-sep-2026) salía de envolver el
/// `FilledButton` en un `Column` con `crossAxisAlignment: stretch`: un botón
/// de Fluent SÍ se estira para llenar el ancho que le da su padre cuando se
/// lo permiten así. Ahí el `Row` sólo mide lo que miden sus botones —
/// `mainAxisAlignment.end` es lo único que lo empuja a la derecha.
///
/// En teléfono/tableta vertical el botón principal SÍ va a todo el ancho,
/// al pie — eso es lo que pide el diseño aprobado para esos anchos, y aquí
/// sí se logra con `crossAxisAlignment.stretch` a propósito.
class EnvasesFormActions extends StatelessWidget {
  const EnvasesFormActions({
    super.key,
    required this.primaryKey,
    required this.primaryLabel,
    required this.onPrimary,
    required this.saving,
    this.onCancel,
    this.helpText,
    this.errorTitle = 'No se pudo guardar',
    this.error,
    this.notice,
  });

  final Key primaryKey;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final bool saving;
  final VoidCallback? onCancel;

  /// Qué falta para poder confirmar — visible junto al botón mientras esté
  /// deshabilitado, en vez de dejarlo mudo sin explicar por qué.
  final String? helpText;
  final String errorTitle;
  final String? error;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    final ayuda = onPrimary == null && !saving && helpText != null;
    final primaryButton = FilledButton(
      key: primaryKey,
      onPressed: saving ? null : onPrimary,
      child: saving
          ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
          : Text(primaryLabel),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kEnvasesDesktopBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBar(title: Text(errorTitle), content: Text(error!), severity: InfoBarSeverity.error),
              ),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InfoBar(title: Text(notice!), severity: InfoBarSeverity.warning),
              ),
            if (isWide)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (ayuda)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          helpText!,
                          key: const Key('envases-form-ayuda'),
                          style: typography.caption,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  if (onCancel != null) ...[
                    Button(onPressed: saving ? null : onCancel, child: const Text('Cancelar')),
                    const SizedBox(width: 8),
                  ],
                  primaryButton,
                ],
              )
            else ...[
              if (ayuda)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(helpText!, key: const Key('envases-form-ayuda'), style: typography.caption),
                ),
              primaryButton,
              if (onCancel != null) ...[
                const SizedBox(height: 8),
                Button(onPressed: saving ? null : onCancel, child: const Text('Cancelar')),
              ],
            ],
          ],
        );
      },
    );
  }
}
