
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Provider;
import 'patient_login_screen.dart';
import 'patient_dashboard_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:care12/services/otp_service.dart';
import 'package:care12/widgets/google_logo_widget.dart';
import 'dart:async';

class PatientSignUpScreen extends StatefulWidget {
  final Map<String, String>? prefillData;
  
  const PatientSignUpScreen({Key? key, this.prefillData}) : super(key: key);

  @override
  State<PatientSignUpScreen> createState() => _PatientSignUpScreenState();
}

class _PatientSignUpScreenState extends State<PatientSignUpScreen> {
  // Name fields
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  
  // Phone fields
  String selectedCountryCode = '+91';
  final TextEditingController aadharLinkedPhoneController = TextEditingController();
  final TextEditingController alternativePhoneController = TextEditingController();
  
  DateTime? selectedDate;
  final TextEditingController dobController = TextEditingController();
  final TextEditingController aadharController = TextEditingController();
  
  // Address fields
  final TextEditingController houseNumberController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController townController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  
  String? selectedGender;

  bool _obscureText = true;
  bool _isLoading = false;
  bool _isGoogleUser = false;
  bool _aadharValid = false;
  bool _aadharTouched = false;
  bool _phoneVerified = false;

  // Country codes list with phone number lengths
  final List<Map<String, dynamic>> countryCodes = [
    {'code': '+91', 'country': 'India', 'length': 10},
    {'code': '+1', 'country': 'USA', 'length': 10},
    {'code': '+44', 'country': 'UK', 'length': 10},
    {'code': '+971', 'country': 'UAE', 'length': 9},
    {'code': '+61', 'country': 'Australia', 'length': 9},
    {'code': '+65', 'country': 'Singapore', 'length': 8},
  ];

  @override
  void initState() {
    super.initState();
    _isGoogleUser = widget.prefillData != null;
    _prefillData();
  }

  void _prefillData() {
    if (widget.prefillData != null) {
      // Split name if provided
      final fullName = widget.prefillData!['name'] ?? '';
      final nameParts = fullName.split(' ');
      if (nameParts.isNotEmpty) {
        firstNameController.text = nameParts[0];
        if (nameParts.length > 2) {
          middleNameController.text = nameParts.sublist(1, nameParts.length - 1).join(' ');
          lastNameController.text = nameParts.last;
        } else if (nameParts.length == 2) {
          lastNameController.text = nameParts[1];
        }
      }
      
      emailController.text = widget.prefillData!['email'] ?? '';
      
      // Pre-fill DOB if available
      if (widget.prefillData!['dob'] != null && widget.prefillData!['dob']!.isNotEmpty) {
        dobController.text = widget.prefillData!['dob']!;
        try {
          selectedDate = DateFormat('yyyy-MM-dd').parse(widget.prefillData!['dob']!);
        } catch (e) {
          // Invalid date format, ignore
        }
      }
      
      // Pre-fill gender if available
      if (widget.prefillData!['gender'] != null && widget.prefillData!['gender']!.isNotEmpty) {
        selectedGender = widget.prefillData!['gender']!;
      }
    }
  }

  // Aadhar validation method
  bool validateAadharFormat(String aadhar) {
    // Remove spaces, dashes, and other non-digit characters
    String clean = aadhar.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if exactly 12 digits
    if (clean.length != 12) return false;
    
    // Check if all characters are digits
    if (!RegExp(r'^\d{12}$').hasMatch(clean)) return false;
    
    // Check if not all same digits (like 111111111111)
    if (RegExp(r'^(\d)\1{11}$').hasMatch(clean)) return false;
    
    // Check if not starting with 0 (UIDAI rules - Aadhar cannot start with 0)
    if (clean.startsWith('0')) return false;
    
    // Basic validation passed - this is a valid Aadhar format
    return true;
  }

  // Verhoeff algorithm implementation for Aadhar checksum
  bool _verhoeffChecksum(String number) {
    int c = 0;
    List<int> num = number.split('').map((e) => int.parse(e)).toList();
    
    // Multiplication table
    List<List<int>> d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    ];
    
