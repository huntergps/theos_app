import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../app/theme/orbi_theme.dart';

/// 🔴 Predecesor de `OrbiPage` (`ui/fluent/orbi_page.dart`), que es el marco
/// que deben usar las pantallas nuevas. Este widget se conserva porque varias
/// pantallas de `features/` todavía lo llaman y esta conversión no cambia su
/// API pública — sólo lo que dibuja por dentro. Migrarlas a `OrbiPage` es
/// trabajo de quien convierta cada pantalla, no de este encargo.
class OrbiPageShell extends StatelessWidget {
  const OrbiPageShell({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: ScaffoldPage(
        header: PageHeader(
          title: Text(title),
          commandBar: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...(actions ?? const <Widget>[]),
              Tooltip(
                message: 'Inicio',
                child: IconButton(
                  key: const Key('home-button'),
                  icon: const Icon(FluentIcons.home),
                  onPressed: () => context.go('/'),
                ),
              ),
            ],
          ),
        ),
        content: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: const EdgeInsets.all(OrbiTheme.space16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Insignia de estado con texto. Fluent no trae `Chip`: la forma no importa
/// (el dueño ya lo resolvió, no hace falta que sea redondo), así que esto es
/// un contenedor propio con borde e icono, no un control de fábrica.
class OrbiStatusChip extends StatelessWidget {
  const OrbiStatusChip({
    super.key,
    required this.label,
    this.icon = FluentIcons.info,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.resources.subtleFillColorSecondary,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          border: Border.all(color: theme.resources.controlStrokeColorDefault),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 16)),
              const SizedBox(width: 6),
              // `Flexible`, no un `Text` suelto: en toda pantalla real este
              // chip vive dentro de un `Wrap` o como hermano de un
              // `Expanded` en un `Row` — nunca se le fuerza un ancho menor
              // al que su contenido pide. Pero un `ListView` (como la
              // galería de desarrollo) sí le da un ancho fijo y angosto a
              // cada item, y a escala de texto 2x (accesibilidad) una
              // etiqueta larga desborda el `Row` sin esto. Con `Flexible` +
              // elipsis, la etiqueta normal se sigue viendo entera — sólo se
              // recorta en esa combinación extrema de ancho angosto y texto
              // grande.
              Flexible(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: theme.typography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrbiEmptyState extends StatelessWidget {
  const OrbiEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Center(
      child: Semantics(
        container: true,
        label: '$title. $message',
        child: Padding(
          padding: const EdgeInsets.all(OrbiTheme.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.inbox, size: 48),
              const SizedBox(height: OrbiTheme.space12),
              Text(
                title,
                style: typography.subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: OrbiTheme.space8),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: OrbiTheme.space16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OrbiErrorState extends StatelessWidget {
  const OrbiErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: 'Error. $message',
        child: Padding(
          padding: const EdgeInsets.all(OrbiTheme.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.error_badge,
                size: 48,
                color: theme.resources.systemFillColorCritical,
              ),
              const SizedBox(height: OrbiTheme.space12),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: OrbiTheme.space16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.refresh),
                      SizedBox(width: 8),
                      Text('Reintentar'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Adapter for a reactive form control owned by the screen/controller.
/// The control is deliberately injected, so rebuilding or resizing the widget
/// never recreates the form state.
///
/// Rebuilt directly on [ReactiveFormField] (the base every other reactive
/// widget in the package extends) instead of on `reactive_forms`'s own
/// `ReactiveTextField`, which renders a Material `TextField` internally and
/// has no Fluent equivalent.
class OrbiReactiveTextField extends StatelessWidget {
  const OrbiReactiveTextField({
    super.key,
    required this.control,
    required this.label,
    this.hintText,
  });

  final FormControl<String> control;
  final String label;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return ReactiveFormField<String, String>(
      formControl: control,
      builder: (field) =>
          _ReactiveTextBoxBody(field: field, label: label, hintText: hintText),
    );
  }
}

class _ReactiveTextBoxBody extends StatefulWidget {
  const _ReactiveTextBoxBody({
    required this.field,
    required this.label,
    this.hintText,
  });

  final ReactiveFormFieldState<String, String> field;
  final String label;
  final String? hintText;

  @override
  State<_ReactiveTextBoxBody> createState() => _ReactiveTextBoxBodyState();
}

class _ReactiveTextBoxBodyState extends State<_ReactiveTextBoxBody> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.field.value ?? '',
  );

  @override
  void didUpdateWidget(covariant _ReactiveTextBoxBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.field.value ?? '';
    if (_controller.text != value) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `TextFormBox` (no un `TextBox` + `Text` rojo a mano): mete el error en
    // un `FormRow` y, cuando hay error, pinta el borde en rojo con
    // `highlightColor` crítico (ver `TextFormBox` en fluent_ui). El
    // `validator` sólo reexpone `field.errorText` — la validación en sí sigue
    // viviendo en el `FormControl` de `reactive_forms` — y
    // `AutovalidateMode.always` hace que `TextFormBox` vuelva a leerlo en
    // cada build de este widget, que es lo que dispara cuando el control
    // cambia.
    return InfoLabel(
      label: widget.label,
      child: TextFormBox(
        controller: _controller,
        placeholder: widget.hintText,
        enabled: widget.field.control.enabled,
        onChanged: widget.field.didChange,
        autovalidateMode: AutovalidateMode.always,
        validator: (_) => widget.field.errorText,
      ),
    );
  }
}

class OrbiActionCard extends StatelessWidget {
  const OrbiActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.icon = FluentIcons.forward,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final typography = theme.typography;
    // `HoverButton` (no `GestureDetector` + `MouseRegion` a mano): trae hover,
    // pulsación, foco y activación por teclado (Enter/Espacio) de fábrica —
    // `Card` no es interactivo por sí solo. El tinte de fondo en hover/pulsado
    // sale de `ButtonThemeData.uncheckedInputColor`, el mismo helper que usa
    // `ListTile`/`Expander` en fluent_ui; en reposo es transparente y el
    // `Card` se ve exactamente igual que antes.
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '$title. $subtitle',
      child: HoverButton(
        onPressed: onPressed,
        cursor: SystemMouseCursors.click,
        builder: (context, states) => FocusBorder(
          focused: states.isFocused,
          renderOutside: false,
          child: Card(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            padding: const EdgeInsets.all(OrbiTheme.space16),
            backgroundColor: Color.alphaBlend(
              ButtonThemeData.uncheckedInputColor(
                theme,
                states,
                transparentWhenNone: true,
              ),
              theme.cardColor,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: typography.bodyStrong),
                      const SizedBox(height: OrbiTheme.space4),
                      Text(subtitle),
                    ],
                  ),
                ),
                Icon(icon, size: 24, semanticLabel: ''),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
