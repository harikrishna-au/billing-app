import 'package:shared_preferences/shared_preferences.dart';

/// Date-based bill number generator backed by SharedPreferences.
/// Format: BILL-DDMMYYNNN  (e.g., BILL-130326001 for the 1st bill on 13 Mar 2026)
/// The 3-digit counter resets to 1 at the start of each new calendar day.
///
/// Use via [billNumberServiceProvider] — do NOT call [SharedPreferences.getInstance]
/// directly so it always operates on the same instance as the app.
class BillNumberGenerator {
  static const String _counterKey    = 'bill_number_counter';
  static const String _dateKey       = 'bill_number_date'; // stored as DDMMYY

  final SharedPreferences _prefs;

  BillNumberGenerator(this._prefs);

  /// Returns DDMMYY string for [date].
  String _dateStamp(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yy = (date.year % 100).toString().padLeft(2, '0');
    return '$dd$mm$yy';
  }

  /// Current counter value (does not increment).
  int get currentCounter => _prefs.getInt(_counterKey) ?? 0;

  /// Increment the counter, reset if the day changed, and return the next bill number.
  Future<String> generate() async {
    final today    = _dateStamp(DateTime.now());
    final lastDate = _prefs.getString(_dateKey) ?? '';

    final next = (lastDate == today) ? currentCounter + 1 : 1;

    await _prefs.setInt(_counterKey, next);
    await _prefs.setString(_dateKey, today);

    return 'BILL-$today${next.toString().padLeft(3, '0')}';
  }

  /// Force-set the counter (used when syncing with backend).
  Future<void> setCounter(int value) async {
    await _prefs.setInt(_counterKey, value);
  }

  /// After coming back online, keep whichever counter is higher to prevent
  /// reusing a number that was already issued locally while offline.
  Future<void> syncWithBackend(int backendCounter) async {
    final max = currentCounter > backendCounter ? currentCounter : backendCounter;
    await setCounter(max);
  }
}
