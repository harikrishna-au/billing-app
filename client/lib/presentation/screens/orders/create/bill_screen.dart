import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../../services/smart_pos_printer_service.dart';
import '../../../../core/network/providers.dart';

class BillScreen extends ConsumerStatefulWidget {
  final String? invoiceNumber;
  final String paymentMethod;
  final double? amount;
  final DateTime? date;

  final bool readOnly;

  const BillScreen({
    super.key,
    this.invoiceNumber,
    required this.paymentMethod,
    this.amount,
    this.date,
    this.readOnly = false,
  });

  @override
  ConsumerState<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends ConsumerState<BillScreen> {
  final SmartPosPrinterService _printer = SmartPosPrinterService();

  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final cartState = ref.read(cartProvider);
        final now = widget.date ?? DateTime.now();
        final invoiceNo = widget.invoiceNumber ?? 'BILL/PENDING';
        final total = widget.amount ?? cartState.totalAmount;
        _handlePrint(context, ref, invoiceNo, total, now, cartState);
      });
    }
  }

  /// Attempts to print the receipt for [billNumber].
  /// Blocks the print and shows an error dialog if this bill was already printed.
  Future<void> _handlePrint(
    BuildContext context,
    WidgetRef ref,
    String billNumber,
    double total,
    DateTime date,
    CartState cartState,
  ) async {
    final tracker = ref.read(printedBillsTrackerProvider);

    // --- GUARD: already printed? ---
    if (tracker.hasBeenPrinted(billNumber)) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Text(
                'Already Printed',
                style: GoogleFonts.dmSans(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Text(
            'Ticket $billNumber has already been printed.\n\nPrinting the same ticket again is not allowed.',
            style: GoogleFonts.dmSans(
                fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('OK',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }

    // --- PRINT ---
    try {
      final config = ref.read(billConfigProvider);
      final cgstRate = config.cgstPercent / 100;
      final sgstRate = config.sgstPercent / 100;
      final taxRate = cgstRate + sgstRate;
      final taxableAmount = taxRate > 0 ? total / (1 + taxRate) : total;
      final cgstAmount = taxableAmount * cgstRate;
      final sgstAmount = taxableAmount * sgstRate;
      final hasTax = taxRate > 0;
      await _printer.initSdk();

      if (config.orgName.isNotEmpty) {
        await _printer.printText(
          text: config.orgName,
          size: 28,
          isBold: true,
          align: 1,
        );
      }
      await _printer.printText(
        text: '--------------------------------',
        size: 20,
        align: 1,
      );

      if (config.unitName != null && config.unitName!.isNotEmpty) {
        await _printer.printText(text: config.unitName!, size: 20, align: 0);
      }
      if (config.territory != null && config.territory!.isNotEmpty) {
        await _printer.printText(text: config.territory!, size: 20, align: 0);
      }
      if (config.gstNumber != null && config.gstNumber!.isNotEmpty) {
        await _printer.printText(
          text: 'GSTIN: ${config.gstNumber!}',
          size: 20,
          align: 0,
        );
      }
      if (config.posId != null && config.posId!.isNotEmpty) {
        await _printer.printText(
          text: 'POS ID: ${config.posId!}',
          size: 20,
          align: 0,
        );
      }
      if ((config.unitName != null && config.unitName!.isNotEmpty) ||
          (config.territory != null && config.territory!.isNotEmpty) ||
          (config.gstNumber != null && config.gstNumber!.isNotEmpty) ||
          (config.posId != null && config.posId!.isNotEmpty)) {
        await _printer.printText(
          text: '--------------------------------',
          size: 20,
          align: 1,
        );
      }

      await _printer.printText(text: 'Bill No: $billNumber', size: 22, align: 0);
      final dateStr =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      await _printer.printText(text: dateStr, size: 20, align: 0);
      await _printer.printText(
        text: '--------------------------------',
        size: 20,
        align: 1,
      );

      for (final item in cartState.items.values) {
        final line =
            '${item.product.name}  x${item.quantity}   Rs.${(item.product.price * item.quantity).toStringAsFixed(2)}';
        await _printer.printText(text: line, size: 22, align: 0);
      }

      await _printer.printText(
        text: '--------------------------------',
        size: 20,
        align: 1,
      );
      await _printer.printText(
        text: 'TOTAL    Rs.${total.toStringAsFixed(2)}',
        size: 26,
        isBold: true,
        align: 0,
      );
      if (hasTax) {
        await _printer.printText(
          text:
              'Taxable Amt  Rs.${taxableAmount.toStringAsFixed(2)}',
          size: 20,
          align: 0,
        );
        await _printer.printText(
          text:
              'CGST @${config.cgstPercent.toStringAsFixed(0)}%  Rs.${cgstAmount.toStringAsFixed(2)}',
          size: 20,
          align: 0,
        );
        await _printer.printText(
          text:
              'SGST @${config.sgstPercent.toStringAsFixed(0)}%  Rs.${sgstAmount.toStringAsFixed(2)}',
          size: 20,
          align: 0,
        );
      }
      await _printer.printText(
        text: 'Payment: ${_paymentLabel(widget.paymentMethod)}',
        size: 20,
        align: 0,
      );
      await _printer.printText(
        text: '--------------------------------',
        size: 20,
        align: 1,
      );

      final footer =
          (config.footerMessage != null && config.footerMessage!.isNotEmpty)
              ? config.footerMessage!
              : 'Thank you. Visit again!';
      await _printer.printText(text: footer, size: 20, align: 1);
      await _printer.printText(text: '\n\n', size: 20, align: 1);
      await _printer.cutPaper();

      // Mark as printed only on success
      await tracker.markAsPrinted(billNumber);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  String _paymentLabel(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'CASH';
      case 'card':
        return 'CARD / Online';
      case 'online':
      case 'upi':
        return 'UPI / Online';
      default:
        return method.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final now = widget.date ?? DateTime.now();
    final invoiceNo = widget.invoiceNumber ?? 'BILL/PENDING';
    final total = widget.amount ?? cartState.totalAmount;
    final isCash = widget.paymentMethod.toLowerCase() == 'cash';
    final isCard = widget.paymentMethod.toLowerCase() == 'card';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Invoice',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: AppColors.textPrimary),
          ),
          onPressed: () {
            ref.read(cartProvider.notifier).clearCart();
            context.go('/new');
          },
        ),
        actions: [
          if (!widget.readOnly) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: AppColors.textSecondary, size: 22),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Share coming soon', style: GoogleFonts.dmSans()),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined,
                  color: AppColors.textSecondary, size: 22),
              onPressed: () =>
                  _handlePrint(context, ref, invoiceNo, total, now, cartState),
            ),
          ],
          const SizedBox(width: 4),
        ],
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  // Success banner
                  _SuccessBanner(total: total, isCash: isCash)
                      .animate()
                      .fadeIn(duration: 200.ms)
                      .scale(
                          begin: const Offset(0.96, 0.96),
                          duration: 250.ms,
                          curve: Curves.easeOut),

                  const SizedBox(height: 16),

                  // Invoice card
                  _InvoiceCard(
                    invoiceNo: invoiceNo,
                    now: now,
                    total: total,
                    cartState: cartState,
                    paymentMethod: widget.paymentMethod,
                    isCash: isCash,
                    isCard: isCard,
                  ).animate().fadeIn(duration: 200.ms, delay: 80.ms),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Action buttons
          _ActionsFooter(
            showPrint: !widget.readOnly,
            onPrint: () =>
                _handlePrint(context, ref, invoiceNo, total, now, cartState),
            onNewOrder: () {
              ref.read(cartProvider.notifier).clearCart();
              context.go('/new');
            },
            onViewOrders: () {
              ref.read(cartProvider.notifier).clearCart();
              context.go('/orders');
            },
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final double total;
  final bool isCash;

  const _SuccessBanner({required this.total, required this.isCash});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Payment successful',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(total),
            style: GoogleFonts.dmSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF065F46),
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCash ? 'Paid via Cash' : 'Paid via UPI / Online',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final String invoiceNo;
  final DateTime now;
  final double total;
  final CartState cartState;
  final String paymentMethod;
  final bool isCash;
  final bool isCard;

  const _InvoiceCard({
    required this.invoiceNo,
    required this.now,
    required this.total,
    required this.cartState,
    required this.paymentMethod,
    required this.isCash,
    required this.isCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BILL NO',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      invoiceNo,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PAID',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // Date & method
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label:
                      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
                ),
                const SizedBox(width: 10),
                _MetaChip(
                  icon: Icons.access_time_rounded,
                  label:
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                ),
                const SizedBox(width: 10),
                _MetaChip(
                  icon: isCash
                      ? Icons.payments_rounded
                      : isCard
                          ? Icons.credit_card_rounded
                          : Icons.qr_code_rounded,
                  label: isCash
                      ? 'Cash'
                      : isCard
                          ? 'Card'
                          : 'Online',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              'ITEMS',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...cartState.items.values.map(
            (ci) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${ci.quantity}x',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ci.product.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${CurrencyFormatter.format(ci.product.price)} each',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(ci.product.price * ci.quantity),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),

          // Total
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(total),
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsFooter extends StatelessWidget {
  final bool showPrint;
  final VoidCallback onPrint;
  final VoidCallback onNewOrder;
  final VoidCallback onViewOrders;

  const _ActionsFooter({
    required this.showPrint,
    required this.onPrint,
    required this.onNewOrder,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary: New Order — biggest CTA on this screen
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onNewOrder,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'New Order',
                  style: GoogleFonts.dmSans(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (showPrint) ...[
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: onPrint,
                        icon: const Icon(Icons.print_outlined, size: 17),
                        label: Text(
                          'Print',
                          style: GoogleFonts.dmSans(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: onViewOrders,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Orders',
                        style: GoogleFonts.dmSans(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
