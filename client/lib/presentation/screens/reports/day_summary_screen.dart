import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/payment_model.dart';
import '../../../data/repositories/api_analytics_repository.dart';
import '../../providers/payment_provider.dart';
import '../../providers/bill_config_provider.dart';
import '../../../services/smart_pos_printer_service.dart';
import '../../../core/network/providers.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPayments();
    });
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
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final analytics = ApiAnalyticsRepository(apiClient);
      final config = ref.read(billConfigProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // Fetch summary from backend
      final summary = await analytics.getTransactionSummary(dateStr);

      String fmt(double v) => v.toStringAsFixed(2);
      final printedStr = DateFormat('dd-MM-yy HH:mm').format(DateTime.now());
      final terminal = (config.unitName != null && config.unitName!.isNotEmpty)
          ? config.unitName!
          : config.orgName;

      final lines = <ThermalPrintLine>[];
      void ln(String text, {int size = 18, bool bold = false, int align = 0}) =>
          lines.add((text: text, size: size, bold: bold, align: align));

      if (config.orgName.isNotEmpty) ln(config.orgName, size: 24, bold: true, align: 1);
      ln('TRANSACTION SUMMARY', size: 20, bold: true, align: 1);
      if (config.unitName?.isNotEmpty == true) ln(config.unitName!, size: 18, bold: true, align: 1);
      ln('Sale Date : ${DateFormat('dd-MM-yyyy').format(_selectedDate)}', bold: true);
      ln('Term: ${terminal.length > 30 ? terminal.substring(0, 30) : terminal}', bold: true);
      ln('----------------------------------------', align: 1);
      ln('BILL#        AMOUNT  METHOD', bold: true);
      ln('----------------------------------------', align: 1);

      for (final p in summary.payments) {
        final billNum = p.billNumber.length > 12 ? p.billNumber.substring(0, 12) : p.billNumber;
        ln('${billNum.padRight(12)}${fmt(p.amount).padLeft(8)}  ${p.method}', bold: true);
      }

      void stat(String label, String val) =>
          ln('${label.padRight(15)}${val.padLeft(12)}', bold: true);

      ln('------------------------', align: 1);
      stat('SUCC TX', summary.successfulCount.toString());
      stat('SUCC AMT', fmt(summary.successfulAmount));
      stat('SUCC CASH', fmt(summary.successfulCash));
      stat('SUCC UPI', fmt(summary.successfulUpi));
      stat('SUCC CARD', fmt(summary.successfulCard));
      ln('');
      stat('FAIL TX', summary.failedCount.toString());
      stat('FAIL AMT', fmt(summary.failedAmount));
      stat('FAIL CASH', fmt(summary.failedCash));
      stat('FAIL UPI', fmt(summary.failedUpi));
      stat('FAIL CARD', fmt(summary.failedCard));
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
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final config = ref.read(billConfigProvider);

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final summary = await ApiAnalyticsRepository(ref.read(apiClientProvider))
          .getSalesSummary(dateStr);

      String fmt(double v) => v.toStringAsFixed(2);
      final printedStr = DateFormat('dd-MM-yy HH:mm').format(DateTime.now());

      final lines = <ThermalPrintLine>[];
      void ln(String text, {int size = 18, bool bold = false, int align = 0}) =>
          lines.add((text: text, size: size, bold: bold, align: align));

      if (config.orgName.isNotEmpty) ln(config.orgName, size: 24, bold: true, align: 1);
      ln('SALES SUMMARY', size: 20, bold: true, align: 1);
      if (config.unitName?.isNotEmpty == true) ln(config.unitName!, size: 18, bold: true, align: 1);
      ln('Date: ${DateFormat('dd-MM-yyyy').format(_selectedDate)}', bold: true);
      ln('----------------------------------------', align: 1);
      ln('Start: ${summary.startTime}', bold: true);
      ln('End:   ${summary.endTime}', bold: true);
      ln('Bills: ${summary.firstBill} to ${summary.lastBill}', bold: true);
      ln('----------------------------------------', align: 1);
      ln('METHOD        CNT      AMOUNT', bold: true);
      ln('----------------------------------------', align: 1);

      void stat(String label, String val) =>
          ln('${label.padRight(18)}${val.padLeft(12)}', bold: true);

      for (final method in summary.byMethod) {
        final tickets = method.count + method.failedCount;
        if (tickets == 0) continue;
        final total = method.amount + method.failedAmount;
        ln('${method.method.padRight(14)}${tickets.toString().padLeft(3)}  ${fmt(total).padLeft(12)}', bold: true);
        if (method.failedCount > 0) {
          ln('  [FAIL] ${method.failedCount.toString().padLeft(3)}  ${fmt(method.failedAmount).padLeft(12)}', bold: true);
        }
      }

      ln('----------------------------------------', align: 1);
      stat('TOTAL', fmt(summary.totalAmount));
      for (final method in summary.byMethod) {
        stat(method.method, fmt(method.amount));
      }
      if (summary.failedUpiAmount > 0) stat('FAIL UPI', fmt(summary.failedUpiAmount));
      if (summary.failedCardAmount > 0) stat('FAIL CARD', fmt(summary.failedCardAmount));
      ln('----------------------------------------', align: 1);
      ln('FINAL TOTAL: ${fmt(summary.totalAmount).padLeft(13)}', size: 22, bold: true);
      ln('');
      ln('Printed: $printedStr', size: 16);

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

    // Calculate statistics — only count successful payments for amounts/counts.
    final successPayments = payments.where((p) => p.isSuccess).toList();
    final totalAmount = successPayments.fold<double>(0.0, (sum, p) => sum + p.amount);
    final cashPayments = successPayments.where((p) => p.method == PaymentMethod.cash).toList();
    final onlinePayments = successPayments.where((p) => p.method == PaymentMethod.upi).toList();
    final cardPayments = successPayments.where((p) => p.method == PaymentMethod.card).toList();
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
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (payments.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${successPayments.length} bills',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
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
                              value: successPayments.length.toString(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
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
              : payment.method == PaymentMethod.card
                  ? Colors.teal.withValues(alpha: 0.2)
                  : Colors.purple.withValues(alpha: 0.2),
          child: Icon(
            payment.method == PaymentMethod.cash
                ? Icons.money
                : payment.method == PaymentMethod.card
                    ? Icons.credit_card
                    : Icons.qr_code,
            color: payment.method == PaymentMethod.cash
                ? Colors.orange
                : payment.method == PaymentMethod.card
                    ? Colors.teal
                    : Colors.purple,
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
