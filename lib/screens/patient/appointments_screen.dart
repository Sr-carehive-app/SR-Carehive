import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:care12/widgets/registration_payment_dialog.dart';
import 'package:care12/models/payment_models.dart';
import 'package:care12/services/payment_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final Color primaryColor = const Color(0xFF2260FF);
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;
  String? errorMessage;
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        setState(() {
          errorMessage = 'User not logged in';
          isLoading = false;
        });
        return;
      }

      // Get patient_id first
      final patient = await supabase
          .from('patients')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (patient == null) {
        setState(() {
          errorMessage = 'Healthcare seeker profile not found';
          isLoading = false;
        });
        return;
      }

    // Fetch appointments for this healthcare seeker(all statuses)
      final response = await supabase
          .from('appointments')
          .select('*')
      .eq('patient_id', patient['id'])
          .order('created_at', ascending: false);

      setState(() {
        appointments = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load appointments: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'approved':
        return Colors.green;
      case 'booked':
        return const Color(0xFF2260FF); // Blue - registration paid
      case 'amount_set':
        return Colors.purple; // Purple - amount set, waiting for pre-payment
      case 'pre_paid':
        return Colors.indigo; // Indigo - pre-payment done
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.teal; // Teal - all payments complete
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey; // Grey - archived/expired appointments
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return '✓';
      case 'approved':
        return '✓';
      case 'pending':
        return '⏳';
      case 'completed':
        return '✓';
      case 'rejected':
        return '✗';
      case 'cancelled':
        return '✗';
      case 'booked':
        return '✓';
      case 'amount_set':
        return '💰';
      case 'pre_paid':
        return '💳';
      case 'expired':
        return '⏰';
      default:
        return '?';
    }
  }

  List<Map<String, dynamic>> _filtered() {
    if (_statusFilter == 'All') return appointments;
    // Map display tab to status value in DB
    final statusMap = {
      'Pending': 'pending',
      'Approved': 'approved',
      'Rejected': 'rejected',
      'Completed': 'completed',
      'Booked': 'booked',
      'Amount Set': 'amount_set',
      'Pre Paid': 'pre_paid',
      'Cancelled': 'cancelled',
    };
    final want = statusMap[_statusFilter] ?? _statusFilter.toLowerCase();
    return appointments.where((e) => (e['status'] ?? '').toString().toLowerCase() == want).toList();
  }

  Widget _filtersBar() {
    final options = ['All', 'Pending', 'Approved', 'Rejected', 'Completed', 'Booked', 'Amount Set', 'Pre Paid', 'Cancelled'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) => ChoiceChip(
        label: Text(o),
        selected: _statusFilter == o,
        onSelected: (selected) {
          if (selected) setState(() { _statusFilter = o; });
        },
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAppointments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                      onRefresh: _loadAppointments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: 1 + _filtered().length,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _filtersBar(),
                                const SizedBox(height: 12),
                                if (_filtered().isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          Text(
                                            appointments.isEmpty 
                                                ? 'No appointments found'
                                                : 'No appointments to show',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (appointments.isEmpty) ...[
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Schedule your first appointment to get started',
                                              style: TextStyle(color: Colors.grey),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }
                          final appointment = _filtered()[index - 1];
                          final date = DateTime.tryParse(appointment['date'] ?? '');
                          final time = appointment['time'] ?? '';
                          final status = appointment['status'] ?? 'pending';
                          final problem = appointment['problem'] ?? '';
                          final patientType = appointment['patient_type'] ?? 'Yourself';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appointment['full_name'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Age: ${appointment['age'] ?? 'N/A'} | ${appointment['gender'] ?? 'N/A'}',
                                              style: const TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _getStatusIcon(status),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              status.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        date != null 
                                            ? DateFormat('MMM dd, yyyy').format(date)
                                            : 'Date not available',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.access_time, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        time,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        'For: $patientType',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  if (problem.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Problem Description:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      problem,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  
                                  // healthcare seeker Details Section
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade100),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Healthcare seeker Details',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (appointment['phone'] != null) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.phone, size: 16, color: primaryColor),
                                              const SizedBox(width: 8),
                                              Text(
                                                appointment['phone'],
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        if (appointment['address'] != null) ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.location_on, size: 16, color: primaryColor),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  appointment['address'],
                                                  style: const TextStyle(fontSize: 13),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        if (appointment['emergency_contact'] != null) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.emergency, size: 16, color: Colors.red),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Emergency: ${appointment['emergency_contact']}',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                        if (appointment['aadhar_number'] != null) ...[
                                          Row(
                                            children: [
                                              Icon(Icons.credit_card, size: 16, color: primaryColor),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Aadhar: ${appointment['aadhar_number']}',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  // Primary Doctor Details (if provided)
                                  if (appointment['primary_doctor_name'] != null || 
                                      appointment['primary_doctor_phone'] != null ||
                                      appointment['primary_doctor_location'] != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade100),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Primary Doctor',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (appointment['primary_doctor_name'] != null)
                                            Text('Name: ${appointment['primary_doctor_name']}', 
                                              style: const TextStyle(fontSize: 13)),
                                          if (appointment['primary_doctor_phone'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text('Phone: ${appointment['primary_doctor_phone']}',
                                              style: const TextStyle(fontSize: 13)),
                                          ],
                                          if (appointment['primary_doctor_location'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text('Location: ${appointment['primary_doctor_location']}',
                                              style: const TextStyle(fontSize: 13)),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        appointment['phone'] ?? 'Phone not available',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  // Payment Section
                                  if (_shouldShowPaymentSection(appointment)) ...[
                                    const Divider(height: 24),
                                    _buildPaymentSection(appointment),
                                  ],
                                  
                                  // Post-Visit Consultation Details (shown after visit completed by nurse)
                                  if (appointment['visit_completion_enabled'] == true && 
                                      (appointment['post_visit_remarks'] != null || appointment['consulted_doctor_name'] != null)) ...[
                                    const Divider(height: 24),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.medical_services, color: Colors.green.shade700),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Post-Visit Summary',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ],
                                          ),
                                          if (appointment['post_visit_remarks'] != null) ...[
                                            const SizedBox(height: 12),
                                            const Text('Healthcare provider Remarks:', style: TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(appointment['post_visit_remarks']),
                                          ],
                                          if (appointment['consulted_doctor_name'] != null) ...[
                                            const SizedBox(height: 12),
                                            const Divider(),
                                            const Text('Recommended Doctor', style: TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            if (appointment['consulted_doctor_name'] != null)
                                              Text('Name: ${appointment['consulted_doctor_name']}'),
                                            if (appointment['consulted_doctor_phone'] != null)
                                              Text('Phone: ${appointment['consulted_doctor_phone']}'),
                                            if (appointment['consulted_doctor_specialization'] != null)
                                              Text('Specialization: ${appointment['consulted_doctor_specialization']}'),
                                            if (appointment['consulted_doctor_clinic_address'] != null) ...[
                                              const SizedBox(height: 4),
                                              Text('Clinic: ${appointment['consulted_doctor_clinic_address']}'),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  // healthcare provider assignment details (shown when approved)
                                  if ((appointment['status'] ?? '').toString().toLowerCase() == 'approved') ...[
                                    const Divider(height: 24),
                                    const Text(
                                      'Assigned Healthcare Provider',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    if (appointment['nurse_name'] != null)
                                      Text('Name: ${appointment['nurse_name']}'),
                                    if (appointment['nurse_phone'] != null)
                                      Text('Phone: ${appointment['nurse_phone']}'),
                                    if (appointment['nurse_branch'] != null)
                                      Text('Branch: ${appointment['nurse_branch']}'),
                                    if (appointment['nurse_comments'] != null)
                                      Text('Comments: ${appointment['nurse_comments']}'),
                                  ],
                                  // Rejection details if any
                                  if ((appointment['status'] ?? '').toString().toLowerCase() == 'rejected') ...[
                                    const Divider(height: 24),
                                    const Text('Request Rejected', style: TextStyle(fontWeight: FontWeight.bold)),
                                    if (appointment['rejection_reason'] != null)
                                      Text('Reason: ${appointment['rejection_reason']}'),
                                  ],
                                  // Cancellation details if any
                                  if ((appointment['status'] ?? '').toString().toLowerCase() == 'cancelled') ...[
                                    const Divider(height: 24),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Appointment Cancelled',
                                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 15),
                                              ),
                                            ],
                                          ),
                                          if (appointment['cancellation_reason'] != null) ...[
                                            const SizedBox(height: 8),
                                            const Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 4),
                                            Text(
                                              appointment['cancellation_reason'],
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          const Text(
                                            'If payment was deducted, refund will be processed within 5-7 business days.',
                                            style: TextStyle(fontSize: 12, color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  // Cancel button for eligible statuses
                                  if (_canCancelAppointment((appointment['status'] ?? '').toString().toLowerCase())) ...[
                                    const Divider(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _cancelAppointment(appointment),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: const Icon(Icons.cancel_outlined),
                                        label: const Text(
                                          'Cancel Appointment',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  bool _shouldShowPaymentSection(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? '').toString().toLowerCase();
    return status == 'approved' || 
           status == 'booked' || 
           status == 'amount_set' || 
           status == 'pre_paid' ||
           status == 'completed';
  }

  bool _canCancelAppointment(String status) {
    final s = status.toLowerCase();
    return s == 'pending' || s == 'approved' || s == 'booked' || s == 'amount_set' || s == 'pre_paid';
  }

  Future<void> _cancelAppointment(Map<String, dynamic> appointment) async {
    final reasonCtrl = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Cancel Appointment',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to cancel this appointment?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason (Optional)',
                  hintText: 'Please share why you are cancelling...',
                  border: OutlineInputBorder(),
                  helperText: 'This helps us improve our service',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'If payment was deducted, refund will be processed within 5-7 business days.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final supabase = Supabase.instance.client;
      final appointmentId = appointment['id'].toString();
      final cancellationReason = reasonCtrl.text.trim();
      
      try {
        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cancelling appointment...'),
                  ],
                ),
              ),
            ),
          ),
        );

        // Update appointment status to cancelled
        await supabase.from('appointments').update({
          'status': 'cancelled',
          'cancellation_reason': cancellationReason.isEmpty ? null : cancellationReason,
          'cancelled_at': DateTime.now().toIso8601String(),
        }).eq('id', appointmentId);

        // Send email notifications
        try {
          final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
          final notifyUri = Uri.parse('$apiBase/api/notify-appointment-cancelled');

          await http.post(
            notifyUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'appointmentId': appointmentId,
              'patientEmail': appointment['patient_email'],
              'patientName': appointment['full_name'],
              'patientPhone': appointment['phone'],
              'date': appointment['date'],
              'time': appointment['time'],
              'status': appointment['status'],
              'cancellationReason': cancellationReason.isEmpty ? 'Not provided' : cancellationReason,
              'registrationPaid': appointment['registration_paid'] ?? false,
              'totalAmount': appointment['total_amount'],
              'prePaid': appointment['pre_paid'] ?? false,
            }),
          );
        } catch (notifyError) {
          print('[WARN] Could not send cancellation notification: $notifyError');
        }

        if (!mounted) return;
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Appointment cancelled successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        _loadAppointments(); // Reload appointments
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading if still open
        
        // Print detailed error for debugging
        print('[ERROR] Cancellation failed: $e');
        print('[ERROR] Appointment ID: $appointmentId');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel appointment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildPaymentSection(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? '').toString().toLowerCase();
    final registrationPaid = appointment['registration_paid'] ?? false;
    final totalAmount = appointment['total_amount'];
    final prePaid = appointment['pre_paid'] ?? false;
    final finalPaid = appointment['final_paid'] ?? false;
    final nurseRemarks = appointment['nurse_remarks'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2260FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Payment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Registration Payment Status
          _buildPaymentStatusRow(
            'Registration Fee',
            '₹10',
            registrationPaid,
            appointment['registration_payment_id'],
          ),

          // Show "Pay ₹10" button if approved and not paid
          if (status == 'approved' && !registrationPaid) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRegistrationPaymentDialog(appointment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text(
                  'Pay ₹10 to Register Booking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Our healthcare provider will contact you after payment',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],

          // Show waiting message if booked but amount not set
          if (status == 'booked' && totalAmount == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Waiting for healthcare provider to set the total service amount',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Show total amount and split payments
          if (totalAmount != null) ...[
            const Divider(height: 24),
            Text(
              'Total Service Amount: ₹${totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (nurseRemarks != null) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks: $nurseRemarks',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),

            // Pre-payment status
            _buildPaymentStatusRow(
              'Pre-Visit Charges (50%)',
              '₹${(totalAmount / 2).toStringAsFixed(0)}',
              prePaid,
              appointment['pre_payment_id'],
            ),

            // Pre-payment button
            if (!prePaid && status == 'amount_set') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payPreVisit(appointment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: Text(
                    'Pay ₹${(totalAmount / 2).toStringAsFixed(0)} (Pre-Visit)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Final payment status
            _buildPaymentStatusRow(
              'Final Charges (50%)',
              '₹${(totalAmount / 2).toStringAsFixed(0)}',
              finalPaid,
              appointment['final_payment_id'],
            ),

            // Show visit completion status if pre-paid but visit not completed
            if (prePaid && !finalPaid && (appointment['visit_completion_enabled'] != true)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Healthcare provider will enable final payment after completing your visit',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Final payment button - only show when visit completion is enabled
            if (prePaid && !finalPaid && (appointment['visit_completion_enabled'] == true)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payFinalAmount(appointment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: Text(
                    'Pay ₹${(totalAmount / 2).toStringAsFixed(0)} (Final)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            // Completion message
            if (finalPaid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '✅ Payment Completed! Total: ₹',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${(10 + totalAmount).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              // Feedback button for completed appointments
              const SizedBox(height: 12),
              FutureBuilder<bool>(
                future: _checkIfFeedbackExists(appointment['id'].toString()),
                builder: (context, snapshot) {
                  final feedbackExists = snapshot.data ?? false;
                  
                  return SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: feedbackExists 
                          ? null 
                          : () => _showFeedbackDialog(appointment['id'].toString(), appointment),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: feedbackExists ? Colors.grey : Colors.amber,
                        side: BorderSide(color: feedbackExists ? Colors.grey : Colors.amber),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: feedbackExists ? Colors.grey.shade100 : null,
                      ),
                      icon: Icon(
                        feedbackExists ? Icons.check_circle : Icons.star, 
                        color: feedbackExists ? Colors.grey : Colors.amber,
                      ),
                      label: Text(
                        feedbackExists ? 'Feedback Submitted' : 'Share Your Feedback',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: feedbackExists ? Colors.grey : Colors.amber,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentStatusRow(
    String label,
    String amount,
    bool isPaid,
    String? paymentId,
  ) {
    return Row(
      children: [
        Icon(
          isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isPaid ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (isPaid && paymentId != null)
                Text(
                  'ID: ${paymentId.length > 20 ? paymentId.substring(0, 20) + '...' : paymentId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isPaid ? Colors.green : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isPaid ? 'PAID' : 'PENDING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.green : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  void _showRegistrationPaymentDialog(Map<String, dynamic> appointment) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    // Get appointment ID as String (UUID format)
    final String appointmentId = appointment['id'].toString();
    
    print('🔍 DEBUG: appointment ID = $appointmentId');
    
    showDialog(
      context: context,
      builder: (context) => RegistrationPaymentDialog(
        appointmentId: appointmentId,
        patientName: appointment['full_name'] ?? '',
        patientEmail: user?.email ?? appointment['patient_email'] ?? '',
        patientPhone: appointment['phone'] ?? '',
        onSuccess: () {
          _loadAppointments(); // Reload appointments
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Registration payment successful!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _payPreVisit(Map<String, dynamic> appointment) async {
    final totalAmount = appointment['total_amount'];
    if (totalAmount == null) return;

    // Get appointment ID as String (UUID format)
    final String appointmentId = appointment['id'].toString();

    // CRITICAL FIX: Store navigator and scaffold messenger before any navigation
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing Payment...'),
                ],
              ),
            ),
          ),
        ),
      );

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      final result = await PaymentService.payPreVisitAmount(
        appointmentId: appointmentId,
        totalAmount: (totalAmount as num).toDouble(),
        email: user?.email ?? appointment['patient_email'] ?? '',
        mobile: appointment['phone'] ?? '',
        name: appointment['full_name'] ?? '',
      );

      // Close loading dialog immediately
      navigator.pop();
      
      // Extract payment ID
      final paymentId = result['razorpay_payment_id']?.toString() ?? 
                       result['payment_id']?.toString() ?? 
                       result['paymentId']?.toString() ?? 
                       'Completed';
      
      // Small delay to ensure context stability
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Reload appointments to reflect updated status
      if (mounted) {
        await _loadAppointments();
      }
      
      // Show success message
      scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '✅ Pre-visit payment of ₹${(totalAmount / 2).toStringAsFixed(0)} successful!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment ID: $paymentId',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      navigator.pop();
      String errorMsg = 'Payment failed. Please try again.';
      try {
        dynamic err = e;
        if (err is Exception) err = err.toString();
        if (err is Map && err['error'] != null) {
          final code = err['error']['code']?.toString()?.toLowerCase();
          if (code == 'payment_cancelled' || code == 'cancelled') {
            errorMsg = 'Payment cancelled. Please try again.';
          }
        } else if (err is String) {
          final lower = err.toLowerCase();
          if (lower.contains('cancelled')) {
            errorMsg = 'Payment cancelled. Please try again.';
          } else if (lower.contains('{error:')) {
            // Try to extract description
            final descMatch = RegExp(r'description: ([^}]+)').firstMatch(lower);
            if (descMatch != null && descMatch.group(1)?.contains('cancelled') == true) {
              errorMsg = 'Payment cancelled. Please try again.';
            }
          }
        }
      } catch (_) {}
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMsg)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _payFinalAmount(Map<String, dynamic> appointment) async {
    final totalAmount = appointment['total_amount'];
    if (totalAmount == null) return;

    // Get appointment ID as String (UUID format)
    final String appointmentId = appointment['id'].toString();

    // CRITICAL FIX: Store navigator and scaffold messenger before any navigation
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing Payment...'),
                ],
              ),
            ),
          ),
        ),
      );

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      final result = await PaymentService.payFinalAmount(
        appointmentId: appointmentId,
        totalAmount: (totalAmount as num).toDouble(),
        email: user?.email ?? appointment['patient_email'] ?? '',
        mobile: appointment['phone'] ?? '',
        name: appointment['full_name'] ?? '',
      );

      // Close loading dialog immediately
      navigator.pop();
      
      // Extract payment ID
      final paymentId = result['razorpay_payment_id']?.toString() ?? 
                       result['payment_id']?.toString() ?? 
                       result['paymentId']?.toString() ?? 
                       'Completed';
      
      // Small delay to ensure context stability
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Reload appointments to reflect updated status
      if (mounted) {
        await _loadAppointments();
      }
      
      // Show success message
      scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '✅ Final payment of ₹${(totalAmount / 2).toStringAsFixed(0)} successful!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment ID: $paymentId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '🎉 Appointment completed! Thank you.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      
      // Show feedback dialog after short delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _showFeedbackDialog(appointmentId, appointment);
      }
    } catch (e) {
      navigator.pop();
      String errorMsg = 'Payment failed. Please try again.';
      try {
        dynamic err = e;
        if (err is Exception) err = err.toString();
        if (err is Map && err['error'] != null) {
          final code = err['error']['code']?.toString()?.toLowerCase();
          if (code == 'payment_cancelled' || code == 'cancelled') {
            errorMsg = 'Payment cancelled. Please try again.';
          }
        } else if (err is String) {
          final lower = err.toLowerCase();
          if (lower.contains('cancelled')) {
            errorMsg = 'Payment cancelled. Please try again.';
          } else if (lower.contains('{error:')) {
            final descMatch = RegExp(r'description: ([^}]+)').firstMatch(lower);
            if (descMatch != null && descMatch.group(1)?.contains('cancelled') == true) {
              errorMsg = 'Payment cancelled. Please try again.';
            }
          }
        }
      } catch (_) {}
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMsg)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Check if feedback already exists for this appointment
  Future<bool> _checkIfFeedbackExists(String appointmentId) async {
    try {
      final supabase = Supabase.instance.client;
      final existingFeedback = await supabase
          .from('appointment_feedback')
          .select('id')
          .eq('appointment_id', appointmentId)
          .maybeSingle();
      
      return existingFeedback != null;
    } catch (e) {
      print('[ERROR] Failed to check feedback: $e');
      return false;
    }
  }

  // Show feedback dialog after final payment
  Future<void> _showFeedbackDialog(String appointmentId, Map<String, dynamic> appointment) async {
    // Check if feedback already exists
    try {
      final supabase = Supabase.instance.client;
      final existingFeedback = await supabase
          .from('appointment_feedback')
          .select('id')
          .eq('appointment_id', appointmentId)
          .maybeSingle();
      
      if (existingFeedback != null) {
        // Feedback already submitted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have already submitted feedback for this appointment'),
              backgroundColor: Colors.blue,
            ),
          );
        }
        return;
      }
    } catch (e) {
      print('[ERROR] Failed to check existing feedback: $e');
      // Continue to show dialog anyway
    }
    
    int overallRating = 0;
    int nurseProfessionalismRating = 0;
    int serviceQualityRating = 0;
    int communicationRating = 0;
    int punctualityRating = 0;
    bool wouldRecommend = false;
    bool satisfiedWithService = false;
    
    final positiveFeedbackCtrl = TextEditingController();
    final improvementSuggestionsCtrl = TextEditingController();
    final additionalCommentsCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Rate Your Experience',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Help us improve our service',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.normal),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Rating
                _buildRatingRow('Overall Experience', overallRating, (rating) {
                  setState(() => overallRating = rating);
                }),
                const Divider(height: 24),
                
                // Healthcare provider Professionalism
                _buildRatingRow('Healthcare provider Professionalism', nurseProfessionalismRating, (rating) {
                  setState(() => nurseProfessionalismRating = rating);
                }),
                const Divider(height: 24),
                
                // Service Quality
                _buildRatingRow('Service Quality', serviceQualityRating, (rating) {
                  setState(() => serviceQualityRating = rating);
                }),
                const Divider(height: 24),
                
                // Communication
                _buildRatingRow('Communication', communicationRating, (rating) {
                  setState(() => communicationRating = rating);
                }),
                const Divider(height: 24),
                
                // Punctuality
                _buildRatingRow('Punctuality', punctualityRating, (rating) {
                  setState(() => punctualityRating = rating);
                }),
                const Divider(height: 24),
                
                // Positive Feedback
                TextField(
                  controller: positiveFeedbackCtrl,
                  decoration: const InputDecoration(
                    labelText: 'What did you like?',
                    hintText: 'Tell us what you appreciated...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Improvement Suggestions
                TextField(
                  controller: improvementSuggestionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Any suggestions for improvement?',
                    hintText: 'How can we serve you better...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Additional Comments
                TextField(
                  controller: additionalCommentsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Additional Comments',
                    hintText: 'Any other feedback...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                // Checkboxes
                CheckboxListTile(
                  title: const Text('I would recommend this service'),
                  value: wouldRecommend,
                  onChanged: (value) {
                    setState(() => wouldRecommend = value ?? false);
                  },
                ),
                CheckboxListTile(
                  title: const Text('I am satisfied with the service'),
                  value: satisfiedWithService,
                  onChanged: (value) {
                    setState(() => satisfiedWithService = value ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: overallRating == 0 
                ? null
                : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Submit Feedback', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true && overallRating > 0) {
      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        
        // Get healthcare seeker ID
        String? patientId;
        if (user != null) {
          try {
            final patient = await supabase
                .from('patients')
                .select('id')
                .eq('user_id', user.id)
                .maybeSingle();
            patientId = patient?['id']?.toString();
          } catch (_) {}
        }

        // Submit feedback
        await supabase.from('appointment_feedback').insert({
          'appointment_id': appointmentId,
          'patient_id': patientId,
          'overall_rating': overallRating,
          'nurse_professionalism_rating': nurseProfessionalismRating,
          'service_quality_rating': serviceQualityRating,
          'communication_rating': communicationRating,
          'punctuality_rating': punctualityRating,
          'positive_feedback': positiveFeedbackCtrl.text.trim().isEmpty ? null : positiveFeedbackCtrl.text.trim(),
          'improvement_suggestions': improvementSuggestionsCtrl.text.trim().isEmpty ? null : improvementSuggestionsCtrl.text.trim(),
          'additional_comments': additionalCommentsCtrl.text.trim().isEmpty ? null : additionalCommentsCtrl.text.trim(),
          'would_recommend': wouldRecommend,
          'satisfied_with_service': satisfiedWithService,
        });

        // Send thank you email notification
        try {
          final apiBase = dotenv.env['API_BASE_URL'] ?? 'https://api.srcarehive.com';
          final notifyUri = Uri.parse('$apiBase/api/notify-feedback-submitted');
          
          await http.post(
            notifyUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'appointmentId': appointmentId,
              'patientEmail': appointment['patient_email'],
              'patientName': appointment['full_name'],
              'overallRating': overallRating,
              'nurseProfessionalismRating': nurseProfessionalismRating,
              'serviceQualityRating': serviceQualityRating,
              'communicationRating': communicationRating,
              'punctualityRating': punctualityRating,
              'positiveFeedback': positiveFeedbackCtrl.text.trim(),
              'improvementSuggestions': improvementSuggestionsCtrl.text.trim(),
              'additionalComments': additionalCommentsCtrl.text.trim(),
              'wouldRecommend': wouldRecommend,
              'satisfiedWithService': satisfiedWithService,
            }),
          );
        } catch (notifyError) {
          print('[WARN] Could not send feedback notification: $notifyError');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Thank you for your feedback!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to submit feedback: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildRatingRow(String label, int rating, Function(int) onRatingChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => onRatingChange(index + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
} 