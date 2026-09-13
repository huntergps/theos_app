import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/auth/capability_runtime.dart';

void main() {
  test(
    'does not grant the supervisor overview without the manager group',
    () {
      expect(
        OdooCapabilityReader.hasCollectionSupervisor(
          const ['l10n_ec_collection_box.group_collection_user'],
        ),
        isFalse,
        reason: 'Cajero (group_collection_user) no es Supervisor de Caja',
      );
      expect(
        OdooCapabilityReader.hasCollectionSupervisor(const []),
        isFalse,
      );
    },
  );

  test('grants the supervisor overview for the real Odoo group', () {
    expect(
      OdooCapabilityReader.hasCollectionSupervisor(
        const ['l10n_ec_collection_box.group_collection_manager'],
      ),
      isTrue,
    );
  });

  test('does not infer supervision from an unrelated accounting group', () {
    expect(
      OdooCapabilityReader.hasCollectionSupervisor(
        const ['account.group_account_manager'],
      ),
      isFalse,
      reason:
          'account.group_account_manager IMPLICA a Supervisor de Caja '
          '(collection_box_groups.xml:274-276), pero la implicación la '
          'expande Odoo en all_group_ids/get_external_id antes de llegar '
          'aquí — este chequeo no debe repetir esa herencia por su cuenta.',
    );
  });
}
