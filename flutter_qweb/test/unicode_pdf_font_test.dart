import 'dart:convert';

import 'package:flutter_qweb/flutter_qweb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default PDF font embeds Unicode mappings for Spanish text', () async {
    const spanishText =
        'Cotización: pingüino, acción, información, año, ¿qué tal? ¡Éxito! €';

    final bytes = await renderQWebToPdf(
      xml: '''
        <div>
          <p><t t-out="title"/></p>
          <strong><t t-out="title"/></strong>
          <em><t t-out="title"/></em>
        </div>
      ''',
      data: const {'title': spanishText},
      options: const RenderOptions(includeHeader: false, includeFooter: false),
    );

    final pdfSource = latin1.decode(bytes, allowInvalid: true);

    expect(bytes, isNotEmpty);
    expect(pdfSource, contains('/ToUnicode'));
    expect(pdfSource, isNot(contains('/BaseFont /Helvetica')));
  });
}
