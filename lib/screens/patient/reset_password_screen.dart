import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'patient_login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _tokenExpired = false;
  bool _codeValid = false;
  String? _resetCode;

  @override
  void initState() {
    super.initState();
    _extractCodeFromUrl();
  }

  void _extractCodeFromUrl() {
    if (kIsWeb) {
      final uri = Uri.base;
      _resetCode = uri.queryParameters['code'];
      if (_resetCode != null && _resetCode!.isNotEmpty) {
        setState(() {
          _codeValid = true;
        });
      } else {
        setState(() {
          _errorMessage = 'Reset code missing in URL!';
        });
      }
    } else {
      // For mobile, assume code is valid
      setState(() {
        _codeValid = true;
      });
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    
    // Basic validation
    if (password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Simple password validation - minimum 6 characters
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Password must be at least 6 characters long'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _tokenExpired = false;
    });
    
    final supabase = Supabase.instance.client;
    try {
      print('🔐 Attempting to reset password...');
      print('📧 Current user: ${supabase.auth.currentUser?.email ?? "No user"}');
      
      // Use the correct method for password reset
      final response = await supabase.auth.updateUser(UserAttributes(password: password));
      
      if (response.user != null) {
        print('✅ Password reset successful for user: ${response.user!.email}');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Password reset successfully! Please log in with your new password.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        // Wait a moment for the snackbar to show, then navigate
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          // Navigate back to login screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const PatientLoginScreen()),
            (route) => false,
          );
        }
      } else {
        print('❌ Password reset failed - no user returned');
        setState(() {
          _errorMessage = 'Failed to reset password';
        });
      }
    } on AuthException catch (e) {
      print('❌ AuthException during password reset: ${e.message}');
      
      if (e.message.toLowerCase().contains('expired') || 
          e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('code')) {
        print('⏰ Reset link expired or invalid');
        setState(() {
          _tokenExpired = true;
          _errorMessage = 'Reset link expired or invalid. Please request a new password reset email.';
        });
      } else {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      print('❌ Unexpected error during password reset: ${e.toString()}');
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _requestNewResetEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    try {
      // Get the base URL from environment or use localhost
      String baseUrl = kIsWeb 
          ? Uri.base.origin 
          : 'carehive://';
      
      String redirectUrl = kIsWeb
          ? '$baseUrl/reset-password'
          : 'carehive://reset-password';
      
      print('Re-sending password reset email to: $email');
      print('📍 Redirect URL: $redirectUrl');
      print('🌐 Base URL: $baseUrl');
      
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
      
      print('✅ Password reset email sent successfully via Supabase!');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Password reset email sent! Check your inbox and spam folder.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      print('AuthException: ${e.message}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.message}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('Error: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _tokenExpired
            ? _buildExpiredTokenView()
            : _codeValid
                ? _buildResetPasswordForm()
                : _buildErrorView(),
      ),
    );
  }

  Widget _buildResetPasswordForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Set New Password',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2260FF)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your new password below',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          // Password Requirements Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFF2260FF), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Password Requirements',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2260FF),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• At least 6 characters long',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New Password',
              hintText: 'Enter your new password',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFFEDEFFF),
            ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm New Password',
            hintText: 'Confirm your new password',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Color(0xFFEDEFFF),
          ),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        const SizedBox(height: 24),
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2260FF)))
            : ElevatedButton(
                onPressed: _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2260FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  'Reset Password',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildExpiredTokenView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Reset link expired or invalid.',
          style: TextStyle(color: Colors.red.shade700, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'Enter your email address',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Color(0xFFEDEFFF),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const CircularProgressIndicator(color: Color(0xFF2260FF))
            : ElevatedButton(
                onPressed: _requestNewResetEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2260FF),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  'Request New Reset Email',
                  style: TextStyle(color: Colors.white),
                ),
              ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Invalid reset link',
          style: TextStyle(color: Colors.red.shade700, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2260FF),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
            'Go Back to Login',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
} 