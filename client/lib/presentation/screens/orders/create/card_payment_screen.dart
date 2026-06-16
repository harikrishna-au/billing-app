import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/constants/plutus_config.dart';
import '../../../../core/services/plutus_smart_service.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/utils/print_utils.dart';
import '../../../../data/models/payment_model.dart';
import '../../../providers/bill_config_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/payment_provider.dart';

enum _CardState { waitingForTerminal, processing, approved, failed }

class CardPaymentScreen extends ConsumerStatefulWidget {
  final double amount;

  const CardPaymentScreen({super.key, required this.amount});

  @override
  ConsumerState<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends ConsumerState<CardPaymentScreen> {
  _CardState _state = _CardState.waitingForTerminal;
  String _statusMsg = 'Connecting to terminal…';
  final List<String> _debugLines = [];
  bool _done = false; // prevents double-completion

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTransaction());
  }

  void _log(String msg) {
    _debugLines.add(msg);
    if (mounted) setState(() => _statusMsg = msg);
  }

  Future<void> _startTransaction() async {
    if (_done) return;
    setState(() {
      _state = _CardState.waitingForTerminal;
      _statusMsg = 'Connecting to terminal…';
      _debugLines.clear();
    });

    try {
      final billConfig = ref.read(billConfigProvider);
      final billGen   = ref.read(billNumberServiceProvider);
      final billNumber = billGen.generatePreview(posId: billConfig.posId);

      final paise = (widget.amount * 100).round();

      final json = PlutusRequestBuilder.sale(
        applicationId:      PlutusConfig.applicationId.trim(),
        versionNo:          PlutusConfig.apiVersion,
        userId: PlutusConfig.userId.trim().isEmpty ? null : PlutusConfig.userId.trim(),
        billingRefNo:       billNumber,
        paymentAmountPaise: paise,
        transactionType:    4001, // Card sale
      );

      _log('Sending card sale — Rs ${widget.amount.toStringAsFixed(2)} (${paise}p)');
      _log('BillingRefNo: $billNumber');
      _log('Waiting for customer card…');

      if (mounted) setState(() => _state = _CardState.processing);

      final response = await PlutusSmartService.startTransaction(
        transactionJson: json,
      );

      _log('Raw response: ${response ?? "(null)"}');

      final parsed = PlutusResponse.tryParse(response);
      _log('ResponseCode: ${parsed.responseCode ?? "?"}'
          '  ResponseMsg: ${parsed.responseMsg ?? "(none)"}');

      if (!parsed.isApproved) {
        final hint = _codeHint(parsed.responseCode, parsed.responseMsg);
        _log('REJECTED: $hint');
        if (mounted) setState(() => _state = _CardState.failed);
        return;
      }

      _log('Card APPROVED — recording payment');
      if (mounted) setState(() => _state = _CardState.approved);
      await _completePayment(billNumber);
    } catch (e) {
      _log('ERROR: $e');
      if (mounted) setState(() => _state = _CardState.failed);
    }
  }

  Future<void> _completePayment(String billNumber) async {
    if (_done) return;
    _done = true;

    try {
      final billConfig = ref.read(billConfigProvider);
      final billGen   = ref.read(billNumberServiceProvider);

      final payment = Payment(
        id:         '',
        billNumber: billNumber,
        amount:     widget.amount,
        method:     PaymentMethod.card,
        status:     PaymentStatus.success,
        createdAt:  DateTime.now(),
      );

      final created = await ref.read(paymentProvider.notifier).createPayment(payment);
      if (created == null) throw Exception('Failed to record payment');

      await billGen.confirmBillNumber(posId: billConfig.posId);

      if (!mounted) return;
      await PrintUtils.showTicketBooked(context);
      if (!mounted) return;

      final savedCart = ref.read(cartProvider);
      final router    = GoRouter.of(context);
      final container = ProviderScope.containerOf(context, listen: false);

      ref.read(cartProvider.notifier).clearCart();
      router.go('/new');

      unawaited(
        PrintUtils.printReceipt(
          context: router.routerDelegate.navigatorKey.currentContext,
          provider: container,
          billNumber: billNumber,
          total: widget.amount,
          date: created.createdAt,
          cartState: savedCart,
          paymentMethod: 'card',
        ),
      );
    } catch (e) {
      _done = false;
      _log('Post-approval error: $e');
      if (mounted) setState(() => _state = _CardState.failed);
    }
  }

  String _codeHint(int? code, String? msg) {
    final base = (msg != null && msg.trim().isNotEmpty) ? msg.trim() : 'Unknown error';
    switch (code) {
      case 7:
        return 'ApplicationId not registered for this terminal (code 7). — "$base"';
      case 14:
        return 'Invalid Application Id (code 14). — "$base"';
      default:
        return 'Transaction declined (code $code). — "$base"';
    }
  }

  Future<void> _showDiagnostics() async {
    if (!mounted) return;
    await PrintUtils.showPrintDiagnostics(
      context: context,
      lines: _debugLines,
      title: 'Card transaction log',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _state == _CardState.waitingForTerminal ||
        _state == _CardState.processing;
    final isFailed   = _state == _CardState.failed;
    final isApproved = _state == _CardState.approved;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Card Payment',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16),
          ),
          onPressed: isBusy ? null : () => context.pop(),
          color: AppColors.textPrimary,
        ),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Amount ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹',
                    style: GoogleFonts.dmSans(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  Text(
                    widget.amount.toStringAsFixed(2).split('.')[0],
                    style: GoogleFonts.dmSans(
                      fontSize: 46,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    '.${widget.amount.toStringAsFixed(2).split('.')[1]}',
                    style: GoogleFonts.dmSans(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 350.ms),

              const SizedBox(height: 36),

              // ── Terminal status card ───────────────────────────────
              _TerminalStatusCard(
                state: _state,
                statusMsg: _statusMsg,
                onShowLog: _showDiagnostics,
              ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

              const Spacer(),

              // ── Bottom actions ────────────────────────────────────
              if (isFailed) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _done = false;
                      _startTransaction();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      'Retry',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      ref.read(cartProvider.notifier).clearCart();
                      context.go('/new');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ] else if (!isApproved) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: isBusy ? null : () {
                      ref.read(cartProvider.notifier).clearCart();
                      context.go('/new');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(
                          color: Color(0xFFEF4444), width: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel transaction',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalStatusCard extends StatelessWidget {
  final _CardState state;
  final String statusMsg;
  final VoidCallback onShowLog;

  const _TerminalStatusCard({
    required this.state,
    required this.statusMsg,
    required this.onShowLog,
  });

  @override
  Widget build(BuildContext context) {
    final isBusy = state == _CardState.waitingForTerminal ||
        state == _CardState.processing;
    final isFailed   = state == _CardState.failed;
    final isApproved = state == _CardState.approved;

    final Color accent = isFailed
        ? const Color(0xFFEF4444)
        : isApproved
            ? const Color(0xFF10B981)
            : const Color(0xFF3B82F6);

    final IconData icon = isFailed
        ? Icons.error_outline_rounded
        : isApproved
            ? Icons.check_circle_outline_rounded
            : Icons.credit_card_rounded;

    final String label = isFailed
        ? 'Transaction Failed'
        : isApproved
            ? 'Approved'
            : state == _CardState.processing
                ? 'Processing…'
                : 'Present Card to Terminal';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (isBusy)
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: accent,
              ),
            )
          else
            Icon(icon, size: 56, color: accent),

          const SizedBox(height: 16),

          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            statusMsg,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: onShowLog,
            child: Text(
              'View transaction log',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
