import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _machineIdKey = 'machine_id';

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

  // Machine ID (for machine login)
  Future<void> saveMachineId(String machineId) async {
    await _prefs.setString(_machineIdKey, machineId);
  }

  String? getMachineId() {
    return _prefs.getString(_machineIdKey);
  }

  Future<void> saveMachineData(String jsonString) async {
    await _prefs.setString('machine_data', jsonString);
  }

  String? getMachineData() {
    return _prefs.getString('machine_data');
  }

  Future<void> clearMachineId() async {
    await _prefs.remove(_machineIdKey);
    await _prefs.remove('machine_data');
  }

  // Clear all tokens
  Future<void> clearAll() async {
    await Future.wait([
      clearAccessToken(),
      clearRefreshToken(),
      clearTokenExpiry(),
      clearMachineId(),
    ]);
  }

  // Check if user is logged in
  bool get isLoggedIn {
    final token = getAccessToken();
    return token != null && token.isNotEmpty && !isTokenExpired();
  }
}
