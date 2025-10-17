import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OTPService {
  static String? _currentOTP;
  static DateTime? _otpGeneratedTime;
  static const int OTP_VALIDITY_MINUTES = 2;

  // Generate 6-digit OTP
  static String generateOTP() {
    final random = Random();
    _currentOTP = (100000 + random.nextInt(900000)).toString();
    _otpGeneratedTime = DateTime.now();
    return _currentOTP!;
  }

  // Verify OTP
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

  // Send OTP via Twilio SMS
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
          'Body': 'Your SERECHI verification code is: $otp. Valid for 2 minutes.',
        },
      );

      print('Twilio SMS Response: ${response.statusCode}');
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  // Send OTP via Email (using your backend)
  static Future<bool> sendOTPViaEmail(String email, String otp) async {
    try {
      final apiUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:9090';
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

  // Send OTP to both phone and email
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
