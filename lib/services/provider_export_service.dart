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
import 'package:care12/utils/web_download.dart';

class ProviderExportService {
  // â”€â”€â”€ Human-readable label for DB field names â”€â”€â”€
  static String _label(String key) {
    const map = {
      'id': 'Unique Provider ID',
      'full_name': 'Full Name',
      'mobile_number': 'Mobile Number',
      'alternative_mobile': 'Alternative Mobile',
      'email': 'Email',
      'city': 'City',
      'professional_role': 'Professional Role',
      'doctor_specialty': 'Doctor Specialty',
      'highest_qualification': 'Highest Qualification',
      'completion_year': 'Completion Year',
      'registration_number': 'Registration Number',
      'current_work_role': 'Current Work Role',
      'workplace': 'Workplace',
      'years_of_experience': 'Years of Experience',
      'services_offered': 'Services Offered',
      'availability_days': 'Availability Days',
      'time_slots': 'Time Slots',
      'community_experience': 'Community Experience',
      'languages': 'Languages',
      'service_areas': 'Service Areas',
      'home_visit_fee': 'Home Visit Fee',
      'teleconsultation_fee': 'Teleconsultation Fee',
      'agreed_to_declaration': 'Declaration of Authentic Information',
      'agreed_to_data_privacy': 'Data Privacy & Health Data Compliance',
      'agreed_to_professional_responsibility': 'Professional Responsibility Acknowledgment',
      'agreed_to_terms': 'Terms & Conditions',
      'agreed_to_communication': 'Communication Consent',
      'application_status': 'Application Status',
      'rejection_reason': 'Rejection Reason',
      'approved_at': 'Approved On',
      'created_at': 'Submitted On',
      'updated_at': 'Last Updated',
      'email_verified': 'Email Verified',
      'mobile_verified': 'Mobile Verified',
      'documents_verified': 'Documents Verified',
      'admin_notes': 'Admin Notes',
      'approval_comments': 'Approval Comments',
      'documents_requested': 'Documents Requested',
      'documents_requested_at': 'Documents Requested At',
      'documents_request_comments': 'Document Request Comments',
      'final_approval_comments': 'Final Approval Comments',
    };
    return map[key] ??
        key
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
            .join(' ');
  }

  // â”€â”€â”€ Ordered list of DB fields to export â”€â”€â”€
  static const List<String> _orderedFields = [
    'id',
    'full_name',
    'mobile_number',
    'alternative_mobile',
    'email',
    'city',
    'professional_role',
    'doctor_specialty',
    'highest_qualification',
    'completion_year',
    'registration_number',
    'current_work_role',
    'workplace',
    'years_of_experience',
    'services_offered',
    'availability_days',
    'time_slots',
    'community_experience',
    'languages',
    'service_areas',
    'home_visit_fee',
    'teleconsultation_fee',
    'agreed_to_declaration',
    'agreed_to_data_privacy',
    'agreed_to_professional_responsibility',
    'agreed_to_terms',
    'agreed_to_communication',
    'application_status',
    'rejection_reason',
    'approved_at',
    'created_at',
    'updated_at',
    'email_verified',
    'mobile_verified',
    'documents_verified',
    'admin_notes',
    'approval_comments',
    'documents_requested',
    'documents_requested_at',
    'documents_request_comments',
    'final_approval_comments',
  ];

  // â”€â”€â”€ Build a list of {label, value} only for non-empty fields â”€â”€â”€
  static List<Map<String, String>> _buildRows(Map<String, dynamic> data) {
    final rows = <Map<String, String>>[];
    for (final key in _orderedFields) {
      if (!data.containsKey(key)) continue;
      final raw = data[key];
      if (raw == null) continue;
      final value = _formatValue(raw);
      if (value.isEmpty) continue;
      rows.add({'label': _label(key), 'value': value});
    }
    return rows;
  }

