import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/payment_provider.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/utils/print_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/app_error_widget.dart';
import 'widgets/payment_processing_layer.dart';
import 'widgets/upi_payment_widgets.dart';

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

class _UpiPaymentScreenState extends ConsumerState<UpiPaymentScreen> {
  /// Prevents double-submit for the whole success flow (matches cash checkout).
  bool _paymentLocked = false;
  bool _paymentProcessingOverlay = false;
  Object? _lastError;

  String _buildUpiUrl(String upiId, String merchantName) {
    final invoice =
        widget.invoiceNumber ?? 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final name =
        Uri.encodeComponent(merchantName.isNotEmpty ? merchantName : 'Merchant');
    final note = Uri.encodeComponent('Payment for $invoice');
    return 'upi://pay?pa=$upiId&pn=$name&am=${widget.amount.toStringAsFixed(2)}&tn=$note&cu=INR';
  }

  /// Staff confirms UPI — same rhythm as cash: processing overlay → ticket booked → New Order → print.
  Future<void> _handlePaymentSuccess() async {
    if (_paymentLocked) return;
    _paymentLocked = true;

    var overlayMustClear = false;
    try {
      if (mounted) {
        setState(() => _paymentProcessingOverlay = true);
      }
      overlayMustClear = true;

      final billConfig = ref.read(billConfigProvider);
      final billNumberGen = ref.read(billNumberServiceProvider);

      final billNumber = widget.invoiceNumber ??
          billNumberGen.generatePreview(posId: billConfig.posId);

      // Lock bill number before calling backend — staff confirmed they received the payment.
      await billNumberGen.confirmBillNumber(posId: billConfig.posId);

      final payment = Payment(
        id: '',
        billNumber: billNumber,
        amount: widget.amount,
        method: PaymentMethod.upi,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      var createdPayment =
          await ref.read(paymentProvider.notifier).createPayment(payment);

      if (createdPayment == null) {
        // Backend unreachable — queue locally so it syncs when server is available.
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(syncQueueServiceProvider).enqueue({
            'machine_id': user.id,
            'bill_number': payment.billNumber,
            'amount': payment.amount,
            'method': 'UPI',
            'status': 'success',
            'created_at': payment.createdAt.toUtc().toIso8601String(),
          });
        }
        createdPayment = Payment(
          id: payment.billNumber,
          billNumber: payment.billNumber,
          amount: payment.amount,
          method: payment.method,
          status: PaymentStatus.pending,
          createdAt: payment.createdAt,
        );
      }

      if (mounted) {
        setState(() => _paymentProcessingOverlay = false);
      }
      overlayMustClear = false;

      if (!mounted) return;

      await PrintUtils.showTicketBooked(context);
      if (!mounted) return;

      final savedCart = ref.read(cartProvider);
      final goRouter = GoRouter.of(context);
      final container = ProviderScope.containerOf(context, listen: false);

      ref.read(cartProvider.notifier).clearCart();
      goRouter.go('/new');

      unawaited(
        PrintUtils.printReceipt(
          context: goRouter.routerDelegate.navigatorKey.currentContext,
          provider: container,
          billNumber: billNumber,
          total: widget.amount,
          date: createdPayment.createdAt,
          cartState: savedCart,
          paymentMethod: 'upi',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = e);
    } finally {
      if (overlayMustClear && mounted) {
        setState(() => _paymentProcessingOverlay = false);
      }
      _paymentLocked = false;
    }
  }

  /// Go back to checkout without a blocking failure dialog.
  void _handleNotReceived() {
    if (_paymentLocked) return;
    context.pop();
  }

  bool get _interactionBlocked => _paymentLocked || _paymentProcessingOverlay;

  @override
  Widget build(BuildContext context) {
    final billConfig = ref.watch(billConfigProvider);
    final upiId = billConfig.upiId ?? '';
    final merchantName = billConfig.orgName;
    final isConfigured = upiId.trim().isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Payment Request',
              style: GoogleFonts.dmSans(
                fontSize: 16,
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
              onPressed: _interactionBlocked ? null : () => context.pop(),
              color: AppColors.textPrimary,
            ),
            elevation: 0,
            backgroundColor: AppColors.background,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  children: [
                    if (widget.invoiceNumber != null)
                      Text(
                        'Invoice #${widget.invoiceNumber}',
                        style: GoogleFonts.dmSans(
                            fontSize: 11, color: AppColors.textSecondary),
                      ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹',
                          style: GoogleFonts.dmSans(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          widget.amount.toStringAsFixed(2).split('.')[0],
                          style: GoogleFonts.dmSans(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          '.${widget.amount.toStringAsFixed(2).split('.')[1]}',
                          style: GoogleFonts.dmSans(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: isConfigured
                      ? UpiPaymentQrCard(
                          upiUrl: _buildUpiUrl(upiId, merchantName),
                          upiId: upiId,
                          merchantName: merchantName,
                        )
                      : const UpiNotConfiguredBanner(),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _interactionBlocked
                                    ? null
                                    : _handleNotReceived,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: const Color(0xFFEF4444),
                                  side: const BorderSide(
                                    color: Color(0xFFEF4444),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'Not received',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _interactionBlocked
                                    ? null
                                    : _handlePaymentSuccess,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 52),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  surfaceTintColor: Colors.transparent,
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF10B981)
                                      .withValues(alpha: 0.5),
                                  disabledForegroundColor: Colors.white70,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  'Received',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _interactionBlocked
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: Text('Cancel Transaction?',
                                        style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w600)),
                                    content: Text(
                                        'Are you sure you want to cancel this payment request?',
                                        style: GoogleFonts.dmSans()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: Text('Keep it',
                                            style: GoogleFonts.dmSans(
                                                color:
                                                    AppColors.textSecondary)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          ref.read(cartProvider.notifier).clearCart();
                                          context.go('/new');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 10)),
                        child: Text(
                          'Cancel transaction',
                          style: GoogleFonts.dmSans(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),

                      if (_lastError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 4),
                          child: InlineErrorBanner(
                            error: _lastError,
                            onDismiss: () => setState(() => _lastError = null),
                          ).animate().fadeIn(duration: 200.ms),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_paymentProcessingOverlay) const PaymentProcessingLayer(),
      ],
    );
  }
}
