import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProviderPasswordManagerScreen extends StatefulWidget {
  const ProviderPasswordManagerScreen({super.key});

  @override
  State<ProviderPasswordManagerScreen> createState() => _ProviderPasswordManagerScreenState();
}

class _ProviderPasswordManagerScreenState extends State<ProviderPasswordManagerScreen> {
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();
    
    // Validation
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Password validation - minimum 6 characters
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Password must be at least 6 characters long'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ New passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (currentPassword == newPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ New password must be different from current password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Get provider session token from SharedPreferences (same key as NurseApiService)
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('nurse_auth_token');
      
      if (sessionToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Not logged in. Please login again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      print('🔐 Calling backend provider password change API');
      
      // Call backend API (handles both email and phone-only providers)
      final response = await http.post(
        Uri.parse('${dotenv.env['API_BASE_URL']}/api/provider/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Password changed successfully');
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Password changed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();
      } else {
        // Parse error message from backend
        String errorMessage = 'Failed to change password';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (parseError) {
          print('⚠️ Failed to parse error response: $parseError');
          errorMessage = 'Server error. Please try again.';
        }
        
        print('❌ Password change failed (${response.statusCode}): $errorMessage');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Unexpected error: ${e.toString()}');
      if (!mounted) return;
      String userMessage = 'Failed to change password. Please try again.';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        userMessage = 'Network error. Please check your internet connection.';
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2260FF);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
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
                    children: [
                      Icon(Icons.info_outline, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Password Requirements',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• At least 6 characters long\n• Different from your current password',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildPasswordField('Current Password', currentPasswordController, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
            _buildPasswordField('New Password', newPasswordController, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
            _buildPasswordField('Confirm New Password', confirmPasswordController, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2260FF)))
                  : ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Change Password',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(String hint, TextEditingController controller, bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFEDEFFF),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: toggle,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
