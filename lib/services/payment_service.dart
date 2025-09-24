import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  static String get _base => dotenv.env['API_BASE_URL'] ?? 'http://localhost:9090';

  // High-level API: create Razorpay order, open checkout, verify signature.
  static Future<Map<String, dynamic>> payWithRazorpay({
    required String amount, // in rupees, e.g., '199.00'
    required String email,
    required String mobile,
    required String name,
    Map<String, dynamic>? appointment,
    String? description,
  }) async {
    // 1) Create order on server
    final createUri = Uri.parse('$_base/api/pg/razorpay/create-order');
    final createResp = await http.post(
      createUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'appointment': appointment,
        'notes': {'mobile': mobile, 'email': email, 'name': name},
      }),
    );
    if (createResp.statusCode != 200) {
      throw Exception('create-order failed: ${createResp.statusCode} ${createResp.body}');
    }
    final createJson = jsonDecode(createResp.body) as Map<String, dynamic>;
    final orderId = createJson['orderId'] as String;
    final keyId = createJson['keyId'] as String;
    final amountPaise = (createJson['amount'] as num).toInt();

    // 2) Open Razorpay checkout
    final razorpay = Razorpay();
    final completer = Completer<Map<String, dynamic>>();
    void clearHandlers() {
      try {
        razorpay.clear();
      } catch (_) {}
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse resp) async {
      try {
        // 3) Verify signature on server
        final verifyUri = Uri.parse('$_base/api/pg/razorpay/verify');
        final verifyResp = await http.post(
          verifyUri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'razorpay_order_id': resp.orderId,
            'razorpay_payment_id': resp.paymentId,
            'razorpay_signature': resp.signature,
          }),
        );
        if (verifyResp.statusCode == 200) {
          completer.complete(jsonDecode(verifyResp.body) as Map<String, dynamic>);
        } else {
          completer.completeError('verify failed: ${verifyResp.statusCode} ${verifyResp.body}');
        }
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

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {
      // optional
    });

    final options = {
      'key': keyId,
      'amount': amountPaise, // in paise
      'currency': 'INR',
      'name': name,
      'description': description ?? 'Payment',
      'order_id': orderId,
      'prefill': {'contact': mobile, 'email': email, 'name': name},
      'theme': {'color': '#3F51B5'},
    };
    razorpay.open(options);

    final result = await completer.future;
    return result;
  }
}
