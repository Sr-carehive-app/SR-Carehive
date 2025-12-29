import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Tubelight Communications SMS Service
/// Integration with Jio TrueConnect for template-based SMS delivery
class TubelightSMSService {
  // API Configuration from environment variables
  static String get _apiUrl => 
      dotenv.env['TUBELIGHT_SMS_API_URL'] ?? 
      'https://portal.tubelightcommunications.com/api/mt/SendSMS';
  
  static String get _username => dotenv.env['TUBELIGHT_USERNAME'] ?? '';
  static String get _password => dotenv.env['TUBELIGHT_PASSWORD'] ?? '';
  static String get _senderId => dotenv.env['TUBELIGHT_SENDER_ID'] ?? '';
  static String get _entityId => dotenv.env['TUBELIGHT_ENTITY_ID'] ?? '';

  // Template IDs for different message types
  static String get _otpTemplateId => 
      dotenv.env['TUBELIGHT_OTP_TEMPLATE_ID'] ?? '';

  /// Send OTP SMS using approved Jio TrueConnect template
  /// 
  /// [phoneNumber] - 10 digit mobile number (without country code)
  /// [otp] - 6 digit OTP code
  /// [recipientName] - Name of the recipient (optional, for personalization)
  /// 
  /// Returns true if SMS sent successfully, false otherwise
  static Future<bool> sendOTPSMS({
    required String phoneNumber,
    required String otp,
    String? recipientName,
  }) async {
    try {
      // Validate credentials
      if (_username.isEmpty || _password.isEmpty) {
        print('[TubelightSMS] ❌ SMS credentials not configured');
        return false;
      }

      if (_senderId.isEmpty || _entityId.isEmpty || _otpTemplateId.isEmpty) {
        print('[TubelightSMS] ❌ SMS configuration incomplete');
        return false;
      }

      // Clean phone number (remove spaces, dashes, etc.)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      
      // Ensure 10 digit phone number
      if (cleanPhone.length != 10) {
        print('[TubelightSMS] ❌ Invalid phone number format: $phoneNumber');
        return false;
      }

      // Add country code (91 for India)
      final fullPhoneNumber = '91$cleanPhone';

      // Construct message with template variables
      // Template format: "Dear {#var#}, Your OTP for SR CareHive password reset is {#var#}. Valid for 10 minutes. Do not share this code."
      final name = recipientName ?? 'User';
      final message = 'Dear $name, Your OTP for SR CareHive password reset is $otp. Valid for 10 minutes. Do not share this code.';

      // Prepare API request body
      final requestBody = {
        'username': _username,
        'password': _password,
        'sender': _senderId,
        'mobile': fullPhoneNumber,
        'message': message,
        'templateid': _otpTemplateId,
        'pe_id': _entityId,
        'dltContentId': _otpTemplateId, // Same as templateid for DLT compliance
      };

      print('[TubelightSMS] 📤 Sending OTP SMS to: $fullPhoneNumber');
      print('[TubelightSMS] 📝 Template ID: $_otpTemplateId');

      // Send API request
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('SMS API request timeout');
        },
      );

      print('[TubelightSMS] 📡 Response Status: ${response.statusCode}');
      print('[TubelightSMS] 📡 Response Body: ${response.body}');

      // Check response status
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Check for success in response
        // Tubelight API typically returns status or success field
        final status = responseData['status']?.toString().toLowerCase();
        final success = responseData['success'];
        
        if (status == 'success' || 
            status == 'sent' || 
            success == true ||
            success == 'true') {
          print('[TubelightSMS] ✅ SMS sent successfully');
          return true;
        } else {
          print('[TubelightSMS] ⚠️ SMS API returned non-success status: $status');
          print('[TubelightSMS] Response: ${response.body}');
          return false;
        }
      } else {
        print('[TubelightSMS] ❌ SMS API error: ${response.statusCode}');
        print('[TubelightSMS] Error body: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('[TubelightSMS] ❌ Exception sending SMS: $e');
      print('[TubelightSMS] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Send appointment reminder SMS
  /// (For future implementation when appointment template is configured)
  static Future<bool> sendAppointmentReminderSMS({
    required String phoneNumber,
    required String patientName,
    required String doctorName,
    required String appointmentDate,
    required String appointmentTime,
  }) async {
    // TODO: Implement when appointment template is approved and configured
    print('[TubelightSMS] ⚠️ Appointment reminder SMS not yet configured');
    return false;
  }

  /// Send appointment confirmation SMS
  /// (For future implementation when confirmation template is configured)
  static Future<bool> sendAppointmentConfirmationSMS({
    required String phoneNumber,
    required String patientName,
    required String appointmentId,
    required String doctorName,
    required String appointmentDate,
  }) async {
    // TODO: Implement when confirmation template is approved and configured
    print('[TubelightSMS] ⚠️ Appointment confirmation SMS not yet configured');
    return false;
  }

  /// Send payment success SMS
  /// (For future implementation when payment template is configured)
  static Future<bool> sendPaymentSuccessSMS({
    required String phoneNumber,
    required String patientName,
    required String amount,
    required String transactionId,
  }) async {
    // TODO: Implement when payment template is approved and configured
    print('[TubelightSMS] ⚠️ Payment success SMS not yet configured');
    return false;
  }

  /// Check if SMS service is properly configured
  static bool isConfigured() {
    return _username.isNotEmpty && 
           _password.isNotEmpty && 
           _senderId.isNotEmpty && 
           _entityId.isNotEmpty &&
           _otpTemplateId.isNotEmpty;
  }

  /// Get SMS service status for debugging
  static Map<String, dynamic> getServiceStatus() {
    return {
      'configured': isConfigured(),
      'hasUsername': _username.isNotEmpty,
      'hasPassword': _password.isNotEmpty,
      'hasSenderId': _senderId.isNotEmpty,
      'hasEntityId': _entityId.isNotEmpty,
      'hasOTPTemplate': _otpTemplateId.isNotEmpty,
      'apiUrl': _apiUrl,
    };
  }
}
