import '../../../../data/models/bill_config_model.dart';
import '../../../../services/smart_pos_printer_service.dart';
import '../../../providers/cart_provider.dart';
import 'receipt_layout_spec.dart';

// ─── Thermal receipt layout (single file) ───────────────────────────────────
// 58/80 mm paper · SmartPOS printText bridge.

final String _kDivider = ReceiptLayoutSpec.thermalDivider;

const int _kAlignLeft = 0;
const int _kAlignCenter = 1;

const int _kSizeBody = 20;
const int _kSizeHeader = 24;
const int _kSizeTitle = 28;
const int _kSizeTotal = 24;

class _ThermalLine {
  final String text;
  final int size;
  final bool bold;
  final int align;

  const _ThermalLine({
    required this.text,
    this.size = _kSizeBody,
    this.bold = false,
    this.align = _kAlignLeft,
  });

  static const _ThermalLine blank = _ThermalLine(text: '');

  static _ThermalLine get divider => _ThermalLine(
        text: _kDivider,
        align: _kAlignCenter,
      );
}

String _metaRow(String label, String value) {
  const labelW = 7;
  final safeLabel = label.length > labelW ? label.substring(0, labelW) : label;
  return '${safeLabel.padRight(labelW)} : $value';
}

String _itemHeader() {
  return ReceiptLayoutSpec.thermalTableHeader();
}

