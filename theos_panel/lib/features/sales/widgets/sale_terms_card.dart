import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

/// theos_pos muestra los términos y condiciones (campo `html` de Odoo) tal
/// cual llegan, sin limpiar — `<p>...</p>` literal en pantalla (ver
/// `theos_pos/lib/features/sales/screens/sale_order_form/form_sections.dart`,
/// `FormSection5Notes`, y `OdooMultilineField.buildViewMode`, que hace un
/// `Text(effectiveValue!)` directo). No hay ningún limpiador de HTML en el
/// monorepo — se buscó en los siete paquetes — así que este es el primero.
/// Sólo quita etiquetas y desescapa entidades comunes; no interpreta ni
/// renderiza el HTML.
String stripHtmlTags(String html) {
  final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  final unescaped = withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return unescaped.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Tarjeta de "Términos y condiciones", como `FormSection5Notes` de
/// theos_pos, reutilizando el mismo `OdooMultilineField` de `odoo_widgets`
/// — sólo que aquí el valor ya llega limpio de etiquetas.
class SaleTermsCard extends StatelessWidget {
  const SaleTermsCard({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: OdooMultilineField(
        config: const OdooFieldConfig(
          label: 'Términos y condiciones',
          prefixIcon: FluentIcons.quick_note,
        ),
        value: stripHtmlTags(html),
        maxLines: 4,
        minLines: 3,
      ),
    ),
  );
}
