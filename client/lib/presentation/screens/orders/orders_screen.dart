import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/bill_config_provider.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/offline_banner.dart';
import '../../../services/smart_pos_printer_service.dart';
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
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _printTransactionSummary(); },
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: Text('Transaction Summary',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
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
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
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
      final printedStr = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
      final terminal   = (config.unitName?.isNotEmpty == true) ? config.unitName! : config.orgName;
      String fmt(double v) => v.toStringAsFixed(2);

      final printer = SmartPosPrinterService();
      await printer.initSdk();

      if (config.orgName.isNotEmpty) {
        await printer.printText(text: config.orgName, size: 26, isBold: true, align: 1);
      }
      await printer.printText(text: 'TRANSACTION SUMMARY', size: 22, isBold: true, align: 1);
      if (config.unitName?.isNotEmpty == true) {
        await printer.printText(text: config.unitName!, size: 20, align: 1);
      }
      await printer.printText(text: 'Sale Date : $dateStr', size: 20, align: 0);
      await printer.printText(text: 'Terminal  : $terminal', size: 20, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);
      await printer.printText(text: 'RECEIPT          TICKETS  AMOUNT', size: 20, isBold: true, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);

      for (final p in payments) {
        await printer.printText(text: p.billNumber, size: 20, align: 0);
        final m = p.method == PaymentMethod.cash ? 'Cash' : p.method == PaymentMethod.upi ? 'UPI' : 'Card';
        await printer.printText(text: '${m.padRight(20)}1${fmt(p.amount).padLeft(10)}', size: 20, align: 0);
      }

      await printer.printText(text: '--------------------------------', size: 20, align: 1);
      await printer.printText(text: 'SUCCESS TOTAL TRANSACTIONS :${successList.length.toString().padLeft(3)}', size: 20, align: 0);
      await printer.printText(text: 'SUCCESS TOTAL TICKETS      :${successList.length.toString().padLeft(3)}', size: 20, align: 0);
      await printer.printText(text: 'SUCCESS TOTAL AMOUNT       : ${fmt(successTotal)}', size: 20, align: 0);
      await printer.printText(text: 'SUCCESS-CASH AMOUNT        : ${fmt(successCash)}', size: 20, align: 0);
      await printer.printText(text: 'SUCCESS-UPI  AMOUNT        : ${fmt(successUpi)}', size: 20, align: 0);
      await printer.printText(text: 'SUCCESS-CARD AMOUNT        : ${fmt(successCard)}', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'FAILED TOTAL TRANSACTIONS  :${failedList.length.toString().padLeft(3)}', size: 20, align: 0);
      await printer.printText(text: 'FAILED TOTAL AMOUNT        : ${fmt(failedTotal)}', size: 20, align: 0);
      await printer.printText(text: 'FAILED-CASH AMOUNT         : ${fmt(failedCash)}', size: 20, align: 0);
      await printer.printText(text: 'FAILED-UPI  AMOUNT         : ${fmt(failedUpi)}', size: 20, align: 0);
      await printer.printText(text: 'FAILED-CARD AMOUNT         : ${fmt(failedCard)}', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Printed on : $printedStr', size: 20, align: 0);
      await printer.printText(text: '\n\n', size: 20, align: 1);
      await printer.cutPaper();
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
      final printedStr   = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
      final startDateStr = DateFormat('dd-MM-yyyy HH:mm:ss').format(sorted.first.createdAt);
      final endDateStr   = DateFormat('dd-MM-yyyy HH:mm:ss').format(sorted.last.createdAt);
      final terminal     = (config.unitName?.isNotEmpty == true) ? config.unitName! : config.orgName;
      String fmt(double v) => v.toStringAsFixed(2);
      String cnt(int n, double v) => n > 0 ? '${n.toString().padLeft(2)}  ${fmt(v)}' : '';

      final printer = SmartPosPrinterService();
      await printer.initSdk();

      if (config.orgName.isNotEmpty) {
        await printer.printText(text: config.orgName, size: 26, isBold: true, align: 1);
      }
      await printer.printText(text: 'SALES SUMMARY', size: 22, isBold: true, align: 1);
      if (config.unitName?.isNotEmpty == true) {
        await printer.printText(text: config.unitName!, size: 20, align: 1);
      }
      await printer.printText(text: 'Sale Date  : $dateStr', size: 20, align: 0);
      await printer.printText(text: 'Terminal   : $terminal', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Starting Date      : $startDateStr', size: 20, align: 0);
      await printer.printText(text: 'Ending Date        : $endDateStr', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Starting Ticket No : ${sorted.first.billNumber}', size: 20, align: 0);
      await printer.printText(text: 'Ending Ticket No   : ${sorted.last.billNumber}', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'ITEM          TICKETS  AMOUNT', size: 20, isBold: true, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);

      Future<void> block(String label, List<Payment> sg, List<Payment> fg) async {
        if (sg.isEmpty && fg.isEmpty) return;
        final total   = sum(sg) + sum(fg);
        final tickets = sg.length + fg.length;
        await printer.printText(text: '${label.padRight(14)}${tickets.toString().padLeft(4)}  ${fmt(total)}', size: 20, align: 0);
        await printer.printText(text: 'Cash :       ${label == "CASH" ? cnt(cashSuccess.length, cashAmt) : ""}', size: 20, align: 0);
        await printer.printText(text: 'Success-Upi :${label == "UPI"  ? cnt(upiSuccess.length,  upiAmt)  : ""}', size: 20, align: 0);
        await printer.printText(text: 'Success-Card :${label == "CARD" ? cnt(cardSuccess.length, cardAmt) : ""}', size: 20, align: 0);
        await printer.printText(text: 'Failed-Upi : ${label == "UPI"  && upiFailedList.isNotEmpty  ? cnt(upiFailedList.length,  failUpiAmt)  : ""}', size: 20, align: 0);
        await printer.printText(text: 'Failed-Card :${label == "CARD" && cardFailedList.isNotEmpty ? cnt(cardFailedList.length, failCardAmt) : ""}', size: 20, align: 0);
        await printer.printText(text: '', size: 20, align: 0);
      }

      await block('CASH', cashSuccess, []);
      await block('UPI',  upiSuccess,  upiFailedList);
      await block('CARD', cardSuccess, cardFailedList);

      await printer.printText(text: '--------------------------------', size: 20, align: 1);
      await printer.printText(text: 'TRANS. AMOUNT :  ${fmt(transTotal).padLeft(16)}', size: 22, isBold: true, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'CASH :         ${cashSuccess.length.toString().padLeft(3)}    ${fmt(cashAmt).padLeft(10)}', size: 20, align: 0);
      await printer.printText(text: 'SUCCESS - UPI :${upiSuccess.length.toString().padLeft(3)}    ${fmt(upiAmt).padLeft(10)}', size: 20, align: 0);
      await printer.printText(text: 'SUCCESS - CARD :${cardSuccess.length.toString().padLeft(2)}    ${fmt(cardAmt).padLeft(10)}', size: 20, align: 0);
      await printer.printText(text: 'FAILED - UPI : ${upiFailedList.length.toString().padLeft(3)}    ${fmt(failUpiAmt).padLeft(10)}', size: 20, align: 0);
      await printer.printText(text: 'FAILED - CARD :${cardFailedList.length.toString().padLeft(3)}    ${fmt(failCardAmt).padLeft(10)}', size: 20, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);
      await printer.printText(text: 'FINAL RECEIVED AMOUNT : ${fmt(transTotal).padLeft(10)}', size: 22, isBold: true, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Printed on : $printedStr', size: 20, align: 0);
      await printer.printText(text: '\n\n', size: 20, align: 1);
      await printer.cutPaper();
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
            fontSize: 22,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          if (_isPrinting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.print_rounded,
                  color: AppColors.textSecondary, size: 22),
              onPressed: () => _showPrintSheet(context),
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
          if (state.isOffline) const OfflineBanner(),

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
                    fontSize: 13,
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
                            fontSize: 13,
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
                            onTap: () => context.push(
                              '/new/review/collect-payment/bill?method=${p.methodDisplay}&invoice=${p.billNumber}&amount=${p.amount}&date=${p.createdAt.toIso8601String()}&readOnly=true',
                            ),
                          )
                              .animate()
                              .fadeIn(
                                  duration: 250.ms,
                                  delay: (index * 30).ms)
                              .slideY(begin: 0.06, end: 0);
                        },
                      ),
          ),
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
                        fontSize: 12,
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
                              fontSize: 26,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'bills',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
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
                    fontSize: 13,
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
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'for ${DateFormat('dd MMM yyyy').format(date)}',
            style: GoogleFonts.dmSans(
              color: AppColors.textLight,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
