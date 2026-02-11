import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/token_manager.dart';
import '../../core/network/api_exception.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  final ApiClient _apiClient;
  final TokenManager _tokenManager;

  ApiAuthRepository(this._apiClient, this._tokenManager);

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

      // Parse User from response - machine login returns 'machine', user login returns 'user'
      final userOrMachineData = authData['machine'] ?? authData['user'];
      if (userOrMachineData == null) {
        throw ApiException(message: 'No user or machine data in response');
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
