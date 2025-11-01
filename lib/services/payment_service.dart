import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mobile_razorpay_helper.dart'
  if (dart.library.html) 'web_razorpay_helper.dart';

class PaymentService {
  static String get _base => dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
  // Allows routing payment calls to production while keeping the rest on localhost during dev
  static String get _paymentBase => (dotenv.env['PAYMENT_API_BASE_URL'] ?? '').trim().isNotEmpty
      ? (dotenv.env['PAYMENT_API_BASE_URL']!.trim())
      : _base;

  // Payment stages
  static const String REGISTRATION = 'registration';
  static const String PRE_VISIT = 'pre_visit';
  static const String FINAL_PAYMENT = 'final_payment';
  
  // Fixed registration amount - Production value
  static const double REGISTRATION_AMOUNT = 10.0;  // Registration fee: ₹10

  // High-level API: create Razorpay order, open checkout, verify signature.
  static Future<Map<String, dynamic>> payWithRazorpay({
    required String amount, // in rupees, e.g., '199.00'
    required String email,
    required String mobile,
    required String name,
    Map<String, dynamic>? appointment,
    String? description,
  }) async {
    // 1) Create order on server
  final createUri = Uri.parse('$_paymentBase/api/pg/razorpay/create-order');
    final createResp = await http.post(
      createUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'appointment': appointment,
        'notes': {'mobile': mobile, 'email': email, 'name': name},
      }),
    );
    if (createResp.statusCode != 200) {
      throw Exception('create-order failed: ${createResp.statusCode} ${createResp.body}');
    }
    final createJson = jsonDecode(createResp.body) as Map<String, dynamic>;
    final orderId = createJson['orderId'] as String;
    
    // SECURITY NOTE: keyId is Razorpay's public key (like Stripe's publishable key)
    // It's required by Razorpay SDK to initialize payment checkout and is safe to expose
    // The actual secret key (key_secret) remains secure on the backend and is NEVER exposed
    // Backend enforces security through: rate limiting, origin validation, and signature verification
    final keyId = (createJson['keyId'] ?? createJson['key_id'] ?? createJson['key']) as String;
    if (keyId.isEmpty) {
      throw Exception('create-order returned empty keyId');
    }
    final amountPaise = (createJson['amount'] as num).toInt();

    final options = {
      // Provide all common aliases to be safe for web bridge
      'key': keyId,
      'key_id': keyId,
      'keyId': keyId,
      'amount': amountPaise, // in paise
      'currency': 'INR',
      'name': name,
      'description': description ?? 'Payment',
      'order_id': orderId,
      'prefill': {'contact': mobile, 'email': email, 'name': name},
      'theme': {'color': '#3F51B5'},
    };

    // Use platform-specific implementation (web uses Checkout.js, mobile uses plugin)
  final resp = await PlatformRazorpay.open(options);
    final verifyUri = Uri.parse('$_paymentBase/api/pg/razorpay/verify');
    final verifyResp = await http.post(
      verifyUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(resp),
    );
    if (verifyResp.statusCode == 200) {
      return jsonDecode(verifyResp.body) as Map<String, dynamic>;
    }
    // Surface useful context
    final body = verifyResp.body;
    throw Exception('verify failed: ${verifyResp.statusCode} ${body.isNotEmpty ? body : ''}');
  }

  /// Pay Registration Fee (₹10)
  static Future<Map<String, dynamic>> payRegistrationFee({
    required String appointmentId,  // Changed from int to String (UUID)
    required String email,
    required String mobile,
    required String name,
  }) async {
    final result = await payWithRazorpay(
      amount: REGISTRATION_AMOUNT.toStringAsFixed(2),
      email: email,
      mobile: mobile,
      name: name,
      description: 'Registration Fee - Appointment #$appointmentId',
      appointment: {
        'id': appointmentId,
        'payment_stage': REGISTRATION,
      },
    );

    // Update appointment with registration payment details
    // Extract payment ID safely with fallbacks
    final paymentId = result['razorpay_payment_id']?.toString() ?? 
                     result['payment_id']?.toString() ?? 
                     result['paymentId']?.toString() ?? 
                     '';
    final receiptId = result['receipt']?.toString() ?? 
                     result['razorpay_order_id']?.toString() ?? 
                     result['order_id']?.toString() ?? 
                     '';
    
    await _updateRegistrationPayment(
      appointmentId: appointmentId,
      paymentId: paymentId,
      receiptId: receiptId,
    );

    return result;
  }

  /// Pay Pre-Visit Amount (50% of total)
  static Future<Map<String, dynamic>> payPreVisitAmount({
    required String appointmentId,  // Changed from int to String (UUID)
    required double totalAmount,
    required String email,
    required String mobile,
    required String name,
  }) async {
    final preAmount = totalAmount / 2;
    final result = await payWithRazorpay(
      amount: preAmount.toStringAsFixed(2),
      email: email,
      mobile: mobile,
      name: name,
      description: 'Pre-Visit Charges - Appointment #$appointmentId',
      appointment: {
        'id': appointmentId,
        'payment_stage': PRE_VISIT,
        'total_amount': totalAmount,
      },
    );

    // Update appointment with pre-payment details
    // Extract payment ID safely with fallbacks
    final paymentId = result['razorpay_payment_id']?.toString() ?? 
                     result['payment_id']?.toString() ?? 
                     result['paymentId']?.toString() ?? 
                     '';
    final receiptId = result['receipt']?.toString() ?? 
                     result['razorpay_order_id']?.toString() ?? 
                     result['order_id']?.toString() ?? 
                     '';
    
    await _updatePrePayment(
      appointmentId: appointmentId,
      paymentId: paymentId,
      receiptId: receiptId,
    );

    return result;
  }

  /// Pay Final Amount (remaining 50%)
  /// Pay Final Amount (remaining 50%)
  static Future<Map<String, dynamic>> payFinalAmount({
    required String appointmentId,  // Changed from int to String (UUID)
    required double totalAmount,
    required String email,
    required String mobile,
    required String name,
  }) async {
    final finalAmount = totalAmount / 2;
    final result = await payWithRazorpay(
      amount: finalAmount.toStringAsFixed(2),
      email: email,
      mobile: mobile,
      name: name,
      description: 'Final Charges - Appointment #$appointmentId',
      appointment: {
        'id': appointmentId,
        'payment_stage': FINAL_PAYMENT,
        'total_amount': totalAmount,
      },
    );

    // Update appointment with final payment details
    // Extract payment ID safely with fallbacks
    final paymentId = result['razorpay_payment_id']?.toString() ?? 
                     result['payment_id']?.toString() ?? 
                     result['paymentId']?.toString() ?? 
                     '';
    final receiptId = result['receipt']?.toString() ?? 
                     result['razorpay_order_id']?.toString() ?? 
                     result['order_id']?.toString() ?? 
                     '';
    
    await _updateFinalPayment(
      appointmentId: appointmentId,
      paymentId: paymentId,
      receiptId: receiptId,
    );

    return result;
  }

  // Private helper methods to update Supabase
  static Future<void> _updateRegistrationPayment({
    required String appointmentId,  // Changed from int to String (UUID)
    required String paymentId,
    required String receiptId,
  }) async {
    final supabase = Supabase.instance.client;
    
    // Update appointment
    await supabase.from('appointments').update({
      'registration_payment_id': paymentId,
      'registration_receipt_id': receiptId,
      'registration_paid': true,
      'registration_paid_at': DateTime.now().toIso8601String(),
      'status': 'booked', // Change status to booked
    }).eq('id', appointmentId);
    
    // Send email & SMS notifications
    try {
      // Fetch appointment details for notification
      final response = await supabase
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .single();
      
      final notifyUri = Uri.parse('$_paymentBase/api/notify-registration-payment');
      print('[INFO] Sending registration notification to: $notifyUri');
      print('[INFO] Notification data: appointmentId=$appointmentId, patientEmail=${response['patient_email']}');
      
      final notifyResponse = await http.post(
        notifyUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appointmentId': appointmentId,
          'patientEmail': response['patient_email'],
          'patientName': response['full_name'],
          'patientPhone': response['phone'],
          'nurseEmail': response['nurse_email'], // May be null
          'nurseName': response['nurse_name'], // May be null
          'paymentId': paymentId,
          'receiptId': receiptId,
          'amount': REGISTRATION_AMOUNT,
          'date': response['date'],
          'time': response['time'],
        }),
      );
      
      if (notifyResponse.statusCode == 200) {
        print('[SUCCESS] ✅ Registration payment notification sent successfully!');
      } else {
        print('[ERROR] ❌ Notification failed with status ${notifyResponse.statusCode}: ${notifyResponse.body}');
      }
    } catch (e) {
      print('[ERROR] Failed to send registration notification: $e');
      // Don't throw - payment is successful even if notification fails
    }
  }

  static Future<void> _updatePrePayment({
    required String appointmentId,  // Changed from int to String (UUID)
    required String paymentId,
    required String receiptId,
  }) async {
    final supabase = Supabase.instance.client;
    
    // Update appointment
    await supabase.from('appointments').update({
      'pre_payment_id': paymentId,
      'pre_receipt_id': receiptId,
      'pre_paid': true,
      'pre_paid_at': DateTime.now().toIso8601String(),
      'status': 'pre_paid', // Change status to pre_paid
    }).eq('id', appointmentId);
    
    // Send email & SMS notifications
    try {
      final response = await supabase
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .single();
      
      final totalAmount = (response['total_amount'] as num?)?.toDouble() ?? 0;
      final preAmount = totalAmount / 2;
      
      final notifyUri = Uri.parse('$_paymentBase/api/notify-pre-payment');
      print('[INFO] Sending pre-payment notification to: $notifyUri');
      print('[INFO] Pre-payment data: appointmentId=$appointmentId, amount=$preAmount');
      
      final notifyResponse = await http.post(
        notifyUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appointmentId': appointmentId,
          'patientEmail': response['patient_email'],
          'patientName': response['full_name'],
          'patientPhone': response['phone'],
          'nurseEmail': response['nurse_email'],
          'nurseName': response['nurse_name'],
          'amount': preAmount,
          'paymentId': paymentId,
          'receiptId': receiptId,
          'totalAmount': totalAmount,
          'date': response['date'],
          'time': response['time'],
        }),
      );
      
      if (notifyResponse.statusCode == 200) {
        print('[SUCCESS] ✅ Pre-payment notification sent successfully!');
      } else {
        print('[ERROR] ❌ Pre-payment notification failed with status ${notifyResponse.statusCode}: ${notifyResponse.body}');
      }
    } catch (e) {
      print('[ERROR] Failed to send pre-payment notification: $e');
    }
  }

  static Future<void> _updateFinalPayment({
    required String appointmentId,  // Changed from int to String (UUID)
    required String paymentId,
    required String receiptId,
  }) async {
    final supabase = Supabase.instance.client;
    
    // Update appointment
    await supabase.from('appointments').update({
      'final_payment_id': paymentId,
      'final_receipt_id': receiptId,
      'final_paid': true,
      'final_paid_at': DateTime.now().toIso8601String(),
      'status': 'completed', // Change status to completed
    }).eq('id', appointmentId);
    
    // Send email & SMS notifications
    try {
      final response = await supabase
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .single();
      
      final totalAmount = (response['total_amount'] as num?)?.toDouble() ?? 0;
      final finalAmount = totalAmount / 2;
      final totalPaid = REGISTRATION_AMOUNT + totalAmount;
      
      final notifyUri = Uri.parse('$_paymentBase/api/notify-final-payment');
      print('[INFO] Sending final payment notification to: $notifyUri');
      print('[INFO] Final payment data: appointmentId=$appointmentId, amount=$finalAmount, totalPaid=$totalPaid');
      
      final notifyResponse = await http.post(
        notifyUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appointmentId': appointmentId,
          'patientEmail': response['patient_email'],
          'patientName': response['full_name'],
          'patientPhone': response['phone'],
          'nurseEmail': response['nurse_email'],
          'nurseName': response['nurse_name'],
          'amount': finalAmount,
          'paymentId': paymentId,
          'receiptId': receiptId,
          'totalPaid': totalPaid,
          'date': response['date'],
          'time': response['time'],
        }),
      );
      
      if (notifyResponse.statusCode == 200) {
        print('[SUCCESS] ✅ Final payment notification sent successfully!');
      } else {
        print('[ERROR] ❌ Final payment notification failed with status ${notifyResponse.statusCode}: ${notifyResponse.body}');
      }
    } catch (e) {
      print('[ERROR] Failed to send final payment notification: $e');
    }
  }
}
