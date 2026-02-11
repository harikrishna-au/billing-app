import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/providers.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/catalogue_repository.dart';
import '../../data/repositories/api_catalogue_repository.dart';
import 'auth_provider.dart';

// Repository Provider
final catalogueRepositoryProvider = Provider<CatalogueRepository>((ref) {
  final user = ref.watch(authProvider).user;
  return ApiCatalogueRepository(
    ref.watch(apiClientProvider),
    machineId: user?.id,
  );
});

// State
class CatalogueState {
  final bool isLoading;
  final List<Product> items;
  final String? error;

  CatalogueState({
    this.isLoading = false,
    this.items = const [],
    this.error,
  });

  CatalogueState copyWith({
    bool? isLoading,
    List<Product>? items,
    String? error,
  }) {
    return CatalogueState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      error: error,
    );
  }
}

// Notifier
class CatalogueNotifier extends StateNotifier<CatalogueState> {
  final CatalogueRepository _repository;
  final Ref _ref;
  List<Product> _allItems = [];

  CatalogueNotifier(this._repository, this._ref) : super(CatalogueState());

  Future<void> fetchItems() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _ref.read(authProvider).user;
      if (user == null) throw Exception('User not authenticated');

      final items = await _repository.getProducts();
      _allItems = items;
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      state = state.copyWith(items: _allItems);
    } else {
      final filtered = _allItems.where((item) {
        return item.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
      state = state.copyWith(items: filtered);
    }
  }

  void setFilter(String? category) {
    if (category == null) {
      state = state.copyWith(items: _allItems);
    } else {
      // Implement category filter if needed
    }
  }
}

final catalogueProvider =
    StateNotifierProvider<CatalogueNotifier, CatalogueState>((ref) {
  return CatalogueNotifier(ref.watch(catalogueRepositoryProvider), ref);
});
