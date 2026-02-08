import 'package:flutter/services.dart';
import 'package:paytmpayments_allinonesdk/paytmpayments_allinonesdk.dart';

class PaytmService {
  Future<Map<dynamic, dynamic>> startTransaction({
    required String mid,
    required String orderId,
    required String amount,
    required String txnToken,
    required String callbackUrl,
    required bool isStaging,
    bool restrictAppInvoke = false,
  }) async {
    try {
      var response = await PaytmPaymentsAllinonesdk().startTransaction(
        mid,
        orderId,
        amount,
        txnToken,
        callbackUrl,
        isStaging,
        restrictAppInvoke,
      );
      return response ?? {};
    } catch (err) {
      if (err is PlatformException) {
        throw Exception(err.message ?? 'Payment failed');
      }
      throw Exception(err.toString());
    }
  }
}
