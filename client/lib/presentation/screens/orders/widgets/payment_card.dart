import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/payment_model.dart';

class PaymentCard extends StatelessWidget {
  final Payment payment;
  final VoidCallback? onTap;

  const PaymentCard({
    super.key,
    required this.payment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final Color statusBg;
    final String statusLabel;

    switch (payment.status) {
      case PaymentStatus.success:
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        statusLabel = 'Success';
        break;
      case PaymentStatus.pending:
        statusColor = AppColors.warning;
        statusBg = AppColors.warningLight;
        statusLabel = 'Pending';
        break;
      case PaymentStatus.failed:
        statusColor = AppColors.error;
        statusBg = AppColors.error.withValues(alpha: 0.1);
        statusLabel = 'Failed';
        break;
      case PaymentStatus.cancelled:
        statusColor = const Color(0xFF92400E);
        statusBg = const Color(0xFFFFEDD5);
        statusLabel = 'Cancelled';
        break;
    }

    final isCash = payment.method == PaymentMethod.cash;
    final isCard = payment.method == PaymentMethod.card;
    final methodLabel = isCash ? 'Cash' : isCard ? 'Card' : 'UPI';
    final methodIcon = isCash
        ? Icons.payments_rounded
        : isCard
            ? Icons.credit_card_rounded
            : Icons.qr_code_rounded;
    final methodColor = isCash ? AppColors.success : AppColors.primary;
    final methodBg = isCash ? AppColors.successLight : AppColors.primaryLight;

    final formattedTime = DateFormat('hh:mm a').format(payment.createdAtLocal);
    final formattedDate = DateFormat('dd MMM').format(payment.createdAtLocal);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // ── Col 1: Bill ──────────────────────────────
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        payment.billNumber,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$formattedDate  •  $formattedTime',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Col 2: Amount ─────────────────────────────
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Amount',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.format(payment.amount),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Col 3: Type ───────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Type',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textLight,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: methodBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(methodIcon, size: 13, color: methodColor),
                            const SizedBox(width: 4),
                            Text(
                              methodLabel,
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: methodColor,
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
        ),
      ),
    );
  }
}
