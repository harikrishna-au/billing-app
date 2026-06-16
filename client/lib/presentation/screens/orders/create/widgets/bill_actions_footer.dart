import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../config/theme/app_colors.dart';

class BillActionsFooter extends StatelessWidget {
  final bool showPrint;
  final bool narrow;
  final VoidCallback? onPrint;
  final VoidCallback? onNewOrder;
  final VoidCallback? onViewOrders;

  const BillActionsFooter({
    super.key,
    required this.showPrint,
    required this.narrow,
    this.onPrint,
    this.onNewOrder,
    this.onViewOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        narrow ? 14 : 20,
        12,
        narrow ? 14 : 20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (showPrint) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(
                  narrow ? 'Print' : 'Print Receipt',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: onNewOrder,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                narrow ? 'New' : 'New Order',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onViewOrders,
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(
                narrow ? 'Orders' : 'View Orders',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.border),
                foregroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
