import '../../../../data/models/bill_config_model.dart';
import '../../../../core/constants/plutus_config.dart';
import '../../../../core/services/plutus_smart_service.dart';
import '../../../../services/smart_pos_printer_service.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/thermal_print_settings_provider.dart';

// ─── Thermal receipt layout (Pine Labs Plutus / SmartPOS fallback) ─────────────
// Effective line width: 40 chars (utilizes full 80mm paper width).

const int _kLineW      = 40;
const int _kAlignLeft   = 0;
const int _kAlignCenter = 1;

const int _kSizeBody   = 28;
const int _kSizeHeader = 32;

const String _kDash = '----------------------------------------'; // 40 dashes

class _ThermalLine {
  final String text;
  final int size;
  final bool bold;
  final int align;

  const _ThermalLine({
    required this.text,
    this.size  = _kSizeBody,
    this.bold  = false,
    this.align = _kAlignLeft,
  });

  static const _ThermalLine blank = _ThermalLine(text: '');
}

// ─── Format helpers ────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.year}';

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}';

/// Wraps [text] at word boundaries to fit within [width] chars per line.
List<String> _wrapWords(String text, int width) {
  if (text.length <= width) return [text];
  final words = text.split(' ');
  final lines = <String>[];
  var current = '';
  for (final word in words) {
    final chunk = word.length > width ? word.substring(0, width) : word;
    if (current.isEmpty) {
      current = chunk;
    } else if (current.length + 1 + chunk.length <= width) {
      current = '$current $chunk';
    } else {
      lines.add(current);
      current = chunk;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines.isEmpty ? [text.substring(0, width.clamp(0, text.length))] : lines;
}

/// "KEY   : value" — key padded to [keyW] chars, left-aligned.
String _kv(String key, String value, {int keyW = 5}) =>
    '${key.padRight(keyW)} : $value';

/// Label left, value right, total [_kLineW] chars.
String _summaryRow(String label, String value) {
  final space = _kLineW - label.length - value.length;
  if (space <= 0) {
    final maxL = (_kLineW - value.length - 1).clamp(0, label.length);
    return '${label.substring(0, maxL)} $value';
  }
  return '$label${' ' * space}$value';
}

/// Normalised payment label for print.
String _paymentMode(String method) {
  switch (method.toLowerCase()) {
    case 'cash':
      return 'CASH';
    case 'card':
      return 'CARD';
    case 'upi':
    case 'online':
      return 'UPI';
    default:
      return method.toUpperCase();
  }
}

// ─── Item table ────────────────────────────────────────────────────────────────

const int _kQtyW   = 6;
const int _kNameW  = 22;
const int _kPriceW = 12;

String _itemsHeader() =>
    '${'QTY'.padRight(_kQtyW)}${'ITEM'.padRight(_kNameW)}${'PRICE'.padLeft(_kPriceW)}';

List<String> _itemRows(int qty, String name, String price) {
  final qtyStr   = '${qty}x'.padRight(_kQtyW);
  final priceStr = price.padLeft(_kPriceW);

  final chunks = <String>[];
  var rem = name;
  while (rem.isNotEmpty) {
    chunks.add(rem.length > _kNameW ? rem.substring(0, _kNameW) : rem);
    rem = rem.length > _kNameW ? rem.substring(_kNameW) : '';
  }
  if (chunks.isEmpty) chunks.add('');

  final rows = <String>[];
  for (var i = 0; i < chunks.length; i++) {
    rows.add(i == 0
        ? '$qtyStr${chunks[i].padRight(_kNameW)}$priceStr'
        : '${' ' * _kQtyW}${chunks[i].padRight(_kNameW)}');
  }
  return rows;
}

// ─── Slip builders ─────────────────────────────────────────────────────────────

List<_ThermalLine> _buildInvoiceSlip({
  required String orgName,
  String? unitName,
  String? gstin,
  String? posId,
  required String billNumber,
  required DateTime dateTime,
  required List<({int qty, String name, double amount})> items,
  required double subtotal,
  required Map<String, double> taxes,
  required double total,
  required String paymentMethod,
  required String footer,
  required ThermalPrintSettings settings,
}) {
  final out = <_ThermalLine>[];

  // ── Header ──────────────────────────────────────────────────────────────────
  out.add(_ThermalLine.blank);
  if (orgName.isNotEmpty) {
    for (final line in _wrapWords(orgName, _kLineW)) {
      out.add(_ThermalLine(text: line, size: settings.bodySize, bold: true, align: _kAlignCenter));
    }
  }
  out.add(_ThermalLine(
    text:  'INVOICE',
    size:  settings.headerSize,
    bold:  true,
    align: _kAlignCenter,
  ));
  if (unitName != null && unitName.isNotEmpty) {
    for (final line in _wrapWords(unitName, _kLineW)) {
      out.add(_ThermalLine(text: line, align: _kAlignCenter, size: settings.bodySize));
    }
  }

  // ── Bill metadata ─────────────────────────────────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  if (gstin != null && gstin.isNotEmpty) {
    out.add(_ThermalLine(text: _kv('GSTIN', gstin, keyW: 5), bold: true));
  }
  if (posId != null && posId.isNotEmpty) {
    out.add(_ThermalLine(text: _kv('POS', posId, keyW: 5), bold: true));
  }
  out.add(_ThermalLine(text: _kv('Bill', billNumber, keyW: 5), bold: true));
  out.add(_ThermalLine(text: _kv('Date', _formatDate(dateTime), keyW: 5), bold: true));
  out.add(_ThermalLine(text: _kv('Time', _formatTime(dateTime), keyW: 5), bold: true));

  // ── Items ──────────────────────────────────────────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  out.add(_ThermalLine(text: _itemsHeader(), bold: true));
  for (final it in items) {
    for (final row in _itemRows(it.qty, it.name, it.amount.toStringAsFixed(2))) {
      out.add(_ThermalLine(text: row, bold: true));
    }
  }

  // ── Tax summary — full breakdown for invoice ──────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  if (taxes.isNotEmpty) {
    out.add(_ThermalLine(text: _summaryRow('Subtotal', subtotal.toStringAsFixed(2)), bold: true));
    for (final entry in taxes.entries) {
      out.add(_ThermalLine(text: _summaryRow(entry.key, entry.value.toStringAsFixed(2)), bold: true));
    }
    out.add(const _ThermalLine(text: _kDash));
  }

  // ── Total + payment ───────────────────────────────────────────────────────
  out.add(_ThermalLine(
    text: _summaryRow('TOTAL', 'Rs.${total.toStringAsFixed(2)}'),
    bold: true,
    size: settings.headerSize,
  ));
  final mode = _paymentMode(paymentMethod);
  if (mode.isNotEmpty) {
    out.add(_ThermalLine(text: _kv('Pay', mode, keyW: 5), bold: true));
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  out.add(_ThermalLine(text: footer, align: _kAlignCenter, bold: true, size: settings.bodySize));
  out
    ..add(_ThermalLine.blank)
    ..add(_ThermalLine.blank);

  return out;
}

// Ticket = Invoice layout with "TICKET" title and no CGST/SGST lines.
List<_ThermalLine> _buildTicketSlip({
  required String orgName,
  String? unitName,
  String? gstin,
  String? posId,
  required String billNumber,
  required DateTime dateTime,
  required List<({int qty, String name, double amount})> items,
  required double subtotal,
  required Map<String, double> taxes,
  required double total,
  required String paymentMethod,
  required String footer,
  required ThermalPrintSettings settings,
}) {
  final out = <_ThermalLine>[];

  // ── Header ──────────────────────────────────────────────────────────────────
  out.add(_ThermalLine.blank);
  if (orgName.isNotEmpty) {
    for (final line in _wrapWords(orgName, _kLineW)) {
      out.add(_ThermalLine(
        text:  line,
        size:  settings.bodySize,
        bold:  true,
        align: _kAlignCenter,
      ));
    }
  }
  out.add(_ThermalLine(
    text:  'TICKET',
    size:  settings.headerSize,
    bold:  true,
    align: _kAlignCenter,
  ));
  if (unitName != null && unitName.isNotEmpty) {
    for (final line in _wrapWords(unitName, _kLineW)) {
      out.add(_ThermalLine(text: line, align: _kAlignCenter, size: settings.bodySize));
    }
  }

  // ── Bill metadata ─────────────────────────────────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  if (gstin != null && gstin.isNotEmpty) {
    out.add(_ThermalLine(text: _kv('GSTIN', gstin, keyW: 5), bold: true));
  }
  if (posId != null && posId.isNotEmpty) {
    out.add(_ThermalLine(text: _kv('POS', posId, keyW: 5), bold: true));
  }
  out.add(_ThermalLine(text: _kv('Bill', billNumber, keyW: 5), bold: true));
  out.add(_ThermalLine(text: _kv('Date', _formatDate(dateTime), keyW: 5), bold: true));
  out.add(_ThermalLine(text: _kv('Time', _formatTime(dateTime), keyW: 5), bold: true));

  // ── Items ──────────────────────────────────────────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  out.add(_ThermalLine(text: _itemsHeader(), bold: true));
  for (final it in items) {
    for (final row in _itemRows(it.qty, it.name, it.amount.toStringAsFixed(2))) {
      out.add(_ThermalLine(text: row));
    }
  }

  // ── Summary — Subtotal only (no CGST/SGST) ───────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  if (taxes.isNotEmpty) {
    out.add(_ThermalLine(
      text: _summaryRow('Subtotal', subtotal.toStringAsFixed(2)),
      bold: true,
    ));
    out.add(const _ThermalLine(text: _kDash));
  }

  // ── Total + payment ───────────────────────────────────────────────────────
  out.add(_ThermalLine(
    text: _summaryRow('TOTAL', 'Rs.${total.toStringAsFixed(2)}'),
    bold: true,
    size: settings.headerSize,
  ));
  final mode = _paymentMode(paymentMethod);
  if (mode.isNotEmpty) {
    out.add(_ThermalLine(text: _kv('Pay', mode, keyW: 5), bold: true));
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  out.add(const _ThermalLine(text: _kDash));
  out.add(_ThermalLine(text: footer, align: _kAlignCenter, bold: true, size: settings.bodySize));
  out
    ..add(_ThermalLine.blank)
    ..add(_ThermalLine.blank);

  return out;
}

