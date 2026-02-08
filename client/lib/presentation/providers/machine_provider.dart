import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/machine_model.dart';
import '../../data/repositories/machine_repository.dart';
import '../../data/repositories/api_machine_repository.dart';
import '../../core/network/providers.dart';

// Repository Provider
final machineRepositoryProvider = Provider<MachineRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiMachineRepository(apiClient);
});

// State
class MachineState {
  final List<Machine> machines;
  final Machine? selectedMachine;
  final bool isLoading;
  final String? error;

  MachineState({
    this.machines = const [],
    this.selectedMachine,
    this.isLoading = false,
    this.error,
  });

  MachineState copyWith({
    List<Machine>? machines,
    Machine? selectedMachine,
    bool? isLoading,
    String? error,
  }) {
    return MachineState(
      machines: machines ?? this.machines,
      selectedMachine: selectedMachine ?? this.selectedMachine,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Controller
class MachineController extends StateNotifier<MachineState> {
  final Ref ref;

  MachineController(this.ref) : super(MachineState()) {
    // Don't auto-load machines
    // Machine will be auto-selected from login response
  }

  Future<void> loadMachines() async {
    state = state.copyWith(isLoading: true);
    try {
      final machines = await ref.read(machineRepositoryProvider).getMachines();
      state = state.copyWith(
        machines: machines,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void selectMachine(Machine machine) {
    state = state.copyWith(selectedMachine: machine);
  }

  Future<void> updateMachineStatus(String id, MachineStatus status) async {
    try {
      await ref.read(machineRepositoryProvider).updateMachineStatus(id, status);
      await loadMachines(); // Reload to get updated data
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Provider
final machineProvider =
    StateNotifierProvider<MachineController, MachineState>((ref) {
  return MachineController(ref);
});
