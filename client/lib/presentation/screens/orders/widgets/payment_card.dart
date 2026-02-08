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
    // Determine status colors
    Color statusText;
    Color statusBg;

    switch (payment.status) {
      case PaymentStatus.success:
        statusText = const Color(0xFF166534); // Green 800
        statusBg = const Color(0xFFDCFCE7); // Green 100
        break;
      case PaymentStatus.pending:
        statusText = const Color(0xFF9A3412); // Orange 800
        statusBg = const Color(0xFFFFEDD5); // Orange 100
        break;
      case PaymentStatus.failed:
        statusText = const Color(0xFF991B1B); // Red 800
        statusBg = const Color(0xFFFEE2E2); // Red 100
        break;
    }

    // Payment Badge (UPI/Cash/Card)
    Color methodBg = const Color(0xFFDBEAFE); // Blue 100
    Color methodText = const Color(0xFF1E40AF); // Blue 800
    if (payment.method == PaymentMethod.cash) {
      methodBg = const Color(0xFFF1F5F9); // Slate 100
      methodText = const Color(0xFF334155); // Slate 700
    }

    final formattedDate =
        DateFormat('dd MMM yyyy, hh:mm a').format(payment.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Bill # and Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payment.billNumber,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(payment.amount),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(
                    height: 1, thickness: 0.5, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                // Bottom Row: Method and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Method Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: methodBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            payment.method == PaymentMethod.cash
                                ? Icons.payments_outlined
                                : Icons.qr_code_scanner,
                            size: 14,
                            color: methodText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            payment.methodDisplay.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: methodText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        payment.statusDisplay.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
