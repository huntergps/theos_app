import 'dart:io';
import 'package:flutter_qweb/flutter_qweb.dart';

void main() async {
  // Create the QWeb report engine
  final engine = QWebReportEngine();

  // Define a QWeb template
  const template = '''
    <div>
      <h1><t t-esc="doc.name"/></h1>

      <div>
        <p><strong>Customer:</strong> <t t-esc="doc.customer.name"/></p>
        <p><strong>Date:</strong> <t t-esc="doc.date"/></p>
      </div>

      <h2>Order Lines</h2>
      <table>
        <thead>
          <tr>
            <th>Product</th>
            <th class="text-center">Quantity</th>
            <th class="text-right">Unit Price</th>
            <th class="text-right">Subtotal</th>
          </tr>
        </thead>
        <tbody>
          <t t-foreach="doc.lines" t-as="line">
            <tr>
              <td><t t-esc="line.product"/></td>
              <td class="text-center"><t t-esc="line.quantity"/></td>
              <td class="text-right">\$ <t t-esc="line.price"/></td>
              <td class="text-right">\$ <t t-esc="line.subtotal"/></td>
            </tr>
          </t>
        </tbody>
      </table>

      <div>
        <p><strong>Subtotal:</strong> \$ <t t-esc="doc.subtotal"/></p>
        <p><strong>Tax (12%):</strong> \$ <t t-esc="doc.tax"/></p>
        <hr/>
        <p><strong>TOTAL:</strong> \$ <t t-esc="doc.total"/></p>
      </div>

      <t t-if="doc.notes">
        <h3>Notes</h3>
        <p><t t-esc="doc.notes"/></p>
      </t>
    </div>
  ''';

  // Define the data
  final data = {
    'doc': {
      'name': 'Sales Order SO-2024-001',
      'date': '2024-12-13',
      'customer': {
        'name': 'Acme Corporation',
        'email': 'orders@acme.com',
      },
      'lines': [
        {
          'product': 'Widget Pro',
          'quantity': 10,
          'price': 99.99,
          'subtotal': 999.90,
        },
        {
          'product': 'Gadget Plus',
          'quantity': 5,
          'price': 149.50,
          'subtotal': 747.50,
        },
        {
          'product': 'Tool Basic',
          'quantity': 20,
          'price': 25.00,
          'subtotal': 500.00,
        },
      ],
      'subtotal': 2247.40,
      'tax': 269.69,
      'total': 2517.09,
      'notes': 'Please deliver to warehouse entrance.',
    },
  };

  // Define company info
  final company = CompanyInfo(
    name: 'My Company Inc.',
    vat: '1234567890001',
    street: '123 Business Ave',
    city: 'Quito',
    country: 'Ecuador',
    phone: '+593 2 123 4567',
    email: 'info@mycompany.com',
    website: 'www.mycompany.com',
  );

  // Render to PDF
  final pdfBytes = await engine.renderToPdf(
    xml: template,
    data: data,
    company: company,
    options: RenderOptions(
      title: 'Sales Order Report',
      author: 'My Company Inc.',
    ),
  );

  // Save to file
  final file = File('example_output.pdf');
  await file.writeAsBytes(pdfBytes);
  print('PDF generated: ${file.path}');
}
