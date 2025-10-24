import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NurseApiService {
  // Send OTP for healthcare provider login
  static Future<bool> sendOtp({required String email}) async {
    final resp = await http.post(
      Uri.parse('$_base/api/nurse/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (resp.statusCode == 200) return true;
    return resp.body.isNotEmpty ? jsonDecode(resp.body)['error'] ?? false : false;
  }

  // Verify OTP for healthcare provider login
  static Future<dynamic> verifyOtp({required String email, required String otp}) async {
    final resp = await http.post(
      Uri.parse('$_base/api/nurse/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    if (resp.statusCode == 200) return true;
    return resp.body.isNotEmpty ? jsonDecode(resp.body)['error'] ?? false : false;
  }

  // Resend OTP for healthcare provider login
  static Future<bool> resendOtp({required String email}) async {
    final resp = await http.post(
      Uri.parse('$_base/api/nurse/resend-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'resend': true}),
    );
    if (resp.statusCode == 200) return true;
    return resp.body.isNotEmpty ? jsonDecode(resp.body)['error'] ?? false : false;
  }
  static String get _base => dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
  static String? _token; // in-memory bearer token

  static Future<bool> login({required String email, required String password}) async {
    final resp = await http.post(
      Uri.parse('$_base/api/nurse/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      _token = json['token'] as String?;
      return _token != null;
    }
    return false;
  }

  static Map<String, String> _authHeaders() => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer ' + _token!,
      };

  static Future<List<Map<String, dynamic>>> listAppointments() async {
    final resp = await http.get(
      Uri.parse('$_base/api/nurse/appointments'),
      headers: _authHeaders(),
    );
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (json['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      return items;
    }
    throw Exception('Failed to load appointments: ${resp.statusCode} ${resp.body}');
  }

  // Fetch archived (past) appointments from history table.
  // Optional status filter: 'pending' | 'approved' | 'rejected'
  static Future<List<Map<String, dynamic>>> listHistory({String? status}) async {
    final qp = (status != null && status.isNotEmpty && ['pending','approved','rejected'].contains(status.toLowerCase()))
        ? '?status=${Uri.encodeQueryComponent(status.toLowerCase())}'
        : '';
    final resp = await http.get(
      Uri.parse('$_base/api/nurse/appointments/history$qp'),
      headers: _authHeaders(),
    );
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = (json['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      return items;
    }
    throw Exception('Failed to load history: ${resp.statusCode} ${resp.body}');
  }

  static Future<Map<String, dynamic>> approveAppointment({
    required String id,
    required String nurseName,
    required String nursePhone,
    String? branch,
    String? comments,
    bool available = true,
  }) async {
    final resp = await http.post(
  Uri.parse('$_base/api/nurse/appointments/$id/approve'),
      headers: _authHeaders(),
      body: jsonEncode({
        'nurse_name': nurseName,
        'nurse_phone': nursePhone,
        'nurse_branch': branch,
        'nurse_comments': comments,
        'available': available,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Approve failed: ${resp.statusCode} ${resp.body}');
  }

  static Future<Map<String, dynamic>> rejectAppointment({
    required String id,
    required String reason,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/api/nurse/appointments/$id/reject'),
      headers: _authHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Reject failed: ${resp.statusCode} ${resp.body}');
  }

  // Soft delete single appointment (hide from nurse dashboard, mark as expired)
  // Using direct Supabase update since backend archive endpoint doesn't exist
  static Future<void> deleteAppointment({required String id}) async {
    // This will be handled directly in the UI layer using Supabase client
    // to avoid backend dependency
    throw UnimplementedError('Use Supabase client directly in UI layer');
  }

  // Soft delete multiple appointments (hide from nurse dashboard, mark as expired)
  // Using direct Supabase update since backend archive endpoint doesn't exist
  static Future<void> deleteAppointments({required List<String> ids}) async {
    // This will be handled directly in the UI layer using Supabase client
    // to avoid backend dependency
    throw UnimplementedError('Use Supabase client directly in UI layer');
  }
}
