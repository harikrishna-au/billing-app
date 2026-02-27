import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../data/models/bill_config_model.dart';

class PrinterService {
  Future<void> printReceipt({
    required String orderId,
    required double totalAmount,
    required DateTime date,
    required List<Map<String, dynamic>> items, // {name, quantity, price}
    String? paymentMethod,
    BillConfig? config,
  }) async {
    final doc = pw.Document();
    final cfg = config ?? BillConfig.empty;

    // Tax-inclusive calculation
    final cgstRate = cfg.cgstPercent / 100;
    final sgstRate = cfg.sgstPercent / 100;
    final taxRate = cgstRate + sgstRate;
    final base = taxRate > 0 ? totalAmount / (1 + taxRate) : totalAmount;
    final cgstAmt = base * cgstRate;
    final sgstAmt = base * sgstRate;
    final hasTax = taxRate > 0;

    const boldStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11);
    const normalStyle = pw.TextStyle(fontSize: 11);
    const smallStyle = pw.TextStyle(fontSize: 10);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              if (cfg.orgName.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    cfg.orgName,
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              if (cfg.tagline != null && cfg.tagline!.isNotEmpty)
                pw.Center(
                  child: pw.Text(cfg.tagline!, style: smallStyle),
                ),
              pw.SizedBox(height: 6),
              pw.Divider(),

              // Unit details
              if (cfg.unitName != null) pw.Text(cfg.unitName!, style: normalStyle),
              if (cfg.territory != null) pw.Text(cfg.territory!, style: normalStyle),
              if (cfg.gstNumber != null)
                pw.Text('GSTIN: ${cfg.gstNumber}', style: normalStyle),
              if (cfg.posId != null)
                pw.Text('POS ID: ${cfg.posId}', style: normalStyle),
              pw.SizedBox(height: 4),
              pw.Text('Ticket: $orderId', style: normalStyle),
              pw.Text(
                'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                style: normalStyle,
              ),
              pw.Divider(),

              // Items header
              pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Item', style: boldStyle)),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text('Price',
                          textAlign: pw.TextAlign.right, style: boldStyle)),
                  pw.Expanded(
                      flex: 1,
                      child: pw.Text('Qty',
                          textAlign: pw.TextAlign.right, style: boldStyle)),
                  pw.Expanded(
                      flex: 2,
                      child: pw.Text('Amt',
                          textAlign: pw.TextAlign.right, style: boldStyle)),
                ],
              ),
              pw.Divider(),

              // Items
              ...items.map((item) {
                final qty = item['quantity'] as int;
                final price = (item['price'] as num).toDouble();
                final amt = price * qty;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                          flex: 4,
                          child: pw.Text(item['name'].toString(), style: normalStyle)),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(price.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right, style: normalStyle)),
                      pw.Expanded(
                          flex: 1,
                          child: pw.Text('$qty',
                              textAlign: pw.TextAlign.right, style: normalStyle)),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(amt.toStringAsFixed(2),
                              textAlign: pw.TextAlign.right, style: normalStyle)),
                    ],
                  ),
                );
              }),

              pw.Divider(),

              // Tax breakdown
              if (hasTax) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CGST @${cfg.cgstPercent}%', style: normalStyle),
                    pw.Text(cgstAmt.toStringAsFixed(2), style: normalStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SGST @${cfg.sgstPercent}%', style: normalStyle),
                    pw.Text(sgstAmt.toStringAsFixed(2), style: normalStyle),
                  ],
                ),
                pw.Divider(),
              ],

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  pw.Text('Rs.${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),
              if (paymentMethod != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3),
                  child: pw.Text('Mode: $paymentMethod', style: normalStyle),
                ),
              if (hasTax)
                pw.Text('Inclusive of all taxes', style: smallStyle),

              pw.SizedBox(height: 10),
              pw.Divider(),

              // Footer
              pw.Center(
                child: pw.Text(
                  cfg.footerMessage ?? 'Thank you. Visit again',
                  style: normalStyle,
                ),
              ),
              if (cfg.website != null)
                pw.Center(child: pw.Text(cfg.website!, style: smallStyle)),
              if (cfg.tollFree != null)
                pw.Center(
                    child: pw.Text('Toll Free: ${cfg.tollFree}', style: smallStyle)),
              pw.SizedBox(height: 20),
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
