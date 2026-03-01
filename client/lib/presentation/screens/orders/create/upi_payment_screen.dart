import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/payment_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../providers/upi_settings_provider.dart';
import '../../../../core/network/providers.dart';
import '../../../../services/smart_pos_printer_service.dart';

class UpiPaymentScreen extends ConsumerStatefulWidget {
  final double amount;
  final String? invoiceNumber;

  const UpiPaymentScreen({
    super.key,
    required this.amount,
    this.invoiceNumber,
  });

  @override
  ConsumerState<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends ConsumerState<UpiPaymentScreen>
    with TickerProviderStateMixin {
  bool _paymentCompleted = false;
  bool _isProcessingPayment = false;
  late AnimationController _pulseController;

  int _remainingSeconds = 300;
  Timer? _countdownTimer;
  bool _showConfirmationButtons = false;

  final _printer = SmartPosPrinterService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _showConfirmationButtons = true;
      _remainingSeconds = 300;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _handlePaymentFailed();
      }
    });
  }

  String get _formattedTime {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _buildUpiUrl(UpiSettings upi) {
    final invoice =
        widget.invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final merchantName =
        Uri.encodeComponent(upi.merchantName.isNotEmpty ? upi.merchantName : 'Merchant');
    final note = Uri.encodeComponent('Payment for $invoice');
    return 'upi://pay?pa=${upi.upiId}&pn=$merchantName&am=${widget.amount.toStringAsFixed(2)}&tn=$note&cu=INR';
  }

  Future<void> _printReceipt(String billNumber) async {
    final cartState = ref.read(cartProvider);
    final config = ref.read(billConfigProvider);
    final now = DateTime.now();

    try {
      await _printer.initSdk();

      // Header
      if (config.orgName.isNotEmpty) {
        await _printer.printText(text: config.orgName, size: 28, isBold: true, align: 1);
      }
      if (config.tagline != null && config.tagline!.isNotEmpty) {
        await _printer.printText(text: config.tagline!, size: 20, align: 1);
      }
      await _printer.printText(text: '--------------------------------', size: 20, align: 1);

      // Invoice info
      await _printer.printText(text: 'Invoice: $billNumber', size: 22, align: 0);
      final dateStr =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _printer.printText(text: dateStr, size: 20, align: 0);
      await _printer.printText(text: '--------------------------------', size: 20, align: 1);

      // Items
      for (final item in cartState.items.values) {
        final line =
            '${item.product.name}  x${item.quantity}   Rs.${(item.product.price * item.quantity).toStringAsFixed(2)}';
        await _printer.printText(text: line, size: 22, align: 0);
      }

      await _printer.printText(text: '--------------------------------', size: 20, align: 1);

      // Total
      await _printer.printText(
          text: 'TOTAL    Rs.${widget.amount.toStringAsFixed(2)}',
          size: 26,
          isBold: true,
          align: 0);
      await _printer.printText(text: 'Payment: UPI / Online', size: 20, align: 0);
      await _printer.printText(text: '--------------------------------', size: 20, align: 1);

      // Footer
      final footer = (config.footerMessage != null && config.footerMessage!.isNotEmpty)
          ? config.footerMessage!
          : 'Thank you. Visit again!';
      await _printer.printText(text: footer, size: 20, align: 1);
      await _printer.printText(text: '\n\n', size: 20, align: 1);

      await _printer.cutPaper();
    } catch (_) {
      // Print failure is non-blocking — bill screen is still shown
    }
  }

  Future<void> _handlePaymentSuccess() async {
    if (_isProcessingPayment) return;
    _countdownTimer?.cancel();
    setState(() {
      _showConfirmationButtons = false;
      _paymentCompleted = true;
      _isProcessingPayment = true;
    });

    try {
      // invoiceNumber is always pre-generated by CollectPaymentScreen.
      // The fallback generates a new number only if navigated to directly.
      final billNumber = widget.invoiceNumber ??
          await ref.read(billNumberServiceProvider).generate();

      final payment = Payment(
        id: '',
        billNumber: billNumber,
        amount: widget.amount,
        method: PaymentMethod.upi,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      final createdPayment =
          await ref.read(paymentProvider.notifier).createPayment(payment);

      if (createdPayment == null) throw Exception('Failed to create payment');

      // Auto-print receipt on the POS thermal printer
      await _printReceipt(billNumber);

      if (!mounted) return;

      context.push(
        '/new/review/collect-payment/bill?method=online&invoice=$billNumber',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handlePaymentFailed() {
    _countdownTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 64),
              ),
              const SizedBox(height: 24),
              Text(
                'Payment Failed',
                style: GoogleFonts.dmSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The payment was not completed',
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Try Again',
                      style: GoogleFonts.dmSans(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upiSettings = ref.watch(upiSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Payment Request',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          onPressed: () => context.pop(),
          color: AppColors.textPrimary,
        ),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Invoice info
            if (widget.invoiceNumber != null)
              Text(
                'Invoice #${widget.invoiceNumber}',
                style: GoogleFonts.dmSans(
                    fontSize: 14, color: AppColors.textSecondary),
              ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 12),

            // Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₹',
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                Text(
                  widget.amount.toStringAsFixed(2).split('.')[0],
                  style: GoogleFonts.dmSans(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                Text(
                  '.${widget.amount.toStringAsFixed(2).split('.')[1]}',
                  style: GoogleFonts.dmSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 24),

            // QR Code section
            if (!upiSettings.isConfigured)
              _UpiNotConfiguredBanner()
            else
              _QrCard(upiUrl: _buildUpiUrl(upiSettings), upi: upiSettings),

            const SizedBox(height: 28),

            // Countdown + confirmation buttons
            if (_showConfirmationButtons) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _remainingSeconds < 60
                        ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Waiting for customer to pay',
                      style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formattedTime,
                      style: GoogleFonts.dmSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: _remainingSeconds < 60
                            ? const Color(0xFFEF4444)
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Time remaining',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handlePaymentFailed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFEF4444),
                          elevation: 0,
                          side: const BorderSide(
                              color: Color(0xFFEF4444), width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Not Received',
                          style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isProcessingPayment
                            ? null
                            : _handlePaymentSuccess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isProcessingPayment
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : Text(
                                'Received ✓',
                                style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _paymentCompleted ? null : _startCountdown,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    'Customer is Scanning — Start Timer',
                    style: GoogleFonts.dmSans(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Text('Cancel Transaction?',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                    content: Text(
                        'Are you sure you want to cancel this payment request?',
                        style: GoogleFonts.dmSans()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Keep it',
                            style: GoogleFonts.dmSans(
                                color: AppColors.textSecondary)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              },
              style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Text(
                'Cancel Transaction',
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── QR Card ────────────────────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  final String upiUrl;
  final UpiSettings upi;

  const _QrCard({required this.upiUrl, required this.upi});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Merchant name + UPI badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_rounded,
                        size: 14, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 5),
                    Text(
                      'UPI',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (upi.merchantName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              upi.merchantName,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],

          const SizedBox(height: 4),
          Text(
            upi.upiId,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 18),

          // QR code
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  width: 2),
            ),
            child: QrImageView(
              data: upiUrl,
              version: QrVersions.auto,
              size: 200,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF7C3AED),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1E1B2E),
              ),
            ),
          ),

          const SizedBox(height: 14),
          Text(
            'Scan with any UPI app to pay',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _UpiAppPill('GPay'),
              const SizedBox(width: 8),
              _UpiAppPill('PhonePe'),
              const SizedBox(width: 8),
              _UpiAppPill('Paytm'),
              const SizedBox(width: 8),
              _UpiAppPill('BHIM'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.15, end: 0);
  }
}

class _UpiAppPill extends StatelessWidget {
  final String name;
  const _UpiAppPill(this.name);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        name,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ── UPI not configured banner ───────────────────────────────────────────────

class _UpiNotConfiguredBanner extends StatelessWidget {
  const _UpiNotConfiguredBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF97316), size: 36),
          const SizedBox(height: 10),
          Text(
            'UPI not configured',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9A3412),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Go to Settings \u2192 UPI Settings and add your UPI ID to generate a payment QR.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF9A3412),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
