import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:care12/data/indian_cities.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final primaryColor = const Color(0xFF2260FF);
  
  // Controllers for split name fields
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  
  // Controllers for phone numbers with country code
  final TextEditingController aadharLinkedPhoneController = TextEditingController();
  final TextEditingController alternativePhoneController = TextEditingController();
  
  // Controllers for detailed address (6 fields)
  final TextEditingController houseNumberController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController townController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  
  // Other controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  // New age controller - we will show Age instead of DOB
  final TextEditingController ageController = TextEditingController();
  final TextEditingController aadharController = TextEditingController();
  
  String? selectedSalutation;
  String? selectedGender;
  String selectedCountryCode = '+91';
  bool isLoading = true;
  bool isUpdating = false;
  bool isUploadingImage = false;
  bool _aadharValid = false;
  bool _aadharTouched = false;
  bool isOAuthUser = false; // Track if user signed in via OAuth
  bool _isStateAutoFilled = false; // Track if state was auto-filled from city dropdown
  
  // Profile image
  String? profileImageUrl;
  File? selectedImageFile;
  Uint8List? selectedImageBytes;
  final ImagePicker _picker = ImagePicker();
  
  // Salutation options
  final List<String> salutationOptions = ['Mr.', 'Mrs.', 'Ms.', 'Dr.', 'Prof.', 'Master', 'Miss'];
  
  // Country codes with phone number lengths
  final List<Map<String, dynamic>> countryCodes = [
    {'code': '+91', 'country': 'India', 'length': 10},
    {'code': '+1', 'country': 'USA', 'length': 10},
    {'code': '+44', 'country': 'UK', 'length': 10},
    {'code': '+971', 'country': 'UAE', 'length': 9},
    {'code': '+61', 'country': 'Australia', 'length': 9},
    {'code': '+65', 'country': 'Singapore', 'length': 8},
  ];
  
  // Helper methods for dynamic phone validation
  int getPhoneNumberLength() {
    final country = countryCodes.firstWhere(
      (c) => c['code'] == selectedCountryCode,
      orElse: () => {'code': '+91', 'country': 'India', 'length': 10},
    );
    return country['length'] as int;
  }

  String getPhonePlaceholder() {
    final length = getPhoneNumberLength();
    return 'X' * length;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Aadhar validation method
  bool validateAadharFormat(String aadhar) {
    // Remove spaces, dashes, and other non-digit characters
    String clean = aadhar.replaceAll(RegExp(r'[^\d]'), '');
    
    // Check if exactly 12 digits
    if (clean.length != 12) return false;
    
    // Check if all characters are digits
    if (!RegExp(r'^\d{12}$').hasMatch(clean)) return false;
    
    // Check if not all same digits (like 111111111111)
    if (RegExp(r'^(\d)\1{11}$').hasMatch(clean)) return false;
    
    // Check if not starting with 0 (UIDAI rules - Aadhar cannot start with 0)
    if (clean.startsWith('0')) return false;
    
    // Basic validation passed - this is a valid Aadhar format
    return true;
  }

  // Verhoeff algorithm implementation for Aadhar checksum
  bool _verhoeffChecksum(String number) {
    int c = 0;
    List<int> num = number.split('').map((e) => int.parse(e)).toList();
    
    // Multiplication table
    List<List<int>> d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
    ];
    
    // Permutation table
    List<List<int>> p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]
    ];
    
    // Inverse table
    List<int> inv = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9];
    
    for (int i = num.length - 1; i >= 0; i--) {
      c = d[c][p[((num.length - i) % 8)][num[i]]];
    }
    
    return inv[c] == 0;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    aadharLinkedPhoneController.dispose();
    alternativePhoneController.dispose();
    houseNumberController.dispose();
    streetController.dispose();
    townController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    emailController.dispose();
  dobController.dispose();
  ageController.dispose();
    aadharController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // PRIORITY 1: Check Auth session FIRST (active login has priority)
      if (user != null) {
        print('[EDIT_PROFILE] Auth user detected: ${user.id}');
        isOAuthUser = user.appMetadata['provider'] != null && user.appMetadata['provider'] != 'email';
        
        final patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .single();
        
        setState(() {
          _loadPatientData(patient);
          isLoading = false;
        });
      } else {
        // PRIORITY 2: Fallback to phone session only if NO Auth session
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        final loginType = prefs.getString('loginType');
        
        if (phone != null && loginType == 'phone') {
          print('[EDIT_PROFILE] Phone-only user detected: $phone');
          
          final patient = await supabase
              .from('patients')
              .select()
              .eq('aadhar_linked_phone', phone)
              .single();
          
          setState(() {
            isOAuthUser = false; // Phone users are not OAuth
            _loadPatientData(patient);
            isLoading = false;
          });
        } else {
          // No valid session found
          print('[EDIT_PROFILE] ERROR: No valid user session found');
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Helper method to load patient data (reduces code duplication)
  void _loadPatientData(Map<String, dynamic> patient) {
    // Load salutation
    selectedSalutation = patient['salutation'];
    
    // Load split name fields (with fallback to legacy name field)
    if (patient['first_name'] != null) {
      firstNameController.text = patient['first_name'] ?? '';
      middleNameController.text = patient['middle_name'] ?? '';
      lastNameController.text = patient['last_name'] ?? '';
    } else if (patient['name'] != null) {
      // Fallback: split legacy name field
      final nameParts = (patient['name'] as String).split(' ');
      firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
      lastNameController.text = nameParts.length > 1 ? nameParts.last : '';
      if (nameParts.length > 2) {
        middleNameController.text = nameParts.sublist(1, nameParts.length - 1).join(' ');
      }
    }
    
    // Load phone fields
    selectedCountryCode = patient['country_code'] ?? '+91';
    aadharLinkedPhoneController.text = patient['aadhar_linked_phone'] ?? patient['phone'] ?? '';
    alternativePhoneController.text = patient['alternative_phone'] ?? '';
    
    // Load address fields (street removed from visible form)
    houseNumberController.text = patient['house_number'] ?? '';
    // keep streetController for backward compatibility but do not populate it from DB to avoid schema issues
    townController.text = patient['town'] ?? '';
    cityController.text = patient['city'] ?? '';
    stateController.text = patient['state'] ?? '';
    pincodeController.text = patient['pincode'] ?? '';
    
    // Load other fields
    emailController.text = patient['email'] ?? '';
    // Load age if available (new preferred field).
    ageController.text = patient['age'] != null ? patient['age'].toString() : '';
    aadharController.text = patient['aadhar_number'] ?? '';
    selectedGender = patient['gender'];
    profileImageUrl = patient['profile_image_url'];
  }

  Future<void> _showImageOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2260FF)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Avatar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            selectedImageBytes = bytes;
            selectedImageFile = null;
          });
        } else {
          setState(() {
            selectedImageFile = File(image.path);
            selectedImageBytes = null;
          });
        }
        await _uploadImage(image);
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to select image. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    setState(() { isUploadingImage = true; });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // Delete old image from Storage if exists
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
        try {
          final oldFileName = profileImageUrl!.split('/').last.split('?').first;
          await supabase.storage.from('profile-images').remove([oldFileName]);
        } catch (e) {
          print('Error deleting old image from Storage: $e');
        }
      }
      
      // Update database
      if (user != null) {
        // Auth users - update by user_id
        await supabase.from('patients').update({'profile_image_url': null}).eq('user_id', user.id);
      } else {
        // Phone-only users - update by phone
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        if (phone != null) {
          await supabase.from('patients').update({'profile_image_url': null}).eq('aadhar_linked_phone', phone);
        }
      }
      
      setState(() { 
        profileImageUrl = null;
        selectedImageFile = null;
        selectedImageBytes = null;
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removed successfully!')),
      );
      
      // Navigate back and trigger callback
      Navigator.pop(context, true);
    } catch (e) {
      print('Error removing avatar: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove profile photo. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() { isUploadingImage = false; });
    }
  }

  Future<void> _uploadImage(XFile image) async {
    setState(() {
      isUploadingImage = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // Delete old image if exists
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
        try {
          final oldFileName = profileImageUrl!.split('/').last.split('?').first;
          await supabase.storage.from('profile-images').remove([oldFileName]);
        } catch (e) {
          print('Could not delete old image: $e');
        }
      }
      
      // Generate unique filename (fix for web blob URLs)
      String fileExtension = 'jpg'; // Default to jpg
      if (kIsWeb) {
        // For web, try to get extension from image name or default to jpg
        final imageName = image.name;
        if (imageName.contains('.')) {
          fileExtension = imageName.split('.').last.toLowerCase();
        }
      } else {
        // For mobile, use path
        fileExtension = image.path.split('.').last.split('?').first;
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Generate filename based on user type
      String fileName;
      if (user != null) {
        final cleanUserId = user.id.replaceAll('-', '').substring(0, 12);
        fileName = 'avatar_${cleanUserId}_$timestamp.$fileExtension';
      } else {
        // Phone-only user - use phone number
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone') ?? 'unknown';
        final cleanPhone = phone.replaceAll('+', '').substring(phone.length > 10 ? phone.length - 10 : 0);
        fileName = 'avatar_phone_${cleanPhone}_$timestamp.$fileExtension';
      }
      
      String imageUrl = '';
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await supabase.storage
            .from('profile-images')
            .uploadBinary(fileName, bytes, fileOptions: FileOptions(cacheControl: '3600', upsert: true));
        imageUrl = supabase.storage
            .from('profile-images')
            .getPublicUrl(fileName);
      } else {
        await supabase.storage
            .from('profile-images')
            .upload(fileName, File(image.path), fileOptions: FileOptions(cacheControl: '3600', upsert: true));
        imageUrl = supabase.storage
            .from('profile-images')
            .getPublicUrl(fileName);
      }
      
      // Update database
      if (user != null) {
        // Auth users - update by user_id
        await supabase
            .from('patients')
            .update({'profile_image_url': imageUrl})
            .eq('user_id', user.id);
      } else {
        // Phone-only users - update by phone
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        if (phone != null) {
          await supabase
              .from('patients')
              .update({'profile_image_url': imageUrl})
              .eq('aadhar_linked_phone', phone);
        }
      }
      
      setState(() {
        profileImageUrl = imageUrl;
        selectedImageFile = null;
        selectedImageBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully!')),
      );
    } catch (e) {
      print('Error uploading image: $e');
      String userMessage = 'Failed to upload photo. Please try again.';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        userMessage = 'Network error. Please check your internet connection.';
      } else if (errorStr.contains('size') || errorStr.contains('large')) {
        userMessage = 'Image is too large. Please select a smaller image.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isUploadingImage = false;
      });
    }
  }

  // Date picker removed - we collect numeric Age only in the UI.

  Future<String?> _showPasswordConfirmationDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirm Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To add email to your account, please enter your current password:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, passwordController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2260FF),
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfile() async {
    // Validate required fields
    if (firstNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your first name')),
      );
      return;
    }
    
    if (lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your last name')),
      );
      return;
    }
    
    if (aadharLinkedPhoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }
    
    // Validate phone number length
    final requiredLength = getPhoneNumberLength();
    if (aadharLinkedPhoneController.text.trim().length != requiredLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number must be $requiredLength digits for $selectedCountryCode')),
      );
      return;
    }
    
    // Validate alternative phone if provided
    if (alternativePhoneController.text.trim().isNotEmpty) {
      if (alternativePhoneController.text.trim().length != requiredLength) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alternative phone must be $requiredLength digits for $selectedCountryCode')),
        );
        return;
      }
      
      // Validate alternative phone is different from primary phone
      if (alternativePhoneController.text.trim() == aadharLinkedPhoneController.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alternative phone number must be different from primary phone number'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    
    // Validate Aadhar number if provided
    if (aadharController.text.isNotEmpty && !validateAadharFormat(aadharController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Aadhar number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate email format if provided
    if (emailController.text.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(emailController.text.trim())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid email address'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      isUpdating = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // Build full name from parts (for ALL users - Auth + Phone)
      String fullName = firstNameController.text.trim();
      if (middleNameController.text.trim().isNotEmpty) {
        fullName += ' ${middleNameController.text.trim()}';
      }
      fullName += ' ${lastNameController.text.trim()}';
      
      final newEmail = emailController.text.trim().isNotEmpty 
          ? emailController.text.trim().toLowerCase() 
          : null;
      
      // CRITICAL FIX: Handle email updates for ALL user types
      // SCENARIOS:
      // 1. Phone-only user (user == null) adding email → Just update patients table
      // 2. Email user (user != null) changing email → Update Auth email + patients table
      // 3. OAuth users → Skip Auth email update (email managed by provider)
      
      if (!isOAuthUser && newEmail != null && user != null) {
        // SCENARIO 2: Email user changing existing email
        final currentAuthEmail = user.email;
        
        if (currentAuthEmail != null && currentAuthEmail != newEmail) {
          try {
            // Use backend Admin API to update email without confirmation
            final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
            final response = await http.post(
              Uri.parse('$apiBase/api/admin/update-user-email'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': user.id,
                'new_email': newEmail,
              }),
            );
            
            if (response.statusCode != 200) {
              final errorData = json.decode(response.body);
              throw Exception(errorData['error'] ?? 'Failed to update email');
            }
            
            print('[PROFILE-UPDATE] ✅ Email user - Auth email updated: $currentAuthEmail → $newEmail');
          } catch (authError) {
            print('[PROFILE-UPDATE] ⚠️ Failed to update Auth email: $authError');
            if (!mounted) return;
            setState(() {
              isUpdating = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to update email: ${authError.toString().contains('duplicate') ? 'This email is already in use' : 'Please try again'}'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }
      }
      
      // Build update data (same for both Auth and phone-only users)
      final updateData = {
        // Salutation
        'salutation': selectedSalutation,
        
        // Split name fields
        'first_name': firstNameController.text.trim(),
        'middle_name': middleNameController.text.trim(),
        'last_name': lastNameController.text.trim(),
        'name': fullName, // Keep legacy field
        
        // Email (CRITICAL: Allow phone-only users to add email later)
        'email': newEmail,
        
        // Phone fields
        'country_code': selectedCountryCode,
        'aadhar_linked_phone': aadharLinkedPhoneController.text.trim(),
        'alternative_phone': alternativePhoneController.text.trim().isNotEmpty 
            ? alternativePhoneController.text.trim() 
            : null,
        
        // Address fields
        'house_number': houseNumberController.text.trim(),
        // 'street' removed from form by design; keep column unchanged if present
        'town': townController.text.trim(),
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'pincode': pincodeController.text.trim(),
        
        // Other fields - prefer storing age (new). Do not write legacy 'dob' column (it may have been dropped).
        'age': ageController.text.isNotEmpty ? int.tryParse(ageController.text.trim()) : null,
        'aadhar_number': aadharController.text.trim(),
        'gender': selectedGender,
      };
      
      // Determine how to update: by user_id (Auth users) or phone (phone-only users)
      if (user != null) {
        // ========== AUTH USERS (Email/OAuth) ==========
        // Update database using user_id
        print('[PROFILE-UPDATE] 📧 Updating Auth user profile: ${user.id}');
        await supabase.from('patients').update(updateData).eq('user_id', user.id);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      } else {
        // ========== PHONE-ONLY USERS ==========
        // Phone-only user - update by phone number
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        if (phone == null) throw Exception('Phone session not found');
        
        print('[PROFILE-UPDATE] 📱 Updating phone-only user profile: $phone');
        
        // ⚠️ CRITICAL: If phone-only user is adding email for first time, create Supabase Auth account
        // Check if this user already has user_id (shouldn't happen, but safety check)
        final existingPatient = await supabase
            .from('patients')
            .select('user_id, password_hash, email')
            .eq('aadhar_linked_phone', phone)
            .single();
        
        final hasUserId = existingPatient['user_id'] != null;
        final oldEmail = existingPatient['email'];
        final passwordHash = existingPatient['password_hash'];
        
        // ⚠️ CRITICAL: Handle email updates for phone users with/without Auth account
        if (newEmail != null && newEmail.isNotEmpty) {
          if (!hasUserId) {
            // ========== SCENARIO 1: Phone user adding email for FIRST TIME (no Auth account yet) ==========
            print('[PROFILE-UPDATE] 🔑 Phone-only user (no user_id) adding email - creating Supabase Auth account');
            
            // Check if password_hash exists (it should for phone-only users)
            if (passwordHash == null || passwordHash.isEmpty) {
              throw Exception('Cannot create auth account: No password set. Please set a password first.');
            }
            
            // We need the original password to create Auth account, but we only have password_hash
            // Solution: Ask user to set/confirm password when adding email
            if (!mounted) return;
            
            // Show dialog to get password
            final password = await _showPasswordConfirmationDialog();
            
            if (password == null || password.isEmpty) {
              if (!mounted) return;
              setState(() {
                isUpdating = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password required to add email. Please try again.'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            
            // Verify password against password_hash
            try {
              final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
              final verifyResponse = await http.post(
                Uri.parse('$apiBase/api/verify-password-hash'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'phone': phone,
                  'password': password,
                }),
              );
              
              if (verifyResponse.statusCode != 200) {
                throw Exception('Incorrect password');
              }
              
              // Password verified - create Supabase Auth account
              print('[PROFILE-UPDATE] ✅ Password verified, creating Auth account...');
              
              // Check if email already exists in Auth
              try {
                final authResponse = await supabase.auth.signUp(
                  email: newEmail,
                  password: password,
                );
                
                if (authResponse.user == null) {
                  throw Exception('Failed to create auth account - no user returned');
                }
                
                final newUserId = authResponse.user!.id;
                print('[PROFILE-UPDATE] ✅ Auth account created successfully!');
                print('[PROFILE-UPDATE] 📧 Email: $newEmail');
                print('[PROFILE-UPDATE] 🆔 New user_id: $newUserId');
                
                // Update updateData to include new user_id
                updateData['user_id'] = newUserId;
                
                // ✅ DON'T sign out - it causes white screen and breaks UI
                // User will continue with phone session, can login with email anytime
                print('[PROFILE-UPDATE] ✅ user_id added, phone session continues');
                
              } catch (signUpError) {
                print('[PROFILE-UPDATE] ❌ Auth signUp error: $signUpError');
                // If email already exists, it might be because of duplicate attempt
                if (signUpError.toString().toLowerCase().contains('already registered') ||
                    signUpError.toString().toLowerCase().contains('duplicate')) {
                  print('[PROFILE-UPDATE] ⚠️ Email already exists in Auth - this is OK if retrying');
                  // Don't throw error, continue with database update
                  // The email might be registered but user_id not linked yet
                } else {
                  throw signUpError;
                }
              }
              
            } catch (authError) {
              print('[PROFILE-UPDATE] ❌ Failed to create Auth account: $authError');
              if (!mounted) return;
              setState(() {
                isUpdating = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add email: ${authError.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          } else if (hasUserId && oldEmail != null && oldEmail != newEmail) {
            // ========== SCENARIO 2: Phone user UPDATING email (Auth account already exists) ==========
            print('[PROFILE-UPDATE] 📧 Phone user with Auth account updating email: $oldEmail → $newEmail');
            
            try {
              // Update Auth email via backend Admin API
              final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
              final response = await http.post(
                Uri.parse('$apiBase/api/admin/update-user-email'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode({
                  'user_id': existingPatient['user_id'],
                  'new_email': newEmail,
                }),
              );
              
              if (response.statusCode != 200) {
                final errorData = json.decode(response.body);
                throw Exception(errorData['error'] ?? 'Failed to update email in Auth');
              }
              
              print('[PROFILE-UPDATE] ✅ Auth email updated successfully: $oldEmail → $newEmail');
            } catch (emailUpdateError) {
              print('[PROFILE-UPDATE] ❌ Failed to update Auth email: $emailUpdateError');
              if (!mounted) return;
              setState(() {
                isUpdating = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update email: ${emailUpdateError.toString().contains('duplicate') ? 'This email is already in use' : 'Please try again'}'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }
        }
        
        // Update patients table
        await supabase.from('patients').update(updateData).eq('aadhar_linked_phone', phone);
        
        // Check if we just created an Auth account
        final authAccountCreated = updateData.containsKey('user_id') && updateData['user_id'] != null;
        
        // ✅ CRITICAL FIX: Update SharedPreferences if phone number changed
        final newPhone = aadharLinkedPhoneController.text.trim();
        if (phone != newPhone) {
          await prefs.setString('phone', newPhone);
          print('[PROFILE-UPDATE] ✅ Updated phone in SharedPreferences: $phone → $newPhone');
        }
        
        if (!mounted) return;
        
        // Show success message
        if (authAccountCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile updated! You can now login with email & password.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      }
      
      Navigator.pop(context, true); // Return true to indicate profile was updated
    } catch (e) {
      if (!mounted) return;
      
      // Convert technical database errors to user-friendly messages
      String userMessage = 'Failed to update profile. Please try again.';
      
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('duplicate') && errorStr.contains('aadhar_linked_phone')) {
        userMessage = 'This phone number is already registered with another account. Please use a different number.';
      } else if (errorStr.contains('duplicate') && errorStr.contains('email')) {
        userMessage = 'This email is already registered with another account. Please use a different email.';
      } else if (errorStr.contains('duplicate') && errorStr.contains('aadhar_number')) {
        userMessage = 'This Aadhar number is already registered. Please verify your details.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        userMessage = 'Network error. Please check your internet connection and try again.';
      } else if (errorStr.contains('timeout')) {
        userMessage = 'Request timed out. Please try again.';
      } else if (errorStr.contains('invalid') && errorStr.contains('phone')) {
        userMessage = 'Invalid phone number format. Please enter a valid 10-digit number.';
      } else if (errorStr.contains('invalid') && errorStr.contains('email')) {
        userMessage = 'Invalid email format. Please enter a valid email address.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          backgroundColor: const Color(0xFF2260FF),
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF2260FF),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: selectedImageBytes != null
                      ? MemoryImage(selectedImageBytes!)
                      : selectedImageFile != null
                          ? FileImage(selectedImageFile!)
                          : (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                              ? NetworkImage(profileImageUrl!) as ImageProvider
                              : const AssetImage('assets/images/user.png') as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: isUploadingImage ? null : _showImageOptions,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: primaryColor,
                      child: isUploadingImage
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.edit, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Name Section - Salutation and Split into 3 fields
          const Text('Name *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          
          // Salutation Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Salutation', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: selectedSalutation,
                  hint: const Text('Select Salutation'),
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: salutationOptions.map((salutation) {
                    return DropdownMenuItem<String>(
                      value: salutation,
                      child: Text(salutation, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedSalutation = value);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          
          buildTextField('First Name', 'Enter first name', firstNameController, isRequired: true),
          buildTextField('Middle Name (Optional)', 'Enter middle name', middleNameController),
          buildTextField('Last Name', 'Enter last name', lastNameController, isRequired: true),
          
          const Divider(thickness: 1),
          const SizedBox(height: 16),
          
          // Email (Read-only for OAuth users, optional for others)
          buildTextField(
            isOAuthUser ? 'Email' : 'Email (Optional)',
            'Enter your email',
            emailController,
            isReadOnly: isOAuthUser,
          ),
          
          // Aadhar Linked Phone Number with Country Code
          const Text('Aadhar Linked Phone Number *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              // Country Code Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: selectedCountryCode,
                  underline: const SizedBox(),
                  items: countryCodes.map((code) {
                    return DropdownMenuItem<String>(
                      value: code['code'] as String,
                      child: Text('${code['code']} ${code['country']}', style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedCountryCode = value!);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Phone Number Field
              Expanded(
                child: TextField(
                  key: ValueKey(selectedCountryCode),
                  controller: aadharLinkedPhoneController,
                  keyboardType: TextInputType.phone,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(getPhoneNumberLength()),
                  ],
                  decoration: InputDecoration(
                    hintText: getPhonePlaceholder(),
                    filled: true,
                    fillColor: const Color(0xFFEDEFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Alternative Phone Number
          const Text('Alternative Phone Number (Optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              // Country Code Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<String>(
                  value: selectedCountryCode,
                  underline: const SizedBox(),
                  items: countryCodes.map((code) {
                    return DropdownMenuItem<String>(
                      value: code['code'] as String,
                      child: Text('${code['code']} ${code['country']}', style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedCountryCode = value!);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Alternative Phone Field
              Expanded(
                child: TextField(
                  key: ValueKey('alt_$selectedCountryCode'),
                  controller: alternativePhoneController,
                  keyboardType: TextInputType.phone,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableInteractiveSelection: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(getPhoneNumberLength()),
                  ],
                  decoration: InputDecoration(
                    hintText: getPhonePlaceholder(),
                    filled: true,
                    fillColor: const Color(0xFFEDEFFF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Age (replaces Date of Birth input)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Age', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                decoration: InputDecoration(
                  hintText: 'Enter your age',
                  filled: true,
                  fillColor: const Color(0xFFEDEFFF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          
          // Aadhar Number with Validation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Aadhar Number (Optional)', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: aadharController,
                keyboardType: TextInputType.number,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                onChanged: (value) {
                  setState(() {
                    _aadharTouched = true;
                    _aadharValid = validateAadharFormat(value);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Enter your Aadhar number',
                  filled: true,
                  fillColor: const Color(0xFFEDEFFF),
                  suffixIcon: _aadharTouched 
                    ? (_aadharValid 
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                        : const Icon(Icons.error, color: Colors.red, size: 20))
                    : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              if (_aadharTouched && !_aadharValid && aadharController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Please enter a valid 12-digit Aadhar number',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
          
          // Address Section - 6 detailed fields
          const Text('Address Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          buildTextField('House/Flat Number (Optional)', 'Enter house/flat number', houseNumberController),
          buildTextField('Town/Village/Locality (Optional)', 'Enter town/village/locality', townController),
          
          // City field with autocomplete
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('City', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return IndianCities.searchCities(textEditingValue.text);
                },
                onSelected: (String selection) {
                  final parsed = IndianCities.parseCityState(selection);
                  setState(() {
                    cityController.text = parsed['city']!;
                    stateController.text = parsed['state']!;
                    _isStateAutoFilled = true; // Mark state as auto-filled
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                  controller.text = cityController.text;
                  controller.selection = TextSelection.collapsed(offset: controller.text.length);
                  
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (value) {
                      cityController.text = value;
                      // If user is typing custom city, allow manual state entry
                      if (_isStateAutoFilled) {
                        setState(() {
                          _isStateAutoFilled = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search city...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: const Icon(Icons.search),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        width: MediaQuery.of(context).size.width - 48,
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            final parsed = IndianCities.parseCityState(option);
                            return ListTile(
                              title: Text(
                                parsed['city']!,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                parsed['state']!,
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              onTap: () {
                                onSelected(option);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
          
          buildTextField(
            'State', 
            _isStateAutoFilled ? 'Auto-filled from city' : 'Enter state manually', 
            stateController, 
            isReadOnly: _isStateAutoFilled
          ),
          buildTextField('Pincode', 'Enter pincode', pincodeController, keyboardType: TextInputType.number),
          
          const SizedBox(height: 8),
          buildGenderField(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isUpdating ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: isUpdating 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text('Update Profile', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(String label, String hint, TextEditingController controller, {bool isRequired = false, bool isReadOnly = false, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isRequired) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isReadOnly,
          keyboardType: keyboardType,
          autocorrect: false,
          enableSuggestions: false,
          enableInteractiveSelection: true,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isReadOnly ? Colors.grey[200] : const Color(0xFFEDEFFF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // buildDateField removed; DOB input replaced by numeric Age field.

  Widget buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Male'),
                value: 'Male',
                groupValue: selectedGender,
                onChanged: (value) => setState(() => selectedGender = value),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Female'),
                value: 'Female',
                groupValue: selectedGender,
                onChanged: (value) => setState(() => selectedGender = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
