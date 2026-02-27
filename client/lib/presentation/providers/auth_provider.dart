import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/api_auth_repository.dart';
import '../../core/network/providers.dart';
import 'bill_config_provider.dart';

// Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenManager = ref.watch(tokenManagerProvider);
  return ApiAuthRepository(apiClient, tokenManager);
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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    print('Attempting login for: $email');
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = await authRepo.login(email, password);
      print('Login successful: ${user.username}');
      state = state.copyWith(user: user, isLoading: false);
      ref.read(billConfigProvider.notifier).refresh(user.id);
    } catch (e) {
      print('Login error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
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