  static String _formatValue(dynamic raw) {
    if (raw == null) return '';
    if (raw is bool) return raw ? 'Yes' : 'No';
    if (raw is List) {
      final items = raw.where((e) => e != null && e.toString().isNotEmpty).toList();
      return items.isEmpty ? '' : items.join(', ');
    }
    final str = raw.toString().trim();
    // Format ISO date strings nicely
    if (str.length >= 10 && str[4] == '-' && str[7] == '-') {
      try {
        final dt = DateTime.parse(str).toLocal();
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return str;
  }

  static String _safeFilename(Map<String, dynamic> data, String ext) {
    final name =
        (data['full_name'] ?? 'provider').toString().trim().replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final idStr = (data['id'] ?? '').toString();
    return '${name}_$idStr.$ext';
  }

  // â”€â”€â”€ PDF section definitions â”€â”€â”€
  static const Map<String, List<String>> _pdfSections = {
    'A. Personal Information': [
      'id', 'full_name', 'mobile_number', 'alternative_mobile', 'email', 'city',
    ],
    'B. Professional Details': [
      'professional_role', 'doctor_specialty', 'highest_qualification', 'completion_year',
      'registration_number', 'current_work_role', 'workplace', 'years_of_experience',
    ],
    'C. Services & Availability': [
      'services_offered', 'availability_days', 'time_slots', 'community_experience',
      'languages', 'service_areas', 'home_visit_fee', 'teleconsultation_fee',
    ],
    'D. Declarations & Consent': [
      'agreed_to_declaration', 'agreed_to_data_privacy',
      'agreed_to_professional_responsibility', 'agreed_to_terms', 'agreed_to_communication',
    ],
    'E. Application Status & Admin': [
      'application_status', 'rejection_reason', 'documents_requested',
      'documents_requested_at', 'documents_request_comments', 'admin_notes',
      'approval_comments', 'final_approval_comments', 'approved_at', 'created_at',
      'updated_at', 'email_verified', 'mobile_verified', 'documents_verified',
    ],
  };

  // â”€â”€â”€ Provider summary banner â”€â”€â”€
  static pw.Widget _buildPdfProviderBanner(Map<String, dynamic> data) {
    final name = data['full_name']?.toString() ?? '';
    final role = data['professional_role']?.toString() ?? '';
    final id = data['id']?.toString() ?? '';
    final status = (data['application_status'] ?? '').toString().toLowerCase();

    PdfColor statusBg;
    String statusLabel;
    if (status == 'approved') {
      statusBg = PdfColor.fromHex('#1B8A3E');
      statusLabel = 'APPROVED';
    } else if (status == 'rejected') {
      statusBg = PdfColor.fromHex('#C62828');
      statusLabel = 'REJECTED';
    } else {
      statusBg = PdfColor.fromHex('#E65100');
      statusLabel = 'PENDING';
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#2260FF'),
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
                  name.isEmpty ? 'Healthcare Provider' : name,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (role.isNotEmpty) ...[pw.SizedBox(height: 3),
                  pw.Text(role,
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 10)),
                ],
                if (id.isNotEmpty) ...[pw.SizedBox(height: 6),
                  pw.Text('Provider ID: $id',
                      style: pw.TextStyle(
                          color: PdfColors.white, fontSize: 8)),
                ],
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: statusBg,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              statusLabel,
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

  // â”€â”€â”€ Section header widget â”€â”€â”€
  static pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 3),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EEF2FF'),
        border: pw.Border(
          left: pw.BorderSide(color: PdfColor.fromHex('#2260FF'), width: 4),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#2260FF'),
        ),
      ),
    );
  }

  // â”€â”€â”€ Section fields two-column table â”€â”€â”€
  static pw.Widget _buildPdfSectionTable(List<Map<String, String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#D8DEF0'),
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
              color: PdfColor.fromHex('#F4F6FB'),
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
              color: i.isEven ? PdfColors.white : PdfColor.fromHex('#FAFBFE'),
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

  // â”€â”€â”€ Full page body content (sectioned) â”€â”€â”€
  static List<pw.Widget> _buildPdfContent(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];
    widgets.add(_buildPdfProviderBanner(data));
    widgets.add(pw.SizedBox(height: 18));

    for (final entry in _pdfSections.entries) {
      final sectionRows = <Map<String, String>>[];
      for (final key in entry.value) {
        if (!data.containsKey(key)) continue;
        final raw = data[key];
        if (raw == null) continue;
        final value = _formatValue(raw);
        if (value.isEmpty) continue;
        sectionRows.add({'label': _label(key), 'value': value});
      }
      if (sectionRows.isEmpty) continue;
      widgets.add(_buildPdfSectionHeader(entry.key));
      widgets.add(_buildPdfSectionTable(sectionRows));
      widgets.add(pw.SizedBox(height: 14));
    }
    return widgets;
  }

  // â”€â”€â”€ Repeating page header â”€â”€â”€
  static pw.Widget _buildPdfPageHeader(pw.Context context, pw.ImageProvider? logo) {
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
                if (logo != null) ...[pw.Image(logo, width: 26, height: 26, fit: pw.BoxFit.contain), pw.SizedBox(width: 8)],
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SR CAREHIVE',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#2260FF'),
                      ),
                    ),
                    pw.Text(
                      'Healthcare Provider Application Report',
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
                pw.Text(
                  dateStr,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromHex('#555555'),
                  ),
                ),
                pw.Text(
                  'CONFIDENTIAL',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#C62828'),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Container(height: 1.5, color: PdfColor.fromHex('#2260FF')),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // â”€â”€â”€ Load logo from Flutter assets â”€â”€â”€
  static Future<pw.ImageProvider?> _loadLogoImage() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  // â”€â”€â”€ Repeating page footer â”€â”€â”€
  static pw.Widget _buildPdfPageFooter(pw.Context context, pw.ImageProvider? logo) {
    final blue = PdfColor.fromHex('#2260FF');
    final grey = PdfColor.fromHex('#666666');
    final lightGrey = PdfColor.fromHex('#999999');

    // Envelope icon drawn with CustomPaint (white lines on blue bg)
    pw.Widget envelopeIcon = pw.Container(
      width: 13,
      height: 13,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: blue,
        borderRadius: pw.BorderRadius.circular(2),
      ),
      child: pw.CustomPaint(
        size: const PdfPoint(9, 6),
        painter: (canvas, size) {
          canvas
            ..setLineWidth(0.7)
            ..setStrokeColor(PdfColors.white)
            // outer rectangle
            ..moveTo(0, 0)
            ..lineTo(9, 0)
            ..lineTo(9, 6)
            ..lineTo(0, 6)
            ..closePath()
            ..strokePath()
            // top flap V (Y-up coordinate system)
            ..moveTo(0, 6)
            ..lineTo(4.5, 2)
            ..lineTo(9, 6)
            ..strokePath();
        },
      ),
    );

    // Generic letter badge for other contact items
    pw.Widget _badge(String letter) => pw.Container(
          width: 13,
          height: 13,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            color: blue,
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: pw.Text(
            letter,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

    // Row: icon + label
    pw.Widget _contactItem(pw.Widget icon, String text) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            icon,
            pw.SizedBox(width: 4),
            pw.Text(text, style: pw.TextStyle(fontSize: 7.5, color: grey)),
          ],
        );

    // Brand block: logo image (if loaded) + text
    final brandBlock = pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) ...[pw.Image(logo, width: 28, height: 28, fit: pw.BoxFit.contain), pw.SizedBox(width: 8)],
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'SR CAREHIVE',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: blue,
              ),
            ),
            pw.Text(
              'Trusted Healthcare Staffing',
              style: pw.TextStyle(fontSize: 7, color: lightGrey),
            ),
          ],
        ),
      ],
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // thick blue top border
        pw.Container(height: 2, color: blue),
        pw.SizedBox(height: 6),
        // Brand + page number row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            brandBlock,
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: blue, width: 0.8),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: blue,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(height: 0.5, color: PdfColor.fromHex('#D0D9FF')),
        pw.SizedBox(height: 5),
        // Contact row
        pw.Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _contactItem(envelopeIcon, 'contact@srcarehive.com'),
            _contactItem(_badge('L'), 'Jollygrant, Dehradun'),
            _contactItem(_badge('P'), '+91 91490 68966'),
            _contactItem(_badge('W'), 'www.srcarehive.com  |  www.srcarehive.org'),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Confidential - For Internal Use Only',
          style: pw.TextStyle(fontSize: 7, color: lightGrey),
        ),
      ],
    );
  }

  // â”€â”€â”€ PDF Export (single) â”€â”€â”€
  static Future<void> exportAsPdf(BuildContext context, Map<String, dynamic> data) async {
    try {
      final logo = await _loadLogoImage();
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
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
        ),
      );
      final bytes = await doc.save();
      if (!context.mounted) return;
      await _shareFile(context, bytes, _safeFilename(data, 'pdf'), 'application/pdf');
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export PDF: $e');
    }
  }

  // â”€â”€â”€ Word (.docx) Export (single) â”€â”€â”€
  static Future<void> exportAsDocx(BuildContext context, Map<String, dynamic> data) async {
    try {
      final bytes = await _buildDocxDocument([data]);
      if (!context.mounted) return;
      await _shareFile(
        context,
        bytes,
        _safeFilename(data, 'docx'),
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export Word document: $e');
    }
  }

  // â”€â”€â”€ Excel Export (single) â”€â”€â”€
  static Future<void> exportAsExcel(BuildContext context, Map<String, dynamic> data) async {
    try {
      final rows = _buildRows(data);
      final fname = _safeFilename(data, 'xlsx');
      if (kIsWeb) {
        // On Flutter Web the excel package auto-triggers a browser download when
        // excel.save() is called.  We pass the correct filename so only ONE
        // download fires (with the right name).  Do NOT also call _shareFile /
        // triggerWebDownload – that would cause a second duplicate download.
        final excelObj = _buildSingleExcelObject(rows);
        excelObj.save(fileName: fname);
      } else {
        // Non-web: get raw bytes and share via the platform share sheet.
        final bytes = Uint8List.fromList(_buildSingleExcelObject(rows).save()!);
        if (!context.mounted) return;
        await _shareFile(
          context,
          bytes,
          fname,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export Excel: $e');
    }
  }

  // â”€â”€â”€ Bulk PDF â”€â”€â”€
  static Future<void> exportBulkAsPdf(
      BuildContext context, List<Map<String, dynamic>> dataList) async {
    try {
      final logo = await _loadLogoImage();
      final doc = pw.Document();
      for (final data in dataList) {
        doc.addPage(
          pw.MultiPage(
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
          ),
        );
      }
      final bytes = await doc.save();
      final ts = DateTime.now();
      final fname = dataList.length == 1
          ? _safeFilename(dataList.first, 'pdf')
          : 'providers_bulk_${ts.day}${ts.month}${ts.year}.pdf';
      if (!context.mounted) return;
      await _shareFile(context, bytes, fname, 'application/pdf');
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export bulk PDF: $e');
    }
  }

  // â”€â”€â”€ Bulk Word (.docx) â”€â”€â”€
  static Future<void> exportBulkAsDocx(
      BuildContext context, List<Map<String, dynamic>> dataList) async {
    try {
      final bytes = await _buildDocxDocument(dataList);
      final ts = DateTime.now();
      final fname = dataList.length == 1
          ? _safeFilename(dataList.first, 'docx')
          : 'providers_bulk_${ts.day}${ts.month}${ts.year}.docx';
      if (!context.mounted) return;
      await _shareFile(
        context,
        bytes,
        fname,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export Word document: $e');
    }
  }

  // â”€â”€â”€ Bulk Excel â”€â”€â”€
  static Future<void> exportBulkAsExcel(
      BuildContext context, List<Map<String, dynamic>> dataList) async {
    try {
      final ts = DateTime.now();
      final fname = dataList.length == 1
          ? _safeFilename(dataList.first, 'xlsx')
          : 'providers_bulk_${ts.day}${ts.month}${ts.year}.xlsx';
      if (kIsWeb) {
        // On Flutter Web the excel package auto-triggers a browser download when
        // excel.save() is called.  We pass the correct filename so only ONE
        // download fires (with the right name).  Do NOT also call _shareFile /
        // triggerWebDownload – that would cause a second duplicate download.
        final excelObj = dataList.length == 1
            ? _buildSingleExcelObject(_buildRows(dataList.first))
            : _buildBulkExcelObject(dataList);
        excelObj.save(fileName: fname);
      } else {
        // Non-web: get raw bytes and share via the platform share sheet.
        final bytes = dataList.length == 1
            ? Uint8List.fromList(_buildSingleExcelObject(_buildRows(dataList.first)).save()!)
            : Uint8List.fromList(_buildBulkExcelObject(dataList).save()!);
        if (!context.mounted) return;
        await _shareFile(
          context,
          bytes,
          fname,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
    } catch (e) {
      if (context.mounted) _showError(context, 'Failed to export Excel: $e');
    }
  }

  // â”€â”€â”€ Word (.docx / OOXML) document builder
  static Future<Uint8List> _buildDocxDocument(List<Map<String, dynamic>> dataList) async {
    // Load logo bytes (null if unavailable)
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/logo.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    String esc(String s) => _xmlEscape(s);

    // EMU dimensions for logo in header/footer: 400x400 EMU = ~0.44cm
    // 1 cm = 914400/2.54 â‰ˆ 360000 EMU; logo at ~0.8cm = 288000 EMU
    const logoEmu = 288000; // ~0.8 cm

    // OOXML inline drawing block (used in both header and footer, different rIds)
    String logoDrawing(String rId) =>
        '<w:r>'
        '<w:rPr><w:noProof/></w:rPr>'
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

    final hasLogo = logoBytes != null;

    // â”€â”€ Provider banner (blue block: name + [STATUS] | role | provider ID) â”€â”€
    void providerBanner(StringBuffer b, Map<String, dynamic> d) {
      final nm  = esc(d['full_name']?.toString() ?? 'Healthcare Provider');
      final rl  = esc(d['professional_role']?.toString() ?? '');
      final id  = esc(d['id']?.toString() ?? '');
      final st  = (d['application_status'] ?? '').toString().toUpperCase();
      final stC = st == 'APPROVED' ? '1B8A3E' : st == 'REJECTED' ? 'C62828' : 'E65100';

      // Name + status
      b.write('<w:p><w:pPr>'
          '<w:shd w:val="clear" w:color="auto" w:fill="2260FF"/>'
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

      if (rl.isNotEmpty) {
        b.write('<w:p><w:pPr>'
            '<w:shd w:val="clear" w:color="auto" w:fill="2260FF"/>'
            '<w:spacing w:before="0" w:after="0"/>'
            '<w:ind w:left="120" w:right="120"/>'
            '</w:pPr>'
            '<w:r><w:rPr><w:sz w:val="20"/><w:color w:val="FFFFFF"/></w:rPr>'
            '<w:t>$rl</w:t></w:r></w:p>\n');
      }
      if (id.isNotEmpty) {
        b.write('<w:p><w:pPr>'
            '<w:shd w:val="clear" w:color="auto" w:fill="2260FF"/>'
            '<w:spacing w:before="0" w:after="180"/>'
            '<w:ind w:left="120" w:right="120"/>'
            '</w:pPr>'
            '<w:r><w:rPr><w:sz w:val="16"/><w:color w:val="FFFFFF"/></w:rPr>'
            '<w:t>Provider ID: $id</w:t></w:r></w:p>\n');
      }
    }

    // â”€â”€ Section heading with blue left border â”€â”€
    void sectionHeader(StringBuffer b, String title) {
      b.write('<w:p><w:pPr>'
          '<w:shd w:val="clear" w:color="auto" w:fill="EEF2FF"/>'
          '<w:pBdr><w:left w:val="single" w:sz="24" w:space="4" w:color="2260FF"/></w:pBdr>'
          '<w:spacing w:before="180" w:after="0"/>'
          '<w:ind w:left="120" w:right="120"/>'
          '</w:pPr>'
          '<w:r><w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="2260FF"/></w:rPr>'
          '<w:t>${esc(title)}</w:t></w:r></w:p>\n');
    }

    // â”€â”€ Two-column field/value table matching PDF style â”€â”€
    void fieldTable(StringBuffer b, List<Map<String, String>> rows) {
      b.write('<w:tbl><w:tblPr>'
          '<w:tblW w:w="9360" w:type="dxa"/>'
          '<w:tblBorders>');
      for (final s in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']) {
        b.write('<w:$s w:val="single" w:sz="4" w:space="0" w:color="D8DEF0"/>');
      }
      b.write('</w:tblBorders>'
          '<w:tblCellMar>'
          '<w:top w:w="80" w:type="dxa"/><w:left w:w="120" w:type="dxa"/>'
          '<w:bottom w:w="80" w:type="dxa"/><w:right w:w="120" w:type="dxa"/>'
          '</w:tblCellMar>'
          '</w:tblPr>'
          '<w:tblGrid><w:gridCol w:w="3240"/><w:gridCol w:w="6120"/></w:tblGrid>');

      for (int i = 0; i < rows.length; i++) {
        final valFill = i.isEven ? 'FFFFFF' : 'FAFBFE';
        b.write('<w:tr>'
            '<w:tc><w:tcPr><w:tcW w:w="3240" w:type="dxa"/>'
            '<w:shd w:val="clear" w:color="auto" w:fill="F4F6FB"/></w:tcPr>'
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

    // â”€â”€ Build document body â”€â”€
    final doc = StringBuffer();
    doc.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    doc.write('<w:document'
        ' xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n');
    doc.write('<w:body>\n');

    for (int idx = 0; idx < dataList.length; idx++) {
      if (idx > 0) doc.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>\n');
      final data = dataList[idx];
      providerBanner(doc, data);
      for (final entry in _pdfSections.entries) {
        final sRows = <Map<String, String>>[];
        for (final key in entry.value) {
          if (!data.containsKey(key)) continue;
          final raw = data[key];
          if (raw == null) continue;
          final value = _formatValue(raw);
          if (value.isEmpty) continue;
          sRows.add({'label': _label(key), 'value': value});
        }
        if (sRows.isEmpty) continue;
        sectionHeader(doc, entry.key);
        fieldTable(doc, sRows);
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

    // â”€â”€ Repeating header XML â”€â”€
    // rId4 = logo image relationship (header)
    final headerXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<w:p><w:pPr>'
        '<w:pBdr><w:bottom w:val="single" w:sz="12" w:space="1" w:color="2260FF"/></w:pBdr>'
        '<w:tabs><w:tab w:val="right" w:pos="9071"/></w:tabs>'
        '<w:spacing w:before="0" w:after="80"/>'
        '</w:pPr>'
        // Logo (if available) then SR CAREHIVE text
        '${hasLogo ? logoDrawing('rId4') : ''}'
        '<w:r><w:rPr><w:sz w:val="8"/></w:rPr><w:t xml:space="preserve"> </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="26"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:t xml:space="preserve">SR CAREHIVE  </w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/><w:color w:val="888888"/></w:rPr>'
        '<w:t>Healthcare Provider Application Report</w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:tab/></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/><w:color w:val="555555"/></w:rPr>'
        '<w:t xml:space="preserve">${esc(dateStr)}  </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="C62828"/></w:rPr>'
        '<w:t>CONFIDENTIAL</w:t></w:r>'
        '</w:p></w:hdr>';

    // â”€â”€ Repeating footer XML â”€â”€
    // rId5 = logo image relationship (footer)
    final footerXml =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
        ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        // SR CAREHIVE + tagline + Page X of Y
        '<w:p><w:pPr>'
        '<w:pBdr><w:top w:val="single" w:sz="12" w:space="1" w:color="2260FF"/></w:pBdr>'
        '<w:tabs><w:tab w:val="right" w:pos="9071"/></w:tabs>'
        '<w:spacing w:before="80" w:after="60"/>'
        '</w:pPr>'
        // Logo
        '${hasLogo ? logoDrawing('rId5') : ''}'
        '<w:r><w:rPr><w:sz w:val="8"/></w:rPr><w:t xml:space="preserve"> </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:t xml:space="preserve">SR CAREHIVE  </w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="14"/><w:color w:val="999999"/></w:rPr>'
        '<w:t>Trusted Healthcare Staffing</w:t></w:r>'
        '<w:r><w:rPr><w:sz w:val="16"/></w:rPr><w:tab/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:t xml:space="preserve">Page </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:t>1</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:t xml:space="preserve"> of </w:t></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r><w:instrText xml:space="preserve"> NUMPAGES </w:instrText></w:r>'
        '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r><w:rPr><w:b/><w:sz w:val="16"/><w:color w:val="2260FF"/></w:rPr>'
        '<w:t>1</w:t></w:r>'
        '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
        '</w:p>'
        // Contact line
        '<w:p><w:pPr><w:spacing w:before="0" w:after="40"/></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="14"/><w:color w:val="555555"/></w:rPr>'
        '<w:t>contact@srcarehive.com  |  Jollygrant, Dehradun  |  +91 91490 68966  |  www.srcarehive.com  |  www.srcarehive.org</w:t></w:r>'
        '</w:p>'
        // Confidential
        '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>'
        '<w:r><w:rPr><w:sz w:val="13"/><w:color w:val="AAAAAA"/></w:rPr>'
        '<w:t>Confidential - For Internal Use Only</w:t></w:r>'
        '</w:p></w:ftr>';

    // â”€â”€ OOXML package â”€â”€
    // Content_Types: include png Default if logo is present
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

    const oldRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"'
        ' Target="word/document.xml"/>'
        '</Relationships>';

    // document.xml.rels: header, footer refs
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

    // header1.xml.rels: rId4 = logo image
    const headerRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId4"'
        ' Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image"'
        ' Target="media/logo.png"/>'
        '</Relationships>';

    // footer1.xml.rels: rId5 = logo image
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
    addUtf8('_rels/.rels', oldRels);
    addUtf8('word/document.xml', doc.toString());
    addUtf8('word/header1.xml', headerXml);
    addUtf8('word/footer1.xml', footerXml);
    addUtf8('word/_rels/document.xml.rels', docRels);
    if (hasLogo) {
      addBytes('word/media/logo.png', logoBytes!);
      addUtf8('word/_rels/header1.xml.rels', headerRels);
      addUtf8('word/_rels/footer1.xml.rels', footerRels);
    }

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  // â”€â”€â”€ Single Excel builder (vertical: field / value columns) â”€â”€â”€
  // Returns the Excel object so callers can decide how to save/download.
  static Excel _buildSingleExcelObject(List<Map<String, String>> rows) {
    final excel = Excel.createExcel();
    const sheetName = 'Provider Application';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final blueHeaderStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2260FF'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 13,
      horizontalAlign: HorizontalAlign.Left,
    );
    final subHeaderStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#666666'),
      horizontalAlign: HorizontalAlign.Left,
    );
    final fieldLabelStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E8EDFF'),
      fontColorHex: ExcelColor.fromHexString('#2260FF'),
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
      backgroundColorHex: ExcelColor.fromHexString('#D0D9FF'),
      fontColorHex: ExcelColor.fromHexString('#1A1A1A'),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Left,
    );

    // Row 0: SR CAREHIVE | Healthcare Provider Application
    final brandCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    brandCell.value = TextCellValue('SR CAREHIVE');
    brandCell.cellStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2260FF'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
    );
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    titleCell.value = TextCellValue('Healthcare Provider Application');
    titleCell.cellStyle = blueHeaderStyle;

    // Row 1: Date
    final dateCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    dateCell.value = TextCellValue('Generated: $dateStr');
    dateCell.cellStyle = subHeaderStyle;
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 1),
    );

    // Row 3: column headers
    final fieldColHeader = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3));
    fieldColHeader.value = TextCellValue('Field');
    fieldColHeader.cellStyle = colHeaderStyle;

    final valueColHeader = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3));
    valueColHeader.value = TextCellValue('Value');
    valueColHeader.cellStyle = colHeaderStyle;

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

  // â”€â”€â”€ Bulk Excel builder (each provider = one row of columns) â”€â”€â”€
  // Returns the Excel object so callers can decide how to save/download.
  static Excel _buildBulkExcelObject(List<Map<String, dynamic>> dataList) {
    final excel = Excel.createExcel();
    const sheetName = 'Provider Applications';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2260FF'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Left,
    );
    final dataStyle = CellStyle(
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Left,
      textWrapping: TextWrapping.WrapText,
    );

    final bulkNow = DateTime.now();
    final bulkDate =
        '${bulkNow.day.toString().padLeft(2, '0')}/${bulkNow.month.toString().padLeft(2, '0')}/${bulkNow.year}';
    final brandBgStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2260FF'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Left,
    );
    final brandTitleStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2260FF'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Left,
    );
    final bluePadStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#2260FF'),
    );
    final bulkDateStyle = CellStyle(
      fontSize: 10,
      fontColorHex: ExcelColor.fromHexString('#666666'),
      horizontalAlign: HorizontalAlign.Left,
    );

    // Row 0: SR CAREHIVE | Healthcare Provider Applications | (rest blue)
    final r0b = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    r0b.value = TextCellValue('SR CAREHIVE');
    r0b.cellStyle = brandBgStyle;
    final r0t = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    r0t.value = TextCellValue('Healthcare Provider Applications');
    r0t.cellStyle = brandTitleStyle;
    for (int c = 2; c < _orderedFields.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = bluePadStyle;
    }

    // Row 1: generated date
    final r1 = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1));
    r1.value = TextCellValue('Generated: $bulkDate');
    r1.cellStyle = bulkDateStyle;

    // Row 2: spacer

    // Row 3: Column headers
    for (int col = 0; col < _orderedFields.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3));
      cell.value = TextCellValue(_label(_orderedFields[col]));
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(col, 25);
    }

    // Row 4+: One row per provider
    for (int rowIdx = 0; rowIdx < dataList.length; rowIdx++) {
      final data = dataList[rowIdx];
      for (int col = 0; col < _orderedFields.length; col++) {
        final key = _orderedFields[col];
        final raw = data[key];
        if (raw == null) continue;
        final value = _formatValue(raw);
        if (value.isEmpty) continue;
        final cell =
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx + 4));
        cell.value = TextCellValue(value);
        cell.cellStyle = dataStyle;
      }
    }

    return excel;
  }

  // â”€â”€â”€ Share / Save file â”€â”€â”€
  static Future<void> _shareFile(
    BuildContext context,
    Uint8List bytes,
    String filename,
    String mimeType,
  ) async {
    try {
      if (kIsWeb) {
        // On Flutter Web, path_provider and share_plus are unavailable.
        // Trigger a direct browser download instead.
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
          text: 'Healthcare Provider Application Export',
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

  // â”€â”€â”€ Show export dialog (single provider) â”€â”€â”€
  static void showExportDialog(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExportBottomSheet(
        onPdf: () {
          Navigator.pop(ctx);
          exportAsPdf(context, data);
        },
        onDocx: () {
          Navigator.pop(ctx);
          exportAsDocx(context, data);
        },
        onExcel: () {
          Navigator.pop(ctx);
          exportAsExcel(context, data);
        },
      ),
    );
  }

  // â”€â”€â”€ Show bulk export dialog â”€â”€â”€
  static void showBulkExportDialog(
      BuildContext context, List<Map<String, dynamic>> dataList) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExportBottomSheet(
        title: 'Export ${dataList.length} Application${dataList.length == 1 ? '' : 's'}',
        onPdf: () {
          Navigator.pop(ctx);
          exportBulkAsPdf(context, dataList);
        },
        onDocx: () {
          Navigator.pop(ctx);
          exportBulkAsDocx(context, dataList);
        },
        onExcel: () {
          Navigator.pop(ctx);
          exportBulkAsExcel(context, dataList);
        },
      ),
    );
  }
}

// â”€â”€â”€ Bottom Sheet UI â”€â”€â”€
class _ExportBottomSheet extends StatelessWidget {
  final String title;
  final VoidCallback onPdf;
  final VoidCallback onDocx;
  final VoidCallback onExcel;

  const _ExportBottomSheet({
    this.title = 'Export Application',
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a format to download',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            _ExportOptionTile(
              icon: FontAwesomeIcons.filePdf,
              iconColor: const Color(0xFFE53935),
              label: 'Export as PDF',
              subtitle: 'Best for viewing & printing',
              onTap: onPdf,
            ),
            const SizedBox(height: 10),
            _ExportOptionTile(
              icon: FontAwesomeIcons.fileWord,
              iconColor: const Color(0xFF1565C0),
              label: 'Export as Word (.docx)',
              subtitle: 'Opens in Microsoft Word & Google Docs',
              onTap: onDocx,
            ),
            const SizedBox(height: 10),
            _ExportOptionTile(
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

class _ExportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportOptionTile({
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
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              FaIcon(FontAwesomeIcons.chevronRight, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
