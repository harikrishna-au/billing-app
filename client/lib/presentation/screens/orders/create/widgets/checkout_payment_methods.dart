import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../config/theme/app_colors.dart';

class CheckoutPaymentMethods extends StatelessWidget {
  final bool isProcessing;
  final String? lastError;
  final VoidCallback onErrorDismissed;
  final VoidCallback onPayCash;
  final VoidCallback onPayUpi;
  /// When `false` (default), CARD is non-interactive — no navigation, no callbacks.
  final bool cardEnabled;
  final VoidCallback onPayCard;
  final VoidCallback onCancel;

  const CheckoutPaymentMethods({
    super.key,
    required this.isProcessing,
    this.lastError,
    required this.onErrorDismissed,
    required this.onPayCash,
    required this.onPayUpi,
    this.cardEnabled = false,
    required this.onPayCard,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lastError != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lastError!,
                    style: GoogleFonts.dmSans(color: AppColors.error, fontSize: 11),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error, size: 16),
                  onPressed: onErrorDismissed,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _PaymentButton(
                label: 'CASH',
                color: const Color(0xFF166534),
                icon: Icons.payments_rounded,
                disabled: isProcessing,
                onTap: onPayCash,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PaymentButton(
                label: 'UPI',
                color: const Color(0xFF0F172A),
                icon: Icons.qr_code_scanner_rounded,
                disabled: isProcessing,
                onTap: onPayUpi,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PaymentButton(
                label: 'CARD',
                color: const Color(0xFF312E81),
                icon: Icons.credit_card_rounded,
                disabled: isProcessing || !cardEnabled,
                onTap: cardEnabled ? onPayCard : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PaymentButton(
                label: 'CANCEL',
                color: AppColors.error,
                icon: Icons.close_rounded,
                disabled: isProcessing,
                onTap: onCancel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _PaymentButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Ink(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
