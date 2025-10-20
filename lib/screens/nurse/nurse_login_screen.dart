import 'package:flutter/material.dart';
import 'dart:async';
import 'package:care12/screens/nurse/nurse_dashboard_screen.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'appointments_manage_screen.dart';

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

  @override
  void initState() {
    super.initState();
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

    setState(() => _isLoading = true);
    final ok = await NurseApiService.login(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );
    setState(() => _isLoading = false);
    if (ok) {
      // Request OTP
      setState(() {
        _showOtpScreen = true;
        _otpError = null;
      });
      _startResendCooldown();
      await NurseApiService.sendOtp(email: emailController.text.trim());
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
    final ok = await NurseApiService.resendOtp(email: emailController.text.trim());
    setState(() {
      _isOtpLoading = false;
    });
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
  }
}
