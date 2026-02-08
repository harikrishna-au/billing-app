import 'package:flutter/material.dart';
// import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../config/theme/app_colors.dart';
import '../../../../../../core/utils/currency_formatter.dart';
import '../../../../../../data/models/product_model.dart';
// import '../../../../providers/cart_provider.dart';

class SelectItemCard extends StatelessWidget {
  final Product item;
  final int quantity; // 0 if not selected
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const SelectItemCard({
    super.key,
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
  });

  bool get isSelected => quantity > 0;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? AppColors.primary : const Color(0xFFE2E8F0);
    final borderWidth = isSelected ? 2.0 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      // padding: const EdgeInsets.all(16), // Moved inside InkWell
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isSelected
            ? [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ]
            : [],
      ),
      child: InkWell(
        onTap: isSelected ? null : onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(item.price),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: isSelected ? _buildCounter() : _buildAddButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      key: const ValueKey('add_btn'),
      onTap: onAdd,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: const Icon(Icons.add, color: AppColors.primary, size: 20),
      ),
    );
  }

  Widget _buildCounter() {
    return Container(
      key: const ValueKey('counter'),
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CounterButton(icon: Icons.remove, onTap: onDecrement),
          SizedBox(
            width: 32,
            child: Text(
              quantity.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _CounterButton(
            icon: Icons.add,
            onTap: onIncrement,
            isPlus: true,
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPlus;

  const _CounterButton(
      {required this.icon, required this.onTap, this.isPlus = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlus ? AppColors.primary : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: isPlus ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }
}
