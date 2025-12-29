import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final Map<String, String> fieldMap = {
    'General Notification': 'general_notification',
    'Sound': 'sound',
    'Sound Call': 'sound_call',
    'Vibrate': 'vibrate',
    'Special Offers': 'special_offers',
    'Payments': 'payments',
    'Promo And Discount': 'promo_and_discount',
    'Cashback': 'cashback',
  };

  Map<String, bool> settings = {
    'General Notification': true,
    'Sound': true,
    'Sound Call': true,
    'Vibrate': false,
    'Special Offers': false,
    'Payments': true,
    'Promo And Discount': true,
    'Cashback': true,
  };

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => isLoading = false);
      return;
    }
    // Get user name and email from patients table
    final patient = await supabase
        .from('patients')
        .select('name, email')
        .eq('user_id', user.id)
        .maybeSingle();
    final name = patient?['name'] ?? '';
    final email = patient?['email'] ?? user.email ?? '';
    // Try to fetch notification settings
    final record = await supabase
        .from('notification_settings')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (record != null) {
      setState(() {
        for (final entry in fieldMap.entries) {
          settings[entry.key] = record[entry.value] ?? settings[entry.key]!;
        }
        isLoading = false;
      });
    } else {
      // Insert default settings for this user
      final insertData = {
        'user_id': user.id,
        'name': name,
        'email': email,
        ...fieldMap.map((k, v) => MapEntry(v, settings[k])),
      };
      await supabase.from('notification_settings').insert(insertData);
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => isSaving = true);
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final updateData = {
      ...fieldMap.map((k, v) => MapEntry(v, settings[k])),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await supabase.from('notification_settings').update(updateData).eq('user_id', user.id);
    setState(() => isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Setting', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF2260FF),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: settings.keys.map((key) {
                      return SwitchListTile(
                        title: Text(key),
                        value: settings[key]!,
                        activeColor: const Color(0xFF2260FF),
                        onChanged: (val) {
                          setState(() => settings[key] = val);
                        },
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2260FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Settings',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
