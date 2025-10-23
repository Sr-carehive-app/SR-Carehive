import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SupportService {
  static String get _base => dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';

  static Future<void> submitPaymentQuery({
    required String paymentId,
    required String name,
    required String email,
    String? mobile,
    String? amount,
    String? complaint,
    String? reason,
    String? transactionDate,
  }) async {
    final uri = Uri.parse('$_base/api/support/payment-query');
    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'payment_id': paymentId,
        'name': name,
        'email': email,
        'mobile': mobile,
        'amount': amount,
        'complaint': complaint,
        'reason': reason,
        'transaction_date': transactionDate,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Submit failed: ${resp.statusCode} ${resp.body}');
    }
  }
}
