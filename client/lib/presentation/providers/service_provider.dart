import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/service_model.dart';
import '../../data/repositories/service_repository.dart';
import '../../data/repositories/api_service_repository.dart';
import '../../core/network/providers.dart';
import 'machine_provider.dart';

// Repository Provider
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiServiceRepository(apiClient);
});

// State
class ServiceState {
  final List<Service> services;
  final List<Service> filteredServices;
  final bool isLoading;
  final String? error;

  ServiceState({
    this.services = const [],
    this.filteredServices = const [],
    this.isLoading = false,
    this.error,
  });

  ServiceState copyWith({
    List<Service>? services,
    List<Service>? filteredServices,
    bool? isLoading,
    String? error,
  }) {
    return ServiceState(
      services: services ?? this.services,
      filteredServices: filteredServices ?? this.filteredServices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Controller
class ServiceController extends StateNotifier<ServiceState> {
  final Ref ref;

  ServiceController(this.ref) : super(ServiceState()) {
    // Listen to machine changes and reload services
    ref.listen(machineProvider, (previous, next) {
      if (next.selectedMachine != null) {
        loadServicesForMachine(next.selectedMachine!.id);
      }
    });
  }

  Future<void> loadAllServices() async {
    state = state.copyWith(isLoading: true);
    try {
      final services = await ref.read(serviceRepositoryProvider).getServices();
      state = state.copyWith(
        services: services,
        filteredServices: services,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadServicesForMachine(String machineId) async {
    print('Loading services for machine: $machineId');
    state = state.copyWith(isLoading: true);
    try {
      final services = await ref
          .read(serviceRepositoryProvider)
          .getServicesByMachine(machineId);
      print('Loaded ${services.length} services');
      state = state.copyWith(
        services: services,
        filteredServices: services,
        isLoading: false,
      );
    } catch (e, stack) {
      print('Error loading services: $e');
      print(stack);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadActiveServicesForMachine(String machineId) async {
    state = state.copyWith(isLoading: true);
    try {
      final services = await ref
          .read(serviceRepositoryProvider)
          .getActiveServicesByMachine(machineId);
      state = state.copyWith(
        services: services,
        filteredServices: services,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> toggleServiceStatus(String id) async {
    try {
      final service = state.services.firstWhere((s) => s.id == id);
      final newStatus = service.status == ServiceStatus.active
          ? ServiceStatus.inactive
          : ServiceStatus.active;

      await ref
          .read(serviceRepositoryProvider)
          .updateServiceStatus(id, newStatus);

      // Reload services for current machine
      await _refreshServices();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> createService(Service service) async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(serviceRepositoryProvider).createService(service);
      await _refreshServices();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateService(Service service) async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(serviceRepositoryProvider).updateService(service);
      await _refreshServices();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteService(String id) async {
    state = state.copyWith(isLoading: true);
    try {
      await ref.read(serviceRepositoryProvider).deleteService(id);
      await _refreshServices();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> _refreshServices() async {
    final selectedMachine = ref.read(machineProvider).selectedMachine;
    if (selectedMachine != null) {
      await loadServicesForMachine(selectedMachine.id);
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  void filterServices(String query) {
    if (query.isEmpty) {
      state = state.copyWith(filteredServices: state.services);
    } else {
      final filtered = state.services
          .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      state = state.copyWith(filteredServices: filtered);
    }
  }
}

// Provider
final serviceProvider =
    StateNotifierProvider<ServiceController, ServiceState>((ref) {
  return ServiceController(ref);
});
