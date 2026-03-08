import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:flutter_qweb/src/qweb_report_engine.dart';

void main() {
  group('QWebReportEngine', () {
    late QWebReportEngine engine;

    setUp(() {
      engine = QWebReportEngine();
    });

    test('should render simple XML to PDF bytes', () async {
      const xml = '''
        <t t-name="test_report">
          <div>
            <h1>Hello World</h1>
            <p><t t-esc="doc.name"/></p>
          </div>
        </t>
      ''';

      final data = {
        'doc': {'name': 'Test Document'}
      };

      final pdfBytes = await engine.renderToPdf(xml: xml, data: data);

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));

      // Basic PDF header verification
      // PDF files start with %PDF-
      expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');
    });

    test('should register and retrieve templates', () {
      const name = 'my.template';
      const xml = '<div>Test</div>';

      engine.registerTemplate(name, xml);

      expect(engine.hasTemplate(name), isTrue);
      expect(engine.hasTemplate('non_existent'), isFalse);
    });

    test('should support t-call to render other templates', () async {
      // Register sub-template
      engine.registerTemplate('sub.template', '<div>Sub Content</div>');

      // Main template calling sub-template
      const xml = '''
        <t t-name="main.template">
           <div>Header</div>
           <t t-call="sub.template"/>
           <div>Footer</div>
        </t>
      ''';

      final pdfBytes = await engine.renderToPdf(xml: xml, data: {});
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));
    });

    test('should ignore script and style tags', () async {
      const xml = '''
        <t t-name="clean.template">
           <script>console.log("ignore me");</script>
           <style>body { color: red; }</style>
           <div>Visible Content</div>
        </t>
      ''';

      // We can't easily check content of PDF bytes here without a PDF parser,
      // but we can ensure it renders without error.
      // Manual verification or integration test would be better for content check.
      final pdfBytes = await engine.renderToPdf(xml: xml, data: {});
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));
    });

    test('should support t-call body injection (t-out="0")', () async {
      engine.registerTemplate('wrapper.template', '''
        <div>
          <h1>Wrapper Header</h1>
          <div class="content">
            <t t-out="0"/>
          </div>
          <footer>Wrapper Footer</footer>
        </div>
      ''');

      const xml = '''
        <t t-name="main.template">
           <t t-call="wrapper.template">
             <p>Injected Content</p>
           </t>
        </t>
      ''';

      final pdfBytes = await engine.renderToPdf(xml: xml, data: {});
      expect(pdfBytes, isA<Uint8List>());
    });
    test('should support nested t-call body injection without stack overflow',
        () async {
      engine.registerTemplate('wrapper.template', '''
        <div>
          <t t-out="0"/>
        </div>
      ''');

      const xml = '''
        <t t-name="main.template">
           <t t-call="wrapper.template">
              <t t-call="wrapper.template">
                 <p>Deep Content</p>
              </t>
           </t>
        </t>
      ''';

      final pdfBytes = await engine.renderToPdf(xml: xml, data: {});
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));
    });

    test('should support bootstrap layout and styling', () async {
      const xml = '''
        <t t-name="grid.template">
           <div class="row">
               <div class="col-6">Left Column</div>
               <div class="col-6 text-end fw-bold">Right Column</div>
           </div>
           <p class="text-center text-muted">Centered Footer</p>
           <div class="d-none">Hidden</div>
        </t>
      ''';

      final pdfBytes = await engine.renderToPdf(xml: xml, data: {});
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(0));
    });
  });
}
