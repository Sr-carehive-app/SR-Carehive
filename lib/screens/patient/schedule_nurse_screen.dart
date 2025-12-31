import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:care12/screens/patient/patient_dashboard_screen.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/services/payment_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ScheduleNurseScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const ScheduleNurseScreen({Key? key, this.onBackToHome}) : super(key: key);

  @override
  State<ScheduleNurseScreen> createState() => _ScheduleNurseScreenState();
}

class _ScheduleNurseScreenState extends State<ScheduleNurseScreen> {
  final Color primaryColor = const Color(0xFF2260FF);

  // Controllers for input fields
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController patientEmailController = TextEditingController();
  final TextEditingController emergencyContactController = TextEditingController();
  final TextEditingController problemController = TextEditingController();
  final TextEditingController aadharController = TextEditingController();
  final TextEditingController primaryDoctorNameController = TextEditingController();
  final TextEditingController primaryDoctorPhoneController = TextEditingController();
  final TextEditingController primaryDoctorLocationController = TextEditingController();

  late List<DateTime> weekDates;
  DateTime selectedDate = DateTime.now();

  late List<String> times;
  String selectedTime = '';

  String selectedPatient = 'Yourself';
  String selectedGender = 'Female';
  
  // Country codes for phone validation
  String selectedCountryCode = '+91';
  String selectedEmergencyCountryCode = '+91';
  String selectedPrimaryDoctorCountryCode = '+91';
  
  // Country codes list with phone number lengths
  final List<Map<String, dynamic>> countryCodes = [
    {'code': '+91', 'country': 'India', 'length': 10},
    {'code': '+1', 'country': 'USA', 'length': 10},
    {'code': '+44', 'country': 'UK', 'length': 10},
    {'code': '+971', 'country': 'UAE', 'length': 9},
    {'code': '+61', 'country': 'Australia', 'length': 9},
    {'code': '+65', 'country': 'Singapore', 'length': 8},
  ];
  
