import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _displayDate = DateFormat('dd MMM yyyy');
  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  /// Formats date to '24 Oct 2024'
  static String format(DateTime date) {
    return _displayDate.format(date);
  }

  /// Formats date to ISO '2024-10-24'
  static String formatISO(DateTime date) {
    return _isoDate.format(date);
  }
}
