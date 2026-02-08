import 'dart:convert';
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
      // Machine login only
      final response = await _apiClient.post(
        ApiConstants.machineLogin,
        data: {
          'username': username,
          'password': password,
        },
      );

      return await _handleAuthResponse(response.data, isMachine: true);
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

      // Parse User
      if (isMachine) {
        final machineData = authData['machine'];

        // Save machine_id for persistent storage
        await _tokenManager.saveMachineId(machineData['id']);

        // Save full machine data to avoid extra API call
        try {
          // imports need dart:convert
          await _tokenManager.saveMachineData(jsonEncode(machineData));
        } catch (e) {
          print('Failed to save machine data: $e');
        }

        // Map machine data to User model
        // Machine doesn't have email, so we leave it null or set a placeholder
        return User(
          id: machineData['id'],
          username: machineData['username'],
          email: null, // Machine has no email
          isActive: machineData['status'] == 'online' ? 'true' : 'false',
          createdAt: DateTime.tryParse(machineData['last_sync'] ?? ''),
        );
      } else {
        return User.fromJson(authData['user']);
      }
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
