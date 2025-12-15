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
    
    // If already authenticated, try to go to appointments directly
    if (NurseApiService.isAuthenticated) {
      print('✅ Existing nurse session found, checking validity...');
      // We'll let them continue - if token is invalid, they'll get 401 on appointments screen
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

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email and password'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to send OTP: ${e.toString()}'),
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
    final forgotPasswordEmailController = TextEditingController();
    bool isDialogLoading = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your registered email address to receive a password reset OTP.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              TextField(
                controller: forgotPasswordEmailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'your.email@example.com',
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
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF2260FF)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A 6-digit OTP will be sent to your email',
                        style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDialogLoading ? null : () {
                forgotPasswordEmailController.dispose();
                Navigator.pop(dialogContext);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDialogLoading
                  ? null
                  : () async {
                      final email = forgotPasswordEmailController.text.trim();
                      
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your email address'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      // Validate email format
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid email address'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isDialogLoading = true);

                      try {
                        print('📧 Sending password reset OTP to: $email');
                        
                        final result = await NurseApiService.sendPasswordResetOtp(email: email);
                        final message = result['message'] ?? 'OTP sent successfully';
                        
                        print('🔍 Backend response message: "$message"');
                        print('🔍 Message contains "If this email": ${message.contains('If this email')}');
                        
                        setDialogState(() => isDialogLoading = false);
                        
                        if (!mounted) return;
                        
                        // Check if email doesn't exist (generic security message)
                        if (message.contains('If this email')) {
                          // Email doesn't exist - show error and don't navigate
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Email not found. Please check and try again.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 4),
                            ),
                          );
                          return; // Don't close dialog, don't navigate
                        }
                        
                        // Email exists and OTP sent - proceed
                        // Close dialog
                        forgotPasswordEmailController.dispose();
                        Navigator.pop(dialogContext);
                        
                        // Navigate to OTP verification screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NurseForgotPasswordOTPScreen(email: email),
                          ),
                        );
                        
                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ OTP sent successfully! Check your email.'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isDialogLoading = false);
                        
                        if (!mounted) return;
                        
                        String errorMessage = 'Failed to send OTP. Please try again.';
                        
                        // Handle rate limiting error
                        if (e.toString().contains('429') || e.toString().contains('wait')) {
                          errorMessage = 'Too many requests. Please wait 2 minutes before trying again.';
                        } else if (e.toString().contains('Exception:')) {
                          errorMessage = e.toString().replaceFirst('Exception: ', '');
                        }
                        
                        print('❌ Error sending password reset OTP: $e');
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.white,
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
        const Text('Email', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: emailController,
          decoration: InputDecoration(
            hintText: 'example@srcarehive.com',
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
        Text('An OTP has been sent to your email: ${emailController.text.trim()}',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resend OTP: $e')),
        );
      }
    } finally {
      setState(() {
        _isOtpLoading = false;
      });
    }
  }
}
