import '../models/payment_model.dart';

abstract class PaymentRepository {
  Future<List<Payment>> getPayments();
  Future<List<Payment>> getPaymentsByMachine(
    String machineId, {
    String? period,
    PaymentMethod? method,
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<List<Payment>> getPaymentsByDateRange(DateTime start, DateTime end);
  Future<Payment> getPaymentById(String id);
  Future<Payment> createPayment(Payment payment);
  Future<void> updatePaymentStatus(String id, PaymentStatus status);

  /// Initiates a transaction by getting the token from backend
  Future<Map<String, dynamic>> initiatePaytmTransaction({
    required String orderId,
    required double amount,
    required String customerId,
  });
}
