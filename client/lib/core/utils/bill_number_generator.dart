/// Utility class for generating unique bill numbers
class BillNumberGenerator {
  static int _counter = 0;
  static DateTime? _lastDate;

  /// Generate a unique bill number in format: BILL-YYYYMMDD-XXXX
  /// Example: BILL-20260204-0001
  static String generate() {
    final now = DateTime.now();
    final dateStr = '${now.year}${_pad(now.month)}${_pad(now.day)}';

    // Reset counter if it's a new day
    if (_lastDate == null || !_isSameDay(_lastDate!, now)) {
      _counter = 0;
      _lastDate = now;
    }

    _counter++;
    final counterStr = _counter.toString().padLeft(4, '0');

    return 'BILL-$dateStr-$counterStr';
  }

  /// Generate bill number with machine prefix
  /// Example: M001-20260204-0001
  static String generateForMachine(String machineId) {
    final now = DateTime.now();
    final dateStr = '${now.year}${_pad(now.month)}${_pad(now.day)}';

    // Reset counter if it's a new day
    if (_lastDate == null || !_isSameDay(_lastDate!, now)) {
      _counter = 0;
      _lastDate = now;
    }

    _counter++;
    final counterStr = _counter.toString().padLeft(4, '0');

    // Extract machine number from ID (e.g., mach_001 -> M001)
    final machineNum = machineId.replaceAll('mach_', 'M');

    return '$machineNum-$dateStr-$counterStr';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Reset counter (useful for testing)
  static void reset() {
    _counter = 0;
    _lastDate = null;
  }
}
