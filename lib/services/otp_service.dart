import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OTPService {
  static String? _currentOTP;
  static DateTime? _otpGeneratedTime;
  static const int OTP_VALIDITY_MINUTES = 2;

  // Generate 6-digit OTP (for backward compatibility only)
  static String generateOTP() {
    final random = Random();
    _currentOTP = (100000 + random.nextInt(900000)).toString();
    _otpGeneratedTime = DateTime.now();
    return _currentOTP!;
  }

  // Verify OTP (for backward compatibility only - not recommended for new code)
  static bool verifyOTP(String enteredOTP) {
    if (_currentOTP == null || _otpGeneratedTime == null) {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(_otpGeneratedTime!);

    // Check if OTP is expired (2 minutes)
    if (difference.inMinutes >= OTP_VALIDITY_MINUTES) {
      return false;
    }

    return enteredOTP == _currentOTP;
  }

  // Check if OTP is expired
  static bool isOTPExpired() {
    if (_otpGeneratedTime == null) return true;
    final now = DateTime.now();
    final difference = now.difference(_otpGeneratedTime!);
    return difference.inMinutes >= OTP_VALIDITY_MINUTES;
  }

  // Get remaining time in seconds
  static int getRemainingSeconds() {
    if (_otpGeneratedTime == null) return 0;
    final now = DateTime.now();
    final difference = now.difference(_otpGeneratedTime!);
    final remainingSeconds = (OTP_VALIDITY_MINUTES * 60) - difference.inSeconds;
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }

  // ============================================================================
  // NEW: Backend-Based OTP with Redis Storage and Multi-Channel Delivery
  // ============================================================================

  /// Send signup OTP via backend (supports email, phone, and alternative phone)
  /// At least one contact method must be provided
  /// Returns a map with delivery status and channels
  static Future<Map<String, dynamic>> sendSignupOTP({
    String? email,
    String? phone,
    String? alternativePhone,
    String? name,
  }) async {
    try {
      // Validate: at least one contact method required
      if ((email == null || email.isEmpty) && 
          (phone == null || phone.isEmpty) && 
          (alternativePhone == null || alternativePhone.isEmpty)) {
        return {
          'success': false,
          'error': 'At least one contact method (email, phone, or alternative phone) is required',
          'deliveryChannels': <String>[],
        };
      }

      final apiUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      
      // Build request body with only provided fields
      final Map<String, dynamic> requestBody = {};
      if (email != null && email.isNotEmpty) requestBody['email'] = email;
      if (phone != null && phone.isNotEmpty) requestBody['aadharLinkedPhone'] = phone;  // Backend expects 'aadharLinkedPhone'
      if (alternativePhone != null && alternativePhone.isNotEmpty) {
        requestBody['alternativePhone'] = alternativePhone;
      }
      if (name != null && name.isNotEmpty) requestBody['name'] = name;

      print('[OTP-SERVICE] 📤 Sending signup OTP request...');
      print('[OTP-SERVICE] 📧 Email: ${email ?? "Not provided"}');
      print('[OTP-SERVICE] 📱 Phone: ${phone ?? "Not provided"}');
      print('[OTP-SERVICE] 📱 Alt Phone: ${alternativePhone ?? "Not provided"}');
      print('[OTP-SERVICE] 📦 Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$apiUrl/api/send-signup-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('[OTP-SERVICE] Response status: ${response.statusCode}');
      print('[OTP-SERVICE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'OTP sent successfully',
          'deliveryChannels': List<String>.from(data['deliveryChannels'] ?? []),
          'expiresIn': data['expiresIn'] ?? 120,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Failed to send OTP',
          'deliveryChannels': <String>[],
        };
      }
    } catch (e) {
      print('[OTP-SERVICE] ❌ Error sending signup OTP: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
        'deliveryChannels': <String>[],
      };
    }
  }

  /// Verify signup OTP via backend
  static Future<Map<String, dynamic>> verifySignupOTP({
    String? email,
    String? phone,
    String? alternativePhone,
    required String otp,
  }) async {
    try {
      if (otp.isEmpty) {
        return {
          'success': false,
          'error': 'OTP is required',
        };
      }

      final apiUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      
      // Build request body with identifiers and OTP
      final Map<String, dynamic> requestBody = {'otp': otp};
      if (email != null && email.isNotEmpty) requestBody['email'] = email;
      if (phone != null && phone.isNotEmpty) requestBody['aadharLinkedPhone'] = phone;  // Backend expects 'aadharLinkedPhone'
      if (alternativePhone != null && alternativePhone.isNotEmpty) {
        requestBody['alternativePhone'] = alternativePhone;
      }

      print('[OTP-SERVICE] 🔍 Verifying signup OTP...');
      print('[OTP-SERVICE] Request body: ${jsonEncode(requestBody)}');
      print('[OTP-SERVICE] API URL: $apiUrl/api/verify-signup-otp');

      final response = await http.post(
        Uri.parse('$apiUrl/api/verify-signup-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('[OTP-SERVICE] Verify response: ${response.statusCode}');
      print('[OTP-SERVICE] Verify response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'OTP verified successfully',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['error'] ?? 'Failed to verify OTP',
          'attemptsRemaining': errorData['attemptsRemaining'],
        };
      }
    } catch (e) {
      print('[OTP-SERVICE] ❌ Error verifying signup OTP: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  // ============================================================================
  // OLD METHODS (DEPRECATED - Kept for backward compatibility)
  // These use client-side OTP generation which is insecure
  // ============================================================================

  // Send OTP via Twilio SMS (DEPRECATED)
  static Future<bool> sendOTPViaSMS(String phoneNumber, String otp) async {
    try {
      final accountSid = dotenv.env['TWILIO_ACCOUNT_SID'];
      final authToken = dotenv.env['TWILIO_AUTH_TOKEN'];
      final twilioNumber = dotenv.env['TWILIO_PHONE_NUMBER'];

      if (accountSid == null || authToken == null || twilioNumber == null) {
        print('Twilio credentials not configured');
        return false;
      }

      final url = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

      final response = await http.post(
        url,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
        },
        body: {
          'From': twilioNumber,
          'To': phoneNumber,
          'Body': 'Your Serechi verification code is: $otp. Valid for 2 minutes.',
        },
      );

      print('Twilio SMS Response: ${response.statusCode}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  // Send OTP via Email (DEPRECATED - uses old endpoint)
  static Future<bool> sendOTPViaEmail(String email, String otp) async {
    try {
      final apiUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      final response = await http.post(
        Uri.parse('$apiUrl/api/send-otp-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      print('Email OTP Response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  // Send OTP to both phone and email (DEPRECATED - insecure client-side OTP)
  static Future<Map<String, bool>> sendOTP(
      String phoneNumber, String email) async {
    final otp = generateOTP();
    print('Generated OTP: $otp'); // For development/testing

    final smsResult = await sendOTPViaSMS(phoneNumber, otp);
    final emailResult = await sendOTPViaEmail(email, otp);

    return {
      'sms': smsResult,
      'email': emailResult,
    };
  }
}
