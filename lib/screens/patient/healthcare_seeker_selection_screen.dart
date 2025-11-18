import 'package:flutter/material.dart';
import 'patient_login_screen.dart';
import 'patient_signup_screen.dart';

class HealthcareSeekerSelectionScreen extends StatelessWidget {
  const HealthcareSeekerSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Heading
                const Text(
                  'Hello Healthcare Seeker!',
                  style: TextStyle(
                    fontSize: 28,
                    color: Color(0xFF2260FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle
                const Text(
                  'Welcome to Serechi',
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF2260FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 50),
                
                // New User Card
                _buildSelectionCard(
                  context: context,
                  title: 'New to Serechi?',
                  description: 'Create a new account to access\nour healthcare services',
                  buttonText: 'Register to Continue',
                  buttonColor: const Color(0xFF2260FF),
                  buttonTextColor: Colors.white,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatientSignUpScreen(),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Existing User Card
                _buildSelectionCard(
                  context: context,
                  title: 'Already a User?',
                  description: 'Please log in here to continue\naccessing your healthcare services',
                  buttonText: 'Log In',
                  buttonColor: const Color(0xFFCAD6FF),
                  buttonTextColor: const Color(0xFF2260FF),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatientLoginScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required BuildContext context,
    required String title,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required Color buttonTextColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            
            // Card Description
            Text(
              description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            
            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  buttonText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: buttonTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
