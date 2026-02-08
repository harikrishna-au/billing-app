import '../models/order_model.dart';

abstract class OrderRepository {
  Future<List<Order>> getOrders({String? query, OrderStatus? status});
  Future<Order> createOrder(Order order);
  Future<void> updateOrderStatus(String id, OrderStatus status);
}
