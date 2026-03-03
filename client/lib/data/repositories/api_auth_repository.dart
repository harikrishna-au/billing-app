import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/token_manager.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/bill_number_generator.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  final ApiClient _apiClient;
  final TokenManager _tokenManager;
  final BillNumberGenerator _billNumberGenerator;

  ApiAuthRepository(this._apiClient, this._tokenManager, this._billNumberGenerator);

  @override
  Future<User> login(String username, String password) async {
    try {
      // Regular user login
      final response = await _apiClient.post(
        ApiConstants.login,
        data: {
          'username': username,
          'password': password,
        },
      );

      return await _handleAuthResponse(response.data, isMachine: false);
    } catch (e) {
      rethrow;
    }
  }

  Future<User> _handleAuthResponse(Map<String, dynamic> data,
      {bool isMachine = false}) async {
    if (data['success'] == true && data['data'] != null) {
      final authData = data['data'];
      final token = authData['token'] as String;
      final refreshToken = authData['refresh_token'] as String;

      // Save tokens
      await _tokenManager.saveAccessToken(token);
      await _tokenManager.saveRefreshToken(refreshToken);

      // Save token expiry so the session persists across app restarts
      final expiresIn = authData['expires_in'] as int? ?? 3600;
      await _tokenManager.saveTokenExpiry(
        DateTime.now().add(Duration(seconds: expiresIn)),
      );

      // Parse User from response - machine login returns 'machine', user login returns 'user'
      final userOrMachineData = authData['machine'] ?? authData['user'];
      if (userOrMachineData == null) {
        throw ApiException(message: 'No user or machine data in response');
      }

      // Sync bill counter from backend so the local sequence never goes backwards.
      final backendCounter = userOrMachineData['bill_counter'];
      if (backendCounter is int && backendCounter > 0) {
        await _billNumberGenerator.syncWithBackend(backendCounter);
      }

      return User.fromJson(userOrMachineData);
    } else {
      throw ApiException(message: 'Invalid response format');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _apiClient.post(ApiConstants.logout);
    } catch (e) {
      // Ignore logout errors
    } finally {
      await _tokenManager.clearAll();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    if (!_tokenManager.isLoggedIn) return null;

    try {
      final response = await _apiClient.get(ApiConstants.me);

      if (response.data['success'] == true) {
        return User.fromJson(response.data['data']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
