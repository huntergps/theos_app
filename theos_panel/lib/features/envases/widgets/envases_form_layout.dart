import 'package:fluent_ui/fluent_ui.dart';

/// Ancho a partir del cual escritorio/iPad horizontal dejan de apilar los
/// campos y las líneas pasan de tarjeta a tabla — el mismo corte que ya usa
/// `OrbiForm` (`odoo_widgets/lib/src/listing/orbi_form.dart`).
const double kEnvasesDesktopBreakpoint = 900;

/// Ancho máximo del contenido de un formulario de envases. Sin esto, un
/// formulario de pocos campos se estira a los 1.900 px de una pantalla de
/// escritorio y dos campos angostos terminan pegados a cada extremo con un
/// vacío enorme entre ellos — el defecto reportado el 14-sep-2026.
class EnvasesFormWidth extends StatelessWidget {
  const EnvasesFormWidth({super.key, required this.child, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

/// Un campo con su etiqueta encima, igual que `OrbiField`
/// (`odoo_widgets/lib/src/listing/orbi_form.dart`) — pero sin que
/// `OrbiFormSection` le imponga la mitad del ancho disponible. Ese reparto a
/// dos mitades es lo que separaba «Sede de origen» y «Sede de destino» a los
/// dos extremos de la pantalla: cada combo mide ~150 px, pero `OrbiForm` le
/// daba una caja de ~950 px y lo dejaba pegado a la izquierda de ella.
class EnvasesField extends StatelessWidget {
  const EnvasesField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
    this.required = false,
    this.error,
  });

  final String label;
  final Widget child;
  final String? hint;
  final bool required;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: Text(label, style: theme.typography.bodyStrong)),
            if (required)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    color: theme.resources.systemFillColorCritical,
                    fontWeight: FontWeight.bold,
                  ),
                  semanticsLabel: 'obligatorio',
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        child,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error!,
              style: theme.typography.caption?.copyWith(color: theme.resources.systemFillColorCritical),
            ),
          )
        else if (hint != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: theme.typography.caption)),
      ],
    );
  }
}

/// Una etiqueta con un valor de sólo lectura — el mismo bloque visual que
/// [EnvasesField], pero para datos que la pantalla informa (encabezado de
/// una recepción), no que el usuario llena.
class EnvasesInfoField extends StatelessWidget {
  const EnvasesInfoField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: typography.caption),
        const SizedBox(height: 2),
        Text(value, style: typography.bodyStrong),
      ],
    );
  }
}

/// Un campo dentro de [EnvasesFieldsRow]: el widget y el ancho que ocupa en
/// escritorio. En teléfono/tableta vertical ese ancho se ignora y el campo
/// pasa a ocupar todo el ancho disponible, apilado con los demás.
class EnvasesFieldSlot {
  const EnvasesFieldSlot({required this.field, this.width = 260});

  final Widget field;
  final double width;
}

/// Datos generales de un formulario: una FILA de campos de ancho fijo en
/// escritorio/iPad horizontal, apilados a todo el ancho en teléfono. Esto
/// reemplaza el reparto a dos mitades de `OrbiFormSection` para este bloque
/// concreto — ver el docstring de [EnvasesField].
class EnvasesFieldsRow extends StatelessWidget {
  const EnvasesFieldsRow({super.key, required this.slots, this.breakpoint = kEnvasesDesktopBreakpoint});

  final List<EnvasesFieldSlot> slots;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= breakpoint;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final slot in slots) Padding(padding: const EdgeInsets.only(bottom: 16), child: slot.field),
            ],
          );
        }
        return Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            for (final slot in slots) SizedBox(width: slot.width, child: slot.field),
          ],
        );
      },
    );
  }
}
