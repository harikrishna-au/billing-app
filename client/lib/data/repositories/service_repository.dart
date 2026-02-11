import '../models/service_model.dart';

abstract class ServiceRepository {
  Future<List<Service>> getServices();
  Future<Service> getServiceById(String id);
  Future<void> updateServiceStatus(String id, ServiceStatus status);
  Future<void> createService(Service service);
  Future<void> updateService(Service service);
  Future<void> deleteService(String id);
}
