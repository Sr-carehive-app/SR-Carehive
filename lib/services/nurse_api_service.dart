import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NurseApiService {
  // Send OTP for healthcare provider login
  static Future<bool> sendOtp({required String email}) async {
    final resp = await http.post(
      Uri.parse('$_base/api/nurse/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    if (resp.statusCode == 200) return true;
    
    // Handle rate limiting (429 Too Many Requests)
    if (resp.statusCode == 429) {
      final error = resp.body.isNotEmpty ? jsonDecode(resp.body)['error'] ?? 'Too many requests' : 'Too many requests';
      throw Exception('429: $error');
    }
    
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
    
    // Handle rate limiting (429 Too Many Requests)
    if (resp.statusCode == 429) {
      final error = resp.body.isNotEmpty ? jsonDecode(resp.body)['error'] ?? 'Too many requests' : 'Too many requests';
      throw Exception('429: $error');
    }
    
    return resp.body.isNotEmpty ? jsonDecode(resp.body)['error'] ?? false : false;
  }
  static String get _base => dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
  static String? _token; // in-memory bearer token
  static const String _tokenKey = 'nurse_auth_token';

  // Initialize and load token from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token != null) {
      print('✅ Nurse token loaded from storage');
    }
  }

  // Save token to storage
  static Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    print('💾 Nurse token saved to storage');
  }

  // Clear token from storage
  static Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    print('🔒 Nurse token cleared from storage');
  }

  // Check if user is authenticated
  static bool get isAuthenticated => _token != null;

  /// Login method that checks application_status
  /// Returns: 
  /// - {'success': true} if approved and login successful
  /// - {'pending': true, 'providerData': {...}} if application is pending/under_review/on_hold
  /// - {'rejected': true, 'providerData': {...}} if application is rejected
  /// - {'success': false, 'error': 'message'} if credentials are wrong or other error
  static Future<Map<String, dynamic>> login({required String email, required String password}) async {
    try {
      print('🔐 Attempting login for: $email');
      
      final resp = await http.post(
        Uri.parse('$_base/api/nurse/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      
      print('📡 Login response status: ${resp.statusCode}');
      print('📡 Login response body: ${resp.body}');
      
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        
        // Check if application is rejected
        if (json['rejected'] == true) {
          print('❌ Application has been rejected');
          return {
            'rejected': true,
            'success': false,
            'providerData': json['providerData'] ?? {},
          };
        }
        
        // Check if application is pending
        if (json['pending'] == true) {
          print('⏳ Application still under review');
          return {
            'pending': true,
            'success': false,
            'providerData': json['providerData'] ?? {},
          };
        }
        
        // Check if login was successful (approved user)
        if (json['success'] == true) {
          // Normal approved login
          final token = json['token'] as String?;
          if (token != null) {
            await _saveToken(token);
            print('✅ Login successful - Token saved');
            return {'success': true};
          } else {
            print('⚠️ Login success but no token received');
            return {'success': false, 'error': 'Authentication error. Please try again.'};
          }
        }
        
        // If success is explicitly false, return the error
        if (json['success'] == false) {
          final errorMsg = json['error'] as String? ?? 'Login failed';
          print('❌ Login failed: $errorMsg');
          return {'success': false, 'error': errorMsg};
        }
        
        // Unknown response format
        print('⚠️ Unknown response format');
        return {'success': false, 'error': 'Unexpected server response'};
      } else if (resp.statusCode == 401) {
        // Unauthorized - invalid credentials
        final json = resp.body.isNotEmpty ? jsonDecode(resp.body) as Map<String, dynamic> : {};
        final errorMsg = json['error'] as String? ?? 'Invalid credentials! Email or password is incorrect.';
        print('❌ Unauthorized: $errorMsg');
        return {'success': false, 'error': errorMsg};
      } else if (resp.statusCode == 400) {
        // Bad request
        final json = resp.body.isNotEmpty ? jsonDecode(resp.body) as Map<String, dynamic> : {};
        final errorMsg = json['error'] as String? ?? 'Invalid request';
        print('❌ Bad request: $errorMsg');
        return {'success': false, 'error': errorMsg};
      } else if (resp.statusCode == 500) {
        // Server error
        final json = resp.body.isNotEmpty ? jsonDecode(resp.body) as Map<String, dynamic> : {};
        final errorMsg = json['error'] as String? ?? 'Server error. Please try again later.';
        print('❌ Server error: $errorMsg');
        return {'success': false, 'error': errorMsg};
      } else {
        // Other errors
        print('❌ Unexpected status code: ${resp.statusCode}');
        return {'success': false, 'error': 'Network error. Please try again.'};
      }
    } catch (e) {
      print('❌ Exception during login: $e');
      return {'success': false, 'error': 'Connection error. Please check your internet and try again.'};
    }
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
