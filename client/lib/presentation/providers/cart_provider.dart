import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/product_model.dart';
// import '../../../../data/models/order_model.dart'; // For OrderItem if needed to map later

class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  double get total => product.price * quantity;
}

class CartState {
  final Map<String, CartItem> items; // Product ID -> CartItem

  CartState({this.items = const {}});

  List<CartItem> get itemList => items.values.toList();

  double get totalAmount =>
      items.values.fold(0.0, (sum, item) => sum + item.total);
  int get totalItems =>
      items.values.fold(0, (sum, item) => sum + item.quantity);

  CartState copyWith({Map<String, CartItem>? items}) {
    return CartState(items: items ?? this.items);
  }
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(CartState());

  void addItem(Product product) {
    final current = state.items[product.id];
    if (current != null) {
      updateQuantity(product.id, current.quantity + 1);
    } else {
      state = state.copyWith(
        items: {
          ...state.items,
          product.id: CartItem(product: product, quantity: 1),
        },
      );
    }
  }

  void removeItem(String productId) {
    final current = state.items[productId];
    if (current == null) return;

    if (current.quantity > 1) {
      updateQuantity(productId, current.quantity - 1);
    } else {
      final newItems = Map<String, CartItem>.from(state.items);
      newItems.remove(productId);
      state = state.copyWith(items: newItems);
    }
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      final newItems = Map<String, CartItem>.from(state.items);
      newItems.remove(productId);
      state = state.copyWith(items: newItems);
      return;
    }

    final current = state.items[productId];
    if (current != null) {
      final newItems = Map<String, CartItem>.from(state.items);
      newItems[productId] =
          CartItem(product: current.product, quantity: quantity);
      state = state.copyWith(items: newItems);
    }
  }

  void clearCart() {
    state = CartState();
  }
}

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});
