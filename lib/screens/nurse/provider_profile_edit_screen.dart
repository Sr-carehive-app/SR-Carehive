import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:care12/utils/safe_navigation.dart';
import 'package:care12/data/indian_cities.dart';

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

  // Controllers for basic information
  late TextEditingController fullNameController;
  late TextEditingController primaryMobileController;
  late TextEditingController alternativeMobileController;
  late TextEditingController emailController;
  late TextEditingController cityController;
  
  // Controllers for professional details
  String? selectedProfessionalRole;
  late TextEditingController otherProfessionController;
  late TextEditingController doctorSpecialtyController;
  late TextEditingController qualificationController;
  late TextEditingController completionYearController;
  late TextEditingController registrationNumberController;
  
  // Controllers for current work profile
  late TextEditingController currentRoleController;
  late TextEditingController workplaceController;
  late TextEditingController experienceYearsController;
  
  // Controllers for service information
  late TextEditingController serviceAreasController;
  late TextEditingController homeVisitFeeController;
  late TextEditingController teleconsultationFeeController;
  late TextEditingController communityExperienceController;
  
  // Multi-select state variables
  Map<String, bool> selectedServices = {};
  Map<String, bool> availability = {};
  Map<String, bool> timeSlots = {};
  Map<String, bool> languages = {};

  @override
  void initState() {
    super.initState();
    
    // Initialize basic information controllers
    fullNameController = TextEditingController(text: widget.providerData['full_name'] ?? '');
    primaryMobileController = TextEditingController(text: widget.providerData['mobile_number'] ?? '');
    alternativeMobileController = TextEditingController(text: widget.providerData['alternative_mobile'] ?? '');
    emailController = TextEditingController(text: widget.providerData['email'] ?? '');
    cityController = TextEditingController(text: widget.providerData['city'] ?? '');
    
    // Initialize professional details controllers
    selectedProfessionalRole = widget.providerData['professional_role'];
    otherProfessionController = TextEditingController(text: widget.providerData['other_profession'] ?? '');
    doctorSpecialtyController = TextEditingController(text: widget.providerData['doctor_specialty'] ?? '');
    qualificationController = TextEditingController(text: widget.providerData['highest_qualification'] ?? '');
    completionYearController = TextEditingController(text: widget.providerData['completion_year']?.toString() ?? '');
    registrationNumberController = TextEditingController(text: widget.providerData['registration_number'] ?? '');
    
    // Initialize current work profile controllers
    currentRoleController = TextEditingController(text: widget.providerData['current_work_role'] ?? '');
    workplaceController = TextEditingController(text: widget.providerData['workplace'] ?? '');
    experienceYearsController = TextEditingController(text: widget.providerData['years_of_experience']?.toString() ?? '');
    
    // Initialize service information controllers
    serviceAreasController = TextEditingController(text: widget.providerData['service_areas'] ?? '');
    homeVisitFeeController = TextEditingController(text: widget.providerData['home_visit_fee']?.toString() ?? '');
    teleconsultationFeeController = TextEditingController(text: widget.providerData['teleconsultation_fee']?.toString() ?? '');
    communityExperienceController = TextEditingController(text: widget.providerData['community_experience'] ?? '');
    
    // Initialize multi-select states from provider data
    _initializeMultiSelectData();
  }
  
  void _initializeMultiSelectData() {
    // Initialize services offered
    final List<String> servicesOfferedList = widget.providerData['services_offered'] != null
        ? (widget.providerData['services_offered'] as List).map((e) => e.toString()).toList()
        : [];
    
    selectedServices = {
      'Teleconsultation': servicesOfferedList.contains('Teleconsultation'),
      'Home Visits': servicesOfferedList.contains('Home Visits'),
      'Chronic Disease Home Care': servicesOfferedList.contains('Chronic Disease Home Care'),
      'Elderly Care & Companionship': servicesOfferedList.contains('Elderly Care & Companionship'),
      'Post-operative / Post-acute Care': servicesOfferedList.contains('Post-operative / Post-acute Care'),
      'Mental Health Counselling': servicesOfferedList.contains('Mental Health Counselling'),
      'Yoga/Wellness Sessions (Home/Online)': servicesOfferedList.contains('Yoga/Wellness Sessions (Home/Online)'),
      'Physiotherapy': servicesOfferedList.contains('Physiotherapy'),
      'Clinical Psychology': servicesOfferedList.contains('Clinical Psychology'),
      'Rehabilitation Services': servicesOfferedList.contains('Rehabilitation Services'),
      'Palliative Care': servicesOfferedList.contains('Palliative Care'),
    };
    
    // Initialize availability days
    final List<String> availabilityList = widget.providerData['availability_days'] != null
        ? (widget.providerData['availability_days'] as List).map((e) => e.toString()).toList()
        : [];
    
    availability = {
      'Monday': availabilityList.contains('Monday'),
      'Tuesday': availabilityList.contains('Tuesday'),
      'Wednesday': availabilityList.contains('Wednesday'),
      'Thursday': availabilityList.contains('Thursday'),
      'Friday': availabilityList.contains('Friday'),
      'Saturday': availabilityList.contains('Saturday'),
      'Sunday': availabilityList.contains('Sunday'),
    };
    
    // Initialize time slots
    final List<String> timeSlotsList = widget.providerData['time_slots'] != null
        ? (widget.providerData['time_slots'] as List).map((e) => e.toString()).toList()
        : [];
    
    timeSlots = {
      'Morning (6 AM - 12 PM)': timeSlotsList.contains('Morning (6 AM - 12 PM)'),
      'Afternoon (12 PM - 5 PM)': timeSlotsList.contains('Afternoon (12 PM - 5 PM)'),
      'Evening (5 PM - 9 PM)': timeSlotsList.contains('Evening (5 PM - 9 PM)'),
      'Night (9 PM - 6 AM)': timeSlotsList.contains('Night (9 PM - 6 AM)'),
      'Flexible': timeSlotsList.contains('Flexible'),
    };
    
    // Initialize languages
    final List<String> languagesList = widget.providerData['languages'] != null
        ? (widget.providerData['languages'] as List).map((e) => e.toString()).toList()
        : [];
    
    languages = {
      'English': languagesList.contains('English'),
      'Hindi': languagesList.contains('Hindi'),
      'Bengali': languagesList.contains('Bengali'),
      'Telugu': languagesList.contains('Telugu'),
      'Marathi': languagesList.contains('Marathi'),
      'Tamil': languagesList.contains('Tamil'),
      'Gujarati': languagesList.contains('Gujarati'),
      'Kannada': languagesList.contains('Kannada'),
      'Malayalam': languagesList.contains('Malayalam'),
      'Punjabi': languagesList.contains('Punjabi'),
      'Odia': languagesList.contains('Odia'),
      'Urdu': languagesList.contains('Urdu'),
    };
  }

  @override
  void dispose() {
    // Dispose basic information controllers
    fullNameController.dispose();
    primaryMobileController.dispose();
    alternativeMobileController.dispose();
    emailController.dispose();
    cityController.dispose();
    
    // Dispose professional details controllers
    otherProfessionController.dispose();
    doctorSpecialtyController.dispose();
    qualificationController.dispose();
    completionYearController.dispose();
    registrationNumberController.dispose();
    
    // Dispose current work profile controllers
    currentRoleController.dispose();
    workplaceController.dispose();
    experienceYearsController.dispose();
    
    // Dispose service information controllers
    serviceAreasController.dispose();
    homeVisitFeeController.dispose();
    teleconsultationFeeController.dispose();
    communityExperienceController.dispose();
    
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
      // Prepare array data from multi-select options
      final List<String> servicesOffered = selectedServices.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      final List<String> availabilityDays = availability.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      final List<String> selectedTimeSlots = timeSlots.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      final List<String> selectedLanguages = languages.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      final updatedData = {
        // Basic Information
        'full_name': fullNameController.text.trim(),
        'mobile_number': primaryMobileController.text.trim(),
        'alternative_mobile': alternativeMobileController.text.trim().isEmpty 
            ? null 
            : alternativeMobileController.text.trim(),
        'email': emailController.text.trim().isEmpty 
            ? null 
            : emailController.text.trim(),
        'city': cityController.text.trim(),
        
        // Professional Details
        'professional_role': selectedProfessionalRole,
        'other_profession': otherProfessionController.text.trim().isEmpty 
            ? null 
            : otherProfessionController.text.trim(),
        'doctor_specialty': doctorSpecialtyController.text.trim().isEmpty 
            ? null 
            : doctorSpecialtyController.text.trim(),
        'highest_qualification': qualificationController.text.trim(),
        'completion_year': completionYearController.text.trim().isEmpty 
            ? null 
            : int.tryParse(completionYearController.text.trim()),
        'registration_number': registrationNumberController.text.trim(),
        
        // Current Work Profile
        'current_work_role': currentRoleController.text.trim(),
        'workplace': workplaceController.text.trim(),
        'years_of_experience': experienceYearsController.text.trim().isEmpty 
            ? null 
            : int.tryParse(experienceYearsController.text.trim()),
        
        // Service Information
        'services_offered': servicesOffered,
        'availability_days': availabilityDays,
        'time_slots': selectedTimeSlots,
        'languages': selectedLanguages,
        'community_experience': communityExperienceController.text.trim().isEmpty 
            ? null 
            : communityExperienceController.text.trim(),
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
          onPressed: () => SafeNavigation.pop(context, debugLabel: 'provider_profile_edit_back'),
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
                        'You can update all your profile information including professional details, work information, and service preferences.',
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
              
              // City field with autocomplete
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_city_outlined, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'City',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return IndianCities.searchCities(textEditingValue.text);
                    },
                    onSelected: (String selection) {
                      setState(() {
                        cityController.text = selection;
                      });
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = cityController.text;
                      controller.selection = TextSelection.collapsed(offset: controller.text.length);
                      
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (value) {
                          cityController.text = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Search or enter your city',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: primaryColor, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.red),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: Icon(Icons.search, color: primaryColor),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your city';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
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
                ],
              ),
              const SizedBox(height: 24),

              // Professional Details Section
              _buildSectionHeader('Professional Details', Icons.medical_services_outlined),
              const SizedBox(height: 16),
              
              // Professional Role Dropdown
              Container(
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
                child: DropdownButtonFormField<String>(
                  value: selectedProfessionalRole,
                  decoration: InputDecoration(
                    labelText: 'Professional Role',
                    prefixIcon: Icon(Icons.badge_outlined, color: primaryColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    'Nurse',
                    'Midwife',
                    'Doctor',
                    'Physiotherapist',
                    'Clinical Psychologist',
                    'Counselor',
                    'Yoga/Wellness Instructor',
                    'Other Allied Health Professional',
                  ].map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedProfessionalRole = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your professional role';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Show "Other Profession" field if "Other Allied Health Professional" is selected
              if (selectedProfessionalRole == 'Other Allied Health Professional')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildTextField(
                    controller: otherProfessionController,
                    label: 'Specify Other Profession',
                    icon: Icons.psychology_outlined,
                    hint: 'e.g., Occupational Therapist, Speech Therapist',
                    validator: (value) {
                      if (selectedProfessionalRole == 'Other Allied Health Professional' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please specify your profession';
                      }
                      return null;
                    },
                  ),
                ),
              
              // Show "Doctor Specialty" field if "Doctor" is selected
              if (selectedProfessionalRole == 'Doctor')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildTextField(
                    controller: doctorSpecialtyController,
                    label: 'Doctor Specialty',
                    icon: Icons.local_hospital_outlined,
                    hint: 'e.g., General Physician, Cardiologist',
                    validator: (value) {
                      if (selectedProfessionalRole == 'Doctor' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please specify your specialty';
                      }
                      return null;
                    },
                  ),
                ),
              
              _buildTextField(
                controller: qualificationController,
                label: 'Highest Qualification',
                icon: Icons.school_outlined,
                hint: 'e.g., BSc Nursing, MBBS, MSc Psychology',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your highest qualification';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: completionYearController,
                label: 'Completion Year',
                icon: Icons.calendar_today_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter completion year';
                  }
                  final year = int.tryParse(value.trim());
                  if (year == null || year < 1950 || year > DateTime.now().year) {
                    return 'Please enter a valid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: registrationNumberController,
                label: 'Registration Number',
                icon: Icons.assignment_outlined,
                hint: 'Professional registration/license number',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your registration number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Current Work Profile Section
              _buildSectionHeader('Current Work Profile', Icons.business_center_outlined),
              const SizedBox(height: 16),
              _buildTextField(
                controller: currentRoleController,
                label: 'Current Work Role',
                icon: Icons.work_history_outlined,
                hint: 'e.g., Senior Nurse, Consultant Doctor',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your current work role';
                  }
                  return null;
                },
              ),
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
                controller: experienceYearsController,
                label: 'Years of Experience',
                icon: Icons.timeline_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter years of experience';
                  }
                  final years = int.tryParse(value.trim());
                  if (years == null || years < 0 || years > 60) {
                    return 'Please enter valid years (0-60)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Work Information Section
              _buildSectionHeader('Service Information', Icons.medical_information_outlined),
              const SizedBox(height: 16),
              _buildTextField(
                controller: serviceAreasController,
                label: 'Service Areas (Optional)',
                icon: Icons.map_outlined,
                required: false,
                maxLines: 2,
                hint: 'e.g., North Delhi, Central Delhi',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: communityExperienceController,
                label: 'Community Experience (Optional)',
                icon: Icons.people_outline,
                required: false,
                maxLines: 3,
                hint: 'Describe your community health experience',
              ),
              const SizedBox(height: 24),

              // Services Offered Section
              _buildSectionHeader('Services Offered', Icons.medical_services),
              const SizedBox(height: 12),
              _buildCheckboxGroup(selectedServices),
              const SizedBox(height: 24),

              // Availability Days Section
              _buildSectionHeader('Availability Days', Icons.calendar_month),
              const SizedBox(height: 12),
              _buildCheckboxGroup(availability),
              const SizedBox(height: 24),

              // Time Slots Section
              _buildSectionHeader('Time Slots', Icons.schedule),
              const SizedBox(height: 12),
              _buildCheckboxGroup(timeSlots),
              const SizedBox(height: 24),

              // Languages Section
              _buildSectionHeader('Languages', Icons.language),
              const SizedBox(height: 12),
              _buildCheckboxGroup(languages),
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

  Widget _buildCheckboxGroup(Map<String, bool> options) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.entries.map((entry) {
          return InkWell(
            onTap: () {
              setState(() {
                options[entry.key] = !entry.value;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: entry.value ? primaryColor.withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: entry.value ? primaryColor : Colors.grey[300]!,
                  width: entry.value ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    entry.value ? Icons.check_circle : Icons.circle_outlined,
                    size: 18,
                    color: entry.value ? primaryColor : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: entry.value ? FontWeight.w600 : FontWeight.normal,
                      color: entry.value ? primaryColor : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
