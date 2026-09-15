import 'package:fluent_ui/fluent_ui.dart';

/// Ancho a partir del cual escritorio/iPad horizontal dejan de apilar los
/// campos y las líneas pasan de tarjeta a tabla — el mismo corte que ya usa
/// `OrbiForm` (`odoo_widgets/lib/src/listing/orbi_form.dart`).
const double kEnvasesDesktopBreakpoint = 900;

/// El `DatePicker` de fluent_ui con la misma apariencia de campo que
/// `TextBox`/`ComboBox` — sin pintar un borde inventado, tomando prestado
/// el mismo token de color que usa `TextBox` internamente.
///
/// 🔴 Causa raíz medida el 14-sep-2026: el `DatePicker` de fluent_ui NO
/// dibuja un borde como el de `TextBox`. Su decoración por omisión
/// (`kPickerDecorationBuilder` en `package:fluent_ui`) usa
/// `theme.inactiveColor.withValues(alpha: 0.2)` con un ancho de **0.15px**
/// — prácticamente invisible —, mientras que `TextBox` dibuja
/// `Border.all(color: theme.resources.controlStrokeColorDefault)` a 1px.
/// `DatePicker` no expone un parámetro `decoration` como `TextBox` para
/// sobrescribir eso por instancia, así que la única forma de emparejarlo
/// sin tocar el tema global de la app (que usaría `inactiveColor` en botones,
/// casillas y otros controles) es envolverlo con el mismo token de borde que
/// ya usa `TextBox` — no un color inventado a mano.
class EnvasesDateField extends StatelessWidget {
  const EnvasesDateField({super.key, required this.selected, this.onChanged, this.datePickerKey});

  final DateTime? selected;
  final ValueChanged<DateTime>? onChanged;

  /// La `Key` del `DatePicker` interno — los tests y el resto de la app
  /// buscan el picker por esta clave, no por la del envoltorio.
  final Key? datePickerKey;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: DatePicker(key: datePickerKey, selected: selected, onChanged: onChanged),
    );
  }
}

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

/// Arma el cuerpo de un formulario de envases junto con su barra de
/// acciones (`EnvasesFormActions`), resolviendo dónde va cada uno según el
/// ancho — sin que cada formulario repita esta decisión.
///
/// 🔴 Causa raíz de la barra pegada al FONDO de la ventana (queja del dueño,
/// 14-sep-2026), medida contra `b31b3b9`: los dos formularios envolvían el
/// cuerpo en `Expanded(child: SingleChildScrollView(...))` dentro de un
/// `Column` que también tenía las acciones como último hijo. Un `Expanded`
/// se estira para llenar TODO el espacio vertical que le sobra a su
/// `Column` — con poco contenido, eso empuja las acciones a los ~1.040 px
/// de una pantalla de 1.080, lejísimos del total/resumen que las precede.
///
/// En escritorio/iPad horizontal, las acciones van DENTRO del mismo
/// `SingleChildScrollView` que el cuerpo, justo debajo — se desplazan juntos
/// y, con poco contenido, las acciones quedan pegadas al cuerpo, no al
/// fondo. En teléfono/tableta vertical, la acción principal sigue fija al
/// pie (lo que pide el diseño aprobado para esos anchos): el cuerpo lleva
/// relleno inferior de sobra para que el botón fijo nunca tape ni «Agregar
/// envase» ni la última tarjeta.
class EnvasesFormScaffold extends StatelessWidget {
  const EnvasesFormScaffold({super.key, required this.body, required this.actions});

  final Widget body;
  final Widget actions;

  /// Alto reservado al pie en teléfono/tableta vertical: la barra de
  /// acciones fija (ayuda + botón, y a veces «Cancelar» debajo) mide menos
  /// que esto incluso con las tres líneas a la vez — de sobra para que
  /// nunca tape el contenido que se desplaza por debajo.
  static const double _phoneBottomClearance = 160;

  @override
  Widget build(BuildContext context) {
    return EnvasesFormWidth(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= kEnvasesDesktopBreakpoint;
          if (isWide) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [body, const SizedBox(height: 24), actions],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: _phoneBottomClearance),
                  child: body,
                ),
              ),
              actions,
            ],
          );
        },
      ),
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
