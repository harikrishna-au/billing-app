import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/payment_provider.dart';
import '../../../../core/network/providers.dart';
import '../../../../services/smart_pos_printer_service.dart';
import '../../../providers/bill_config_provider.dart';

class CollectPaymentScreen extends ConsumerStatefulWidget {
  final String paymentMethod;

  const CollectPaymentScreen({
    super.key,
    required this.paymentMethod,
  });

  @override
  ConsumerState<CollectPaymentScreen> createState() =>
      _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends ConsumerState<CollectPaymentScreen> {
  bool _isProcessing = false;

  bool get _isCash => widget.paymentMethod == 'cash';

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final total = cartState.totalAmount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Collect Payment',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        leading: _BackButton(onTap: () => context.pop()),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Amount hero card
                  _AmountCard(
                    total: total,
                    isCash: _isCash,
                  )
                      .animate()
                      .fadeIn(duration: 180.ms),

                  const SizedBox(height: 16),

                  // Items summary
                  _ItemsSummary(cartState: cartState, total: total)
                      .animate()
                      .fadeIn(duration: 180.ms, delay: 60.ms),

                  const SizedBox(height: 12),

                  // Cash note
                  if (_isCash)
                    _CashNote(amount: total)
                        .animate()
                        .fadeIn(duration: 180.ms, delay: 100.ms),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          _ActionFooter(
            isCash: _isCash,
            isProcessing: _isProcessing,
            onConfirm: () => _handleConfirm(context),
            onCancel: () => _handleCancel(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirm(BuildContext context) async {
    if (_isProcessing) return;

    if (!_isCash) {
      setState(() => _isProcessing = true);
      try {
        final total = ref.read(cartProvider).totalAmount;
        // Generate the bill number here so cash and UPI share the same sequence.
        final billNumber =
            await ref.read(billNumberServiceProvider).generate();
        if (!mounted) return;
        setState(() => _isProcessing = false);
        context.push(
            '/new/review/collect-payment/upi?amount=$total&invoice=$billNumber');
      } catch (e) {
        setState(() => _isProcessing = false);
        _showError(context, e.toString());
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final cartState = ref.read(cartProvider);
      final total = cartState.totalAmount;
      final billNumber = await ref.read(billNumberServiceProvider).generate();

      await _createPaymentRecord(context, total, PaymentMethod.cash, billNumber);

      // Print receipt
      try {
        final config = ref.read(billConfigProvider);
        final cgstRate = config.cgstPercent / 100;
        final sgstRate = config.sgstPercent / 100;
        final taxRate = cgstRate + sgstRate;
        final base = taxRate > 0 ? total / (1 + taxRate) : total;
        final cgstAmt = base * cgstRate;
        final sgstAmt = base * sgstRate;

        final printer = SmartPosPrinterService();
        await printer.initSdk();

        // Header
        final orgName = config.orgName.isNotEmpty ? config.orgName : 'BillKaro';
        await printer.printText(text: "$orgName\n", size: 30, isBold: true, align: 1);
        if (config.tagline != null && config.tagline!.isNotEmpty) {
          await printer.printText(text: "${config.tagline}\n", size: 22, align: 1);
        }
        await printer.printText(text: "--------------------------------\n", size: 22, align: 1);

        // Unit details
        if (config.unitName != null) {
          await printer.printText(text: "${config.unitName}\n", size: 22, align: 0);
        }
        if (config.territory != null) {
          await printer.printText(text: "${config.territory}\n", size: 22, align: 0);
        }
        if (config.gstNumber != null) {
          await printer.printText(text: "GSTIN: ${config.gstNumber}\n", size: 22, align: 0);
        }
        if (config.posId != null) {
          await printer.printText(text: "POS ID: ${config.posId}\n", size: 22, align: 0);
        }
        await printer.printText(text: "Ticket: $billNumber\n", size: 22, align: 0);
        await printer.printText(
            text: "Date: ${DateTime.now().toString().substring(0, 16)}\n",
            size: 22,
            align: 0);
        await printer.printText(text: "--------------------------------\n", size: 22, align: 1);

        // Items header
        await printer.printText(
            text: "Item            Rate  Qty   Amt\n", size: 20, isBold: true, align: 0);
        await printer.printText(text: "--------------------------------\n", size: 20, align: 0);

        // Items
        for (final ci in ref.read(cartProvider).items.values) {
          final qty = ci.quantity;
          final rate = ci.product.price;
          final amt = rate * qty;
          final name = ci.product.name.length > 14
              ? ci.product.name.substring(0, 14)
              : ci.product.name.padRight(14);
          final rateFmt = rate.toStringAsFixed(0).padLeft(5);
          final qtyFmt = qty.toString().padLeft(4);
          final amtFmt = amt.toStringAsFixed(0).padLeft(5);
          await printer.printText(
              text: "$name$rateFmt$qtyFmt$amtFmt\n", size: 20, align: 0);
        }

        await printer.printText(text: "--------------------------------\n", size: 22, align: 1);

        // Tax breakdown
        if (taxRate > 0) {
          await printer.printText(
              text: "CGST @${config.cgstPercent}%: ${cgstAmt.toStringAsFixed(2)}\n",
              size: 22,
              align: 0);
          await printer.printText(
              text: "SGST @${config.sgstPercent}%: ${sgstAmt.toStringAsFixed(2)}\n",
              size: 22,
              align: 0);
          await printer.printText(text: "--------------------------------\n", size: 22, align: 1);
        }

        // Total
        await printer.printText(
            text: "TOTAL: ${CurrencyFormatter.format(total)}\n",
            size: 28,
            isBold: true,
            align: 0);
        await printer.printText(text: "Mode: CASH\n", size: 22, align: 0);
        if (taxRate > 0) {
          await printer.printText(text: "Inclusive of all taxes\n", size: 20, align: 0);
        }
        await printer.printText(text: "--------------------------------\n", size: 22, align: 1);

        // Footer
        final footer = config.footerMessage ?? "Thank you. Visit again";
        await printer.printText(text: "$footer\n", size: 22, align: 1);
        if (config.website != null) {
          await printer.printText(text: "${config.website}\n", size: 20, align: 1);
        }
        if (config.tollFree != null) {
          await printer.printText(text: "Toll Free: ${config.tollFree}\n", size: 20, align: 1);
        }
        await printer.printText(text: "\n\n\n\n", size: 22, align: 1);
      } catch (e) {
        debugPrint("Printing failed: $e");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError(context, e.toString());
    }
  }

  Future<void> _createPaymentRecord(BuildContext context, double amount,
      PaymentMethod method, String billNumber) async {
    final payment = Payment(
      id: '',
      billNumber: billNumber,
      amount: amount,
      method: method,
      status: PaymentStatus.success,
      createdAt: DateTime.now(),
    );

    final created =
        await ref.read(paymentProvider.notifier).createPayment(payment);
    if (created == null) throw Exception('Failed to create payment');
    if (!mounted) return;

    setState(() => _isProcessing = false);
    context.push(
      '/new/review/collect-payment/bill?method=${widget.paymentMethod}&invoice=${payment.billNumber}',
    );
  }

  void _handleCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel transaction?',
          style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'This will discard the current payment.',
          style: GoogleFonts.dmSans(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep it',
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text('Cancel',
                style: GoogleFonts.dmSans(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $message',
            style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  final double total;
  final bool isCash;

  const _AmountCard({required this.total, required this.isCash});

  @override
  Widget build(BuildContext context) {
    final color = isCash ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Method badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCash ? Icons.payments_rounded : Icons.qr_code_rounded,
                  color: Colors.white.withOpacity(0.95),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  isCash ? 'CASH PAYMENT' : 'UPI / ONLINE',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.95),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Amount to collect',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(total),
            style: GoogleFonts.dmSans(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsSummary extends StatelessWidget {
  final CartState cartState;
  final double total;

  const _ItemsSummary({required this.cartState, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order summary',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text('Edit',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16, color: AppColors.borderLight),
          ...cartState.items.values.map((ci) => _Row(
                name: ci.product.name,
                qty: ci.quantity,
                price: ci.product.price * ci.quantity,
              )),
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(
                  CurrencyFormatter.format(total),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
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

class _Row extends StatelessWidget {
  final String name;
  final int qty;
  final double price;
  const _Row({required this.name, required this.qty, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text('${qty}x',
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(CurrencyFormatter.format(price),
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _CashNote extends StatelessWidget {
  final double amount;
  const _CashNote({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'By confirming, you acknowledge that you have received ${CurrencyFormatter.format(amount)} in cash.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF92400E),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionFooter extends StatelessWidget {
  final bool isCash;
  final bool isProcessing;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ActionFooter({
    required this.isCash,
    required this.isProcessing,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCash ? AppColors.success : AppColors.primary;

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
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  disabledBackgroundColor: color.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isProcessing
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          key: const ValueKey('btn'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isCash
                                  ? Icons.check_circle_rounded
                                  : Icons.qr_code_scanner_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isCash
                                  ? 'Confirm Cash Received'
                                  : 'Proceed to Pay',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
              child: Text(
                'Cancel transaction',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
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
      onPressed: onTap,
    );
  }
}
