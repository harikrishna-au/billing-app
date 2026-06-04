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
  final List<String> _printDebugLines = <String>[];
  bool _isPrinting = false;

  void _addPrintDebug(String message) {
    if (!mounted) return;
    setState(() {
      final stamp = TimeOfDay.now().format(context);
      _printDebugLines.add('$stamp - $message');
    });
  }

  Future<void> _showPrintDebugDialog(String title) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            Text(title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _printDebugLines.isEmpty
                  ? 'No print diagnostics captured.'
                  : _printDebugLines.join('\n'),
              style: GoogleFonts.robotoMono(fontSize: 12, height: 1.35),
            ),
          ),
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
  }

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
    if (_isPrinting) return;
    final tracker = ref.read(printedBillsTrackerProvider);

    try {
      setState(() {
        _isPrinting = true;
        _printDebugLines
          ..clear()
          ..add('Starting print for bill $billNumber');
      });
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
        onDebug: _addPrintDebug,
      );

      await tracker.markAsPrinted(billNumber);
      _addPrintDebug('Marked bill as printed');
    } catch (e) {
      _addPrintDebug('FAILED: $e');
      if (context.mounted) {
        await _showPrintDebugDialog('Print failed');
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
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
                      if (_printDebugLines.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _PrintDiagnosticsPanel(
                          lines: _printDebugLines,
                          isPrinting: _isPrinting,
                          onOpen: () => _showPrintDebugDialog(
                            _isPrinting
                                ? 'Printing ticket'
                                : 'Print diagnostics',
                          ),
                        ),
                      ],
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

class _PrintDiagnosticsPanel extends StatelessWidget {
  final List<String> lines;
  final bool isPrinting;
  final VoidCallback onOpen;

  const _PrintDiagnosticsPanel({
    required this.lines,
    required this.isPrinting,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final latest = lines.isEmpty ? '' : lines.last;
    final failed = latest.contains('FAILED:');
    final color = failed
        ? AppColors.error
        : isPrinting
            ? AppColors.warning
            : AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isPrinting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  failed
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 18,
                  color: color,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPrinting
                      ? 'Printing ticket'
                      : failed
                          ? 'Print failed'
                          : 'Print diagnostics',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpen,
                child: Text(
                  'Details',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            latest,
            style: GoogleFonts.robotoMono(
              fontSize: 11,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
