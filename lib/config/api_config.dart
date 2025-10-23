import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Centralized API Configuration
/// Automatically handles localhost for web and production URL for mobile
class ApiConfig {
  /// Get the base API URL based on platform and environment
  static String get baseUrl {
    // Check if we have an API_BASE_URL in .env file
    final envUrl = dotenv.env['API_BASE_URL'];
    
    // If running on web, use production URL by default
    if (kIsWeb) {
      // In web mode, use production URL unless explicitly set to localhost
      return envUrl ?? 'https://api.srcarehive.com';
    }
    
    // For mobile devices, ALWAYS use the production URL
    // Never use localhost on mobile as it refers to the device itself
    return envUrl ?? 'https://api.srcarehive.com';
  }
  
  /// Password Reset OTP Endpoints
  static String get sendPasswordResetOtp => '$baseUrl/send-password-reset-otp';
  static String get verifyPasswordResetOtp => '$baseUrl/verify-password-reset-otp';
  static String get resetPasswordWithOtp => '$baseUrl/reset-password-with-otp';
  
  /// OTP Endpoints
  static String get sendOtpEmail => '$baseUrl/api/send-otp-email';
  static String get sendOtpSms => '$baseUrl/api/send-otp-sms';
  static String get verifyOtp => '$baseUrl/verify-otp';
  
  /// Payment Endpoints
  static String get createOrder => '$baseUrl/create-order';
  static String get verifyPayment => '$baseUrl/verify-payment';
  static String get cancelOrder => '$baseUrl/cancel-order';
  
  /// Appointment Endpoints
  static String get approveAppointment => '$baseUrl/approve-appointment';
  static String get rejectAppointment => '$baseUrl/reject-appointment';
  static String get completeAppointment => '$baseUrl/complete-appointment';
  
  /// Support Endpoints
  static String get submitIssue => '$baseUrl/api/support/submit-issue';
  
  /// Helper method to log the current configuration
  static void logConfig() {
    print('🌐 API Config:');
    print('   Platform: ${kIsWeb ? "Web" : "Mobile"}');
    print('   Base URL: $baseUrl');
    print('   Environment: ${dotenv.env['API_BASE_URL'] ?? "Not set (using default)"}');
  }
}
