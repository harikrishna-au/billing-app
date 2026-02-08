import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/service_model.dart';
import 'service_repository.dart';

class ApiServiceRepository implements ServiceRepository {
  final ApiClient _apiClient;

  ApiServiceRepository(this._apiClient);

  @override
  Future<List<Service>> getServices() async {
    try {
      final response = await _apiClient.get(ApiConstants.services);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        // Handle both array and object with services key
        final List<dynamic> servicesJson =
            data is List ? data : (data['services'] as List? ?? []);
        return servicesJson.map((json) => Service.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Service>> getServicesByMachine(String machineId) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.machineServices(machineId),
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        // Handle both array and object with services key
        final List<dynamic> servicesJson =
            data is List ? data : (data['services'] as List? ?? []);

        final List<Service> services = [];
        for (var json in servicesJson) {
          try {
            services.add(Service.fromJson(json));
          } catch (e) {
            print('Error parsing service item: $e');
            // Skip invalid items
          }
        }
        return services;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Service>> getActiveServicesByMachine(String machineId) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.machineServicesActive(machineId),
      );

      if (response.data['success'] == true) {
        final data = response.data['data'];
        // Handle both array and object with services key
        final List<dynamic> servicesJson =
            data is List ? data : (data['services'] as List? ?? []);
        return servicesJson.map((json) => Service.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Service> getServiceById(String id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.serviceById(id),
      );

      if (response.data['success'] == true) {
        return Service.fromJson(response.data['data']);
      }
      throw Exception('Service not found');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> createService(Service service) async {
    try {
      await _apiClient.post(
        ApiConstants.machineServices(service.machineId),
        data: {
          'name': service.name,
          'price': service.price,
          'status':
              service.status == ServiceStatus.active ? 'active' : 'inactive',
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateService(Service service) async {
    try {
      await _apiClient.put(
        ApiConstants.serviceById(service.id),
        data: {
          'name': service.name,
          'price': service.price,
          'status':
              service.status == ServiceStatus.active ? 'active' : 'inactive',
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateServiceStatus(String id, ServiceStatus status) async {
    try {
      await _apiClient.put(
        ApiConstants.serviceById(id),
        data: {
          'status': status == ServiceStatus.active ? 'active' : 'inactive',
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteService(String id) async {
    try {
      await _apiClient.delete(ApiConstants.serviceById(id));
    } catch (e) {
      rethrow;
    }
  }
}
