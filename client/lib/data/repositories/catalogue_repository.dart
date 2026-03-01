import '../models/product_model.dart';

abstract class CatalogueRepository {
  /// Synchronous — returns whatever is in the local cache (may be empty).
  List<Product> loadCached();

  /// Network fetch. Falls back to [loadCached] on connectivity failure.
  Future<List<Product>> getProducts();
}
