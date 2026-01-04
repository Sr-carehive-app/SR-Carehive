import 'package:flutter/material.dart';
import 'dart:async';
import 'package:care12/screens/nurse/nurse_dashboard_screen.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'package:care12/screens/nurse/provider_application_status_screen.dart';
import 'package:care12/screens/nurse/admin_dashboard_selection_screen.dart';
import 'appointments_manage_screen.dart';
import 'nurse_forgot_password_otp_screen.dart';

class NurseLoginScreen extends StatefulWidget {
  const NurseLoginScreen({Key? key}) : super(key: key);

  @override
  State<NurseLoginScreen> createState() => _NurseLoginScreenState();
}

class _NurseLoginScreenState extends State<NurseLoginScreen> {
  bool _showOtpScreen = false;
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpLoading = false;
  String? _otpError;
  int _resendCooldown = 0;
  Timer? _resendTimer;
  bool _otpSent = false; // Flag to prevent duplicate OTP sends
  bool _isSuperAdmin = false; // Track if logged in as super admin

  @override
  void initState() {
    super.initState();
    _checkExistingAuth();
  }

  Future<void> _checkExistingAuth() async {
    // Load token from storage
    await NurseApiService.init();
    
    // If already authenticated, validate token with backend
    if (NurseApiService.isAuthenticated) {
      print('✅ Existing nurse session found, validating token...');
      
      try {
        // Try to fetch appointments - this validates the token
        final appointments = await NurseApiService.listAppointments();
        
        // Token is valid - auto-login to appointments page
        print('✅ Token valid - Auto-login successful');
        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const NurseAppointmentsManageScreen(isSuperAdmin: false),
          ),
        );
      } catch (e) {
        // Token invalid or expired - clear it and show login screen
        print('❌ Token validation failed: $e');
        await NurseApiService.logout();
        print('🔄 Cleared invalid token - Please login again');
      }
    }
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 120);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Helper method to check if input is a phone number (10 digits)
  bool _isPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 10 && RegExp(r'^\d{10}$').hasMatch(cleaned);
  }

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email/phone number and password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Prevent duplicate submissions
    if (_isLoading) return;

    setState(() => _isLoading = true);
    
    final enteredEmail = emailController.text.trim();
    final enteredPassword = passwordController.text.trim();
    
    print('🔐 Attempting login...');
    
    // Login with status check
    final result = await NurseApiService.login(
      email: enteredEmail,
      password: enteredPassword,
    );
    
    setState(() => _isLoading = false);
    
    if (!mounted) return;
    
    print('📋 Login completed');
    
    // Check if application was rejected
    if (result['rejected'] == true) {
      print('❌ Navigating to rejection status screen');
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderApplicationStatusScreen(
            providerData: result['providerData'] as Map<String, dynamic>? ?? {},
          ),
        ),
      );
      return;
    }
    
    // Check if application is still pending
    if (result['pending'] == true) {
      print('⏳ Navigating to pending status screen');
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ProviderApplicationStatusScreen(
            providerData: result['providerData'] as Map<String, dynamic>? ?? {},
          ),
        ),
      );
      return;
    }
    
    // Check if login was successful (approved user)
    if (result['success'] == true) {
      print('✅ Login successful - Requesting OTP');
      
      // Store super admin flag
      _isSuperAdmin = result['isSuperAdmin'] == true;
      
      // Request OTP only once
      if (!_otpSent) {
        setState(() {
          _showOtpScreen = true;
          _otpError = null;
          _otpSent = true;
        });
        _startResendCooldown();
        
        try {
          await NurseApiService.sendOtp(email: enteredEmail);
          print('✅ OTP sent successfully');
        } catch (e) {
          print('❌ Failed to send OTP: $e');
          // Handle rate limiting error
          if (e.toString().contains('429') || e.toString().contains('wait')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Too many requests. Please wait 2 minutes before trying again.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          } else {
            String userMessage = 'Failed to send OTP. Please try again.';
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('network') || errorStr.contains('connection')) {
              userMessage = 'Network error. Please check your internet connection.';
            } else if (errorStr.contains('invalid') && errorStr.contains('email')) {
              userMessage = 'Invalid email or phone number format.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } else {
      // Login failed - Show error message from server
      final errorMsg = result['error'] as String? ?? 'Invalid credentials! Email or password is incorrect.';
      print('❌ Login failed: $errorMsg');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    final forgotPasswordController = TextEditingController();
    
    // Dialog returns a map with email and message, or null
    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDialogLoading = false;
        
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: Color(0xFF2260FF)),
              SizedBox(width: 12),
              Text('Forgot Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter your registered email or phone number to receive a password reset OTP.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: forgotPasswordController,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Email Address or Phone Number',
                    hintText: 'your.email@example.com or 10-digit phone',
                    prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF2260FF)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2260FF), width: 2),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Color(0xFF2260FF)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'OTP will be sent to your email.\nIf phone is registered, SMS will also be sent.',
                          style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isDialogLoading ? null : () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton(
              onPressed: isDialogLoading
                  ? null
                  : () async {
                      final input = forgotPasswordController.text.trim();
                      
                      if (input.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your email address or phone number'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Detect if input is a phone number (10 digits)
                      final isPhoneNumber = RegExp(r'^\d{10}$').hasMatch(input);
                      
                      // Validate format
                      if (!isPhoneNumber) {
                        // Validate email format
                        final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(input)) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a valid email address or 10-digit phone number'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                      }

                      setDialogState(() => isDialogLoading = true);

                      try {
                        print('📧 Sending password reset OTP to: $input');
                        
                        final result = await NurseApiService.sendPasswordResetOtp(
                          email: input,
                          phone: null,  // Backend now handles phone detection automatically
                        );
                        final success = result['success'] ?? false;
                        final message = result['message'] ?? 'OTP sent successfully';
                        final notFound = result['notFound'] ?? false;
                        final serviceError = result['serviceError'] ?? false;
                        final isOAuthUser = result['isOAuthUser'] ?? false;
                        final deliveryChannels = result['deliveryChannels'] as List?;
                        final emailForNavigation = result['email'] ?? input;  // Use email from response
                        
                        print('🔍 Backend response success: $success');
                        print('🔍 Backend response message: "$message"');
                        print('🔍 Backend response notFound: $notFound');
                        print('🔍 Backend response serviceError: $serviceError');
                        print('🔍 Backend response isOAuthUser: $isOAuthUser');
                        if (deliveryChannels != null) {
                          print('🔍 Delivery channels: $deliveryChannels');
                        }
                        
                        setDialogState(() => isDialogLoading = false);
                        
                        if (!mounted) return;
                        
                        // ✅ CHECK IF USER IS OAUTH USER (Google Sign-In)
                        if (!success && isOAuthUser) {
                          print('🔵 OAuth provider detected: ${result['provider']}');
                          
                          Navigator.pop(dialogContext); // Close forgot password dialog
                          
                          // Show OAuth user dialog
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.blue, size: 28),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Google Account Detected',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            result['suggestion'] ?? 'Use "Continue with Google" button to login instantly without password.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (result['helpText'] != null) ...[
                                    SizedBox(height: 12),
                                    Text(
                                      result['helpText'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text('Got it', style: TextStyle(fontSize: 16)),
                                ),
                              ],
                            ),
                          );
                          
                          return;
                        }
                        
                        // Check success flag - if false, show specific error
                        if (!success) {
                          String errorMsg = message;
                          
                          // Customize error message based on error type
                          if (notFound) {
                            errorMsg = '❌ This email/phone is not registered as a healthcare provider.\n\nPlease check your information or contact support.';
                          } else if (serviceError) {
                            errorMsg = '❌ Service is temporarily unavailable.\n\nPlease try again in a few minutes.';
                          }
                          
                          if (!mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                          return; // Don't close dialog, don't navigate
                        }
                        
                        // Build success message
                        String successMessage = message;
                        if (deliveryChannels != null && deliveryChannels.contains('SMS')) {
                          successMessage = 'OTP sent to your email and phone!';
                        } else {
                          successMessage = 'OTP sent to your email!';
                        }
                        
                        // Success! Return email and message to show OUTSIDE dialog
                        Navigator.pop(dialogContext, {
                          'email': emailForNavigation,
                          'message': successMessage,
                        });
                      } catch (e) {
                        setDialogState(() => isDialogLoading = false);
                        
                        if (!mounted) return;
                        
                        String errorMessage = 'Failed to send OTP. Please try again.';
                        bool isRateLimitError = false;
                        
                        print('❌ Error sending password reset OTP: $e');
                        
                        // Check if it's a 429 rate limit error
                        if (e.toString().contains('429')) {
                          isRateLimitError = true;
                          
                          // Try to extract time from error message
                          final errorStr = e.toString();
                          if (errorStr.contains('minute')) {
                            errorMessage = '⏳ Please wait before requesting a new OTP.\n\nIf you already received an OTP, please check your email inbox and spam folder.';
                          } else {
                            errorMessage = '⏳ OTP already sent! Please check your email.\n\nWait 2 minutes before requesting a new OTP.';
                          }
                        } else if (e.toString().contains('Exception:')) {
                          errorMessage = e.toString().replaceFirst('Exception: ', '');
                        }
                        
                        if (!mounted) return;
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: isRateLimitError ? Colors.orange : Colors.red,
                            duration: Duration(seconds: isRateLimitError ? 6 : 4),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2260FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isDialogLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('Send OTP'),
            ),
          ],
        ),
      );
      },
    );
    
    // Wait for dialog close animation to complete before disposing controller
    await Future.delayed(const Duration(milliseconds: 300));
    forgotPasswordController.dispose();
    
    // If result was returned, show message and navigate (OUTSIDE dialog)
    if (result != null && mounted) {
      final email = result['email']!;
      final message = result['message']!;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $message'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      
      if (!mounted) return;
      
      // Now navigate - completely safe!
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NurseForgotPasswordOTPScreen(
            email: email,
            deliveryChannels: result['deliveryChannels'] as List<String>?,
            sentTo: result['sentTo'] as List<String>?,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _showOtpScreen ? _buildOtpScreen() : _buildLoginScreen(),
      ),
    );
  }

  Widget _buildLoginScreen() {
    return ListView(
      children: [
        const SizedBox(height: 20),
        const Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: 28,
            color: Color(0xFF2260FF),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Log in below to manage your appointments',
          style: TextStyle(
            fontSize: 20,
            color: Color(0xFF2260FF),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 30),
        const Text('Email or Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Enter registered email or primary phone number you have registered with',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Email or phone number',
            filled: true,
            fillColor: const Color(0xFFEDEFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: passwordController,
          obscureText: _obscureText,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFEDEFFF),
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Forgot Password Link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                color: Color(0xFF2260FF),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2260FF)))
            : ElevatedButton(
          onPressed: _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2260FF),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Log In', style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildOtpScreen() {
    return ListView(
      children: [
        const SizedBox(height: 20),
        const Text(
          'OTP Verification',
          style: TextStyle(
            fontSize: 28,
            color: Color(0xFF2260FF),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(_isPhoneNumber(emailController.text.trim()) 
            ? 'An OTP has been sent to your phone: ${emailController.text.trim()}'
            : 'An OTP has been sent to your email: ${emailController.text.trim()}',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 30),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Enter OTP',
            errorText: _otpError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: const Color(0xFFEDEFFF),
          ),
        ),
        const SizedBox(height: 20),
        _isOtpLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2260FF)))
            : ElevatedButton(
          onPressed: _handleOtpVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2260FF),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text('Verify OTP', style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _resendCooldown > 0 ? null : _handleResendOtp,
          child: Text(_resendCooldown > 0 ? 'Resend OTP in $_resendCooldown s' : 'Resend OTP'),
        ),
      ],
    );
  }

  Future<void> _handleOtpVerify() async {
    setState(() {
      _isOtpLoading = true;
      _otpError = null;
    });
    final result = await NurseApiService.verifyOtp(
      email: emailController.text.trim(),
      otp: _otpController.text.trim(),
    );
    setState(() => _isOtpLoading = false);
    if (result == true) {
      // Navigate based on user type
      if (_isSuperAdmin) {
        // Super admin goes to Admin Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardSelectionScreen()),
        );
      } else {
        // Regular approved provider goes to Appointments Management
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NurseAppointmentsManageScreen(isSuperAdmin: false)),
        );
      }
    } else {
      setState(() => _otpError = result is String ? result : 'Invalid OTP');
    }
  }

  Future<void> _handleResendOtp() async {
    setState(() => _isOtpLoading = true);
    try {
      final ok = await NurseApiService.resendOtp(email: emailController.text.trim());
      _startResendCooldown();
      if (ok == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok is String ? ok.toString() : 'Failed to resend OTP')),
        );
      }
    } catch (e) {
      // Handle rate limiting error
      if (e.toString().contains('429') || e.toString().contains('wait')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait 2 minutes before requesting another OTP.'),
            duration: Duration(seconds: 5),
          ),
        );
      } else {
        // Convert technical errors to user-friendly messages
        String userMessage = 'Failed to resend OTP. Please try again.';
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('network') || errorStr.contains('connection')) {
          userMessage = 'Network error. Please check your internet connection.';
        } else if (errorStr.contains('timeout')) {
          userMessage = 'Request timed out. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isOtpLoading = false;
      });
    }
  }
}
