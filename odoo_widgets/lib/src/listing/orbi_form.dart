import 'package:fluent_ui/fluent_ui.dart';

/// Un campo del formulario estándar: su etiqueta, el control y, cuando hace
/// falta, lo que hay que saber para rellenarlo bien.
class OrbiField {
  const OrbiField({
    required this.label,
    required this.child,
    this.hint,
    this.required = false,
    this.error,
    this.span = 1,
  });

  final String label;
  final Widget child;

  /// Una línea que ayuda a rellenarlo. No repite la etiqueta.
  final String? hint;

  final bool required;

  /// Qué está mal, en palabras. Nulo mientras el campo esté bien.
  final String? error;

  /// Cuántas columnas ocupa cuando el formulario va a dos. Un campo largo
  /// —una dirección, una nota— pide las dos.
  final int span;
}

/// Un grupo de campos con su título.
class OrbiFormSection {
  const OrbiFormSection({required this.title, required this.fields});

  final String title;
  final List<OrbiField> fields;
}

/// El formulario estándar, para que todos se parezcan entre sí.
///
/// Por orden del dueño (12-sep-2026): *«los formularios también de manera
/// similar»*. Lo que fija, y es justo lo que se desvía cuando cada pantalla se
/// dibuja sola:
///
/// - **La etiqueta va encima del control, siempre.** Poner unas al lado y
///   otras encima hace que dos formularios del mismo sistema parezcan de
///   sistemas distintos.
/// - Lo obligatorio se marca **en la etiqueta**, antes de escribir, no con un
///   error después de intentar guardar.
/// - Dos columnas cuando la ventana da, una sola cuando no. Un formulario de
///   dos columnas en un teléfono se lee en zigzag.
/// - El error del campo va **pegado al campo**, no en un aviso arriba que
///   obliga a adivinar cuál falló.
class OrbiForm extends StatelessWidget {
  const OrbiForm({
    super.key,
    required this.sections,
    this.actions,
    this.twoColumnBreakpoint = 840,
  });

  final List<OrbiFormSection> sections;

  /// La barra de acciones, normalmente un [Row] con cancelar y confirmar.
  final Widget? actions;

  /// A partir de este ancho el formulario va a dos columnas. Coincide con el
  /// corte medio que ya usa el resto de la aplicación.
  final double twoColumnBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= twoColumnBreakpoint ? 2 : 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final section in sections)
                      _Section(section: section, columns: columns),
                  ],
                ),
              ),
            ),
            if (actions != null)
              Padding(padding: const EdgeInsets.only(top: 16), child: actions),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, required this.columns});

  final OrbiFormSection section;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: typography.subtitle),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 16.0;
              final unit = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final field in section.fields)
                    SizedBox(
                      width: field.span >= 2 || columns == 1
                          ? constraints.maxWidth
                          : unit,
                      child: _Field(field: field),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.field});

  final OrbiField field;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(field.label, style: theme.typography.bodyStrong),
            if (field.required)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '*',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  semanticsLabel: 'obligatorio',
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        field.child,
        if (field.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              field.error!,
              style: theme.typography.caption?.copyWith(color: Colors.red),
            ),
          )
        else if (field.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(field.hint!, style: theme.typography.caption),
          ),
      ],
    );
  }
}
