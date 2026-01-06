import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'schedule_nurse_screen.dart';
import 'appointments_screen.dart';
import 'package:care12/screens/patient/profile/profile_screen.dart';
import 'package:care12/screens/patient/profile/menu_screen.dart';
import 'package:care12/screens/patient/profile/settings_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  final String? userName;
  final int initialIndex;

  const PatientDashboardScreen({Key? key, this.userName, this.initialIndex = 0}) : super(key: key);

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0; // Track previous tab
  int _backPressCount = 0; // Track consecutive back presses
  String? profileImageUrl;
  String? userName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _previousIndex = 0; // Default to Home
    _backPressCount = 0;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // CRITICAL FIX: Support both Auth users AND phone-only users
      Map<String, dynamic>? patient;
      
      // PRIORITY 1: Check Auth session FIRST (active login has priority)
      if (user != null) {
        print('[DASHBOARD] Auth user detected: ${user.id}');
        patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .single();
      } else {
        // PRIORITY 2: Fallback to phone session only if NO Auth session
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        final loginType = prefs.getString('loginType');
        
        if (phone != null && loginType == 'phone') {
          print('[DASHBOARD] Phone-only user detected: $phone');
          patient = await supabase
              .from('patients')
              .select()
              .eq('aadhar_linked_phone', phone)
              .single();
        }
      }
      
      if (patient != null) {
        setState(() {
          profileImageUrl = patient!['profile_image_url'];
          // Include salutation with name if available
          final salutation = patient!['salutation'] ?? '';
          final name = patient!['name'] ?? widget.userName;
          userName = salutation.isNotEmpty ? '$salutation $name' : name;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _handleBackButton() {
    setState(() {
      // If already on Home, do nothing
      if (_currentIndex == 0) return;
      
      _backPressCount++; // Increment back press counter
      
      // First back press: Go to previous tab
      if (_backPressCount == 1) {
        int temp = _currentIndex;
        _currentIndex = _previousIndex;
        _previousIndex = temp;
      } 
      // Second back press: Always go to Home
      else {
        _previousIndex = _currentIndex;
        _currentIndex = 0;
        _backPressCount = 0; // Reset counter after going home
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2260FF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(context, primaryColor),
          AppointmentsScreen(onBackToHome: _handleBackButton), // Use smart back handler
          ScheduleNurseScreen(onBackToHome: _handleBackButton), // Use smart back handler
          ProfileScreen(
            userName: userName ?? widget.userName,
            onProfileUpdated: _loadProfileData, // Add callback
            onBackToHome: _handleBackButton, // Use smart back handler
          ),
          MenuScreen(onBackToHome: _handleBackButton),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _previousIndex = _currentIndex; // Save current as previous before switching
            _currentIndex = index;
            _backPressCount = 0; // Reset back press counter on manual tab switch
          });
          // Refresh profile data when navigating to Home tab
          if (index == 0) {
            _loadProfileData();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Care Requests'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Care Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, Color primaryColor) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
            child: Row(
              children: [
                  GestureDetector(
                    onTap: () {
                      // Navigate to Profile tab within the dashboard
                      setState(() {
                        _currentIndex = 3;
                      });
                      // Refresh profile data when opening profile
                      _loadProfileData();
                    },
                    child: CircleAvatar(
                      radius: 28,
                      backgroundImage: (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                          ? NetworkImage(profileImageUrl!)
                          : const AssetImage('assets/images/user.png') as ImageProvider,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Hi, Welcome Back',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        userName ?? widget.userName ?? 'User',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = 1; // Navigate to Appointments tab
                    });
                  },
                  child: Icon(Icons.notifications, color: primaryColor),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  child: Icon(Icons.settings, color: primaryColor),
                ),
              ],
            ),
          ),

          // Services title with branding
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2260FF).withOpacity(0.05),
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Serechi',
                      style: TextStyle(
                        color: const Color(0xFF2260FF),
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2260FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'by SR CareHive',
                        style: TextStyle(
                          color: const Color(0xFF2260FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Our services',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Services list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                buildServiceCard(
                  context,
                  title: 'Request Care Support',
                  subtitle: 'Professional home care',
                  image: 'assets/images/nurse.png',
                  onTap: () {
                    setState(() {
                      _currentIndex = 2; // Switch to Schedule tab within dashboard
                    });
                  },
                ),
                const SizedBox(height: 12),
                buildServiceCard(
                  context,
                  title: 'My Care Requests',
                  subtitle: 'View your scheduled care',
                  image: 'assets/images/logo.png',
                  onTap: () {
                    setState(() {
                      _currentIndex = 1; // Switch to Appointments tab within dashboard
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildServiceCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required String image,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFEDEFFF),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: AssetImage(image),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFF2260FF), fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        onTap: onTap,
      ),
    );
  }
}
