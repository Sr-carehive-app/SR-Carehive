import 'package:flutter/material.dart';
import 'notification_settings_screen.dart';
import 'password_manager_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          buildSettingsOption(context, Icons.notifications, 'Notification Setting', const NotificationSettingsScreen()),
          buildSettingsOption(context, Icons.lock, 'Password Manager', const PasswordManagerScreen()),

        ],
      ),
    );
  }

  Widget buildSettingsOption(BuildContext context, IconData icon, String title, Widget? nextPage) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2260FF)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        if (nextPage != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => nextPage));
        }
      },
    );
  }
}
