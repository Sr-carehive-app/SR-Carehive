import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/patient/reset_password_screen.dart';
import 'screens/patient/patient_dashboard_screen.dart';
import 'screens/patient/patient_signup_screen.dart';
import 'screens/patient/appointments_screen.dart' as patient_pages;
import 'package:app_links/app_links.dart';
import 'dart:async';

class ErrorScreen extends StatelessWidget {
  final String error;
  final String? description;
  const ErrorScreen({Key? key, required this.error, this.description}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error, style: const TextStyle(color: Colors.red, fontSize: 20)),
            if (description != null) ...[
              const SizedBox(height: 16),
              Text(description!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _homeWidget = const SplashScreen();
  StreamSubscription? _sub;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLink();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user != null) {
      // User is already logged in, check if they have a patient record
      try {
        final patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        
        if (patient != null) {
          setState(() {
            _homeWidget = PatientDashboardScreen(userName: patient['name'] ?? '');
          });
        }
      } catch (e) {
        print('Error checking patient record: $e');
      }
    }
  }

  Future<void> _initDeepLink() async {
    // Listen for incoming deep links
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) async {
      if (uri != null) {
        await _handleIncomingLink(uri);
      }
    }, onError: (err) {});

    // Handle initial link if app was opened via deep link
    final initialUri = await _appLinks.getInitialAppLink();
    if (initialUri != null) {
      await _handleIncomingLink(initialUri);
    }
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    final supabase = Supabase.instance.client;
    
    // Handle OAuth callback
    if (uri.queryParameters.containsKey('code') || uri.queryParameters.containsKey('access_token')) {
      try {
        // Handle the OAuth session
        final user = supabase.auth.currentUser;
        if (user != null) {
          // Check if patient record exists
          final patient = await supabase
              .from('patients')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();
          
          if (patient != null) {
            // Existing user - go to dashboard
            setState(() {
              _homeWidget = PatientDashboardScreen(userName: patient['name'] ?? '');
            });
          } else {
            // New Google sign-up user - redirect to signup page with pre-filled data
            setState(() {
              _homeWidget = PatientSignUpScreen(
                prefillData: {
                  'name': user.userMetadata?['full_name'] ?? '',
                  'email': user.email ?? '',
                  'dob': user.userMetadata?['birthdate'] ?? '',
                  'gender': user.userMetadata?['gender'] ?? '',
                },
              );
            });
          }
        }
      } catch (e) {
        print('Error handling OAuth callback: $e');
      }
    }
    
    // Handle password reset
    if ((uri.scheme == 'carehive' && uri.host == 'reset-password' && uri.queryParameters.containsKey('code')) ||
        (uri.path == '/reset-password' && uri.queryParameters.containsKey('code'))) {
      setState(() {
        _homeWidget = const ResetPasswordScreen();
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Care Hive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/appointments': (_) => const patient_pages.AppointmentsScreen(),
      },
      home: _homeWidget,
    );
  }
}