// ─── Plutus / SmartPOS transport ──────────────────────────────────────────────

Future<void> _sendToPrinter(
  SmartPosPrinterService printer,
  List<_ThermalLine> lines,
) async {
  await printer.printLines(
    lines
        .map((line) => <String, Object?>{
              'text':   line.text,
              'size':   line.size,
              'isBold': line.bold,
              'align':  line.align,
            })
        .toList(),
  );
}

List<Map<String, dynamic>> _toPlutusPrintData(List<_ThermalLine> lines) {
  return lines
      .map((line) => <String, dynamic>{
            'PrintDataType':   '0',
            'PrinterWidth':    _kLineW,
            'IsCenterAligned': line.align == _kAlignCenter,
            'DataToPrint':     line.text,
            'ImagePath':       '0',
            'ImageData':       '0',
          })
      .toList();
}

Future<void> _sendToPlutusPrinter({
  required String printRefNo,
  required List<_ThermalLine> lines,
  void Function(String message)? onDebug,
}) async {
  onDebug?.call('Binding to Pine Labs MasterApp');
  await PlutusSmartService.bindToService();
  onDebug?.call('MasterApp bind successful');
  final printJson = PlutusRequestBuilder.printJob(
    applicationId: PlutusConfig.applicationId.trim(),
    versionNo:     PlutusConfig.apiVersion,
    userId:        PlutusConfig.userId.trim().isEmpty
        ? null
        : PlutusConfig.userId.trim(),
    printRefNo:    printRefNo,
    data:          _toPlutusPrintData(lines),
  );
  onDebug?.call('Sending print job $printRefNo (${lines.length} lines)');
  final response = await PlutusSmartService.startPrintJob(printJson: printJson);
  if (response == null || response.trim().isEmpty) {
    onDebug?.call('Print job $printRefNo returned empty MasterApp response');
  } else {
    onDebug?.call('Print job $printRefNo MasterApp response: $response');
  }
  onDebug?.call('Print job $printRefNo accepted by MasterApp');
}

