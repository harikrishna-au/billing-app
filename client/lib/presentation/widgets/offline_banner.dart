import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

export 'app_error_widget.dart' show ImprovedOfflineBanner;

/// A slim amber banner shown at the top of a screen when the app is
/// displaying cached data because it cannot reach the server.
class OfflineBanner extends StatelessWidget {
  final String? message;
  final int? pendingCount;
  final VoidCallback? onSyncTap;

  const OfflineBanner({
    super.key,
    this.message,
    this.pendingCount,
    this.onSyncTap,
  });

  @override
  Widget build(BuildContext context) {
    final String text;
    if (message != null && message!.trim().isNotEmpty) {
      text = message!.trim();
    } else if (pendingCount != null && pendingCount! > 0) {
      text =
          '$pendingCount bill${pendingCount == 1 ? '' : 's'} queued — syncing…';
    } else {
      text = 'Offline — showing cached data';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFEF3C7),
        border: Border(
          bottom: BorderSide(color: Color(0xFFFDE68A), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              pendingCount != null && pendingCount! > 0
                  ? Icons.cloud_upload_outlined
                  : Icons.wifi_off_rounded,
              size: 14,
              color: Color(0xFF92400E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF78350F),
              ),
            ),
          ),
          if (onSyncTap != null && pendingCount != null && pendingCount! > 0)
            TextButton(
              onPressed: onSyncTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Sync',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E),
                ),
              ),
            )
          else
            const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF92400E)),
        ],
      ),
    );
  }
}
