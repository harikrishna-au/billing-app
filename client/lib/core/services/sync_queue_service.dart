import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists payments that failed to upload due to network errors.
/// Uses SharedPreferences so data survives app restarts.
///
/// All mutating operations are serialized through [_pending] to prevent
/// read-modify-write races when enqueue and clear are called concurrently.
class SyncQueueService {
  static const _key = 'pending_sync_payments';

  final SharedPreferences _prefs;

  /// Sequential lock: each mutating op chains onto this future so concurrent
  /// calls never interleave their read-modify-write steps.
  Future<void> _pending = Future.value();

  SyncQueueService(this._prefs);

  /// Add a payment to the pending queue.
  Future<void> enqueue(Map<String, dynamic> paymentData) {
    return _pending = _pending.then((_) async {
      final existing = _prefs.getStringList(_key) ?? [];
      existing.add(jsonEncode(paymentData));
      await _prefs.setStringList(_key, existing);
    });
  }

  /// Return all pending payments.
  Future<List<Map<String, dynamic>>> getPending() async {
    final raw = _prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
  }

  /// Remove a specific payment from the queue by bill number.
  Future<void> removeByBillNumber(String billNumber) {
    return _pending = _pending.then((_) async {
      final raw = _prefs.getStringList(_key) ?? [];
      final updated = raw.where((s) {
        final data = jsonDecode(s) as Map<String, dynamic>;
        return data['bill_number'] != billNumber;
      }).toList();
      await _prefs.setStringList(_key, updated);
    });
  }

  /// Clear all pending payments (call after a successful bulk sync).
  Future<void> clear() {
    return _pending = _pending.then((_) async {
      await _prefs.remove(_key);
    });
  }

  /// Number of payments waiting to be synced.
  Future<int> get pendingCount async {
    return (_prefs.getStringList(_key) ?? []).length;
  }
}
