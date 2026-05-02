import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/utils/web_download.dart';

class PatientExportService {
  // ─── Human-readable label for DB field names ───────────────────────────────
  static String _label(String key) {
    const map = {
      // ── Appointment fields ──
      'appointment_id': 'Appointment ID',
      'date': 'Appointment Date',
      'time': 'Appointment Time',
      'status': 'Appointment Status',
      'problem': 'Health Problem / Concern',
      'patient_type': 'Patient Type',
      'address': 'Service Address',
      'emergency_contact': 'Emergency Contact',
      'duration_hours': 'Duration (Hours)',
      'amount_rupees': 'Amount (₹)',
      'patient_email': 'Email (Appointment)',
      'phone': 'Contact Phone',
      'patient_id': 'Healthcare Seeker ID',
      'aadhar_number': 'Aadhaar Number',
      // Provider assignment
      'nurse_name': 'Assigned Provider Name',
      'nurse_phone': 'Assigned Provider Phone',
      'nurse_branch': 'Branch / Office',
      'nurse_comments': 'Provider Comments',
      'nurse_available': 'Provider Available',
      'approved_at': 'Approved At',
      'rejected_at': 'Rejected At',
      'rejection_reason': 'Rejection Reason',
      // Primary doctor
      'primary_doctor_name': 'Primary Doctor Name',
      'primary_doctor_phone': 'Primary Doctor Phone',
      'primary_doctor_location': 'Primary Doctor Location',
      // Payment
      'registration_paid': 'Registration Fee Paid',
      'registration_paid_at': 'Registration Paid At',
      'registration_payment_id': 'Registration Payment ID',
      'registration_receipt_id': 'Registration Receipt ID',
      'total_amount': 'Total Service Amount (₹)',
      'nurse_remarks': 'Provider Remarks',
      'pre_paid': 'Pre-Payment Paid',
      'pre_paid_at': 'Pre-Payment Paid At',
      'pre_payment_id': 'Pre-Payment ID',
      'pre_receipt_id': 'Pre-Payment Receipt ID',
      'final_paid': 'Final Payment Paid',
      'final_paid_at': 'Final Payment Paid At',
      'final_payment_id': 'Final Payment ID',
      'final_receipt_id': 'Final Payment Receipt ID',
      // Post-visit
      'consulted_doctor_name': 'Recommended Doctor Name',
      'consulted_doctor_phone': 'Recommended Doctor Phone',
      'consulted_doctor_specialization': 'Recommended Doctor Specialization',
      'consulted_doctor_clinic_address': 'Recommended Doctor Clinic Address',
      'post_visit_remarks': 'Post-Visit Remarks',
      'visit_completed_at': 'Visit Completed At',
      'visit_completion_enabled': 'Final Payment Enabled',
      'cancellation_reason': 'Cancellation Reason',
      'cancelled_at': 'Cancelled At',
      'appointment_created_at': 'Appointment Submitted On',
      // ── Patient (from patients table) fields ──
      'salutation': 'Salutation',
      'first_name': 'First Name',
      'middle_name': 'Middle Name',
      'last_name': 'Last Name',
      'p_name': 'Full Name',
      'p_age': 'Age',
      'p_gender': 'Gender',
      'aadhar_linked_phone': 'Phone Number',
      'country_code': 'Country Code',
      'alternative_phone': 'Alternative Phone',
      'p_email': 'Email',
      'house_number': 'House Number',
      'town': 'Town',
      'city': 'City',
      'state': 'State',
      'pincode': 'Pincode',
      'phone_verified': 'Phone Verified',
      'otp_verified_at': 'OTP Verified At',
      'patient_created_at': 'Patient Registered On',
    };
    return map[key] ??
        key
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
            .join(' ');
  }

  // ─── Ordered list of fields for export (defines row order) ─────────────────
  // Section A – Personal Info (from patients table)
  static const List<String> _sectionAFields = [
    'patient_id', 'p_name', 'salutation', 'first_name', 'middle_name', 'last_name',
    'p_age', 'p_gender',
  ];
  // Section B – Contact Details
  static const List<String> _sectionBFields = [
    'aadhar_linked_phone', 'country_code', 'alternative_phone',
    'p_email', 'house_number', 'town', 'city', 'state', 'pincode',
  ];
  // Section C – Verification & Identity
  static const List<String> _sectionCFields = [
    'aadhar_number', 'phone_verified', 'otp_verified_at', 'patient_created_at',
  ];
  // Section D – Appointment Details
  static const List<String> _sectionDFields = [
    'appointment_id', 'date', 'time', 'status', 'problem',
    'patient_type', 'address', 'phone', 'patient_email', 'emergency_contact',
    'duration_hours', 'amount_rupees', 'appointment_created_at',
  ];
  // Section E – Provider Assignment
  static const List<String> _sectionEFields = [
    'nurse_name', 'nurse_phone', 'nurse_branch', 'nurse_comments',
    'nurse_available', 'approved_at', 'rejected_at', 'rejection_reason',
    'cancellation_reason', 'cancelled_at',
  ];
  // Section F – Medical & Doctors
  static const List<String> _sectionFFields = [
    'primary_doctor_name', 'primary_doctor_phone', 'primary_doctor_location',
    'consulted_doctor_name', 'consulted_doctor_phone',
    'consulted_doctor_specialization', 'consulted_doctor_clinic_address',
    'post_visit_remarks', 'visit_completed_at', 'visit_completion_enabled',
  ];
  // Section G – Payment
  static const List<String> _sectionGFields = [
    'registration_paid', 'registration_paid_at',
    'registration_payment_id', 'registration_receipt_id',
    'total_amount', 'nurse_remarks',
    'pre_paid', 'pre_paid_at', 'pre_payment_id', 'pre_receipt_id',
    'final_paid', 'final_paid_at', 'final_payment_id', 'final_receipt_id',
  ];

