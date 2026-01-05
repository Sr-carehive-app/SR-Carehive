
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Provider;
import 'patient_dashboard_screen.dart';
import 'patient_login_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:care12/services/otp_service.dart';
import 'package:care12/widgets/google_logo_widget.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:care12/utils/safe_navigation.dart';

class PatientSignUpScreen extends StatefulWidget {
  final Map<String, String>? prefillData;
  final bool showRegistrationMessage;
  
  const PatientSignUpScreen({Key? key, this.prefillData, this.showRegistrationMessage = false}) : super(key: key);

  @override
  State<PatientSignUpScreen> createState() => _PatientSignUpScreenState();
}

class _PatientSignUpScreenState extends State<PatientSignUpScreen> with SingleTickerProviderStateMixin {
  // Animation controller for Google button gradient border
  late AnimationController _gradientController;
  late Animation<double> _gradientAnimation;
  
  // Salutation and Name fields
  String? selectedSalutation;
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  
  // Phone fields
  String selectedCountryCode = '+91';
  final TextEditingController aadharLinkedPhoneController = TextEditingController();
  final TextEditingController alternativePhoneController = TextEditingController();
  
  DateTime? selectedDate;
  final TextEditingController dobController = TextEditingController();
  // New age controller to replace DOB input
  final TextEditingController ageController = TextEditingController();
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
  String? _verifiedPhoneNumber; // Track which phone was verified via OTP

  // Salutation options
  final List<String> salutationOptions = ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.', 'Master', 'Miss'];
  
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
    
