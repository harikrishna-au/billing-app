import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/bill_config_provider.dart';
import '../../../services/smart_pos_printer_service.dart';

class DaySummaryScreen extends ConsumerStatefulWidget {
  const DaySummaryScreen({super.key});

  @override
  ConsumerState<DaySummaryScreen> createState() => _DaySummaryScreenState();
}

class _DaySummaryScreenState extends ConsumerState<DaySummaryScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  void _loadPayments() {
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final endOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23,
      59,
      59,
    );

    ref.read(paymentProvider.notifier).loadPaymentsByDateRange(
          startOfDay,
          endOfDay,
        );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadPayments();
    }
  }

  Future<void> _printOnPos() async {
    setState(() => _isGenerating = true);
    try {
      final payments = ref.read(paymentProvider).payments;
      final config = ref.read(billConfigProvider);

      final successList = payments.where((p) => p.isSuccess).toList();
      final failedList = payments.where((p) => p.isFailed).toList();

      double sum(Iterable<Payment> list) =>
          list.fold(0.0, (s, p) => s + p.amount);

      final successTotal = sum(successList);
      final failedTotal = sum(failedList);
      final successCash = sum(successList.where((p) => p.method == PaymentMethod.cash));
      final successUpi = sum(successList.where((p) => p.method == PaymentMethod.upi));
      final successCard = sum(successList.where((p) => p.method == PaymentMethod.card));
      final failedCash = sum(failedList.where((p) => p.method == PaymentMethod.cash));
      final failedUpi = sum(failedList.where((p) => p.method == PaymentMethod.upi));
      final failedCard = sum(failedList.where((p) => p.method == PaymentMethod.card));

      final dateStr = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final printedStr = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
      final terminal = (config.unitName != null && config.unitName!.isNotEmpty)
          ? config.unitName!
          : config.orgName;

      String fmt(double v) => v.toStringAsFixed(2);

      final printer = SmartPosPrinterService();
      await printer.initSdk();

      // ── Header ─────────────────────────────────────────────────────────
      if (config.orgName.isNotEmpty) {
        await printer.printText(text: config.orgName, size: 26, isBold: true, align: 1);
      }
      await printer.printText(text: 'TRANSACTION SUMMARY', size: 22, isBold: true, align: 1);
      if (config.unitName != null && config.unitName!.isNotEmpty) {
        await printer.printText(text: config.unitName!, size: 20, align: 1);
      }
      await printer.printText(text: 'Sale Date : $dateStr', size: 20, align: 0);
      await printer.printText(text: 'Terminal  : $terminal', size: 20, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);

      // ── Receipt list ───────────────────────────────────────────────────
      await printer.printText(
          text: 'RECEIPT          TICKETS  AMOUNT', size: 20, isBold: true, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);

      for (final p in payments) {
        await printer.printText(text: p.billNumber, size: 20, align: 0);
        final method = p.method == PaymentMethod.cash
            ? 'Cash'
            : p.method == PaymentMethod.upi
                ? 'UPI'
                : 'Card';
        final amtPadded = fmt(p.amount).padLeft(10);
        await printer.printText(
            text: '${method.padRight(20)}1$amtPadded', size: 20, align: 0);
      }

      await printer.printText(text: '--------------------------------', size: 20, align: 1);

      // ── Success totals ─────────────────────────────────────────────────
      await printer.printText(
          text: 'SUCCESS TOTAL TRANSACTIONS :${successList.length.toString().padLeft(3)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'SUCCESS TOTAL TICKETS      :${successList.length.toString().padLeft(3)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'SUCCESS TOTAL AMOUNT       : ${fmt(successTotal)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'SUCCESS-CASH AMOUNT        : ${fmt(successCash)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'SUCCESS-UPI  AMOUNT        : ${fmt(successUpi)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'SUCCESS-CARD AMOUNT        : ${fmt(successCard)}',
          size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);

      // ── Failed totals ──────────────────────────────────────────────────
      await printer.printText(
          text: 'FAILED TOTAL TRANSACTIONS  :${failedList.length.toString().padLeft(3)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'FAILED TOTAL AMOUNT        : ${fmt(failedTotal)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'FAILED-CASH AMOUNT         : ${fmt(failedCash)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'FAILED-UPI  AMOUNT         : ${fmt(failedUpi)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'FAILED-CARD AMOUNT         : ${fmt(failedCard)}',
          size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Printed on : $printedStr', size: 20, align: 0);
      await printer.printText(text: '\n\n', size: 20, align: 1);
      await printer.cutPaper();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _printSalesSummary() async {
    setState(() => _isGenerating = true);
    try {
      final payments = ref.read(paymentProvider).payments;
      final config = ref.read(billConfigProvider);

      if (payments.isEmpty) return;

      // Sort by date to get date range and ticket range
      final sorted = [...payments]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final firstTicket = sorted.first.billNumber;
      final lastTicket = sorted.last.billNumber;
      final startingDate = sorted.first.createdAt;
      final endingDate = sorted.last.createdAt;

      final successList = payments.where((p) => p.isSuccess).toList();
      final failedList = payments.where((p) => p.isFailed).toList();

      double sum(Iterable<Payment> list) =>
          list.fold(0.0, (s, p) => s + p.amount);

      // Per-method groups
      final cashSuccess = successList.where((p) => p.method == PaymentMethod.cash).toList();
      final upiSuccess  = successList.where((p) => p.method == PaymentMethod.upi).toList();
      final cardSuccess = successList.where((p) => p.method == PaymentMethod.card).toList();
      final upiFailedList  = failedList.where((p) => p.method == PaymentMethod.upi).toList();
      final cardFailedList = failedList.where((p) => p.method == PaymentMethod.card).toList();

      final transTotal  = sum(successList);
      final cashAmt     = sum(cashSuccess);
      final upiAmt      = sum(upiSuccess);
      final cardAmt     = sum(cardSuccess);
      final failedUpiAmt  = sum(upiFailedList);
      final failedCardAmt = sum(cardFailedList);

      final dateStr      = DateFormat('dd-MM-yyyy').format(_selectedDate);
      final printedStr   = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
      final startDateStr = DateFormat('dd-MM-yyyy HH:mm:ss').format(startingDate);
      final endDateStr   = DateFormat('dd-MM-yyyy HH:mm:ss').format(endingDate);
      final terminal = (config.unitName != null && config.unitName!.isNotEmpty)
          ? config.unitName!
          : config.orgName;

      String fmt(double v) => v.toStringAsFixed(2);
      String cnt(int n, double v) =>
          n > 0 ? '${n.toString().padLeft(2)}  ${fmt(v)}' : '';

      final printer = SmartPosPrinterService();
      await printer.initSdk();

      // ── Header ─────────────────────────────────────────────────────────
      if (config.orgName.isNotEmpty) {
        await printer.printText(text: config.orgName, size: 26, isBold: true, align: 1);
      }
      await printer.printText(text: 'SALES SUMMARY', size: 22, isBold: true, align: 1);
      if (config.unitName != null && config.unitName!.isNotEmpty) {
        await printer.printText(text: config.unitName!, size: 20, align: 1);
      }
      await printer.printText(text: 'Sale Date  : $dateStr', size: 20, align: 0);
      await printer.printText(text: 'Terminal   : $terminal', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Starting Date      : $startDateStr', size: 20, align: 0);
      await printer.printText(text: 'Ending Date        : $endDateStr', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Starting Ticket No : $firstTicket', size: 20, align: 0);
      await printer.printText(text: 'Ending Ticket No   : $lastTicket', size: 20, align: 0);
      await printer.printText(text: '', size: 20, align: 0);

      // ── Item/method section ────────────────────────────────────────────
      await printer.printText(
          text: 'ITEM          TICKETS  AMOUNT', size: 20, isBold: true, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);

      // Helper to print one method-group block
      Future<void> printMethodBlock(
          String label, List<Payment> successGroup, List<Payment> failedGroup) async {
        final total = sum(successGroup) + sum(failedGroup);
        final tickets = successGroup.length + failedGroup.length;
        if (tickets == 0) return;
        await printer.printText(
            text: '${label.padRight(14)}${tickets.toString().padLeft(4)}  ${fmt(total)}',
            size: 20, align: 0);
        await printer.printText(
            text: 'Cash :       ${label == "CASH" ? cnt(cashSuccess.length, cashAmt) : ""}',
            size: 20, align: 0);
        await printer.printText(
            text: 'Success-Upi :${label == "UPI" ? cnt(upiSuccess.length, upiAmt) : ""}',
            size: 20, align: 0);
        await printer.printText(
            text: 'Success-Card :${label == "CARD" ? cnt(cardSuccess.length, cardAmt) : ""}',
            size: 20, align: 0);
        await printer.printText(
            text: 'Failed-Upi : ${label == "UPI" && upiFailedList.isNotEmpty ? cnt(upiFailedList.length, failedUpiAmt) : ""}',
            size: 20, align: 0);
        await printer.printText(
            text: 'Failed-Card :${label == "CARD" && cardFailedList.isNotEmpty ? cnt(cardFailedList.length, failedCardAmt) : ""}',
            size: 20, align: 0);
        await printer.printText(text: '', size: 20, align: 0);
      }

      await printMethodBlock('CASH', cashSuccess, []);
      await printMethodBlock('UPI',  upiSuccess,  upiFailedList);
      await printMethodBlock('CARD', cardSuccess, cardFailedList);

      await printer.printText(text: '--------------------------------', size: 20, align: 1);

      // ── Totals footer ──────────────────────────────────────────────────
      await printer.printText(
          text: 'TRANS. AMOUNT :  ${fmt(transTotal).padLeft(16)}',
          size: 22, isBold: true, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(
          text: 'CASH :         ${cashSuccess.length.toString().padLeft(3)}    ${fmt(cashAmt).padLeft(10)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'SUCCESS - UPI :${upiSuccess.length.toString().padLeft(3)}    ${fmt(upiAmt).padLeft(10)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'SUCCESS - CARD :${cardSuccess.length.toString().padLeft(2)}    ${fmt(cardAmt).padLeft(10)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'FAILED - UPI : ${upiFailedList.length.toString().padLeft(3)}    ${fmt(failedUpiAmt).padLeft(10)}',
          size: 20, align: 0);
      await printer.printText(
          text: 'FAILED - CARD :${cardFailedList.length.toString().padLeft(3)}    ${fmt(failedCardAmt).padLeft(10)}',
          size: 20, align: 0);
      await printer.printText(text: '--------------------------------', size: 20, align: 1);
      await printer.printText(
          text: 'FINAL RECEIVED AMOUNT : ${fmt(transTotal).padLeft(10)}',
          size: 22, isBold: true, align: 0);
      await printer.printText(text: '', size: 20, align: 0);
      await printer.printText(text: 'Printed on : $printedStr', size: 20, align: 0);
      await printer.printText(text: '\n\n', size: 20, align: 1);
      await printer.cutPaper();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final payments = paymentState.payments;

    // Calculate statistics
    final totalAmount = payments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final cashPayments = payments.where((p) => p.method == PaymentMethod.cash).toList();
    final onlinePayments = payments.where((p) => p.method == PaymentMethod.upi).toList();
    final cardPayments = payments.where((p) => p.method == PaymentMethod.card).toList();
    final cashAmount = cashPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final onlineAmount = onlinePayments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final cardAmount = cardPayments.fold<double>(0.0, (sum, p) => sum + p.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day Summary Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: paymentState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Date Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (payments.isNotEmpty)
                        Text(
                          '${payments.length} bills',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                    ],
                  ),
                ),

                // Statistics Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Collection',
                              value: '₹${totalAmount.toStringAsFixed(2)}',
                              icon: Icons.account_balance_wallet,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Total Bills',
                              value: payments.length.toString(),
                              icon: Icons.receipt_long,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Cash',
                              value: '₹${cashAmount.toStringAsFixed(2)}',
                              subtitle: '${cashPayments.length} bills',
                              icon: Icons.money,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'UPI / Online',
                              value: '₹${onlineAmount.toStringAsFixed(2)}',
                              subtitle: '${onlinePayments.length} bills',
                              icon: Icons.qr_code,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'Card',
                              value: '₹${cardAmount.toStringAsFixed(2)}',
                              subtitle: '${cardPayments.length} bills',
                              icon: Icons.credit_card,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Payment List
                Expanded(
                  child: payments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No payments for this date',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: payments.length,
                          itemBuilder: (context, index) {
                            final payment = payments[index];
                            return _PaymentListItem(payment: payment);
                          },
                        ),
                ),

                // Action Buttons
                if (payments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _printOnPos,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.receipt_long),
                            label: const Text('Transaction\nSummary', textAlign: TextAlign.center),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isGenerating ? null : _printSalesSummary,
                            icon: _isGenerating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.summarize),
                            label: const Text('Sales\nSummary', textAlign: TextAlign.center),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentListItem extends StatelessWidget {
  final Payment payment;

  const _PaymentListItem({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: payment.method == PaymentMethod.cash
              ? Colors.orange.withValues(alpha: 0.2)
              : Colors.purple.withValues(alpha: 0.2),
          child: Icon(
            payment.method == PaymentMethod.cash ? Icons.money : Icons.qr_code,
            color: payment.method == PaymentMethod.cash ? Colors.orange : Colors.purple,
          ),
        ),
        title: Text(
          payment.billNumber,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          DateFormat('hh:mm a').format(payment.createdAt),
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              payment.methodDisplay,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
