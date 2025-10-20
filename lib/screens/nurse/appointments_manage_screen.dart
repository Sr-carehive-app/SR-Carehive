import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NurseAppointmentsManageScreen extends StatefulWidget {
  const NurseAppointmentsManageScreen({Key? key}) : super(key: key);

  @override
  State<NurseAppointmentsManageScreen> createState() => _NurseAppointmentsManageScreenState();
}

class _NurseAppointmentsManageScreenState extends State<NurseAppointmentsManageScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _statusFilter = 'All';
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { _items = await NurseApiService.listAppointments(); } catch (e) { _error = e.toString(); }
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _approveDialog(Map<String, dynamic> appt) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final branchCtrl = TextEditingController();
    final commentsCtrl = TextEditingController();
    bool available = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & Assign Healthcare Provider'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Healthcare provider name')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Healthcare provider phone')),
              TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Branch/Office')),
              TextField(controller: commentsCtrl, decoration: const InputDecoration(labelText: 'Comments'), maxLines: 3),
              const SizedBox(height: 8),
              StatefulBuilder(builder: (ctx, setS) => CheckboxListTile(
                    title: const Text('Available for selected time/duration'),
                    value: available,
                    onChanged: (v) => setS(() => available = v ?? true),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await NurseApiService.approveAppointment(
          id: (appt['id'] ?? '').toString(),
          nurseName: nameCtrl.text.trim(),
          nursePhone: phoneCtrl.text.trim(),
          branch: branchCtrl.text.trim().isEmpty ? null : branchCtrl.text.trim(),
          comments: commentsCtrl.text.trim().isEmpty ? null : commentsCtrl.text.trim(),
          available: available,
        );
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved'))); _load();
      } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approve failed: $e'))); }
    }
  }

  Future<void> _rejectDialog(Map<String, dynamic> appt) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (ok == true) {
      if (reasonCtrl.text.trim().isEmpty) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason to reject.'))); return; }
      try { await NurseApiService.rejectAppointment(id: (appt['id'] ?? '').toString(), reason: reasonCtrl.text.trim()); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected'))); _load(); } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reject failed: $e'))); }
    }
  }

  Future<void> _setAmountDialog(Map<String, dynamic> appt) async {
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2260FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.attach_money, color: Color(0xFF2260FF)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Set Total Service Amount',
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
              // Info card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Healthcare seeker paid ₹100 registration fee. Set the total service amount based on requirements.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Amount field
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Total Amount (₹)',
                  hintText: 'e.g., 1000',
                  prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF2260FF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FF),
                ),
              ),
              const SizedBox(height: 16),
              
              // Remarks field
              TextField(
                controller: remarksCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Remarks/Breakdown',
                  hintText: 'Explain the amount breakdown...\ne.g., Nursing: ₹400, Medicines: ₹300, Transport: ₹300',
                  prefixIcon: const Icon(Icons.notes, color: Color(0xFF2260FF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FF),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              
              // Payment split info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Split:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text('50% before visit', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                        SizedBox(width: 8),
                        Text('50% after successful visit', style: TextStyle(fontSize: 12)),
                      ],
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2260FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (ok == true) {
      final amount = double.tryParse(amountCtrl.text.trim());
      
      // Validation
      if (amount == null || amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid amount greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final remarks = remarksCtrl.text.trim();
      if (remarks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide remarks explaining the amount'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      try {
        // Show loading
        if (!mounted) return;
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
                    Text('Updating amount...'),
                  ],
                ),
              ),
            ),
          ),
        );
        
        // Update in Supabase
        final supabase = Supabase.instance.client;
        await supabase.from('appointments').update({
          'total_amount': amount,
          'nurse_remarks': remarks,
          'status': 'amount_set',
        }).eq('id', appt['id']);
        
        // Send email/SMS notification to healthcare seeker
        try {
          final apiBase = dotenv.env['API_BASE_URL'] ?? 'http://localhost:9090';
          final notifyUri = Uri.parse('$apiBase/api/notify-amount-set');
          
          await http.post(
            notifyUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'appointmentId': appt['id'],
              'patientEmail': appt['patient_email'],
              'patientName': appt['full_name'],
              'patientPhone': appt['phone'],
              'totalAmount': amount,
              'nurseRemarks': remarks,
              'nurseName': appt['nurse_name'],
              'date': appt['date'],
              'time': appt['time'],
            }),
          );
          print('[INFO] Amount-set notification sent');
        } catch (notifyErr) {
          print('[ERROR] Failed to send notification: $notifyErr');
          // Don't fail the whole operation if notification fails
        }
        
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Total amount ₹${amount.toStringAsFixed(0)} set successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        _load(); // Reload appointments
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set amount: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitPostVisitConsultation(Map<String, dynamic> appt) async {
    final postVisitRemarksCtrl = TextEditingController();
    final doctorNameCtrl = TextEditingController();
    final doctorPhoneCtrl = TextEditingController();
    final doctorSpecializationCtrl = TextEditingController();
    final doctorClinicAddressCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.medical_services, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Post-Visit Consultation',
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
                'Visit Completion',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: postVisitRemarksCtrl,
                decoration: const InputDecoration(
                  labelText: 'Post-Visit Remarks *',
                  hintText: 'Describe the service provided, healthcare seeker condition, etc.',
                  border: OutlineInputBorder(),
                  helperText: 'Required: Summary of your visit',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Recommended Doctor (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Doctor Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Doctor Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorSpecializationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  hintText: 'e.g., Cardiologist, Pediatrician',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: doctorClinicAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Clinic Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
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
                    const Expanded(
                      child: Text(
                        'This will enable final payment for the healthcare seeker',
                        style: TextStyle(fontSize: 13),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Submit & Enable Final Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      final postVisitRemarks = postVisitRemarksCtrl.text.trim();
      
      // Validation
      if (postVisitRemarks.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Post-visit remarks are required'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        if (!mounted) return;
        
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
                    Text('Submitting...'),
                  ],
                ),
              ),
            ),
          ),
        );
        
        // Update in Supabase
        final supabase = Supabase.instance.client;
        await supabase.from('appointments').update({
          'post_visit_remarks': postVisitRemarks,
          'consulted_doctor_name': doctorNameCtrl.text.trim().isEmpty ? null : doctorNameCtrl.text.trim(),
          'consulted_doctor_phone': doctorPhoneCtrl.text.trim().isEmpty ? null : doctorPhoneCtrl.text.trim(),
          'consulted_doctor_specialization': doctorSpecializationCtrl.text.trim().isEmpty ? null : doctorSpecializationCtrl.text.trim(),
          'consulted_doctor_clinic_address': doctorClinicAddressCtrl.text.trim().isEmpty ? null : doctorClinicAddressCtrl.text.trim(),
          'visit_completed_at': DateTime.now().toIso8601String(),
          'visit_completion_enabled': true, // Enable final payment
        }).eq('id', appt['id']);
        
        // Send email/SMS notification to healthcare seeker
        try {
          final apiBase = dotenv.env['API_BASE_URL'] ?? 'http://localhost:9090';
          final notifyUri = Uri.parse('$apiBase/api/notify-visit-completed');
          
          await http.post(
            notifyUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'appointmentId': appt['id'],
              'patientEmail': appt['patient_email'],
              'patientName': appt['full_name'],
              'patientPhone': appt['phone'],
              'nurseName': appt['nurse_name'],
              'postVisitRemarks': postVisitRemarks,
              'doctorName': doctorNameCtrl.text.trim().isEmpty ? null : doctorNameCtrl.text.trim(),
              'doctorPhone': doctorPhoneCtrl.text.trim().isEmpty ? null : doctorPhoneCtrl.text.trim(),
              'doctorSpecialization': doctorSpecializationCtrl.text.trim().isEmpty ? null : doctorSpecializationCtrl.text.trim(),
              'doctorClinicAddress': doctorClinicAddressCtrl.text.trim().isEmpty ? null : doctorClinicAddressCtrl.text.trim(),
            }),
          );
        } catch (notifyError) {
          print('[WARN] Could not send visit completion notification: $notifyError');
        }
        
        if (!mounted) return;
        Navigator.pop(context); // Close loading
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Visit completed! Final payment enabled for healthcare seeker.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        _load(); // Reload appointments
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewDetails(Map<String, dynamic> a) async {
    String fmtDate() { final d = DateTime.tryParse(a['date'] ?? ''); return d != null ? DateFormat('MMM dd, yyyy').format(d) : 'N/A'; }
    String fmtVal(dynamic v) => (v == null || (v is String && v.trim().isEmpty)) ? '-' : v.toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a['full_name'] ?? 'Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Appointment Info
              const Text('Appointment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _kv('Date', fmtDate()),
              _kv('Time', fmtVal(a['time'])),
              
              // Patient Information
              const Divider(height: 24),
              const Text('Healthcare seeker Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _kv('Full Name', fmtVal(a['full_name'])),
              _kv('Age', fmtVal(a['age'])),
              _kv('Gender', fmtVal(a['gender'])),
              _kv('Patient Type', fmtVal(a['patient_type'])),
              
              // Contact Details
              const Divider(height: 24),
              const Text('Contact Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _kv('Email', fmtVal(a['patient_email'])),
              _kv('Phone', fmtVal(a['phone'])),
              _kv('Address', fmtVal(a['address'])),
              _kv('Emergency Contact', fmtVal(a['emergency_contact'])),
              
              // Medical Information
              const Divider(height: 24),
              const Text('Medical Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (a['problem'] != null && (a['problem'] as String).isNotEmpty) 
                _kv('Problem', a['problem']),
              if (a['aadhar_number'] != null && (a['aadhar_number'] as String).isNotEmpty)
                _kv('Aadhar Number', fmtVal(a['aadhar_number'])),
              
              // Primary Doctor Details
              if (a['primary_doctor_name'] != null || a['primary_doctor_phone'] != null || a['primary_doctor_location'] != null) ...[
                const Divider(height: 24),
                const Text('Primary Doctor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (a['primary_doctor_name'] != null && (a['primary_doctor_name'] as String).isNotEmpty)
                  _kv('Doctor Name', fmtVal(a['primary_doctor_name'])),
                if (a['primary_doctor_phone'] != null && (a['primary_doctor_phone'] as String).isNotEmpty)
                  _kv('Doctor Phone', fmtVal(a['primary_doctor_phone'])),
                if (a['primary_doctor_location'] != null && (a['primary_doctor_location'] as String).isNotEmpty)
                  _kv('Doctor Location', fmtVal(a['primary_doctor_location'])),
              ],
              
              // Payment Status (if applicable)
              if (a['total_amount'] != null || a['registration_paid'] == true) ...[
                const Divider(height: 24),
                const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (a['registration_paid'] == true)
                  _kv('Registration', '✅ Paid (₹1)'),
                if (a['total_amount'] != null)
                  _kv('Total Amount', '₹${a['total_amount']}'),
                if (a['pre_paid'] == true)
                  _kv('Pre-Payment', '✅ Paid (50%)'),
                if (a['final_paid'] == true)
                  _kv('Final Payment', '✅ Paid (50%)'),
              ],
              
              // Assigned healthcare provider Info
              if (a['status']?.toString().toLowerCase() == 'approved') ...[
                const Divider(height: 24),
                const Text('Assigned Nurse', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                _kv('Name', fmtVal(a['nurse_name'])),
                _kv('Phone', fmtVal(a['nurse_phone'])),
                _kv('Branch', fmtVal(a['nurse_branch'])),
                _kv('Comments', fmtVal(a['nurse_comments'])),
                _kv('Available', a['nurse_available'] == true ? 'Yes' : (a['nurse_available'] == false ? 'No' : '-')),
              ],
              
              // Rejection Info
              if (a['status']?.toString().toLowerCase() == 'rejected') ...[
                const Divider(height: 24),
                const Text('Rejection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                const SizedBox(height: 8),
                _kv('Reason', fmtVal(a['rejection_reason'])),
              ],
              
              // Post-Visit Consultation Details (NEW)
              if (a['post_visit_remarks'] != null || a['consulted_doctor_name'] != null) ...[
                const Divider(height: 24),
                const Text('Post-Visit Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                const SizedBox(height: 8),
                if (a['post_visit_remarks'] != null && (a['post_visit_remarks'] as String).isNotEmpty)
                  _kv('Healthcare provider Remarks', fmtVal(a['post_visit_remarks'])),
                if (a['visit_completed_at'] != null) ...[
                  (() {
                    try {
                      final dt = DateTime.parse(a['visit_completed_at'].toString());
                      final formatted = DateFormat('MMM dd, yyyy hh:mm a').format(dt);
                      return _kv('Visit Completed', formatted);
                    } catch (_) {
                      return _kv('Visit Completed', fmtVal(a['visit_completed_at']));
                    }
                  })(),
                ],
              ],
              
              // Recommended Doctor Details (NEW)
              if (a['consulted_doctor_name'] != null || a['consulted_doctor_phone'] != null || 
                  a['consulted_doctor_specialization'] != null || a['consulted_doctor_clinic_address'] != null) ...[
                const Divider(height: 24),
                const Text('🩺 Recommended Doctor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                const SizedBox(height: 8),
                if (a['consulted_doctor_name'] != null && (a['consulted_doctor_name'] as String).isNotEmpty)
                  _kv('Doctor Name', fmtVal(a['consulted_doctor_name'])),
                if (a['consulted_doctor_phone'] != null && (a['consulted_doctor_phone'] as String).isNotEmpty)
                  _kv('Phone', fmtVal(a['consulted_doctor_phone'])),
                if (a['consulted_doctor_specialization'] != null && (a['consulted_doctor_specialization'] as String).isNotEmpty)
                  _kv('Specialization', fmtVal(a['consulted_doctor_specialization'])),
                if (a['consulted_doctor_clinic_address'] != null && (a['consulted_doctor_clinic_address'] as String).isNotEmpty)
                  _kv('Clinic Address', fmtVal(a['consulted_doctor_clinic_address'])),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch(status.toLowerCase()) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'rejected': return Colors.red;
      case 'booked': return const Color(0xFF2260FF); // Blue - registration paid
      case 'amount_set': return Colors.purple; // Purple - amount set, waiting for pre-payment
      case 'pre_paid': return Colors.indigo; // Indigo - pre-payment done
      case 'completed': return Colors.teal; // Teal - all payments complete
      default: return Colors.grey;
    }
  }

  // Combine stored date ('yyyy-MM-dd') and time ('h:mm a') as local time.
  // Avoid UTC conversion to prevent shifting to previous day, which incorrectly
  // classifies appointments as past or upcoming.
  DateTime? _parseIst(Map a) {
    final dateStr = (a['date'] ?? '').toString();
    if (dateStr.isEmpty) return null;
    final base = DateTime.tryParse(dateStr); // local midnight
    if (base == null) return null;
    final timeStr = (a['time'] ?? '').toString().trim();
    int hour=0, minute=0;
    if (timeStr.isNotEmpty) {
      try { final t = DateFormat('h:mm a').parseStrict(timeStr); hour = t.hour; minute = t.minute; } catch(_){}
    }
    return DateTime(base.year, base.month, base.day, hour, minute);
  }

  bool _isPast(Map a){
    // Compare using date strings first to avoid timezone ambiguity
    final dateStr = (a['date'] ?? '').toString();
    if (dateStr.isEmpty) return false;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (dateStr.compareTo(todayStr) < 0) return true; // past date
    if (dateStr.compareTo(todayStr) > 0) return false; // future date
    // Same day: compare time in minutes; if time missing, consider it NOT past yet
    final timeStr = (a['time'] ?? '').toString().trim();
    if (timeStr.isEmpty) return false; // time unknown on same day -> not past
    int apptMins = 0;
    try { final t = DateFormat('h:mm a').parseStrict(timeStr); apptMins = t.hour * 60 + t.minute; } catch(_){ return false; }
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    return apptMins < nowMins;
  }

  @override
  Widget build(BuildContext context) {
    final listFiltered = _filtered();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Appointments'),
        actions:[
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh))
        ],
        backgroundColor: const Color(0xFF2260FF),
        centerTitle:true),
      body: _loading
          ? const Center(child:CircularProgressIndicator())
          : _error!=null
            ? Center(child: Text(_error!, style: const TextStyle(color:Colors.red)))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 1 + listFiltered.length,
                  itemBuilder: (ctx,i){
                    if(i==0){
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        _filtersBar(),
                        const SizedBox(height:12),
                        if(listFiltered.isEmpty) Padding(
                          padding: const EdgeInsets.symmetric(vertical:24),
                          child: Center(child: Text('No appointments to show')),
                        ),
                      ]);
                    }
                    final a = listFiltered[i-1];
                    final date = DateTime.tryParse(a['date'] ?? '');
                    final time = a['time'] ?? '';
                    final status = (a['status'] ?? 'pending') as String;
                    // History header logic removed
                    final card = Card(margin: const EdgeInsets.only(bottom:16), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                        Text(a['full_name'] ?? 'Unknown', style: const TextStyle(fontSize:16, fontWeight: FontWeight.bold)),
                        Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color:_statusColor(status), borderRadius: BorderRadius.circular(12)), child: Text(status.toUpperCase(), style: const TextStyle(color:Colors.white, fontSize:12, fontWeight: FontWeight.bold)))
                      ]),
                      const SizedBox(height:8),
                      Row(children:[ const Icon(Icons.calendar_today, size:14, color: Color(0xFF2260FF)), const SizedBox(width:6), Text(date!=null? DateFormat('MMM dd, yyyy').format(date):'N/A'), const SizedBox(width:12), const Icon(Icons.access_time, size:14, color: Color(0xFF2260FF)), const SizedBox(width:6), Text(time) ]),
                      const SizedBox(height:4),
                      Text('Phone: ${a['phone'] ?? '-'}'),
                      if(a['problem']!=null && (a['problem'] as String).isNotEmpty)...[ const SizedBox(height:8), Text('Problem: ${a['problem']}', style: const TextStyle(color: Colors.black54)) ],
                      
                      // Show registration payment status if booked
                      if(status.toLowerCase()=='booked')...[
                        const Divider(),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Registration Fee Paid (₹100)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if(a['registration_payment_id']!=null)...[
                          const SizedBox(height:4),
                          Text(
                            'Payment ID: ${_truncatePaymentId(a['registration_payment_id'])}', 
                            style: const TextStyle(fontSize:11, color: Colors.grey)
                          ),
                        ],
                      ],
                      
                      // Show total amount if set
                      if(a['total_amount']!=null)...[
                        const Divider(),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.attach_money, color: Colors.purple, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Total Amount: ₹${(a['total_amount'] as num).toStringAsFixed(0)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              if(a['nurse_remarks']!=null)...[
                                const SizedBox(height:6),
                                Text('Remarks: ${a['nurse_remarks']}', style: const TextStyle(fontSize:12, color: Colors.black87)),
                              ],
                            ],
                          ),
                        ),
                      ],
                      
                      if(a['nurse_name']!=null)...[ const Divider(), Text('Assigned Healthcare Provider: ${a['nurse_name']}'), if(a['nurse_phone']!=null) Text('Phone: ${a['nurse_phone']}'), if(a['nurse_branch']!=null) Text('Branch: ${a['nurse_branch']}'), if(a['nurse_comments']!=null) Text('Comments: ${a['nurse_comments']}') ],
                      const SizedBox(height:12),
                      
                      // Action buttons - conditional based on status
                      if(status.toLowerCase()=='booked')...[
                        // Show "Set Amount" button for booked appointments
                        Row(children:[
                          Expanded(child: ElevatedButton.icon(
                            icon: const Icon(Icons.attach_money, color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2260FF),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            label: const Text('Set Total Amount', style: TextStyle(color:Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => _setAmountDialog(a),
                          )),
                          const SizedBox(width:8),
                          IconButton(tooltip:'View details', onPressed: () => _viewDetails(a), icon: const Icon(Icons.visibility, color: Color(0xFF2260FF)))
                        ]),
                      ] else if(status.toLowerCase()=='pre_paid' && (a['visit_completion_enabled'] != true))...[
                        // Show "Complete Visit" button for pre-paid appointments not yet completed
                        Row(children:[
                          Expanded(child: ElevatedButton.icon(
                            icon: const Icon(Icons.medical_services, color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            label: const Text('Complete Visit & Enable Final Payment', style: TextStyle(color:Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => _submitPostVisitConsultation(a),
                          )),
                          const SizedBox(width:8),
                          IconButton(tooltip:'View details', onPressed: () => _viewDetails(a), icon: const Icon(Icons.visibility, color: Color(0xFF2260FF)))
                        ]),
                      ] else ...[
                        // Approve/Reject buttons disabled for amount_set status
                        Row(children:[
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject', style: TextStyle(color:Colors.red)),
                              onPressed: (status.toLowerCase()=='completed' || status.toLowerCase()=='rejected' || status.toLowerCase()=='amount_set' || status.toLowerCase()=='pre_paid') ? null : () => _rejectDialog(a),
                            ),
                          ),
                          const SizedBox(width:8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, color: Colors.white),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              label: const Text('Approve', style: TextStyle(color:Colors.white)),
                              onPressed: (status.toLowerCase()=='completed' || status.toLowerCase()=='approved' || status.toLowerCase()=='amount_set' || status.toLowerCase()=='pre_paid') ? null : () => _approveDialog(a),
                            ),
                          ),
                          const SizedBox(width:8),
                          IconButton(tooltip:'View details', onPressed: () => _viewDetails(a), icon: const Icon(Icons.visibility, color: Color(0xFF2260FF)))
                        ]),
                      ]
                    ])));
                    return card;
                  },
                ),
              ),
    );
  }

  List<Map<String, dynamic>> _filtered(){
  if(_statusFilter=='All') return _items;
  // Map display tab to status value in DB
  final statusMap = {
    'Pending': 'pending',
    'Approved': 'approved',
    'Rejected': 'rejected',
    'Completed': 'completed',
    'Booked': 'booked',
    'Amount Set': 'amount_set',
    'Pre Paid': 'pre_paid',
  };
  final want = statusMap[_statusFilter] ?? _statusFilter.toLowerCase();
  return _items.where((e)=>(e['status']??'').toString().toLowerCase()==want).toList();
  }

  Widget _filtersBar(){
  final options=['All','Pending','Approved','Rejected','Completed','Booked','Amount Set','Pre Paid'];
  return Wrap(
    spacing:8,
    runSpacing:8,
    children: options.map((o) => ChoiceChip(
      label: Text(o),
      selected: _statusFilter==o,
      onSelected: (selected) {
        if(selected) setState(() { _statusFilter = o; });
      },
    )).toList(),
  );
  }


  Widget _kv(String k, String v){
    return Padding(padding: const EdgeInsets.only(bottom:6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[ SizedBox(width:140, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(v)) ]));
  }

  // Helper function to safely truncate payment ID
  String _truncatePaymentId(dynamic paymentId) {
    if (paymentId == null) return 'N/A';
    final id = paymentId.toString();
    if (id.length <= 20) return id;
    return '${id.substring(0, 20)}...';
  }
}
