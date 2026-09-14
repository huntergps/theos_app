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
}
