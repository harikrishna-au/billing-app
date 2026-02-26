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

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    // Calculate totals
    // Calculate totals
    final subtotal = cartState.totalAmount;
    final total = subtotal;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Collect Payment',
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
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Amount to Collect Card
                  _AmountCard(totalAmount: total)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 20),

                  // Payment Method Badge
                  _PaymentMethodBadge(method: widget.paymentMethod)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 100.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // Item Summary Section
                  _ItemSummarySection(
                    cartState: cartState,
                    subtotal: subtotal,
                    total: total,
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: 200.ms)
                      .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // Payment Confirmation Note
                  if (widget.paymentMethod == 'cash')
                    _ConfirmationNote(amount: total)
                        .animate()
                        .fadeIn(duration: 300.ms, delay: 300.ms)
                        .slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Action Buttons Footer
          _ActionButtonsFooter(
            paymentMethod: widget.paymentMethod,
            totalAmount: total,
            isProcessing: _isProcessing,
            onConfirm: () => _handleConfirmPayment(context),
            onCancel: () => _handleCancelTransaction(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmPayment(BuildContext context) async {
    // If online payment, show coming soon message
    // If online payment
    if (widget.paymentMethod == 'online') {
      // Prevent duplicate submissions
      if (_isProcessing) return;

      setState(() => _isProcessing = true);
      try {
        final cartState = ref.read(cartProvider);
        final total = cartState.totalAmount;

        final orderId = 'ORDER_${DateTime.now().millisecondsSinceEpoch}';

        // For online payment, navigate to UPI payment screen
        if (!mounted) return;
        setState(() => _isProcessing = false);

        // Navigate to UPI payment screen
        context.push(
            '/new/review/collect-payment/upi?amount=$total&invoice=$orderId');
      } catch (e) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Failed: ${e.toString()}')),
        );
      }
      return;
    }

    // For cash payment, create payment record
    // Prevent duplicate submissions
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final cartState = ref.read(cartProvider);
      final subtotal = cartState.totalAmount;
      final total = subtotal;

      // Generate sequential bill number
      final billNumber = await BillNumberGenerator.generate();

      // Determine payment method enum
      PaymentMethod method;
      if (widget.paymentMethod == 'cash') {
        method = PaymentMethod.cash;
      } else if (widget.paymentMethod == 'card') {
        method = PaymentMethod.card;
      } else {
        method = PaymentMethod.upi;
      }

      // Create payment object
      await _createPaymentRecord(context, total, method, billNumber);

      // Print Receipt
      try {
        final printerService = SmartPosPrinterService();
        await printerService.initSdk();

        await printerService.printText(
            text: "BILL KARO\n", size: 30, isBold: true, align: 1);
        await printerService.printText(
            text: "Bill No: $billNumber\n", size: 24, align: 0);
        await printerService.printText(
            text: "Date: ${DateTime.now().toString().substring(0, 16)}\n",
            size: 24,
            align: 0);
        await printerService.printText(
            text: "--------------------------------\n", size: 24, align: 1);
        await printerService.printText(
            text: "Amount: ${CurrencyFormatter.format(total)}\n",
            size: 30,
            isBold: true,
            align: 1);
        await printerService.printText(
            text: "Method: ${method.name.toUpperCase()}\n", size: 24, align: 1);
        await printerService.printText(
            text: "--------------------------------\n", size: 24, align: 1);
        await printerService.printText(
            text: "Thank you!\n\n\n\n", size: 24, align: 1);
      } catch (e) {
        print("Printing failed: $e");
        // Don't block navigation if printing fails
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isProcessing = false);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
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

    final createdPayment =
        await ref.read(paymentProvider.notifier).createPayment(payment);

    if (createdPayment == null) {
      throw Exception('Failed to create payment');
    }

    if (!mounted) return;

    setState(() => _isProcessing = false);

    context.push(
      '/new/review/collect-payment/bill?method=${widget.paymentMethod}&invoice=${payment.billNumber}',
    );
  }

  void _handleCancelTransaction(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Cancel Transaction?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to cancel this transaction?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'No, Keep it',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
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
  }
}

class _AmountCard extends StatelessWidget {
  final double totalAmount;

  const _AmountCard({required this.totalAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'AMOUNT TO COLLECT',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.format(totalAmount),
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          /*
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Including all taxes',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          */
        ],
      ),
    );
  }
}

class _PaymentMethodBadge extends StatelessWidget {
  final String method;

  const _PaymentMethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isCash = method == 'cash';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCash
              ? const Color(0xFF10B981).withOpacity(0.3)
              : AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCash
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCash ? Icons.payments_outlined : Icons.qr_code_scanner_rounded,
              color: isCash ? const Color(0xFF10B981) : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Method',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCash ? 'Cash Payment' : 'UPI / Online Payment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCash
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isCash ? 'CASH' : 'ONLINE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isCash ? const Color(0xFF10B981) : AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSummarySection extends StatelessWidget {
  final CartState cartState;
  final double subtotal;
  final double total;

  const _ItemSummarySection({
    required this.cartState,
    required this.subtotal,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Order Summary',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(
                'Edit',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Items List
              ...cartState.items.values.map((cartItem) => _OrderItemRow(
                    name: cartItem.product.name,
                    quantity: cartItem.quantity,
                    price: cartItem.product.price * cartItem.quantity,
                  )),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),

              // Bill Breakdown
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _BillRow('Subtotal', subtotal),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(total),
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final String name;
  final int quantity;
  final double price;

  const _OrderItemRow({
    required this.name,
    required this.quantity,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Qty: $quantity',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyFormatter.format(price),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final double amount;

  const _BillRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          CurrencyFormatter.format(amount),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ConfirmationNote extends StatelessWidget {
  final double amount;

  const _ConfirmationNote({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFBBF24).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirmation Required',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'By clicking "Confirm Cash Received", you acknowledge that you have physically received ${CurrencyFormatter.format(amount)} in cash.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF92400E),
                    height: 1.4,
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

class _ActionButtonsFooter extends StatelessWidget {
  final String paymentMethod;
  final double totalAmount;
  final bool isProcessing;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ActionButtonsFooter({
    required this.paymentMethod,
    required this.totalAmount,
    required this.isProcessing,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
            // Primary Action Button
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF10B981).withOpacity(0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, size: 24),
                          const SizedBox(width: 12),
                          Text(
                            paymentMethod == 'cash'
                                ? 'Confirm Cash Received'
                                : 'Confirm Payment',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Cancel Transaction Button
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                'Cancel Transaction',
                style: GoogleFonts.inter(
                  fontSize: 14,
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
