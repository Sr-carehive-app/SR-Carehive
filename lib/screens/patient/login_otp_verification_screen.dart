import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/api_config.dart';
import 'patient_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginOTPVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  
  const LoginOTPVerificationScreen({
    Key? key,
    required this.email,
    required this.password,
  }) : super(key: key);

  @override
  State<LoginOTPVerificationScreen> createState() => _LoginOTPVerificationScreenState();
}

class _LoginOTPVerificationScreenState extends State<LoginOTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  
  bool _isLoading = false;
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
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    
    super.dispose();
  }

  void _startResendCooldown() {
    if (!mounted) return;
    setState(() {
      _canResend = false;
      _resendCooldown = 120;
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

  String _getOTPSentMessage() {
    final identifier = widget.email.trim();
    final isEmail = identifier.contains('@');
    
    if (isEmail) {
      // Mask email: sh***@example.com
      final parts = identifier.split('@');
      if (parts.length == 2) {
        final username = parts[0];
        final maskedUsername = username.length > 2 
            ? '${username.substring(0, 2)}${'*' * 5}'
            : username;
        return 'We\'ve sent a 6-digit OTP to\n$maskedUsername@${parts[1]}';
      }
      return 'We\'ve sent a 6-digit OTP to\n$identifier';
    } else {
      // Mask phone: 96******06
      if (identifier.length == 10) {
        final masked = '${identifier.substring(0, 2)}${'X' * 6}${identifier.substring(8)}';
        return 'We\'ve sent a 6-digit OTP to\n+91 $masked';
      }
      return 'We\'ve sent a 6-digit OTP to\n$identifier';
    }
  }

  Future<void> _verifyOTPAndLogin() async {
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
      print('🔐 Verifying login OTP for: ${widget.email}');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/verify-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'otp': otp,
        }),
      );

      final data = json.decode(response.body);
      print('Response: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        print('✅ OTP verified! Checking user type...');
        
        final userId = data['userId']; // NULL for phone-only users
        final actualEmail = data['email']; // NULL OR populated for phone-only users who added email
        final phone = data['phone']; // Phone number for phone-only users
        final loginType = data['loginType']; // 'email' or 'phone'
        
        print('📋 Login type: $loginType');
        print('📧 Email: $actualEmail');
        print('📱 Phone: $phone');
        print('🆔 User ID: $userId');
        
        final supabase = Supabase.instance.client;
        
        // ⚠️ CRITICAL: Check user_id instead of email presence
        // Phone-registered users have NO user_id even if they add email later
        if (userId == null || userId == 'null' || loginType == 'phone') {
          // ========== PHONE-ONLY USER (NO SUPABASE AUTH ACCOUNT) ==========
          print('📱 Phone-only user detected (no user_id), querying by phone number');
          
          // Fetch patient data using phone number (since user_id is NULL)
          final result = await supabase
              .from('patients')
              .select()
              .eq('aadhar_linked_phone', phone)
              .maybeSingle();
          
          if (result == null) {
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Patient record not found';
            });
            return;
          }
          
          if (!mounted) return;
          
          // Save phone to SharedPreferences for phone-only users
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('phone', phone);
          await prefs.setString('loginType', 'phone');
          
          // Build display name
          final salutation = result['salutation'] ?? '';
          final name = result['name'] ?? '';
          final displayName = salutation.isNotEmpty ? '$salutation $name' : name;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Login successful!')),
          );
          
          // Navigate to dashboard
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDashboardScreen(userName: displayName),
            ),
            (route) => false,
          );
        } else {
          // ========== EMAIL USER (Supabase Auth) ==========
          print('📧 Email user detected: $actualEmail');
          print('🔑 Password length: ${widget.password.length}');
          
          try {
            final authResponse = await supabase.auth.signInWithPassword(
              email: actualEmail,
              password: widget.password,
            );
            
            final user = authResponse.user;
            
            if (user != null) {
              // Fetch patient data
              var patient = await supabase
                  .from('patients')
                  .select()
                  .eq('user_id', user.id)
                  .maybeSingle();
              
              if (patient == null) {
                // Handle missing patient profile
                await _showCompleteProfileDialog(user);
                
                patient = await supabase
                    .from('patients')
                    .select()
                    .eq('user_id', user.id)
                    .single();
              }
              
              if (!mounted) return;
              
              // Build display name
              final salutation = patient?['salutation'] ?? '';
              final name = patient?['name'] ?? '';
              final displayName = salutation.isNotEmpty ? '$salutation $name' : name;
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Login successful!')),
              );
              
              // Navigate to dashboard
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientDashboardScreen(userName: displayName),
                ),
                (route) => false,
              );
            } else {
              if (!mounted) return;
              setState(() {
                _errorMessage = 'Login failed after OTP verification';
              });
            }
          } on AuthException catch (e) {
            if (!mounted) return;
            setState(() {
              _errorMessage = 'Login error: ${e.message}';
            });
          }
        }
      } else {
        // Handle OTP verification errors
        final errorMsg = data['error'] ?? 'Invalid OTP';
        final remainingAttempts = data['remainingAttempts'];
        
        if (!mounted) return;
        setState(() {
          _errorMessage = errorMsg;
          if (remainingAttempts != null) {
            _remainingAttempts = remainingAttempts;
          }
        });
        
        if (data['expired'] == true || data['attemptsExceeded'] == true) {
          // OTP expired or too many attempts - go back to login
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          Navigator.pop(context);
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      
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

  Future<void> _showCompleteProfileDialog(User user) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final ageController = TextEditingController();
    final aadharController = TextEditingController();
    final addressController = TextEditingController();
    String? selectedGender;
    
    // Pre-fill from shared_preferences
    final prefs = await SharedPreferences.getInstance();
    nameController.text = prefs.getString('signup_name') ?? '';
    phoneController.text = prefs.getString('signup_phone') ?? '';
    ageController.text = prefs.getString('signup_age') ?? '';
    aadharController.text = prefs.getString('signup_aadhar') ?? '';
    addressController.text = prefs.getString('signup_address') ?? '';
    selectedGender = prefs.getString('signup_gender');
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Complete Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Mobile Number')),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: const InputDecoration(labelText: 'Age', hintText: '1-100'),
                ),
                TextField(controller: aadharController, decoration: const InputDecoration(labelText: 'Aadhar Number')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Permanent Address')),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Male'),
                        value: 'Male',
                        groupValue: selectedGender,
                        onChanged: (value) => setDialogState(() => selectedGender = value),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Female'),
                        value: 'Female',
                        groupValue: selectedGender,
                        onChanged: (value) => setDialogState(() => selectedGender = value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (nameController.text.isEmpty || phoneController.text.isEmpty || ageController.text.isEmpty || aadharController.text.isEmpty || addressController.text.isEmpty || selectedGender == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                  return;
                }
                
                final age = int.tryParse(ageController.text.trim()) ?? 0;
                if (age < 1 || age > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Age must be between 1 and 100')));
                  return;
                }
                
                final supabase = Supabase.instance.client;
                await supabase.from('patients').insert({
                  'user_id': user.id,
                  'name': nameController.text.trim(),
                  'email': user.email ?? '',
                  'aadhar_linked_phone': phoneController.text.trim(),
                  'age': int.tryParse(ageController.text.trim()) ?? 0,
                  'aadhar_number': aadharController.text.trim(),
                  'permanent_address': addressController.text.trim(),
                  'gender': selectedGender,
                });
                
                // Clear prefs
                await prefs.remove('signup_name');
                await prefs.remove('signup_email');
                await prefs.remove('signup_phone');
                await prefs.remove('signup_age');
                await prefs.remove('signup_aadhar');
                await prefs.remove('signup_address');
                await prefs.remove('signup_gender');
                
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/send-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'password': widget.password,
        }),
      );

      final data = json.decode(response.body);
      
      if (!mounted) return;
      
      if (response.statusCode == 200 && data['success'] == true) {
        final deliveryChannels = data['deliveryChannels'] as List?;
        String message = '✅ New OTP sent!';
        if (deliveryChannels != null && deliveryChannels.isNotEmpty) {
          if (deliveryChannels.contains('SMS')) {
            message += ' Check your phone.';
          } else {
            message += ' Check your email.';
          }
        } else {
          message += ' Check your email/phone.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        _startResendCooldown();
        
        // Clear OTP fields
        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
        
        setState(() {
          _errorMessage = null;
          _remainingAttempts = 5;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${data['error'] ?? 'Failed to resend OTP'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Network error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Login OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF2260FF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(
                Icons.verified_user,
                size: 80,
                color: Color(0xFF2260FF),
              ),
              const SizedBox(height: 30),
              Text(
                'Enter OTP',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _getOTPSentMessage(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    child: TextField(
                      controller: _otpControllers[index],
                      focusNode: _otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
                        ),
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 5) {
                          _otpFocusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _otpFocusNodes[index - 1].requestFocus();
                        }
                        
                        if (_getOTP().length == 6) {
                          _verifyOTPAndLogin();
                        }
                      },
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 20),
              
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
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTPAndLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2260FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Verify & Login',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
              
              const SizedBox(height: 20),
              
              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Didn't receive OTP? "),
                  TextButton(
                    onPressed: _canResend && !_isLoading ? _resendOTP : null,
                    child: Text(
                      _canResend ? 'Resend OTP' : 'Resend in ${_formatCooldownTime()}',
                      style: TextStyle(
                        color: _canResend ? const Color(0xFF2260FF) : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              Text(
                'Remaining attempts: $_remainingAttempts/5',
                style: TextStyle(
                  fontSize: 12,
                  color: _remainingAttempts <= 2 ? Colors.red : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