// ─── Public API ───────────────────────────────────────────────────────────────

Future<void> printBillThermalInvoiceAndTicket({
  required SmartPosPrinterService printer,
  required BillConfig config,
  required String billDisplay,
  required DateTime dateTime,
  required CartState cartState,
  required double total,
  required double taxableAmount,
  required double cgstAmount,
  required double sgstAmount,
  required bool hasTax,
  required String paymentMethod,
  required ThermalPrintSettings settings,
  void Function(String message)? onDebug,
}) async {
  onDebug?.call('Preparing invoice and ticket print data');
  final items = cartState.items.values
      .map((it) => (qty: it.quantity, name: it.product.name, amount: it.total))
      .toList();
  onDebug?.call('Cart items: ${items.length}, total: ${total.toStringAsFixed(2)}');

  final taxes = <String, double>{};
  if (hasTax) {
    taxes['CGST (${config.cgstPercent.toStringAsFixed(0)}%)'] = cgstAmount;
    taxes['SGST (${config.sgstPercent.toStringAsFixed(0)}%)'] = sgstAmount;
  }

  final rawFooter =
      (config.footerMessage != null && config.footerMessage!.isNotEmpty)
          ? config.footerMessage!
          : 'Thank you. Visit again!';
  final footer = '|$rawFooter|';

  final invoiceLines = _buildInvoiceSlip(
    orgName:       config.orgName,
    unitName:      config.unitName,
    gstin:         config.gstNumber,
    posId:         config.posId,
    billNumber:    billDisplay,
    dateTime:      dateTime,
    items:         items,
    subtotal:      taxableAmount,
    taxes:         taxes,
    total:         total,
    paymentMethod: paymentMethod,
    footer:        footer,
    settings:      settings,
  );

  final ticketLines = _buildTicketSlip(
    orgName:       config.orgName,
    unitName:      config.unitName,
    gstin:         config.gstNumber,
    posId:         config.posId,
    billNumber:    billDisplay,
    dateTime:      dateTime,
    items:         items,
    subtotal:      taxableAmount,
    taxes:         taxes,
    total:         total,
    paymentMethod: paymentMethod,
    footer:        footer,
    settings:      settings,
  );

  if (PlutusConfig.isConfigured) {
    onDebug?.call('Using Pine Labs print path');
    onDebug?.call('Plutus ApplicationId: ${PlutusConfig.applicationId.trim()}');
    await _sendToPlutusPrinter(
      printRefNo: billDisplay,
      lines:      invoiceLines,
      onDebug:    onDebug,
    );
    await _sendToPlutusPrinter(
      printRefNo: '$billDisplay-T',
      lines:      ticketLines,
      onDebug:    onDebug,
    );
    onDebug?.call('Invoice and ticket print completed');
    return;
  }

  onDebug?.call('Plutus disabled — using SmartPOS fallback');
  await printer.initSdk();
  await _sendToPrinter(printer, invoiceLines);
  await printer.cutPaper();
  await _sendToPrinter(printer, ticketLines);
  await printer.cutPaper();
  onDebug?.call('Invoice and ticket print completed');
}

// ─── Public summary-print helper ──────────────────────────────────────────────

/// Simple record for a single thermal print line used by summary reports.
typedef ThermalPrintLine = ({String text, int size, bool bold, int align});

/// Print a batch of lines via Pine Labs Plutus (when configured) or SmartPOS fallback.
/// Used by transaction/sales/day-summary reports that don't go through _buildInvoiceSlip.
Future<void> printThermalLineBatch({
  required SmartPosPrinterService printer,
  required String printRefNo,
  required List<ThermalPrintLine> lines,
  void Function(String)? onDebug,
}) async {
  final thermalLines = lines
      .map((l) => _ThermalLine(text: l.text, size: l.size, bold: l.bold, align: l.align))
      .toList();

  if (PlutusConfig.isConfigured) {
    onDebug?.call('Routing batch print via Plutus ($printRefNo)');
    await _sendToPlutusPrinter(
      printRefNo: printRefNo,
      lines:      thermalLines,
      onDebug:    onDebug,
    );
  } else {
    onDebug?.call('Routing batch print via SmartPOS ($printRefNo)');
    await printer.initSdk();
    await _sendToPrinter(printer, thermalLines);
    await printer.cutPaper();
  }
}
