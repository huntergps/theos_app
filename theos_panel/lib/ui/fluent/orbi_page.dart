import 'package:fluent_ui/fluent_ui.dart';

/// El marco obligatorio de toda pantalla de Orbi.
///
/// 🔴 **Por qué es obligatorio y no una ayuda opcional.** La aplicación madura
/// también usa Fluent y sus quince pantallas repiten el andamiaje a mano; el
/// resultado es que una se quedó sin barra de acciones y el desplazamiento se
/// reparte de dos formas distintas. Está medido en
/// `docs/orbi_panel/reports/ESQUELETO_FLUENT_2026_09_12.md`, Parte II.
/// **La uniformidad no venía en el paquete: la pone quien lo usa.** Por eso
/// aquí ninguna pantalla construye su propia cabecera.
///
/// Lo que fija, y está escrito en `SHELL_AND_INTERACTION_SPEC.md`:
///
/// - El título vive DENTRO del contenido, bajo la barra superior, nunca dentro
///   de ella. Las 39 láminas aprobadas coinciden en esto sin una sola
///   excepción.
/// - Lleva subtítulo de una línea.
/// - **No se muestra el código de pantalla** (`VEN-01` y compañía): es control
///   de calidad de las láminas, no producto.
/// - Las acciones van en una barra que se pliega sola cuando no caben, en vez
///   de recortarse en silencio.
class OrbiPage extends StatelessWidget {
  const OrbiPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.commands = const <CommandBarItem>[],
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final String title;

  /// Una línea que dice de qué va la pantalla. Opcional sólo porque unas pocas
  /// pantallas de detalle no lo necesitan; en un listado se espera.
  final String? subtitle;

  /// Acciones de pantalla. Se pliegan solas al estrechar la ventana: el
  /// recorte silencioso es lo que deja botones inalcanzables en tableta.
  final List<CommandBarItem> commands;

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: ScaffoldPage(
        header: PageHeader(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: typography.title),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: typography.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          commandBar: commands.isEmpty
              ? null
              : CommandBar(
                  mainAxisAlignment: MainAxisAlignment.end,
                  overflowBehavior: CommandBarOverflowBehavior.dynamicOverflow,
                  primaryItems: commands,
                ),
        ),
        content: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// El par cancelar/confirmar, en el único orden que usan las 39 láminas: el
/// secundario con contorno a la izquierda, el primario relleno a la derecha.
///
/// Existe para que nadie tenga que acordarse del orden, que es exactamente
/// como se invierte en una pantalla y nadie lo nota hasta que alguien cancela
/// creyendo que confirma.
class OrbiActionBar extends StatelessWidget {
  const OrbiActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel = 'Cancelar',
    this.onSecondary,
  });

  final String primaryLabel;

  /// Nulo deshabilita la acción. Un primario que no se puede pulsar tiene que
  /// verse deshabilitado, no desaparecer: una pantalla que cambia de forma
  /// según el estado se lee como si faltara algo.
  final VoidCallback? onPrimary;

  final String secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (onSecondary != null) ...[
          Button(onPressed: onSecondary, child: Text(secondaryLabel)),
          const SizedBox(width: 8),
        ],
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
      ],
    );
  }
}
