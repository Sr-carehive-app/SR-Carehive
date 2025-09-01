import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://srcarehive.com'; // change if needed

  /// Register user (already sends JSON, keep as-is)
  static Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String dob,
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
          'date_of_birth': dob,
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
  /// Login Nurse (now sending JSON)
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
