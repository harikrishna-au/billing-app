import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/product_model.dart';
import 'catalogue_repository.dart';

class ApiCatalogueRepository implements CatalogueRepository {
  final ApiClient _apiClient;
  final String? machineId;

  ApiCatalogueRepository(this._apiClient, {this.machineId});

  @override
  Future<List<Product>> getProducts() async {
    try {
      if (machineId == null) {
        throw Exception('Machine ID not found. Please login again.');
      }

      // Fetch services for this machine
      final response = await _apiClient.get(
        '/machines/$machineId/services',
      );

      if (response.data['success'] == true) {
        final servicesData = response.data['data'] as List;
        
        // Map services to Product model with proper field mapping
        return servicesData.map((serviceJson) {
          return Product(
            id: serviceJson['id'] as String,
            type: ItemType.SERVICE,
            name: serviceJson['name'] as String,
            category: 'Service', // Default category for services
            price: (serviceJson['price'] as num).toDouble(),
            isActive: serviceJson['status'] == 'active',
            taxRate: 18.0, // Default tax rate
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching services: $e');
      rethrow;
    }
  }
}
