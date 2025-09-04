import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  static String get _base => dotenv.env['API_BASE_URL'] ?? 'http://localhost:9090';

  static Future<Map<String, dynamic>> initiateSale({
    required String amount,
    required String email,
    required String mobile,
    Map<String, dynamic>? appointment,
    String? paymentMode,
  }) async {
    final uri = Uri.parse('$_base/api/pg/payment/initiateSale');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'customerEmailID': email,
        'customerMobileNo': mobile,
        'appointment': appointment,
        if (paymentMode != null) 'paymentMode': paymentMode,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('initiateSale failed: ${resp.statusCode} ${resp.body}');
  }
}
