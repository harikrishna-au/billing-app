import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which bill numbers have already been printed.
/// Stored in SharedPreferences so the guard survives app restarts.
class PrintedBillsTracker {
  static const String _key = 'printed_bill_numbers';

  final SharedPreferences _prefs;

  PrintedBillsTracker(this._prefs);

  /// Returns the set of already-printed bill numbers.
  Set<String> get _printed {
    final list = _prefs.getStringList(_key) ?? [];
    return list.toSet();
  }

  /// Returns true if this bill number has already been printed.
  bool hasBeenPrinted(String billNumber) => _printed.contains(billNumber);

  /// Marks the given bill number as printed. Call this AFTER a successful print.
  Future<void> markAsPrinted(String billNumber) async {
    final current = _printed;
    current.add(billNumber);
    await _prefs.setStringList(_key, current.toList());
  }

  /// Clears the entire print history (can be used by admin reset).
  Future<void> clearAll() async {
    await _prefs.remove(_key);
  }
}
