import '../models/machine_model.dart';

abstract class MachineRepository {
  Future<List<Machine>> getMachines();
  Future<Machine> getMachineById(String id);
  Future<void> updateMachineStatus(String id, MachineStatus status);
}
