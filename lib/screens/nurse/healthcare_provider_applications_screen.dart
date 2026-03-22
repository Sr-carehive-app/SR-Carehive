import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:care12/screens/nurse/healthcare_provider_detail_screen.dart';
import 'package:care12/services/nurse_api_service.dart';
import 'package:care12/config/api_config.dart';
import 'package:care12/utils/safe_navigation.dart';
import 'package:care12/services/provider_export_service.dart';

class HealthcareProviderApplicationsScreen extends StatefulWidget {
  const HealthcareProviderApplicationsScreen({Key? key}) : super(key: key);

  @override
  State<HealthcareProviderApplicationsScreen> createState() => _HealthcareProviderApplicationsScreenState();
}

class _HealthcareProviderApplicationsScreenState extends State<HealthcareProviderApplicationsScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, approved, rejected

  // Selection state
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);

    try {
      print('🔍 Loading applications...');

      final authToken = NurseApiService.token;
      if (authToken == null) {
        print('❌ No auth token available');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/admin/providers').replace(
        queryParameters: _selectedFilter != 'all' ? {'status': _selectedFilter} : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final providers = data['providers'] as List<dynamic>;
        print('✅ Applications loaded: ${providers.length}');
        if (mounted) {
          setState(() {
            _applications = List<Map<String, dynamic>>.from(providers);
            _isLoading = false;
            // Clear selection whenever data is replaced — selected IDs from the
            // previous data set are no longer guaranteed to exist in the new set.
            _selectedIds.clear();
            _isSelectionMode = false;
          });
        }
      } else {
        final serverMsg = (data['error'] ?? 'Failed to load applications. Please try again.').toString();
        print('❌ Error loading applications: $serverMsg');
        if (mounted) setState(() => _isLoading = false);
        if (mounted) {
          final userMsg = (response.statusCode == 503 || serverMsg.toLowerCase().contains('unavailable'))
              ? 'Database is temporarily unavailable. Please try again later.'
              : serverMsg;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userMsg),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading applications: $e');
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        String userMessage = 'Failed to load applications. Please try again.';
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('network') || errorStr.contains('connection')) {
          userMessage = 'Network error. Please check your internet connection.';
        } else if (errorStr.contains('timeout')) {
          userMessage = 'Request timed out. Please try again.';
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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.clear();
      for (final app in _applications) {
        final id = app['id']?.toString();
        if (id != null) _selectedIds.add(id);
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  List<Map<String, dynamic>> get _selectedApplications {
    return _applications.where((a) => _selectedIds.contains(a['id']?.toString())).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'on_hold':
        return Colors.grey;
      default:
        return Colors.grey;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => SafeNavigation.pop(context, debugLabel: 'provider_applications_back'),
        ),
        title: const Text(
          'Healthcare Provider Applications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF2260FF),
        elevation: 0,
        actions: [
          // Select All / Deselect All
          if (!_isLoading && _applications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
              child: _isSelectionMode
                  ? TextButton(
                      onPressed: _deselectAll,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Deselect',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    )
                  : TextButton(
                      onPressed: _selectAll,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Select All',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
            ),
          // Export button
          if (!_isLoading && _applications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 8, bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () {
                  final toExport = _isSelectionMode ? _selectedApplications : _applications;
                  if (toExport.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No applications selected to export')),
                    );
                    return;
                  }
                  ProviderExportService.showBulkExportDialog(context, toExport);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white70, width: 1.5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(40, 36),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.file_download, size: 16, color: Colors.white),
                label: Text(
                  _isSelectionMode
                      ? 'Export (${_selectedIds.length})'
                      : 'Export',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ),
          // Refresh button
          Padding(
            padding: const EdgeInsets.only(left: 6, right: 12, top: 8, bottom: 8),
            child: OutlinedButton(
              onPressed: _isLoading ? null : _loadApplications,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white70, width: 1.5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(40, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20, color: Colors.white),
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
      body: Column(
        children: [
          // Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', 'approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
          ),

          // Selection info bar
          if (_isSelectionMode)
            Container(
              color: const Color(0xFF2260FF).withOpacity(0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: _selectedIds.length == _applications.length
                        ? true
                        : _selectedIds.isEmpty
                            ? false
                            : null,
                    onChanged: (_) {
                      if (_selectedIds.length == _applications.length) {
                        _deselectAll();
                      } else {
                        _selectAll();
                      }
                    },
                    activeColor: const Color(0xFF2260FF),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_selectedIds.length} of ${_applications.length} selected',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2260FF),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selectedIds.length == _applications.length
                        ? _deselectAll
                        : _selectAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: Text(
                      _selectedIds.length == _applications.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2260FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Applications List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _applications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No applications found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadApplications,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _applications.length,
                          itemBuilder: (context, index) {
                            final application = _applications[index];
                            return _buildApplicationCard(application);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
          // Clear selection when filter changes — stale IDs from the previous
          // filter must not bleed into the new result set.
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        _loadApplications();
      },
      selectedColor: const Color(0xFF2260FF),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.grey[200],
      elevation: 0,
      pressElevation: 0,
    );
  }

  Widget _buildApplicationCard(Map<String, dynamic> application) {
    final status = application['application_status'] ?? 'pending';
    final createdAt = DateTime.tryParse(application['created_at']?.toString() ?? '');
    final formattedDate = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : 'N/A';
    final id = application['id']?.toString() ?? '';
    final isSelected = _selectedIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: const Color(0xFF2260FF), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF2260FF).withOpacity(0.15)
                : Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (_isSelectionMode) {
              _toggleSelection(id);
              return;
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HealthcareProviderDetailScreen(
                  applicationData: application,
                ),
              ),
            );
            
            // Reload if application was updated (guard against disposed widget)
            if (result == true && mounted) {
              _loadApplications();
            }
          },
          onLongPress: () => _toggleSelection(id),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Always-visible checkbox — tapping it enters selection mode
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(id),
                          activeColor: const Color(0xFF2260FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2260FF).withOpacity(0.2)
                            : const Color(0xFF2260FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF2260FF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application['full_name'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            application['professional_role'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getStatusColor(status).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.fingerprint, 'ID: ${application['id'] ?? 'N/A'}'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.email, application['email'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.phone, application['mobile_number'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.location_city, application['city'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.calendar_today, formattedDate),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isSelectionMode)
                      Text(
                        isSelected ? 'Selected' : 'Tap to select',
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? const Color(0xFF2260FF) : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      )
                    else ...[
                      Text(
                        'Tap to view details',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
