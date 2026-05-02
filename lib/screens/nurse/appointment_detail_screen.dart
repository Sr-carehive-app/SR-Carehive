import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/services/patient_export_service.dart';

/// A read-only detail page for a single appointment + patient record.
/// All action logic (approve, reject, set amount, etc.) remains on the
/// parent list screen. This page only displays information.
class AppointmentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailScreen({Key? key, required this.appointment})
      : super(key: key);

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  /// Resolved Healthcare Seeker ID — filled from appointment.patient_id
  /// or via email fallback for legacy appointments where patient_id is NULL.
  String? _resolvedPatientId;

  @override
  void initState() {
    super.initState();
    final pid = widget.appointment['patient_id']?.toString();
    if (pid != null && pid.isNotEmpty) {
      _resolvedPatientId = pid;
    } else {
      // Legacy appointment: patient_id was not stored — look up by email
      _lookupPatientByEmail();
    }
  }

  Future<void> _lookupPatientByEmail() async {
    final email = widget.appointment['patient_email']?.toString();
    if (email == null || email.isEmpty) return;
    try {
      final result = await Supabase.instance.client
          .from('patients')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (result != null && result['id'] != null && mounted) {
        setState(() => _resolvedPatientId = result['id'].toString());
      }
    } catch (_) {}
  }

  /// Fetches provider feedback for the given appointment from Supabase.
  /// Returns null when no feedback has been submitted yet.
  Future<Map<String, dynamic>?> _fetchProviderFeedback(String? appointmentId) async {
    if (appointmentId == null || appointmentId.isEmpty) return null;
    try {
      final result = await Supabase.instance.client
          .from('provider_feedback')
          .select('*')
          .eq('appointment_id', appointmentId)
          .maybeSingle();
      return result;
    } catch (e) {
      print('[ERROR] Failed to fetch provider feedback: $e');
      return null;
    }
  }

  /// Fetches patient service-experience feedback (appointment_feedback table).
  /// Returns null when no feedback has been submitted yet.
  Future<Map<String, dynamic>?> _fetchAppointmentFeedback(String? appointmentId) async {
    if (appointmentId == null || appointmentId.isEmpty) return null;
    try {
      final result = await Supabase.instance.client
          .from('appointment_feedback')
          .select('*')
          .eq('appointment_id', appointmentId)
          .maybeSingle();
      return result;
    } catch (e) {
      print('[ERROR] Failed to fetch appointment feedback: $e');
      return null;
    }
  }


  // ─── helpers ───────────────────────────────────────────────────────────────
  String _fmtVal(dynamic v) =>
      (v == null || (v is String && v.trim().isEmpty)) ? '—' : v.toString();

  String _fmtDate(dynamic raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw.toString());
    if (d == null) return raw.toString();
    return DateFormat('MMM dd, yyyy').format(d);
  }

  String _fmtDateTime(dynamic raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw.toString()).toLocal();
      return DateFormat('MMM dd, yyyy  hh:mm a').format(d);
    } catch (_) {
      return raw.toString();
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':    return const Color(0xFF1B8A3E);
      case 'completed':   return const Color(0xFF0F766E);
      case 'pending':     return const Color(0xFFE65100);
      case 'rejected':    return const Color(0xFFC62828);
      case 'booked':      return const Color(0xFF2260FF);
      case 'amount_set':  return const Color(0xFF7B3FE4);
      case 'pre_paid':    return const Color(0xFF3730A3);
      case 'cancelled':   return const Color(0xFFB91C1C);
      case 'expired':     return const Color(0xFF6B7280);
      default:            return const Color(0xFF6B7280);
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'amount_set': return 'AMOUNT SET';
      case 'pre_paid':   return 'PRE-PAID';
      default:           return status.toUpperCase();
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final status = (a['status'] ?? 'pending').toString();
    final statusColor = _statusColor(status);
    final name = (a['full_name'] ?? 'Appointment Details').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () =>
                  PatientExportService.showExportDialog(context, a),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70, width: 1.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(40, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.file_download_outlined,
                  size: 16, color: Colors.white),
              label: const Text('Export',
                  style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ),
        ],
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Banner ──────────────────────────────────────────────────
            _heroBanner(a, name, status, statusColor),
            const SizedBox(height: 16),

            // ── Appointment Details ──────────────────────────────────────────
            _section(
              icon: Icons.calendar_today_outlined,
              iconColor: const Color(0xFF2260FF),
              title: 'Appointment Details',
              children: [
                _kvRow('Appointment ID', _fmtVal(a['id'])),
                _kvRow('Date', _fmtDate(a['date'])),
                _kvRow('Time', _fmtVal(a['time'])),
                _kvRow('Status', _statusLabel(status),
                    valueColor: statusColor),
                _kvRow('Patient Type', _fmtVal(a['patient_type'])),
                _kvRow('Health Problem / Concern', _fmtVal(a['problem'])),
                _kvRow('Service Address', _fmtVal(a['address'])),
                _kvRow('Emergency Contact', _fmtVal(a['emergency_contact'])),
                if (a['duration_hours'] != null)
                  _kvRow('Duration (Hours)', _fmtVal(a['duration_hours'])),
                if (a['amount_rupees'] != null)
                  _kvRow('Amount (₹)', _fmtVal(a['amount_rupees'])),
                _kvRow('Submitted On', _fmtDateTime(a['created_at'])),
              ],
            ),
            const SizedBox(height: 16),

            // ── Healthcare Seeker Info ────────────────────────────────────────
            _section(
              icon: Icons.person_outline,
              iconColor: const Color(0xFF0F766E),
              title: 'Healthcare Seeker Information',
              children: [
                if (_resolvedPatientId != null && _resolvedPatientId!.isNotEmpty)
                  _kvRow('Healthcare Seeker ID', _resolvedPatientId!),
                _kvRow('Full Name', _fmtVal(a['full_name'])),
                _kvRow('Age', _fmtVal(a['age'])),
                _kvRow('Gender', _fmtVal(a['gender'])),
              ],
            ),
            const SizedBox(height: 16),

            // ── Contact Details ───────────────────────────────────────────────
            _section(
              icon: Icons.contact_phone_outlined,
              iconColor: const Color(0xFF7C3AED),
              title: 'Contact Details',
              children: [
                _kvRow('Email', _fmtVal(a['patient_email'])),
                _kvRow('Phone', _fmtVal(a['phone'])),
                _kvRow('Aadhaar Number', _fmtVal(a['aadhar_number'])),
              ],
            ),
            const SizedBox(height: 16),

            // ── Primary Doctor ────────────────────────────────────────────────
            if (a['primary_doctor_name'] != null ||
                a['primary_doctor_phone'] != null ||
                a['primary_doctor_location'] != null) ...[
              _section(
                icon: Icons.local_hospital_outlined,
                iconColor: const Color(0xFFDB2777),
                title: 'Primary Doctor',
                children: [
                  _kvRow('Doctor Name', _fmtVal(a['primary_doctor_name'])),
                  _kvRow('Doctor Phone', _fmtVal(a['primary_doctor_phone'])),
                  _kvRow('Doctor Location',
                      _fmtVal(a['primary_doctor_location'])),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Assigned Healthcare Provider ──────────────────────────────────
            _section(
              icon: Icons.medical_services_outlined,
              iconColor: const Color(0xFF059669),
              title: 'Assigned Healthcare Provider',
              children: [
                _kvRow('Provider Name', _fmtVal(a['nurse_name'])),
                _kvRow('Provider Phone', _fmtVal(a['nurse_phone'])),
                _kvRow('Branch / Office', _fmtVal(a['nurse_branch'])),
                _kvRow('Comments', _fmtVal(a['nurse_comments'])),
                _kvRow(
                  'Available',
                  a['nurse_available'] == true
                      ? 'Yes'
                      : (a['nurse_available'] == false ? 'No' : '—'),
                ),
                if (a['approved_at'] != null)
                  _kvRow('Approved At', _fmtDateTime(a['approved_at'])),
              ],
            ),
            const SizedBox(height: 16),

            // ── Payment Details ───────────────────────────────────────────────
            _section(
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFFD97706),
              title: 'Payment Details',
              children: [
                // Registration
                _kvRow(
                  'Registration Fee Paid',
                  a['registration_paid'] == true ? '✅ Paid (₹10)' : '—',
                ),
                if (a['registration_paid_at'] != null)
                  _kvRow('Registration Paid At',
                      _fmtDateTime(a['registration_paid_at'])),
                if (a['registration_payment_id'] != null)
                  _kvRow('Registration Payment ID',
                      _fmtVal(a['registration_payment_id'])),
                if (a['registration_receipt_id'] != null)
                  _kvRow('Registration Receipt ID',
                      _fmtVal(a['registration_receipt_id'])),

                _divider(),

                // Total amount
                if (a['total_amount'] != null)
                  _kvRow('Total Service Amount',
                      '₹${_fmtVal(a['total_amount'])}',
                      bold: true),
                if (a['nurse_remarks'] != null)
                  _kvRow('Provider Remarks', _fmtVal(a['nurse_remarks'])),

                _divider(),

                // Pre-payment
                _kvRow(
                  'Pre-Payment Status',
                  a['pre_paid'] == true ? '✅ Paid (50%)' : '—',
                ),
                if (a['pre_paid_at'] != null)
                  _kvRow('Pre-Payment Paid At', _fmtDateTime(a['pre_paid_at'])),
                if (a['pre_payment_id'] != null)
                  _kvRow('Pre-Payment ID', _fmtVal(a['pre_payment_id'])),
                if (a['pre_receipt_id'] != null)
                  _kvRow('Pre-Payment Receipt ID',
                      _fmtVal(a['pre_receipt_id'])),

                _divider(),

                // Final payment
                _kvRow(
                  'Final Payment Status',
                  a['final_paid'] == true ? '✅ Paid (50%)' : '—',
                ),
                if (a['final_paid_at'] != null)
                  _kvRow('Final Payment Paid At',
                      _fmtDateTime(a['final_paid_at'])),
                if (a['final_payment_id'] != null)
                  _kvRow('Final Payment ID', _fmtVal(a['final_payment_id'])),
                if (a['final_receipt_id'] != null)
                  _kvRow('Final Payment Receipt ID',
                      _fmtVal(a['final_receipt_id'])),
              ],
            ),
            const SizedBox(height: 16),

            // ── Post-Visit Summary ────────────────────────────────────────────
            if (a['post_visit_remarks'] != null ||
                a['visit_completed_at'] != null ||
                a['consulted_doctor_name'] != null) ...[
              _section(
                icon: Icons.event_available_outlined,
                iconColor: const Color(0xFF0F766E),
                title: 'Post-Visit Summary',
                children: [
                  if (a['post_visit_remarks'] != null)
                    _kvRow('Provider Remarks',
                        _fmtVal(a['post_visit_remarks'])),
                  if (a['visit_completed_at'] != null)
                    _kvRow('Visit Completed At',
                        _fmtDateTime(a['visit_completed_at'])),
                  _kvRow(
                    'Final Payment Enabled',
                    a['visit_completion_enabled'] == true ? 'Yes' : 'No',
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Recommended Doctor ────────────────────────────────────────────
            if (a['consulted_doctor_name'] != null ||
                a['consulted_doctor_phone'] != null ||
                a['consulted_doctor_specialization'] != null ||
                a['consulted_doctor_clinic_address'] != null) ...[
              _section(
                icon: Icons.health_and_safety_outlined,
                iconColor: const Color(0xFF2563EB),
                title: '🩺 Recommended Doctor',
                children: [
                  _kvRow('Doctor Name', _fmtVal(a['consulted_doctor_name'])),
                  _kvRow('Doctor Phone',
                      _fmtVal(a['consulted_doctor_phone'])),
                  _kvRow('Specialization',
                      _fmtVal(a['consulted_doctor_specialization'])),
                  _kvRow('Clinic Address',
                      _fmtVal(a['consulted_doctor_clinic_address'])),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Rejection Info ────────────────────────────────────────────────
            if (status.toLowerCase() == 'rejected') ...[
              _section(
                icon: Icons.cancel_outlined,
                iconColor: const Color(0xFFC62828),
                title: 'Rejection Details',
                children: [
                  if (a['rejected_at'] != null)
                    _kvRow('Rejected At', _fmtDateTime(a['rejected_at'])),
                  _kvRow('Rejection Reason',
                      _fmtVal(a['rejection_reason'])),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Cancellation Info ─────────────────────────────────────────────
            if (status.toLowerCase() == 'cancelled') ...[
              _section(
                icon: Icons.block_outlined,
                iconColor: const Color(0xFFB91C1C),
                title: 'Cancellation Details',
                children: [
                  _kvRow('Cancellation Reason',
                      _fmtVal(a['cancellation_reason'])),
                  if (a['cancelled_at'] != null)
                    _kvRow('Cancelled At', _fmtDateTime(a['cancelled_at'])),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Patient Service Experience Feedback ───────────────────────────
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchAppointmentFeedback(a['id']?.toString()),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const SizedBox.shrink();
                }
                final fb = snapshot.data!;
                final stars = (int? n) =>
                    (n != null && n > 0)
                        ? List.generate(n, (_) => '⭐').join() + ' ($n/5)'
                        : '—';
                final yesNo = (dynamic v) =>
                    v == true ? '✅ Yes' : v == false ? '❌ No' : '—';
                return Column(
                  children: [
                    _section(
                      icon: Icons.star_rate_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      title: '⭐ Patient Service Experience Feedback',
                      children: [
                        _kvRow('Submitted On',
                            _fmtDateTime(fb['created_at'])),
                        _divider(),
                        _kvRow('Overall Rating',
                            stars((fb['overall_rating'] as num?)?.toInt()),
                            bold: true, valueColor: Colors.amber[700]),
                        _kvRow('Nurse Professionalism',
                            stars((fb['nurse_professionalism_rating'] as num?)?.toInt())),
                        _kvRow('Service Quality',
                            stars((fb['service_quality_rating'] as num?)?.toInt())),
                        _kvRow('Communication',
                            stars((fb['communication_rating'] as num?)?.toInt())),
                        _kvRow('Punctuality',
                            stars((fb['punctuality_rating'] as num?)?.toInt())),
                        _divider(),
                        _kvRow('Would Recommend?',
                            yesNo(fb['would_recommend']),
                            valueColor: fb['would_recommend'] == true
                                ? Colors.green
                                : Colors.red),
                        _kvRow('Satisfied with Service?',
                            yesNo(fb['satisfied_with_service']),
                            valueColor: fb['satisfied_with_service'] == true
                                ? Colors.green
                                : Colors.red),
                        if (fb['positive_feedback'] != null &&
                            (fb['positive_feedback'] as String).isNotEmpty) ...[
                          _divider(),
                          _kvRow('What Patient Liked',
                              _fmtVal(fb['positive_feedback'])),
                        ],
                        if (fb['improvement_suggestions'] != null &&
                            (fb['improvement_suggestions'] as String)
                                .isNotEmpty)
                          _kvRow('Improvement Suggestions',
                              _fmtVal(fb['improvement_suggestions'])),
                        if (fb['additional_comments'] != null &&
                            (fb['additional_comments'] as String).isNotEmpty)
                          _kvRow('Additional Comments',
                              _fmtVal(fb['additional_comments'])),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // ── Healthcare Provider Feedback ──────────────────────────────────
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchProviderFeedback(a['id']?.toString()),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) {
                  return const SizedBox.shrink();
                }
                final fb = snapshot.data!;
                final stars = (int? n) =>
                    (n != null && n > 0)
                        ? List.generate(n, (_) => '⭐').join() + ' ($n/5)'
                        : '—';
                final yesNo = (dynamic v) =>
                    v == true ? '✅ Yes' : v == false ? '❌ No' : '—';
                return Column(
                  children: [
                    _section(
                      icon: Icons.local_hospital_outlined,
                      iconColor: const Color(0xFF2260FF),
                      title: '👩\u200d⚕️ Healthcare Provider Feedback',
                      children: [
                        _kvRow('Submitted On',
                            _fmtDateTime(fb['created_at'])),
                        _divider(),
                        _kvRow('Overall Rating',
                            stars((fb['overall_rating'] as num?)?.toInt()),
                            bold: true, valueColor: Colors.amber[700]),
                        _kvRow('Behavior & Attitude',
                            stars((fb['service_behavior_rating'] as num?)?.toInt())),
                        _kvRow('Technical / Medical Skill',
                            stars((fb['technical_skill_rating'] as num?)?.toInt())),
                        _kvRow('Punctuality',
                            stars((fb['punctuality_rating'] as num?)?.toInt())),
                        _kvRow('Hygiene & Cleanliness',
                            stars((fb['hygiene_cleanliness_rating'] as num?)?.toInt())),
                        _kvRow('Communication',
                            stars((fb['communication_rating'] as num?)?.toInt())),
                        _divider(),
                        _kvRow('Faced Any Problem?',
                            yesNo(fb['faced_any_problem']),
                            valueColor: fb['faced_any_problem'] == true
                                ? Colors.red
                                : Colors.green),
                        if (fb['problem_description'] != null &&
                            (fb['problem_description'] as String).isNotEmpty)
                          _kvRow('Problem Description',
                              _fmtVal(fb['problem_description'])),
                        _kvRow('Would Recommend Provider?',
                            yesNo(fb['would_recommend_provider']),
                            valueColor: fb['would_recommend_provider'] == true
                                ? Colors.green
                                : Colors.red),
                        _kvRow('Provider Was Professional?',
                            yesNo(fb['provider_was_professional']),
                            valueColor:
                                fb['provider_was_professional'] == true
                                    ? Colors.green
                                    : Colors.red),
                        if (fb['additional_feedback'] != null &&
                            (fb['additional_feedback'] as String).isNotEmpty)
                          ...[
                            _divider(),
                            _kvRow('Additional Feedback',
                                _fmtVal(fb['additional_feedback'])),
                          ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );

  }

  // ─── Hero banner ────────────────────────────────────────────────────────────
  Widget _heroBanner(Map<String, dynamic> a, String name, String status,
      Color statusColor) {
    final date = _fmtDate(a['date']);
    final time = _fmtVal(a['time']);
    return Container(
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
            color: const Color(0xFF2260FF).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(date,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(width: 20),
                const Icon(Icons.access_time, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(time,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section card ────────────────────────────────────────────────────────────
  Widget _section({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                left: BorderSide(color: iconColor, width: 4),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Key-value row ───────────────────────────────────────────────────────────
  Widget _kvRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                color: valueColor ?? const Color(0xFF1A1A1A),
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Divider(color: Color(0xFFE2E8F0), height: 1),
      );
}
