import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/utils/bill_number_generator.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/payment_provider.dart';
import '../../../providers/thermal_print_settings_provider.dart';
import '../../../../services/smart_pos_printer_service.dart';
import 'bill_thermal_print.dart';
import 'widgets/classic_checkout_widgets.dart';

enum _CashOverlay { none, loading, success }

class ReviewOrderScreen extends ConsumerStatefulWidget {
  const ReviewOrderScreen({super.key});

  @override
  ConsumerState<ReviewOrderScreen> createState() => _ReviewOrderScreenState();
}

class _ReviewOrderScreenState extends ConsumerState<ReviewOrderScreen> {
  /// Frozen when this screen opens so date/time on the receipt do not tick on rebuilds.
  final DateTime _checkoutOpenedAt = DateTime.now();

  _CashOverlay _cashOverlay = _CashOverlay.none;

  bool get _cashUiLocked => _cashOverlay != _CashOverlay.none;

  Future<void> _cashSuccessAndExit() async {
    if (!mounted) return;
    setState(() => _cashOverlay = _CashOverlay.success);
    await Future.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    ref.read(cartProvider.notifier).clearCart();
    context.go('/new');
  }

  Future<void> _submitCashPrintAndReturn() async {
    if (_cashUiLocked) return;
    final cartState = ref.read(cartProvider);
    if (cartState.totalItems <= 0) return;

    setState(() => _cashOverlay = _CashOverlay.loading);

    try {
      final total = cartState.totalAmount;
      final billConfig = ref.read(billConfigProvider);

      // Cashier confirmed receipt — reserve the bill number from the server.
      final billNumber = await ref
          .read(paymentProvider.notifier)
          .acquireBillNumber(posId: billConfig.posId);

      final payment = Payment(
        id: '',
        billNumber: billNumber,
        amount: total,
        method: PaymentMethod.cash,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      final created =
          await ref.read(paymentProvider.notifier).createPayment(payment);
      if (created == null) {
        // Backend unreachable — queue so it syncs later; cash is already collected.
        final user = ref.read(authProvider).user;
        if (user != null) {
          await ref.read(syncQueueServiceProvider).enqueue({
            'machine_id': user.id,
            'bill_number': payment.billNumber,
            'amount': payment.amount,
            'method': 'CASH',
            'status': 'success',
            'created_at': payment.createdAt.toUtc().toIso8601String(),
          });
        }
      }
      if (!mounted) return;

      final tracker = ref.read(printedBillsTrackerProvider);
      if (tracker.hasBeenPrinted(billNumber)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Bill ${BillNumberGenerator.displayTicketNumber(billNumber)} was already printed.',
              ),
            ),
          );
        }
        await _cashSuccessAndExit();
        return;
      }

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
        final dateLocal = DateTime.now().toLocal();
        final settings = ref.read(thermalPrintSettingsProvider);
        await printBillThermalInvoiceAndTicket(
          printer: SmartPosPrinterService(),
          config: config,
          billDisplay: billDisplay,
          dateTime: dateLocal,
          cartState: cartState,
          total: total,
          taxableAmount: taxableAmount,
          cgstAmount: cgstAmount,
          sgstAmount: sgstAmount,
          hasTax: hasTax,
          paymentMethod: 'cash',
          settings: settings,
        );
        await tracker.markAsPrinted(billNumber);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Print failed: $e')),
          );
        }
      }

      await _cashSuccessAndExit();
    } catch (e) {
      if (mounted) {
        setState(() => _cashOverlay = _CashOverlay.none);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  Widget _buildCashOverlay() {
    final isSuccess = _cashOverlay == _CashOverlay.success;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: isSuccess
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 76,
                        color: AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Booked',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  )
                : const SizedBox(
                    width: 44,
                    height: 44,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.2,
                      color: AppColors.primary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Checkout',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, size: 22),
              onPressed: _cashUiLocked ? null : () => context.pop(),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: ClassicCheckoutReceiptCard(
                    cartState: cartState,
                    now: _checkoutOpenedAt,
                  ),
                ),
              ),
              ClassicCheckoutPaymentBar(
                hasItems: cartState.totalItems > 0,
                cartTotal: cartState.totalAmount,
                cashBusy: _cashUiLocked,
                onCashDirect: _submitCashPrintAndReturn,
              ),
            ],
          ),
        ),
        if (_cashOverlay != _CashOverlay.none) _buildCashOverlay(),
      ],
    );
  }
}
