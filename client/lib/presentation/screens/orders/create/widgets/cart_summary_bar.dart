import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../config/theme/app_colors.dart';
import '../../../../../../core/utils/currency_formatter.dart';

class CartSummaryBar extends StatelessWidget {
  final double totalAmount;
  final int totalItems;
  final VoidCallback onNext;

  const CartSummaryBar({
    super.key,
    required this.totalAmount,
    required this.totalItems,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Left: totals
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$totalItems item${totalItems == 1 ? '' : 's'}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    CurrencyFormatter.format(totalAmount),
                    style: GoogleFonts.dmSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Right: CTA — full height, clean rectangle
            GestureDetector(
              onTap: onNext,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Review',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideY(
            begin: 1.0,
            end: 0.0,
            duration: 200.ms,
            curve: Curves.easeOutCubic)
        .fadeIn(duration: 150.ms);
  }
}