  static List<String> get _allOrderedFields => [
    ..._sectionAFields,
    ..._sectionBFields,
    ..._sectionCFields,
    ..._sectionDFields,
    ..._sectionEFields,
    ..._sectionFFields,
    ..._sectionGFields,
  ];

  // ─── PDF section definitions (map of title → field keys) ───────────────────
  static Map<String, List<String>> get _pdfSections => {
    'A. Personal Information': _sectionAFields,
    'B. Contact Details': _sectionBFields,
    'C. Verification & Identity': _sectionCFields,
    'D. Appointment Details': _sectionDFields,
    'E. Provider Assignment & Status': _sectionEFields,
    'F. Medical & Post-Visit Information': _sectionFFields,
    'G. Payment Details': _sectionGFields,
  };

  // ─── Format a raw value; null/empty → "—" ─────────────────────────────────
  static String _formatValue(dynamic raw) {
    if (raw == null) return '—';
    if (raw is bool) return raw ? 'Yes' : 'No';
    if (raw is List) {
      final items = raw.where((e) => e != null && e.toString().isNotEmpty).toList();
      return items.isEmpty ? '—' : items.join(', ');
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return '—';
    // Format ISO date strings
    if (str.length >= 10 && str[4] == '-' && str[7] == '-') {
      try {
        final dt = DateTime.parse(str).toLocal();
        return '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return str;
  }

  // ─── Build rows list; ALWAYS includes every field (null → "—") ─────────────
  static List<Map<String, String>> _buildRows(Map<String, dynamic> data) {
    return _allOrderedFields
        .map((key) => {'label': _label(key), 'value': _formatValue(data[key])})
        .toList();
  }

  // Build rows for a single section
  static List<Map<String, String>> _buildSectionRows(
      Map<String, dynamic> data, List<String> fields) {
    return fields
        .map((key) => {'label': _label(key), 'value': _formatValue(data[key])})
        .toList();
  }

  static String _safeFilename(Map<String, dynamic> data, String ext) {
    final rawName = (data['p_name'] ?? data['full_name'] ?? 'patient')
        .toString()
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        .toUpperCase();
    // Use full patient UUID (Healthcare Seeker Unique ID) — no truncation
    final patientId = (data['patient_id'] ?? '').toString();
    final idPart = patientId.isNotEmpty ? patientId.toUpperCase() : 'NO_ID';
    return '${rawName}_$idPart.$ext';
  }

  static String _bulkFilename(String ext) {
    final now = DateTime.now();
    final datePart =
        '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';
    return 'care_seeker_bulk_$datePart.$ext';
  }

  // ─── Load logo from assets ─────────────────────────────────────────────────
  static Future<pw.ImageProvider?> _loadLogoImage() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // ─── Fetch full patient data from Supabase and merge with appointment ───────
  /// Merges patient-table fields into the appointment map under prefixed/renamed
  /// keys so they don't overwrite existing appointment fields.
  static Future<Map<String, dynamic>> _fetchAndMerge(
      Map<String, dynamic> appt) async {
    final merged = Map<String, dynamic>.from(appt);
    // Rename appointment-level id & timestamps
    merged['appointment_id'] = appt['id'];
    merged['appointment_created_at'] = appt['created_at'];
    merged['patient_email'] = appt['patient_email'];

    final patientId = appt['patient_id']?.toString();
    if (patientId != null && patientId.isNotEmpty) {
      try {
        final supabase = Supabase.instance.client;
        final result = await supabase
            .from('patients')
            .select(
              'name, first_name, middle_name, last_name, salutation, age, gender, '
              'email, aadhar_linked_phone, country_code, alternative_phone, '
              'house_number, town, city, state, pincode, phone_verified, '
              'otp_verified_at, created_at',
            )
            .eq('id', patientId)
            .maybeSingle();
        if (result != null) {
          // Prefix patient fields to avoid conflict
          merged['p_name'] = result['name'];
          merged['salutation'] = result['salutation'];
          merged['first_name'] = result['first_name'];
          merged['middle_name'] = result['middle_name'];
          merged['last_name'] = result['last_name'];
          merged['p_age'] = result['age'];
          merged['p_gender'] = result['gender'];
          merged['aadhar_linked_phone'] = result['aadhar_linked_phone'];
          merged['country_code'] = result['country_code'];
          merged['alternative_phone'] = result['alternative_phone'];
          merged['p_email'] = result['email'];
          merged['house_number'] = result['house_number'];
          merged['town'] = result['town'];
          merged['city'] = result['city'];
          merged['state'] = result['state'];
          merged['pincode'] = result['pincode'];
          merged['phone_verified'] = result['phone_verified'];
          merged['otp_verified_at'] = result['otp_verified_at'];
          merged['patient_created_at'] = result['created_at'];
        }
      } catch (e) {
        debugPrint('[PatientExport] Could not fetch patient data: $e');
      }
    } else {
      // Fallback for legacy appointments where patient_id was not stored:
      // try to resolve the patient via their email address.
      merged['p_name'] = appt['full_name'];
      merged['p_age'] = appt['age'];
      merged['p_gender'] = appt['gender'];
      merged['p_email'] = appt['patient_email'];
      final fallbackEmail = appt['patient_email']?.toString();
      if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
        try {
          final supabase = Supabase.instance.client;
          final result = await supabase
              .from('patients')
              .select(
                'id, name, first_name, middle_name, last_name, salutation, age, gender, '
                'email, aadhar_linked_phone, country_code, alternative_phone, '
                'house_number, town, city, state, pincode, phone_verified, '
                'otp_verified_at, created_at',
              )
              .eq('email', fallbackEmail)
              .maybeSingle();
          if (result != null) {
            // Resolve patient_id from the patients table (fixes NULL patient_id)
            merged['patient_id'] = result['id'];
            merged['p_name'] = result['name'] ?? appt['full_name'];
            merged['salutation'] = result['salutation'];
            merged['first_name'] = result['first_name'];
            merged['middle_name'] = result['middle_name'];
            merged['last_name'] = result['last_name'];
            merged['p_age'] = result['age'] ?? appt['age'];
            merged['p_gender'] = result['gender'] ?? appt['gender'];
            merged['aadhar_linked_phone'] = result['aadhar_linked_phone'];
            merged['country_code'] = result['country_code'];
            merged['alternative_phone'] = result['alternative_phone'];
            merged['p_email'] = result['email'];
            merged['house_number'] = result['house_number'];
            merged['town'] = result['town'];
            merged['city'] = result['city'];
            merged['state'] = result['state'];
            merged['pincode'] = result['pincode'];
            merged['phone_verified'] = result['phone_verified'];
            merged['otp_verified_at'] = result['otp_verified_at'];
            merged['patient_created_at'] = result['created_at'];
          }
        } catch (e) {
          debugPrint('[PatientExport] Email fallback lookup failed: $e');
        }
      }
    }
    return merged;
  }

  // ─── XML escape helper ─────────────────────────────────────────────────────
  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // ─── Share / Save file ─────────────────────────────────────────────────────
  static Future<void> _shareFile(
    BuildContext context,
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    try {
      if (kIsWeb) {
        triggerWebDownload(bytes, filename, mimeType);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (!context.mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          text: 'Healthcare Seeker Export',
        ),
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not share file: $e');
    }
  }

  static void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ─── PDF: Patient summary banner (teal themed) ─────────────────────────────
  static pw.Widget _buildPdfPatientBanner(Map<String, dynamic> data) {
    final name = (data['p_name'] ?? data['full_name'] ?? '').toString();
    final apptId = (data['appointment_id'] ?? data['id'] ?? '').toString();
    final status = (data['status'] ?? '').toString().toUpperCase();

    PdfColor statusBg;
    if (status == 'APPROVED' || status == 'COMPLETED') {
      statusBg = PdfColor.fromHex('#1B8A3E');
    } else if (status == 'REJECTED' || status == 'CANCELLED') {
      statusBg = PdfColor.fromHex('#C62828');
    } else if (status == 'PRE_PAID' || status == 'AMOUNT_SET' || status == 'BOOKED') {
      statusBg = PdfColor.fromHex('#1565C0');
    } else {
      statusBg = PdfColor.fromHex('#E65100');
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0F766E'),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name.isEmpty ? 'Healthcare Seeker' : name,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Healthcare Seeker Profile & Appointment Report',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                ),
                if (apptId.isNotEmpty) ...[
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Appointment ID: $apptId',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                  ),
                ],
              ],
            ),
          ),
          if (status.isNotEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: statusBg,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                status,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── PDF: Section header (teal left border) ─────────────────────────────────
  static pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 3),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F0FDF4'),
        border: pw.Border(
          left: pw.BorderSide(color: PdfColor.fromHex('#0F766E'), width: 4),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#0F766E'),
        ),
      ),
    );
  }

  // ─── PDF: Two-column field/value table ─────────────────────────────────────
  static pw.Widget _buildPdfSectionTable(List<Map<String, String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#D1FAE5'),
        width: 0.5,
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
      },
      children: List.generate(rows.length, (i) {
        return pw.TableRow(
          children: [
            pw.Container(
              color: PdfColor.fromHex('#F0FDF4'),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: pw.Text(
                rows[i]['label']!,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#44546A'),
                ),
              ),
            ),
            pw.Container(
              color: i.isEven ? PdfColors.white : PdfColor.fromHex('#FAFFFE'),
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: pw.Text(
                rows[i]['value']!,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: PdfColor.fromHex('#1A1A1A'),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ─── PDF: Page header ───────────────────────────────────────────────────────
  static pw.Widget _buildPdfPageHeader(pw.Context ctx, pw.ImageProvider? logo) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logo != null) ...[
                  pw.Image(logo, width: 26, height: 26, fit: pw.BoxFit.contain),
                  pw.SizedBox(width: 8),
                ],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SR CAREHIVE',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#0F766E'),
                      ),
                    ),
                    pw.Text(
                      'Healthcare Seeker Report',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromHex('#888888'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(dateStr,
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColor.fromHex('#555555'))),
                pw.Text('CONFIDENTIAL',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#C62828'))),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 1.5, color: PdfColor.fromHex('#0F766E')),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ─── PDF: Page footer ───────────────────────────────────────────────────────
  static pw.Widget _buildPdfPageFooter(pw.Context ctx, pw.ImageProvider? logo) {
    final teal = PdfColor.fromHex('#0F766E');
    final grey = PdfColor.fromHex('#666666');
    final lightGrey = PdfColor.fromHex('#999999');

    // Inline badge widget (no local function to avoid static-method capture issues)
    pw.Widget badge(String letter) => pw.Container(
          width: 13,
          height: 13,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
              color: teal, borderRadius: pw.BorderRadius.circular(2)),
          child: pw.Text(letter,
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold)),
        );

    final brandBlock = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) ...[
          pw.Image(logo, width: 26, height: 26, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 8),
        ],
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('SR CAREHIVE',
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: teal)),
            pw.Text('Trusted Healthcare Staffing',
                style: pw.TextStyle(fontSize: 7, color: lightGrey)),
          ],
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 2, color: teal),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            brandBlock,
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: teal, width: 0.8),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: teal),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: PdfColor.fromHex('#A7F3D0')),
        pw.SizedBox(height: 5),
        // Single row — all 4 contact items fit within A4 content width (~515pt)
        pw.Row(
          children: [
            badge('E'),
            pw.SizedBox(width: 5),
            pw.Text('contact@srcarehive.com',
                style: pw.TextStyle(fontSize: 7.5, color: grey)),
            pw.SizedBox(width: 10),
            badge('L'),
            pw.SizedBox(width: 5),
            pw.Text('Jollygrant, Dehradun',
                style: pw.TextStyle(fontSize: 7.5, color: grey)),
            pw.SizedBox(width: 10),
            badge('P'),
            pw.SizedBox(width: 5),
            pw.Text('+91 91490 68966',
                style: pw.TextStyle(fontSize: 7.5, color: grey)),
            pw.SizedBox(width: 10),
            badge('W'),
            pw.SizedBox(width: 5),
            pw.Text('www.srcarehive.com  |  www.srcarehive.org',
                style: pw.TextStyle(fontSize: 7.5, color: grey)),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text('Confidential - For Internal Use Only',
            style: pw.TextStyle(fontSize: 7, color: lightGrey)),
      ],
    );
  }


  // ─── PDF: Full document body content ────────────────────────────────────────
  static List<pw.Widget> _buildPdfContent(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];
    widgets.add(_buildPdfPatientBanner(data));
    widgets.add(pw.SizedBox(height: 18));

    for (final entry in _pdfSections.entries) {
      // Only include fields that have actual data (skip null/empty → avoid
      // rendering '—' em-dash which Helvetica font cannot encode)
      final sectionRows = <Map<String, String>>[];
      for (final key in entry.value) {
        final raw = data[key];
        if (raw == null) continue;
        final value = _formatValue(raw);
        if (value.isEmpty || value == '—') continue; // skip blanks
        sectionRows.add({'label': _label(key), 'value': value});
      }
      if (sectionRows.isEmpty) continue; // skip whole section if nothing to show

      widgets.add(_buildPdfSectionHeader(entry.key));
      widgets.add(_buildPdfSectionTable(sectionRows));
      widgets.add(pw.SizedBox(height: 14));
    }
    return widgets;
  }

  // ─── PDF Export (single) ────────────────────────────────────────────────────
  static Future<void> exportAsPdf(
      BuildContext context, Map<String, dynamic> data) async {
    try {
      final logo = await _loadLogoImage();
      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        header: (ctx) => _buildPdfPageHeader(ctx, logo),
        footer: (ctx) => _buildPdfPageFooter(ctx, logo),
        build: (_) => _buildPdfContent(data),
      ));
      final bytes = await doc.save();
      if (!context.mounted) return;
      await _shareFile(context, bytes, _safeFilename(data, 'pdf'), 'application/pdf');
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export PDF: $e');
    }
  }

  // ─── PDF Export (bulk) ──────────────────────────────────────────────────────
  static Future<void> exportBulkAsPdf(
      BuildContext context, List<Map<String, dynamic>> dataList) async {
    try {
      final logo = await _loadLogoImage();
      final doc = pw.Document();
      for (final data in dataList) {
        doc.addPage(pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          header: (ctx) => _buildPdfPageHeader(ctx, logo),
          footer: (ctx) => _buildPdfPageFooter(ctx, logo),
          build: (_) => _buildPdfContent(data),
        ));
      }
      final bytes = await doc.save();
      final fname = dataList.length == 1
          ? _safeFilename(dataList.first, 'pdf')
          : _bulkFilename('pdf');
      if (!context.mounted) return;
      await _shareFile(context, bytes, fname, 'application/pdf');
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export bulk PDF: $e');
    }
  }

  // ─── Word (.docx) document builder ─────────────────────────────────────────
  static Future<Uint8List> _buildDocxDocument(
      List<Map<String, dynamic>> dataList) async {
    Uint8List? logoBytes;
    try {
      final d = await rootBundle.load('assets/images/logo.png');
      logoBytes = d.buffer.asUint8List();
    } catch (_) {}

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    String esc(String s) => _xmlEscape(s);
    const logoEmu = 288000;
    final hasLogo = logoBytes != null;

    String logoDrawing(String rId) =>
        '<w:r><w:rPr><w:noProof/></w:rPr>'
        '<w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0"'
        ' xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<wp:extent cx="$logoEmu" cy="$logoEmu"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="1" name="Logo"/>'
        '<wp:cNvGraphicFramePr>'
        '<a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>'
        '</wp:cNvGraphicFramePr>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr>'
        '<pic:cNvPr id="1" name="logo.png"/>'
        '<pic:cNvPicPr><a:picLocks noChangeAspect="1" noChangeArrowheads="1"/></pic:cNvPicPr>'
        '</pic:nvPicPr>'
        '<pic:blipFill>'
        '<a:blip r:embed="$rId" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>'
        '<a:stretch><a:fillRect/></a:stretch>'
        '</pic:blipFill>'
        '<pic:spPr bwMode="auto">'
        '<a:xfrm><a:off x="0" y="0"/><a:ext cx="$logoEmu" cy="$logoEmu"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom>'
        '</pic:spPr>'
        '</pic:pic>'
        '</a:graphicData>'
        '</a:graphic>'
        '</wp:inline>'
        '</w:drawing>'
        '</w:r>';

    // Patient banner in teal
    void patientBanner(StringBuffer b, Map<String, dynamic> d) {
      final nm = esc((d['p_name'] ?? d['full_name'] ?? 'Healthcare Seeker').toString());
      final apptId = esc((d['appointment_id'] ?? d['id'] ?? '').toString());
      final st = (d['status'] ?? '').toString().toUpperCase();
      final stC = (st == 'APPROVED' || st == 'COMPLETED')
          ? '1B8A3E'
          : (st == 'REJECTED' || st == 'CANCELLED')
              ? 'C62828'
              : (st == 'PRE_PAID' || st == 'AMOUNT_SET' || st == 'BOOKED')
                  ? '1565C0'
                  : 'E65100';

      b.write('<w:p><w:pPr>'
          '<w:shd w:val="clear" w:color="auto" w:fill="0F766E"/>'
          '<w:tabs><w:tab w:val="right" w:pos="9071"/></w:tabs>'
          '<w:spacing w:before="120" w:after="0"/>'
          '<w:ind w:left="120" w:right="120"/>'
          '</w:pPr>'
          '<w:r><w:rPr><w:b/><w:sz w:val="34"/><w:color w:val="FFFFFF"/></w:rPr>'
          '<w:t xml:space="preserve">$nm</w:t></w:r>');
      if (st.isNotEmpty) {
        b.write('<w:r><w:rPr><w:sz w:val="20"/><w:color w:val="FFFFFF"/></w:rPr><w:tab/></w:r>'
            '<w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="$stC"/></w:rPr>'
            '<w:t>[$st]</w:t></w:r>');
      }
      b.write('</w:p>\n');
      b.write('<w:p><w:pPr>'
          '<w:shd w:val="clear" w:color="auto" w:fill="0F766E"/>'
          '<w:spacing w:before="0" w:after="0"/>'
          '<w:ind w:left="120" w:right="120"/>'
          '</w:pPr>'
          '<w:r><w:rPr><w:sz w:val="20"/><w:color w:val="FFFFFF"/></w:rPr>'
          '<w:t>Healthcare Seeker Profile &amp; Appointment Report</w:t></w:r></w:p>\n');
      if (apptId.isNotEmpty) {
        b.write('<w:p><w:pPr>'
            '<w:shd w:val="clear" w:color="auto" w:fill="0F766E"/>'
            '<w:spacing w:before="0" w:after="180"/>'
            '<w:ind w:left="120" w:right="120"/>'
            '</w:pPr>'
            '<w:r><w:rPr><w:sz w:val="16"/><w:color w:val="FFFFFF"/></w:rPr>'
            '<w:t>Appointment ID: $apptId</w:t></w:r></w:p>\n');
      }
    }

    void sectionHeader(StringBuffer b, String title) {
      b.write('<w:p><w:pPr>'
          '<w:shd w:val="clear" w:color="auto" w:fill="F0FDF4"/>'
          '<w:pBdr><w:left w:val="single" w:sz="24" w:space="4" w:color="0F766E"/></w:pBdr>'
          '<w:spacing w:before="180" w:after="0"/>'
          '<w:ind w:left="120" w:right="120"/>'
          '</w:pPr>'
          '<w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="0F766E"/></w:rPr>'
          '<w:t>${esc(title)}</w:t></w:r></w:p>\n');
    }

    void fieldTable(StringBuffer b, List<Map<String, String>> rows) {
      b.write('<w:tbl><w:tblPr>'
          '<w:tblW w:w="9360" w:type="dxa"/>'
          '<w:tblBorders>');
      for (final s in ['top','left','bottom','right','insideH','insideV']) {
        b.write('<w:$s w:val="single" w:sz="4" w:space="0" w:color="D1FAE5"/>');
      }
      b.write('</w:tblBorders>'
          '<w:tblCellMar>'
          '<w:top w:w="80" w:type="dxa"/><w:left w:w="120" w:type="dxa"/>'
          '<w:bottom w:w="80" w:type="dxa"/><w:right w:w="120" w:type="dxa"/>'
          '</w:tblCellMar>'
          '</w:tblPr>'
          '<w:tblGrid><w:gridCol w:w="3240"/><w:gridCol w:w="6120"/></w:tblGrid>');
      for (int i = 0; i < rows.length; i++) {
        final valFill = i.isEven ? 'FFFFFF' : 'FAFFFE';
        b.write('<w:tr>'
            '<w:tc><w:tcPr><w:tcW w:w="3240" w:type="dxa"/>'
            '<w:shd w:val="clear" w:color="auto" w:fill="F0FDF4"/></w:tcPr>'
            '<w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr>'
            '<w:r><w:rPr><w:b/><w:sz w:val="18"/><w:color w:val="44546A"/></w:rPr>'
            '<w:t>${esc(rows[i]['label']!)}</w:t></w:r></w:p></w:tc>');
        b.write('<w:tc><w:tcPr><w:tcW w:w="6120" w:type="dxa"/>'
            '<w:shd w:val="clear" w:color="auto" w:fill="$valFill"/></w:tcPr>'
            '<w:p><w:pPr><w:spacing w:before="60" w:after="60"/></w:pPr>');
        final valLines = rows[i]['value']!.split('\n');
        for (int li = 0; li < valLines.length; li++) {
          if (li > 0) b.write('<w:r><w:rPr><w:sz w:val="19"/></w:rPr><w:br/></w:r>');
          b.write('<w:r><w:rPr><w:sz w:val="19"/><w:color w:val="1A1A1A"/></w:rPr>'
              '<w:t xml:space="preserve">${esc(valLines[li])}</w:t></w:r>');
        }
        b.write('</w:p></w:tc></w:tr>');
      }
      b.write('</w:tbl>'
          '<w:p><w:pPr><w:spacing w:before="0" w:after="80"/></w:pPr></w:p>\n');
    }

    final doc = StringBuffer();
    doc.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    doc.write('<w:document'
        ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n');
    doc.write('<w:body>\n');
    for (int idx = 0; idx < dataList.length; idx++) {
      if (idx > 0) doc.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>\n');
      final data = dataList[idx];
      patientBanner(doc, data);
      for (final entry in _pdfSections.entries) {
        final rows = _buildSectionRows(data, entry.value);
        sectionHeader(doc, entry.key);
        fieldTable(doc, rows);
      }
    }
    doc.write('<w:sectPr>'
        '<w:headerReference w:type="default" r:id="rId2"/>'
        '<w:footerReference w:type="default" r:id="rId3"/>'
        '<w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="1080" w:right="1080" w:bottom="1440" w:left="1080"'
        ' w:header="720" w:footer="720"/>'
        '</w:sectPr>\n');
    doc.write('</w:body>\n</w:document>');

    final headerXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:p><w:pPr>'
        '<w:pBdr><w:bottom w:val="single" w:sz="12" w:space="1" w:color="0F766E"/></w:pBdr>'
        '<w:tabs><w:tab w:val="right" w:pos="9071"/></w:tabs>'
        '<w:spacing w:before="0" w:after="80"/>'
        '</w:pPr>'
        '${hasLogo ? logoDrawing('rId4') : ''}'
        '<w:r><w:rPr><w:sz w:val="8"/></w:rPr><w:t xml:space="preserve"> </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:t xml:space="preserve">SR CAREHIVE  </w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/><w:color w:val="888888"/></w:rPr>'
        '<w:t>Healthcare Seeker Report</w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:tab/></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/><w:color w:val="555555"/></w:rPr>'
        '<w:t xml:space="preserve">${esc(dateStr)}  </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="C62828"/></w:rPr>'
        '<w:t>CONFIDENTIAL</w:t></w:r>'
        '</w:p></w:hdr>';

    final footerXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:p><w:pPr>'
        '<w:pBdr><w:top w:val="single" w:sz="12" w:space="1" w:color="0F766E"/></w:pBdr>'
        '<w:tabs><w:tab w:val="right" w:pos="9071"/></w:tabs>'
        '<w:spacing w:before="80" w:after="60"/>'
        '</w:pPr>'
        '${hasLogo ? logoDrawing('rId5') : ''}'
        '<w:r><w:rPr><w:sz w:val="8"/></w:rPr><w:t xml:space="preserve"> </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:t xml:space="preserve">SR CAREHIVE  </w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="14"/><w:color w:val="999999"/></w:rPr>'
        '<w:t>Trusted Healthcare Staffing</w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:tab/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:t xml:space="preserve">Page </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:t>1</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:t xml:space="preserve"> of </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> NUMPAGES </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="0F766E"/></w:rPr>'
        '<w:t>1</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
        '</w:p>'
        '<w:p><w:pPr><w:spacing w:before="0" w:after="40"/></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="14"/><w:color w:val="555555"/></w:rPr>'
        '<w:t>contact@srcarehive.com  |  Jollygrant, Dehradun  |  +91 91490 68966  |  www.srcarehive.com  |  www.srcarehive.org</w:t></w:r>'
        '</w:p>'
        '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="13"/><w:color w:val="AAAAAA"/></w:rPr>'
        '<w:t>Confidential - For Internal Use Only</w:t></w:r>'
        '</w:p></w:ftr>';

    final contentTypesXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '${hasLogo ? '<Default Extension="png" ContentType="image/png"/>' : ''}'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
        '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
        '</Types>';

    const rootRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"'
        ' Target="word/document.xml"/>'
        '</Relationships>';

    const docRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId2"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header"'
        ' Target="header1.xml"/>'
        '<Relationship Id="rId3"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer"'
        ' Target="footer1.xml"/>'
        '</Relationships>';

    const headerRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId4"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"'
        ' Target="media/logo.png"/>'
        '</Relationships>';

    const footerRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId5"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"'
        ' Target="media/logo.png"/>'
        '</Relationships>';

    final archive = Archive();
    void addUtf8(String name, String content) {
      final encoded = utf8.encode(content);
      archive.addFile(ArchiveFile(name, encoded.length, encoded));
    }
    void addBytes(String name, Uint8List bytes) {
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    addUtf8('[Content_Types].xml', contentTypesXml);
    addUtf8('_rels/.rels', rootRels);
    addUtf8('word/document.xml', doc.toString());
    addUtf8('word/header1.xml', headerXml);
    addUtf8('word/footer1.xml', footerXml);
    addUtf8('word/_rels/document.xml.rels', docRels);
    if (hasLogo) {
      addBytes('word/media/logo.png', logoBytes);
      addUtf8('word/_rels/header1.xml.rels', headerRels);
      addUtf8('word/_rels/footer1.xml.rels', footerRels);
    }
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // ─── Word Export (single) ───────────────────────────────────────────────────
  static Future<void> exportAsDocx(
      BuildContext context, Map<String, dynamic> data) async {
    try {
      final bytes = await _buildDocxDocument([data]);
      if (!context.mounted) return;
      await _shareFile(
        context, bytes, _safeFilename(data, 'docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export Word: $e');
    }
  }

  // ─── Word Export (bulk) ─────────────────────────────────────────────────────
  static Future<void> exportBulkAsDocx(
      BuildContext context, List<Map<String, dynamic>> dataList) async {
    try {
      final bytes = await _buildDocxDocument(dataList);
      final fname = dataList.length == 1
          ? _safeFilename(dataList.first, 'docx')
          : _bulkFilename('docx');
      if (!context.mounted) return;
      await _shareFile(
        context, bytes, fname,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export bulk Word: $e');
    }
  }

  // ─── Excel: single record (Field | Value layout) ────────────────────────────
  static Excel _buildSingleExcelObject(Map<String, dynamic> data) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final rows = _buildRows(data);
    final excel = Excel.createExcel();
    const sheetName = 'Patient Report';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final blueHeaderStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Left,
    );
    final subHeaderStyle = CellStyle(
      fontSize: 9,
      fontColorHex: ExcelColor.fromHexString('#666666'),
      horizontalAlign: HorizontalAlign.Left,
    );
    final fieldLabelStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#F0FDF4'),
      fontColorHex: ExcelColor.fromHexString('#0F766E'),
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
    );
    final fieldValueStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      textWrapping: TextWrapping.WrapText,
    );
    final colHeaderStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#D1FAE5'),
      fontColorHex: ExcelColor.fromHexString('#1A1A1A'),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Left,
    );

    // Row 0: SR CAREHIVE | Healthcare Seeker Report
    final brandCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    brandCell.value = TextCellValue('SR CAREHIVE');
    brandCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
    );
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    titleCell.value = TextCellValue('Healthcare Seeker Report');
    titleCell.cellStyle = blueHeaderStyle;

    // Row 1: Generated date
    final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    dateCell.value = TextCellValue('Generated: $dateStr');
    dateCell.cellStyle = subHeaderStyle;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1),
    );

    // Row 3: column headers
    final fieldCol = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
    fieldCol.value = TextCellValue('Field');
    fieldCol.cellStyle = colHeaderStyle;
    final valCol = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3));
    valCol.value = TextCellValue('Value');
    valCol.cellStyle = colHeaderStyle;

    sheet.setColumnWidth(0, 38);
    sheet.setColumnWidth(1, 60);

    for (int i = 0; i < rows.length; i++) {
      final rowIdx = i + 4;
      final lCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx));
      lCell.value = TextCellValue(rows[i]['label']!);
      lCell.cellStyle = fieldLabelStyle;
      final vCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx));
      vCell.value = TextCellValue(rows[i]['value']!);
      vCell.cellStyle = fieldValueStyle;
    }
    return excel;
  }

  // ─── Excel: bulk (one patient per row) ──────────────────────────────────────
  static Excel _buildBulkExcelObject(List<Map<String, dynamic>> dataList) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final excel = Excel.createExcel();
    const sheetName = 'Patient Reports';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Left,
    );
    final dataStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      textWrapping: TextWrapping.WrapText,
    );
    final brandTitleStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 11, horizontalAlign: HorizontalAlign.Left,
    );
    final bluePadStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#0F766E'));
    final dateRowStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#666666'),
      horizontalAlign: HorizontalAlign.Left,
    );

    // Row 0 brand header
    final r0b = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    r0b.value = TextCellValue('SR CAREHIVE');
    r0b.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0F766E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 14, horizontalAlign: HorizontalAlign.Left,
    );
    final r0t = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    r0t.value = TextCellValue('Healthcare Seeker Reports');
    r0t.cellStyle = brandTitleStyle;
    for (int c = 2; c < _allOrderedFields.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .cellStyle = bluePadStyle;
    }

    // Row 1: generated date
    final r1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    r1.value = TextCellValue('Generated: $dateStr');
    r1.cellStyle = dateRowStyle;

    // Row 3: column headers
    for (int col = 0; col < _allOrderedFields.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3));
      cell.value = TextCellValue(_label(_allOrderedFields[col]));
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(col, 25);
    }

    // Row 4+: One row per patient
    for (int rowIdx = 0; rowIdx < dataList.length; rowIdx++) {
      final data = dataList[rowIdx];
      for (int col = 0; col < _allOrderedFields.length; col++) {
        final key = _allOrderedFields[col];
        final value = _formatValue(data[key]);
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx + 4));
        cell.value = TextCellValue(value);
        cell.cellStyle = dataStyle;
      }
    }
    return excel;
  }

  // ─── Excel Export (single) ──────────────────────────────────────────────────
  static Future<void> exportAsExcel(
      BuildContext context, Map<String, dynamic> data) async {
    try {
      final excel = _buildSingleExcelObject(data);
      final bytes = Uint8List.fromList(excel.encode()!);
      if (!context.mounted) return;
      await _shareFile(context, bytes, _safeFilename(data, 'xlsx'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export Excel: $e');
    }
  }

  // ─── Excel Export (bulk) ────────────────────────────────────────────────────
  static Future<void> exportBulkAsExcel(
      BuildContext context, List<Map<String, dynamic>> dataList) async {
    try {
      final excel = _buildBulkExcelObject(dataList);
      final bytes = Uint8List.fromList(excel.encode()!);
      final fname = dataList.length == 1
          ? _safeFilename(dataList.first, 'xlsx')
          : _bulkFilename('xlsx');
      if (!context.mounted) return;
      await _shareFile(context, bytes, fname,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export bulk Excel: $e');
    }
  }

  // ─── Public: Show export dialog for a single appointment ───────────────────
  /// Fetches full patient data first (Option B), then shows format picker.
  static void showExportDialog(
      BuildContext context, Map<String, dynamic> apptData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PatientExportBottomSheet(
        title: 'Export Patient Record',
        onPdf: () async {
          Navigator.pop(ctx);
          final merged = await _fetchAndMerge(apptData);
          if (!context.mounted) return;
          await exportAsPdf(context, merged);
        },
        onDocx: () async {
          Navigator.pop(ctx);
          final merged = await _fetchAndMerge(apptData);
          if (!context.mounted) return;
          await exportAsDocx(context, merged);
        },
        onExcel: () async {
          Navigator.pop(ctx);
          final merged = await _fetchAndMerge(apptData);
          if (!context.mounted) return;
          await exportAsExcel(context, merged);
        },
      ),
    );
  }

  // ─── Public: Show bulk export dialog ───────────────────────────────────────
  /// Fetches full patient data for all items, then shows format picker.
  static void showBulkExportDialog(
      BuildContext context, List<Map<String, dynamic>> apptList) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PatientExportBottomSheet(
        title: 'Export ${apptList.length} Record${apptList.length == 1 ? '' : 's'}',
        onPdf: () async {
          Navigator.pop(ctx);
          if (!context.mounted) return;
          final merged = await Future.wait(apptList.map(_fetchAndMerge));
          if (!context.mounted) return;
          await exportBulkAsPdf(context, merged);
        },
        onDocx: () async {
          Navigator.pop(ctx);
          if (!context.mounted) return;
          final merged = await Future.wait(apptList.map(_fetchAndMerge));
          if (!context.mounted) return;
          await exportBulkAsDocx(context, merged);
        },
        onExcel: () async {
          Navigator.pop(ctx);
          if (!context.mounted) return;
          final merged = await Future.wait(apptList.map(_fetchAndMerge));
          if (!context.mounted) return;
          await exportBulkAsExcel(context, merged);
        },
      ),
    );
  }
} // end PatientExportService

