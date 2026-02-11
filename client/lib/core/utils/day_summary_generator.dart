import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../data/models/payment_model.dart';

class DaySummaryGenerator {
  /// Generate PDF day summary report
  static Future<pw.Document> generateDaySummary({
    required List<Payment> payments,
    required DateTime date,
    String businessName = 'BillKaro POS',
    String? businessAddress,
    String? businessPhone,
  }) async {
    final pdf = pw.Document();

    // Calculate statistics
    final totalAmount = payments.fold<double>(
      0.0,
      (sum, payment) => sum + payment.amount,
    );

    final cashPayments = payments.where((p) => p.method == PaymentMethod.cash).toList();
    final onlinePayments = payments.where((p) => p.method == PaymentMethod.upi).toList();

    final cashAmount = cashPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final onlineAmount = onlinePayments.fold<double>(0.0, (sum, p) => sum + p.amount);

    final dateFormat = DateFormat('dd MMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (businessAddress != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        businessAddress,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                    if (businessPhone != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Phone: $businessPhone',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Report Title
              pw.Center(
                child: pw.Text(
                  'DAY SUMMARY REPORT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  dateFormat.format(date),
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ),

              pw.SizedBox(height: 20),

              // Summary Statistics
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    _buildStatRow('Total Bills:', payments.length.toString()),
                    pw.SizedBox(height: 8),
                    _buildStatRow(
                      'Total Collection:',
                      '₹${totalAmount.toStringAsFixed(2)}',
                      bold: true,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    _buildStatRow(
                      'Cash Payments:',
                      '₹${cashAmount.toStringAsFixed(2)} (${cashPayments.length} bills)',
                    ),
                    pw.SizedBox(height: 8),
                    _buildStatRow(
                      'Online Payments:',
                      '₹${onlineAmount.toStringAsFixed(2)} (${onlinePayments.length} bills)',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Payment List Header
              pw.Text(
                'PAYMENT DETAILS',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'Bill No.',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'Time',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'Method',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'Status',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        'Amount',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              // Payment Rows
              ...payments.map((payment) => _buildPaymentRow(payment, timeFormat)),

              pw.SizedBox(height: 20),
              pw.Divider(),

              // Grand Total
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRAND TOTAL',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '₹${totalAmount.toStringAsFixed(2)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildStatRow(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPaymentRow(Payment payment, DateFormat timeFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              payment.billNumber,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              timeFormat.format(payment.createdAt),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              payment.method.name.toUpperCase(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              payment.status.name.toUpperCase(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              '₹${payment.amount.toStringAsFixed(2)}',
              style: const pw.TextStyle(fontSize: 9),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Print the day summary
  static Future<void> printDaySummary(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  /// Share the day summary as PDF
  static Future<void> shareDaySummary(pw.Document pdf, DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/day_summary_$dateStr.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Day Summary Report - $dateStr',
    );
  }
}
