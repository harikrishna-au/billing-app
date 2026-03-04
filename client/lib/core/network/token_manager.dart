import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages JWT tokens using Android Keystore via flutter_secure_storage.
///
/// Uses an in-memory cache so that synchronous reads (needed by Dio interceptors)
/// always work, while persistence is handled asynchronously in the background.
class TokenManager {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _tokenExpiryKey = 'token_expiry';

  final FlutterSecureStorage _storage;

  // In-memory cache — populated once at startup via [initialize()].
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  TokenManager(this._storage);

  /// Call once at app startup (before [runApp]) to warm the in-memory cache.
  Future<void> initialize() async {
    _accessToken  = await _storage.read(key: _accessTokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
    if (expiryStr != null) {
      final millis = int.tryParse(expiryStr);
      if (millis != null) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
  }

  // ── Access token ────────────────────────────────────────────────────────────

  Future<void> saveAccessToken(String token) async {
    _accessToken = token;
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Synchronous read from in-memory cache — safe to call in Dio interceptors.
  String? getAccessToken() => _accessToken;

  Future<void> clearAccessToken() async {
    _accessToken = null;
    await _storage.delete(key: _accessTokenKey);
  }

  // ── Refresh token ───────────────────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  String? getRefreshToken() => _refreshToken;

  Future<void> clearRefreshToken() async {
    _refreshToken = null;
    await _storage.delete(key: _refreshTokenKey);
  }

  // ── Token expiry ────────────────────────────────────────────────────────────

  Future<void> saveTokenExpiry(DateTime expiry) async {
    _tokenExpiry = expiry;
    await _storage.write(
      key: _tokenExpiryKey,
      value: expiry.millisecondsSinceEpoch.toString(),
    );
  }

  DateTime? getTokenExpiry() => _tokenExpiry;

  Future<void> clearTokenExpiry() async {
    _tokenExpiry = null;
    await _storage.delete(key: _tokenExpiryKey);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool isTokenExpired() {
    final expiry = _tokenExpiry;
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)));
  }

  bool get isLoggedIn {
    final token = _accessToken;
    return token != null && token.isNotEmpty && !isTokenExpired();
  }

  Future<void> clearAll() async {
    _accessToken  = null;
    _refreshToken = null;
    _tokenExpiry  = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _tokenExpiryKey),
    ]);
  }
}
