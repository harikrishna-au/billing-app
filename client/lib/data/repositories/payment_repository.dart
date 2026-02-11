import '../models/payment_model.dart';

abstract class PaymentRepository {
  Future<List<Payment>> getPayments();
  Future<List<Payment>> getPaymentsByDateRange(DateTime start, DateTime end);
  Future<Payment> getPaymentById(String id);
  Future<Payment> createPayment(Payment payment);
  Future<void> updatePaymentStatus(String id, PaymentStatus status);
}
