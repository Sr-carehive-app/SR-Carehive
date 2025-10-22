import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';
import 'refund_request_screen.dart';
import 'help_center_screen.dart';
import 'about_screen.dart';
import 'package:care12/screens/splash_screen.dart'; // update import if needed
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  final String? userName;
  final VoidCallback? onProfileUpdated; // Add callback parameter
  
  const ProfileScreen({Key? key, this.userName, this.onProfileUpdated}) : super(key: key);

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
      if (user != null) {
        final patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .single();
        
        // Build full name from parts if available, otherwise use legacy name field
        String displayName = patient['name'] ?? widget.userName;
        if (patient['first_name'] != null) {
          displayName = patient['first_name'];
          if (patient['middle_name'] != null && patient['middle_name'].toString().isNotEmpty) {
            displayName += ' ${patient['middle_name']}';
          }
          if (patient['last_name'] != null) {
            displayName += ' ${patient['last_name']}';
          }
        }
        
        setState(() {
          profileImageUrl = patient['profile_image_url'];
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
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
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
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() { isUploadingImage = true; });
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
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
      await supabase.from('patients').update({'profile_image_url': null}).eq('user_id', user.id);
      
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
        SnackBar(content: Text('Error removing avatar: $e')),
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
      if (user == null) return;
      
      // Delete old image if exists
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
        try {
          final oldFileName = profileImageUrl!.split('/').last.split('?').first;
          await supabase.storage.from('profile-images').remove([oldFileName]);
        } catch (e) {
          print('Could not delete old image: $e');
        }
      }
      
      final fileExtension = image.path.split('.').last.split('?').first; // Clean extension
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanUserId = user.id.replaceAll('-', '').substring(0, 12); // Shorten UUID
      final fileName = 'avatar_${cleanUserId}_$timestamp.$fileExtension';
      
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
      await supabase.from('patients').update({'profile_image_url': imageUrl}).eq('user_id', user.id);
      
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
      final response = await http.post(
        Uri.parse('https://sr-carehive.vercel.app/api/admin/delete-user'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': user.id}),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete user from auth: ${response.body}');
      }
      
      // Close loading dialog
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF2260FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 20),
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
                buildProfileOption(context, Icons.person, 'Profile', const EditProfileScreen()),
                buildProfileOption(context, Icons.info_outline, 'About Serechi', const AboutScreen()),
                buildProfileOption(context, Icons.assignment_return, 'Ask for Refund', const RefundRequestScreen()),
                buildProfileOption(context, Icons.article, 'Terms & Conditions', const TermsConditionsScreen()),
                buildProfileOption(context, Icons.privacy_tip, 'Privacy Policy', const PrivacyPolicyScreen()),
                buildProfileOption(context, Icons.settings, 'Settings', const SettingsScreen()),
                buildProfileOption(context, Icons.help, 'Help', const HelpCenterScreen()),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF2260FF)),
                  title: const Text('Logout'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                          (route) => false,
                    );
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
