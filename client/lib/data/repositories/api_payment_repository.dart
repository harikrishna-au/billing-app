import 'dart:convert';
import '../models/payment_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/cache_service.dart';
import 'payment_repository.dart';

class ApiPaymentRepository implements PaymentRepository {
  static const _cacheKey = 'payments_all';

  final ApiClient _apiClient;
  final CacheService _cache;
  final String? machineId;

  ApiPaymentRepository(this._apiClient, this._cache, {this.machineId});

  // ── Cache helpers ────────────────────────────────────────────────────────

  @override
  List<Payment> loadCachedPayments() {
    final raw = _cache.get(_cacheKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistPayments(List<Payment> payments) async {
    await _cache.set(
        _cacheKey, jsonEncode(payments.map((p) => p.toJson()).toList()));
  }

  // ── Repository methods ───────────────────────────────────────────────────

  @override
  Future<List<Payment>> getPayments() async {
    try {
      final queryParams =
          machineId != null ? {'machine_id': machineId} : null;
      final response = await _apiClient.get(
        ApiConstants.payments,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final paymentsData = response.data['data']['payments'] as List;
        final payments = paymentsData.map((p) => Payment.fromJson(p)).toList();
        await _persistPayments(payments);
        return payments;
      }
      return loadCachedPayments();
    } catch (_) {
      final cached = loadCachedPayments();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  @override
  Future<List<Payment>> getPaymentsByDateRange(
      DateTime start, DateTime end) async {
    try {
      final queryParams = {
        'start_date': start.toUtc().toIso8601String(),
        'end_date': end.toUtc().toIso8601String(),
        if (machineId != null) 'machine_id': machineId!,
      };
      final response = await _apiClient.get(
        ApiConstants.payments,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final paymentsData = response.data['data']['payments'] as List;
        return paymentsData.map((p) => Payment.fromJson(p)).toList();
      }
      return _filterCachedByRange(start, end);
    } catch (_) {
      // Fall back to filtering the cached full list by date range.
      final filtered = _filterCachedByRange(start, end);
      if (filtered.isNotEmpty) return filtered;
      rethrow;
    }
  }

  List<Payment> _filterCachedByRange(DateTime start, DateTime end) {
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();
    return loadCachedPayments()
        .where((p) =>
            !p.createdAt.toUtc().isBefore(startUtc) &&
            !p.createdAt.toUtc().isAfter(endUtc))
        .toList();
  }

  @override
  Future<Payment> getPaymentById(String id) async {
    final response = await _apiClient.get(ApiConstants.paymentById(id));
    if (response.data['success'] == true) {
      return Payment.fromJson(response.data['data']);
    }
    throw Exception('Payment not found');
  }

  @override
  Future<Payment> createPayment(Payment payment) async {
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
  }

  @override
  Future<void> updatePaymentStatus(String id, PaymentStatus status) async {
    await _apiClient.put(
      ApiConstants.paymentById(id),
      data: {'status': status.name},
    );
  }
}
