import 'package:odoo_sdk/odoo_sdk.dart';

/// Checks the child schema instead of assuming the parent's discriminator exists.
/// Keep the durable payload intact: discovery and adaptation happen at replay.
Future<List<dynamic>> adaptPaymentWizardCommands(
  OdooClient client,
  List<dynamic> commands,
) async {
  if (commands.isEmpty) return commands;
  final hasLineType = await client.hasField(
    'l10n_ec_collection_box.sale.order.payment.wizard.line',
    'line_type',
  );
  return commands
      .map((raw) {
        if (raw is! List || raw.length != 3 || raw[2] is! Map) {
          throw StateError('Invalid payment wizard line command');
        }
        final values = Map<String, dynamic>.from(raw[2] as Map);
        if (!hasLineType) values.remove('line_type');
        return [raw[0], raw[1], values];
      })
      .toList(growable: false);
}
