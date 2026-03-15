import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/payment_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../../services/smart_pos_printer_service.dart';

class RazorpayPaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String invoiceNumber;

  const RazorpayPaymentScreen({
    super.key,
    required this.amount,
    required this.invoiceNumber,
  });

  @override
  ConsumerState<RazorpayPaymentScreen> createState() =>
      _RazorpayPaymentScreenState();
}

class _RazorpayPaymentScreenState extends ConsumerState<RazorpayPaymentScreen> {
  late Razorpay _razorpay;
  bool _isCreatingOrder = false;
  bool _isProcessingPayment = false;
  String? _errorMessage;

  final _printer = SmartPosPrinterService();

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ── Step 1: Call FastAPI backend to create a Razorpay order ─────────────

  Future<String?> _createRazorpayOrder() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        RazorpayConfig.createOrderPath,
        data: {
          'amount': (widget.amount * 100).toInt(), // Razorpay expects paise
          'currency': 'INR',
          'receipt': widget.invoiceNumber,
          'notes': {'invoice': widget.invoiceNumber},
        },
      );

      if (response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['id'] as String?;
      }
    } catch (e) {
      debugPrint('Failed to create Razorpay order: $e');
    }
    return null;
  }

  // ── Step 2: Open Razorpay checkout ────────────────────────────────────────

  Future<void> _startPayment() async {
    if (_isCreatingOrder) return;
    setState(() {
      _isCreatingOrder = true;
      _errorMessage = null;
    });

    final orderId = await _createRazorpayOrder();

    if (!mounted) return;
    setState(() => _isCreatingOrder = false);

    if (orderId == null) {
      setState(() =>
          _errorMessage = 'Failed to create payment order. Please try again.');
      return;
    }

    final config = ref.read(billConfigProvider);

    final options = {
      'key': RazorpayConfig.keyId,
      'order_id': orderId,
      'amount': (widget.amount * 100).toInt(),
      'currency': 'INR',
      'name': config.orgName.isNotEmpty ? config.orgName : 'Payment',
      'description': 'Invoice #${widget.invoiceNumber}',
      'prefill': {
        'contact': '9999999999',
        'email': 'customer@pos.local',
      },
      'hidden': {
        'contact': true,
        'email': true,
      },
      'theme': {'color': '#6366F1'},
      'external': {
        'wallets': ['paytm'],
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _errorMessage = 'Could not open payment. Please try again.');
    }
  }

  // ── Step 3: Handle Razorpay callbacks ─────────────────────────────────────

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_isProcessingPayment) return;
    setState(() => _isProcessingPayment = true);

    try {
      final payment = Payment(
        id: '',
        billNumber: widget.invoiceNumber,
        amount: widget.amount,
        method: PaymentMethod.card,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      final created =
          await ref.read(paymentProvider.notifier).createPayment(payment);

      if (created == null) throw Exception('Failed to record payment');

      await _printReceipt();

      if (!mounted) return;
      context.pushReplacement(
        '/new/review/collect-payment/bill?method=card&invoice=${widget.invoiceNumber}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingPayment = false;
        _errorMessage = 'Payment received but failed to record. Contact support.';
      });
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    final msg = response.message ?? 'Payment was not completed.';
    setState(() => _errorMessage = msg);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // User chose an external wallet — treat as pending; they'll confirm manually
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Redirecting to ${response.walletName}…',
          style: GoogleFonts.dmSans(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Receipt printing ───────────────────────────────────────────────────────

  Future<void> _printReceipt() async {
    final cartState = ref.read(cartProvider);
    final config = ref.read(billConfigProvider);
    final now = DateTime.now();

    try {
      await _printer.initSdk();

      if (config.orgName.isNotEmpty) {
        await _printer.printText(
            text: config.orgName, size: 28, isBold: true, align: 1);
      }
      if (config.tagline != null && config.tagline!.isNotEmpty) {
        await _printer.printText(text: config.tagline!, size: 20, align: 1);
      }
      await _printer.printText(
          text: '--------------------------------', size: 20, align: 1);

      await _printer.printText(
          text: 'Invoice: ${widget.invoiceNumber}', size: 22, align: 0);
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _printer.printText(text: dateStr, size: 20, align: 0);
      await _printer.printText(
          text: '--------------------------------', size: 20, align: 1);

      for (final item in cartState.items.values) {
        final line =
            '${item.product.name}  x${item.quantity}   Rs.${(item.product.price * item.quantity).toStringAsFixed(2)}';
        await _printer.printText(text: line, size: 22, align: 0);
      }

      await _printer.printText(
          text: '--------------------------------', size: 20, align: 1);
      await _printer.printText(
          text: 'TOTAL    Rs.${widget.amount.toStringAsFixed(2)}',
          size: 26,
          isBold: true,
          align: 0);
      await _printer.printText(text: 'Payment: CARD / Online', size: 20, align: 0);
      await _printer.printText(
          text: '--------------------------------', size: 20, align: 1);

      final footer =
          (config.footerMessage != null && config.footerMessage!.isNotEmpty)
              ? config.footerMessage!
              : 'Thank you. Visit again!';
      await _printer.printText(text: footer, size: 20, align: 1);
      await _printer.printText(text: '\n\n', size: 20, align: 1);

      await _printer.cutPaper();
    } catch (_) {
      // Non-blocking — bill screen still shown
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Card Payment',
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
          onPressed: () => context.pop(),
        ),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Amount card
                  _CardAmountHero(amount: widget.amount)
                      .animate()
                      .fadeIn(duration: 200.ms),

                  const SizedBox(height: 20),

                  // Invoice info
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          'Invoice #${widget.invoiceNumber}',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 200.ms, delay: 60.ms),

                  const SizedBox(height: 20),

                  // Accepted payment methods
                  const _AcceptedMethodsCard()
                      .animate()
                      .fadeIn(duration: 200.ms, delay: 120.ms),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFCA5A5).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2),
                  ],
                ],
              ),
            ),
          ),

          // Action footer
          _PayFooter(
            amount: widget.amount,
            isLoading: _isCreatingOrder || _isProcessingPayment,
            onPay: _startPayment,
            onCancel: () => _showCancelDialog(context),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel transaction?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'This will discard the current payment.',
          style:
              GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 14),
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
}

