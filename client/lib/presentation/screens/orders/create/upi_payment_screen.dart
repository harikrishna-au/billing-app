import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

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
  bool _isWaitingForPayment = false;
  bool _paymentCompleted = false;
  late AnimationController _pulseController;

  // UPI ID for payment (replace with your actual UPI ID)
  final String _upiId = 'merchant@upi';

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
    super.dispose();
  }

  String get _upiLink {
    // Generate UPI payment link
    final invoice = widget.invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
    return 'upi://pay?pa=$_upiId&pn=YourBusinessName&am=${widget.amount}&tn=Payment for $invoice&cu=INR';
  }

  void _initiatePayment() {
    setState(() => _isWaitingForPayment = true);

    // Simulate payment verification (replace with actual API call)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isWaitingForPayment = false;
          _paymentCompleted = true;
        });

        // Show success dialog
        _showPaymentSuccessDialog();
      }
    });
  }

  void _showPaymentSuccessDialog() {
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 64,
                ),
              )
                  .animate()
                  .scale(duration: 300.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'Payment Successful!',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                CurrencyFormatter.format(widget.amount),
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
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
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Payment Request',
          style: GoogleFonts.poppins(
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
                  color: Colors.black.withOpacity(0.05),
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
        backgroundColor: const Color(0xFFF8FAFC),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Invoice Info
            if (widget.invoiceNumber != null)
              Text(
                'Paying for Invoice #${widget.invoiceNumber}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 16),

            // Amount Display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    widget.amount.toStringAsFixed(2).split('.')[0],
                    style: GoogleFonts.poppins(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '.${widget.amount.toStringAsFixed(2).split('.')[1]}',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 32),

            // QR Code Card
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: QrImageView(
                      data: _upiLink,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'SCAN & PAY',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

            const SizedBox(height: 32),

            // UPI Apps Section
            Text(
              'SUPPORTED UPI APPS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _UpiAppIcon(
                  name: 'GPay',
                  color: const Color(0xFF4285F4),
                  icon: Icons.payment,
                  onTap: _initiatePayment,
                ),
                const SizedBox(width: 20),
                _UpiAppIcon(
                  name: 'PhonePe',
                  color: const Color(0xFF5F259F),
                  icon: Icons.phone_android,
                  onTap: _initiatePayment,
                ),
                const SizedBox(width: 20),
                _UpiAppIcon(
                  name: 'Paytm',
                  color: const Color(0xFF00BAF2),
                  icon: Icons.account_balance_wallet,
                  onTap: _initiatePayment,
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 300.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 32),

            // Payment Status
            if (_isWaitingForPayment)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Waiting for payment...',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              )
                  .animate(
                    onPlay: (controller) => controller.repeat(),
                  )
                  .fadeIn(duration: 600.ms)
                  .then()
                  .shimmer(duration: 1500.ms, color: Colors.white),

            const SizedBox(height: 24),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _paymentCompleted || _isWaitingForPayment
                    ? null
                    : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E7FF),
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xFFE0E7FF).withOpacity(0.5),
                  disabledForegroundColor: AppColors.primary.withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  _paymentCompleted
                      ? Icons.check_circle
                      : Icons.receipt_long_outlined,
                  size: 22,
                ),
                label: Text(
                  _paymentCompleted ? 'Payment Received' : 'Generate Bill',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: Text(
                      'Cancel Transaction?',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    content: Text(
                      'Are you sure you want to cancel this payment request?',
                      style: GoogleFonts.inter(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'No, Keep it',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Yes, Cancel',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Cancel Transaction',
                style: GoogleFonts.inter(
                  fontSize: 15,
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

class _UpiAppIcon extends StatelessWidget {
  final String name;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _UpiAppIcon({
    required this.name,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.inter(
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
