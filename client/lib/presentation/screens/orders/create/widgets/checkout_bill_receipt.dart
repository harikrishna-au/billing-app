import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../../../config/theme/app_colors.dart';
import '../../../../../../core/utils/currency_formatter.dart';
import '../../../../providers/cart_provider.dart';

class CheckoutBillReceipt extends StatelessWidget {
  final CartState cartState;
  final double total;

  const CheckoutBillReceipt({
    super.key,
    required this.cartState,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                'NEW ORDER',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Time: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),

        // Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text('QTY', style: _tableHeaderStyle()),
              ),
              Expanded(
                flex: 4,
                child: Text('ITEM NAME', style: _tableHeaderStyle()),
              ),
              Expanded(
                flex: 2,
                child: Text('PRICE', textAlign: TextAlign.right, style: _tableHeaderStyle()),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.borderLight),

        // Items List
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: cartState.itemList.length,
          itemBuilder: (context, index) {
            final item = cartState.itemList[index];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text('${item.quantity}', style: _tableRowStyle()),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(item.product.name, style: _tableRowStyle()),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(item.product.price * item.quantity),
                      textAlign: TextAlign.right,
                      style: _tableRowStyle(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const Divider(height: 1, color: AppColors.borderLight),

        // Totals
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildTotalRow('Sub total :', total),
              const SizedBox(height: 6),
              _buildTotalRow('Discount :', 0.0),
              const SizedBox(height: 6),
              _buildTotalRow('Tax :', 0.0),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1, color: AppColors.borderLight),
              ),
              _buildTotalRow('To pay :', total, isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _tableHeaderStyle() {
    return GoogleFonts.dmSans(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    );
  }

  TextStyle _tableRowStyle() {
    return GoogleFonts.dmSans(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 100,
          child: Text(
            CurrencyFormatter.format(amount),
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
