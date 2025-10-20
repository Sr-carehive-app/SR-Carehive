import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/patient/reset_password_screen.dart';
import 'screens/patient/patient_dashboard_screen.dart';
import 'screens/patient/patient_signup_screen.dart';
import 'screens/patient/appointments_screen.dart' as patient_pages;
import 'screens/patient/schedule_nurse_screen.dart';
import 'screens/patient/profile/profile_screen.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'config/api_config.dart';

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
  
  // Log API configuration for debugging
  ApiConfig.logConfig();
  
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
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    
    print('🔗 Deep link received: $uri');
    
    // Handle OAuth callback - Manually process the OAuth code
    if (uri.host == 'login-callback' && uri.queryParameters.containsKey('code')) {
      try {
        print('📲 OAuth callback detected with code');
        
        // Manually handle the OAuth callback with the full URL
        await supabase.auth.getSessionFromUrl(uri);
        
        print('✅ Session established from URL');
        
        final session = supabase.auth.currentSession;
        final user = supabase.auth.currentUser;
        
        print('👤 Current user: ${user?.email}');
        print('🔐 Session exists: ${session != null}');
        
        if (user != null) {
          // Check if patient record exists
          final patient = await supabase
              .from('patients')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();
          
          print('📋 Patient record: ${patient != null ? "Found" : "Not found"}');
          
          if (patient != null) {
            // Existing user - go to dashboard
            print('🚀 Navigating to dashboard');
            if (mounted) {
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => PatientDashboardScreen(userName: patient['name'] ?? ''),
                ),
                (route) => false,
              );
            }
          } else {
            // New Google sign-up user - redirect to signup page with pre-filled data
            print('📝 Navigating to signup');
            if (mounted) {
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => PatientSignUpScreen(
                    prefillData: {
                      'name': user.userMetadata?['full_name'] ?? '',
                      'email': user.email ?? '',
                      'dob': user.userMetadata?['birthdate'] ?? '',
                      'gender': user.userMetadata?['gender'] ?? '',
                    },
                  ),
                ),
                (route) => false,
              );
            }
          }
        } else {
          print('❌ No user found after OAuth - session establishment failed');
        }
      } catch (e) {
        print('❌ Error handling OAuth callback: $e');
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
      navigatorKey: navigatorKey,
      title: 'Care Hive',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      routes: {
        '/home': (_) => const PatientDashboardScreen(),
        // Keep legacy route but prefer using /home with initialIndex
        '/appointments': (_) => const patient_pages.AppointmentsScreen(),
        '/schedule': (_) => const ScheduleNurseScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
      home: _homeWidget,
    );
  }
}
