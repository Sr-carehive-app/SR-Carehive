import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/services/payment_service.dart';
// url_launcher no longer needed for payment redirect; Razorpay SDK opens checkout.

class ScheduleNurseScreen extends StatefulWidget {
  const ScheduleNurseScreen({Key? key}) : super(key: key);

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
  
  bool isLoading = false;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    weekDates = getCurrentWeekDates();
    updateTimeSlotsForDate(selectedDate);
    _loadUserData();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    addressController.dispose();
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
            .select('name, phone, permanent_address, aadhar_number')
            .eq('user_id', user.id)
            .maybeSingle();
        
        if (patient != null) {
          setState(() {
            fullNameController.text = patient['name'] ?? '';
            phoneController.text = patient['phone'] ?? '';
            addressController.text = patient['permanent_address'] ?? '';
            aadharController.text = patient['aadhar_number'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Generate current week's dates (Mon–Sun)
  List<DateTime> getCurrentWeekDates() {
    DateTime now = DateTime.now();
    int weekday = now.weekday; // Monday = 1
    DateTime monday = now.subtract(Duration(days: weekday - 1));
    return List.generate(7, (index) => monday.add(Duration(days: index)));
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
    if (phoneController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter phone number');
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
    if (primaryDoctorPhoneController.text.trim().isNotEmpty) {
      final phone = primaryDoctorPhoneController.text.trim();
      if (phone.length != 10 || int.tryParse(phone) == null) {
        _showErrorSnackBar('Primary doctor phone must be 10 digits');
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
        'full_name': fullNameController.text.trim(),
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
        'patient_email': (user?.email ?? '').trim(),
        'status': 'pending', // Admin will approve/reject
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await supabase.from('appointments').insert(appointmentData);
      
      if (mounted) {
        _showSuccessSnackBar('Appointment request submitted successfully! Admin will review shortly.');
        _clearForm();
        // Navigate to appointments page
        Navigator.of(context).pushReplacementNamed('/appointments');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Failed to submit appointment: $e');
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
          title: const Text('Schedule'),
          backgroundColor: primaryColor,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        backgroundColor: primaryColor,
        centerTitle: true,
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

          // Care Seeker section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Care Seeker Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  toggleButton('Yourself'),
                  const SizedBox(width: 8),
                  toggleButton('Another Person'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Patient information fields
          buildTextField('Full Name', controller: fullNameController),
          const SizedBox(height: 16),
          buildTextField('Age', controller: ageController, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          buildTextField('Phone Number', controller: phoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          buildTextField('Address', controller: addressController, keyboardType: TextInputType.multiline),
          const SizedBox(height: 16),
          buildTextField('Emergency Contact', controller: emergencyContactController, keyboardType: TextInputType.phone),
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
          buildTextField('Doctor Phone Number', controller: primaryDoctorPhoneController, keyboardType: TextInputType.phone),
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
      onTap: () => setState(() => selectedPatient = text),
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
  Widget buildTextField(String hint, {TextEditingController? controller, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
}
