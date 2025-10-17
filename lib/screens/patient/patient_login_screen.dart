import 'package:flutter/material.dart';
import 'package:care12/screens/patient/patient_dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Provider;
import 'patient_signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:care12/widgets/google_logo_widget.dart';

class PatientLoginScreen extends StatefulWidget {
  const PatientLoginScreen({Key? key}) : super(key: key);

  @override
  State<PatientLoginScreen> createState() => _PatientLoginScreenState();
}

class _PatientLoginScreenState extends State<PatientLoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      final user = response.user;
      if (user != null) {
        // Check if patient record exists
        var patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (patient == null) {
          // If coming from signup, you may want to pass these details via Navigator or store temporarily
          // For now, show a dialog to collect missing info
          await showDialog(
            context: context,
            builder: (context) {
              final nameController = TextEditingController();
              final phoneController = TextEditingController();
              final dobController = TextEditingController();
              final aadharController = TextEditingController();
              final addressController = TextEditingController();
              String? selectedGender;
              // Pre-fill from shared_preferences if available
              Future<void> prefill() async {
                final prefs = await SharedPreferences.getInstance();
                nameController.text = prefs.getString('signup_name') ?? '';
                phoneController.text = prefs.getString('signup_phone') ?? '';
                dobController.text = prefs.getString('signup_dob') ?? '';
                aadharController.text = prefs.getString('signup_aadhar') ?? '';
                addressController.text = prefs.getString('signup_address') ?? '';
                selectedGender = prefs.getString('signup_gender');
              }
              // Use a FutureBuilder to prefill before showing dialog
              return FutureBuilder(
                future: prefill(),
                builder: (context, snapshot) {
                  return AlertDialog(
                    title: const Text('Complete Profile'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                          TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Mobile Number')),
                          TextField(controller: dobController, decoration: const InputDecoration(labelText: 'Date of Birth (yyyy-MM-dd)')),
                          TextField(controller: aadharController, decoration: const InputDecoration(labelText: 'Aadhar Number')),
                          TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Permanent Address')),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Male'),
                                  value: 'Male',
                                  groupValue: selectedGender,
                                  onChanged: (value) => selectedGender = value,
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Female'),
                                  value: 'Female',
                                  groupValue: selectedGender,
                                  onChanged: (value) => selectedGender = value,
                                ),
                              ),
                            ],
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
                        onPressed: () async {
                          if (nameController.text.isEmpty || phoneController.text.isEmpty || dobController.text.isEmpty || aadharController.text.isEmpty || addressController.text.isEmpty || selectedGender == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                            return;
                          }
                          await supabase.from('patients').insert({
                            'user_id': user.id,
                            'name': nameController.text.trim(),
                            'email': user.email ?? '',
                            'phone': phoneController.text.trim(),
                            'dob': dobController.text.trim(),
                            'aadhar_number': aadharController.text.trim(),
                            'permanent_address': addressController.text.trim(),
                            'gender': selectedGender,
                          });
                          // Clear shared_preferences after saving
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('signup_name');
                          await prefs.remove('signup_email');
                          await prefs.remove('signup_phone');
                          await prefs.remove('signup_dob');
                          await prefs.remove('signup_aadhar');
                          await prefs.remove('signup_address');
                          await prefs.remove('signup_gender');
                          Navigator.pop(context);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  );
                },
              );
            },
          );
          // Re-fetch patient after insert
          patient = await supabase
              .from('patients')
              .select()
              .eq('user_id', user.id)
              .single();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => PatientDashboardScreen(userName: patient?['name'] ?? ''),
          ),
              (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed! Please check credentials')),
        );
      }
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();
    bool isLoading = false;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Forgot Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: true,
                decoration: const InputDecoration(
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'ll send you a password reset link to your email address.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
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
                      final email = emailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your email address')),
                        );
                        return;
                      }
                      
                      // Basic email validation
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid email address')),
                        );
                        return;
                      }
                      
                      setState(() => isLoading = true);
                      final supabase = Supabase.instance.client;
                      try {
                        // Use proper redirect URL for password reset
                        await supabase.auth.resetPasswordForEmail(
                          email,
                          redirectTo: kIsWeb
                              ? 'http://localhost:5173/reset-password'
                              : 'carehive://reset-password',
                        );
                        
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password reset email sent to $email! Please check your inbox and spam folder.'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      } on AuthException catch (e) {
                        if (!mounted) return;
                        String errorMessage = 'Failed to send reset email. ';
                        String detailedMessage = '';
                        
                        if (e.message.toLowerCase().contains('rate limit') || 
                            e.message.toLowerCase().contains('too many requests')) {
                          errorMessage = 'Rate limit exceeded. ';
                          detailedMessage = 'Please wait 15-30 minutes before trying again, or contact support if you need immediate assistance.';
                        } else if (e.message.toLowerCase().contains('not found') || 
                                   e.message.toLowerCase().contains('user not found')) {
                          errorMessage = 'Email not found. ';
                          detailedMessage = 'This email address is not registered in our system. Please check the email address or sign up for a new account.';
                        } else if (e.message.toLowerCase().contains('invalid email')) {
                          errorMessage = 'Invalid email format. ';
                          detailedMessage = 'Please enter a valid email address.';
                        } else if (e.message.toLowerCase().contains('disabled') || 
                                   e.message.toLowerCase().contains('not allowed')) {
                          errorMessage = 'Email sending disabled. ';
                          detailedMessage = 'Password reset emails are temporarily disabled. Please contact support for assistance.';
                        } else {
                          detailedMessage = e.message;
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (detailedMessage.isNotEmpty) 
                                  Text(detailedMessage, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 8),
                            action: SnackBarAction(
                              label: 'Dismiss',
                              textColor: Colors.white,
                              onPressed: () {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              },
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Network error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      } finally {
                        setState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send'),
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
        child: ListView(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Hello!',
              style: TextStyle(
                fontSize: 28,
                color: Color(0xFF2260FF),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to SERECHI By SR CareHive',
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
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              enableInteractiveSelection: true,
              decoration: InputDecoration(
                hintText: 'example@example.com',
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
            // Google Sign-In Button
            OutlinedButton.icon(
              onPressed: _handleGoogleSignIn,
              icon: const GoogleLogoWidget(size: 18),
              label: const Text(
                'Login with Google',
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
