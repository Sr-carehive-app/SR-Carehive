import 'package:flutter/material.dart';
import 'dart:async';
import 'register_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _navigated = false;
  
  @override
  void initState() {
    super.initState();
    // CRITICAL FIX: Prevent navigation if main.dart session check replaces this screen
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _navigated) return;
      
      // Double-check we're still the current route before navigating
      // If main.dart found a session, it would have replaced this screen via setState
      _navigated = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RegisterScreen()),
      );
    });
  }
  
  @override
  void deactivate() {
    // Mark as navigated if being deactivated (replaced by another screen)
    _navigated = true;
    super.deactivate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: const Color(0xFF2260FF),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/images/logo.png', width: 110, height: 110),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Serechi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Compassionate Care, Connected Community',
                  style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.08,
            left: screenWidth * 0.05,
            right: screenWidth * 0.05,
            child: Text(
              'Serechi by SR CareHive is a healthcare facilitator platform that helps patients and families connect with verified healthcare workers for non-emergency care, home care, and health support services.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: screenWidth < 600 ? 12 : (screenWidth < 1200 ? 14 : 16),
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
