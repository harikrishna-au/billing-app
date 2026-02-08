import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/order_model.dart';
// import '../../dashboard/widgets/stat_card.dart'; // Reusing for consistent shadows/shapes if needed, or build custom

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status colors
    // Color statusBg;
    Color statusText;

    if (!order.isPaid) {
      statusText = const Color(0xFF9A3412); // Orange 800
    } else {
      statusText = const Color(0xFF166534); // Green 800
    }

    // Payment Badge (UPI/Cash)
    Color paymentBg = const Color(0xFFDBEAFE); // Blue 100
    Color paymentText = const Color(0xFF1E40AF); // Blue 800
    if (order.paymentMethod == 'Cash') {
      paymentBg = const Color(0xFFDCFCE7);
      paymentText = const Color(0xFF166534);
    }

    final formattedDate =
        DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Order #${order.id}',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (order.isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: paymentBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.paymentMethod.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: paymentText,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(order.totalAmount),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          order.isPaid ? 'PAID' : 'UNPAID',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),

                // Content Row
                Row(
                  children: [
                    // Item Image (Placeholder or first item image)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      // In real app use Image.network
                      child: const Icon(Icons.shopping_bag_outlined,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getItemSummary(order.items),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Client: ${order.clientName}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF64748B), // Slate 500
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary, size: 20),
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

  String _getItemSummary(List<OrderItem> items) {
    if (items.isEmpty) return 'No items';
    final first = items.first.productName;
    if (items.length > 1) {
      return '$first + ${items.length - 1} Products';
    }
    return first;
  }
}
