import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:care12/services/provider_email_service.dart';
import 'package:care12/screens/nurse/provider_application_status_screen.dart';
import 'package:care12/utils/safe_navigation.dart';

class HealthcareProviderRegistrationScreen extends StatefulWidget {
  const HealthcareProviderRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<HealthcareProviderRegistrationScreen> createState() => _HealthcareProviderRegistrationScreenState();
}

class _HealthcareProviderRegistrationScreenState extends State<HealthcareProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  
  // Section A: Basic Information
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController alternativeMobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  String? selectedProfessionalRole;
  final TextEditingController otherProfessionController = TextEditingController();
  final TextEditingController doctorSpecialtyController = TextEditingController();
  
  final TextEditingController qualificationController = TextEditingController();
  final TextEditingController completionYearController = TextEditingController();
  final TextEditingController registrationNumberController = TextEditingController();
  
  final TextEditingController currentRoleController = TextEditingController();
  final TextEditingController workplaceController = TextEditingController();
  final TextEditingController experienceYearsController = TextEditingController();
  
  // Section B: Service Preferences
  final Map<String, bool> selectedServices = {
    'Teleconsultation': false,
    'Home Visits': false,
    'Chronic Disease Home Care': false,
    'Elderly Care & Companionship': false,
    'Post-operative / Post-acute Care': false,
    'Mental Health Counselling': false,
    'Yoga/Wellness Sessions (Home/Online)': false,
    'Physiotherapy': false,
    'Clinical Psychology': false,
    'Rehabilitation Services': false,
    'Palliative Care': false,
  };
  
  final Map<String, bool> availability = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };
  
  final Map<String, bool> timeSlots = {
    'Morning (6 AM - 12 PM)': false,
    'Afternoon (12 PM - 5 PM)': false,
    'Evening (5 PM - 9 PM)': false,
    'Night (9 PM - 6 AM)': false,
    'Flexible': false,
  };
  
  final TextEditingController communityExperienceController = TextEditingController();
  
  final Map<String, bool> languages = {
    'Hindi': false,
    'English': false,
    'Garhwali': false,
    'Kumaoni': false,
    'Punjabi': false,
    'Bengali': false,
    'Marathi': false,
    'Tamil': false,
    'Telugu': false,
    'Gujarati': false,
    'Kannada': false,
    'Malayalam': false,
    'Urdu': false,
  };
  final TextEditingController otherLanguagesController = TextEditingController();
  
  final TextEditingController serviceAreasController = TextEditingController();
  final TextEditingController homeVisitFeeController = TextEditingController();
  final TextEditingController teleconsultationFeeController = TextEditingController();
  
  // Section C: Consent & Compliance
  bool agreedToDeclaration = false;
  bool agreedToDataPrivacy = false;
  bool agreedToProfessionalResponsibility = false;
  bool agreedToTerms = false;
  bool agreedToCommunication = false;

  final List<String> professionalRoles = [
    'Doctor',
    'Nurse',
    'Physiotherapist',
    'Clinical Psychologist',
    'Yoga/Wellness Instructor',
    'Dietitian/Nutritionist',
    'Occupational Therapist',
    'Speech Therapist',
    'Medical Social Worker',
    'Pharmacist',
    'Lab Technician',
    'Radiographer',
    'Other Allied Health Professional',
  ];

  final List<String> doctorSpecialties = [
    'General Physician',
    'Cardiologist',
    'Neurologist',
    'Orthopedic',
    'Pediatrician',
    'Dermatologist',
    'Gynecologist',
    'Psychiatrist',
    'ENT Specialist',
    'Ophthalmologist',
    'Urologist',
    'Gastroenterologist',
    'Pulmonologist',
    'Endocrinologist',
    'Oncologist',
    'Nephrologist',
    'Rheumatologist',
    'General Surgeon',
    'Other Specialty',
  ];

  @override
  void dispose() {
    fullNameController.dispose();
    mobileController.dispose();
    alternativeMobileController.dispose();
    emailController.dispose();
    cityController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otherProfessionController.dispose();
    doctorSpecialtyController.dispose();
    qualificationController.dispose();
    completionYearController.dispose();
    registrationNumberController.dispose();
    currentRoleController.dispose();
    workplaceController.dispose();
    experienceYearsController.dispose();
    communityExperienceController.dispose();
    otherLanguagesController.dispose();
    serviceAreasController.dispose();
    homeVisitFeeController.dispose();
    teleconsultationFeeController.dispose();
    super.dispose();
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if email already exists
  Future<bool> _checkEmailExists(String email) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('healthcare_providers')
          .select('email')
          .eq('email', email.trim())
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Check if mobile already exists
  Future<bool> _checkMobileExists(String mobile) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('healthcare_providers')
          .select('mobile_number')
          .eq('mobile_number', mobile.trim())
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _submitForm() async {
    // Enable auto-validation after first attempt
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
    
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate at least one service is selected
    if (!selectedServices.values.any((element) => element)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service you wish to provide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate at least one availability day
    if (!availability.values.any((element) => element)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one availability day'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate at least one time slot
    if (!timeSlots.values.any((element) => element)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one time slot'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate at least one language
    if (!languages.values.any((element) => element) && otherLanguagesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate all checkboxes
    if (!agreedToDeclaration || !agreedToDataPrivacy || !agreedToProfessionalResponsibility || 
        !agreedToTerms || !agreedToCommunication) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to all terms and conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Validate alternative mobile is different from primary mobile
    if (alternativeMobileController.text.trim().isNotEmpty && 
        alternativeMobileController.text.trim() == mobileController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alternative mobile number must be different from primary mobile number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate password match
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if email already exists (only if email is provided)
      if (emailController.text.trim().isNotEmpty) {
        final emailExists = await _checkEmailExists(emailController.text.trim());
        if (emailExists) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This email is already registered. Please use a different email.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Check if mobile already exists
      final mobileExists = await _checkMobileExists(mobileController.text.trim());
      if (mobileExists) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This mobile number is already registered. Please use a different number.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final supabase = Supabase.instance.client;

      // Hash the password
      final hashedPassword = _hashPassword(passwordController.text);

      // Prepare selected services list
      final servicesList = selectedServices.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Prepare availability days list
      final availabilityList = availability.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Prepare time slots list
      final timeSlotsList = timeSlots.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      // Prepare languages list
      final languagesList = languages.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      if (otherLanguagesController.text.trim().isNotEmpty) {
        languagesList.addAll(otherLanguagesController.text.split(',').map((e) => e.trim()));
      }

      // Prepare provider data for email
      final providerDataForEmail = {
        'full_name': fullNameController.text.trim(),
        'mobile_number': mobileController.text.trim(),
        'alternative_mobile': alternativeMobileController.text.trim().isEmpty 
            ? 'Not provided' 
            : alternativeMobileController.text.trim(),
        'email': emailController.text.trim(),
        'city': cityController.text.trim(),
        'professional_role': selectedProfessionalRole,
        'other_profession': selectedProfessionalRole == 'Other Allied Health Professional' 
            ? otherProfessionController.text.trim() 
            : 'N/A',
        'doctor_specialty': selectedProfessionalRole == 'Doctor' 
            ? doctorSpecialtyController.text.trim() 
            : 'N/A',
        'highest_qualification': qualificationController.text.trim(),
        'completion_year': completionYearController.text.trim(),
        'registration_number': registrationNumberController.text.trim(),
        'current_work_role': currentRoleController.text.trim(),
        'workplace': workplaceController.text.trim(),
        'years_of_experience': experienceYearsController.text.trim(),
        'services_offered': servicesList,
        'availability_days': availabilityList,
        'time_slots': timeSlotsList,
        'community_experience': communityExperienceController.text.trim().isEmpty 
            ? 'Not provided' 
            : communityExperienceController.text.trim(),
        'languages': languagesList,
        'service_areas': serviceAreasController.text.trim(),
        'home_visit_fee': homeVisitFeeController.text.trim().isEmpty 
            ? 'Not specified' 
            : '₹${homeVisitFeeController.text.trim()}',
        'teleconsultation_fee': teleconsultationFeeController.text.trim().isEmpty 
            ? 'Not specified' 
            : '₹${teleconsultationFeeController.text.trim()}',
        'agreed_to_declaration': agreedToDeclaration,
        'agreed_to_data_privacy': agreedToDataPrivacy,
        'agreed_to_professional_responsibility': agreedToProfessionalResponsibility,
        'agreed_to_terms': agreedToTerms,
        'agreed_to_communication': agreedToCommunication,
        'submitted_at': DateTime.now().toIso8601String(),
      };

      // Insert into healthcare_providers table
      await supabase.from('healthcare_providers').insert({
        'full_name': fullNameController.text.trim(),
        'mobile_number': mobileController.text.trim(),
        'alternative_mobile': alternativeMobileController.text.trim().isEmpty 
            ? null 
            : alternativeMobileController.text.trim(),
        'email': emailController.text.trim().isEmpty 
            ? null 
            : emailController.text.trim(),
        'city': cityController.text.trim(),
        'password_hash': hashedPassword, // Hashed password using SHA-256
        'professional_role': selectedProfessionalRole,
        'other_profession': selectedProfessionalRole == 'Other Allied Health Professional' 
            ? otherProfessionController.text.trim() 
            : null,
        'doctor_specialty': selectedProfessionalRole == 'Doctor' 
            ? doctorSpecialtyController.text.trim() 
            : null,
        'highest_qualification': qualificationController.text.trim(),
        'completion_year': int.tryParse(completionYearController.text.trim()),
        'registration_number': registrationNumberController.text.trim(),
        'current_work_role': currentRoleController.text.trim(),
        'workplace': workplaceController.text.trim(),
        'years_of_experience': int.tryParse(experienceYearsController.text.trim()),
        'services_offered': servicesList,
        'availability_days': availabilityList,
        'time_slots': timeSlotsList,
        'community_experience': communityExperienceController.text.trim().isEmpty 
            ? null 
            : communityExperienceController.text.trim(),
        'languages': languagesList,
        'service_areas': serviceAreasController.text.trim(),
        'home_visit_fee': homeVisitFeeController.text.trim().isEmpty 
            ? null 
            : double.tryParse(homeVisitFeeController.text.trim()),
        'teleconsultation_fee': teleconsultationFeeController.text.trim().isEmpty 
            ? null 
            : double.tryParse(teleconsultationFeeController.text.trim()),
        'agreed_to_declaration': agreedToDeclaration,
        'agreed_to_data_privacy': agreedToDataPrivacy,
        'agreed_to_professional_responsibility': agreedToProfessionalResponsibility,
        'agreed_to_terms': agreedToTerms,
        'agreed_to_communication': agreedToCommunication,
        'application_status': 'pending', // pending, approved, rejected
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send email notification to admins
      try {
        await ProviderEmailService.sendProviderRegistrationEmail(
          providerData: providerDataForEmail,
        );
        print('✅ Email notification sent successfully to admin emails');
      } catch (emailError) {
        print('⚠️ Failed to send email notification: $emailError');
        // Don't block the flow if email fails
      }

      // Send confirmation email to user (only if email is provided)
      if (emailController.text.trim().isNotEmpty) {
        try {
          await ProviderEmailService.sendUserConfirmationEmail(
            userEmail: emailController.text.trim(),
            userName: fullNameController.text.trim(),
          );
          print('✅ Confirmation email sent to user successfully');
        } catch (emailError) {
          print('⚠️ Failed to send user confirmation email: $emailError');
          // Don't block the flow if email fails
        }
      } else {
        print('ℹ️ No email provided - skipping user confirmation email');
      }

      if (mounted) {
        setState(() => _isLoading = false);
        
        // Navigate to application status screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProviderApplicationStatusScreen(
              providerData: providerDataForEmail,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Convert technical errors to user-friendly messages
        String userMessage = 'Failed to submit application. Please try again.';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('duplicate') && errorStr.contains('mobile')) {
          userMessage = 'This mobile number is already registered. Please use a different number or login if you already have an account.';
        } else if (errorStr.contains('duplicate') && errorStr.contains('email')) {
          userMessage = 'This email is already registered. Please use a different email or login if you already have an account.';
        } else if (errorStr.contains('network') || errorStr.contains('connection')) {
          userMessage = 'Network error. Please check your internet connection and try again.';
        } else if (errorStr.contains('timeout')) {
          userMessage = 'Request timed out. Please try again.';
        } else if (errorStr.contains('constraint') || errorStr.contains('check')) {
          userMessage = 'Invalid data. Please verify all fields and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => SafeNavigation.pop(context, debugLabel: 'provider_registration_back'),
        ),
        title: const Text(
          'Healthcare Provider Registration',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2260FF), Color(0xFF1A4FCC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidateMode,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2260FF), Color(0xFF1A4FCC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2260FF).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join Our Healthcare Network',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Complete the form below to become part of our trusted healthcare provider network',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              // Section A: Basic Information
              _buildSectionHeader('Section A: Basic Information', Icons.person),
              const SizedBox(height: 20),
              
              _buildSubsectionTitle('1. Your Basic Details'),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: fullNameController,
                label: 'Full Name *',
                hint: 'Enter your full name',
                validator: (val) => val == null || val.isEmpty ? 'Full name is required' : null,
              ),
              
              _buildTextField(
                controller: mobileController,
                label: 'Mobile Number *',
                hint: '10-digit mobile number',
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Mobile number is required';
                  if (val.length != 10) return 'Enter valid 10-digit mobile number';
                  return null;
                },
              ),
              
              _buildTextField(
                controller: alternativeMobileController,
                label: 'Alternative Mobile Number (Optional)',
                hint: '10-digit alternative mobile number',
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              
              _buildTextField(
                controller: emailController,
                label: 'Email ID (Optional)',
                hint: 'your.email@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val != null && val.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                    return 'Enter valid email address';
                  }
                  return null;
                },
              ),
              
              _buildTextField(
                controller: cityController,
                label: 'Current City *',
                hint: 'Enter your city',
                validator: (val) => val == null || val.isEmpty ? 'City is required' : null,
              ),
              
              _buildPasswordField(
                controller: passwordController,
                label: 'Set Password *',
                hint: 'At least 6 characters',
                obscureText: _obscurePassword,
                onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Password is required';
                  if (val.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              
              _buildPasswordField(
                controller: confirmPasswordController,
                label: 'Confirm Password *',
                hint: 'Re-enter password',
                obscureText: _obscureConfirmPassword,
                onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please confirm password';
                  if (val != passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('2. Select Your Professional Role'),
              const SizedBox(height: 12),
              
              _buildDropdown(
                value: selectedProfessionalRole,
                label: 'Professional Role *',
                hint: 'Select your role',
                items: professionalRoles,
                onChanged: (val) => setState(() {
                  selectedProfessionalRole = val;
                  if (val != 'Doctor') doctorSpecialtyController.clear();
                  if (val != 'Other Allied Health Professional') otherProfessionController.clear();
                }),
                validator: (val) => val == null ? 'Please select your professional role' : null,
              ),
              
              if (selectedProfessionalRole == 'Doctor') ...[
                const SizedBox(height: 12),
                _buildDropdown(
                  value: doctorSpecialtyController.text.isEmpty ? null : doctorSpecialtyController.text,
                  label: 'Specialty *',
                  hint: 'Select your specialty',
                  items: doctorSpecialties,
                  onChanged: (val) => setState(() => doctorSpecialtyController.text = val!),
                  validator: (val) => val == null ? 'Please select your specialty' : null,
                ),
              ],
              
              if (selectedProfessionalRole == 'Other Allied Health Professional') ...[
                const SizedBox(height: 12),
                _buildTextField(
                  controller: otherProfessionController,
                  label: 'Specify Profession *',
                  hint: 'Enter your profession',
                  validator: (val) => val == null || val.isEmpty ? 'Please specify your profession' : null,
                ),
              ],
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('3. Qualifications & Registration'),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: qualificationController,
                label: 'Highest Qualification *',
                hint: 'e.g., MBBS, B.Sc Nursing, BPT',
                validator: (val) => val == null || val.isEmpty ? 'Qualification is required' : null,
              ),
              
              _buildTextField(
                controller: completionYearController,
                label: 'Year of Completion *',
                hint: 'e.g., 2020',
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Year is required';
                  final year = int.tryParse(val);
                  if (year == null || year < 1950 || year > DateTime.now().year) {
                    return 'Enter valid year';
                  }
                  return null;
                },
              ),
              
              _buildTextField(
                controller: registrationNumberController,
                label: 'Registration Number (Optional)',
                hint: 'Medical/Nursing/RCI/etc. Registration No.',
              ),
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('4. Current Work Profile'),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: currentRoleController,
                label: 'Current Role *',
                hint: 'e.g., Senior Nurse, Consultant',
                validator: (val) => val == null || val.isEmpty ? 'Current role is required' : null,
              ),
              
              _buildTextField(
                controller: workplaceController,
                label: 'Current Workplace *',
                hint: 'Hospital/Clinic name',
                validator: (val) => val == null || val.isEmpty ? 'Workplace is required' : null,
              ),
              
              _buildTextField(
                controller: experienceYearsController,
                label: 'Years of Experience *',
                hint: 'Enter years',
                keyboardType: TextInputType.number,
                maxLength: 2,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Experience is required';
                  if (int.tryParse(val) == null) return 'Enter valid number';
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.grey[300]!, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Section B: Service Preferences
              _buildSectionHeader('Section B: Service Preferences', Icons.psychology_rounded),
              const SizedBox(height: 20),
              
              _buildSubsectionTitle('5. Services You Wish to Provide *'),
              const Text('(Select all that apply)', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              
              ...selectedServices.keys.map((service) => CheckboxListTile(
                title: Text(service, style: const TextStyle(fontSize: 15)),
                value: selectedServices[service],
                onChanged: (val) => setState(() => selectedServices[service] = val!),
                activeColor: const Color(0xFF2260FF),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('6. Availability *'),
              const SizedBox(height: 12),
              
              const Text('Select Days:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              
              ...availability.keys.map((day) => CheckboxListTile(
                title: Text(day, style: const TextStyle(fontSize: 15)),
                value: availability[day],
                onChanged: (val) => setState(() => availability[day] = val!),
                activeColor: const Color(0xFF2260FF),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              
              const SizedBox(height: 16),
              const Text('Select Time Slots:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 8),
              
              ...timeSlots.keys.map((slot) => CheckboxListTile(
                title: Text(slot, style: const TextStyle(fontSize: 15)),
                value: timeSlots[slot],
                onChanged: (val) => setState(() => timeSlots[slot] = val!),
                activeColor: const Color(0xFF2260FF),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('7. Community / Home-Care Experience (Optional)'),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: communityExperienceController,
                label: 'Experience Details',
                hint: 'Share your experience in community health, home care, elderly care, or telemedicine',
                maxLines: 4,
              ),
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('8. Languages You Can Communicate In *'),
              const SizedBox(height: 12),
              
              ...languages.keys.map((lang) => CheckboxListTile(
                title: Text(lang, style: const TextStyle(fontSize: 15)),
                value: languages[lang],
                onChanged: (val) => setState(() => languages[lang] = val!),
                activeColor: const Color(0xFF2260FF),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              
              const SizedBox(height: 12),
              _buildTextField(
                controller: otherLanguagesController,
                label: 'Other Languages',
                hint: 'Comma-separated (e.g., Odiya, Assamese)',
              ),
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('9. Service Areas You Can Cover *'),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: serviceAreasController,
                label: 'Localities/Regions',
                hint: 'Enter areas where you can provide home visits (comma-separated)',
                maxLines: 3,
                validator: (val) => val == null || val.isEmpty ? 'Service areas are required' : null,
              ),
              
              const SizedBox(height: 24),
              _buildSubsectionTitle('10. Expected Service Fee'),
              const SizedBox(height: 12),
              
              _buildTextField(
                controller: homeVisitFeeController,
                label: 'Home Visit Charge (₹)',
                hint: 'Enter amount',
                keyboardType: TextInputType.number,
              ),
              
              _buildTextField(
                controller: teleconsultationFeeController,
                label: 'Teleconsultation Fee (₹)',
                hint: 'Enter amount',
                keyboardType: TextInputType.number,
              ),
              
              const SizedBox(height: 32),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.grey[300]!, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Section C: Consent & Compliance
              _buildSectionHeader('Section C: Consent & Compliance', Icons.gavel),
              const SizedBox(height: 20),
              
              _buildConsentCheckbox(
                value: agreedToDeclaration,
                title: '11. Declaration of Authentic Information *',
                description: 'I confirm that the information provided by me is true and accurate to the best of my knowledge. I understand that SR CareHive may verify my credentials before onboarding.',
                onChanged: (val) => setState(() => agreedToDeclaration = val!),
              ),
              
              const SizedBox(height: 16),
              _buildConsentCheckbox(
                value: agreedToDataPrivacy,
                title: '12. Data Privacy & Health Data Compliance *',
                description: 'SR CareHive follows the Digital Personal Data Protection Act, 2023 (DPDP Act). By submitting this form, you consent to:\n• SR CareHive securely storing your professional and contact information\n• Using this information only for verification, scheduling, service allocation, payments, and communication\n• Contacting you for patient-related services, platform updates, or operational requirements\n• Not sharing your personal data with third parties without your explicit consent, except where required by law',
                onChanged: (val) => setState(() => agreedToDataPrivacy = val!),
              ),
              
              const SizedBox(height: 16),
              _buildConsentCheckbox(
                value: agreedToProfessionalResponsibility,
                title: '13. Professional Responsibility Acknowledgment *',
                description: 'I acknowledge that teleconsultations and home visits will be provided only for non-emergency services. I agree to uphold ethical standards, patient confidentiality, and professional conduct as per my council\'s regulations.',
                onChanged: (val) => setState(() => agreedToProfessionalResponsibility = val!),
              ),
              
              const SizedBox(height: 16),
              _buildConsentCheckbox(
                value: agreedToTerms,
                title: '14. Terms of Engagement (Pay-Per-Service Model) *',
                description: 'I understand that this is not an employment contract. Services are offered on a pay-per-service basis through the Serechi platform. Payment structure, patient allocation, and operational guidelines will be shared during onboarding.',
                onChanged: (val) => setState(() => agreedToTerms = val!),
              ),
              
              const SizedBox(height: 16),
              _buildConsentCheckbox(
                value: agreedToCommunication,
                title: '15. Communication Consent *',
                description: 'I agree to receive communication via phone, SMS, email, or WhatsApp regarding service requests, scheduling, training, and onboarding.',
                onChanged: (val) => setState(() => agreedToCommunication = val!),
              ),
              
              const SizedBox(height: 32),
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.grey[300]!, Colors.transparent],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Section D: Final Submission
              _buildSectionHeader('Section D: Final Submission', Icons.send),
              const SizedBox(height: 20),
              
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2260FF), Color(0xFF1A4FCC)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2260FF).withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Apply to Join SR CareHive Network',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2260FF).withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2260FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2260FF).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2260FF),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2260FF).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2260FF),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2260FF).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF2260FF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              maxLines: maxLines,
              validator: validator,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
                counterText: maxLength != null ? '' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              validator: validator,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF2260FF),
                  ),
                  onPressed: onToggle,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    String? hint,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              value: value,
              hint: Text(hint ?? 'Select', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
              validator: validator,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1.5),
                ),
              ),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCheckbox({
    required bool value,
    required String title,
    required String description,
    required void Function(bool?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? const Color(0xFF2260FF).withOpacity(0.3) : Colors.grey[300]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: value ? const Color(0xFF2260FF).withOpacity(0.08) : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2260FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF2260FF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
          CheckboxListTile(
            title: Text(
              'I agree',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: value ? const Color(0xFF2260FF) : Colors.grey[700],
              ),
            ),
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2260FF),
            contentPadding: const EdgeInsets.only(left: 0, top: 8),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }
}
