import 'package:shared_preferences/shared_preferences.dart';

/// Sequential bill number generator backed by SharedPreferences.
/// Format: BILL-XXXX (e.g., BILL-0001, BILL-0002, …)
///
/// Use via [billNumberServiceProvider] — do NOT call [SharedPreferences.getInstance]
/// directly so it always operates on the same instance as the app.
class BillNumberGenerator {
  static const String _counterKey = 'bill_number_counter';

  final SharedPreferences _prefs;

  BillNumberGenerator(this._prefs);

  /// Current counter value (does not increment).
  int get currentCounter => _prefs.getInt(_counterKey) ?? 0;

  /// Increment the counter, persist it, and return the next bill number.
  Future<String> generate() async {
    final next = currentCounter + 1;
    await _prefs.setInt(_counterKey, next);
    return 'BILL-${next.toString().padLeft(4, '0')}';
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
