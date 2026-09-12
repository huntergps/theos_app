import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import '../../dev/orbi_design_preview.dart';

void main() {
  testWidgets('Orbi preview lays out at expanded and compact widths', (
    tester,
  ) async {
    for (final size in [const Size(1440, 900), const Size(390, 844)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const OrbiDesignPreviewApp());
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'layout failed at $size');
    }
  });
}
