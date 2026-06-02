class ReceiptLayoutSpec {
  static const int thermalQtyWidth = 4;
  static const int thermalItemWidth = 24;
  static const int thermalPriceWidth = 10;
  static const int thermalLineWidth =
      thermalQtyWidth + thermalItemWidth + thermalPriceWidth + 4;
  static const int thermalSummaryLabelWidth = 27;
  static const int thermalSummaryValueWidth = 12;
  static final String thermalDivider = '-' * thermalLineWidth;
  static final String thermalTableBorder =
      '+${'-' * thermalQtyWidth}+${'-' * thermalItemWidth}+${'-' * thermalPriceWidth}+';
  static final String thermalSummaryBorder =
      '+${'-' * thermalSummaryLabelWidth}+${'-' * thermalSummaryValueWidth}+';

  static const double screenQtyWidth = 52;
  static const double screenPriceWidth = 112;
  static const double screenSummaryLabelWidth = 112;
  static const double screenSummaryValueWidth = 112;

  static String thermalTableHeader() {
    return thermalTableRow(qty: 'QTY', item: 'ITEM NAME', price: 'PRICE');
  }

  static List<String> thermalItemRows({
    required int qty,
    required String item,
    required String price,
  }) {
    final rows = <String>[];
    final chunks = _chunks(item, thermalItemWidth);

    for (var i = 0; i < chunks.length; i += 1) {
      rows.add(
        thermalTableRow(
          qty: i == 0 ? '$qty' : '',
          item: chunks[i],
          price: i == 0 ? price : '',
        ),
      );
    }

    return rows;
  }

  static String thermalTableRow({
    required String qty,
    required String item,
    required String price,
  }) {
    final safeQty = _left(qty, thermalQtyWidth);
    final safeItem = _left(item, thermalItemWidth);
    final safePrice = _right(price, thermalPriceWidth);

    return '|$safeQty|$safeItem|$safePrice|';
  }

  static String thermalSummaryRow(String label, String value) {
    return '|${_right(label, thermalSummaryLabelWidth)}'
        '|${_right(value, thermalSummaryValueWidth)}|';
  }

  static List<String> _chunks(String value, int width) {
    if (value.isEmpty) return [''];

    final chunks = <String>[];
    var remaining = value;

    while (remaining.isNotEmpty) {
      final end = remaining.length > width ? width : remaining.length;
      chunks.add(remaining.substring(0, end));
      remaining = remaining.substring(end);
    }

    return chunks;
  }

  static String _left(String value, int width) {
    final safe = value.length > width ? value.substring(0, width) : value;
    return safe.padRight(width);
  }

  static String _right(String value, int width) {
    final safe =
        value.length > width ? value.substring(value.length - width) : value;
    return safe.padLeft(width);
  }
}
