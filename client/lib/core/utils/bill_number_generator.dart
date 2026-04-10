import 'package:shared_preferences/shared_preferences.dart';

/// Continuous bill number generator backed by SharedPreferences.
/// Format: POSID/000001 (or BILL/000001 when POS ID is unavailable).
/// The counter never resets automatically, so bill numbers continue across days.
///
/// Use via [billNumberServiceProvider] — do NOT call [SharedPreferences.getInstance]
/// directly so it always operates on the same instance as the app.
class BillNumberGenerator {
  static const String _counterKey = 'bill_number_counter';

  final SharedPreferences _prefs;

  BillNumberGenerator(this._prefs);

  /// Current counter value (does not increment).
  int get currentCounter => _prefs.getInt(_counterKey) ?? 0;

  /// Increment the counter and return the next bill number.
  Future<String> generate({String? posId}) async {
    final next = currentCounter + 1;
    await _prefs.setInt(_counterKey, next);

    final normalizedPosId = (posId ?? '').trim();
    final prefix = normalizedPosId.isEmpty ? 'BILL' : normalizedPosId;
    return '$prefix/${next.toString().padLeft(6, '0')}';
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
