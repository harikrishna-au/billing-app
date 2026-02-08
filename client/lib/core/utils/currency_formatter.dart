import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _indianRupeeFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _compactIndianFormat = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats amount to Indian Rupee (e.g. ₹1,23,456.78)
  static String format(double amount) {
    // Ensure the symbol is always ₹
    final formatted = _indianRupeeFormat.format(amount);
    // Replace any $ symbol with ₹ as a safety measure
    return formatted.replaceAll('\$', '₹');
  }

  /// Compact format for charts or brief views (e.g. ₹1.2L)
  static String formatCompact(double amount) {
    return _compactIndianFormat.format(amount);
  }

  /// Parse string back to double
  static double parse(String formatted) {
    return _indianRupeeFormat.parse(formatted).toDouble();
  }
}
