import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  final SharedPreferences _prefs;

  TokenManager(this._prefs);

  // Access Token
  Future<void> saveAccessToken(String token) async {
    await _prefs.setString(_accessTokenKey, token);
  }

  String? getAccessToken() {
    return _prefs.getString(_accessTokenKey);
  }

  Future<void> clearAccessToken() async {
    await _prefs.remove(_accessTokenKey);
  }

  // Refresh Token
  Future<void> saveRefreshToken(String token) async {
    await _prefs.setString(_refreshTokenKey, token);
  }

  String? getRefreshToken() {
    return _prefs.getString(_refreshTokenKey);
  }

  Future<void> clearRefreshToken() async {
    await _prefs.remove(_refreshTokenKey);
  }

  // Token Expiry
  Future<void> saveTokenExpiry(DateTime expiry) async {
    await _prefs.setInt(_tokenExpiryKey, expiry.millisecondsSinceEpoch);
  }

  DateTime? getTokenExpiry() {
    final millis = _prefs.getInt(_tokenExpiryKey);
    return millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
  }

  Future<void> clearTokenExpiry() async {
    await _prefs.remove(_tokenExpiryKey);
  }

  // Check if token is expired
  bool isTokenExpired() {
    final expiry = getTokenExpiry();
    if (expiry == null) return true;

    // Consider expired if within 5 minutes of expiry
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)));
  }

  // Clear all tokens
  Future<void> clearAll() async {
    await Future.wait([
      clearAccessToken(),
      clearRefreshToken(),
      clearTokenExpiry(),
    ]);
  }

  // Check if user is logged in
  bool get isLoggedIn {
    final token = getAccessToken();
    return token != null && token.isNotEmpty && !isTokenExpired();
  }
}
