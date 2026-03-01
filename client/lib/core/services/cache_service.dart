import 'package:shared_preferences/shared_preferences.dart';

/// A lightweight TTL-aware cache backed by SharedPreferences.
///
/// All values are stored as raw strings (typically JSON).
/// Each entry gets a companion timestamp key so staleness can be checked.
///
/// Keys are namespaced internally — callers use simple logical names
/// like `'products'` or `'payments'`.
class CacheService {
  static const _val = 'cache_val_';
  static const _ts = 'cache_ts_';

  final SharedPreferences _prefs;

  CacheService(this._prefs);

  /// Store [value] under [key] and record the current timestamp.
  Future<void> set(String key, String value) async {
    await _prefs.setString('$_val$key', value);
    await _prefs.setInt('$_ts$key', DateTime.now().millisecondsSinceEpoch);
  }

  /// Return the cached string for [key], or `null` if not present.
  String? get(String key) => _prefs.getString('$_val$key');

  /// Whether the cached value for [key] is older than [ttl]
  /// (or has never been cached).
  bool isStale(String key, Duration ttl) {
    final ms = _prefs.getInt('$_ts$key');
    if (ms == null) return true;
    return DateTime.now().millisecondsSinceEpoch - ms > ttl.inMilliseconds;
  }

  /// Whether any value exists for [key] (regardless of staleness).
  bool has(String key) => _prefs.containsKey('$_val$key');

  /// Delete the cached value and its timestamp for [key].
  Future<void> remove(String key) async {
    await _prefs.remove('$_val$key');
    await _prefs.remove('$_ts$key');
  }
}
