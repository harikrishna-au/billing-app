import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/product_model.dart';
import 'catalogue_repository.dart';

class ApiCatalogueRepository implements CatalogueRepository {
  final ApiClient _apiClient;

  ApiCatalogueRepository(this._apiClient);

  @override
  Future<List<Product>> getProducts(String machineId) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.catalogue(machineId),
      );

      if (response.data['success'] == true) {
        final productsData = response.data['data']['items'] as List;
        return productsData.map((p) => Product.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
