import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PrinterService {
  Future<void> printReceipt({
    required String orderId,
    required double totalAmount,
    required DateTime date,
    required List<Map<String, dynamic>>
        items, // List of {name, quantity, price}
    String shopName = 'BillKaro Shop',
    String? paymentMethod,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Standard 80mm thermal roll
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(shopName,
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Order: $orderId'),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}'),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Item')),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('Qty', textAlign: pw.TextAlign.right)),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('Price', textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(),
              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item['name'])),
                      pw.Expanded(
                          flex: 1,
                          child: pw.Text('${item['quantity']}',
                              textAlign: pw.TextAlign.right)),
                      pw.Expanded(
                          flex: 1,
                          child: pw.Text('${item['price']}',
                              textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }).toList(),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('$totalAmount',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
              if (paymentMethod != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 5),
                  child: pw.Text('Paid via: $paymentMethod'),
                ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Thank you like a visit again!')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Receipt_$orderId',
    );
  }
}
