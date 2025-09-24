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
    super.dispose();
  }

  /// Load user data from patients table
  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final patient = await supabase
            .from('patients')
            .select('name, phone, permanent_address')
            .eq('user_id', user.id)
            .maybeSingle();
        
        if (patient != null) {
          setState(() {
            fullNameController.text = patient['name'] ?? '';
            phoneController.text = patient['phone'] ?? '';
            addressController.text = patient['permanent_address'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() => isLoading = false);
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
    setState(() => isSubmitting = true);
    try {
      // Initiate payment first – do NOT store appointment as paid yet.
      final amount = '1.00'; // TODO: derive from selected service / duration.
      final email = phoneController.text.contains('@') ? phoneController.text : 'srcarehive@gmail.com';
      final mobile = phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : '8923068966';
      // Minimal appointment object for server to persist after payment success
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      int? patientId;
      if (user != null) {
        try {
          final patient = await supabase.from('patients').select('id').eq('user_id', user.id).maybeSingle();
          patientId = patient?['id'];
        } catch (_) {}
      }
      final apptPayload = {
        'patient_id': patientId,
        'full_name': fullNameController.text.trim(),
        'age': int.tryParse(ageController.text.trim()) ?? 0,
        'gender': selectedGender,
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'emergency_contact': emergencyContactController.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(selectedDate),
        'time': selectedTime,
        'problem': problemController.text.trim(),
        'patient_type': selectedPatient,
      };
      final resp = await PaymentService.payWithRazorpay(
        amount: amount,
        email: email,
        mobile: mobile,
        name: fullNameController.text.trim(),
        appointment: apptPayload,
        description: 'Nurse Appointment',
      );
      _showSuccessSnackBar('Payment successful');
    } catch (e) {
  _showErrorSnackBar('Payment failed: $e');
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _clearForm() {
    // Don't clear name, phone, address as they're user data
    ageController.clear();
    emergencyContactController.clear();
    problemController.clear();
    selectedGender = 'Female';
    selectedPatient = 'Yourself';
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

          // Patient Details section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Patient Details',
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

          // Payment button
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
                      Text('Processing...', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ],
                  )
                : const Text('Payment', style: TextStyle(fontSize: 16, color: Colors.white)),
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
