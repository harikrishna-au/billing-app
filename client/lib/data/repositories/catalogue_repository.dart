import '../models/product_model.dart';

abstract class CatalogueRepository {
  Future<List<Product>> getProducts();
}
