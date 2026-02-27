import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/payment_provider.dart';
import '../../../../core/utils/bill_number_generator.dart';

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
  bool _isProcessingPayment = false; // Prevent duplicate submissions
  late AnimationController _pulseController;
  
  // Timer related
  int _remainingSeconds = 300; // 5 minutes = 300 seconds
  Timer? _countdownTimer;
  bool _showConfirmationButtons = false;

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
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _handlePaymentFailed();
      }
    });
  }
  
  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _upiLink {
    // Generate UPI payment link
    final invoice = widget.invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
    return 'upi://pay?pa=$_upiId&pn=YourBusinessName&am=${widget.amount}&tn=Payment for $invoice&cu=INR';
  }

  void _initiatePayment() {
    _startCountdown();
  }
  
  Future<void> _handlePaymentSuccess() async {
    // Prevent duplicate submissions
    if (_isProcessingPayment) return;
    
    _countdownTimer?.cancel();
    setState(() {
      _isWaitingForPayment = false;
      _paymentCompleted = true;
      _isProcessingPayment = true; // Lock to prevent duplicates
    });
    
    try {
      // Generate sequential bill number if not provided
      final billNumber = widget.invoiceNumber ?? await BillNumberGenerator.generate();
      
      // Create payment record
      final payment = Payment(
        id: '',
        billNumber: billNumber,
        amount: widget.amount,
        method: PaymentMethod.upi,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      final createdPayment = await ref.read(paymentProvider.notifier).createPayment(payment);

      if (createdPayment == null) {
        throw Exception('Failed to create payment');
      }

      if (!mounted) return;

      // Navigate to bill screen
      context.push(
        '/new/review/collect-payment/bill?method=online&invoice=${payment.billNumber}',
      );
    } catch (e) {
      if (!mounted) return;
      
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
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel,
                  color: Color(0xFFEF4444),
                  size: 64,
                ),
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
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Try Again',
                    style: GoogleFonts.dmSans(
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
        backgroundColor: AppColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Invoice Info
            if (widget.invoiceNumber != null)
              Text(
                'Paying for Invoice #${widget.invoiceNumber}',
                style: GoogleFonts.dmSans(
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
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms)
                .slideY(begin: 0.2, end: 0),

            const SizedBox(height: 32),

            // Payment instruction text
            if (!_showConfirmationButtons)
              Text(
                'Click "Confirm Payment" to start the payment timer',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

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
                      style: GoogleFonts.dmSans(
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

            // Countdown Timer and Confirmation Buttons
            if (_showConfirmationButtons) ...[
              // Timer Display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _remainingSeconds < 60 
                        ? const Color(0xFFEF4444).withOpacity(0.3)
                        : AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Waiting for payment confirmation',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
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
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 24),
              
              // Confirmation Buttons
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
                            color: Color(0xFFEF4444),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Payment Failed',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handlePaymentSuccess,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Payment Success',
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .slideY(begin: 0.2, end: 0),
            ] else ...[
              // Confirm Payment Button (initial state)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _paymentCompleted
                      ? null
                      : _initiatePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 22),
                  label: Text(
                    'Confirm Payment',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

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
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                    ),
                    content: Text(
                      'Are you sure you want to cancel this payment request?',
                      style: GoogleFonts.dmSans(),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'No, Keep it',
                          style: GoogleFonts.dmSans(
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
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
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
                style: GoogleFonts.dmSans(
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
