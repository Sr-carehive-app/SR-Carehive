import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // Prefer explicit API base from environment (set API_BASE_URL),
  // otherwise default to the current app origin (works well for web dev) or fall back to historical srcarehive.com.
  static String get baseUrl {
    final env = dotenv.env['API_BASE_URL']?.trim();
    if (env != null && env.isNotEmpty) return env;
    try {
      return Uri.base.origin; // runtime origin (http://localhost:5173 for local web)
    } catch (_) {
      return 'https://www.srcarehive.com';
    }
  }

  /// Register user (already sends JSON, keep as-is)
  static Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    int? age,
  }) async {
    try {
      print('➡️ Sending registration request to $baseUrl/signup.php');
      final response = await http.post(
        Uri.parse('$baseUrl/signup.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': name,
          'password': password,
          'email': email,
          'mobile_number': phone,
          // send 'age' instead of legacy 'date_of_birth'
          if (age != null) 'age': age,
        }),
      );
      print('✅ Registration response status: ${response.statusCode}');
      print('📦 Registration response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      } else {
        print('⚠️ Unexpected status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Register error: $e');
      return false;
    }
  }

  /// Login user (now sending JSON)
  static Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('➡️ Sending login request to $baseUrl/login.php');
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      print('✅ Login response status: ${response.statusCode}');
      print('📦 Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('✅ Server success: ${json['success']}, message: ${json['message']}');

        return {
          'success': json['success'] == true,
          'name': json['name'] ?? json['full_name'] ?? json['user']?['name'] ?? '',

        };
      } else {
        return {'success': false, 'name': ''};
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {'success': false, 'name': ''};
    }
  }
  /// Login healthcare provider
  static Future<Map<String, dynamic>> loginNurse({
    required String email,
    required String password,
  }) async {
    try {
      print('➡️ Sending login request to $baseUrl/login.php');
      final response = await http.post(
        Uri.parse('$baseUrl/nurselogin.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      print('✅ Login response status: ${response.statusCode}');
      print('📦 Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('✅ Server success: ${json['success']}, message: ${json['message']}');

        return {
          'success': json['success'] == true,
          'name': json['name'] ?? json['full_name'] ?? json['user']?['name'] ?? '',

        };
      } else {
        return {'success': false, 'name': ''};
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {'success': false, 'name': ''};
    }
  }
}
