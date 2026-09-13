import 'package:fluent_ui/fluent_ui.dart';

/// Tarjeta del cliente seleccionado, como la de theos_pos
/// (`theos_pos/lib/shared/widgets/reactive/reactive_partner_card.dart`), pero
/// con un avatar de inicial en vez de la foto real del contacto: el borrador
/// de Orbi no trae `avatar128`.
///
/// `SaleCatalogPartner` (`theos_pos_core/lib/src/services/sales/sale_draft_repository.dart`)
/// sólo tiene nombre, RUC/cédula (`vat`) y correo — no hay dirección ni
/// teléfono en ningún punto del borrador de Orbi. Por eso esta tarjeta sólo
/// pinta lo que de verdad tiene: nunca un dato inventado.
class SaleClientSummaryCard extends StatelessWidget {
  const SaleClientSummaryCard({
    super.key,
    required this.name,
    this.vat,
    this.email,
  });

  final String name;
  final String? vat;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final displayName = name.trim().isEmpty ? 'Cliente pendiente' : name.trim();
    final initial = displayName.substring(0, 1).toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                initial,
                style: theme.typography.subtitle?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(displayName, style: theme.typography.bodyStrong),
                  if (vat != null && vat!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.contact_card, size: 14),
                        const SizedBox(width: 6),
                        Text(vat!),
                      ],
                    ),
                  ],
                  if (email != null && email!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(FluentIcons.mail, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            email!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
