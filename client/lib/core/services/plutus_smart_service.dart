import 'dart:convert';

import 'package:flutter/services.dart';

/// Plutus Smart App-to-App integration (Hybrid Intent flow).
///
/// Android side is implemented in `MainActivity.kt` under MethodChannel `PLUTUS-API`.
class PlutusSmartService {
  static const MethodChannel _channel = MethodChannel('PLUTUS-API');

  /// Best-effort bind (some devices require it before HYBRID_REQUEST works).
  static Future<void> bindToService() async {
    await _channel.invokeMethod('bindToService');
  }

  static Future<String?> startTransaction({required String transactionJson}) async {
    final res = await _channel.invokeMethod<String>(
      'startTransaction',
      {'transactionData': transactionJson},
    );
    return res;
  }

  static Future<String?> startPrintJob({required String printJson}) async {
    final res = await _channel.invokeMethod<String>(
      'startPrintJob',
      {'printData': printJson},
    );
    return res;
  }
}

class PlutusRequestBuilder {
  /// DoTransaction (MethodId=1001) sale.
  static String sale({
    required String applicationId,
    required String versionNo,
    String? userId,
    required String billingRefNo,
    required int paymentAmountPaise,
    int transactionType = 4001,
  }) {
    return jsonEncode({
      'Header': {
        'ApplicationId': applicationId,
        if (userId != null) 'UserId': userId,
        'MethodId': '1001',
        'VersionNo': versionNo,
      },
      'Detail': {
        'TransactionType': transactionType,
        'BillingRefNo': billingRefNo,
        'PaymentAmount': paymentAmountPaise,
      },
    });
  }

  /// DoTransaction (MethodId=1001) UPI sale.
  /// As per Pine Labs doc: UPI Sale = 5120, Get Status = 5122.
  static String upiSale({
    required String applicationId,
    required String versionNo,
    String? userId,
    required String billingRefNo,
    required int paymentAmountPaise,
  }) {
    return sale(
      applicationId: applicationId,
      versionNo: versionNo,
      userId: userId,
      billingRefNo: billingRefNo,
      paymentAmountPaise: paymentAmountPaise,
      transactionType: 5120,
    );
  }

  static String upiGetStatus({
    required String applicationId,
    required String versionNo,
    String? userId,
    required String billingRefNo,
    required int paymentAmountPaise,
  }) {
    return sale(
      applicationId: applicationId,
      versionNo: versionNo,
      userId: userId,
      billingRefNo: billingRefNo,
      paymentAmountPaise: paymentAmountPaise,
      transactionType: 5122,
    );
  }
}

class PlutusResponse {
  final int? responseCode;
  final String? responseMsg;

  const PlutusResponse({this.responseCode, this.responseMsg});

  bool get isApproved => responseCode == 0;
  bool get isInitiatedNeedsStatus => responseCode == 100;

  static PlutusResponse tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const PlutusResponse();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const PlutusResponse();
      final res = decoded['Response'];
      if (res is! Map) return const PlutusResponse();
      final codeAny = res['ResponseCode'];
      final msgAny = res['ResponseMsg'];
      final code = (codeAny is int) ? codeAny : int.tryParse(codeAny?.toString() ?? '');
      final msg = msgAny?.toString();
      return PlutusResponse(responseCode: code, responseMsg: msg);
    } catch (_) {
      return const PlutusResponse();
    }
  }
}

