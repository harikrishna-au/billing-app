import 'package:shared_preferences/shared_preferences.dart';

/// Continuous bill number generator backed by SharedPreferences.
/// Format: POSID/1 (or BILL/1 when POS ID is unavailable) — numeric part has no leading zeros.
/// The counter never resets automatically, so bill numbers continue across days.
///
/// Use via [billNumberServiceProvider] — do NOT call [SharedPreferences.getInstance]
/// directly so it always operates on the same instance as the app.
class BillNumberGenerator {
  static const String _counterKey = 'bill_number_counter';

  final SharedPreferences _prefs;

  BillNumberGenerator(this._prefs);

  /// Strips redundant leading zeros from the numeric suffix (e.g. `WSSBI-AP/000027` → `WSSBI-AP/27`).
  static String displayTicketNumber(String billNumber) {
    final i = billNumber.lastIndexOf('/');
    if (i <= 0 || i >= billNumber.length - 1) return billNumber;
    final prefix = billNumber.substring(0, i);
    final suffix = billNumber.substring(i + 1);
    final n = int.tryParse(suffix);
    if (n == null) return billNumber;
    return '$prefix/$n';
  }

  /// Current counter value (does not increment).
  int get currentCounter => _prefs.getInt(_counterKey) ?? 0;

  /// Generate the next bill number WITHOUT incrementing the counter.
  /// Use this when generating a bill number for preview/confirmation.
  /// Call [confirmBillNumber] only after payment is successfully processed.
  String generatePreview({String? posId}) {
    final next = currentCounter + 1;
    final normalizedPosId = (posId ?? '').trim();
    final prefix = normalizedPosId.isEmpty ? 'BILL' : normalizedPosId;
    return '$prefix/$next';
  }

  /// Confirm and increment the bill number counter.
  /// Call this ONLY after successful payment creation to lock in the bill number.
  Future<String> confirmBillNumber({String? posId}) async {
    final next = currentCounter + 1;
    await _prefs.setInt(_counterKey, next);

    final normalizedPosId = (posId ?? '').trim();
    final prefix = normalizedPosId.isEmpty ? 'BILL' : normalizedPosId;
    return '$prefix/$next';
  }

  /// Legacy method - for backward compatibility, increments immediately.
  /// Deprecated: Use [generatePreview] + [confirmBillNumber] instead.
  @deprecated
  Future<String> generate({String? posId}) async {
    return confirmBillNumber(posId: posId);
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
