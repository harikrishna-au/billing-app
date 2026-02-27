import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/cart_provider.dart';
import '../../../../core/network/providers.dart';

class BillScreen extends ConsumerStatefulWidget {
  final String? invoiceNumber;
  final String paymentMethod;
  final double? amount;
  final DateTime? date;

  const BillScreen({
    super.key,
    this.invoiceNumber,
    required this.paymentMethod,
    this.amount,
    this.date,
  });

  @override
  ConsumerState<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends ConsumerState<BillScreen> {
  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final now = widget.date ?? DateTime.now();
    final invoiceNo = widget.invoiceNumber ??
        'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';
    final total = widget.amount ?? cartState.totalAmount;
    final isCash = widget.paymentMethod.toLowerCase() == 'cash';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Invoice',
          style: GoogleFonts.plusJakartaSans(
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
          onPressed: () {
            ref.read(cartProvider.notifier).clearCart();
            context.go('/new');
          },
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.share_outlined, color: AppColors.textSecondary, size: 22),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Share coming soon',
                      style: GoogleFonts.plusJakartaSans()),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined,
                color: AppColors.textSecondary, size: 22),
            onPressed: () async {
              final items = cartState.items.values
                  .map((i) => {
                        'name': i.product.name,
                        'quantity': i.quantity,
                        'price': i.product.price,
                      })
                  .toList();
              try {
                await ref.read(printerServiceProvider).printReceipt(
                      orderId: invoiceNo,
                      totalAmount: total,
                      date: now,
                      items: items,
                      paymentMethod: widget.paymentMethod,
                    );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Print failed: $e')));
                }
              }
            },
          ),
          const SizedBox(width: 4),
        ],
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  // Success banner
                  _SuccessBanner(total: total, isCash: isCash)
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .scale(
                          begin: const Offset(0.92, 0.92),
                          duration: 500.ms,
                          curve: Curves.easeOutBack),

                  const SizedBox(height: 20),

                  // Invoice card
                  _InvoiceCard(
                    invoiceNo: invoiceNo,
                    now: now,
                    total: total,
                    cartState: cartState,
                    paymentMethod: widget.paymentMethod,
                    isCash: isCash,
                  )
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 100.ms)
                      .slideY(begin: 0.08, end: 0),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Action buttons
          _ActionsFooter(
            onPrint: () async {
              final items = cartState.items.values
                  .map((i) => {
                        'name': i.product.name,
                        'quantity': i.quantity,
                        'price': i.product.price,
                      })
                  .toList();
              try {
                await ref.read(printerServiceProvider).printReceipt(
                      orderId: invoiceNo,
                      totalAmount: total,
                      date: now,
                      items: items,
                      paymentMethod: widget.paymentMethod,
                    );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Print failed: $e')));
                }
              }
            },
            onNewOrder: () {
              ref.read(cartProvider.notifier).clearCart();
              context.go('/new');
            },
            onViewOrders: () {
              ref.read(cartProvider.notifier).clearCart();
              context.go('/orders');
            },
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  final double total;
  final bool isCash;

  const _SuccessBanner({required this.total, required this.isCash});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            'Payment successful',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(total),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF065F46),
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCash ? 'Paid via Cash' : 'Paid via UPI / Online',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final String invoiceNo;
  final DateTime now;
  final double total;
  final CartState cartState;
  final String paymentMethod;
  final bool isCash;

  const _InvoiceCard({
    required this.invoiceNo,
    required this.now,
    required this.total,
    required this.cartState,
    required this.paymentMethod,
    required this.isCash,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INVOICE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      invoiceNo,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PAID',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // Date & method
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label:
                      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
                ),
                const SizedBox(width: 10),
                _MetaChip(
                  icon: Icons.access_time_rounded,
                  label:
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                ),
                const SizedBox(width: 10),
                _MetaChip(
                  icon: isCash
                      ? Icons.payments_rounded
                      : Icons.qr_code_rounded,
                  label: isCash ? 'Cash' : 'Online',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderLight),

          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Text(
              'ITEMS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...cartState.items.values.map(
            (ci) => Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${ci.quantity}x',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ci.product.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${CurrencyFormatter.format(ci.product.price)} each',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(ci.product.price * ci.quantity),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.borderLight),

          // Total
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(total),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
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

class _ActionsFooter extends StatelessWidget {
  final VoidCallback onPrint;
  final VoidCallback onNewOrder;
  final VoidCallback onViewOrders;

  const _ActionsFooter({
    required this.onPrint,
    required this.onNewOrder,
    required this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
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
            // Print
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  'Print Receipt',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1917),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onNewOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'New Order',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onViewOrders,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'View Orders',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
