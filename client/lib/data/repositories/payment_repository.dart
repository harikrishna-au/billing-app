import '../models/payment_model.dart';

abstract class PaymentRepository {
  /// Synchronous — returns whatever is in the local cache (may be empty).
  List<Payment> loadCachedPayments();

  Future<List<Payment>> getPayments();
  Future<List<Payment>> getPaymentsByDateRange(DateTime start, DateTime end);
  Future<Payment> getPaymentById(String id);
  Future<Payment> createPayment(Payment payment);
  Future<Payment> updatePaymentStatus(String id, PaymentStatus status);

  /// Inserts [payment] at the front of the all-payments local cache, replacing
  /// any row with the same [Payment.billNumber] (dedupe).
  Future<void> mergePaymentIntoLocalCache(Payment payment);
}
