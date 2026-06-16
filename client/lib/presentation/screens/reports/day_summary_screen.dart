import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/payment_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/bill_config_provider.dart';
import '../../../services/smart_pos_printer_service.dart';
import '../orders/create/bill_thermal_print.dart';

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
      final printedStr = DateFormat('dd-MM-yy HH:mm').format(DateTime.now());
      final terminal = (config.unitName != null && config.unitName!.isNotEmpty)
          ? config.unitName!
          : config.orgName;

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
        final method = p.method == PaymentMethod.cash
            ? 'Cash'
            : p.method == PaymentMethod.upi ? 'UPI' : 'Card';
        ln('  ${method.padRight(5)}${fmt(p.amount).padLeft(15)}');
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
      final startingDate = sorted.first.createdAtLocal;
      final endingDate = sorted.last.createdAtLocal;

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
      final printedStr   = DateFormat('dd-MM-yy HH:mm').format(DateTime.now());
      final startDateStr = DateFormat('dd-MM-yy HH:mm').format(startingDate);
      final endDateStr   = DateFormat('dd-MM-yy HH:mm').format(endingDate);
      final terminal = (config.unitName != null && config.unitName!.isNotEmpty)
          ? config.unitName!
          : config.orgName;

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
      ln('From: $firstTicket');
      ln('To:   $lastTicket');
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
      stat('FAIL UPI AMT', fmt(failedUpiAmt));
      stat('FAIL CARD AMT', fmt(failedCardAmt));
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
                                  fontSize: 14,
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
                  fontSize: 11,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 10,
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
          DateFormat('hh:mm a').format(payment.createdAtLocal),
          style: TextStyle(color: Colors.grey[600], fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              payment.methodDisplay,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
