import 'dart:convert';

import 'package:flutter/services.dart';

/// Plutus Smart integration via Messenger IPC.
///
/// Android side binds to `com.pinelabs.masterapp.SERVER`, sends MASTERAPPREQUEST,
/// and receives MASTERAPPRESPONSE — exactly as shown in the Pine Labs reference sample.
class PlutusSmartService {
  static const MethodChannel _channel = MethodChannel('PLUTUS-API');

  /// Warm-up bind to Pine Labs MasterApp service.
  static Future<void> bindToService() async {
    await _channel.invokeMethod('bindToService');
  }

  static Future<String?> startTransaction({
    required String transactionJson,
  }) async {
    final res = await _channel.invokeMethod<String>('startTransaction', {
      'transactionData': transactionJson,
    });
    return res;
  }

  /// Hardware serial / model from PayDroid (falls back to [PineTerminalConfig]).
  static Future<Map<String, String>> getTerminalInfo() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getTerminalInfo',
    );
    if (raw == null) return const {};
    return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  static Future<String?> startPrintJob({required String printJson}) async {
    final res = await _channel.invokeMethod<String>('startPrintJob', {
      'printData': printJson,
    });
    return res;
  }
}

class PlutusRequestBuilder {
  /// Sanitize a reference number for Pine Labs: keep only alphanumeric chars
  /// and hyphens. The slash in our internal format (e.g. "1014596/27") is
  /// replaced with a hyphen so Pine Labs doesn't reject the field.
  static String _sanitizeRef(String ref) =>
      ref.replaceAll('/', '-').replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');

  /// DoPrint (MethodId=1002) print job.
  static String printJob({
    required String applicationId,
    required String versionNo,
    String? userId,
    required String printRefNo,
    required List<Map<String, dynamic>> data,
  }) {
    return jsonEncode({
      'Header': {
        'ApplicationId': applicationId,
        'UserId': (userId != null && userId.isNotEmpty) ? userId : '',
        'MethodId': '1002',
        'VersionNo': versionNo,
      },
      'Detail': {
        'PrintRefNo': _sanitizeRef(printRefNo),
        'SavePrintData': true,
        'Data': data,
      },
    });
  }

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
        'UserId': (userId != null && userId.isNotEmpty) ? userId : '',
        'MethodId': '1001',
        'VersionNo': versionNo,
      },
      'Detail': {
        'TransactionType': transactionType,
        'BillingRefNo': _sanitizeRef(billingRefNo),
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
      final code = (codeAny is int)
          ? codeAny
          : int.tryParse(codeAny?.toString() ?? '');
      final msg = msgAny?.toString();
      return PlutusResponse(responseCode: code, responseMsg: msg);
    } catch (_) {
      return const PlutusResponse();
    }
  }
}