// ── Amount Hero Card ──────────────────────────────────────────────────────────

class _CardAmountHero extends StatelessWidget {
  final double amount;
  const _CardAmountHero({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Card chip graphic
          Row(
            children: [
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: Colors.white, size: 18),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      'SECURE',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Amount to charge',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount),
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

// ── Accepted Methods Card ─────────────────────────────────────────────────────

class _AcceptedMethodsCard extends StatelessWidget {
  const _AcceptedMethodsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accepted payment methods',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MethodPill(label: 'Credit Card', icon: Icons.credit_card_rounded),
              _MethodPill(
                  label: 'Debit Card', icon: Icons.payment_rounded),
              _MethodPill(label: 'UPI', icon: Icons.qr_code_rounded),
              _MethodPill(label: 'Net Banking', icon: Icons.account_balance_rounded),
              _MethodPill(label: 'Wallets', icon: Icons.account_balance_wallet_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.textLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Powered by Razorpay. Your card details are never stored.',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textLight),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodPill extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MethodPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
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

// ── Pay Footer ────────────────────────────────────────────────────────────────

class _PayFooter extends StatelessWidget {
  final double amount;
  final bool isLoading;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  const _PayFooter({
    required this.amount,
    required this.isLoading,
    required this.onPay,
    required this.onCancel,
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
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  disabledBackgroundColor:
                      const Color(0xFF4F46E5).withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          key: const ValueKey('btn'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.credit_card_rounded, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'Pay ${CurrencyFormatter.format(amount)}',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
