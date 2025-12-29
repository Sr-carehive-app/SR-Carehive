import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordManagerScreen extends StatefulWidget {
  const PasswordManagerScreen({super.key});

  @override
  State<PasswordManagerScreen> createState() => _PasswordManagerScreenState();
}

class _PasswordManagerScreenState extends State<PasswordManagerScreen> {
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
    
    // Simple password validation - minimum 6 characters
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
    final supabase = Supabase.instance.client;
    
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      print('🔐 Attempting to verify current password for user: ${user.email}');
      
      // Step 1: Re-authenticate with current password to verify it's correct
      try {
        final signInResponse = await supabase.auth.signInWithPassword(
          email: user.email!,
          password: currentPassword,
        );
        
        if (signInResponse.user == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Current password is incorrect'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        print('✅ Current password verified successfully');
      } on AuthException catch (e) {
        print('❌ Password verification failed: ${e.message}');
        if (!mounted) return;
        
        String errorMessage = '❌ Current password is incorrect';
        if (e.message.toLowerCase().contains('invalid')) {
          errorMessage = '❌ Current password is incorrect';
        } else if (e.message.toLowerCase().contains('rate limit')) {
          errorMessage = '❌ Too many attempts. Please try again later';
        } else {
          errorMessage = '❌ ${e.message}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      
      // Step 2: Update password
      print('🔐 Updating password...');
      final response = await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      if (response.user != null) {
        print('✅ Password updated successfully');
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
        print('❌ Password update failed - no user returned');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to change password'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on AuthException catch (e) {
      print('❌ AuthException during password change: ${e.message}');
      if (!mounted) return;
      
      String errorMessage = e.message;
      if (e.message.toLowerCase().contains('same')) {
        errorMessage = 'New password must be different from current password';
      } else if (e.message.toLowerCase().contains('weak')) {
        errorMessage = 'Password is too weak. Please use a stronger password';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $errorMessage'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('❌ Unexpected error: ${e.toString()}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
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
      appBar: AppBar(title: const Text('Password Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
                    '• At least 6 characters long',
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