    // Initialize gradient animation for Google button
    _gradientController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(); // Infinite loop
    
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_gradientController);
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
      
      // Prefill age if available instead of DOB
      if (widget.prefillData!['age'] != null && widget.prefillData!['age']!.isNotEmpty) {
        ageController.text = widget.prefillData!['age']!;
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

  // OTP Verification Dialog (NEW - Backend-based with Redis)
  Future<bool> _showOTPVerificationDialog() async {
    final otpController = TextEditingController();
    bool isVerifying = false;
    int remainingSeconds = 120; // 2 minutes
    bool canResend = false;
    Timer? countdownTimer;

    // Send OTP via new backend endpoint
    final aadharPhone = aadharLinkedPhoneController.text.trim();
    final phoneWithCode = aadharPhone.isNotEmpty ? selectedCountryCode + aadharPhone : null;
    final altPhone = alternativePhoneController.text.trim().isNotEmpty 
        ? selectedCountryCode + alternativePhoneController.text.trim() 
        : null;
    final email = emailController.text.trim().isNotEmpty 
        ? emailController.text.trim() 
        : null;
    
    final fullName = '${firstNameController.text.trim()} ${middleNameController.text.trim()} ${lastNameController.text.trim()}'.trim();
    
    final result = await OTPService.sendSignupOTP(
      email: email,
      phone: phoneWithCode,
      alternativePhone: altPhone,
      name: fullName,
    );

    if (!result['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to send OTP. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    
    // Get delivery channels
    final List<String> deliveryChannels = result['deliveryChannels'] ?? [];

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
                  // Show channels dynamically based on backend response
                  ...deliveryChannels.map((channel) {
                    String icon = '📧';
                    String text = '';
                    
                    if (channel.toLowerCase().contains('email') && email != null) {
                      icon = '📧';
                      text = email;
                    } else if (channel.toLowerCase().contains('primary') || (channel.toLowerCase().contains('sms') && !channel.toLowerCase().contains('alternative'))) {
                      icon = '📱';
                      text = phoneWithCode ?? '';
                    } else if (channel.toLowerCase().contains('alternative') && altPhone != null) {
                      icon = '📱';
                      text = '$altPhone (Alt)';
                    } else {
                      return SizedBox.shrink(); // Skip unknown channels
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(icon, style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              text,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
                        
                        final resendResult = await OTPService.sendSignupOTP(
                          email: email,
                          phone: phoneWithCode,
                          alternativePhone: altPhone,
                          name: fullName,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                resendResult['success']
                                    ? 'OTP resent successfully'
                                    : resendResult['error'] ?? 'Failed to resend OTP',
                              ),
                              backgroundColor:
                                  resendResult['success']
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
                      : () async {
                          if (otpController.text.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a 6-digit OTP'),
                              ),
                            );
                            return;
                          }

                          setState(() => isVerifying = true);

                          // Verify OTP via backend
                          final verifyResult = await OTPService.verifySignupOTP(
                            email: email,
                            phone: phoneWithCode,
                            alternativePhone: altPhone,
                            otp: otpController.text,
                          );

                          setState(() => isVerifying = false);

                          if (verifyResult['success']) {
                            countdownTimer?.cancel();
                            Navigator.of(dialogContext).pop(true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(verifyResult['error'] ?? 'Invalid or expired OTP'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            
                            // Show remaining attempts if available
                            if (verifyResult['attemptsRemaining'] != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${verifyResult['attemptsRemaining']} attempts remaining'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
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
    _gradientController.dispose(); // Dispose animation controller
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    emailController.dispose();
    aadharLinkedPhoneController.dispose();
    alternativePhoneController.dispose();
  dobController.dispose();
  ageController.dispose();
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
    if (selectedSalutation == null || selectedSalutation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your salutation')),
      );
      return;
    }
    
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
    
    // EMAIL IS NOW OPTIONAL - No validation needed
    // User can signup with just phone numbers if they don't have email
    
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
      
      // Validate alternative phone is different from primary phone
      if (alternativePhoneController.text.trim() == aadharLinkedPhoneController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alternative phone number must be different from Aadhar-linked phone number'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    if (ageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your age')),
      );
      return;
    }
    
    final age = int.tryParse(ageController.text.trim()) ?? 0;
    if (age < 1 || age > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Age must be between 1 and 100')),
      );
      return;
    }
    
    // Aadhar is now optional - skip empty check
    // House/Flat Number is now optional - skip empty check
    // Street removed from signup form (not required)
    // Town/Locality is now optional - skip empty check
    
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
    
    // Validate Aadhar number only if provided
    if (aadharController.text.trim().isNotEmpty && !validateAadharFormat(aadharController.text)) {
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
    
    // Validate password length (minimum 6 characters)
    if (!_isGoogleUser && passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters long'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate password confirmation
    if (!_isGoogleUser && passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match. Please check and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    
    // We no longer use Date of Birth input; Age is required and already validated above.

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
      // Store which phone number was verified
      setState(() {
        _phoneVerified = true;
        _verifiedPhoneNumber = aadharLinkedPhoneController.text.trim();
      });
    }
    
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    
    // ✅ SECURITY CHECK: Ensure phone number hasn't changed after OTP verification
    if (!_isGoogleUser && _phoneVerified) {
      final currentPhone = aadharLinkedPhoneController.text.trim();
      if (_verifiedPhoneNumber != null && currentPhone != _verifiedPhoneNumber) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Phone number has changed. Please verify the new number with OTP.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _phoneVerified = false); // Reset verification
        return;
      }
    }
    
    try {
      final fullName = '${firstNameController.text.trim()} ${middleNameController.text.trim()} ${lastNameController.text.trim()}'.trim();
      final fullNameWithSalutation = selectedSalutation != null && selectedSalutation!.isNotEmpty 
          ? '$selectedSalutation $fullName' 
          : fullName;
      final phoneWithCode = selectedCountryCode + aadharLinkedPhoneController.text.trim();
      
      if (_isGoogleUser) {
        // Google user - already authenticated, just create patient record
        final user = supabase.auth.currentUser;
        if (user != null) {
          // Get Google avatar URL from prefill data
          final googleAvatarUrl = widget.prefillData?['google_avatar_url'] ?? '';
          
          await supabase.from('patients').insert({
            'user_id': user.id,
            'salutation': selectedSalutation,
            'name': fullName,
            'first_name': firstNameController.text.trim(),
            'middle_name': middleNameController.text.trim().isNotEmpty ? middleNameController.text.trim() : null,
            'last_name': lastNameController.text.trim(),
            'email': emailController.text.trim(),
            'country_code': selectedCountryCode,
            'aadhar_linked_phone': aadharLinkedPhoneController.text.trim(),
            'alternative_phone': alternativePhoneController.text.trim().isNotEmpty 
                ? alternativePhoneController.text.trim() 
                : null,
            'age': int.tryParse(ageController.text.trim()) ?? 0,
            'aadhar_number': aadharController.text.trim().isNotEmpty ? aadharController.text.trim() : null,
            'house_number': houseNumberController.text.trim().isNotEmpty ? houseNumberController.text.trim() : null,
            'town': townController.text.trim().isNotEmpty ? townController.text.trim() : null,
            'city': cityController.text.trim(),
            'state': stateController.text.trim(),
            'pincode': pincodeController.text.trim(),
            'gender': selectedGender,
            'phone_verified': true, // OAuth users are pre-verified
            'profile_image_url': googleAvatarUrl.isNotEmpty ? googleAvatarUrl : null, // Store Google avatar
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile completed successfully!')),
          );
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDashboardScreen(userName: fullNameWithSalutation),
            ),
            (route) => false,
          );
        }
      } else {
        // Regular sign-up with email/password OR phone-only signup
        // We already verified phone via OTP, so email verification is optional
        
        // Check if email is provided
        final hasEmail = emailController.text.trim().isNotEmpty;
        
        if (!hasEmail) {
          // ============================================================================
          // PHONE-ONLY SIGNUP PATH (Backend API call with service_role)
          // ============================================================================
          try {
            // Call backend API for phone-only registration (bypasses RLS securely)
            final response = await http.post(
              Uri.parse('${dotenv.env['API_BASE_URL']}/api/register-phone-only'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'salutation': selectedSalutation,
                'firstName': firstNameController.text.trim(),
                'middleName': middleNameController.text.trim(),
                'lastName': lastNameController.text.trim(),
                'countryCode': selectedCountryCode,
                'aadharLinkedPhone': aadharLinkedPhoneController.text.trim(),
                'alternativePhone': alternativePhoneController.text.trim(),
                'age': ageController.text.trim(),
                'aadharNumber': aadharController.text.trim(),
                'houseNumber': houseNumberController.text.trim(),
                'town': townController.text.trim(),
                'city': cityController.text.trim(),
                'state': stateController.text.trim(),
                'pincode': pincodeController.text.trim(),
                'gender': selectedGender,
                'password': passwordController.text.trim(),
              }),
            );

            if (response.statusCode == 200) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Registration successful! Please login with your phone number.'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
                
                // Save signup prefills
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('signup_name', fullName);
                await prefs.setString('signup_phone', phoneWithCode);
                await prefs.setString('signup_age', ageController.text.trim());
                await prefs.setString('signup_aadhar', aadharController.text.trim());
                await prefs.setString('signup_address', '${houseNumberController.text.trim()}, ${townController.text.trim()}, ${cityController.text.trim()}');
                await prefs.setString('signup_gender', selectedGender ?? '');
                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => PatientLoginScreen()),
                );
              }
            } else {
              final errorData = jsonDecode(response.body);
              throw Exception(errorData['error'] ?? 'Registration failed');
            }
          } catch (e) {
            if (mounted) {
              String userMessage = 'Registration failed. Please try again.';
              final errorStr = e.toString().toLowerCase();
              if (errorStr.contains('duplicate') || errorStr.contains('already registered')) {
                userMessage = 'This phone number is already registered. Please login or use a different number.';
              } else if (errorStr.contains('network') || errorStr.contains('connection')) {
                userMessage = 'Network error. Please check your internet connection.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } else {
          // ============================================================================
          // EMAIL + PASSWORD SIGNUP PATH (Existing code - NO CHANGES)
          // ============================================================================
          try {
            final authResponse = await supabase.auth.signUp(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
              emailRedirectTo: null, // Explicitly disable redirect
              data: {
                'email_confirmed': true,
                'phone_verified': true,
              },
            );
            
            final user = authResponse.user;
          
          if (user != null) {
            await supabase.from('patients').insert({
              'user_id': user.id,
              'salutation': selectedSalutation,
              'name': fullName,
              'first_name': firstNameController.text.trim(),
              'middle_name': middleNameController.text.trim().isNotEmpty ? middleNameController.text.trim() : null,
              'last_name': lastNameController.text.trim(),
              'email': emailController.text.trim(),
              'country_code': selectedCountryCode,
              'aadhar_linked_phone': aadharLinkedPhoneController.text.trim(),
              'alternative_phone': alternativePhoneController.text.trim().isNotEmpty 
                  ? alternativePhoneController.text.trim() 
                  : null,
              'age': int.tryParse(ageController.text.trim()) ?? 0,
              'aadhar_number': aadharController.text.trim().isNotEmpty ? aadharController.text.trim() : null,
              'house_number': houseNumberController.text.trim().isNotEmpty ? houseNumberController.text.trim() : null,
              // street removed from signup form
              'town': townController.text.trim().isNotEmpty ? townController.text.trim() : null,
              'city': cityController.text.trim(),
              'state': stateController.text.trim(),
              'pincode': pincodeController.text.trim(),
              'gender': selectedGender,
              'phone_verified': true,
              'otp_verified_at': DateTime.now().toIso8601String(),
            });
            
            if (mounted) {
              // Sign out the user so they have to login
              await supabase.auth.signOut();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Registration successful! Please login with your credentials.')),
              );
                // Save signup prefills (age/aadhar/gender) for post-signup prompt if needed
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('signup_name', fullName);
                await prefs.setString('signup_email', emailController.text.trim());
                await prefs.setString('signup_phone', phoneWithCode);
                await prefs.setString('signup_age', ageController.text.trim());
                await prefs.setString('signup_aadhar', aadharController.text.trim());
                await prefs.setString('signup_address', '${houseNumberController.text.trim()}, ${townController.text.trim()}, ${cityController.text.trim()}');
                await prefs.setString('signup_gender', selectedGender ?? '');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => PatientLoginScreen()),
                );
            }
          }
        } on AuthException catch (e) {
          // Handle rate limit error gracefully - we already verified phone via OTP
          if (e.message.toLowerCase().contains('rate limit') || 
              e.message.toLowerCase().contains('email rate limit exceeded')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Registration is processing. Please try logging in after a few minutes using your email and password.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 6),
                ),
              );
              // Navigate to login screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => PatientLoginScreen()),
              );
            }
          } else {
            // Other auth errors - convert to user-friendly message
            if (mounted) {
              String userMessage = 'Registration failed. Please try again.';
              final errorMsg = e.message.toLowerCase();
              if (errorMsg.contains('already registered') || errorMsg.contains('already exists')) {
                userMessage = 'This email or phone number is already registered. Please use the login option.';
              } else if (errorMsg.contains('invalid email')) {
                userMessage = 'Invalid email format. Please enter a valid email address.';
              } else if (errorMsg.contains('weak password')) {
                userMessage = 'Password is too weak. Please use a stronger password.';
              } else if (errorMsg.contains('network')) {
                userMessage = 'Network error. Please check your internet connection.';
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            // Convert database errors to user-friendly messages
            String userMessage = 'Registration failed. Please try again.';
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('duplicate') && errorStr.contains('phone')) {
              userMessage = 'This phone number is already registered. Please login or use a different number.';
            } else if (errorStr.contains('duplicate') && errorStr.contains('email')) {
              userMessage = 'This email is already registered. Please login or use a different email.';
            } else if (errorStr.contains('network') || errorStr.contains('connection')) {
              userMessage = 'Network error. Please check your internet connection.';
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
        } // End of email+password signup else block
      }
    } catch (e) {
      if (mounted) {
        String userMessage = 'Something went wrong. Please try again.';
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('network') || errorStr.contains('connection')) {
          userMessage = 'Network error. Please check your internet connection and try again.';
        } else if (errorStr.contains('timeout')) {
          userMessage = 'Request timed out. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final supabase = Supabase.instance.client;
    try {
      // For web, use localhost callback for development
      final redirect = kIsWeb
          ? '${Uri.base.origin}/auth/v1/callback'
          : 'carehive://login-callback';

      print(' Starting Google OAuth with redirect: $redirect');
      
      // Don't clear localStorage - Supabase needs to store PKCE parameters
      if (kIsWeb) {
        print(' Starting OAuth with existing localStorage state');
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
          content: Text('An error occurred during sign-in. Please try again.'),
          backgroundColor: Colors.red,
        ),
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
    return 'X' * length; // e.g., "XXXXXXXXXX" for 10 digits
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
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF5F5F5),
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // Date of birth input removed — we collect numeric Age instead.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isGoogleUser) {
              // For Google users, navigate to dashboard since they're already authenticated
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientLoginScreen(),
                ),
                (route) => false,
              );
            } else {
              // For regular users, normal back navigation
              SafeNavigation.pop(context, debugLabel: 'patient_signup_back');
            }
          },
        ),
        title: const Text(
          'Healthcare Seeker Registration',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2260FF), Color(0xFF1A4FCC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2260FF), Color(0xFF1A4FCC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2260FF).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register Your New Account Below',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete the form below to create your account and access our healthcare services',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (_isGoogleUser || widget.showRegistrationMessage) ...[
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
                        widget.showRegistrationMessage 
                          ? 'Please register your account to continue'
                          : 'Please complete your profile details to continue',
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
            // Salutation Dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Salutation *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButton<String>(
                    value: selectedSalutation,
                    hint: const Text('Select Salutation'),
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: salutationOptions.map((salutation) {
                      return DropdownMenuItem<String>(
                        value: salutation,
                        child: Text(salutation, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedSalutation = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // First Name
            buildTextField(
              label: 'First Name *',
              hint: '',
              controller: firstNameController,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            // Middle Name (Optional)
            buildTextField(
              label: 'Middle Name (Optional)',
              hint: '',
              controller: middleNameController,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            // Last Name
            buildTextField(
              label: 'Last Name *',
              hint: '',
              controller: lastNameController,
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 20),
            if (!_isGoogleUser) ...[
              buildTextField(
                label: 'Password (Should be atleast 6 characters)',
                hint: '******',
                controller: passwordController,
                obscure: _obscureText,
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              const SizedBox(height: 20),
              buildTextField(
                label: 'Confirm Password *',
                hint: '******',
                controller: confirmPasswordController,
                obscure: _obscureText,
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              const SizedBox(height: 20),
            ],
            buildTextField(
              label: 'Email (Optional)',
              hint: 'example@domain.com',
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
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
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
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Age input (replaces Date of Birth)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Age', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: InputDecoration(
                    hintText: 'XX',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aadhar Number (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: _aadharTouched 
                      ? (_aadharValid 
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : const Icon(Icons.error, color: Colors.red, size: 20))
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
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
              label: 'House/Flat Number (Optional)',
              hint: '',
              controller: houseNumberController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'Town/Village/Locality (Optional)',
              hint: '',
              controller: townController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'City *',
              hint: '',
              controller: cityController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'State *',
              hint: '',
              controller: stateController,
            ),
            const SizedBox(height: 20),
            buildTextField(
              label: 'PIN Code *',
              hint: 'XXXXXX',
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
              // Animated Google Sign-In Button with rotating gradient border
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
                                  'Sign up with Google',
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
            ],
          ],
        ),
      ),
    );
  }
}


