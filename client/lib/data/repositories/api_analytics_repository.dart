import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class TransactionSummary {
  final String date;
  final String startTime;
  final String endTime;
  final List<PaymentDetail> payments;
  final int successfulCount;
  final double successfulAmount;
  final double successfulCash;
  final double successfulUpi;
  final double successfulCard;
  final int failedCount;
  final double failedAmount;
  final double failedCash;
  final double failedUpi;
  final double failedCard;

  TransactionSummary({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.payments,
    required this.successfulCount,
    required this.successfulAmount,
    required this.successfulCash,
    required this.successfulUpi,
    required this.successfulCard,
    required this.failedCount,
    required this.failedAmount,
    required this.failedCash,
    required this.failedUpi,
    required this.failedCard,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) =>
      TransactionSummary(
        date: json['date'] as String? ?? '',
        startTime: json['start_time'] as String? ?? '',
        endTime: json['end_time'] as String? ?? '',
        payments: (json['payments'] as List?)
                ?.map((e) => PaymentDetail.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        successfulCount: json['successful_count'] as int? ?? 0,
        successfulAmount: (json['successful_amount'] as num?)?.toDouble() ?? 0.0,
        successfulCash: (json['successful_cash'] as num?)?.toDouble() ?? 0.0,
        successfulUpi: (json['successful_upi'] as num?)?.toDouble() ?? 0.0,
        successfulCard: (json['successful_card'] as num?)?.toDouble() ?? 0.0,
        failedCount: json['failed_count'] as int? ?? 0,
        failedAmount: (json['failed_amount'] as num?)?.toDouble() ?? 0.0,
        failedCash: (json['failed_cash'] as num?)?.toDouble() ?? 0.0,
        failedUpi: (json['failed_upi'] as num?)?.toDouble() ?? 0.0,
        failedCard: (json['failed_card'] as num?)?.toDouble() ?? 0.0,
      );
}

class PaymentDetail {
  final String billNumber;
  final double amount;
  final String method;
  final String status;

  PaymentDetail({
    required this.billNumber,
    required this.amount,
    required this.method,
    required this.status,
  });

  factory PaymentDetail.fromJson(Map<String, dynamic> json) => PaymentDetail(
    billNumber: json['bill_number'] as String? ?? '',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    method: json['method'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );
}

class SalesSummary {
  final String date;
  final String startTime;
  final String endTime;
  final String firstBill;
  final String lastBill;
  final int totalCount;
  final double totalAmount;
  final List<MethodBreakdown> byMethod;
  final double failedUpiAmount;
  final double failedCardAmount;

  SalesSummary({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.firstBill,
    required this.lastBill,
    required this.totalCount,
    required this.totalAmount,
    required this.byMethod,
    required this.failedUpiAmount,
    required this.failedCardAmount,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
    date: json['date'] as String? ?? '',
    startTime: json['start_time'] as String? ?? '',
    endTime: json['end_time'] as String? ?? '',
    firstBill: json['first_bill'] as String? ?? '',
    lastBill: json['last_bill'] as String? ?? '',
    totalCount: json['total_count'] as int? ?? 0,
    totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
    byMethod: (json['by_method'] as List?)
            ?.map((e) => MethodBreakdown.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    failedUpiAmount: (json['failed_upi_amount'] as num?)?.toDouble() ?? 0.0,
    failedCardAmount: (json['failed_card_amount'] as num?)?.toDouble() ?? 0.0,
  );
}

class MethodBreakdown {
  final String method;
  final int count;
  final double amount;
  final int failedCount;
  final double failedAmount;

  MethodBreakdown({
    required this.method,
    required this.count,
    required this.amount,
    required this.failedCount,
    required this.failedAmount,
  });

  factory MethodBreakdown.fromJson(Map<String, dynamic> json) =>
      MethodBreakdown(
        method: json['method'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        failedCount: json['failed_count'] as int? ?? 0,
        failedAmount: (json['failed_amount'] as num?)?.toDouble() ?? 0.0,
      );
}

class ApiAnalyticsRepository {
  final ApiClient _apiClient;

  ApiAnalyticsRepository(this._apiClient);

  Future<TransactionSummary> getTransactionSummary(String dateStr) async {
    try {
      final response = await _apiClient.get(
        '/analytics/transaction-summary/$dateStr',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return TransactionSummary.fromJson(
              data['data'] as Map<String, dynamic>);
        }
      }
      throw Exception('Failed to fetch transaction summary');
    } catch (e) {
      rethrow;
    }
  }

  Future<SalesSummary> getSalesSummary(String dateStr) async {
    try {
      final response = await _apiClient.get(
        '/analytics/sales-summary/$dateStr',
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true && data['data'] != null) {
          return SalesSummary.fromJson(data['data'] as Map<String, dynamic>);
        }
      }
      throw Exception('Failed to fetch sales summary');
    } catch (e) {
      rethrow;
    }
  }
}
