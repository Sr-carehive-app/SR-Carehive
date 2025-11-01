import 'package:flutter/material.dart';
import 'dart:async';
import 'package:care12/screens/nurse/nurse_dashboard_screen.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'appointments_manage_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    // Prevent duplicate submissions
    if (_isLoading) return;

    setState(() => _isLoading = true);
    
    // **TEMPORARY OTP BYPASS FOR GOOGLE PLAY REVIEWERS**
    // Check if credentials match the ENV variables (for Google reviewers)
    final bypassEmail = dotenv.env['NURSE_ADMIN_EMAIL']?.trim() ?? '';
    final bypassPassword = dotenv.env['NURSE_ADMIN_PASSWORD']?.trim() ?? '';
    final enteredEmail = emailController.text.trim();
    final enteredPassword = passwordController.text.trim();
    
    if (bypassEmail.isNotEmpty && 
        bypassPassword.isNotEmpty &&
        enteredEmail.toLowerCase() == bypassEmail.toLowerCase() && 
        enteredPassword == bypassPassword) {
      // Direct login without OTP for Google reviewers
      print('🔓 OTP BYPASS: Google reviewer detected, logging in directly...');
      
      final ok = await NurseApiService.login(
        email: enteredEmail,
        password: enteredPassword,
      );
      
      if (ok) {
        // Bypass OTP verification completely - navigate directly to dashboard
        if (!mounted) return;
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Login successful! (OTP bypassed for reviewer access)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Small delay for user to see the success message
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NurseAppointmentsManageScreen()),
        );
        return;
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed! Please check credentials')),
        );
        return;
      }
    }
    
    // **NORMAL FLOW FOR ALL OTHER USERS**
    final ok = await NurseApiService.login(
      email: enteredEmail,
      password: enteredPassword,
    );
    setState(() => _isLoading = false);
    
    if (ok) {
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
        } catch (e) {
          // Handle rate limiting error
          if (e.toString().contains('429') || e.toString().contains('wait')) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Too many requests. Please wait 2 minutes before trying again.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed! Please check credentials')),
      );
    }
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
          'Hello Healthcare Provider!',
          style: TextStyle(
            fontSize: 28,
            color: Color(0xFF2260FF),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Welcome to Serechi by SR CareHive',
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NurseAppointmentsManageScreen()),
      );
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
