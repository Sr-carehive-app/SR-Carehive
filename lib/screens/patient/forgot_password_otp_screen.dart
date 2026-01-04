import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../config/api_config.dart';
import 'patient_login_screen.dart';

class ForgotPasswordOTPScreen extends StatefulWidget {
  final String email;
  
  const ForgotPasswordOTPScreen({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<ForgotPasswordOTPScreen> createState() => _ForgotPasswordOTPScreenState();
}

class _ForgotPasswordOTPScreenState extends State<ForgotPasswordOTPScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _otpVerified = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  int _remainingAttempts = 5;
  
  // Resend OTP cooldown
  bool _canResend = false;
  int _resendCooldown = 120; // 2 minutes in seconds
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    // Cancel timer first to stop any pending setState calls
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    
    // Dispose all text controllers
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    
    // Dispose all focus nodes
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    
    super.dispose();
  }

  void _startResendCooldown() {
    if (!mounted) return;
    setState(() {
      _canResend = false;
      _resendCooldown = 120; // 2 minutes
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String _formatCooldownTime() {
    final minutes = _resendCooldown ~/ 60;
    final seconds = _resendCooldown % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getOTP() {
    return _otpControllers.map((c) => c.text).join();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    
    if (otp.length != 6) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Please enter complete 6-digit OTP';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔐 Verifying OTP for: ${widget.email}');
      print('🌐 Using API: ${ApiConfig.verifyPasswordResetOtp}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.verifyPasswordResetOtp),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'otp': otp,
        }),
      );

      final data = json.decode(response.body);
      print('Response: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ OTP verified successfully!');
        
        if (!mounted) return;
        setState(() {
          _otpVerified = true;
          _errorMessage = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ OTP verified! Now set your new password.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ OTP verification failed: ${data['error']}');
        
        if (!mounted) return;
        setState(() {
          _errorMessage = data['error'] ?? 'Invalid OTP';
          if (data['remainingAttempts'] != null) {
            _remainingAttempts = data['remainingAttempts'];
          }
        });
      }
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validation
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Please fill all password fields';
      });
      return;
    }

    if (newPassword.length < 6) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔐 Resetting password for: ${widget.email}');
      print('🌐 Using API: ${ApiConfig.resetPasswordWithOtp}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.resetPasswordWithOtp),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'otp': _getOTP(),
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);
      print('Response: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ Password reset successfully!');
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Password reset successfully! Please login with your new password.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to login - use pushAndRemoveUntil to avoid splash screen conflict
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PatientLoginScreen()),
          (route) => false,
        );
      } else {
        print('❌ Password reset failed: ${data['error']}');
        
        if (!mounted) return;
        setState(() {
          _errorMessage = data['error'] ?? 'Failed to reset password';
        });
      }
    } catch (e) {
      print('❌ Error resetting password: $e');
      
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('📧 Resending OTP to: ${widget.email}');
      print('🌐 Using API: ${ApiConfig.sendPasswordResetOtp}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.sendPasswordResetOtp),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'resend': true,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ OTP resent successfully');
        
        // Start cooldown again
        _startResendCooldown();
        
        if (!mounted) return;
        
        final deliveryChannels = data['deliveryChannels'] as List?;
        String message = '✅ New OTP sent!';
        if (deliveryChannels != null && deliveryChannels.isNotEmpty) {
          if (deliveryChannels.contains('SMS')) {
            message += ' Check your email and phone.';
          } else {
            message += ' Check your email.';
          }
        } else {
          message += ' Check your email.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      } else if (response.statusCode == 429) {
        // Cooldown active - update remaining time
        final remainingSeconds = data['remainingSeconds'] ?? 120;
        if (!mounted) return;
        setState(() {
          _resendCooldown = remainingSeconds;
          _canResend = false;
        });
        _startResendCooldown();
        
        print('⏳ Cooldown active: ${data['error']}');
        if (!mounted) return;
        _showError(data['error'] ?? 'Please wait before requesting new OTP');
      } else {
        print('❌ Failed to resend OTP: ${data['error']}');
        
        if (!mounted) return;
        _showError(data['error'] ?? 'Failed to resend OTP. Please try again.');
      }
    } catch (e) {
      print('❌ Error resending OTP: $e');
      
      if (!mounted) return;
        _showError('Network error. Please check your connection.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _otpVerified ? Icons.check_circle : Icons.security,
              size: 80,
              color: _otpVerified ? Colors.green : const Color(0xFF2260FF),
            ),
            const SizedBox(height: 20),
            Text(
              _otpVerified ? 'OTP Verified!' : 'Enter OTP',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2260FF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _otpVerified 
                  ? 'Now set your new password' 
                  : 'We sent a 6-digit code to ${widget.email}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            if (!_otpVerified) ...[
              // OTP Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 60,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFEDEFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        }
                        
                        // Auto-verify when all 6 digits entered
                        if (index == 5 && value.isNotEmpty) {
                          _verifyOTP();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              
              // Resend OTP with cooldown timer
              TextButton(
                onPressed: (_isLoading || !_canResend) ? null : _resendOTP,
                child: Text(
                  _canResend 
                      ? 'Didn\'t receive? Resend OTP'
                      : 'Resend OTP (${_formatCooldownTime()})',
                  style: TextStyle(
                    color: _canResend ? const Color(0xFF2260FF) : Colors.grey,
                  ),
                ),
              ),
              
              if (!_canResend)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Please wait before requesting a new OTP',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2260FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Verify OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
            
            if (_otpVerified) ...[
              // Password fields
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Enter new password (min 6 characters)',
                  filled: true,
                  fillColor: const Color(0xFFEDEFFF),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Re-enter new password',
                  filled: true,
                  fillColor: const Color(0xFFEDEFFF),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2260FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Remaining attempts (if applicable)
            if (!_otpVerified && _remainingAttempts < 5)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Remaining attempts: $_remainingAttempts/5',
                  style: TextStyle(
                    color: _remainingAttempts <= 2 ? Colors.red : Colors.orange,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
