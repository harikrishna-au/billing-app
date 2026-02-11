import '../models/payment_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import 'payment_repository.dart';

class ApiPaymentRepository implements PaymentRepository {
  final ApiClient _apiClient;
  final String? machineId;

  ApiPaymentRepository(this._apiClient, {this.machineId});

  @override
  Future<List<Payment>> getPayments() async {
    try {
      final queryParams = machineId != null ? {'machine_id': machineId} : null;
      final response = await _apiClient.get(
        ApiConstants.payments,
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
      final queryParams = {
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String(),
      };
      if (machineId != null) {
        queryParams['machine_id'] = machineId!;
      }
      final response = await _apiClient.get(
        ApiConstants.payments,
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
      if (machineId == null) {
        throw Exception('Machine ID not found. Please login again.');
      }

      final response = await _apiClient.post(
        ApiConstants.payments,
        data: {
          'machine_id': machineId,
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
}
