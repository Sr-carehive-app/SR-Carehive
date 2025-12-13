import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:care12/screens/nurse/appointments_manage_screen.dart';
import 'package:care12/screens/nurse/healthcare_provider_applications_screen.dart';
import 'package:care12/services/nurse_api_service.dart';

class AdminDashboardSelectionScreen extends StatefulWidget {
  const AdminDashboardSelectionScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardSelectionScreen> createState() => _AdminDashboardSelectionScreenState();
}

class _AdminDashboardSelectionScreenState extends State<AdminDashboardSelectionScreen> {
  int _pendingProvidersCount = 0;
  int _totalProvidersCount = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final supabase = Supabase.instance.client;
      
      print('🔍 Loading provider statistics...');
      
      // Get total providers count
      final totalResponse = await supabase
          .from('healthcare_providers')
          .select('*');
      
      print('✅ Total providers loaded: ${totalResponse.length}');
      
      // Get pending providers count
      final pendingResponse = await supabase
          .from('healthcare_providers')
          .select('*')
          .eq('application_status', 'pending');
      
      print('✅ Pending providers loaded: ${pendingResponse.length}');
      
      if (mounted) {
        setState(() {
          _totalProvidersCount = totalResponse.length;
          _pendingProvidersCount = pendingResponse.length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          // Set to 0 on error so cards still show
          _totalProvidersCount = 0;
          _pendingProvidersCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Building AdminDashboardSelectionScreen - Loading: $_isLoadingStats, Pending: $_pendingProvidersCount, Total: $_totalProvidersCount');
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2260FF), Color(0xFF1A4FCC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2260FF).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome, Admin!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage healthcare services and provider applications',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Select Management Area',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),

              const SizedBox(height: 20),

              // Card 1: Healthcare Seeker Management (Patient Appointments)
              _buildManagementCard(
                context: context,
                icon: Icons.people_outline,
                iconColor: const Color(0xFF2260FF),
                title: 'Healthcare Seeker Management',
                description: 'Manage patient appointments, bookings, and service requests',
                buttonText: 'View Patient Appointments',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NurseAppointmentsManageScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Card 2: Healthcare Provider Applications
              _buildManagementCard(
                context: context,
                icon: Icons.badge_outlined,
                iconColor: const Color(0xFF10B981),
                title: 'Healthcare Provider Applications',
                description: 'Review and manage healthcare worker registration requests',
                buttonText: 'View Provider Applications',
                badgeCount: _pendingProvidersCount,
                totalCount: _totalProvidersCount,
                isLoadingStats: _isLoadingStats,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HealthcareProviderApplicationsScreen(),
                    ),
                  ).then((_) => _loadStatistics()); // Refresh stats on return
                },
              ),

              const SizedBox(height: 32),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select a management area to view and process requests',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
    int? badgeCount,
    int? totalCount,
    bool isLoadingStats = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 32,
                      ),
                    ),
                    if (badgeCount != null && totalCount != null)
                      isLoadingStats
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: badgeCount > 0 ? Colors.orange : Colors.green,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$badgeCount Pending',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total: $totalCount',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
