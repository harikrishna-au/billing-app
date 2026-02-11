import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for generating sequential bill numbers
/// Format: BILL-XXXX (e.g., BILL-0001, BILL-0002, etc.)
class BillNumberGenerator {
  static const String _counterKey = 'bill_number_counter';
  static int? _cachedCounter;

  /// Get the next bill number and increment the counter
  static Future<String> generate() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current counter (default to 0 if not set)
    int counter = _cachedCounter ?? prefs.getInt(_counterKey) ?? 0;
    
    // Increment counter
    counter++;
    
    // Save to SharedPreferences
    await prefs.setInt(_counterKey, counter);
    _cachedCounter = counter;
    
    // Format as BILL-XXXX (4 digits with leading zeros)
    final counterStr = counter.toString().padLeft(4, '0');
    return 'BILL-$counterStr';
  }

  /// Set the counter to a specific value (used when syncing with backend)
  static Future<void> setCounter(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_counterKey, value);
    _cachedCounter = value;
  }

  /// Get the current counter value without incrementing
  static Future<int> getCurrentCounter() async {
    if (_cachedCounter != null) return _cachedCounter!;
    
    final prefs = await SharedPreferences.getInstance();
    final counter = prefs.getInt(_counterKey) ?? 0;
    _cachedCounter = counter;
    return counter;
  }

  /// Sync with backend to get the latest bill number
  /// This should be called when the app goes online
  static Future<void> syncWithBackend(int backendCounter) async {
    final localCounter = await getCurrentCounter();
    
    // Use the higher value to avoid duplicates
    final maxCounter = localCounter > backendCounter ? localCounter : backendCounter;
    await setCounter(maxCounter);
  }

  /// Reset counter (useful for testing or manual reset)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_counterKey);
    _cachedCounter = null;
  }
}
