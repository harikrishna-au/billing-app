import 'package:flutter/services.dart';

/// Result of a Paytm EDC card payment.
class PaytmPaymentResult {
  final bool success;
  final String orderId;
  final String? transactionId;
  final String? responseCode;
  final String? responseMessage;
  final Map<String, String?> raw;

  const PaytmPaymentResult({
    required this.success,
    required this.orderId,
    this.transactionId,
    this.responseCode,
    this.responseMessage,
    required this.raw,
  });

  factory PaytmPaymentResult.fromMap(Map<String, String?> map) {
    final responseCode = map['RESPONSE_CODE'] ?? map['responseCode'];
    return PaytmPaymentResult(
      success: responseCode == '01' || responseCode == '00',
      orderId: map['ORDER_ID'] ?? map['orderId'] ?? '',
      transactionId: map['TRANSACTION_ID'] ?? map['txnId'],
      responseCode: responseCode,
      responseMessage: map['RESPONSE_MESSAGE'] ?? map['responseMessage'],
      raw: map,
    );
  }

  @override
  String toString() =>
      'PaytmPaymentResult(success=$success, orderId=$orderId, '
      'txnId=$transactionId, code=$responseCode, msg=$responseMessage)';
}

/// Payment modes supported by Paytm EDC.
enum PaytmPayMode { card, qr, all }

extension PaytmPayModeExt on PaytmPayMode {
  String get value {
    switch (this) {
      case PaytmPayMode.card: return 'CARD';
      case PaytmPayMode.qr:   return 'QR';
      case PaytmPayMode.all:  return 'ALL';
    }
  }
}

/// Flutter service that talks to the Paytm EDC Android app via MethodChannel.
///
/// On Paytm POS hardware the Paytm EDC app handles card swiping / NFC / QR.
/// This service invokes it and receives the payment result via onActivityResult.
///
/// Usage:
/// ```dart
/// final service = PaytmPosService();
/// final result = await service.doPayment(
///   orderId: 'ORD-001',
///   amount: '150.00',        // in rupees, 2 decimal places
///   payMode: PaytmPayMode.card,
/// );
/// if (result.success) { /* mark order paid */ }
/// ```
class PaytmPosService {
  static const _channel = MethodChannel('com.hadoom.mit/paytm_edc');

  /// Invoke Paytm EDC to collect a card / QR payment.
  ///
  /// [amount] must be a string in rupees with 2 decimal places, e.g. "150.00".
  Future<PaytmPaymentResult> doPayment({
    required String orderId,
    required String amount,
    PaytmPayMode payMode = PaytmPayMode.card,
  }) async {
    final raw = await _channel.invokeMapMethod<String, String>('doPayment', {
      'orderId': orderId,
      'amount': amount,
      'payMode': payMode.value,
    });
    return PaytmPaymentResult.fromMap(raw ?? {});
  }

  /// Check the status of a previously initiated payment.
  Future<PaytmPaymentResult> checkStatus({required String orderId}) async {
    final raw = await _channel.invokeMapMethod<String, String>('checkStatus', {
      'orderId': orderId,
    });
    return PaytmPaymentResult.fromMap(raw ?? {});
  }

  /// Void (reverse) a previously completed transaction.
  Future<PaytmPaymentResult> doVoid({required String orderId}) async {
    final raw = await _channel.invokeMapMethod<String, String>('doVoid', {
      'orderId': orderId,
    });
    return PaytmPaymentResult.fromMap(raw ?? {});
  }

  /// Returns true if the Paytm EDC app is installed on this device.
  /// Use this to conditionally show the "Pay by Card" option.
  Future<bool> isPaytmInstalled() async {
    return await _channel.invokeMethod<bool>('isPaytmInstalled') ?? false;
  }
}
