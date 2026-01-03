import 'package:flutter/material.dart';
import 'package:care12/screens/patient/patient_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Provider;
import 'patient_signup_screen.dart';
import 'forgot_password_otp_screen.dart';
import 'login_otp_verification_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:care12/widgets/google_logo_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'package:intl/intl.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({Key? key}) : super(key: key);

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;
  
  // Animation controller for Google button gradient border
  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize gradient animation for Google button
    _gradientController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(); // Infinite loop
    
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_gradientController);
  }

  @override
  void dispose() {
    _gradientController.dispose(); // Dispose animation controller
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email/phone and password')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();
      
      print('🔐 Sending login OTP request for: $email');
      
      // Step 1: Validate credentials and send OTP
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/send-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = json.decode(response.body);
      print('Response: $data');

      if (!mounted) return;
      
      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Login OTP sent successfully!');
        
        final deliveryChannels = data['deliveryChannels'] as List?;
        final loginType = data['loginType'] ?? 'email';
        
        String message = 'OTP sent!';
        if (deliveryChannels != null && deliveryChannels.isNotEmpty) {
          if (loginType == 'phone') {
            message = 'OTP sent to your phone via SMS!';
          } else if (deliveryChannels.contains('SMS') && deliveryChannels.contains('email')) {
            message = 'OTP sent to your email and phone!';
          } else if (deliveryChannels.contains('email')) {
            message = 'OTP sent to your email!';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $message Check and verify.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Step 2: Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LoginOTPVerificationScreen(
              email: email,
              password: password,
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        // Invalid credentials
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${data['error'] ?? 'Invalid email/phone or password'}'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (response.statusCode == 429) {
        // Rate limited
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏳ ${data['error'] ?? 'Please wait before trying again'}'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${data['error'] ?? 'Failed to send OTP'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Login error: $e');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Network error. Please check your connection.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final supabase = Supabase.instance.client;
    try {
      // For web, use localhost callback for development
      final redirect = kIsWeb
          ? '${Uri.base.origin}/auth/v1/callback'
          : 'carehive://login-callback';

      print('🔐 Starting Google OAuth with redirect: $redirect');
      
      // Don't clear localStorage - Supabase needs to store PKCE parameters
      if (kIsWeb) {
        print('🔐 Starting OAuth with existing localStorage state');
      }
      
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirect,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // The OAuth callback will be handled in main.dart
    } on AuthException catch (e) {
      print('❌ AuthException during Google sign-in: ${e.message}');
      if (!mounted) return;
      
      String userMessage = 'Google sign-in failed. Please try again.';
      final errorMsg = e.message.toLowerCase();
      if (errorMsg.contains('popup') || errorMsg.contains('closed')) {
        userMessage = 'Sign-in was cancelled. Please try again.';
      } else if (errorMsg.contains('network')) {
        userMessage = 'Network error. Please check your internet connection.';
      } else if (errorMsg.contains('account') && errorMsg.contains('exist')) {
        userMessage = 'No account found. Please sign up first.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Error during Google sign-in: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailOrPhoneController = TextEditingController();
    bool isLoading = false;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Forgot Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: emailOrPhoneController,
                  keyboardType: TextInputType.text,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: true,
                  decoration: const InputDecoration(
                    labelText: 'Email Address or Phone Number',
                    hintText: 'Enter your email or phone',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'We\'ll send a 6-digit OTP to your email.\nIf phone is provided and registered, SMS will also be sent.',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final input = emailOrPhoneController.text.trim();
                      
                      if (input.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your email address or phone number')),
                        );
                        return;
                      }
                      
                      // Detect if input is a phone number (10 digits)
                      final isPhoneNumber = RegExp(r'^\d{10}$').hasMatch(input);
                      
                      // Validate format
                      if (!isPhoneNumber) {
                        // Validate email format
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a valid email address or 10-digit phone number')),
                          );
                          return;
                        }
                      }
                      
                      setState(() => isLoading = true);
                      
                      try {
                        print('📧 Sending OTP to: $input');
                        print('🌐 Using API: ${ApiConfig.sendPasswordResetOtp}');
                        
                        // Call backend to send OTP via email (and SMS if phone provided)
                        final requestBody = {'email': input};  // Backend now handles both
                        
                        final response = await http.post(
                          Uri.parse(ApiConfig.sendPasswordResetOtp),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode(requestBody),
                        );

                        final data = json.decode(response.body);
                        print('Response: $data');

                        if (!mounted) return;
                        
                        // ✅ CHECK IF USER IS OAUTH USER (Google Sign-In)
                        if (response.statusCode == 400 && data['isOAuthUser'] == true) {
                          print('🔵 OAuth user detected: ${data['provider']}');
                          
                          Navigator.pop(context); // Close forgot password dialog
                          
                          // Show OAuth user dialog
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
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
                                    '${data['error'] ?? 'This account uses Google Sign-In.'}',
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
                                            data['suggestion'] ?? 'Tap "Continue with Google" button below to login instantly without password.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (data['helpText'] != null) ...[
                                    SizedBox(height: 12),
                                    Text(
                                      data['helpText'],
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
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text('Got it', style: TextStyle(fontSize: 16)),
                                ),
                              ],
                            ),
                          );
                          
                          return;
                        }
                        
                        if (response.statusCode == 200 && data['success'] == true) {
                          print('✅ OTP sent successfully!');
                          
                          final deliveryChannels = data['deliveryChannels'] as List?;
                          final emailForNavigation = data['email'] ?? input;  // Use email from response or original input
                          
                          String successMsg = '✅ OTP sent!';
                          if (deliveryChannels != null && deliveryChannels.contains('SMS')) {
                            successMsg = '✅ OTP sent to your email and phone. Check your messages.';
                          } else {
                            successMsg = '✅ OTP sent to your email. Check your inbox and spam folder.';
                          }
                          
                          Navigator.pop(context); // Close dialog
                          
                          // Navigate to OTP screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ForgotPasswordOTPScreen(email: emailForNavigation),
                            ),
                          );
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(successMsg),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        } else {
                          print('❌ Failed to send OTP: ${data['error']}');
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ ${data['error'] ?? 'Failed to send OTP'}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        print('❌ Error: $e');
                        
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ Network error. Please check your connection.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => isLoading = false);
                        }
                      }
                    },
              child: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send OTP'),
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
        leading: const BackButton(color: Colors.white),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
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
              'Login below to continue',
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFF2260FF),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Email or Phone Number',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Enter registered email or primary phone (Aadhar-linked) you have registered with',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: true,
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
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: true,
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFF2260FF))),
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            // Google Sign-In with animated gradient border
            AnimatedBuilder(
              animation: _gradientAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: SweepGradient(
                      colors: const [
                        Color(0xFF4285F4), // Google Blue
                        Color(0xFF34A853), // Google Green
                        Color(0xFFFBBC04), // Google Yellow
                        Color(0xFFEA4335), // Google Red
                        Color(0xFF4285F4), // Back to Blue for smooth loop
                      ],
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      transform: GradientRotation(_gradientAnimation.value * 2 * 3.14159), // 360 degree rotation
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2), // Border width
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _handleGoogleSignIn,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              GoogleLogoWidget(size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Login with Google',
                                style: TextStyle(
                                  color: Color(0xFF3C4043),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientSignUpScreen()),
                ),
                child: const Text(
                  "or\nDon't have an account? Sign Up",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF2260FF), fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
