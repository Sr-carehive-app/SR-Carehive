import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/services/provider_email_service.dart';
import 'package:care12/utils/safe_navigation.dart';
import 'package:care12/services/provider_export_service.dart';

class HealthcareProviderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> applicationData;

  const HealthcareProviderDetailScreen({
    Key? key,
    required this.applicationData,
  }) : super(key: key);

  @override
  State<HealthcareProviderDetailScreen> createState() => _HealthcareProviderDetailScreenState();
}

class _HealthcareProviderDetailScreenState extends State<HealthcareProviderDetailScreen> {
  final supabase = Supabase.instance.client;
  bool _isProcessing = false;
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  
  // New state variables for two-stage approval
  bool _documentsRequested = false;
  bool _documentsVerificationChecked = false;
  final TextEditingController _documentRequestCommentsController = TextEditingController();
  final TextEditingController _finalApprovalCommentsController = TextEditingController();
  final TextEditingController _revokeReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize from application data
    _documentsRequested = widget.applicationData['documents_requested'] ?? false;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _commentsController.dispose();
    _documentRequestCommentsController.dispose();
    _finalApprovalCommentsController.dispose();
    _revokeReasonController.dispose();
    super.dispose();
  }

  Future<void> _updateApplicationStatus(String status, {String? reason, String? comments}) async {
    setState(() => _isProcessing = true);

    try {
      final updateData = {
        'application_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'approved') {
        updateData['approved_at'] = DateTime.now().toIso8601String();
        if (comments != null && comments.isNotEmpty) {
          updateData['approval_comments'] = comments;
        }
      }

      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason;
      }

      await supabase
          .from('healthcare_providers')
          .update(updateData)
          .eq('id', widget.applicationData['id']);

      // Send email notification (only if email is provided)
      final userEmail = widget.applicationData['email'] ?? '';
      final userName = widget.applicationData['full_name'] ?? 'User';
      final professionalRole = widget.applicationData['professional_role'] ?? 'Healthcare Provider';

      if (userEmail.isNotEmpty) {
        if (status == 'approved') {
          // Send approval email (non-blocking)
          ProviderEmailService.sendApprovalEmail(
            userEmail: userEmail,
            userName: userName,
            professionalRole: professionalRole,
            adminComments: comments,
            primaryPhone: widget.applicationData['mobile_number']?.toString(),
            rejectionReason: widget.applicationData['rejection_reason']?.toString(),
          ).catchError((e) {
            // Silent error - don't expose email details
            return false;
          });
        } else if (status == 'rejected') {
          // Send rejection email (non-blocking)
          ProviderEmailService.sendRejectionEmail(
            userEmail: userEmail,
            userName: userName,
            rejectionReason: reason,
          ).catchError((e) {
            // Silent error - don't expose email details
            return false;
          });
        }
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, true); // Return true to indicate update
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Application ${status == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating provider application: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        // Convert technical errors to user-friendly messages
        String userMessage = 'Failed to update application. Please try again.';
        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('network') || errorStr.contains('connection')) {
          userMessage = 'Network error. Please check your internet connection.';
        } else if (errorStr.contains('timeout')) {
          userMessage = 'Request timed out. Please try again.';
        } else if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
          userMessage = 'Session expired. Please login again.';
        } else if (errorStr.contains('not found') || errorStr.contains('404')) {
          userMessage = 'Application not found or already processed.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showApproveDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Approve Application',
                overflow: TextOverflow.ellipsis,
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
                'Are you sure you want to approve this healthcare provider application? They will be able to login and start providing services.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Admin Comments (Optional):',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2260FF)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _commentsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any comments or welcome message for the provider...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _commentsController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final comments = _commentsController.text.trim();
              Navigator.pop(context);
              _updateApplicationStatus('approved', comments: comments);
              _commentsController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Reject Application',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _reasonController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _updateApplicationStatus('rejected', reason: _reasonController.text.trim());
              _reasonController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Revoke: Show confirmation dialog with optional reason
  void _showRevokeDialog() {
    _revokeReasonController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.block, color: Colors.deepOrange, size: 28),
            const SizedBox(width: 12),
            const Flexible(
              child: Text(
                'Revoke Healthcare Provider Access',
                overflow: TextOverflow.ellipsis,
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
                'This will revoke the healthcare provider\'s access. They will no longer be able to login and will see a rejection notice. This action can be reviewed later.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason (Optional):',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.deepOrange),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _revokeReasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. Resigned, contract ended, policy violation...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _revokeReasonController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = _revokeReasonController.text.trim();
              Navigator.pop(context);
              _revokeProvider(reason.isNotEmpty ? reason : null);
              _revokeReasonController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Revoke Access', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Revoke: Set status back to rejected
  Future<void> _revokeProvider(String? reason) async {
    setState(() => _isProcessing = true);
    try {
      final updateData = <String, dynamic>{
        'application_status': 'rejected',
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason;
      }
      await supabase
          .from('healthcare_providers')
          .update(updateData)
          .eq('id', widget.applicationData['id']);

      // Send revoke email (only if email is provided) — non-blocking
      final userEmail = widget.applicationData['email']?.toString().trim() ?? '';
      final userName = widget.applicationData['full_name'] ?? 'User';
      final professionalRole = widget.applicationData['professional_role'] ?? 'Healthcare Provider';
      if (userEmail.isNotEmpty) {
        ProviderEmailService.sendRevokeEmail(
          userEmail: userEmail,
          userName: userName,
          professionalRole: professionalRole,
          revokeReason: reason,
        ).catchError((e) => false);
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Healthcare provider access revoked successfully'),
            backgroundColor: Colors.deepOrange,
          ),
        );
      }
    } catch (e) {
      print('Error revoking healthcare provider: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to revoke access. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // New method: Show request documents dialog
  void _showRequestDocumentsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mail_outline, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Request Additional Documents',
                overflow: TextOverflow.ellipsis,
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
                'This will send an email with a Google Form link to the provider. Their application status will remain "Pending" until you give final approval.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Admin Comments (Optional):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _documentRequestCommentsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any instructions or notes for the provider...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _documentRequestCommentsController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final comments = _documentRequestCommentsController.text.trim();
              Navigator.pop(context);
              _requestDocuments(comments);
              _documentRequestCommentsController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // New method: Request documents logic
  Future<void> _requestDocuments(String? comments) async {
    setState(() => _isProcessing = true);

    try {
      final updateData = {
        'documents_requested': true,
        'documents_requested_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (comments != null && comments.isNotEmpty) {
        updateData['documents_request_comments'] = comments;
      }

      await supabase
          .from('healthcare_providers')
          .update(updateData)
          .eq('id', widget.applicationData['id']);

      // Send email notification
      final userEmail = widget.applicationData['email'] ?? '';
      final userName = widget.applicationData['full_name'] ?? 'User';
      final professionalRole = widget.applicationData['professional_role'] ?? 'Healthcare Provider';

      if (userEmail.isNotEmpty) {
        ProviderEmailService.sendDocumentRequestEmail(
          userEmail: userEmail,
          userName: userName,
          professionalRole: professionalRole,
          adminComments: comments,
        ).catchError((e) => false);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _documentsRequested = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document request sent successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error requesting documents: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send document request. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // New method: Show final approval dialog
  void _showFinalApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Final Approval',
                overflow: TextOverflow.ellipsis,
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
                'Are you sure you want to approve this healthcare provider? They will be able to login and access the appointments dashboard.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              const Text(
                'Admin Comments (Optional):',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2260FF),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _finalApprovalCommentsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Add any welcome message or comments...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _finalApprovalCommentsController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final comments = _finalApprovalCommentsController.text.trim();
              Navigator.pop(context);
              _finalApprove(comments);
              _finalApprovalCommentsController.clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // New method: Final approval logic
  Future<void> _finalApprove(String? comments) async {
    setState(() => _isProcessing = true);

    try {
      final updateData = {
        'application_status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (comments != null && comments.isNotEmpty) {
        updateData['final_approval_comments'] = comments;
      }

      await supabase
          .from('healthcare_providers')
          .update(updateData)
          .eq('id', widget.applicationData['id']);

      // Send final approval email (existing template)
      final userEmail = widget.applicationData['email'] ?? '';
      final userName = widget.applicationData['full_name'] ?? 'User';
      final professionalRole = widget.applicationData['professional_role'] ?? 'Healthcare Provider';

      if (userEmail.isNotEmpty) {
        ProviderEmailService.sendApprovalEmail(
          userEmail: userEmail,
          userName: userName,
          professionalRole: professionalRole,
          adminComments: comments,
          primaryPhone: widget.applicationData['mobile_number']?.toString(),
          rejectionReason: widget.applicationData['rejection_reason']?.toString(),
        ).catchError((e) => false);
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Provider approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error approving provider: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve provider. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.applicationData['application_status'] ?? 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';
    final isPending = status == 'pending' || status == 'under_review';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => SafeNavigation.pop(context, debugLabel: 'provider_detail_back'),
        ),
        title: const Text(
          'Application Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () => ProviderExportService.showExportDialog(context, widget.applicationData),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70, width: 1.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(40, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.file_download, size: 16, color: Colors.white),
              label: const Text(
                'Export',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unique Provider ID Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2260FF).withOpacity(0.1), Color(0xFF1A4FCC).withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Color(0xFF2260FF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFF2260FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fingerprint, color: Color(0xFF2260FF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unique Provider ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.applicationData['id']?.toString() ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2260FF),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section A: Basic Information
            _buildSectionTitle('Section A: Basic Information'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildDetailRow('Full Name', widget.applicationData['full_name']),
              _buildDetailRow('Mobile Number', widget.applicationData['mobile_number']),
              _buildDetailRow('Alternative Mobile', widget.applicationData['alternative_mobile'] ?? 'Not provided'),
              _buildDetailRow('Email', widget.applicationData['email'] ?? 'Not provided'),
              _buildDetailRow('City', widget.applicationData['city']),
              _buildDetailRow('Professional Role', widget.applicationData['professional_role']),
              if (widget.applicationData['other_profession'] != null)
                _buildDetailRow('Other Profession', widget.applicationData['other_profession']),
              if (widget.applicationData['doctor_specialty'] != null)
                _buildDetailRow('Doctor Specialty', widget.applicationData['doctor_specialty']),
              _buildDetailRow('Highest Qualification', widget.applicationData['highest_qualification']),
              _buildDetailRow('Completion Year', widget.applicationData['completion_year']?.toString() ?? 'N/A'),
              _buildDetailRow('Registration Number', widget.applicationData['registration_number']),
              _buildDetailRow('Current Work Role', widget.applicationData['current_work_role']),
              _buildDetailRow('Workplace', widget.applicationData['workplace']),
              _buildDetailRow('Years of Experience', widget.applicationData['years_of_experience']?.toString() ?? 'N/A'),
            ]),

            const SizedBox(height: 24),

            // Section B: Service Preferences
            _buildSectionTitle('Section B: Service Preferences'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildArrayDetailRow('Services Offered', widget.applicationData['services_offered']),
              _buildArrayDetailRow('Availability Days', widget.applicationData['availability_days']),
              _buildArrayDetailRow('Time Slots', widget.applicationData['time_slots']),
              _buildDetailRow('Community Experience', widget.applicationData['community_experience'] ?? 'Not provided'),
              _buildArrayDetailRow('Languages', widget.applicationData['languages']),
              _buildDetailRow('Service Areas', widget.applicationData['service_areas']),
              _buildDetailRow('Home Visit Fee', widget.applicationData['home_visit_fee']?.toString() ?? 'Not specified'),
              _buildDetailRow('Teleconsultation Fee', widget.applicationData['teleconsultation_fee']?.toString() ?? 'Not specified'),
            ]),

            const SizedBox(height: 24),

            // Section C: Consent & Compliance
            _buildSectionTitle('Section C: Consent & Compliance'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildBooleanRow('Declaration of Authentic Information', widget.applicationData['agreed_to_declaration']),
              _buildBooleanRow('Data Privacy & Health Data Compliance', widget.applicationData['agreed_to_data_privacy']),
              _buildBooleanRow('Professional Responsibility Acknowledgment', widget.applicationData['agreed_to_professional_responsibility']),
              _buildBooleanRow('Terms & Conditions', widget.applicationData['agreed_to_terms']),
              _buildBooleanRow('Communication Consent', widget.applicationData['agreed_to_communication']),
            ]),

            const SizedBox(height: 24),

            // Application Status
            _buildSectionTitle('Application Status'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildDetailRow('Current Status', _getStatusLabel(status)),
              _buildDetailRow('Submitted On', _formatDate(widget.applicationData['created_at'])),
              if (widget.applicationData['approved_at'] != null)
                _buildDetailRow('Approved On', _formatDate(widget.applicationData['approved_at'])),
              if (widget.applicationData['rejection_reason'] != null)
                _buildDetailRow('Rejection Reason', widget.applicationData['rejection_reason']),
            ]),

            // Admin Comments Section (if approved with comments)
            if (widget.applicationData['approval_comments'] != null && 
                widget.applicationData['approval_comments'].toString().trim().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2260FF).withOpacity(0.1),
                          const Color(0xFF2260FF).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2260FF).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2260FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.comment,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Flexible(
                              child: Text(
                                'Admin Comments',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2260FF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.applicationData['approval_comments'].toString(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Display Document Request Comments (if exists)
            if (widget.applicationData['documents_request_comments'] != null &&
                widget.applicationData['documents_request_comments'].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Document Request Comments',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.applicationData['documents_request_comments'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                    if (widget.applicationData['documents_requested_at'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Sent: ${_formatDate(widget.applicationData['documents_requested_at'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Display Final Approval Comments (if exists)
            if (widget.applicationData['final_approval_comments'] != null &&
                widget.applicationData['final_approval_comments'].toString().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
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
                        Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Final Approval Comments',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.applicationData['final_approval_comments'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons - Two-stage approval process
            if (!_isProcessing)
              Column(
                children: [
                  // BUTTON 1: Request Additional Documents
                  // Visible if: NOT approved AND NOT rejected
                  // Disabled if: documents already requested
                  if (!isApproved && !isRejected)
                    Opacity(
                      opacity: _documentsRequested ? 0.5 : 1.0,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _documentsRequested ? null : _showRequestDocumentsDialog,
                          icon: Icon(
                            _documentsRequested ? Icons.mark_email_read : Icons.mail_outline,
                          ),
                          label: Text(
                            _documentsRequested 
                              ? 'Documents Already Requested' 
                              : 'Request Additional Documents'
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.orange.withOpacity(0.6),
                            disabledForegroundColor: Colors.white.withOpacity(0.7),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _documentsRequested ? 0 : 2,
                          ),
                        ),
                      ),
                    ),
                  
                  if (!isApproved && !isRejected)
                    const SizedBox(height: 16),
                  
                  // Verification Checkbox - Only visible if documents requested
                  if (_documentsRequested && !isApproved && !isRejected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: CheckboxListTile(
                        title: const Text(
                          "I have verified all documents and necessary information",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _documentsVerificationChecked,
                        onChanged: (value) {
                          setState(() => _documentsVerificationChecked = value ?? false);
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.green,
                      ),
                    ),
                  
                  // BUTTON 2: Final Approval
                  // Visible if: documents requested AND NOT approved AND NOT rejected
                  // Enabled if: checkbox is checked
                  if (_documentsRequested && !isApproved && !isRejected)
                    Opacity(
                      opacity: _documentsVerificationChecked ? 1.0 : 0.5,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _documentsVerificationChecked 
                            ? _showFinalApprovalDialog 
                            : null,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Final Approval'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.green.withOpacity(0.5),
                            disabledForegroundColor: Colors.white.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _documentsVerificationChecked ? 2 : 0,
                          ),
                        ),
                      ),
                    ),
                  
                  if (_documentsRequested && !isApproved && !isRejected)
                    const SizedBox(height: 12),
                  
                  // BUTTON 3: Reject Application
                  // Only visible when NOT yet approved and NOT rejected
                  if (!isApproved && !isRejected)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _showRejectDialog,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject Application'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                    ),

                  // BUTTON 4: Revoke Access — only visible when already approved
                  if (isApproved) ...
                    [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Application Already Approved',
                                style: TextStyle(
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showRevokeDialog,
                          icon: const Icon(Icons.block),
                          label: const Text('Revoke Healthcare Provider Access'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: Colors.deepOrange, width: 2),
                          ),
                        ),
                      ),
                    ],
                  
                  if (isRejected)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Application Already Rejected',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'N/A',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrayDetailRow(String label, dynamic value) {
    if (value == null || (value is List && value.isEmpty)) {
      return _buildDetailRow(label, 'None selected');
    }

    List<String> items = [];
    if (value is List) {
      items = value.map((e) => e.toString()).toList();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2260FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF2260FF).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2260FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanRow(String label, dynamic value) {
    final agreed = value == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            agreed ? Icons.check_circle : Icons.cancel,
            color: agreed ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'under_review':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'on_hold':
        return 'On Hold';
      default:
        return status;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
