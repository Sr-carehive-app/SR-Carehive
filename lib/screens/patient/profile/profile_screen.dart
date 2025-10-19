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
      
      final bytes = await image.readAsBytes();
      final fileExtension = image.path.split('.').last.split('?').first; // Clean extension
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanUserId = user.id.replaceAll('-', '').substring(0, 12); // Shorten UUID
      final fileName = 'avatar_${cleanUserId}_$timestamp.$fileExtension';
      
      // Upload with upsert to overwrite if exists
      await supabase.storage.from('profile-images').uploadBinary(
        fileName, 
        bytes, 
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: 'image/$fileExtension', // Explicit content type
        ),
      );
      
      final imageUrl = supabase.storage.from('profile-images').getPublicUrl(fileName);
      
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
      if (!mounted) return;
      
      String errorMessage = 'Error uploading image';
      if (e.toString().contains('403') || e.toString().contains('Unauthorized')) {
        errorMessage = 'Permission denied. Please check storage policies in Supabase.';
      } else if (e.toString().contains('404')) {
        errorMessage = 'Bucket not found. Please create "profile-images" bucket.';
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
                buildProfileOption(context, Icons.info_outline, 'About SERECHI', const AboutScreen()),
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
