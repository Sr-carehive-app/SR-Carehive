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
import 'package:flutter/foundation.dart';
import 'dart:html' as html; // web-only diagnostics (used behind kIsWeb guard)
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
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    final supabase = Supabase.instance.client;
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      
      print('🔄 Auth state changed: $event');
      
      if (event == AuthChangeEvent.signedOut) {
        print('👤 User signed out, returning to splash screen');
        setState(() {
          _homeWidget = const SplashScreen();
        });
      } else if (event == AuthChangeEvent.signedIn && session?.user != null) {
        print('✅ User signed in: ${session?.user.email}');
        _handlePostAuthRedirect(session!.user);
      }
    });
  }

  Future<void> _handlePostAuthRedirect(User user) async {
    final supabase = Supabase.instance.client;
    
    print('🔄 _handlePostAuthRedirect called for user: ${user.email}');
    
    try {
      // Check if patient record exists
      final patient = await supabase
          .from('patients')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
      print('Patient record: ${patient != null ? "Found" : "Not found"}');
      
      if (patient != null) {
        // Existing user - go to dashboard
        print('🔄 Navigating to dashboard for existing user');
        if (mounted) {
          setState(() {
            _homeWidget = PatientDashboardScreen(userName: patient['name'] ?? '');
          });
          
          // Also try navigator push for immediate navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => PatientDashboardScreen(userName: patient['name'] ?? ''),
              ),
              (route) => false,
            );
          });
        }
        } else {
          // User is NOT registered in DB - redirect to register page with message
          print('📝 User not registered - redirecting to register page');
          print('📝 Setting _homeWidget to PatientSignUpScreen');
          if (mounted) {
          final prefillData = <String, String>{
            'name': user.userMetadata?['full_name'] ?? '',
            'email': user.email ?? '',
            if (user.userMetadata?['birthdate'] != null && user.userMetadata?['birthdate'].isNotEmpty)
              'age': (() {
                try {
                  final birth = DateTime.parse(user.userMetadata!['birthdate']);
                  final now = DateTime.now();
                  final years = now.year - birth.year - ((now.month < birth.month || (now.month == birth.month && now.day < birth.day)) ? 1 : 0);
                  return years.toString();
                } catch (_) {
                  return '';
                }
              })(),
            'gender': user.userMetadata?['gender'] ?? '',
            'google_avatar_url': user.userMetadata?['avatar_url'] ?? '', // Store Google avatar URL
          };
          
          setState(() {
            _homeWidget = PatientSignUpScreen(
              prefillData: prefillData,
              showRegistrationMessage: true, // Show "Please register your account to continue" message
            );
          });
          
          // Also try navigator push for immediate navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => PatientSignUpScreen(
                  prefillData: prefillData,
                  showRegistrationMessage: true,
                ),
              ),
              (route) => false,
            );
          });
        }
      }
    } catch (e) {
      print('❌ Error handling post-auth redirect: $e');
    }
  }

  Future<void> _checkAuthState() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    print('🔍 Checking auth state for user: ${user?.email}');
    
    if (user != null) {
      // User is already logged in, check if they have a healthcare seeker record
      try {
        final patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        
        print('Patient record found: ${patient != null}');
        
        if (patient != null) {
          print('🔄 Setting home widget to dashboard');
          setState(() {
            _homeWidget = PatientDashboardScreen(userName: patient['name'] ?? '');
          });
        } else {
          print('📝 No patient record found, staying on splash screen');
        }
      } catch (e) {
        print('❌ Error checking healthcare seeker record: $e');
      }
    } else {
      print('👤 No authenticated user found');
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

    // On web, AppLinks may not provide an initial URI, so check the browser URL directly
    if (kIsWeb) {
      final webUri = Uri.base;
      print('🌐 Web URI: $webUri');
      if (webUri.queryParameters.containsKey('code') || webUri.queryParameters.containsKey('access_token')) {
        print('🔗 OAuth callback detected in initial URL');
        await _handleIncomingLink(webUri);
      }
      
      // Also check for Supabase hosted callback redirects
      if (webUri.path.contains('/auth/v1/callback') || webUri.queryParameters.containsKey('code')) {
        print('🔗 Supabase callback detected');
        await _handleIncomingLink(webUri);
      }
    }
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    final supabase = Supabase.instance.client;
    
    print('Deep link received: $uri');
    
    // Handle OAuth callback - Manually process the OAuth code
    // Accept Supabase /auth/v1/callback (e.g. http://localhost:5173/auth/v1/callback?code=...)
    // or any incoming link that contains an OAuth code or access_token (may be in fragment)
    // Merge query and fragment parameters (some providers put tokens in the URL fragment)
    final Map<String, String> mergedParams = {};
    mergedParams.addAll(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      try {
        mergedParams.addAll(Uri.splitQueryString(uri.fragment));
      } catch (_) {
        // ignore parse errors
      }
    }

    if (mergedParams.containsKey('code') || mergedParams.containsKey('access_token')) {
      try {
        print('OAuth callback detected with code');
        
        // Check if user is already authenticated (from auth state change)
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          print('✅ User already authenticated: ${currentUser.email}');
          // Skip session establishment and proceed with navigation
          await _handlePostAuthRedirect(currentUser);
          return;
        }
        
        print('🔍 No authenticated user found, proceeding with session establishment');
        
        // On web, use the current browser URL to ensure proper PKCE handling
        final callbackUri = kIsWeb ? Uri.base : uri;
        
        if (kIsWeb) {
          print('URI queryParameters: ${uri.queryParameters}');
          print('URI fragment: ${uri.fragment}');
          print('Merged params: $mergedParams');
          print('Callback URI passed to getSessionFromUrl: $callbackUri');
          
          // Log localStorage for debugging
          try {
            final keys = html.window.localStorage.keys;
            print('LocalStorage keys: $keys');
          } catch (_) {}
        }
        
        // Try to establish session from URL
        try {
          await supabase.auth.getSessionFromUrl(callbackUri);
          print('✅ Session established from URL');
        } on AuthException catch (err) {
          print('❌ AuthException: ${err.message}');
          
          // If PKCE code_verifier missing, try alternative approaches
          final msg = err.message?.toLowerCase() ?? '';
          if (kIsWeb && msg.contains('code verifier') && msg.contains('could not be found')) {
            print('Code verifier missing - attempting bypass strategy');
            
            // Bypass PKCE by using the auth state change event that already fired
            // The user is already signed in (we saw AuthChangeEvent.signedIn)
            // Just proceed with the current user
            print('🔄 Bypassing PKCE - using existing auth state');
            
            // Check if user is already authenticated
            final currentUser = supabase.auth.currentUser;
            if (currentUser != null) {
              print('✅ User already authenticated: ${currentUser.email}');
              // Don't rethrow - proceed with the authenticated user
            } else {
              print('❌ No authenticated user found despite auth state change');
              rethrow;
            }
          } else {
            rethrow;
          }
        }
        
        // Get the current session and user
        final session = supabase.auth.currentSession;
        final user = supabase.auth.currentUser;
        
        print('Current user: ${user?.email}');
        print('Session exists: ${session != null}');
        
        if (user != null) {
          // Check if patient record exists
          final patient = await supabase
              .from('patients')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();
          
          print('Patient record: ${patient != null ? "Found" : "Not found"}');
          
          if (patient != null) {
            // Existing user - go to dashboard
            print('🔄 Navigating to dashboard for existing user');
            if (mounted) {
              setState(() {
                _homeWidget = PatientDashboardScreen(userName: patient['name'] ?? '');
              });
              
              // Also try navigator push for immediate navigation
              WidgetsBinding.instance.addPostFrameCallback((_) {
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => PatientDashboardScreen(userName: patient['name'] ?? ''),
                  ),
                  (route) => false,
                );
              });
            }
          } else {
            // New Google sign-up user - redirect to signup page with pre-filled data
            print('📝 Navigating to signup for new user');
            if (mounted) {
              final prefillData = <String, String>{
                'name': user.userMetadata?['full_name'] ?? '',
                'email': user.email ?? '',
                if (user.userMetadata?['birthdate'] != null && user.userMetadata?['birthdate'].isNotEmpty)
                  'age': (() {
                    try {
                      final birth = DateTime.parse(user.userMetadata!['birthdate']);
                      final now = DateTime.now();
                      final years = now.year - birth.year - ((now.month < birth.month || (now.month == birth.month && now.day < birth.day)) ? 1 : 0);
                      return years.toString();
                    } catch (_) {
                      return '';
                    }
                  })(),
                'gender': user.userMetadata?['gender'] ?? '',
              };
              
              setState(() {
                _homeWidget = PatientSignUpScreen(prefillData: prefillData);
              });
              
              // Also try navigator push for immediate navigation
              WidgetsBinding.instance.addPostFrameCallback((_) {
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => PatientSignUpScreen(prefillData: prefillData),
                  ),
                  (route) => false,
                );
              });
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
      title: 'Serechi',
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
