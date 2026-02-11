import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/payment_model.dart';

class ReceiptGenerator {
  /// Generate PDF receipt for a payment
  static Future<pw.Document> generateReceipt({
    required Payment payment,
    String businessName = 'BillKaro POS',
    String? businessAddress,
    String? businessPhone,
    String? businessGSTIN,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (businessAddress != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        businessAddress,
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                    if (businessPhone != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Phone: $businessPhone',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                    if (businessGSTIN != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'GSTIN: $businessGSTIN',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 8),

              // Bill Details
              _buildRow('Bill No:', payment.billNumber),
              _buildRow('Date:', _formatDateTime(payment.createdAt)),

              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Note: Item details not available in payment record
              pw.Center(
                child: pw.Text(
                  'Payment Receipt',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount:',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '₹${payment.amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // Payment Method
              _buildRow('Payment Mode:', payment.methodDisplay),
              _buildRow('Status:', payment.statusDisplay),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 8),

              // Footer
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Visit again!',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Helper to build key-value rows
  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Format DateTime for receipt
  static String _formatDateTime(DateTime dateTime) {
    return '${_pad(dateTime.day)}/${_pad(dateTime.month)}/${dateTime.year} '
        '${_pad(dateTime.hour)}:${_pad(dateTime.minute)}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  /// Print receipt
  static Future<void> printReceipt({
    required Payment payment,
  }) async {
    final pdf = await generateReceipt(payment: payment);
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Share receipt as PDF
  static Future<void> shareReceipt({
    required Payment payment,
  }) async {
    final pdf = await generateReceipt(payment: payment);
    final bytes = await pdf.save();

    // Save to temporary directory
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_${payment.billNumber}.pdf');
    await file.writeAsBytes(bytes);

    // Share
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Receipt - ${payment.billNumber}',
      text:
          'Receipt for bill ${payment.billNumber} - ₹${payment.amount.toStringAsFixed(2)}',
    );
  }

  /// Save receipt to device
  static Future<File> saveReceipt({
    required Payment payment,
  }) async {
    final pdf = await generateReceipt(payment: payment);
    final bytes = await pdf.save();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/receipt_${payment.billNumber}.pdf');
    await file.writeAsBytes(bytes);

    return file;
  }
}
