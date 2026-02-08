import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/machine_model.dart';
import 'machine_repository.dart';

class ApiMachineRepository implements MachineRepository {
  final ApiClient _apiClient;

  ApiMachineRepository(this._apiClient);

  @override
  Future<List<Machine>> getMachines() async {
    try {
      final response = await _apiClient.get(ApiConstants.machines);

      if (response.data['success'] == true) {
        final data = response.data['data'];
        // Handle both array and object with machines key
        final List<dynamic> machinesJson = data is List 
            ? data 
            : (data['machines'] as List? ?? []);
        return machinesJson.map((json) => Machine.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Machine> getMachineById(String id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.machineById(id),
      );

      if (response.data['success'] == true) {
        return Machine.fromJson(response.data['data']);
      }
      throw Exception('Machine not found');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateMachineStatus(String id, MachineStatus status) async {
    try {
      await _apiClient.put(
        ApiConstants.machineById(id),
        data: {
          'status': status == MachineStatus.online
              ? 'online'
              : status == MachineStatus.offline
                  ? 'offline'
                  : 'maintenance',
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}
