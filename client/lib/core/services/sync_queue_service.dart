import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists payments that failed to upload due to network errors.
/// Uses SharedPreferences so data survives app restarts.
class SyncQueueService {
  static const _key = 'pending_sync_payments';

  /// Add a payment to the pending queue.
  Future<void> enqueue(Map<String, dynamic> paymentData) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_key) ?? [];
    existing.add(jsonEncode(paymentData));
    await prefs.setStringList(_key, existing);
  }

  /// Return all pending payments.
  Future<List<Map<String, dynamic>>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => jsonDecode(s) as Map<String, dynamic>)
        .toList();
  }

  /// Remove a specific payment from the queue by bill number.
  Future<void> removeByBillNumber(String billNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.where((s) {
      final data = jsonDecode(s) as Map<String, dynamic>;
      return data['bill_number'] != billNumber;
    }).toList();
    await prefs.setStringList(_key, updated);
  }

  /// Clear all pending payments (call after a successful bulk sync).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Number of payments waiting to be synced.
  Future<int> get pendingCount async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).length;
  }
}
