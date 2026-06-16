import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/constants/plutus_config.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../providers/payment_provider.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/utils/print_utils.dart';
import '../../../../core/services/plutus_smart_service.dart';
import '../../../widgets/confirm_payment_dialog.dart';
import 'widgets/checkout_bill_receipt.dart';
import 'widgets/checkout_payment_methods.dart';
import 'widgets/payment_processing_layer.dart';

String _checkoutErrorText(Object e) {
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
  return s;
}

class POSCheckoutScreen extends ConsumerStatefulWidget {
  const POSCheckoutScreen({super.key});

  @override
  ConsumerState<POSCheckoutScreen> createState() => _POSCheckoutScreenState();
}

class _POSCheckoutScreenState extends ConsumerState<POSCheckoutScreen> {
  /// Prevents double-submit; no spinner overlay during payment or printing.
  bool _paymentLocked = false;
  String? _lastError;

  /// In-scaffold overlay (not a [Navigator] route) so it cannot stay stuck above `/new` after pop.
  bool _paymentProcessingOverlay = false;

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final total = cartState.totalAmount;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildScaffold(context, cartState, total, isMobile),
        if (_paymentProcessingOverlay) const PaymentProcessingLayer(),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context, CartState cartState, double total, bool isMobile) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _paymentProcessingOverlay ? null : () => context.pop(),
        ),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: isMobile
          ? _buildMobileLayout(context, cartState, total)
          : _buildDesktopLayout(context, cartState, total),
    );
  }

  Widget _buildMobileLayout(BuildContext context, CartState cartState, double total) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CheckoutBillReceipt(cartState: cartState, total: total),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(
                top: BorderSide(color: AppColors.borderLight, width: 1),
              ),
            ),
            child: _buildPaymentMethods(context, cartState, total),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context, CartState cartState, double total) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 10, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CheckoutBillReceipt(cartState: cartState, total: total),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 8, 20, 20),
            child: _buildPaymentMethods(context, cartState, total),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods(BuildContext context, CartState cartState, double total) {
    final plutusConfigured = PlutusConfig.isConfigured;
    return CheckoutPaymentMethods(
      isProcessing: false,
      lastError: _lastError,
      onErrorDismissed: () => setState(() => _lastError = null),
      onPayCash: () => _showCashConfirmPaymentDialog(context, total),
      onPayUpi: () => plutusConfigured
          ? unawaited(_handlePlutusUpiPayment(total))
          : _pushUpiPayment(context, total),
      cardEnabled: plutusConfigured,
      onPayCard: () => plutusConfigured
          ? unawaited(_handleCardPayment(total))
          : setState(
              () => _lastError = 'Card via Plutus is not configured on this build.',
            ),
      onCancel: () => _handleCancel(context),
    );
  }

  Future<void> _handlePlutusUpiPayment(double total) async {
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
      final billNumber = billNumberGen.generatePreview(posId: billConfig.posId);

      if (!PlutusConfig.isConfigured) {
        throw Exception('Plutus ApplicationId not configured');
      }

      await PlutusSmartService.bindToService();

      final amountPaise = (total * 100).round();
      final payload = PlutusRequestBuilder.upiSale(
        applicationId: PlutusConfig.applicationId.trim(),
        versionNo: PlutusConfig.apiVersion,
        userId: PlutusConfig.userId.trim().isEmpty ? null : PlutusConfig.userId.trim(),
        billingRefNo: billNumber,
        paymentAmountPaise: amountPaise,
      );

      String? raw = await PlutusSmartService.startTransaction(transactionJson: payload);
      PlutusResponse parsed = PlutusResponse.tryParse(raw);

      // If Plutus asks to check status, poll a few times.
      if (parsed.isInitiatedNeedsStatus) {
        for (var i = 0; i < 6; i++) {
          await Future.delayed(const Duration(seconds: 3));
          final statusPayload = PlutusRequestBuilder.upiGetStatus(
            applicationId: PlutusConfig.applicationId.trim(),
            versionNo: PlutusConfig.apiVersion,
            userId: PlutusConfig.userId.trim().isEmpty ? null : PlutusConfig.userId.trim(),
            billingRefNo: billNumber,
            paymentAmountPaise: amountPaise,
          );
          raw = await PlutusSmartService.startTransaction(transactionJson: statusPayload);
          parsed = PlutusResponse.tryParse(raw);
          if (parsed.isApproved) break;
          if (!parsed.isInitiatedNeedsStatus) break;
        }
      }

      if (!parsed.isApproved) {
        throw Exception(parsed.responseMsg ?? 'UPI transaction not approved');
      }

      final payment = Payment(
        id: '',
        billNumber: billNumber,
        amount: total,
        method: PaymentMethod.upi,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      final created = await ref.read(paymentProvider.notifier).createPayment(payment);
      if (created == null) {
        final reason = ref.read(paymentProvider).error ??
            'Payment could not be confirmed. Check connection and try again.';
        throw Exception(reason);
      }

      await billNumberGen.confirmBillNumber(posId: billConfig.posId);

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
          total: total,
          date: created.createdAt,
          cartState: savedCart,
          paymentMethod: PaymentMethod.upi.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = _checkoutErrorText(e));
    } finally {
      if (overlayMustClear && mounted) {
        setState(() => _paymentProcessingOverlay = false);
      }
      _paymentLocked = false;
    }
  }

  Future<void> _handleCardPayment(double total) async {
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
      final billNumber = billNumberGen.generatePreview(posId: billConfig.posId);

      if (!PlutusConfig.isConfigured) {
        throw Exception('Plutus ApplicationId not configured');
      }

      await PlutusSmartService.bindToService();

      final payload = PlutusRequestBuilder.sale(
        applicationId: PlutusConfig.applicationId.trim(),
        versionNo: PlutusConfig.apiVersion,
        userId: PlutusConfig.userId.trim().isEmpty ? null : PlutusConfig.userId.trim(),
        billingRefNo: billNumber,
        paymentAmountPaise: (total * 100).round(),
      );

      final raw = await PlutusSmartService.startTransaction(transactionJson: payload);
      final parsed = PlutusResponse.tryParse(raw);
      if (!parsed.isApproved) {
        throw Exception(parsed.responseMsg ?? 'Card transaction declined');
      }

      final payment = Payment(
        id: '',
        billNumber: billNumber,
        amount: total,
        method: PaymentMethod.card,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      final created = await ref.read(paymentProvider.notifier).createPayment(payment);
      if (created == null) {
        final reason = ref.read(paymentProvider).error ??
            'Payment could not be confirmed. Check connection and try again.';
        throw Exception(reason);
      }

      await billNumberGen.confirmBillNumber(posId: billConfig.posId);

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
          total: total,
          date: created.createdAt,
          cartState: savedCart,
          paymentMethod: PaymentMethod.card.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = _checkoutErrorText(e));
    } finally {
      if (overlayMustClear && mounted) {
        setState(() => _paymentProcessingOverlay = false);
      }
      _paymentLocked = false;
    }
  }

  void _handleCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel transaction?',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        content: Text(
          'This will discard the current order and clear your cart.',
          style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep it',
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clearCart();
              context.pop();
            },
            child: Text('Cancel',
                style: GoogleFonts.dmSans(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  /// Opens the dedicated UPI screen (QR + timer). Does not record payment until staff confirms.
  void _pushUpiPayment(BuildContext context, double total) {
    ref.read(paymentProvider.notifier).clearPaymentError();
    if (mounted) setState(() => _lastError = null);

    final billConfig = ref.read(billConfigProvider);
    final billNumberGen = ref.read(billNumberServiceProvider);
    final preview = billNumberGen.generatePreview(posId: billConfig.posId);
    final location = Uri(
      path: '/new/review/upi',
      queryParameters: {
        'amount': total.toStringAsFixed(2),
        'invoice': preview,
      },
    ).toString();
    context.push(location);
  }

  Future<void> _showCashConfirmPaymentDialog(
    BuildContext context,
    double total,
  ) async {
    ref.read(paymentProvider.notifier).clearPaymentError();
    if (mounted) setState(() => _lastError = null);

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => ConfirmPaymentDialog(
        amount: total,
        method: PaymentMethod.cash,
        isProcessing: false,
        onConfirm: () {
          Navigator.of(ctx, rootNavigator: true).pop();
          // Run payment after confirm route is gone so overlay stacks correctly.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_handleCashPayment(total));
          });
        },
        onCancel: () => Navigator.of(ctx, rootNavigator: true).pop(),
      ),
    );
  }

  Future<void> _handleCashPayment(double total) async {
    if (_paymentLocked) return;
    _paymentLocked = true;

    /// True until we hide the overlay after the server records payment (not after thermal print).
    var overlayMustClear = false;
    final cartNotifier = ref.read(cartProvider.notifier);
    try {
      if (mounted) {
        setState(() => _paymentProcessingOverlay = true);
      }
      overlayMustClear = true;

      if (mounted) {
        setState(() => _lastError = null);
      }

      final billConfig = ref.read(billConfigProvider);

      final billNumberGen = ref.read(billNumberServiceProvider);
      final billNumber = billNumberGen.generatePreview(posId: billConfig.posId);

      final savedCart = ref.read(cartProvider);

      final payment = Payment(
        id: '',
        billNumber: billNumber,
        amount: total,
        method: PaymentMethod.cash,
        status: PaymentStatus.success,
        createdAt: DateTime.now(),
      );

      final created = await ref.read(paymentProvider.notifier).createPayment(payment);
      if (created == null) {
        final reason = ref.read(paymentProvider).error ??
            'Payment could not be confirmed. Check connection and try again.';
        throw Exception(reason);
      }

      await billNumberGen.confirmBillNumber(posId: billConfig.posId);

      // Hide "Processing payment" as soon as payment is saved. Thermal SDK can block a long time;
      // keeping the overlay until print finished is what left users stuck on checkout.
      if (mounted) {
        setState(() => _paymentProcessingOverlay = false);
      }
      overlayMustClear = false;

      if (!mounted) return;

      // Ticket UI must run before thermal print: the POS SDK often blocks the UI thread
      // for a long time, which prevented the dialog from ever appearing.
      await PrintUtils.showTicketBooked(context);
      if (!mounted) return;

      // Capture before navigation — checkout will dispose after [go].
      final goRouter = GoRouter.of(context);
      final container = ProviderScope.containerOf(context, listen: false);

      cartNotifier.clearCart();
      goRouter.go('/new');

      unawaited(
        PrintUtils.printReceipt(
          context: goRouter.routerDelegate.navigatorKey.currentContext,
          provider: container,
          billNumber: billNumber,
          total: total,
          date: created.createdAt,
          cartState: savedCart,
          paymentMethod: PaymentMethod.cash.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastError = _checkoutErrorText(e));
    } finally {
      if (overlayMustClear && mounted) {
        setState(() => _paymentProcessingOverlay = false);
      }
      _paymentLocked = false;
    }
  }
}
