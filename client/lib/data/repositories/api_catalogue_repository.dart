import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/services/cache_service.dart';
import '../models/product_model.dart';
import 'catalogue_repository.dart';

class ApiCatalogueRepository implements CatalogueRepository {
  static const _cacheKey = 'products';

  final ApiClient _apiClient;
  final CacheService _cache;
  final String? machineId;

  ApiCatalogueRepository(this._apiClient, this._cache, {this.machineId});

  @override
  List<Product> loadCached() {
    final raw = _cache.get(_cacheKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Product>> getProducts() async {
    if (machineId == null) {
      throw Exception('Machine ID not found. Please login again.');
    }

    try {
      final response = await _apiClient.get('/machines/$machineId/services');

      if (response.data['success'] == true) {
        final servicesData = response.data['data'] as List;
        final products = servicesData.map((s) {
          return Product(
            id: s['id'] as String,
            type: ItemType.SERVICE,
            name: s['name'] as String,
            category: 'Service',
            price: (s['price'] as num).toDouble(),
            isActive: s['status'] == 'active',
            taxRate: 18.0,
          );
        }).toList();

        // Persist fresh results so next offline launch shows them.
        await _cache.set(_cacheKey,
            jsonEncode(products.map((p) => p.toJson()).toList()));

        return products;
      }
      // Unexpected success=false — fall through to cache.
    } catch (_) {
      // Network or timeout error — fall through to cache.
    }

    // Serve stale cache rather than throwing when offline.
    final cached = loadCached();
    if (cached.isNotEmpty) return cached;

    throw Exception(
        'Unable to load catalogue. Please check your internet connection.');
  }
}
