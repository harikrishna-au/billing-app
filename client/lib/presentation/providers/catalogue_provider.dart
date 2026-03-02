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
    ref.watch(cacheServiceProvider),
    machineId: user?.id,
  );
});

// State
class CatalogueState {
  final bool isLoading;
  final List<Product> items;
  final String? error;
  /// True when items are served from cache because the network is unavailable.
  final bool isOffline;

  CatalogueState({
    this.isLoading = false,
    this.items = const [],
    this.error,
    this.isOffline = false,
  });

  CatalogueState copyWith({
    bool? isLoading,
    List<Product>? items,
    String? error,
    bool? isOffline,
  }) {
    return CatalogueState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      error: error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

// Notifier
class CatalogueNotifier extends StateNotifier<CatalogueState> {
  final CatalogueRepository _repository;
  final Ref _ref;
  List<Product> _allItems = [];

  CatalogueNotifier(this._repository, this._ref) : super(CatalogueState()) {
    // Pre-populate from cache synchronously so the UI has data before the
    // first network response arrives.
    final cached = _repository.loadCached();
    if (cached.isNotEmpty) {
      _allItems = cached;
      state = CatalogueState(items: cached, isLoading: false, isOffline: false);
    }
  }

  Future<void> fetchItems() async {
    final hasCached = state.items.isNotEmpty;

    // Show spinner only when there's nothing to display yet.
    if (!hasCached) state = state.copyWith(isLoading: true, error: null);

    try {
      final user = _ref.read(authProvider).user;
      if (user == null) throw Exception('User not authenticated');

      final items = await _repository.getProducts();
      _allItems = items;
      state = state.copyWith(
          items: items, isLoading: false, isOffline: false, error: null);

      assert(() {
        // ignore: avoid_print
        print('╔══ Products Fetched ══════════════════════════════════');
        // ignore: avoid_print
        print('║  Total products : ${items.length}');
        for (final item in items) {
          // ignore: avoid_print
          print('║  ${item.name.padRight(20)} ₹${item.price.toStringAsFixed(2)}  [${item.isActive ? "active" : "inactive"}]');
        }
        // ignore: avoid_print
        print('╚═════════════════════════════════════════════════════');
        return true;
      }());
    } catch (e) {
      if (hasCached) {
        // Already showing cached data — just mark as offline, no error text.
        state = state.copyWith(isLoading: false, isOffline: true);
      } else {
        state = state.copyWith(
            isLoading: false, error: e.toString(), isOffline: true);
      }
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      state = state.copyWith(items: _allItems);
    } else {
      final filtered = _allItems
          .where((item) =>
              item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      state = state.copyWith(items: filtered);
    }
  }

  void setFilter(String? category) {
    if (category == null) {
      state = state.copyWith(items: _allItems);
    }
  }
}

final catalogueProvider =
    StateNotifierProvider<CatalogueNotifier, CatalogueState>((ref) {
  return CatalogueNotifier(ref.watch(catalogueRepositoryProvider), ref);
});
