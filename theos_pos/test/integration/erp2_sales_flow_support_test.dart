import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';

import '../../integration_test/support/erp2_sales_flow_support.dart';

void main() {
  test('flow stage parser accepts only the three isolated stages', () {
    expect(parseErp2FlowStage('seller'), 'seller');
    expect(parseErp2FlowStage(' CASHIER '), 'cashier');
    expect(parseErp2FlowStage('approver'), 'approver');
    expect(parseErp2FlowStage(''), isEmpty);
    expect(parseErp2FlowStage('administrator'), isEmpty);
  });

  test('stage actor gate binds ERP2 users and minimum groups', () {
    expect(
      () => validateErp2StageActor(
        stage: 'seller',
        userId: 43,
        configuredApproverUserId: 99,
        permissions: const [OdooUserGroup.salesUser],
      ),
      returnsNormally,
    );
    expect(
      () => validateErp2StageActor(
        stage: 'cashier',
        userId: 23,
        configuredApproverUserId: 99,
        permissions: const [OdooUserGroup.collectionUser],
      ),
      returnsNormally,
    );
    expect(
      () => validateErp2StageActor(
        stage: 'approver',
        userId: 99,
        configuredApproverUserId: 99,
        permissions: const [OdooUserGroup.creditApprover],
      ),
      returnsNormally,
    );
    expect(
      () => validateErp2StageActor(
        stage: 'cashier',
        userId: 43,
        configuredApproverUserId: 99,
        permissions: const [OdooUserGroup.collectionUser],
      ),
      throwsStateError,
    );
    expect(
      () => validateErp2StageActor(
        stage: 'seller',
        userId: 43,
        configuredApproverUserId: 99,
        permissions: const [OdooUserGroup.collectionUser],
      ),
      throwsStateError,
    );
  });
}
