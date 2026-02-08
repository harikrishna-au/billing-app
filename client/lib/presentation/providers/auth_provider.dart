import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/models/machine_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/api_auth_repository.dart';
import '../../core/network/providers.dart';
import 'machine_provider.dart';

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

      // Auto-select machine if logged in as machine
      await _autoSelectMachine();
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

      // Auto-select machine after successful login
      await _autoSelectMachine();
    } catch (e) {
      print('Login error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _autoSelectMachine() async {
    try {
      final tokenManager = ref.read(tokenManagerProvider);

      // 1. Try to get full machine data from storage first (fastest, works offline)
      final machineJson = tokenManager.getMachineData();
      if (machineJson != null) {
        try {
          // needing dart:convert
          final machineMap = jsonDecode(machineJson);
          final machine = Machine.fromJson(machineMap);
          ref.read(machineProvider.notifier).selectMachine(machine);
          print('Machine auto-selected from storage: ${machine.name}');
          return;
        } catch (e) {
          print('Error parsing stored machine data: $e');
          // Start fresh if data is corrupted
          await tokenManager.clearMachineId(); // or just clear data?
        }
      }

      // 2. Fallback: Fetch by ID if data not found but ID exists
      final machineId = tokenManager.getMachineId();

      if (machineId != null) {
        print('Auto-selecting machine by ID: $machineId');

        try {
          // Fetch full machine details from backend
          final machine =
              await ref.read(machineRepositoryProvider).getMachineById(machineId);

          // Select the machine in machineProvider
          ref.read(machineProvider.notifier).selectMachine(machine);

          print('Machine auto-selected via API: ${machine.name}');

          // Update stored data
          await tokenManager.saveMachineData(jsonEncode(machine.toJson()));
        } catch (e) {
          print('Failed to fetch machine by ID: $e');
          // Clear invalid machine ID
          await tokenManager.clearMachineId();
        }
      }
    } catch (e) {
      print('Error auto-selecting machine: $e');
      // Don't fail the login if machine selection fails
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
