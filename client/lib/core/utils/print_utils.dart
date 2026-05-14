import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/bill_config_model.dart';
import '../../presentation/providers/cart_provider.dart';
import '../../presentation/providers/bill_config_provider.dart';
import '../network/providers.dart';
import '../../services/smart_pos_printer_service.dart';

class PrintUtils {
  static final SmartPosPrinterService _printer = SmartPosPrinterService();

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
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 36),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text('Already Printed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: const Text(
              'The invoice and ticket for this bill were already printed.\n\n'
              'Reprinting is not allowed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }
      return false;
    }

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

      await _printer.initSdk();

      await _printInvoiceSlip(
        config: config,
        billNumber: billNumber,
        date: localDate,
        cartState: cartState,
        total: total,
        paymentMethod: paymentMethod,
        hasTax: hasTax,
        taxableAmount: taxableAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
      );

      await _printEntryTicketSlip(
        config: config,
        billNumber: billNumber,
        date: localDate,
        cartState: cartState,
        total: total,
        paymentMethod: paymentMethod,
      );

      await tracker.markAsPrinted(billNumber);
      return true;
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
      return false;
    }
  }

  /// Invoice slip — legacy receipt style with INVOICE header.
  static Future<void> _printInvoiceSlip({
    required BillConfig config,
    required String billNumber,
    required DateTime date,
    required CartState cartState,
    required double total,
    required String paymentMethod,
    required bool hasTax,
    required double taxableAmount,
    required double cgstAmount,
    required double sgstAmount,
  }) async {
    // ── Header ──────────────────────────────────────────────────────────────
    if (config.orgName.isNotEmpty) {
      await _printer.printText(text: config.orgName, size: 28, isBold: true, align: 1);
    }
    await _printer.printText(text: '--------------------------------', size: 20, align: 1);

    // ── Address / identifiers ───────────────────────────────────────────────
    if (config.unitName != null && config.unitName!.isNotEmpty) {
      await _printer.printText(text: config.unitName!, size: 20, align: 0);
    }
    if (config.territory != null && config.territory!.isNotEmpty) {
      await _printer.printText(text: config.territory!, size: 20, align: 0);
    }
    if (config.gstNumber != null && config.gstNumber!.isNotEmpty) {
      await _printer.printText(text: 'GSTIN: ${config.gstNumber!}', size: 20, align: 0);
    }
    if (config.posId != null && config.posId!.isNotEmpty) {
      await _printer.printText(text: 'POS ID: ${config.posId!}', size: 20, align: 0);
    }
    if ((config.unitName != null && config.unitName!.isNotEmpty) ||
        (config.territory != null && config.territory!.isNotEmpty) ||
        (config.gstNumber != null && config.gstNumber!.isNotEmpty) ||
        (config.posId != null && config.posId!.isNotEmpty)) {
      await _printer.printText(text: '--------------------------------', size: 20, align: 1);
    }

    // ── INVOICE label + bill details ────────────────────────────────────────
    await _printer.printText(text: 'INVOICE', size: 22, isBold: true, align: 1);
    await _printer.printText(text: 'Bill No: $billNumber', size: 22, align: 0);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    await _printer.printText(text: dateStr, size: 20, align: 0);
    await _printer.printText(text: '--------------------------------', size: 20, align: 1);

    // ── Item list ────────────────────────────────────────────────────────────
    for (final item in cartState.items.values) {
      final line =
          '${item.product.name}  x${item.quantity}   Rs.${item.total.toStringAsFixed(2)}';
      await _printer.printText(text: line, size: 22, align: 0);
    }

    // ── Totals ───────────────────────────────────────────────────────────────
    await _printer.printText(text: '--------------------------------', size: 20, align: 1);
    await _printer.printText(
      text: 'TOTAL    Rs.${total.toStringAsFixed(2)}',
      size: 26,
      isBold: true,
      align: 0,
    );
    if (hasTax) {
      await _printer.printText(
        text: 'Taxable Amt  Rs.${taxableAmount.toStringAsFixed(2)}',
        size: 20,
        align: 0,
      );
      await _printer.printText(
        text: 'CGST @${config.cgstPercent.toStringAsFixed(0)}%  Rs.${cgstAmount.toStringAsFixed(2)}',
        size: 20,
        align: 0,
      );
      await _printer.printText(
        text: 'SGST @${config.sgstPercent.toStringAsFixed(0)}%  Rs.${sgstAmount.toStringAsFixed(2)}',
        size: 20,
        align: 0,
      );
    }
    await _printer.printText(text: receiptPaymentLabel(paymentMethod), size: 20, align: 0);
    await _printer.printText(text: '--------------------------------', size: 20, align: 1);

    // ── Footer ───────────────────────────────────────────────────────────────
    final footer = (config.footerMessage != null && config.footerMessage!.isNotEmpty)
        ? config.footerMessage!
        : 'Thank you. Visit again!';
    await _printer.printText(text: footer, size: 20, align: 1);
    await _printer.printText(text: '\n\n', size: 20, align: 1);
    await _printer.cutPaper();
  }

  /// Compact ticket for gate / proof of booking (different layout from invoice).
  static Future<void> _printEntryTicketSlip({
    required BillConfig config,
    required String billNumber,
    required DateTime date,
    required CartState cartState,
    required double total,
    required String paymentMethod,
  }) async {
    await _printer.printText(
      text: '      ENTRY TICKET',
      size: 26,
      isBold: true,
      align: 1,
    );
    await _printer.printText(
      text: '         BOOKED',
      size: 22,
      isBold: true,
      align: 1,
    );
    await _printer.printText(text: '--------------------------------', size: 20, align: 1);

    if (config.orgName.isNotEmpty) {
      await _printer.printText(text: config.orgName, size: 22, isBold: true, align: 1);
    }
    if (config.unitName != null && config.unitName!.isNotEmpty) {
      await _printer.printText(text: config.unitName!, size: 18, align: 1);
    }
    await _printer.printText(text: '--------------------------------', size: 20, align: 1);

    await _printer.printText(
      text: 'Ticket No:',
      size: 18,
      align: 0,
    );
    await _printer.printText(
      text: billNumber,
      size: 24,
      isBold: true,
      align: 0,
    );

    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    await _printer.printText(text: dateStr, size: 20, align: 0);

    final itemCount = cartState.items.length;
    final pieceCount =
        cartState.items.values.fold<int>(0, (sum, ci) => sum + ci.quantity);
    await _printer.printText(
      text: 'Lines: $itemCount   Pcs: $pieceCount',
      size: 20,
      align: 0,
    );

    await _printer.printText(text: '--------------------------------', size: 20, align: 1);
    await _printer.printText(
      text: 'AMOUNT  Rs.${total.toStringAsFixed(2)}',
      size: 24,
      isBold: true,
      align: 0,
    );
    await _printer.printText(
      text: receiptPaymentLabel(paymentMethod),
      size: 20,
      align: 0,
    );
    await _printer.printText(text: '--------------------------------', size: 20, align: 1);
    await _printer.printText(
      text: 'Present this ticket at entry.',
      size: 18,
      align: 1,
    );
    await _printer.printText(text: '\n\n', size: 20, align: 1);
    await _printer.cutPaper();
  }
}
