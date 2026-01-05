import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/utils/safe_navigation.dart';
import 'edit_profile_screen.dart';
import 'view_profile_details_screen.dart';
import 'package:care12/screens/splash_screen.dart'; // update import if needed
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  final String? userName;
  final VoidCallback? onProfileUpdated; // Add callback parameter
  final VoidCallback? onBackToHome; // Add back to home callback
  
  const ProfileScreen({Key? key, this.userName, this.onProfileUpdated, this.onBackToHome}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? profileImageUrl;
  String? userName;
  bool isLoading = true;
  bool isUploadingImage = false;
  final ImagePicker _picker = ImagePicker();
  File? selectedImageFile;
  Uint8List? selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      Map<String, dynamic>? patient;
      
      if (user != null) {
        // Auth users (email/OAuth) - query by user_id
        patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .single();
      } else {
        // Phone-only users - query by phone
        print('[PROFILE] No Auth user - checking for phone-only user');
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        
        if (phone != null) {
          print('[PROFILE] Phone-only user: $phone');
          patient = await supabase
              .from('patients')
              .select()
              .eq('aadhar_linked_phone', phone)
              .single();
        }
      }
      
      if (patient != null) {
        // Build full name from parts if available, otherwise use legacy name field
        String displayName = patient!['name'] ?? widget.userName;
        final salutation = patient!['salutation'] ?? '';
        
        if (patient!['first_name'] != null) {
          displayName = patient!['first_name'];
          if (patient!['middle_name'] != null && patient!['middle_name'].toString().isNotEmpty) {
            displayName += ' ${patient!['middle_name']}';
          }
          if (patient!['last_name'] != null) {
            displayName += ' ${patient!['last_name']}';
          }
        }
        
        // Add salutation prefix if available
        if (salutation.isNotEmpty) {
          displayName = '$salutation $displayName';
        }
        
        setState(() {
          profileImageUrl = patient!['profile_image_url'] as String?;
          userName = displayName;
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

  Future<void> _showImageOptions() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16,
            vertical: isTablet ? 20 : 16,
          ),
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF2260FF)),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(fontSize: isTablet ? 16 : 15),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Remove Avatar',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isTablet ? 16 : 15,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAvatar();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: Text(
                  'Cancel',
                  style: TextStyle(fontSize: isTablet ? 16 : 15),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewProfilePicture() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: selectedImageBytes != null
                    ? Image.memory(selectedImageBytes!, fit: BoxFit.contain)
                    : selectedImageFile != null
                        ? Image.file(selectedImageFile!, fit: BoxFit.contain)
                        : (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                            ? Image.network(profileImageUrl!, fit: BoxFit.contain)
                            : Image.asset('assets/images/user.png', fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() { selectedImageBytes = bytes; selectedImageFile = null; });
        } else {
          setState(() { selectedImageFile = File(image.path); selectedImageBytes = null; });
        }
        await _uploadImage(image);
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to select image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      
      // Update database to remove avatar URL
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
      
      // Notify parent (Dashboard) to refresh
      if (widget.onProfileUpdated != null) {
        widget.onProfileUpdated!();
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removed successfully!')),
      );
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
    setState(() { isUploadingImage = true; });
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
      
      // Fix file extension extraction for web (avoid blob URLs)
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
        await supabase.from('patients').update({'profile_image_url': imageUrl}).eq('user_id', user.id);
      } else {
        // Phone-only users - update by phone
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('phone');
        if (phone != null) {
          await supabase.from('patients').update({'profile_image_url': imageUrl}).eq('aadhar_linked_phone', phone);
        }
      }
      
      setState(() { 
        profileImageUrl = imageUrl;
        selectedImageFile = null;
        selectedImageBytes = null;
      });
      
      // Notify parent (Dashboard) to refresh
      if (widget.onProfileUpdated != null) {
        widget.onProfileUpdated!();
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile picture updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error uploading image: $e');
      print('Error type: ${e.runtimeType}');
      if (!mounted) return;
      
      String errorMessage = 'Error uploading image: $e';
      if (e.toString().contains('403') || e.toString().contains('Unauthorized')) {
        errorMessage = 'Permission denied. Please check storage policies in Supabase.';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Bucket not found. Please create "profile-images" bucket.';
      } else if (e.toString().contains('storage')) {
        errorMessage = 'Storage error. Please check Supabase Storage configuration.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() { isUploadingImage = false; });
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete your account?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ This action cannot be undone!',
                      style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• All your data will be permanently deleted\n• You will be logged out immediately\n• You cannot recover your account',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user found'), backgroundColor: Colors.red),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting account...'),
            ],
          ),
        ),
      );

      // Delete patient record and related data first
      await supabase.from('patients').delete().eq('user_id', user.id);
      
      // Call your existing server endpoint to delete user from Supabase Auth
      final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
      final response = await http.post(
        Uri.parse('$apiBase/api/admin/delete-user'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': user.id}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete user from auth: ${response.body}');
      }
      
     
      Navigator.of(context).pop();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to splash screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
      
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      print('Error deleting account: $e');
      String userMessage = 'Failed to delete account. Please try again.';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        userMessage = 'Network error. Please check your internet connection and try again.';
      } else if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
        userMessage = 'Session expired. Please login again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red[400]!, width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to logout?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will be logged out from your account',
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Logging out...'),
            ],
          ),
        ),
      );

      // Sign out from Supabase Auth (for email/OAuth users)
      await Supabase.instance.client.auth.signOut();
      
      // CRITICAL: Also clear phone-only user session from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('phone');
      await prefs.remove('loginType');
      print('✅ Phone session cleared from SharedPreferences');
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // Navigate to splash screen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      print('Error during logout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logout failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2260FF);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBackToHome ?? () => SafeNavigation.pop(context, debugLabel: 'profile_back'),
        ),
        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => _viewProfilePicture(),
                        child: Hero(
                          tag: 'profile_picture',
                          child: ClipOval(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                              ),
                              child: selectedImageBytes != null
                                  ? Image.memory(
                                      selectedImageBytes!,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                    )
                                  : selectedImageFile != null
                                      ? Image.file(
                                          selectedImageFile!,
                                          fit: BoxFit.cover,
                                          width: 100,
                                          height: 100,
                                        )
                                      : (profileImageUrl != null && profileImageUrl!.isNotEmpty)
                                          ? Image.network(
                                              profileImageUrl!,
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    value: loadingProgress.expectedTotalBytes != null
                                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                        : null,
                                                  ),
                                                );
                                              },
                                              errorBuilder: (context, error, stackTrace) {
                                                return Image.asset('assets/images/user.png', fit: BoxFit.cover);
                                              },
                                            )
                                          : Image.asset(
                                              'assets/images/user.png',
                                              fit: BoxFit.cover,
                                              width: 100,
                                              height: 100,
                                            ),
                            ),
                          ),
                        ),
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
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    userName ?? widget.userName ?? 'User',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                buildProfileOption(context, Icons.visibility, 'View Profile', const ViewProfileDetailsScreen()),
                buildProfileOption(context, Icons.edit, 'Edit Profile', const EditProfileScreen()),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF2260FF)),
                  title: const Text('Logout'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    _showLogoutConfirmationDialog();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    _showDeleteAccountDialog();
                  },
                ),
              ],
            ),
    );
  }

  Widget buildProfileOption(BuildContext context, IconData icon, String title, Widget? nextPage) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2260FF)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: () {
        if (nextPage != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => nextPage)).then((_) {
            _loadProfileData();
            // Notify parent (Dashboard) to refresh
            if (widget.onProfileUpdated != null) {
              widget.onProfileUpdated!();
            }
          });
        }
      },
    );
  }
}