// ─── Bottom Sheet UI ─────────────────────────────────────────────────────────
class _PatientExportBottomSheet extends StatelessWidget {
  final String title;
  final VoidCallback onPdf;
  final VoidCallback onDocx;
  final VoidCallback onExcel;

  const _PatientExportBottomSheet({
    this.title = 'Export Patient Record',
    required this.onPdf,
    required this.onDocx,
    required this.onExcel,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a format to download',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            _PatientExportOptionTile(
              icon: FontAwesomeIcons.filePdf,
              iconColor: const Color(0xFFE53935),
              label: 'Export as PDF',
              subtitle: 'Best for viewing & printing',
              onTap: onPdf,
            ),
            const SizedBox(height: 10),
            _PatientExportOptionTile(
              icon: FontAwesomeIcons.fileWord,
              iconColor: const Color(0xFF1565C0),
              label: 'Export as Word (.docx)',
              subtitle: 'Opens in Microsoft Word & Google Docs',
              onTap: onDocx,
            ),
            const SizedBox(height: 10),
            _PatientExportOptionTile(
              icon: FontAwesomeIcons.fileExcel,
              iconColor: const Color(0xFF2E7D32),
              label: 'Export as Excel (.xlsx)',
              subtitle: 'Spreadsheet with all fields',
              onTap: onExcel,
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _PatientExportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              FaIcon(FontAwesomeIcons.chevronRight,
                  color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
