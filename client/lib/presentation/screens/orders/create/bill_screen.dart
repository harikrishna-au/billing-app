import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/bill_number_generator.dart';
import '../../../../core/network/providers.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../../services/smart_pos_printer_service.dart';
import 'bill_thermal_print.dart';
import 'widgets/bill_actions_footer.dart';
import 'widgets/bill_invoice_card.dart';
import 'widgets/bill_success_banner.dart';

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
        final now = (widget.date ?? DateTime.now()).toLocal();
        final invoiceNo = widget.invoiceNumber ?? 'BILL/PENDING';
        final total = widget.amount ?? cartState.totalAmount;
        _handlePrint(context, ref, invoiceNo, total, now, cartState);
      });
    }
  }

  Future<void> _handlePrint(
    BuildContext context,
    WidgetRef ref,
    String billNumber,
    double total,
    DateTime date,
    CartState cartState,
  ) async {
    final tracker = ref.read(printedBillsTrackerProvider);

    try {
      final config = ref.read(billConfigProvider);
      final cgstRate = config.cgstPercent / 100;
      final sgstRate = config.sgstPercent / 100;
      final taxRate = cgstRate + sgstRate;
      final taxableAmount = taxRate > 0 ? total / (1 + taxRate) : total;
      final cgstAmount = taxableAmount * cgstRate;
      final sgstAmount = taxableAmount * sgstRate;
      final hasTax = taxRate > 0;
      final billDisplay = BillNumberGenerator.displayTicketNumber(billNumber);
      final dateLocal = date.toLocal();
      final dateStr =
          '${dateLocal.day.toString().padLeft(2, '0')}/${dateLocal.month.toString().padLeft(2, '0')}/${dateLocal.year}  '
          '${dateLocal.hour.toString().padLeft(2, '0')}:${dateLocal.minute.toString().padLeft(2, '0')}';
      await printBillThermalInvoiceAndTicket(
        printer: _printer,
        config: config,
        billDisplay: billDisplay,
        dateStr: dateStr,
        cartState: cartState,
        total: total,
        taxableAmount: taxableAmount,
        cgstAmount: cgstAmount,
        sgstAmount: sgstAmount,
        hasTax: hasTax,
        paymentMethod: widget.paymentMethod,
      );

      await tracker.markAsPrinted(billNumber);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Print failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final now = (widget.date ?? DateTime.now()).toLocal();
    final invoiceNo = widget.invoiceNumber ?? 'BILL/PENDING';
    final invoiceDisplay = BillNumberGenerator.displayTicketNumber(invoiceNo);
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
          const SizedBox(width: 4),
        ],
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final hPad = w < 360 ? 16.0 : 20.0;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 20),
                  child: Column(
                    children: [
                      BillSuccessBanner(
                        total: total,
                        isCash: isCash,
                        screenWidth: w,
                      ).animate().fadeIn(duration: 200.ms).scale(
                          begin: const Offset(0.96, 0.96),
                          duration: 250.ms,
                          curve: Curves.easeOut),
                      const SizedBox(height: 16),
                      BillInvoiceCard(
                        displayInvoiceNo: invoiceDisplay,
                        now: now,
                        total: total,
                        cartState: cartState,
                        isCash: isCash,
                        isCard: isCard,
                      ).animate().fadeIn(duration: 200.ms, delay: 80.ms),
                      SizedBox(height: w < 360 ? 80 : 100),
                    ],
                  ),
                ),
              ),
              BillActionsFooter(
                showPrint: true,
                narrow: w < 380,
                onPrint: () => _handlePrint(
                    context, ref, invoiceNo, total, now, cartState),
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
          );
        },
      ),
    );
  }
}
