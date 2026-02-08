import '../models/payment_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import 'payment_repository.dart';

class ApiPaymentRepository implements PaymentRepository {
  final ApiClient _apiClient;

  ApiPaymentRepository(this._apiClient);

  @override
  Future<List<Payment>> getPayments() async {
    try {
      final response = await _apiClient.get(ApiConstants.payments);

      if (response.data['success'] == true) {
        final paymentsData = response.data['data']['payments'] as List;
        return paymentsData.map((p) => Payment.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Payment>> getPaymentsByMachine(
    String machineId, {
    String? period,
    PaymentMethod? method,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (period != null) queryParams['period'] = period;
      if (method != null)
        queryParams['method'] = method
            .name; // Enum name usually matches API expectation (UPI, Card, Cash)
      if (startDate != null)
        queryParams['start_date'] = startDate.toIso8601String();
      if (endDate != null) queryParams['end_date'] = endDate.toIso8601String();

      final response = await _apiClient.get(
        ApiConstants.paymentsByMachine(machineId),
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final paymentsData = response.data['data']['payments'] as List;
        return paymentsData.map((p) => Payment.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Payment>> getPaymentsByDateRange(
      DateTime start, DateTime end) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.payments,
        queryParameters: {
          'start_date': start.toIso8601String(),
          'end_date': end.toIso8601String(),
        },
      );

      if (response.data['success'] == true) {
        final paymentsData = response.data['data']['payments'] as List;
        return paymentsData.map((p) => Payment.fromJson(p)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Payment> getPaymentById(String id) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.paymentById(id),
      );

      if (response.data['success'] == true) {
        return Payment.fromJson(response.data['data']);
      }
      throw Exception('Payment not found');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Payment> createPayment(Payment payment) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.payments,
        data: {
          'machine_id': payment.machineId,
          'bill_number': payment.billNumber,
          'amount': payment.amount,
          'method': payment.method.name.toUpperCase(),
          'status': payment.status.name,
        },
      );

      if (response.data['success'] == true) {
        return Payment.fromJson(response.data['data']);
      }
      throw Exception('Failed to create payment');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updatePaymentStatus(String id, PaymentStatus status) async {
    try {
      await _apiClient.put(
        ApiConstants.paymentById(id),
        data: {
          'status': status.name,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> initiatePaytmTransaction({
    required String orderId,
    required double amount,
    required String customerId,
  }) async {
    try {
      final response = await _apiClient.post(
        // Assuming a new endpoint for initiating transaction
        '/payments/initiate',
        data: {
          'order_id': orderId,
          'amount': amount,
          'customer_id': customerId,
        },
      );

      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception('Failed to initiate transaction');
    } catch (e) {
      rethrow;
    }
  }
}
