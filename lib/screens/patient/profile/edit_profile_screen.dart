import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

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
  final TextEditingController aadharController = TextEditingController();
  
  String? selectedGender;
  String selectedCountryCode = '+91';
  bool isLoading = true;
  bool isUpdating = false;
  bool isUploadingImage = false;
  bool _aadharValid = false;
  bool _aadharTouched = false;
  
  // Profile image
  String? profileImageUrl;
  File? selectedImageFile;
  Uint8List? selectedImageBytes;
  final ImagePicker _picker = ImagePicker();
  
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
    return '9' * length;
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
    aadharController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        final patient = await supabase
            .from('patients')
            .select()
            .eq('user_id', user.id)
            .single();
        
        setState(() {
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
          
          // Load address fields
          houseNumberController.text = patient['house_number'] ?? '';
          streetController.text = patient['street'] ?? '';
          townController.text = patient['town'] ?? '';
          cityController.text = patient['city'] ?? '';
          stateController.text = patient['state'] ?? '';
          pincodeController.text = patient['pincode'] ?? '';
          
          // Load other fields
          emailController.text = patient['email'] ?? '';
          dobController.text = patient['dob'] != null ? patient['dob'] : '';
          aadharController.text = patient['aadhar_number'] ?? '';
          selectedGender = patient['gender'];
          profileImageUrl = patient['profile_image_url'];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        isLoading = false;
      });
    }
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
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _uploadImage(XFile image) async {
    setState(() {
      isUploadingImage = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        // Generate unique filename
        final fileName = 'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String imageUrl = '';
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          await supabase.storage
              .from('profile-images')
              .uploadBinary(fileName, bytes);
          imageUrl = supabase.storage
              .from('profile-images')
              .getPublicUrl(fileName);
        } else {
          await supabase.storage
              .from('profile-images')
              .upload(fileName, File(image.path));
          imageUrl = supabase.storage
              .from('profile-images')
              .getPublicUrl(fileName);
        }
        // Update database
        await supabase
            .from('patients')
            .update({'profile_image_url': imageUrl})
            .eq('user_id', user.id);
        setState(() {
          profileImageUrl = imageUrl;
          selectedImageFile = null;
          selectedImageBytes = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully!')),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    } finally {
      setState(() {
        isUploadingImage = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
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

    setState(() {
      isUpdating = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user != null) {
        // Build full name from parts
        String fullName = firstNameController.text.trim();
        if (middleNameController.text.trim().isNotEmpty) {
          fullName += ' ${middleNameController.text.trim()}';
        }
        fullName += ' ${lastNameController.text.trim()}';
        
        await supabase
            .from('patients')
            .update({
              // Split name fields
              'first_name': firstNameController.text.trim(),
              'middle_name': middleNameController.text.trim(),
              'last_name': lastNameController.text.trim(),
              'name': fullName, // Keep legacy field
              
              // Phone fields
              'country_code': selectedCountryCode,
              'aadhar_linked_phone': aadharLinkedPhoneController.text.trim(),
              'alternative_phone': alternativePhoneController.text.trim().isNotEmpty 
                  ? alternativePhoneController.text.trim() 
                  : null,
              'phone': aadharLinkedPhoneController.text.trim(), // Legacy field
              
              // Address fields
              'house_number': houseNumberController.text.trim(),
              'street': streetController.text.trim(),
              'town': townController.text.trim(),
              'city': cityController.text.trim(),
              'state': stateController.text.trim(),
              'pincode': pincodeController.text.trim(),
              
              // Other fields
              'dob': dobController.text.isNotEmpty ? dobController.text.trim() : null,
              'aadhar_number': aadharController.text.trim(),
              'gender': selectedGender,
            })
            .eq('user_id', user.id);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
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
          title: const Text('Profile', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
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
                    onTap: isUploadingImage ? null : _pickImage,
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
          
          // Name Section - Split into 3 fields
          const Text('Name *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          buildTextField('First Name', 'Enter first name', firstNameController, isRequired: true),
          buildTextField('Middle Name (Optional)', 'Enter middle name', middleNameController),
          buildTextField('Last Name', 'Enter last name', lastNameController, isRequired: true),
          
          const Divider(thickness: 1),
          const SizedBox(height: 16),
          
          // Email (Read-only)
          buildTextField('Email', 'Enter your email', emailController, isReadOnly: true),
          
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
          
          // Date of Birth
          buildDateField('Date Of Birth', 'Select your date of birth', dobController),
          
          // Aadhar Number with Validation
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Aadhar Number', style: const TextStyle(fontWeight: FontWeight.bold)),
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
          buildTextField('House/Flat Number', 'Enter house/flat number', houseNumberController),
          buildTextField('Street/Road', 'Enter street/road name', streetController),
          buildTextField('Town/Village', 'Enter town/village', townController),
          buildTextField('City', 'Enter city', cityController),
          buildTextField('State', 'Enter state', stateController),
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

  Widget buildDateField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: _selectDate,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFEDEFFF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

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
