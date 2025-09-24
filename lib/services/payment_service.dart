import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'mobile_razorpay_helper.dart'
  if (dart.library.html) 'web_razorpay_helper.dart';

class PaymentService {
  static String get _base => dotenv.env['API_BASE_URL'] ?? 'http://localhost:9090';
  // Allows routing payment calls to production while keeping the rest on localhost during dev
  static String get _paymentBase => (dotenv.env['PAYMENT_API_BASE_URL'] ?? '').trim().isNotEmpty
      ? (dotenv.env['PAYMENT_API_BASE_URL']!.trim())
      : _base;

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
  final createUri = Uri.parse('$_paymentBase/api/pg/razorpay/create-order');
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
    final keyId = (createJson['keyId'] ?? createJson['key_id'] ?? createJson['key']) as String;
    if (keyId.isEmpty) {
      throw Exception('create-order returned empty keyId');
    }
    final amountPaise = (createJson['amount'] as num).toInt();

    final options = {
      // Provide all common aliases to be safe for web bridge
      'key': keyId,
      'key_id': keyId,
      'keyId': keyId,
      'amount': amountPaise, // in paise
      'currency': 'INR',
      'name': name,
      'description': description ?? 'Payment',
      'order_id': orderId,
      'prefill': {'contact': mobile, 'email': email, 'name': name},
      'theme': {'color': '#3F51B5'},
    };

    // Use platform-specific implementation (web uses Checkout.js, mobile uses plugin)
    final resp = await PlatformRazorpay.open(options);
    final verifyUri = Uri.parse('$_paymentBase/api/pg/razorpay/verify');
    final verifyResp = await http.post(
      verifyUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(resp),
    );
    if (verifyResp.statusCode == 200) {
      return jsonDecode(verifyResp.body) as Map<String, dynamic>;
    }
    throw Exception('verify failed: ${verifyResp.statusCode} ${verifyResp.body}');
  }
}