  bool isLoading = false;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    weekDates = getCurrentWeekDates();
    updateTimeSlotsForDate(selectedDate);
    _loadUserData();
  }

  // Helper methods for dynamic phone validation
  int getPhoneNumberLength(String countryCode) {
    final country = countryCodes.firstWhere(
      (c) => c['code'] == countryCode,
      orElse: () => {'code': '+91', 'country': 'India', 'length': 10},
    );
    return country['length'] as int;
  }

  String getPhonePlaceholder(String countryCode) {
    final length = getPhoneNumberLength(countryCode);
    return 'X' * length; // e.g., "XXXXXXXXXX" for 10 digits
  }

  @override
  void dispose() {
    fullNameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    addressController.dispose();
    patientEmailController.dispose();
    emergencyContactController.dispose();
    problemController.dispose();
    aadharController.dispose();
    primaryDoctorNameController.dispose();
    primaryDoctorPhoneController.dispose();
    primaryDoctorLocationController.dispose();
    super.dispose();
  }

  /// Load user data from patients table
  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final patient = await supabase
            .from('patients')
            .select('salutation, name, aadhar_linked_phone, permanent_address, aadhar_number, email, age, country_code')
            .eq('user_id', user.id)
            .maybeSingle();
        
        if (patient != null) {
          setState(() {
            // Include salutation with name if available
            final salutation = patient['salutation'] ?? '';
            final name = patient['name'] ?? '';
            fullNameController.text = salutation.isNotEmpty ? '$salutation $name' : name;
            phoneController.text = patient['aadhar_linked_phone'] ?? '';
            addressController.text = patient['permanent_address'] ?? '';
            aadharController.text = patient['aadhar_number'] ?? '';
            patientEmailController.text = (patient['email'] ?? user.email ?? '').toString();
            ageController.text = patient['age'] != null ? patient['age'].toString() : ageController.text;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Generate dates from today onwards (next 7 days)
  List<DateTime> getCurrentWeekDates() {
    DateTime now = DateTime.now();
    // Only return dates from today onwards
    DateTime today = DateTime(now.year, now.month, now.day);
    return List.generate(7, (index) => today.add(Duration(days: index)));
  }

  /// Update time slots when date changes
  void updateTimeSlotsForDate(DateTime date) {
    times = generateTimeSlots(
      startHour: 9,
      endHour: 18,
      intervalMinutes: 60,
    );
    selectedTime = times.isNotEmpty ? times[0] : '';
  }

  /// Dynamically generate time slots
  List<String> generateTimeSlots({
    required int startHour,
    required int endHour,
    required int intervalMinutes,
  }) {
    List<String> slots = [];
    DateTime time = DateTime(2020, 1, 1, startHour, 0);
    DateTime endTime = DateTime(2020, 1, 1, endHour, 0);

    while (time.isBefore(endTime) || time.isAtSameMomentAs(endTime)) {
      slots.add(DateFormat.jm().format(time)); // e.g., 9:00 AM
      time = time.add(Duration(minutes: intervalMinutes));
    }
    return slots;
  }

  /// Validate form fields
  bool _validateForm() {
    if (fullNameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter full name');
      return false;
    }
    if (ageController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter age');
      return false;
    }
    if (int.tryParse(ageController.text.trim()) == null) {
      _showErrorSnackBar('Please enter a valid age');
      return false;
    }
    final age = int.tryParse(ageController.text.trim()) ?? 0;
    if (age < 1 || age > 100) {
      _showErrorSnackBar('Age must be between 1 and 100');
      return false;
    }
    // Email required and valid
    if (patientEmailController.text.trim().isEmpty) {
      final emailContext = selectedPatient == 'Another Person' 
        ? 'Please enter the healthcare seeker\'s email' 
        : 'Please enter your email';
      _showErrorSnackBar(emailContext);
      return false;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(patientEmailController.text.trim())) {
      final emailContext = selectedPatient == 'Another Person' 
        ? 'Please enter a valid email for the healthcare seeker' 
        : 'Please enter a valid email';
      _showErrorSnackBar(emailContext);
      return false;
    }
    if (phoneController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter phone number');
      return false;
    }
    // Validate phone number format based on country code
    final phone = phoneController.text.trim();
    final requiredLength = getPhoneNumberLength(selectedCountryCode);
    if (phone.length != requiredLength || int.tryParse(phone) == null) {
      _showErrorSnackBar('Phone number must be $requiredLength digits for $selectedCountryCode');
      return false;
    }
    // For Indian numbers, check if starts with 6-9
    if (selectedCountryCode == '+91' && !RegExp(r'^[6-9]').hasMatch(phone)) {
      _showErrorSnackBar('Indian phone number must start with 6, 7, 8, or 9');
      return false;
    }
    if (addressController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter address');
      return false;
    }
    if (emergencyContactController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter emergency contact');
      return false;
    }
    // Validate emergency contact phone format based on country code
    final emergencyPhone = emergencyContactController.text.trim();
    final emergencyRequiredLength = getPhoneNumberLength(selectedEmergencyCountryCode);
    if (emergencyPhone.length != emergencyRequiredLength || int.tryParse(emergencyPhone) == null) {
      _showErrorSnackBar('Emergency contact must be $emergencyRequiredLength digits for $selectedEmergencyCountryCode');
      return false;
    }
    // For Indian numbers, check if starts with 6-9
    if (selectedEmergencyCountryCode == '+91' && !RegExp(r'^[6-9]').hasMatch(emergencyPhone)) {
      _showErrorSnackBar('Indian emergency contact must start with 6, 7, 8, or 9');
      return false;
    }
    // Aadhar validation
    if (aadharController.text.trim().isNotEmpty) {
      final aadhar = aadharController.text.replaceAll(RegExp(r'\s+'), '');
      if (aadhar.length != 12 || int.tryParse(aadhar) == null) {
        _showErrorSnackBar('Aadhar number must be exactly 12 digits');
        return false;
      }
      // Check if all digits are same
      if (RegExp(r'^(\d)\1{11}$').hasMatch(aadhar)) {
        _showErrorSnackBar('Invalid Aadhar number (all digits same)');
        return false;
      }
      // Check if starts with 0 or 1
      if (aadhar.startsWith('0') || aadhar.startsWith('1')) {
        _showErrorSnackBar('Aadhar number cannot start with 0 or 1');
        return false;
      }
      // Verhoeff algorithm validation
      if (!_validateAadharChecksum(aadhar)) {
        _showErrorSnackBar('Invalid Aadhar number (checksum failed)');
        return false;
      }
    }
    // Primary doctor phone validation (optional but if provided must be valid)
    // Note: Database constraint only supports Indian format (10 digits, starts with 6-9)
    if (primaryDoctorPhoneController.text.trim().isNotEmpty) {
      final phone = primaryDoctorPhoneController.text.trim();
      if (phone.length != 10 || int.tryParse(phone) == null) {
        _showErrorSnackBar('Primary doctor phone must be exactly 10 digits');
        return false;
      }
      // Must start with 6-9 (Indian mobile format) due to database constraint
      if (!RegExp(r'^[6-9]').hasMatch(phone)) {
        _showErrorSnackBar('Primary doctor phone must start with 6, 7, 8, or 9');
        return false;
      }
    }
    if (selectedTime.isEmpty) {
      _showErrorSnackBar('Please select a time slot');
      return false;
    }
    if (problemController.text.trim().isEmpty) {
      _showErrorSnackBar('Please describe your problem');
      return false;
    }
    return true;
  }

  /// Verhoeff algorithm for Aadhar validation
  bool _validateAadharChecksum(String aadhar) {
    final d = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
      [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
      [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
      [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
      [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
      [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
      [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
      [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
      [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
    ];
    final p = [
      [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
      [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
      [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
      [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
      [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
      [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
      [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
    ];
    int c = 0;
    final invertedArray = aadhar.split('').reversed.toList();
    for (int i = 0; i < invertedArray.length; i++) {
      c = d[c][p[(i % 8)][int.parse(invertedArray[i])]];
    }
    return c == 0;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleAppointment() async {
    if (!_validateForm()) return;
    if (mounted) setState(() => isSubmitting = true);
    try {
      // No payment required - directly create appointment
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      String? patientId;
      
      if (user != null) {
        try {
          final patient = await supabase
              .from('patients')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();
          final dynamic pid = patient?['id'];
          if (pid != null) patientId = pid.toString();
        } catch (_) {}
      }
      
      // Create appointment directly in database
      final appointmentData = {
        'patient_id': patientId,
        'full_name': fullNameController.text.trim(), // Already includes salutation from form
        'age': int.tryParse(ageController.text.trim()) ?? 0,
        'gender': selectedGender,
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'emergency_contact': emergencyContactController.text.trim(),
        'aadhar_number': aadharController.text.replaceAll(RegExp(r'\s+'), '').trim(),
        'primary_doctor_name': primaryDoctorNameController.text.trim().isNotEmpty 
            ? primaryDoctorNameController.text.trim() 
            : null,
        'primary_doctor_phone': primaryDoctorPhoneController.text.trim().isNotEmpty 
            ? primaryDoctorPhoneController.text.trim() 
            : null,
        'primary_doctor_location': primaryDoctorLocationController.text.trim().isNotEmpty 
            ? primaryDoctorLocationController.text.trim() 
            : null,
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'time': selectedTime,
        'problem': problemController.text.trim(),
        'patient_type': selectedPatient,
        'patient_email': patientEmailController.text.trim(),
        'status': 'pending', // Admin will approve/reject
        'created_at': DateTime.now().toIso8601String(),
      };
      
      final response = await supabase.from('appointments').insert(appointmentData).select().maybeSingle();
      
      // Notify admin about new appointment
      if (response != null && response['id'] != null) {
        try {
          final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
          await http.post(
            Uri.parse('$apiBaseUrl/api/notify-new-appointment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'appointmentId': response['id']}),
          );
        } catch (notifyError) {
          print('[WARN] Could not send admin notification: $notifyError');
        }
      }
      
      if (mounted) {
        _showSuccessSnackBar('Appointment request submitted successfully! Admin will review shortly.');
        _clearForm();
        // Navigate to dashboard with Appointments tab selected to preserve navbar/back stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PatientDashboardScreen(initialIndex: 1)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to submit appointment. Please try again.';
        
        // Handle specific database constraint errors
        if (e.toString().contains('chk_primary_doctor_phone_format')) {
          errorMessage = 'Primary doctor phone number must be 10 digits starting with 6, 7, 8, or 9';
        } else if (e.toString().contains('chk_aadhar_format')) {
          errorMessage = 'Aadhar number must be 12 digits and cannot start with 0 or 1';
        } else if (e.toString().contains('PostgrestException')) {
          // Extract user-friendly message from PostgrestException
          final match = RegExp(r'"message":"([^"]+)"').firstMatch(e.toString());
          if (match != null) {
            final dbMessage = match.group(1);
            if (dbMessage != null) {
              if (dbMessage.contains('chk_primary_doctor_phone_format')) {
                errorMessage = 'Primary doctor phone number format is invalid. Please enter a 10-digit number starting with 6, 7, 8, or 9';
              } else if (dbMessage.contains('chk_aadhar_format')) {
                errorMessage = 'Aadhar number format is invalid. Please enter a valid 12-digit Aadhar number';
              } else {
                errorMessage = 'Please check your information and try again';
              }
            }
          }
        }
        
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void _clearForm() {
    // Don't clear name, phone, address, aadhar as they're user data
    ageController.clear();
    emergencyContactController.clear();
    problemController.clear();
    primaryDoctorNameController.clear();
    primaryDoctorPhoneController.clear();
    primaryDoctorLocationController.clear();
    selectedGender = 'Female';
    selectedPatient = 'Yourself';
  }

  /// Show custom calendar picker for selecting any future date
  Future<void> _showCustomCalendar() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(), // Can't select past dates
      lastDate: DateTime.now().add(const Duration(days: 365)), // Up to 1 year ahead
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor, // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primaryColor, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        selectedDate = pickedDate;
        updateTimeSlotsForDate(pickedDate);
        
        // Update week dates to show the week containing the selected date
        int weekday = pickedDate.weekday;
        DateTime monday = pickedDate.subtract(Duration(days: weekday - 1));
        weekDates = List.generate(7, (index) => monday.add(Duration(days: index)));
      });

      // Show confirmation snackbar with selected date
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Date selected: ${DateFormat('EEEE, MMM dd, yyyy').format(pickedDate)}',
                ),
              ),
            ],
          ),
          backgroundColor: primaryColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Care Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          backgroundColor: primaryColor,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: null, // Disabled during loading
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: widget.onBackToHome ?? () => Navigator.pop(context),
        ),
        title: const Text('Care Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              // Refresh user data and reset form
              _loadUserData();
              setState(() {
                weekDates = getCurrentWeekDates();
                selectedDate = DateTime.now();
                updateTimeSlotsForDate(selectedDate);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshed successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date Selection Header with Calendar Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Date',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showCustomCalendar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.calendar_month, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Custom Date',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dynamic week selector
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDates.length,
              itemBuilder: (_, index) {
                DateTime date = weekDates[index];
                bool isSelected = DateFormat('yyyy-MM-dd').format(date) ==
                    DateFormat('yyyy-MM-dd').format(selectedDate);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDate = date;
                      updateTimeSlotsForDate(date);
                    });
                  },
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : const Color(0xFFEDEFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey,
                          ),
                        ),
                        Text(
                          DateFormat('dd').format(date),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Choose Time section
          const Text(
            'Choose Time',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: times.length,
              itemBuilder: (_, index) {
                String time = times[index];
                bool isSelected = selectedTime == time;
                return GestureDetector(
                  onTap: () => setState(() => selectedTime = time),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : const Color(0xFFEDEFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.check, color: Colors.white, size: 16),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Service User section
          const Text(
            'Service User Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: toggleButton('Yourself')),
              const SizedBox(width: 10),
              Expanded(child: toggleButton('Another Person')),
            ],
          ),
          const SizedBox(height: 16),

          // Patient information fields
          buildTextField('Full Name', controller: fullNameController),
          const SizedBox(height: 16),
          buildTextField('Age', controller: ageController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)]),
          const SizedBox(height: 16),
          // Patient Email - read-only for "Yourself", editable for "Another Person"
          TextField(
            controller: patientEmailController,
            readOnly: selectedPatient == 'Yourself',
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              suffixIcon: selectedPatient == 'Another Person' 
                ? const Icon(Icons.edit, size: 20, color: Colors.grey) 
                : const Icon(Icons.lock, size: 18, color: Colors.grey),
              filled: true,
              fillColor: selectedPatient == 'Yourself' 
                ? const Color(0xFFF5F5F5) 
                : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), 
                borderSide: selectedPatient == 'Another Person' 
                  ? const BorderSide(color: Color(0xFF2260FF), width: 1.5) 
                  : BorderSide.none
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), 
                borderSide: selectedPatient == 'Another Person' 
                  ? const BorderSide(color: Color(0xFF2260FF), width: 1.5) 
                  : BorderSide.none
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              helperText: selectedPatient == 'Another Person' 
                ? 'Enter the healthcare seeker\'s email address' 
                : 'Your email (read-only)',
              helperStyle: TextStyle(
                color: selectedPatient == 'Another Person' 
                  ? const Color(0xFF2260FF) 
                  : Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          buildPhoneField('Phone Number', phoneController, selectedCountryCode, (value) {
            setState(() => selectedCountryCode = value!);
          }),
          const SizedBox(height: 16),
          buildTextField('Address', controller: addressController, keyboardType: TextInputType.multiline),
          const SizedBox(height: 16),
          buildPhoneField('Emergency Contact', emergencyContactController, selectedEmergencyCountryCode, (value) {
            setState(() => selectedEmergencyCountryCode = value!);
          }),
          const SizedBox(height: 16),

          // Aadhar Number with formatting
          buildAadharField(),
          const SizedBox(height: 16),

          // Gender selection
          const Text('Gender', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              genderButton('Male'),
              const SizedBox(width: 12),
              genderButton('Female'),
            ],
          ),

          const SizedBox(height: 24),

          // Primary Doctor Details (Optional)
          const Text(
            'Primary Doctor Details (Optional)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          buildTextField('Doctor Name', controller: primaryDoctorNameController),
          const SizedBox(height: 16),
          buildTextField('Doctor Phone Number (India only)', 
            controller: primaryDoctorPhoneController, 
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
          ),
          const SizedBox(height: 16),
          buildTextField('Clinic Location (Area, City)', controller: primaryDoctorLocationController),
          const SizedBox(height: 24),

          // Problem description
          const Text(
            'Describe your problem',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: problemController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter your problem here...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: const Color(0xFFEDEFFF),
            ),
          ),

          const SizedBox(height: 30),

          // Submit Appointment button
          ElevatedButton(
            onPressed: isSubmitting ? null : _handleAppointment,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: isSubmitting
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Submitting...', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ],
                  )
                : const Text('Submit Appointment Request', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }


  // Toggle button for Yourself / Another Person
  Widget toggleButton(String text) {
    final bool isSelected = selectedPatient == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPatient = text;
          // When switching to "Another Person", clear email to force user to enter it
          // When switching back to "Yourself", restore logged-in user's email
          if (text == 'Another Person') {
            patientEmailController.text = ''; // Clear for other person
          } else {
            // Restore user's email
            final user = Supabase.instance.client.auth.currentUser;
            patientEmailController.text = user?.email ?? '';
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFEDEFFF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // Toggle button for Male / Female
  Widget genderButton(String text) {
    final bool isSelected = selectedGender == text;
    return GestureDetector(
      onTap: () => setState(() => selectedGender = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : const Color(0xFFEDEFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  // Aadhar field with formatting and validation
  Widget buildAadharField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Aadhar Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            if (aadharController.text.isNotEmpty)
              Icon(
                _isAadharValid() ? Icons.check_circle : Icons.error,
                color: _isAadharValid() ? Colors.green : Colors.red,
                size: 20,
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: aadharController,
          keyboardType: TextInputType.number,
          maxLength: 14, // 12 digits + 2 spaces
          onChanged: (value) {
            // Auto-format as user types: XXXX XXXX XXXX
            String digitsOnly = value.replaceAll(RegExp(r'\s+'), '');
            if (digitsOnly.length > 12) {
              digitsOnly = digitsOnly.substring(0, 12);
            }
            
            String formatted = '';
            for (int i = 0; i < digitsOnly.length; i++) {
              if (i > 0 && i % 4 == 0) {
                formatted += ' ';
              }
              formatted += digitsOnly[i];
            }
            
            if (formatted != value) {
              aadharController.value = TextEditingValue(
                text: formatted,
                selection: TextSelection.collapsed(offset: formatted.length),
              );
            }
            setState(() {}); // Rebuild to show validation icon
          },
          decoration: InputDecoration(
            hintText: 'XXXX XXXX XXXX',
            filled: true,
            fillColor: const Color(0xFFEDEFFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counterText: '', // Hide character counter
            suffixIcon: aadharController.text.isNotEmpty
                ? Icon(
                    _isAadharValid() ? Icons.check_circle : Icons.cancel,
                    color: _isAadharValid() ? Colors.green : Colors.red,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  bool _isAadharValid() {
    final aadhar = aadharController.text.replaceAll(RegExp(r'\s+'), '');
    if (aadhar.isEmpty) return false;
    if (aadhar.length != 12) return false;
    if (int.tryParse(aadhar) == null) return false;
    if (RegExp(r'^(\d)\1{11}$').hasMatch(aadhar)) return false;
    if (aadhar.startsWith('0') || aadhar.startsWith('1')) return false;
    return _validateAadharChecksum(aadhar);
  }

  // Reusable text field
  Widget buildTextField(String hint, {TextEditingController? controller, TextInputType keyboardType = TextInputType.text, List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFEDEFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Phone field with country code dropdown
  Widget buildPhoneField(String label, TextEditingController controller, String selectedCode, Function(String?) onCountryChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                value: selectedCode,
                underline: const SizedBox(),
                items: countryCodes.map((code) {
                  return DropdownMenuItem<String>(
                    value: code['code'] as String,
                    child: Text('${code['code']} ${code['country']}', style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: onCountryChanged,
              ),
            ),
            const SizedBox(width: 12),
            // Phone Number Field
            Expanded(
              child: TextField(
                key: ValueKey(selectedCode), // Rebuild when country changes
                controller: controller,
                keyboardType: TextInputType.phone,
                autocorrect: false,
                enableSuggestions: false,
                enableInteractiveSelection: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(getPhoneNumberLength(selectedCode)),
                ],
                decoration: InputDecoration(
                  hintText: getPhonePlaceholder(selectedCode),
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
      ],
    );
  }
}
