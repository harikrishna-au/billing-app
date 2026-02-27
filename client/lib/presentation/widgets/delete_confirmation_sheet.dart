import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// import '../../config/theme/app_colors.dart';

class DeleteConfirmationSheet extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final bool isDeleting;

  const DeleteConfirmationSheet({
    super.key,
    this.title = 'Delete Item?',
    this.description =
        'Are you sure you want to delete this item? This will permanently remove it from your catalogue.',
    required this.onConfirm,
    this.confirmLabel = 'Delete',
    this.isDeleting = false,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onConfirm,
    String? title,
    String? description,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DeleteConfirmationSheet(
        onConfirm: onConfirm,
        title: title ?? 'Delete Item?',
        description: description ??
            'Are you sure you want to delete this item? This will permanently remove it from your catalogue.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon Badge
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2), // Red 50
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFDC2626), // Red 600
              size: 32,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                duration: 600.ms,
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.15, 1.15),
                curve: Curves.easeInOut,
              ),

          const SizedBox(height: 20),

          // Text Group
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              height: 1.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 32),

          // Action Buttons
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    onConfirm();
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .slideY(
            begin: 1.0, end: 0.0, duration: 400.ms, curve: Curves.easeOutQuint)
        .fadeIn(duration: 400.ms);
  }
}
