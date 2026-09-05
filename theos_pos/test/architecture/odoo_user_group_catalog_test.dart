import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';

void main() {
  test('functional authorization groups belong to the synced catalog', () {
    expect(
      kKnownTheosUserGroups.toSet(),
      containsAll(<String>{
        OdooUserGroup.creditApprover,
        OdooUserGroup.saleConfirm,
        OdooUserGroup.allowDeleteRecords,
        OdooUserGroup.saleDelete,
      }),
    );
    expect(kKnownTheosUserGroups.toSet().length, kKnownTheosUserGroups.length);
  });

  test('production code declares group XML IDs only in OdooUserGroup', () {
    final packageRoot = Directory.current.path.endsWith('theos_pos')
        ? Directory.current
        : Directory('theos_pos');
    final libDirectory = Directory('${packageRoot.path}/lib');
    final catalogPath = File(
      '${libDirectory.path}/shared/constants/user_groups.dart',
    ).absolute.path;
    final xmlIdLiteral = RegExp(
      r'''(['"])([a-zA-Z0-9_]+\.group_[a-zA-Z0-9_]+)\1''',
    );
    final violations = <String>[];

    for (final entity in libDirectory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.absolute.path == catalogPath) continue;
      final contents = entity.readAsStringSync();
      for (final match in xmlIdLiteral.allMatches(contents)) {
        violations.add(
          '${entity.path}:${_lineNumber(contents, match.start)} '
          '${match.group(2)}',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Declare every production group XML ID in OdooUserGroup and use the '
          'constant from consumers:\n${violations.join('\n')}',
    );
  });
}

int _lineNumber(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length + 1;
