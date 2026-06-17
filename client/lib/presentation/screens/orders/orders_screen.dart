import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/bill_config_provider.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/app_error_widget.dart';
import '../../../services/smart_pos_printer_service.dart';
import 'create/bill_thermal_print.dart';
import 'widgets/payment_card.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFor(_selectedDate);
    });
  }

  Future<void> _loadFor(DateTime date) async {
    setState(() => _selectedDate = date);
    await ref.read(paymentProvider.notifier).loadPaymentsForDate(date);
  }

  Future<void> _syncQueuedTickets() async {
    final r = await ref.read(paymentProvider.notifier).syncQueuedTicketsNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.userMessage,
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: r == QueuedTicketsSyncResult.success
            ? AppColors.success
            : AppColors.textSecondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
    await _loadFor(_selectedDate);
  }

  bool _isPrinting = false;

  void _showPrintSheet(BuildContext context) {
    final payments = ref.read(paymentProvider).payments;
    if (payments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to print')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Print Summary',
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _printTransactionSummary(); },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: Text('Transaction Summary',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _printSalesSummary(); },
                  icon: const Icon(Icons.summarize, size: 18),
                  label: Text('Sales Summary',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printTransactionSummary() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final payments = ref.read(paymentProvider).payments;
      final config = ref.read(billConfigProvider);

      final successList = payments.where((p) => p.isSuccess).toList();
      final failedList  = payments.where((p) => p.isFailed).toList();
      double sum(Iterable<Payment> l) => l.fold(0.0, (s, p) => s + p.amount);

      final successTotal = sum(successList);
      final failedTotal  = sum(failedList);
      final successCash  = sum(successList.where((p) => p.method == PaymentMethod.cash));
      final successUpi   = sum(successList.where((p) => p.method == PaymentMethod.upi));
      final successCard  = sum(successList.where((p) => p.method == PaymentMethod.card));
      final failedCash   = sum(failedList.where((p) => p.method == PaymentMethod.cash));
      final failedUpi    = sum(failedList.where((p) => p.method == PaymentMethod.upi));
      final failedCard   = sum(failedList.where((p) => p.method == PaymentMethod.card));

      final dateStr    = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final printedStr = DateFormat('dd-MM-yy HH:mm').format(DateTime.now());
      final terminal   = (config.unitName?.isNotEmpty == true) ? config.unitName! : config.orgName;
      String fmt(double v) => v.toStringAsFixed(2);

      final lines = <ThermalPrintLine>[];
      void ln(String text, {int size = 20, bool bold = false, int align = 0}) =>
          lines.add((text: text, size: size, bold: bold, align: align));

      if (config.orgName.isNotEmpty) ln(config.orgName, size: 26, bold: true, align: 1);
      ln('TRANSACTION SUMMARY', size: 22, bold: true, align: 1);
      if (config.unitName?.isNotEmpty == true) ln(config.unitName!, size: 20, align: 1);
      ln('Sale Date : $dateStr');
      ln('Term: ${terminal.length > 18 ? terminal.substring(0, 18) : terminal}');
      ln('------------------------', align: 1);
      ln('BILL         AMOUNT', bold: true);
      ln('------------------------', align: 1);

      for (final p in payments) {
        ln(p.billNumber);
        final m = p.method == PaymentMethod.cash ? 'Cash' : p.method == PaymentMethod.upi ? 'UPI' : 'Card';
        ln('  ${m.padRight(5)}${fmt(p.amount).padLeft(15)}');
      }

      void stat(String label, String val) =>
          ln('${label.padRight(13)}:${val.padLeft(10)}');

      ln('------------------------', align: 1);
      stat('SUCC TX', successList.length.toString());
      stat('SUCC AMT', fmt(successTotal));
      stat('SUCC CASH', fmt(successCash));
      stat('SUCC UPI', fmt(successUpi));
      stat('SUCC CARD', fmt(successCard));
      ln('');
      stat('FAIL TX', failedList.length.toString());
      stat('FAIL AMT', fmt(failedTotal));
      stat('FAIL CASH', fmt(failedCash));
      stat('FAIL UPI', fmt(failedUpi));
      stat('FAIL CARD', fmt(failedCard));
      ln('');
      ln('Prtd: $printedStr');
      ln('\n\n', align: 1);

      await printThermalLineBatch(
        printer: SmartPosPrinterService(),
        printRefNo: 'TXSUM-${dateStr.replaceAll('-', '')}',
        lines: lines,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e')));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _printSalesSummary() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      final payments = ref.read(paymentProvider).payments;
      final config   = ref.read(billConfigProvider);
      if (payments.isEmpty) return;

      final sorted = [...payments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final successList    = payments.where((p) => p.isSuccess).toList();
      final failedList     = payments.where((p) => p.isFailed).toList();
      double sum(Iterable<Payment> l) => l.fold(0.0, (s, p) => s + p.amount);

      final cashSuccess    = successList.where((p) => p.method == PaymentMethod.cash).toList();
      final upiSuccess     = successList.where((p) => p.method == PaymentMethod.upi).toList();
      final cardSuccess    = successList.where((p) => p.method == PaymentMethod.card).toList();
      final upiFailedList  = failedList.where((p) => p.method == PaymentMethod.upi).toList();
      final cardFailedList = failedList.where((p) => p.method == PaymentMethod.card).toList();

      final transTotal  = sum(successList);
      final cashAmt     = sum(cashSuccess);
      final upiAmt      = sum(upiSuccess);
      final cardAmt     = sum(cardSuccess);
      final failUpiAmt  = sum(upiFailedList);
      final failCardAmt = sum(cardFailedList);

      final dateStr      = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final printedStr   = DateFormat('dd-MM-yy HH:mm').format(DateTime.now());
      final startDateStr = DateFormat('dd-MM-yy HH:mm').format(sorted.first.createdAtLocal);
      final endDateStr   = DateFormat('dd-MM-yy HH:mm').format(sorted.last.createdAtLocal);
      final terminal     = (config.unitName?.isNotEmpty == true) ? config.unitName! : config.orgName;
      String fmt(double v) => v.toStringAsFixed(2);

      final lines = <ThermalPrintLine>[];
      void ln(String text, {int size = 20, bool bold = false, int align = 0}) =>
          lines.add((text: text, size: size, bold: bold, align: align));

      if (config.orgName.isNotEmpty) ln(config.orgName, size: 26, bold: true, align: 1);
      ln('SALES SUMMARY', size: 22, bold: true, align: 1);
      if (config.unitName?.isNotEmpty == true) ln(config.unitName!, size: 20, align: 1);
      ln('Sale Date  : $dateStr');
      ln('Term: ${terminal.length > 18 ? terminal.substring(0, 18) : terminal}');
      ln('');
      ln('Start: $startDateStr');
      ln('End:   $endDateStr');
      ln('');
      ln('From: ${sorted.first.billNumber}');
      ln('To:   ${sorted.last.billNumber}');
      ln('');
      ln('ITEM  CNT    AMOUNT', bold: true);
      ln('------------------------', align: 1);

      void stat(String label, String val) =>
          ln('${label.padRight(13)}:${val.padLeft(10)}');
      void block(String label, List<Payment> sg, List<Payment> fg) {
        final tickets = sg.length + fg.length;
        if (tickets == 0) return;
        final total = sum(sg) + sum(fg);
        ln('${label.padRight(5)} ${tickets.toString().padLeft(3)} ${fmt(total).padLeft(11)}');
        if (fg.isNotEmpty) {
          ln('  FAIL ${fg.length.toString().padLeft(3)} ${fmt(sum(fg)).padLeft(11)}');
        }
        ln('');
      }

      block('CASH', cashSuccess, []);
      block('UPI',  upiSuccess,  upiFailedList);
      block('CARD', cardSuccess, cardFailedList);

      ln('------------------------', align: 1);
      stat('TRANS AMT', fmt(transTotal));
      ln('');
      stat('CASH AMT', fmt(cashAmt));
      stat('SUCC UPI AMT', fmt(upiAmt));
      stat('SUCC CARD AMT', fmt(cardAmt));
      stat('FAIL UPI AMT', fmt(failUpiAmt));
      stat('FAIL CARD AMT', fmt(failCardAmt));
      ln('------------------------', align: 1);
      ln('FINAL AMT    :${fmt(transTotal).padLeft(10)}', size: 22, bold: true);
      ln('');
      ln('Prtd: $printedStr');
      ln('\n\n', align: 1);

      await printThermalLineBatch(
        printer: SmartPosPrinterService(),
        printRefNo: 'SALE-${dateStr.replaceAll('-', '')}',
        lines: lines,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e')));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _loadFor(picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);
    final payments = state.filteredPayments;
    final totalAmount = payments.fold(0.0, (sum, p) => sum + p.amount);

    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Orders',
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.print_rounded,
              color: _isPrinting
                  ? AppColors.border
                  : AppColors.textSecondary,
              size: 22,
            ),
            onPressed: _isPrinting ? null : () => _showPrintSheet(context),
            tooltip: 'Print Summary',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () => _loadFor(_selectedDate),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isOffline || state.pendingCount > 0)
            ImprovedOfflineBanner(
              message: !state.isOffline && state.pendingCount > 0
                  ? '${state.pendingCount} ticket(s) queued — tap Sync'
                  : null,
              pendingCount: state.pendingCount > 0 ? state.pendingCount : null,
              onSyncTap: state.pendingCount > 0 ? _syncQueuedTickets : null,
            ),

          // Full-screen error (non-offline hard failure)
          if (state.error != null && !state.isOffline && payments.isEmpty)
            Expanded(
              child: AppErrorWidget(
                error: state.error,
                onRetry: () => _loadFor(_selectedDate),
              ),
            )
          else ...[

          // Summary card
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: _SummaryCard(
              total: totalAmount,
              count: payments.length,
              cashAmount: payments
                  .where((p) => p.method == PaymentMethod.cash && p.isSuccess)
                  .fold(0.0, (s, p) => s + p.amount),
              cashCount: payments
                  .where((p) => p.method == PaymentMethod.cash && p.isSuccess)
                  .length,
              upiAmount: payments
                  .where((p) => p.method == PaymentMethod.upi && p.isSuccess)
                  .fold(0.0, (s, p) => s + p.amount),
              upiCount: payments
                  .where((p) => p.method == PaymentMethod.upi && p.isSuccess)
                  .length,
              cardAmount: payments
                  .where((p) => p.method == PaymentMethod.card && p.isSuccess)
                  .fold(0.0, (s, p) => s + p.amount),
              cardCount: payments
                  .where((p) => p.method == PaymentMethod.card && p.isSuccess)
                  .length,
              isLoading: state.isLoading,
            ),
          ),

          // Date row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isToday ? "Today's transactions" : 'Transactions',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 7),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: state.isLoading
                ? const PaymentsShimmer()
                : payments.isEmpty
                    ? _EmptyState(date: _selectedDate)
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final p = payments[index];
                          return PaymentCard(
                            payment: p,
                          )
                              .animate()
                              .fadeIn(
                                  duration: 250.ms,
                                  delay: (index * 30).ms)
                              .slideY(begin: 0.06, end: 0);
                        },
                      ),
          ),
          ], // end else block
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double total;
  final int count;
  final double cashAmount;
  final int cashCount;
  final double upiAmount;
  final int upiCount;
  final double cardAmount;
  final int cardCount;
  final bool isLoading;

  const _SummaryCard({
    required this.total,
    required this.count,
    required this.cashAmount,
    required this.cashCount,
    required this.upiAmount,
    required this.upiCount,
    required this.cardAmount,
    required this.cardCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row — total + count
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total collected',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    isLoading
                        ? Container(
                            width: 120,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          )
                            .animate(onPlay: (c) => c.repeat())
                            .shimmer(
                                duration: 1200.ms,
                                color: Colors.white.withValues(alpha: 0.4))
                        : Text(
                            CurrencyFormatter.format(total),
                            style: GoogleFonts.dmSans(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.7,
                              height: 1.1,
                            ),
                          ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      isLoading ? '—' : '$count',
                      style: GoogleFonts.dmSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'bills',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!isLoading && count > 0) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 14),
            // Breakdown row — cash | UPI | Card
            Row(
              children: [
                Expanded(
                  child: _BreakdownChip(
                    icon: Icons.money_rounded,
                    label: 'Cash',
                    amount: CurrencyFormatter.format(cashAmount),
                    count: cashCount,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BreakdownChip(
                    icon: Icons.qr_code_rounded,
                    label: 'UPI',
                    amount: CurrencyFormatter.format(upiAmount),
                    count: upiCount,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BreakdownChip(
                    icon: Icons.credit_card_rounded,
                    label: 'Card',
                    amount: CurrencyFormatter.format(cardAmount),
                    count: cardCount,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final int count;

  const _BreakdownChip({
    required this.icon,
    required this.label,
    required this.amount,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  amount,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                Text(
                  '$count bill${count == 1 ? '' : 's'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final DateTime date;
  const _EmptyState({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 30, color: AppColors.textLight),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions',
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'for ${DateFormat('dd MMM yyyy').format(date)}',
            style: GoogleFonts.dmSans(
              color: AppColors.textLight,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
