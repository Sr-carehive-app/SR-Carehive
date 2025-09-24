import 'dart:async';
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PlatformRazorpay {
  static Future<Map<String, dynamic>> open(Map<String, dynamic> options) async {
    final razorpay = Razorpay();
    final completer = Completer<Map<String, dynamic>>();

    void clearHandlers() { try { razorpay.clear(); } catch (_) {} }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse resp) async {
      try {
        completer.complete({
          'razorpay_order_id': resp.orderId,
          'razorpay_payment_id': resp.paymentId,
          'razorpay_signature': resp.signature,
        });
      } catch (e) {
        completer.completeError(e);
      } finally {
        clearHandlers();
      }
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse resp) {
      clearHandlers();
      completer.completeError('payment_error: ${resp.code} ${resp.message}');
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    razorpay.open(options);
    return completer.future;
  }
}
