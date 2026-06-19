import 'dart:convert';

import 'package:dio/dio.dart';
import '../models/payment_model.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/services/cache_service.dart';
import 'payment_repository.dart';

String _apiDetailFromBody(dynamic raw) {
  if (raw is! Map) return 'Request failed';
  final m = Map<String, dynamic>.from(raw);
  final d = m['detail'];
  if (d is String) return d;
  if (d is List && d.isNotEmpty) {
    final first = d.first;
    if (first is Map && first['msg'] is String) return first['msg'] as String;
  }
  final msg = m['message'];
  if (msg is String) return msg;
  return 'Request failed';
}

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

  @override
  Future<void> mergePaymentIntoLocalCache(Payment payment) async {
    final existing = loadCachedPayments();
    final tail =
        existing.where((p) => p.billNumber != payment.billNumber).toList();
    await _persistPayments([payment, ...tail]);
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
        // Only cache if we have data; otherwise serve from DB pagination
        if (payments.isNotEmpty) {
          await _persistPayments(payments);
        }
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
      // Use server-side filtering instead of client-side filtering
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

    // Short timeout: if the server doesn't respond in 12 s, fall back to the
    // offline queue immediately rather than blocking the cashier for 90 s.
    // The global 90-s timeout exists only for Render cold-starts on GETs.
    final response = await _apiClient.post(
      ApiConstants.payments,
      data: {
        'machine_id': machineId,
        'bill_number': payment.billNumber,
        'amount': payment.amount,
        'method': payment.method.name.toUpperCase(),
        'status': payment.status.name,
      },
      options: Options(
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    final raw = response.data;
    if (raw is! Map) {
      throw Exception('Invalid response from server');
    }
    final body = Map<String, dynamic>.from(raw);
    if (body['success'] == true && body['data'] != null) {
      try {
        return Payment.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
      } catch (e) {
        throw Exception(
          'Payment may have been saved but the app could not read the response. '
          'Pull to refresh on Orders, or try again. ($e)',
        );
      }
    }
    throw Exception(_apiDetailFromBody(body));
  }

  @override
  Future<Payment> updatePaymentStatus(String id, PaymentStatus status) async {
    final response = await _apiClient.put(
      ApiConstants.paymentById(id),
      data: {'status': status.name},
    );
    final raw = response.data;
    if (raw is Map && raw['success'] == true && raw['data'] != null) {
      return Payment.fromJson(
        Map<String, dynamic>.from(raw['data'] as Map),
      );
    }
    throw Exception('Failed to update payment');
  }
}
