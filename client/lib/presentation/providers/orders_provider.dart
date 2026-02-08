import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/order_model.dart';
import 'repository_providers.dart';

enum OrderFilter { all, cash, upi, pending }

class OrdersState {
  final List<Order> allOrders;
  final List<Order> filteredOrders;
  final OrderFilter selectedFilter;
  final bool isLoading;
  final String searchQuery;

  OrdersState({
    this.allOrders = const [],
    this.filteredOrders = const [],
    this.selectedFilter = OrderFilter.all,
    this.isLoading = false,
    this.searchQuery = '',
  });

  OrdersState copyWith({
    List<Order>? allOrders,
    List<Order>? filteredOrders,
    OrderFilter? selectedFilter,
    bool? isLoading,
    String? searchQuery,
  }) {
    return OrdersState(
      allOrders: allOrders ?? this.allOrders,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class OrdersController extends StateNotifier<OrdersState> {
  final Ref ref;

  OrdersController(this.ref) : super(OrdersState()) {
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    state = state.copyWith(isLoading: true);

    // Simulate delay
    await Future.delayed(const Duration(milliseconds: 800));

    final repo = ref.read(orderRepositoryProvider);
    final orders = await repo.getOrders();

    state = state.copyWith(
      allOrders: orders,
      filteredOrders: orders,
      isLoading: false,
    );
  }

  void setFilter(OrderFilter filter) {
    state = state.copyWith(selectedFilter: filter);
    _applyFilters();
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void _applyFilters() {
    List<Order> filtered = state.allOrders;

    // Apply Tab Filter
    if (state.selectedFilter != OrderFilter.all) {
      if (state.selectedFilter == OrderFilter.pending) {
        filtered = filtered.where((o) => !o.isPaid).toList();
      } else {
        // Mocking payment method filter based on some criteria
        // In real app, Order model should have paymentMethod field
        // Here we just map 'cash' and 'upi' to isPaid for demo or separate field if exists
        // Since mock data might not have detailed payment methods, we will simplify:
        // Cash -> Simple logic or random for demo if field missing.
        // For now let's assume all paid are split.
        // Checking Order model: has paymentMethod string.

        final method =
            state.selectedFilter == OrderFilter.cash ? 'Cash' : 'UPI';
        filtered = filtered.where((o) => o.paymentMethod == method).toList();
      }
    }

    // Apply Search
    if (state.searchQuery.isNotEmpty) {
      final q = state.searchQuery.toLowerCase();
      filtered = filtered.where((o) {
        final idMatch = o.id.toLowerCase().contains(q);
        final clientMatch = o.clientName.toLowerCase().contains(q);
        // also search items?
        final itemMatch =
            o.items.any((i) => i.productName.toLowerCase().contains(q));
        return idMatch || clientMatch || itemMatch;
      }).toList();
    }

    state = state.copyWith(filteredOrders: filtered);
  }
}

final ordersProvider =
    StateNotifierProvider<OrdersController, OrdersState>((ref) {
  return OrdersController(ref);
});
