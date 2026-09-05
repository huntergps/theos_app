import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageRoot = Directory.current.path.endsWith('theos_pos')
      ? Directory.current
      : Directory('theos_pos');

  String read(String relativePath) =>
      File('${packageRoot.path}/$relativePath').readAsStringSync();

  test('Web bootstraps a self-hosted patched PDF.js under strict CSP', () {
    final index = read('web/index.html');
    final bootstrap = read('web/app_bootstrap.js');
    final workflow = File(
      '${packageRoot.parent.path}/.github/workflows/deploy-web.yml',
    ).readAsStringSync();
    final pdfModule = File(
      '${packageRoot.path}/web/pdfjs/4.10.38/build/pdf.min.mjs',
    );
    final pdfWorker = File(
      '${packageRoot.path}/web/pdfjs/4.10.38/build/pdf.worker.min.mjs',
    );
    final checksums = read('web/pdfjs/4.10.38/SHA256SUMS');

    expect(index, contains('Content-Security-Policy'));
    expect(index, contains("script-src 'self' 'wasm-unsafe-eval'"));
    expect(index, isNot(contains("script-src 'self' 'unsafe-inline'")));
    expect(index, contains('src="app_bootstrap.js"'));
    expect('$index\n$bootstrap', isNot(contains('cdnjs.cloudflare.com')));
    expect('$index\n$bootstrap', isNot(contains('unpkg.com')));
    expect(bootstrap, contains("pdfjs/4.10.38/build/pdf.min.mjs"));
    expect(bootstrap, contains("pdf.worker.min.mjs"));
    expect(pdfModule.lengthSync(), greaterThan(300000));
    expect(pdfWorker.lengthSync(), greaterThan(1000000));
    expect(checksums, contains('27fc2a057a00f92a4334ad06e17dbd725'));
    expect(checksums, contains('1baa1844c89c80a5b2797c916e75ab29'));
    expect(workflow, contains('--csp'));
    expect(workflow, contains('--no-web-resources-cdn'));
  });

  test(
    'Android production configuration is networked but never debug-signed',
    () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');
      final gradle = read('android/app/build.gradle.kts');
      final example = read('android/key.properties.example');

      expect(manifest, contains('android.permission.INTERNET'));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(gradle, contains('signingConfigs.getByName("release")'));
      expect(example, contains('storeFile='));
      expect(example, contains('keyAlias='));
    },
  );

  test('macOS does not globally disable App Transport Security', () {
    final infoPlist = read('macos/Runner/Info.plist');

    expect(infoPlist, isNot(contains('NSAllowsArbitraryLoads')));
    expect(infoPlist, isNot(contains('NSAppTransportSecurity')));
  });

  test('Android backup rules exclude the effective credential namespace', () {
    const expectedFiles = <String>[
      'theos_pos_credentials.xml',
      'FlutterSecureKeyStorage:theos_pos_credentials.xml',
      'FlutterSecureStorageConfiguration:theos_pos_credentials.xml',
    ];
    final backupRules = read('android/app/src/main/res/xml/backup_rules.xml');
    final extractionRules = read(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    );

    for (final filename in expectedFiles) {
      expect(backupRules, contains(filename));
      expect(extractionRules, contains(filename));
    }
  });

  test('local credential launcher rejects Web and non-debug builds', () {
    final launcher = File(
      '${packageRoot.parent.path}/scripts/run_flutter_with_erp2.sh',
    ).readAsStringSync();
    final serverService = read(
      'lib/features/authentication/services/server_service.dart',
    );

    expect(launcher, contains('chrome|web-server'));
    expect(launcher, contains('--release|--release=*|--profile|--profile=*'));
    expect(
      serverService,
      isNot(contains("String.fromEnvironment('THEOS_ERP2_API_KEY')")),
    );
    expect(serverService, contains('developmentErp2ApiKey'));
  });
}
