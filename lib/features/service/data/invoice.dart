import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'tracking.dart';

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

/// GST split of a GST-inclusive [amount] at 18%.
({double taxable, double tax}) gstSplit(double amount) {
  final taxable = amount / 1.18;
  return (taxable: taxable, tax: amount - taxable);
}

/// Builds a GST tax invoice PDF for one shipment.
Future<Uint8List> buildInvoicePdf(Shipment s) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
  );
  final inv = s.invoice;
  final seller = (inv['seller'] as Map?) ?? const {};
  final buyer = (inv['buyer'] as Map?) ?? const {};
  final inter = inv['interState'] == true;
  final date = DateTime.tryParse('${inv['date']}') ?? DateTime.now();
  final g = gstSplit(s.price);
  const brand = PdfColor.fromInt(0xFF3B5BFF);
  const muted = PdfColor.fromInt(0xFF5E6484);
  const line = PdfColor.fromInt(0xFFE4E3F6);

  pw.Widget cell(
    String t, {
    bool b = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      t,
      textAlign: align,
      style: pw.TextStyle(fontSize: 9, font: b ? bold : regular),
    ),
  );
  pw.Widget party(String title, Map m) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 8, color: muted, font: bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${m['name'] ?? ''}',
            style: pw.TextStyle(font: bold, fontSize: 11),
          ),
          if ((m['address'] ?? '').toString().isNotEmpty)
            pw.Text('${m['address']}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text(
            [m['city'], m['state']].whereType<String>().join(', '),
            style: const pw.TextStyle(fontSize: 9),
          ),
          if ((m['gstin'] ?? '').toString().isNotEmpty)
            pw.Text(
              'GSTIN: ${m['gstin']}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          if ((m['phone'] ?? '').toString().isNotEmpty)
            pw.Text(
              'Phone: ${m['phone']}',
              style: const pw.TextStyle(fontSize: 9),
            ),
        ],
      ),
    ),
  );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.RichText(
                    text: pw.TextSpan(
                      children: [
                        pw.TextSpan(
                          text: 'GAME',
                          style: pw.TextStyle(font: bold, fontSize: 24),
                        ),
                        pw.TextSpan(
                          text: 'X',
                          style: pw.TextStyle(
                            font: bold,
                            fontSize: 24,
                            color: brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    'Certified second-hand phones',
                    style: const pw.TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'TAX INVOICE',
                    style: pw.TextStyle(font: bold, fontSize: 16, color: brand),
                  ),
                  pw.Text(
                    'Invoice no: ${inv['number'] ?? s.id}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('d MMM yyyy').format(date)}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    'Order: ${s.id}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              party('SOLD BY', seller),
              pw.SizedBox(width: 10),
              party('BILL & SHIP TO', buyer),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: line),
            columnWidths: const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(0.6),
              3: pw.FlexColumnWidth(1.8),
              4: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF1F0FF),
                ),
                children: [
                  cell('Item', b: true),
                  cell('HSN', b: true),
                  cell('Qty', b: true),
                  cell('Taxable value', b: true, align: pw.TextAlign.right),
                  cell('Total', b: true, align: pw.TextAlign.right),
                ],
              ),
              pw.TableRow(
                children: [
                  cell(
                    '${s.item}\n${s.variant}${inv['imei'] != null ? '\nIMEI ${inv['imei']}' : ''}',
                  ),
                  cell('${inv['hsn'] ?? '8517'}'),
                  cell('1'),
                  cell(_inr.format(g.taxable), align: pw.TextAlign.right),
                  cell(_inr.format(s.price), align: pw.TextAlign.right),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  for (final (l, v) in [
                    ('Taxable value', g.taxable),
                    if (inter)
                      ('IGST @ 18%', g.tax)
                    else ...[
                      ('CGST @ 9%', g.tax / 2),
                      ('SGST @ 9%', g.tax / 2),
                    ],
                  ])
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(l, style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(
                          _inr.format(v),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  pw.Divider(color: line),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Invoice total',
                        style: pw.TextStyle(font: bold, fontSize: 12),
                      ),
                      pw.Text(
                        _inr.format(s.price),
                        style: pw.TextStyle(font: bold, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Place of supply: ${buyer['state'] ?? buyer['city'] ?? '-'}. Prices are inclusive of GST. '
            'Warranty, returns and the GAMEX QC certificate are linked to the IMEI above.',
            style: const pw.TextStyle(fontSize: 8.5, color: muted),
          ),
          pw.Spacer(),
          pw.Divider(color: line),
          pw.Text(
            'This is a computer-generated invoice and does not need a signature. Support: support@gamex.in',
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Opens the system share / save sheet for the invoice.
Future<void> shareInvoice(Shipment s) async {
  final bytes = await buildInvoicePdf(s);
  await Printing.sharePdf(bytes: bytes, filename: 'GAMEX-invoice-${s.id}.pdf');
}
