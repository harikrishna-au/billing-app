import '../../../../core/utils/bill_number_generator.dart';
import '../../../../data/models/bill_config_model.dart';
import '../../../../services/smart_pos_printer_service.dart';
import '../../../providers/cart_provider.dart';

String billPaymentLabelForPrint(String method) {
  switch (method.toLowerCase()) {
    case 'cash':
      return 'CASH';
    case 'card':
      return 'CARD / Online';
    case 'online':
    case 'upi':
      return 'UPI / Online';
    default:
      return method.toUpperCase();
  }
}

/// Prints INVOICE + TICKET thermal copies (same layout as main branch).
Future<void> printBillThermalInvoiceAndTicket({
  required SmartPosPrinterService printer,
  required BillConfig config,
  required String billNumber,
  required String dateStr,
  required CartState cartState,
  required double total,
  required double taxableAmount,
  required double cgstAmount,
  required double sgstAmount,
  required bool hasTax,
  required String paymentMethod,
}) async {
  final billDisplay = BillNumberGenerator.displayTicketNumber(billNumber);

  await printer.initSdk();

  await printer.printText(
    text: 'INVOICE',
    size: 22,
    isBold: true,
    align: 1,
  );
  if (config.orgName.isNotEmpty) {
    await printer.printText(
      text: config.orgName,
      size: 20,
      isBold: true,
      align: 1,
    );
  }
  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );

  if (config.unitName != null && config.unitName!.isNotEmpty) {
    await printer.printText(text: config.unitName!, size: 20, align: 0);
  }
  if (config.territory != null && config.territory!.isNotEmpty) {
    await printer.printText(text: config.territory!, size: 20, align: 0);
  }
  if (config.gstNumber != null && config.gstNumber!.isNotEmpty) {
    await printer.printText(
      text: 'GSTIN: ${config.gstNumber!}',
      size: 20,
      align: 0,
    );
  }
  if (config.posId != null && config.posId!.isNotEmpty) {
    await printer.printText(
      text: 'POS ID: ${config.posId!}',
      size: 20,
      align: 0,
    );
  }
  if ((config.unitName != null && config.unitName!.isNotEmpty) ||
      (config.territory != null && config.territory!.isNotEmpty) ||
      (config.gstNumber != null && config.gstNumber!.isNotEmpty) ||
      (config.posId != null && config.posId!.isNotEmpty)) {
    await printer.printText(
      text: '--------------------------------',
      size: 20,
      align: 1,
    );
  }

  await printer.printText(
    text: 'Bill No: $billDisplay',
    size: 20,
    align: 0,
  );
  await printer.printText(text: dateStr, size: 20, align: 0);
  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );

  for (final item in cartState.items.values) {
    final line =
        '${item.product.name}  x${item.quantity}   Rs.${item.total.toStringAsFixed(2)}';
    await printer.printText(text: line, size: 20, align: 0);
  }

  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );
  await printer.printText(
    text: 'TOTAL  Rs.${total.toStringAsFixed(2)}',
    size: 20,
    isBold: true,
    align: 0,
  );
  if (hasTax) {
    await printer.printText(
      text: 'Taxable Amt  Rs.${taxableAmount.toStringAsFixed(2)}',
      size: 20,
      align: 0,
    );
    await printer.printText(
      text:
          'CGST @${config.cgstPercent.toStringAsFixed(0)}%  Rs.${cgstAmount.toStringAsFixed(2)}',
      size: 20,
      align: 0,
    );
    await printer.printText(
      text:
          'SGST @${config.sgstPercent.toStringAsFixed(0)}%  Rs.${sgstAmount.toStringAsFixed(2)}',
      size: 20,
      align: 0,
    );
  }
  await printer.printText(
    text: 'Payment: ${billPaymentLabelForPrint(paymentMethod)}',
    size: 20,
    align: 0,
  );
  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );

  final footer =
      (config.footerMessage != null && config.footerMessage!.isNotEmpty)
          ? config.footerMessage!
          : 'Thank you. Visit again!';
  await printer.printText(text: footer, size: 20, align: 1);
  await printer.printText(text: '\n\n', size: 20, align: 1);
  await printer.cutPaper();

  await printer.printText(
    text: 'TICKET',
    size: 22,
    isBold: true,
    align: 1,
  );
  if (config.orgName.isNotEmpty) {
    await printer.printText(
      text: config.orgName,
      size: 20,
      isBold: true,
      align: 1,
    );
  }
  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );
  await printer.printText(
    text: 'Ticket No: $billDisplay',
    size: 20,
    align: 0,
  );
  await printer.printText(text: dateStr, size: 20, align: 0);
  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );
  for (final item in cartState.items.values) {
    final line =
        '${item.product.name}  x${item.quantity}   Rs.${item.total.toStringAsFixed(2)}';
    await printer.printText(text: line, size: 20, align: 0);
  }
  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );
  await printer.printText(
    text: 'TOTAL  Rs.${total.toStringAsFixed(2)}',
    size: 20,
    isBold: true,
    align: 0,
  );
  if (hasTax) {
    await printer.printText(
      text: 'Incl. all taxes',
      size: 20,
      align: 0,
    );
  }
  await printer.printText(
    text: 'Payment: ${billPaymentLabelForPrint(paymentMethod)}',
    size: 20,
    align: 0,
  );
  await printer.printText(
    text: '--------------------------------',
    size: 20,
    align: 1,
  );
  await printer.printText(
    text: 'Customer copy',
    size: 20,
    align: 1,
  );
  await printer.printText(text: '\n\n', size: 20, align: 1);
  await printer.cutPaper();
}
