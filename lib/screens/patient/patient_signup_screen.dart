
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Provider;
import 'patient_login_screen.dart';
import 'patient_dashboard_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PatientSignUpScreen extends StatefulWidget {
  final Map<String, String>? prefillData;
  
  const PatientSignUpScreen({Key? key, this.prefillData}) : super(key: key);

  @override
  State<PatientSignUpScreen> createState() => _PatientSignUpScreenState();
}

class _PatientSignUpScreenState extends State<PatientSignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  DateTime? selectedDate;
  final TextEditingController dobController = TextEditingController();
  final TextEditingController aadharController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  String? selectedGender;

  bool _obscureText = true;
  bool _isLoading = false;
  bool _isGoogleUser = false;
  bool _aadharValid = false;
  bool _aadharTouched = false;

  @override
  void initState() {
    super.initState();
    _isGoogleUser = widget.prefillData != null;
    _prefillData();
  }

  void _prefillData() {
    if (widget.prefillData != null) {
      nameController.text = widget.prefillData!['name'] ?? '';
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

  @override
  void dispose() {
    nameController.dispose();
    passwordController.dispose();
    emailController.dispose();
    phoneController.dispose();
    dobController.dispose();
    aadharController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (nameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        dobController.text.isEmpty ||
        aadharController.text.isEmpty ||
        addressController.text.isEmpty ||
        selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
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
    
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    
    try {
      if (_isGoogleUser) {
        // Google user - already authenticated, just create patient record
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase.from('patients').insert({
            'user_id': user.id,
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'dob': dobController.text.trim(),
            'aadhar_number': aadharController.text.trim(),
            'permanent_address': addressController.text.trim(),
            'gender': selectedGender,
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile completed successfully!')),
          );
          
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => PatientDashboardScreen(userName: nameController.text.trim()),
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
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'dob': dobController.text.trim(),
            'aadhar_number': aadharController.text.trim(),
            'permanent_address': addressController.text.trim(),
            'gender': selectedGender,
          });
          
          // Save details to shared_preferences for pre-filling on first login
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('signup_name', nameController.text.trim());
          await prefs.setString('signup_email', emailController.text.trim());
          await prefs.setString('signup_phone', phoneController.text.trim());
          await prefs.setString('signup_dob', dobController.text.trim());
          await prefs.setString('signup_aadhar', aadharController.text.trim());
          await prefs.setString('signup_address', addressController.text.trim());
          await prefs.setString('signup_gender', selectedGender ?? '');
          
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
            : 'https://abqqwgzijmvqjabfvqbc.supabase.co/auth/v1/callback',
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
            buildTextField(
              label: 'Full name',
              hint: 'Example',
              controller: nameController,
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
            buildTextField(
              label: 'Mobile Number',
              hint: '9999XXXXX',
              controller: phoneController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            buildDateField(),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Aadhar Number', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: aadharController,
                  keyboardType: TextInputType.number,
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
            buildTextField(
              label: 'Permanent Address',
              hint: 'Enter your address',
              controller: addressController,
              keyboardType: TextInputType.multiline,
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
              ElevatedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: Image.asset('assets/images/google.png', height: 24),
                label: const Text('Sign up with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Color(0xFF2260FF)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
