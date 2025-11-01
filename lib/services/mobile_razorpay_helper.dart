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
      
      // Check if user cancelled payment
      final code = resp.code?.toString() ?? '';
      final message = resp.message?.toString() ?? '';
      
      // Razorpay codes: 0 = Cancelled by user, 2 = Back button pressed
      if (code == '0' || code == '2' || 
          message.toLowerCase().contains('cancel') || 
          message.toLowerCase().contains('dismiss')) {
        // Return structured error for cancellation
        completer.completeError({
          'error': {
            'code': 'cancelled',
            'description': 'Payment cancelled by user'
          }
        });
      } else {
        // Return structured error for failures
        completer.completeError({
          'error': {
            'code': resp.code?.toString() ?? 'payment_failed',
            'description': message.isNotEmpty ? message : 'Payment failed'
          }
        });
      }
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    razorpay.open(options);
    return completer.future;
  }
}
