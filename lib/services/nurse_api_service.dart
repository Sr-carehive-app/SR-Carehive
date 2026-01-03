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
      print('🔐 Login attempt');
      
      final resp = await http.post(
        Uri.parse('$_base/api/nurse/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      
      print('📡 Response received: ${resp.statusCode}');
      
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
          // Normal approved login or super admin
          final token = json['token'] as String?;
          final isSuperAdmin = json['isSuperAdmin'] == true;
          
          if (token != null) {
            // Save token for both regular providers and super admin
            await _saveToken(token);
            
            if (isSuperAdmin) {
              print('✅ Super Admin login successful - Token saved');
            } else {
              print('✅ Login successful - Token saved (Approved Provider)');
            }
            
            return {
              'success': true,
              'isSuperAdmin': isSuperAdmin,
            };
          } else {
            print('⚠️ Login success but no token received');
            return {'success': false, 'error': 'Authentication error. Please try again.'};
          }
        }
        
        
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

  // ============================================================================
  // FORGOT PASSWORD METHODS
  // ============================================================================

  /// Send password reset OTP to healthcare provider email (and phone if provided)
  /// Returns a map with 'success' and 'message' keys
  /// Throws exception on rate limiting (429) or other errors
  static Future<Map<String, dynamic>> sendPasswordResetOtp({
    required String email,
    String? phone,
  }) async {
    try {
      final requestBody = {'email': email};
      if (phone != null && phone.isNotEmpty) {
        requestBody['phone'] = phone;
      }
      
      final resp = await http.post(
        Uri.parse('$_base/api/nurse/send-password-reset-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      print('📡 Response status: ${resp.statusCode}');
      print('📡 Response body: ${resp.body}');
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return {
          'success': data['success'] ?? true,
          'message': data['message'] ?? 'OTP sent successfully',
          'deliveryChannels': data['deliveryChannels'],
        };
      }
      
      // Handle 404 - Email not found
      if (resp.statusCode == 404) {
        final data = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
        return {
          'success': false,
          'message': data['error'] ?? 'Email not registered as healthcare provider',
          'notFound': true,
        };
      }
      
      // Handle rate limiting (429 Too Many Requests)
      // OTP is already sent, just inform user to check email
      if (resp.statusCode == 429) {
        final data = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
        final errorMsg = data['error'] ?? 'Too many requests';
        final remainingSeconds = data['remainingSeconds'];
        
        // Return success with special message since OTP was already sent
        return {
          'success': true,  // Mark as success because OTP is sent
          'message': 'OTP already sent! Please check your email.',
          'rateLimited': true,
          'remainingSeconds': remainingSeconds,
          'note': errorMsg,
        };
      }
      
      // Handle 500 - Server/Email service error
      if (resp.statusCode == 500) {
        final data = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
        return {
          'success': false,
          'message': data['error'] ?? 'Email service unavailable. Please try again later.',
          'serviceError': true,
        };
      }
      
      // Handle other errors
      final error = resp.body.isNotEmpty 
          ? jsonDecode(resp.body)['error'] ?? 'Failed to send OTP' 
          : 'Failed to send OTP';
      throw Exception(error);
    } catch (e) {
      print('❌ Error sending password reset OTP: $e');
      rethrow;
    }
  }

  /// Verify password reset OTP
  /// Returns true if OTP is valid
  /// Throws exception with error message on failure
  static Future<bool> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/api/nurse/verify-password-reset-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['success'] == true;
      }
      
      // Handle error
      final error = resp.body.isNotEmpty 
          ? jsonDecode(resp.body)['error'] ?? 'Invalid OTP' 
          : 'Invalid OTP';
      throw Exception(error);
    } catch (e) {
      print('❌ Error verifying password reset OTP: $e');
      rethrow;
    }
  }

  /// Reset password with verified OTP
  /// Returns true if password reset successfully
  /// Throws exception with error message on failure
  static Future<bool> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_base/api/nurse/reset-password-with-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['success'] == true;
      }
      
      // Handle error
      final error = resp.body.isNotEmpty 
          ? jsonDecode(resp.body)['error'] ?? 'Failed to reset password' 
          : 'Failed to reset password';
      throw Exception(error);
    } catch (e) {
      print('❌ Error resetting password: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PROVIDER PROFILE METHODS
  // ============================================================================

  /// Get provider's own profile data
  /// Requires authentication token
  /// Returns provider data as Map
  static Future<Map<String, dynamic>> getProviderProfile() async {
    try {
      final resp = await http.get(
        Uri.parse('$_base/api/provider/profile'),
        headers: _authHeaders(),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['provider'] ?? {};
      }
      
      if (resp.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      }
      
      final error = resp.body.isNotEmpty 
          ? jsonDecode(resp.body)['error'] ?? 'Failed to load profile' 
          : 'Failed to load profile';
      throw Exception(error);
    } catch (e) {
      print('❌ Error fetching provider profile: $e');
      rethrow;
    }
  }

  /// Update provider's own profile data
  /// Requires authentication token
  /// Only allows updating certain fields (contact info, fees, etc.)
  /// Professional credentials cannot be changed
  static Future<Map<String, dynamic>> updateProviderProfile(Map<String, dynamic> updatedData) async {
    try {
      final resp = await http.put(
        Uri.parse('$_base/api/provider/profile'),
        headers: _authHeaders(),
        body: jsonEncode(updatedData),
      );
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data;
      }
      
      if (resp.statusCode == 401) {
        throw Exception('Unauthorized. Please login again.');
      }
      
      if (resp.statusCode == 400) {
        final error = resp.body.isNotEmpty 
            ? jsonDecode(resp.body)['error'] ?? 'Invalid data' 
            : 'Invalid data';
        throw Exception(error);
      }
      
      final error = resp.body.isNotEmpty 
          ? jsonDecode(resp.body)['error'] ?? 'Failed to update profile' 
          : 'Failed to update profile';
      throw Exception(error);
    } catch (e) {
      print('❌ Error updating provider profile: $e');
      rethrow;
    }
  }
}
