import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme/app_colors.dart';
import '../../core/network/api_exception.dart';

enum _ErrorType { network, server, generic }

/// A full-screen error state widget.
/// Shows a contextual icon + title + message and optional retry button.
///
/// Usage:
/// ```dart
/// if (state.error != null)
///   AppErrorWidget(
///     error: state.error,
///     onRetry: () => ref.read(provider.notifier).load(),
///   )
/// ```
class AppErrorWidget extends StatelessWidget {
  final Object? error;
  final String? customMessage;
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    this.error,
    this.customMessage,
    this.onRetry,
  });

  _ErrorType get _type {
    if (error is NetworkException) return _ErrorType.network;
    if (error is ApiException) {
      final e = error as ApiException;
      if (e.isNetworkError) return _ErrorType.network;
      if (e.isServerError) return _ErrorType.server;
    }
    // Detect common network error strings even when not wrapped
    final msg = error?.toString().toLowerCase() ?? '';
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('internet') ||
        msg.contains('timeout')) {
      return _ErrorType.network;
    }
    return _ErrorType.generic;
  }

  String get _title {
    switch (_type) {
      case _ErrorType.network:
        return 'No internet connection';
      case _ErrorType.server:
        return 'Server error';
      case _ErrorType.generic:
        return 'Something went wrong';
    }
  }

  String get _message {
    if (customMessage != null) return customMessage!;
    switch (_type) {
      case _ErrorType.network:
        return 'Check your Wi-Fi or mobile data\nand try again.';
      case _ErrorType.server:
        return 'Our server ran into a problem.\nPlease try again in a moment.';
      case _ErrorType.generic:
        return 'An unexpected error occurred.\nPlease try again.';
    }
  }

  IconData get _icon {
    switch (_type) {
      case _ErrorType.network:
        return Icons.wifi_off_rounded;
      case _ErrorType.server:
        return Icons.cloud_off_rounded;
      case _ErrorType.generic:
        return Icons.error_outline_rounded;
    }
  }

  Color get _color {
    switch (_type) {
      case _ErrorType.network:
        return const Color(0xFFF59E0B); // amber
      case _ErrorType.server:
        return AppColors.error;
      case _ErrorType.generic:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon bubble
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 36, color: _color),
            ),

            const SizedBox(height: 20),

            Text(
              _title,
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              _message,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            if (onRetry != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    'Try Again',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact inline error banner (not full-screen).
/// Use inside forms or below content when you can't take the whole screen.
class InlineErrorBanner extends StatelessWidget {
  final Object? error;
  final String? customMessage;
  final VoidCallback? onDismiss;

  const InlineErrorBanner({
    super.key,
    this.error,
    this.customMessage,
    this.onDismiss,
  });

  String get _message {
    if (customMessage != null) return customMessage!;
    if (error is ApiException) return (error as ApiException).message;
    final raw = error?.toString() ?? 'Something went wrong';
    // Strip 'Exception: ' prefix that Dart adds automatically
    return raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  bool get _isNetwork {
    if (error is NetworkException) return true;
    final msg = error?.toString().toLowerCase() ?? '';
    return msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('internet') ||
        msg.contains('timeout');
  }

  @override
  Widget build(BuildContext context) {
    final color = _isNetwork
        ? const Color(0xFFF59E0B)
        : AppColors.error;
    final bgColor = _isNetwork
        ? const Color(0xFFFFFBEB)
        : const Color(0xFFFEF2F2);
    final borderColor = _isNetwork
        ? const Color(0xFFFCD34D)
        : const Color(0xFFFCA5A5);
    final icon = _isNetwork
        ? Icons.wifi_off_rounded
        : Icons.error_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isNetwork ? 'No internet — bill saved offline' : _message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close_rounded, size: 16, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

/// Improved offline banner — more prominent than the original slim strip.
class ImprovedOfflineBanner extends StatelessWidget {
  final String? message;
  final int? pendingCount;
  const ImprovedOfflineBanner({super.key, this.message, this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final text = pendingCount != null && pendingCount! > 0
        ? 'Offline — $pendingCount bill${pendingCount == 1 ? '' : 's'} queued to sync'
        : (message ?? 'Offline — showing cached data');

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
            child: const Icon(Icons.wifi_off_rounded,
                size: 14, color: Color(0xFF92400E)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF78350F),
              ),
            ),
          ),
          const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF92400E)),
        ],
      ),
    );
  }
}
