import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/api_auth_repository.dart';
import '../../core/network/providers.dart';
import 'bill_config_provider.dart';

/// Dio wraps our [ApiException] in [DioException.error] — surface the inner message for UI/logs.
String _unwrapAuthError(Object e) {
  if (e is DioException && e.error is ApiException) {
    return (e.error as ApiException).message;
  }
  if (e is ApiException) return e.message;
  return e.toString();
}

// Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenManager = ref.watch(tokenManagerProvider);
  final billGenerator = ref.watch(billNumberServiceProvider);
  return ApiAuthRepository(apiClient, tokenManager, billGenerator);
});

// State
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error, // Nullable reset
    );
  }
}

// Controller
class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(AuthState()) {
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      state = state.copyWith(user: user, isLoading: false);
      if (user != null) {
        ref.read(billConfigProvider.notifier).refresh(user.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _unwrapAuthError(e));
    }
  }

  Future<void> login(String email, String password) async {
    if (kDebugMode) {
      debugPrint('Login attempt (username only): $email');
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.login(email, password);
      if (kDebugMode) {
        debugPrint('Login successful: ${user.username}');
      }
      state = state.copyWith(user: user, isLoading: false);
      ref.read(billConfigProvider.notifier).refresh(user.id);
    } catch (e) {
      final msg = _unwrapAuthError(e);
      if (kDebugMode) {
        debugPrint('Login error: $msg');
      }
      state = state.copyWith(isLoading: false, error: msg);
    }
  }



  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await ref.read(authRepositoryProvider).logout();
    state = AuthState(); // Reset
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
