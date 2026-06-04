import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/cart_provider.dart';
import '../../presentation/providers/bill_config_provider.dart';
import '../network/providers.dart';
import '../../presentation/screens/orders/create/bill_thermal_print.dart';
import '../../services/smart_pos_printer_service.dart';

class PrintUtils {
  static final SmartPosPrinterService _printer = SmartPosPrinterService();

  static Future<void> _showPrintDiagnosticsDialog({
    required BuildContext context,
    required List<String> lines,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Print failed',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              lines.isEmpty
                  ? 'No print diagnostics captured.'
                  : lines.join('\n'),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Shows a centered "Ticket Booked!" overlay, then closes automatically.
  /// Uses [useRootNavigator] so it appears above shell routes (e.g. `/new/review`).
  static Future<void> showTicketBooked(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext, rootNavigator: true).pop();
          }
        });
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Color(0xFF10B981),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ticket Booked!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF065F46),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Same wording everywhere (thermal + on-screen invoice).
  static String receiptPaymentLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Paid via Cash';
      case 'card':
        return 'Paid via Card';
      case 'online':
      case 'upi':
        return 'Paid via Online';
      default:
        return 'Paid — ${method.trim()}';
    }
  }

  /// Prints **two different slips** in one flow: a full **invoice**, then a
  /// compact **entry ticket** (when a booking / sale completes). Each slip is
  /// cut separately. [markPrinted] is only called if both succeed.
  ///
  /// Returns [true] if both printed; [false] if blocked (already printed) or failed.
  static Future<bool> printReceipt({
    BuildContext? context,
    required ProviderContainer provider,
    required String billNumber,
    required double total,
    required DateTime date,
    required CartState cartState,
    required String paymentMethod,
  }) async {
    final tracker = provider.read(printedBillsTrackerProvider);

    if (tracker.hasBeenPrinted(billNumber)) {
      if (context != null && context.mounted) {
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Already Printed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: const Text(
              'The invoice and ticket for this bill were already printed.\n\n'
              'Reprinting is not allowed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      }
      return false;
    }

    final debugLines = <String>['Starting print for bill $billNumber'];

    try {
      final localDate = date.toLocal();
      final config = provider.read(billConfigProvider);
      final cgstRate = config.cgstPercent / 100;
      final sgstRate = config.sgstPercent / 100;
      final taxRate = cgstRate + sgstRate;
      final taxableAmount = taxRate > 0 ? total / (1 + taxRate) : total;
      final cgstAmount = taxableAmount * cgstRate;
      final sgstAmount = taxableAmount * sgstRate;
      final hasTax = taxRate > 0;

      final dateStr =
          '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}  '
          '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';

      await printBillThermalInvoiceAndTicket(
        printer: _printer,
        config: config,
        billDisplay: billNumber,
        dateStr: dateStr,
        cartState: cartState,
        total: total,
        taxableAmount: taxableAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        hasTax: hasTax,
        paymentMethod: paymentMethod,
        onDebug: debugLines.add,
      );

      await tracker.markAsPrinted(billNumber);
      return true;
    } catch (e) {
      if (context != null && context.mounted) {
        debugLines.add('FAILED: $e');
        await _showPrintDiagnosticsDialog(context: context, lines: debugLines);
      }
      return false;
    }
  }
}
