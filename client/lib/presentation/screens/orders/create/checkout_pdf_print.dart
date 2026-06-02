import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../data/models/bill_config_model.dart';
import '../../../providers/cart_provider.dart';

String _money(double value) => 'Rs.${value.toStringAsFixed(2)}';

String _dateOnly(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';

String _timeOnly(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

pw.TextStyle _style({
  double size = 10,
  bool bold = false,
  PdfColor color = PdfColors.black,
}) {
  return pw.TextStyle(
    fontSize: size,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    color: color,
  );
}

pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.SizedBox(
        width: 92,
        child: pw.Text(
          label,
          textAlign: pw.TextAlign.right,
          style: _style(size: bold ? 12 : 10.5, bold: bold),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.SizedBox(
        width: 72,
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.right,
          style: _style(
            size: bold ? 13 : 10.5,
            bold: bold,
            color: bold ? PdfColors.blue700 : PdfColors.black,
          ),
        ),
      ),
    ],
  );
}

Future<bool> printCheckoutReceiptPdf({
  required BillConfig config,
  required String billDisplay,
  required DateTime dateTime,
  required CartState cartState,
  required double total,
  required double taxableAmount,
  required double cgstAmount,
  required double sgstAmount,
}) async {
  final doc = pw.Document();
  final items = cartState.items.values.toList();
  final taxAmount = cgstAmount + sgstAmount;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(
        80 * PdfPageFormat.mm,
        210 * PdfPageFormat.mm,
        marginAll: 7 * PdfPageFormat.mm,
      ),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (config.orgName.isNotEmpty) ...[
              pw.Text(
                config.orgName,
                textAlign: pw.TextAlign.center,
                style: _style(size: 15, bold: true),
              ),
              pw.SizedBox(height: 4),
            ],
            pw.Text(
              'NEW ORDER',
              textAlign: pw.TextAlign.center,
              style: _style(size: 16, bold: true),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Date: ${_dateOnly(dateTime)}',
              textAlign: pw.TextAlign.center,
              style: _style(size: 12, bold: true),
            ),
            pw.Text(
              'Time: ${_timeOnly(dateTime)}',
              textAlign: pw.TextAlign.center,
              style: _style(size: 12, bold: true),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                pw.SizedBox(
                  width: 34,
                  child: pw.Text('QTY', style: _style(size: 10, bold: true)),
                ),
                pw.Expanded(
                  child:
                      pw.Text('ITEM NAME', style: _style(size: 10, bold: true)),
                ),
                pw.SizedBox(
                  width: 70,
                  child: pw.Text(
                    'PRICE',
                    textAlign: pw.TextAlign.right,
                    style: _style(size: 10, bold: true),
                  ),
                ),
              ],
            ),
            pw.Divider(thickness: 0.6),
            ...items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 34,
                      child: pw.Text(
                        '${item.quantity}',
                        style: _style(size: 12, bold: true),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        item.product.name,
                        style: _style(size: 12, bold: true),
                      ),
                    ),
                    pw.SizedBox(
                      width: 70,
                      child: pw.Text(
                        _money(item.total),
                        textAlign: pw.TextAlign.right,
                        style: _style(size: 12, bold: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            _summaryRow('Taxable Value :', _money(taxableAmount)),
            pw.SizedBox(height: 6),
            _summaryRow('CGST :', _money(cgstAmount)),
            pw.SizedBox(height: 6),
            _summaryRow('SGST :', _money(sgstAmount)),
            pw.SizedBox(height: 8),
            _summaryRow('Tax :', _money(taxAmount)),
            pw.SizedBox(height: 10),
            _summaryRow('To pay :', _money(total), bold: true),
            pw.SizedBox(height: 14),
            pw.Text(
              'Bill No: $billDisplay',
              textAlign: pw.TextAlign.center,
              style: _style(size: 9),
            ),
          ],
        );
      },
    ),
  );

  return Printing.layoutPdf(
    name: 'checkout-$billDisplay.pdf',
    onLayout: (_) => doc.save(),
  );
}
