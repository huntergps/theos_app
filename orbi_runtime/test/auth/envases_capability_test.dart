import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/auth/capability_runtime.dart';

void main() {
  test(
    'does not grant Envases read without either effective Envases group',
    () {
      expect(
        OdooCapabilityReader.hasEnvasesRead(const ['stock.group_stock_user']),
        isFalse,
      );
      expect(OdooCapabilityReader.hasEnvasesRead(const []), isFalse);
    },
  );

  test('grants Envases read for the verified user or manager group', () {
    expect(
      OdooCapabilityReader.hasEnvasesRead(const [
        OdooCapabilityReader.envasesUserGroup,
      ]),
      isTrue,
    );
    expect(
      OdooCapabilityReader.hasEnvasesRead(const [
        OdooCapabilityReader.envasesManagerGroup,
      ]),
      isTrue,
    );
  });

  test('does not infer access from unrelated admin or warehouse groups', () {
    expect(
      OdooCapabilityReader.hasEnvasesRead(const [
        'base.group_system',
        'stock.group_stock_manager',
      ]),
      isFalse,
    );
  });

  test('grants Envases manage only to the manager group', () {
    expect(
      OdooCapabilityReader.hasEnvasesManage(const [
        OdooCapabilityReader.envasesManagerGroup,
      ]),
      isTrue,
    );
  });

  test('does not grant Envases manage to the plain user group', () {
    expect(
      OdooCapabilityReader.hasEnvasesManage(const [
        OdooCapabilityReader.envasesUserGroup,
      ]),
      isFalse,
    );
    expect(OdooCapabilityReader.hasEnvasesManage(const []), isFalse);
  });

  // `group_envases_custodia` (Saldo por tercero) is a group of its own: it
  // does NOT imply, and is not implied by, `group_envases_user` (see
  // `l10n_ec_stock_envases/security/envases_security.xml`). A custodian
  // without the basic Envases group must still reach the balance screen.
  test('grants Envases custodia only for the custody group', () {
    expect(
      OdooCapabilityReader.hasEnvasesCustodia(const [
        OdooCapabilityReader.envasesCustodiaGroup,
      ]),
      isTrue,
    );
  });

  test('does not grant Envases custodia to the plain user group', () {
    expect(
      OdooCapabilityReader.hasEnvasesCustodia(const [
        OdooCapabilityReader.envasesUserGroup,
      ]),
      isFalse,
    );
    expect(OdooCapabilityReader.hasEnvasesCustodia(const []), isFalse);
  });
}
