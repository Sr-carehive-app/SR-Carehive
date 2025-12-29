import 'package:flutter/material.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'refund_request_screen.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import 'help_center_screen.dart';

class MenuScreen extends StatelessWidget {
  final VoidCallback? onBackToHome;

  const MenuScreen({Key? key, this.onBackToHome}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2260FF);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBackToHome ?? () => Navigator.pop(context),
        ),
        title: const Text('Menu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildMenuOption(context, Icons.info_outline, 'About Serechi', const AboutScreen()),
          _buildMenuOption(context, Icons.assignment_return, 'Ask for Refund', const RefundRequestScreen()),
          _buildMenuOption(context, Icons.article, 'Terms & Conditions', const TermsConditionsScreen()),
          _buildMenuOption(context, Icons.privacy_tip, 'Privacy Policy', const PrivacyPolicyScreen()),
          _buildMenuOption(context, Icons.settings, 'Settings', const SettingsScreen()),
          _buildMenuOption(context, Icons.help, 'Help', const HelpCenterScreen()),
        ],
      ),
    );
  }

  Widget _buildMenuOption(BuildContext context, IconData icon, String title, Widget? nextPage) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2260FF)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        if (nextPage != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => nextPage),
          );
        }
      },
    );
  }
}
