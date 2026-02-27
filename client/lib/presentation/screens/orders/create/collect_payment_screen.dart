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
import '../../../../core/utils/bill_number_generator.dart';
import '../../../../services/smart_pos_printer_service.dart';

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
          style: GoogleFonts.plusJakartaSans(
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
                      .fadeIn(duration: 300.ms)
                      .scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 400.ms,
                          curve: Curves.easeOutBack),

                  const SizedBox(height: 20),

                  // Items summary
                  _ItemsSummary(cartState: cartState, total: total)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 100.ms)
                      .slideY(begin: 0.06, end: 0),

                  const SizedBox(height: 16),

                  // Cash note
                  if (_isCash)
                    _CashNote(amount: total)
                        .animate()
                        .fadeIn(duration: 300.ms, delay: 180.ms)
                        .slideY(begin: 0.06, end: 0),

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
        final orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';
        if (!mounted) return;
        setState(() => _isProcessing = false);
        context.push(
            '/new/review/collect-payment/upi?amount=$total&invoice=$orderId');
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
      final billNumber = await BillNumberGenerator.generate();

      await _createPaymentRecord(context, total, PaymentMethod.cash, billNumber);

      // Print receipt
      try {
        final printer = SmartPosPrinterService();
        await printer.initSdk();
        await printer.printText(
            text: "BILL KARO\n", size: 30, isBold: true, align: 1);
        await printer.printText(
            text: "Bill No: $billNumber\n", size: 24, align: 0);
        await printer.printText(
            text: "Date: ${DateTime.now().toString().substring(0, 16)}\n",
            size: 24,
            align: 0);
        await printer.printText(
            text: "--------------------------------\n", size: 24, align: 1);
        await printer.printText(
            text: "Amount: ${CurrencyFormatter.format(total)}\n",
            size: 30,
            isBold: true,
            align: 1);
        await printer.printText(
            text: "Method: CASH\n", size: 24, align: 1);
        await printer.printText(
            text: "--------------------------------\n", size: 24, align: 1);
        await printer.printText(
            text: "Thank you!\n\n\n\n", size: 24, align: 1);
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
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'This will discard the current payment.',
          style: GoogleFonts.plusJakartaSans(
              color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep it',
                style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text('Cancel',
                style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(color: Colors.white)),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
                  style: GoogleFonts.plusJakartaSans(
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(total),
            style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text('Edit',
                      style: GoogleFonts.plusJakartaSans(
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
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(
                  CurrencyFormatter.format(total),
                  style: GoogleFonts.plusJakartaSans(
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
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(CurrencyFormatter.format(price),
              style: GoogleFonts.plusJakartaSans(
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
              style: GoogleFonts.plusJakartaSans(
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  disabledBackgroundColor: color.withOpacity(0.5),
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
                              style: GoogleFonts.plusJakartaSans(
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
                foregroundColor: AppColors.error.withOpacity(0.8),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
              child: Text(
                'Cancel transaction',
                style: GoogleFonts.plusJakartaSans(
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