    // Permutation table
    List<List<int>> p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]
    ];
    
    // Inverse table
    List<int> inv = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9];
    
    for (int i = num.length - 1; i >= 0; i--) {
      c = d[c][p[((num.length - i) % 8)][num[i]]];
    }
    
    return inv[c] == 0;
  }

  // Format Aadhar number with dashes
  String _formatAadhar(String text) {
    // Remove all non-digits
    String clean = text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Add dashes after every 4 digits
    if (clean.length <= 4) return clean;
    if (clean.length <= 8) return '${clean.substring(0, 4)}-${clean.substring(4)}';
    return '${clean.substring(0, 4)}-${clean.substring(4, 8)}-${clean.substring(8)}';
  }

  // OTP Verification Dialog
  Future<bool> _showOTPVerificationDialog() async {
    final otpController = TextEditingController();
    bool isVerifying = false;
    int remainingSeconds = 120; // 2 minutes
    bool canResend = false;
    Timer? countdownTimer;

    // Send OTP
    final phoneWithCode = selectedCountryCode + aadharLinkedPhoneController.text.trim();
    final result = await OTPService.sendOTP(phoneWithCode, emailController.text.trim());

    if (!result['sms']! && !result['email']!) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send OTP. Please check your phone number and email.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Start timer only once
            if (countdownTimer == null || !countdownTimer!.isActive) {
              countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (remainingSeconds > 0) {
                  setState(() {
                    remainingSeconds--;
                    if (remainingSeconds == 0) {
                      canResend = true;
                      timer.cancel();
                    }
                  });
                } else {
                  timer.cancel();
                }
              });
            }

            return AlertDialog(
              title: const Text('Verify OTP'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the 6-digit OTP sent to:',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📧 ${emailController.text}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (result['sms']!)
                    Text(
                      '📱 $phoneWithCode',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableInteractiveSelection: true,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8),
                    decoration: const InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (remainingSeconds > 0)
                    Text(
                      'OTP expires in ${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  if (canResend)
                    TextButton(
                      onPressed: () async {
                        setState(() {
                          remainingSeconds = 120;
                          canResend = false;
                        });
                        
                        // Restart timer
                        countdownTimer?.cancel();
                        countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                          if (remainingSeconds > 0) {
                            setState(() {
                              remainingSeconds--;
                              if (remainingSeconds == 0) {
                                canResend = true;
                                timer.cancel();
                              }
                            });
                          } else {
                            timer.cancel();
                          }
                        });
                        
                        final resendResult = await OTPService.sendOTP(
                          phoneWithCode,
                          emailController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                resendResult['sms']! || resendResult['email']!
                                    ? 'OTP resent successfully'
                                    : 'Failed to resend OTP',
                              ),
                              backgroundColor:
                                  resendResult['sms']! || resendResult['email']!
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Resend OTP'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    countdownTimer?.cancel();
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () {
                          if (otpController.text.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a 6-digit OTP'),
                              ),
                            );
                            return;
                          }

                          setState(() => isVerifying = true);

                          final isValid = OTPService.verifyOTP(otpController.text);

                          setState(() => isVerifying = false);

                          if (isValid) {
                            countdownTimer?.cancel();
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invalid or expired OTP'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      countdownTimer?.cancel();
    }) ?? false;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    aadharLinkedPhoneController.dispose();
    alternativePhoneController.dispose();
    dobController.dispose();
    aadharController.dispose();
    houseNumberController.dispose();
    streetController.dispose();
    townController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    // Validate all required fields with specific error messages
    if (firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your first name')),
      );
      return;
    }
    
    if (lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your last name')),
      );
      return;
    }
    
    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email')),
      );
      return;
    }
    
    if (aadharLinkedPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Aadhar linked phone number')),
      );
      return;
    }
    
    // Validate phone number length based on country code
    final requiredLength = getPhoneNumberLength();
    if (aadharLinkedPhoneController.text.trim().length != requiredLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number must be $requiredLength digits for $selectedCountryCode')),
      );
      return;
    }
    
    // Validate alternative phone number if provided
    if (alternativePhoneController.text.trim().isNotEmpty) {
      if (alternativePhoneController.text.trim().length != requiredLength) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alternative phone number must be $requiredLength digits for $selectedCountryCode')),
        );
        return;
      }
    }
    
    if (dobController.text.trim().isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }
    
    if (aadharController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Aadhar number')),
      );
      return;
    }
    
    if (houseNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your house/flat number')),
      );
      return;
    }
    
    if (streetController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your street')),
      );
      return;
    }
    
    if (townController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your town/locality')),
      );
      return;
    }
    
    if (cityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your city')),
      );
      return;
    }
    
    if (stateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your state')),
      );
      return;
    }
    
    if (pincodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your PIN code')),
      );
      return;
    }
    
    if (selectedGender == null || selectedGender!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }
    
    // Validate Aadhar number
    if (!validateAadharFormat(aadharController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Aadhar number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // For non-Google users, check password
    if (!_isGoogleUser && passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }
    
    // Validate date format
    try {
      DateFormat('yyyy-MM-dd').parseStrict(dobController.text.trim());
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid date of birth')),
      );
      return;
    }

    // For non-OAuth users, verify phone via OTP
    if (!_isGoogleUser && !_phoneVerified) {
      // Show loading state
      setState(() => _isLoading = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Sending OTP...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      final otpVerified = await _showOTPVerificationDialog();
      
      // Hide loading state
      setState(() => _isLoading = false);
      
      if (!otpVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verification is required to continue'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _phoneVerified = true);
    }
    
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    
    try {
      final fullName = '${firstNameController.text.trim()} ${middleNameController.text.trim()} ${lastNameController.text.trim()}'.trim();
      final phoneWithCode = selectedCountryCode + aadharLinkedPhoneController.text.trim();
      
      if (_isGoogleUser) {
        // Google user - already authenticated, just create patient record
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase.from('patients').insert({
            'user_id': user.id,
            'name': fullName,
            'first_name': firstNameController.text.trim(),
            'middle_name': middleNameController.text.trim(),
            'last_name': lastNameController.text.trim(),
            'email': emailController.text.trim(),
            'country_code': selectedCountryCode,
            'aadhar_linked_phone': aadharLinkedPhoneController.text.trim(),
            'alternative_phone': alternativePhoneController.text.trim().isNotEmpty 
                ? alternativePhoneController.text.trim() 
                : null,
            'dob': dobController.text.trim(),
            'aadhar_number': aadharController.text.trim(),
            'house_number': houseNumberController.text.trim(),
            'street': streetController.text.trim(),
            'town': townController.text.trim(),
            'city': cityController.text.trim(),
            'state': stateController.text.trim(),
            'pincode': pincodeController.text.trim(),
            'gender': selectedGender,
            'phone_verified': true, // OAuth users are pre-verified
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile completed successfully!')),
          );
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDashboardScreen(userName: fullName),
            ),
            (route) => false,
          );
        }
      } else {
        // Regular sign-up with email/password
        final authResponse = await supabase.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        final user = authResponse.user;
        if (user != null) {
          await supabase.from('patients').insert({
            'user_id': user.id,
            'name': fullName,
            'first_name': firstNameController.text.trim(),
            'middle_name': middleNameController.text.trim(),
            'last_name': lastNameController.text.trim(),
            'email': emailController.text.trim(),
            'country_code': selectedCountryCode,
            'aadhar_linked_phone': aadharLinkedPhoneController.text.trim(),
            'alternative_phone': alternativePhoneController.text.trim().isNotEmpty 
                ? alternativePhoneController.text.trim() 
                : null,
            'dob': dobController.text.trim(),
            'aadhar_number': aadharController.text.trim(),
            'house_number': houseNumberController.text.trim(),
            'street': streetController.text.trim(),
            'town': townController.text.trim(),
            'city': cityController.text.trim(),
            'state': stateController.text.trim(),
            'pincode': pincodeController.text.trim(),
            'gender': selectedGender,
            'phone_verified': true,
            'otp_verified_at': DateTime.now().toIso8601String(),
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please verify your email.')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const PatientLoginScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? 'http://localhost:5173/auth/v1/callback'
            : null,  // ✅ Let Supabase auto-detect (uses deep link from Supabase dashboard)
      );
      // The OAuth callback will be handled in main.dart
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // Get phone number length for selected country
  int getPhoneNumberLength() {
    final country = countryCodes.firstWhere(
      (c) => c['code'] == selectedCountryCode,
      orElse: () => {'code': '+91', 'country': 'India', 'length': 10},
    );
    return country['length'] as int;
  }

  // Get placeholder for selected country
  String getPhonePlaceholder() {
    final length = getPhoneNumberLength();
    return '9' * length; // e.g., "9999999999" for 10 digits
  }

  Widget buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          enabled: enabled,
          enableInteractiveSelection: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? const Color(0xFFEDEFFF) : const Color(0xFFF5F5F5),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDateField() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000, 1, 1),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            selectedDate = picked;
            dobController.text = DateFormat('yyyy-MM-dd').format(picked);
          });
        }
      },
      child: AbsorbPointer(
        child: buildTextField(
          label: 'Date Of Birth',
          hint: 'YYYY-MM-DD',
          controller: dobController,
          keyboardType: TextInputType.datetime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (_isGoogleUser) {
              // For Google users, navigate to dashboard since they're already authenticated
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const PatientLoginScreen(),
                ),
                (route) => false,
              );
            } else {
              // For regular users, normal back navigation
              Navigator.pop(context);
            }
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const SizedBox(height: 20),
            const Text(
              'New Account',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFF2260FF),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isGoogleUser) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2260FF), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: const Color(0xFF2260FF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please complete your profile details to continue',
                        style: TextStyle(
                          color: const Color(0xFF2260FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // First Name
            buildTextField(
              label: 'First Name *',
              hint: 'John',
              controller: firstNameController,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            // Middle Name (Optional)
            buildTextField(
              label: 'Middle Name (Optional)',
              hint: 'Kumar',
              controller: middleNameController,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            // Last Name
            buildTextField(
              label: 'Last Name *',
              hint: 'Sharma',
              controller: lastNameController,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            if (!_isGoogleUser) ...[
              buildTextField(
                label: 'Password',
                hint: '******',
                controller: passwordController,
                obscure: _obscureText,
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              const SizedBox(height: 20),
            ],
            buildTextField(
              label: 'Email',
              hint: 'example@example.com',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isGoogleUser,
            ),
            const SizedBox(height: 20),
            // Aadhar Linked Phone Number with Country Code
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aadhar Linked Phone Number *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Country Code Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: selectedCountryCode,
                        underline: const SizedBox(),
                        items: countryCodes.map((code) {
                          return DropdownMenuItem<String>(
                            value: code['code'] as String,
                            child: Text('${code['code']} ${code['country']}', style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedCountryCode = value!);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Phone Number Field
                    Expanded(
                      child: TextField(
                        key: ValueKey(selectedCountryCode), // Rebuild when country changes
                        controller: aadharLinkedPhoneController,
                        keyboardType: TextInputType.phone,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableInteractiveSelection: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(getPhoneNumberLength()),
                        ],
                        decoration: InputDecoration(
                          hintText: getPhonePlaceholder(),
                          filled: true,
                          fillColor: const Color(0xFFEDEFFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'This number must be linked to your Aadhar card. OTP will be sent here.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Alternative Phone Number (Optional)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alternative Phone Number (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Country Code Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: selectedCountryCode,
                        underline: const SizedBox(),
                        items: countryCodes.map((code) {
                          return DropdownMenuItem<String>(
                            value: code['code'] as String,
                            child: Text('${code['code']} ${code['country']}', style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedCountryCode = value!);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Alternative Phone Number Field
                    Expanded(
                      child: TextField(
                        key: ValueKey('alt_$selectedCountryCode'), // Rebuild when country changes
                        controller: alternativePhoneController,
                        keyboardType: TextInputType.phone,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableInteractiveSelection: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(getPhoneNumberLength()),
                        ],
                        decoration: InputDecoration(
                          hintText: getPhonePlaceholder(),
                          filled: true,
                          fillColor: const Color(0xFFEDEFFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            buildDateField(),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aadhar Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: aadharController,
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _aadharTouched = true;
                      _aadharValid = validateAadharFormat(value);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX-XXXX',
                    filled: true,
                    fillColor: const Color(0xFFEDEFFF),
                    suffixIcon: _aadharTouched 
                      ? (_aadharValid 
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : const Icon(Icons.error, color: Colors.red, size: 20))
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_aadharTouched && !_aadharValid && aadharController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Please enter a valid 12-digit Aadhar number',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Permanent Address Section
            const Text('Permanent Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            buildTextField(
              label: 'House/Flat Number *',
              hint: '123 or A-45',
              controller: houseNumberController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'Street *',
              hint: 'MG Road',
              controller: streetController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'Town/Locality *',
              hint: 'Rajpur',
              controller: townController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'City *',
              hint: 'Dehradun',
              controller: cityController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'State *',
              hint: 'Uttarakhand',
              controller: stateController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'PIN Code *',
              hint: '248001',
              controller: pincodeController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            const Text('Gender', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Male'),
                    value: 'Male',
                    groupValue: selectedGender,
                    onChanged: (value) => setState(() => selectedGender = value),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Female'),
                    value: 'Female',
                    groupValue: selectedGender,
                    onChanged: (value) => setState(() => selectedGender = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2260FF)))
                : ElevatedButton(
                    onPressed: _handleSignUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2260FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(
                      _isGoogleUser ? 'Complete Profile' : 'Sign Up',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
            const SizedBox(height: 20),
            if (!_isGoogleUser) ...[
              OutlinedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: const GoogleLogoWidget(size: 18),
                label: const Text(
                  'Sign up with Google',
                  style: TextStyle(
                    color: Color(0xFF3C4043),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFDADADA), width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
