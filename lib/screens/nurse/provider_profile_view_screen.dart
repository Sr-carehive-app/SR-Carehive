import 'package:flutter/material.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'provider_profile_edit_screen.dart';

class ProviderProfileViewScreen extends StatefulWidget {
  const ProviderProfileViewScreen({Key? key}) : super(key: key);

  @override
  State<ProviderProfileViewScreen> createState() => _ProviderProfileViewScreenState();
}

class _ProviderProfileViewScreenState extends State<ProviderProfileViewScreen> {
  final primaryColor = const Color(0xFF2260FF);
  bool isLoading = true;
  Map<String, dynamic>? providerData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  Future<void> _loadProviderData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch provider data using backend call
      // The backend already has the provider context from the token
      final response = await NurseApiService.getProviderProfile();
      
      setState(() {
        providerData = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load profile: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Your Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (providerData != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Profile',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderProfileEditScreen(providerData: providerData!),
                  ),
                );
                if (result == true) {
                  _loadProviderData(); // Reload if profile was updated
                }
              },
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
                      Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadProviderData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProviderData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card with Name
                        _buildHeaderCard(),
                        const SizedBox(height: 16),

                        // Basic Information Section
                        _buildModernSection(
                          title: 'Basic Information',
                          icon: Icons.person_outline,
                          iconColor: primaryColor,
                          items: [
                            _buildModernInfoRow(
                              icon: Icons.badge_outlined,
                              label: 'Full Name',
                              value: providerData!['full_name'],
                              iconBg: const Color(0xFF2260FF),
                            ),
                            _buildModernInfoRow(
                              icon: Icons.phone_android,
                              label: 'Primary Mobile',
                              value: providerData!['mobile_number'],
                              iconBg: const Color(0xFF10B981),
                            ),
                            if (providerData!['alternative_mobile'] != null && 
                                providerData!['alternative_mobile'].toString().isNotEmpty)
                              _buildModernInfoRow(
                                icon: Icons.phone_iphone,
                                label: 'Alternative Mobile',
                                value: providerData!['alternative_mobile'],
                                iconBg: const Color(0xFF059669),
                              ),
                            _buildModernInfoRow(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: providerData!['email'] ?? 'Not provided',
                              iconBg: const Color(0xFF3B82F6),
                            ),
                            _buildModernInfoRow(
                              icon: Icons.location_city_outlined,
                              label: 'City',
                              value: providerData!['city'],
                              iconBg: const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Professional Details Section
                        _buildModernSection(
                          title: 'Professional Details',
                          icon: Icons.work_outline,
                          iconColor: const Color(0xFF8B5CF6),
                          items: [
                            _buildModernInfoRow(
                              icon: Icons.medical_services_outlined,
                              label: 'Professional Role',
                              value: providerData!['professional_role'],
                              iconBg: const Color(0xFF8B5CF6),
                            ),
                            if (providerData!['other_profession'] != null &&
                                providerData!['other_profession'].toString().isNotEmpty &&
                                providerData!['other_profession'] != 'N/A')
                              _buildModernInfoRow(
                                icon: Icons.psychology_outlined,
                                label: 'Other Profession',
                                value: providerData!['other_profession'],
                                iconBg: const Color(0xFF7C3AED),
                              ),
                            if (providerData!['doctor_specialty'] != null &&
                                providerData!['doctor_specialty'].toString().isNotEmpty &&
                                providerData!['doctor_specialty'] != 'N/A')
                              _buildModernInfoRow(
                                icon: Icons.local_hospital_outlined,
                                label: 'Doctor Specialty',
                                value: providerData!['doctor_specialty'],
                                iconBg: const Color(0xFF6D28D9),
                              ),
                            _buildModernInfoRow(
                              icon: Icons.school_outlined,
                              label: 'Highest Qualification',
                              value: providerData!['highest_qualification'],
                              iconBg: const Color(0xFFEC4899),
                            ),
                            _buildModernInfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Completion Year',
                              value: providerData!['completion_year']?.toString() ?? 'Not provided',
                              iconBg: const Color(0xFFDB2777),
                            ),
                            _buildModernInfoRow(
                              icon: Icons.assignment_outlined,
                              label: 'Registration Number',
                              value: providerData!['registration_number'],
                              iconBg: const Color(0xFFC026D3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Current Work Profile Section
                        _buildModernSection(
                          title: 'Current Work Profile',
                          icon: Icons.business_center_outlined,
                          iconColor: const Color(0xFFEF4444),
                          items: [
                            _buildModernInfoRow(
                              icon: Icons.work_history_outlined,
                              label: 'Current Work Role',
                              value: providerData!['current_work_role'],
                              iconBg: const Color(0xFFEF4444),
                            ),
                            _buildModernInfoRow(
                              icon: Icons.apartment_outlined,
                              label: 'Workplace',
                              value: providerData!['workplace'],
                              iconBg: const Color(0xFFDC2626),
                            ),
                            _buildModernInfoRow(
                              icon: Icons.timeline_outlined,
                              label: 'Years of Experience',
                              value: '${providerData!['years_of_experience'] ?? 0} years',
                              iconBg: const Color(0xFFB91C1C),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Services Offered Section
                        if (providerData!['services_offered'] != null &&
                            (providerData!['services_offered'] as List).isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Services Offered', Icons.medical_services, const Color(0xFF10B981)),
                              const SizedBox(height: 12),
                              _buildTagList(providerData!['services_offered'] as List, const Color(0xFF10B981)),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Availability Section
                        if (providerData!['availability_days'] != null &&
                            (providerData!['availability_days'] as List).isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Availability Days', Icons.calendar_month, const Color(0xFF3B82F6)),
                              const SizedBox(height: 12),
                              _buildTagList(providerData!['availability_days'] as List, const Color(0xFF3B82F6)),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Time Slots Section
                        if (providerData!['time_slots'] != null &&
                            (providerData!['time_slots'] as List).isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Time Slots', Icons.schedule, const Color(0xFFF59E0B)),
                              const SizedBox(height: 12),
                              _buildTagList(providerData!['time_slots'] as List, const Color(0xFFF59E0B)),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Languages Section
                        if (providerData!['languages'] != null &&
                            (providerData!['languages'] as List).isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Languages', Icons.language, const Color(0xFF8B5CF6)),
                              const SizedBox(height: 12),
                              _buildTagList(providerData!['languages'] as List, const Color(0xFF8B5CF6)),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Additional Information Section
                        if (providerData!['community_experience']?.toString().isNotEmpty == true ||
                            providerData!['service_areas']?.toString().isNotEmpty == true ||
                            providerData!['home_visit_fee'] != null ||
                            providerData!['teleconsultation_fee'] != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildModernSection(
                                title: 'Additional Information',
                                icon: Icons.info_outline,
                                iconColor: const Color(0xFF6366F1),
                                items: [
                                  if (providerData!['community_experience'] != null &&
                                      providerData!['community_experience'].toString().isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.people_outline,
                                      label: 'Community Experience',
                                      value: providerData!['community_experience'],
                                      iconBg: const Color(0xFF6366F1),
                                    ),
                                  if (providerData!['service_areas'] != null &&
                                      providerData!['service_areas'].toString().isNotEmpty)
                                    _buildModernInfoRow(
                                      icon: Icons.map_outlined,
                                      label: 'Service Areas',
                                      value: providerData!['service_areas'],
                                      iconBg: const Color(0xFF4F46E5),
                                    ),
                                  if (providerData!['home_visit_fee'] != null)
                                    _buildModernInfoRow(
                                      icon: Icons.home_outlined,
                                      label: 'Home Visit Fee',
                                      value: '₹${providerData!['home_visit_fee']}',
                                      iconBg: const Color(0xFF10B981),
                                    ),
                                  if (providerData!['teleconsultation_fee'] != null)
                                    _buildModernInfoRow(
                                      icon: Icons.videocam_outlined,
                                      label: 'Teleconsultation Fee',
                                      value: '₹${providerData!['teleconsultation_fee']}',
                                      iconBg: const Color(0xFF059669),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        // Consent & Agreement Section (Read-only)
                        _buildModernSection(
                          title: 'Consent & Agreement',
                          icon: Icons.verified_user_outlined,
                          iconColor: const Color(0xFF8B5CF6),
                          items: [
                            _buildConsentItem(
                              'Professional Declaration',
                              providerData!['agreed_to_declaration'],
                            ),
                            _buildConsentItem(
                              'Data Privacy Policy',
                              providerData!['agreed_to_data_privacy'],
                            ),
                            _buildConsentItem(
                              'Professional Responsibility',
                              providerData!['agreed_to_professional_responsibility'],
                            ),
                            _buildConsentItem(
                              'Terms & Conditions',
                              providerData!['agreed_to_terms'],
                            ),
                            _buildConsentItem(
                              'Communication Consent',
                              providerData!['agreed_to_communication'],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Unique ID Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.fingerprint, color: Colors.grey[700], size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Unique Provider ID: ',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  providerData!['id']?.toString() ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Application Status Section
                        _buildStatusCard(),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            providerData!['full_name'] ?? 'Healthcare Provider',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            providerData!['professional_role'] ?? '',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconBg,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTagList(List items, Color color) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            item.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusCard() {
    final status = providerData!['application_status'] ?? 'pending';
    final isApproved = status == 'approved';
    final approvalComments = providerData!['approval_comments'];
    
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel;
        statusText = 'Rejected';
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending;
        statusText = 'Pending';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Application Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (approvalComments != null && approvalComments.toString().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Admin Comments:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      approvalComments,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentItem(String label, dynamic agreed) {
    // Safely convert to boolean - handles null, bool, int (0/1), string
    final bool isAgreed = agreed == true || agreed == 1 || agreed == '1' || agreed == 'true';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isAgreed ? Icons.check_circle : Icons.cancel,
            color: isAgreed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
          Text(
            isAgreed ? 'Agreed' : 'Not Agreed',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAgreed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}
