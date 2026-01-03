import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ProviderProfileEditScreen extends StatefulWidget {
  final Map<String, dynamic> providerData;

  const ProviderProfileEditScreen({
    Key? key,
    required this.providerData,
  }) : super(key: key);

  @override
  State<ProviderProfileEditScreen> createState() => _ProviderProfileEditScreenState();
}

class _ProviderProfileEditScreenState extends State<ProviderProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final primaryColor = const Color(0xFF2260FF);
  bool isSaving = false;

  // Controllers for editable fields
  late TextEditingController fullNameController;
  late TextEditingController primaryMobileController;
  late TextEditingController alternativeMobileController;
  late TextEditingController emailController;
  late TextEditingController cityController;
  late TextEditingController workplaceController;
  late TextEditingController serviceAreasController;
  late TextEditingController homeVisitFeeController;
  late TextEditingController teleconsultationFeeController;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing data
    fullNameController = TextEditingController(text: widget.providerData['full_name'] ?? '');
    primaryMobileController = TextEditingController(text: widget.providerData['mobile_number'] ?? '');
    alternativeMobileController = TextEditingController(text: widget.providerData['alternative_mobile'] ?? '');
    emailController = TextEditingController(text: widget.providerData['email'] ?? '');
    cityController = TextEditingController(text: widget.providerData['city'] ?? '');
    workplaceController = TextEditingController(text: widget.providerData['workplace'] ?? '');
    serviceAreasController = TextEditingController(text: widget.providerData['service_areas'] ?? '');
    homeVisitFeeController = TextEditingController(
      text: widget.providerData['home_visit_fee']?.toString() ?? '',
    );
    teleconsultationFeeController = TextEditingController(
      text: widget.providerData['teleconsultation_fee']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    fullNameController.dispose();
    primaryMobileController.dispose();
    alternativeMobileController.dispose();
    emailController.dispose();
    cityController.dispose();
    workplaceController.dispose();
    serviceAreasController.dispose();
    homeVisitFeeController.dispose();
    teleconsultationFeeController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // CRITICAL VALIDATION: Alternative mobile must be different from primary mobile
    final primaryPhone = primaryMobileController.text.trim();
    final alternativePhone = alternativeMobileController.text.trim();
    
    if (alternativePhone.isNotEmpty && primaryPhone == alternativePhone) {
      Fluttertoast.showToast(
        msg: "Alternative mobile number must be different from primary mobile number",
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final updatedData = {
        'full_name': fullNameController.text.trim(),
        'mobile_number': primaryMobileController.text.trim(),
        'alternative_mobile': alternativeMobileController.text.trim().isEmpty 
            ? null 
            : alternativeMobileController.text.trim(),
        'email': emailController.text.trim().isEmpty 
            ? null 
            : emailController.text.trim(),
        'city': cityController.text.trim(),
        'workplace': workplaceController.text.trim(),
        'service_areas': serviceAreasController.text.trim().isEmpty 
            ? null 
            : serviceAreasController.text.trim(),
        'home_visit_fee': homeVisitFeeController.text.trim().isEmpty 
            ? null 
            : double.tryParse(homeVisitFeeController.text.trim()),
        'teleconsultation_fee': teleconsultationFeeController.text.trim().isEmpty 
            ? null 
            : double.tryParse(teleconsultationFeeController.text.trim()),
      };

      await NurseApiService.updateProviderProfile(updatedData);

      if (mounted) {
        Fluttertoast.showToast(
          msg: "Profile updated successfully!",
          toastLength: Toast.LENGTH_SHORT,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
        Navigator.pop(context, true); // Return true to indicate profile was updated
      }
    } catch (e) {
      if (mounted) {
        // Convert technical errors to user-friendly messages
        String userMessage = 'Failed to update profile. Please try again.';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('duplicate') && errorStr.contains('mobile')) {
          userMessage = 'This mobile number is already registered with another provider.';
        } else if (errorStr.contains('duplicate') && errorStr.contains('email')) {
          userMessage = 'This email is already registered with another provider.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          userMessage = 'Network error. Please check your internet connection.';
        } else if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
          userMessage = 'Session expired. Please login again.';
        } else if (errorStr.contains('invalid') && errorStr.contains('mobile')) {
          userMessage = 'Invalid mobile number format. Please enter a valid 10-digit number.';
        } else if (errorStr.contains('invalid') && errorStr.contains('email')) {
          userMessage = 'Invalid email format. Please enter a valid email address.';
        }
        
        Fluttertoast.showToast(
          msg: userMessage,
          toastLength: Toast.LENGTH_LONG,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can update your contact details and service information. Professional credentials cannot be changed.',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information Section
              _buildSectionHeader('Basic Information', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(
                controller: fullNameController,
                label: 'Full Name',
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: primaryMobileController,
                label: 'Primary Mobile (Aadhar-linked)',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your primary mobile number';
                  }
                  if (value.trim().length != 10) {
                    return 'Mobile number must be 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: alternativeMobileController,
                label: 'Alternative Mobile (Optional)',
                icon: Icons.phone_iphone,
                keyboardType: TextInputType.phone,
                required: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length != 10) {
                      return 'Mobile number must be 10 digits';
                    }
                    // Check if same as primary
                    if (value.trim() == primaryMobileController.text.trim()) {
                      return 'Must be different from primary mobile';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: emailController,
                label: 'Email (Optional)',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                required: false,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: cityController,
                label: 'City',
                icon: Icons.location_city_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your city';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Work Information Section
              _buildSectionHeader('Work Information', Icons.work_outline),
              const SizedBox(height: 16),
              _buildTextField(
                controller: workplaceController,
                label: 'Workplace',
                icon: Icons.apartment_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your workplace';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: serviceAreasController,
                label: 'Service Areas (Optional)',
                icon: Icons.map_outlined,
                required: false,
                maxLines: 2,
                hint: 'e.g., North Delhi, Central Delhi',
              ),
              const SizedBox(height: 24),

              // Fee Information Section
              _buildSectionHeader('Fee Information', Icons.currency_rupee),
              const SizedBox(height: 16),
              _buildTextField(
                controller: homeVisitFeeController,
                label: 'Home Visit Fee (Optional)',
                icon: Icons.home_outlined,
                keyboardType: TextInputType.number,
                required: false,
                prefixText: '₹ ',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final fee = double.tryParse(value.trim());
                    if (fee == null || fee < 0) {
                      return 'Please enter a valid fee';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: teleconsultationFeeController,
                label: 'Teleconsultation Fee (Optional)',
                icon: Icons.videocam_outlined,
                keyboardType: TextInputType.number,
                required: false,
                prefixText: '₹ ',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final fee = double.tryParse(value.trim());
                    if (fee == null || fee < 0) {
                      return 'Please enter a valid fee';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Non-Editable Fields Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.amber[900], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Non-Editable Fields',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Professional credentials (role, qualifications, registration number, etc.) cannot be changed. Contact admin if you need to update these details.',
                      style: TextStyle(
                        color: Colors.amber[900],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
    int maxLines = 1,
    String? hint,
    String? prefixText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryColor),
          prefixText: prefixText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
      ),
    );
  }
}
