import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/catalogue_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/order_repository.dart';

// Repositories - TODO: Replace with API implementations

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  throw UnimplementedError(
      'ClientRepository not implemented. Create ApiClientRepository.');
});

final catalogueRepositoryProvider = Provider<CatalogueRepository>((ref) {
  throw UnimplementedError(
      'CatalogueRepository not implemented. Create ApiCatalogueRepository.');
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  throw UnimplementedError(
      'DashboardRepository not implemented. Create ApiDashboardRepository.');
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  throw UnimplementedError(
      'OrderRepository not implemented. Create ApiOrderRepository.');
});
