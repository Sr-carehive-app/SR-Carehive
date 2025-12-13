import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProviderEmailService {
  /// Sends registration notification email to admin emails
  static Future<bool> sendProviderRegistrationEmail({
    required Map<String, dynamic> providerData,
  }) async {
    try {
      final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      
      final response = await http.post(
        Uri.parse('$apiBase/api/provider/send-registration-notification'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerData': providerData,
          'adminEmails': [
            'srcarehive@gmail.com',
            'ns.srcarehive@gmail.com',
          ],
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ Provider registration email sent to admins successfully');
        return true;
      } else {
        print('❌ Failed to send admin email: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending provider registration email to admins: $e');
      return false;
    }
  }

  /// Sends confirmation email to the user who just registered
  static Future<bool> sendUserConfirmationEmail({
    required String userEmail,
    required String userName,
  }) async {
    try {
      final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      
      final response = await http.post(
        Uri.parse('$apiBase/api/provider/send-user-confirmation'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userEmail': userEmail,
          'userName': userName,
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ Confirmation email sent to user successfully');
        return true;
      } else {
        print('❌ Failed to send user confirmation email: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending user confirmation email: $e');
      return false;
    }
  }

  /// Sends approval email to the provider
  static Future<bool> sendApprovalEmail({
    required String userEmail,
    required String userName,
    required String professionalRole,
  }) async {
    try {
      final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      
      final response = await http.post(
        Uri.parse('$apiBase/api/provider/send-approval-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userEmail': userEmail,
          'userName': userName,
          'professionalRole': professionalRole,
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ Approval email sent to provider successfully');
        return true;
      } else {
        print('❌ Failed to send approval email: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending approval email: $e');
      return false;
    }
  }

  /// Sends rejection email to the provider
  static Future<bool> sendRejectionEmail({
    required String userEmail,
    required String userName,
    String? rejectionReason,
  }) async {
    try {
      final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      
      final response = await http.post(
        Uri.parse('$apiBase/api/provider/send-rejection-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userEmail': userEmail,
          'userName': userName,
          'rejectionReason': rejectionReason,
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ Rejection email sent to provider successfully');
        return true;
      } else {
        print('❌ Failed to send rejection email: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending rejection email: $e');
      return false;
    }
  }
}
