import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:care12/screens/nurse/appointments_manage_screen.dart';
import 'package:care12/screens/nurse/healthcare_provider_applications_screen.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'package:care12/config/api_config.dart';
import 'healthcare_provider_selection_screen.dart';

class NursingExecutiveDashboardScreen extends StatefulWidget {
  const NursingExecutiveDashboardScreen({Key? key}) : super(key: key);

  @override
  State<NursingExecutiveDashboardScreen> createState() =>
      _NursingExecutiveDashboardScreenState();
}

class _NursingExecutiveDashboardScreenState
    extends State<NursingExecutiveDashboardScreen> {
  // ─── colors ───────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF0F766E);   // teal-700
  static const Color _primaryDark = Color(0xFF0D5E57); // teal-800
  static const Color _accent = Color(0xFF6D28D9);    // violet-700

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
      // Re-use the same admin stats endpoint — the token gives access since
      // the nursing executive session holds a valid superadmin-level token.
      final authToken = NurseApiService.token;
      if (authToken == null) {
        if (mounted) setState(() => _isLoadingStats = false);
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/providers/stats'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          setState(() {
            _totalProvidersCount = (data['total'] as num).toInt();
            _pendingProvidersCount = (data['pending'] as num).toInt();
            _isLoadingStats = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
            _totalProvidersCount = 0;
            _pendingProvidersCount = 0;
          });
          final serverMsg = (data['error'] ?? '').toString();
          if (response.statusCode == 503 ||
              serverMsg.toLowerCase().contains('unavailable')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Database is temporarily unavailable. Please try again later.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 6),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _totalProvidersCount = 0;
          _pendingProvidersCount = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4), // very light teal tint
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome banner ──────────────────────────────────────────
              _buildWelcomeBanner(),

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

              // ── Card 1: Patient Appointments ────────────────────────────
              _buildCard(
                icon: Icons.people_outline,
                iconColor: _primary,
                gradientColors: [const Color(0xFF0F766E), const Color(0xFF0D5E57)],
                title: 'Healthcare Seeker Management',
                description:
                    'Manage patient appointments, bookings, and care requests',
                buttonText: 'View Appointments',
                badgeCount: null,
                totalCount: null,
                isLoadingStats: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const NurseAppointmentsManageScreen(isSuperAdmin: true),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── Card 2: Provider Applications ───────────────────────────
              _buildCard(
                icon: Icons.assignment_ind,
                iconColor: _accent,
                gradientColors: [const Color(0xFF6D28D9), const Color(0xFF5B21B6)],
                title: 'Healthcare Provider Applications',
                description:
                    'Review and manage healthcare worker registration requests',
                buttonText: 'View Applications',
                badgeCount: _pendingProvidersCount,
                totalCount: _totalProvidersCount,
                isLoadingStats: _isLoadingStats,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HealthcareProviderApplicationsScreen(),
                    ),
                  ).then((_) => _loadStatistics());
                },
              ),

              const SizedBox(height: 32),

              // ── Info footer ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6EE7B7)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, color: Colors.teal[700], size: 22),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 110,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0, top: 6.0, bottom: 6.0),
        child: Container(
          constraints: const BoxConstraints(minWidth: 95, maxWidth: 110),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5252), Color(0xFFE53935)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showLogoutConfirmation,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.logout, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      title: const Text(
        'Nursing Executive Dashboard',
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
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_hospital,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Welcome, Nursing Executive!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Manage healthcare services and provider applications',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.88),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
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
            color: iconColor.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: iconColor.withOpacity(0.15)),
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
                      child: Icon(icon, color: iconColor, size: 32),
                    ),
                    if (badgeCount != null && totalCount != null)
                      isLoadingStats
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: badgeCount > 0
                                        ? Colors.orange
                                        : Colors.green,
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
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 10),
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
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.logout, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            const Text(
              'Logout',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to logout?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You will need to login again',
                      style: TextStyle(
                          fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.logout,
                color: Colors.white, size: 20),
            label: const Text(
              'Logout',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await NurseApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => const HealthcareProviderSelectionScreen()),
        (route) => false,
      );
    }
  }
}
