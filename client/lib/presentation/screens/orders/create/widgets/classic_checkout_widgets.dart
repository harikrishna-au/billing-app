import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../config/theme/app_colors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../providers/bill_config_provider.dart';
import '../../../../providers/cart_provider.dart';
import '../receipt_layout_spec.dart';

/// Receipt-style summary matching classic POS checkout layout.
class ClassicCheckoutReceiptCard extends ConsumerWidget {
  final CartState cartState;
  final DateTime now;

  const ClassicCheckoutReceiptCard({
    super.key,
    required this.cartState,
    required this.now,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(billConfigProvider);
    final total = cartState.totalAmount;
    final cgstRate = config.cgstPercent / 100;
    final sgstRate = config.sgstPercent / 100;
    final taxRate = cgstRate + sgstRate;
    final subTotal = taxRate > 0 ? total / (1 + taxRate) : total;
    final taxAmount = (total - subTotal).clamp(0.0, double.infinity);
    const discount = 0.0;

    final local = now.toLocal();
    final dateStr =
        '${local.day.toString().padLeft(2, '0')}-${local.month.toString().padLeft(2, '0')}-${local.year}';
    final timeStr =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';

    final items = cartState.itemList;

    if (items.isEmpty) {
      return Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No items in this order.\nGo back to add items.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header: matches thermal bill header ──────────────────────
            if (config.orgName.isNotEmpty) ...[
              Text(
                config.orgName,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              'INVOICE',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            if (config.unitName != null && config.unitName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                config.unitName!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if ((config.gstNumber != null && config.gstNumber!.isNotEmpty) ||
                (config.posId != null && config.posId!.isNotEmpty)) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (config.gstNumber != null && config.gstNumber!.isNotEmpty)
                    'GSTIN: ${config.gstNumber}',
                  if (config.posId != null && config.posId!.isNotEmpty)
                    'POS: ${config.posId}',
                ].join(' / '),
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            Text(
              'Date: $dateStr',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Time: $timeStr',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _tableHeader(),
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 4),
            ...items
                .map((ci) => _tableRow(ci.quantity, ci.product.name, ci.total)),
            const SizedBox(height: 16),
            _totalLine('Taxable Value', subTotal),
            _totalLine('Discount', discount),
            _totalLine('Tax', taxAmount),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: ReceiptLayoutSpec.screenSummaryLabelWidth,
                  child: Text(
                    'To pay : ',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: ReceiptLayoutSpec.screenSummaryValueWidth,
                  child: Text(
                    CurrencyFormatter.format(total),
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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

  Widget _tableHeader() {
    return Row(
      children: [
        SizedBox(
          width: ReceiptLayoutSpec.screenQtyWidth,
          child: Text(
            'QTY',
            textAlign: TextAlign.left,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'ITEM NAME',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SizedBox(
          width: ReceiptLayoutSpec.screenPriceWidth,
          child: Text(
            'PRICE',
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableRow(int qty, String name, double lineTotal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ReceiptLayoutSpec.screenQtyWidth,
            child: Text(
              '$qty',
              textAlign: TextAlign.left,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: ReceiptLayoutSpec.screenPriceWidth,
            child: Text(
              CurrencyFormatter.format(lineTotal),
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: ReceiptLayoutSpec.screenSummaryLabelWidth,
            child: Text(
              '$label :',
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: ReceiptLayoutSpec.screenSummaryValueWidth,
            child: Text(
              CurrencyFormatter.format(amount),
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom CASH / UPI / CARD / CANCEL bar from classic POS checkout.
class ClassicCheckoutPaymentBar extends StatelessWidget {
  final bool hasItems;
  final double cartTotal;
  final bool cashBusy;
  final Future<void> Function() onCashDirect;

  const ClassicCheckoutPaymentBar({
    super.key,
    required this.hasItems,
    required this.cartTotal,
    required this.cashBusy,
    required this.onCashDirect,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: _PayTile(
              label: 'CASH',
              icon: Icons.payments_outlined,
              background: const Color(0xFF22C55E),
              enabled: !cashBusy,
              onTap: () => _cashTap(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PayTile(
              label: 'UPI',
              icon: Icons.qr_code_2_outlined,
              background: const Color(0xFF0F172A),
              onTap: () => _pay(context, hasItems, () {
                context.push(
                  '/new/review/collect-payment/upi?amount=$cartTotal',
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PayTile(
              label: 'CARD',
              icon: Icons.credit_card_outlined,
              background: const Color(0xFF3B82F6),
              onTap: () {
                if (!hasItems) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Add at least one item to continue')),
                  );
                  return;
                }
                // Card checkout mocked: no second screen / Razorpay for now.
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PayTile(
              label: 'CANCEL',
              icon: Icons.close,
              background: const Color(0xFFEF4444),
              onTap: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  void _cashTap(BuildContext context) {
    if (!hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to continue')),
      );
      return;
    }
    if (cashBusy) return;
    onCashDirect();
  }

  void _pay(BuildContext context, bool hasItems, VoidCallback go) {
    if (!hasItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to continue')),
      );
      return;
    }
    go();
  }
}

class _PayTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final VoidCallback onTap;
  final bool enabled;

  const _PayTile({
    required this.label,
    required this.icon,
    required this.background,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: AspectRatio(
            aspectRatio: 0.92,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
