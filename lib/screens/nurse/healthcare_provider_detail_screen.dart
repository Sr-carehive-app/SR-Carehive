import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/services/provider_email_service.dart';

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

  @override
  void dispose() {
    _reasonController.dispose();
    _commentsController.dispose();
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
      }

      if (reason != null && reason.isNotEmpty) {
        updateData['rejection_reason'] = reason;
      }

      await supabase
          .from('healthcare_providers')
          .update(updateData)
          .eq('id', widget.applicationData['id']);

      // Send email notification
      final userEmail = widget.applicationData['email'] ?? '';
      final userName = widget.applicationData['full_name'] ?? 'User';
      final professionalRole = widget.applicationData['professional_role'] ?? 'Healthcare Provider';

      if (status == 'approved') {
        // Send approval email (non-blocking)
        ProviderEmailService.sendApprovalEmail(
          userEmail: userEmail,
          userName: userName,
          professionalRole: professionalRole,
          adminComments: comments,
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
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating application: $e'),
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
          onPressed: () => Navigator.pop(context),
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
            // Section A: Basic Information
            _buildSectionTitle('Section A: Basic Information'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildDetailRow('Full Name', widget.applicationData['full_name']),
              _buildDetailRow('Mobile Number', widget.applicationData['mobile_number']),
              _buildDetailRow('Alternative Mobile', widget.applicationData['alternative_mobile'] ?? 'Not provided'),
              _buildDetailRow('Email', widget.applicationData['email']),
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

            const SizedBox(height: 32),

            // Action Buttons - Always show both, disable based on status
            if (!_isProcessing)
              Column(
                children: [
                  // Approve Button
                  Opacity(
                    opacity: isApproved ? 0.5 : 1.0,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isApproved ? null : _showApproveDialog,
                        icon: Icon(
                          isApproved ? Icons.check_circle : Icons.check_circle_outline,
                        ),
                        label: Text(isApproved ? 'Already Approved' : 'Approve Application'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.green.withOpacity(0.6),
                          disabledForegroundColor: Colors.white.withOpacity(0.7),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: isApproved ? 0 : 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Reject Button
                  Opacity(
                    opacity: isRejected ? 0.5 : 1.0,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: isRejected ? null : _showRejectDialog,
                        icon: Icon(
                          isRejected ? Icons.cancel : Icons.cancel_outlined,
                        ),
                        label: Text(isRejected ? 'Already Rejected' : 'Reject Application'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          disabledForegroundColor: Colors.red.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isRejected ? Colors.red.withOpacity(0.3) : Colors.red,
                            width: 2,
                          ),
                        ),
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