String _formatDateOnly(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';

String _formatTimeOnly(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

double _taxAmount(Map<String, double> taxes, String prefix) {
  for (final entry in taxes.entries) {
    if (entry.key.toUpperCase().startsWith(prefix)) return entry.value;
  }
  return 0;
}

List<_ThermalLine> _buildSlip({
  required String slipTitle,
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
  required String footer,
}) {
  final out = <_ThermalLine>[];

  // ── Top Padding ──────────────────────────────────────────────────────────
  out.add(_ThermalLine.blank);

  // ── Header ───────────────────────────────────────────────────────────────
  final showOrg = orgName.isNotEmpty;

  if (showOrg) {
    out.add(
      _ThermalLine(
        text: orgName,
        size: _kSizeTitle,
        bold: true,
        align: _kAlignCenter,
      ),
    );
  }

  if (slipTitle.isNotEmpty &&
      orgName.toUpperCase() != slipTitle.toUpperCase()) {
    out.add(
      _ThermalLine(
        text: slipTitle,
        size: showOrg ? _kSizeHeader : _kSizeTitle,
        bold: true,
        align: _kAlignCenter,
      ),
    );
  }

  if (unitName != null && unitName.isNotEmpty) {
    out.add(_ThermalLine(text: unitName, align: _kAlignCenter));
  }

  // Combine GSTIN / POS if both exist as per the example
  final gstinStr = (gstin != null && gstin.isNotEmpty) ? 'GSTIN: $gstin' : '';
  final posStr = (posId != null && posId.isNotEmpty) ? 'POS: $posId' : '';
  final combinedGstPos =
      [gstinStr, posStr].where((e) => e.isNotEmpty).join(' / ');
  if (combinedGstPos.isNotEmpty) {
    out.add(_ThermalLine(text: combinedGstPos, align: _kAlignCenter));
  }

  out.add(_ThermalLine.divider);

  // ── Bill meta ────────────────────────────────────────────────────────────
  out
    ..add(_ThermalLine(
        text: _metaRow('Bill No', billNumber), align: _kAlignCenter))
    ..add(_ThermalLine(
        text: 'Date: ${_formatDateOnly(dateTime)}', align: _kAlignCenter))
    ..add(_ThermalLine(
        text: 'Time: ${_formatTimeOnly(dateTime)}', align: _kAlignCenter));

  out.add(_ThermalLine.divider);

  // ── Line items ───────────────────────────────────────────────────────────
  out
    ..add(_ThermalLine(text: ReceiptLayoutSpec.thermalTableBorder))
    ..add(_ThermalLine(text: _itemHeader(), bold: true))
    ..add(_ThermalLine(text: ReceiptLayoutSpec.thermalTableBorder));

  for (final it in items) {
    final priceStr = it.amount.toStringAsFixed(2);
    for (final row in ReceiptLayoutSpec.thermalItemRows(
      qty: it.qty,
      item: it.name,
      price: priceStr,
    )) {
      out.add(_ThermalLine(text: row));
    }
  }

  out.add(_ThermalLine(text: ReceiptLayoutSpec.thermalTableBorder));

  // ── Tax summary table ────────────────────────────────────────────────────
  final cgst = _taxAmount(taxes, 'CGST');
  final sgst = _taxAmount(taxes, 'SGST');
  out
    ..add(_ThermalLine(text: ReceiptLayoutSpec.thermalSummaryBorder))
    ..add(_ThermalLine(
        text: ReceiptLayoutSpec.thermalSummaryRow(
            'Taxable Value:', subtotal.toStringAsFixed(2))))
    ..add(_ThermalLine(
        text: ReceiptLayoutSpec.thermalSummaryRow(
            'CGST:', cgst.toStringAsFixed(2))))
    ..add(_ThermalLine(
        text: ReceiptLayoutSpec.thermalSummaryRow(
            'SGST:', sgst.toStringAsFixed(2))))
    ..add(_ThermalLine(text: ReceiptLayoutSpec.thermalSummaryBorder))
    ..add(_ThermalLine(
      text: ReceiptLayoutSpec.thermalSummaryRow(
          'To pay:', total.toStringAsFixed(2)),
      size: _kSizeTotal,
      bold: true,
    ))
    ..add(_ThermalLine(text: ReceiptLayoutSpec.thermalSummaryBorder));

  // ── Footer ───────────────────────────────────────────────────────────────
  out.add(_ThermalLine(text: footer, align: _kAlignCenter));

  // ── Bottom Padding (for paper tear-off margin) ───────────────────────────
  out
    ..add(_ThermalLine.blank)
    ..add(_ThermalLine.blank);

  return out;
}

Future<void> _sendToPrinter(
  SmartPosPrinterService printer,
  List<_ThermalLine> lines,
) async {
  await printer.printLines(
    lines
        .map(
          (line) => <String, Object?>{
            'text': line.text,
            'size': line.size,
            'isBold': line.bold,
            'align': line.align,
          },
        )
        .toList(),
  );
}

// ─── Public API ─────────────────────────────────────────────────────────────

Future<void> printBillThermalInvoiceAndTicket({
  required SmartPosPrinterService printer,
  required BillConfig config,
  required String billDisplay,
  required String dateStr,
  required CartState cartState,
  required double total,
  required double taxableAmount,
  required double cgstAmount,
  required double sgstAmount,
  required bool hasTax,
  required String paymentMethod,
}) async {
  await printer.initSdk();

  final items = cartState.items.values
      .map((it) => (qty: it.quantity, name: it.product.name, amount: it.total))
      .toList();

  final taxes = <String, double>{};
  if (hasTax) {
    taxes['CGST (${config.cgstPercent.toStringAsFixed(0)}%)'] = cgstAmount;
    taxes['SGST (${config.sgstPercent.toStringAsFixed(0)}%)'] = sgstAmount;
  }

  DateTime parsedDate;
  try {
    final dpart = dateStr.split('  ').first.replaceAll('/', '-');
    parsedDate = DateTime.parse(dpart);
  } catch (_) {
    parsedDate = DateTime.now();
  }

  final footer =
      (config.footerMessage != null && config.footerMessage!.isNotEmpty)
          ? config.footerMessage!
          : 'Thank You. Visit Again';

  final orgName = config.orgName.isNotEmpty ? config.orgName : 'INVOICE';

  await _sendToPrinter(
    printer,
    _buildSlip(
      slipTitle: 'INVOICE',
      orgName: orgName,
      unitName: config.unitName,
      gstin: config.gstNumber,
      posId: config.posId,
      billNumber: billDisplay,
      dateTime: parsedDate,
      items: items,
      subtotal: taxableAmount,
      taxes: taxes,
      total: total,
      footer: footer,
    ),
  );

  await printer.cutPaper();

  // ── TICKET (same layout, no tax breakdown, headed as TICKET) ─────────────
  await _sendToPrinter(
    printer,
    _buildSlip(
      slipTitle: 'TICKET',
      orgName: orgName,
      unitName: config.unitName,
      gstin: null,
      posId: config.posId,
      billNumber: billDisplay,
      dateTime: parsedDate,
      items: items,
      subtotal: taxableAmount,
      taxes: taxes,
      total: total,
      footer: footer,
    ),
  );

  await printer.cutPaper();
}
