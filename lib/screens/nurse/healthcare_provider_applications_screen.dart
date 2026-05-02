import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
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

  // ── Real-time search state ──
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchActive = false;
  bool _searchLoading = false;
  String? _searchError;

  // ── Date range filter ──
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
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

      // Always fetch ALL records — status/date filtering is done client-side
      // so search + status + date can all work simultaneously on the full dataset.
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/admin/providers');

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
            // Clear selection whenever data is replaced.
            _selectedIds.clear();
            _isSelectionMode = false;
          });
          // If a search was active, re-run it on the freshly loaded data
          // so _searchResults never holds stale results.
          if (_searchActive && _searchCtrl.text.trim().isNotEmpty) {
            _runSearch(_searchCtrl.text.trim());
          }
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

  // ── Live search: client-side on already-loaded data (debounced 300ms) ──
  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    final q = val.trim();
    if (q.isEmpty) {
      setState(() {
        _searchActive = false;
        _searchResults = [];
        _searchLoading = false;
        _searchError = null;
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      return;
    }
    setState(() { _searchActive = true; _searchLoading = true; _searchError = null; });
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  // Client-side search across all loaded records — avoids UUID cast errors
  // from Supabase direct queries and works instantly with existing data.
  void _runSearch(String q) {
    if (!mounted) return;
    try {
      final lower = q.toLowerCase();

      // Search across: name, email, phone, city, role, full provider ID, status
      final matched = _applications.where((row) {
        bool contains(String? val) =>
            val != null && val.toLowerCase().contains(lower);
        return contains(row['full_name']?.toString())
            || contains(row['email']?.toString())
            || contains(row['mobile_number']?.toString())
            || contains(row['city']?.toString())
            || contains(row['professional_role']?.toString())
            || contains(row['id']?.toString())       // UUID partial/full match
            || contains(row['application_status']?.toString());
      }).toList();

      // Maintain created_at desc order
      matched.sort((a, b) {
        final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
        final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
        return bd.compareTo(ad);
      });

      if (!mounted) return;
      setState(() { _searchResults = matched; _searchLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _searchLoading = false; _searchError = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  // Unified list: search/full base → status filter → date filter
  List<Map<String, dynamic>> _getDisplayList() {
    List<Map<String, dynamic>> base = _searchActive ? _searchResults : _applications;
    if (_selectedFilter != 'all') {
      base = base.where((e) => (e['application_status'] ?? '').toString().toLowerCase() == _selectedFilter).toList();
    }
    if (_dateFrom != null || _dateTo != null) {
      base = base.where((e) {
        final raw = e['created_at']?.toString();
        if (raw == null || raw.isEmpty) return false;
        final d = DateTime.tryParse(raw)?.toLocal();
        if (d == null) return false;
        final dDate = DateTime(d.year, d.month, d.day);
        if (_dateFrom != null && dDate.isBefore(DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day))) return false;
        if (_dateTo != null && dDate.isAfter(DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day))) return false;
        return true;
      }).toList();
    }
    return base;
  }

  Future<void> _showDateFilterDialog() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: (_dateFrom != null && _dateTo != null) ? DateTimeRange(start: _dateFrom!, end: _dateTo!) : null,
      helpText: 'Filter by application date',
      saveText: 'Apply',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2260FF), onPrimary: Colors.white, surface: Colors.white),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) setState(() { _dateFrom = range.start; _dateTo = range.end; });
  }

  // ── Search bar widget ──
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name, phone, email or provider ID…',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          prefixIcon: _searchLoading
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2260FF))),
                )
              : const Icon(Icons.search_rounded, color: Color(0xFF2260FF), size: 22),
          suffixIcon: _searchActive
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.grey.shade600,
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _searchCtrl.clear();
                    setState(() {
                      _searchActive = false; _searchResults = [];
                      _searchLoading = false; _searchError = null;
                      _selectedIds.clear(); _isSelectionMode = false;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1.2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2260FF), width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
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
      for (final app in _getDisplayList()) {
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
    return _getDisplayList().where((a) => _selectedIds.contains(a['id']?.toString())).toList();
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
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, color: Colors.white, size: 16),
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
                  final displayList = _getDisplayList();
                  final toExport = _isSelectionMode ? _selectedApplications : displayList;
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
                icon: const FaIcon(FontAwesomeIcons.download, size: 14, color: Colors.white),
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
                  : const FaIcon(FontAwesomeIcons.arrowsRotate, size: 17, color: Colors.white),
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
      body: Builder(builder: (context) {
          final displayList = _getDisplayList();
          final anyFilterActive = _searchActive || _selectedFilter != 'all' || _dateFrom != null;
          final hasDate = _dateFrom != null && _dateTo != null;
          final hasFilter = _selectedFilter != 'all' || hasDate || _searchActive;
          return Column(
            children: [
              // ── White header: search bar + filter chips ──
              Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search bar
                    _buildSearchBar(),
                    const SizedBox(height: 8),
                    // Filter chips row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                            const SizedBox(width: 8),
                            // Date range filter chip (right of Rejected)
                            FilterChip(
                              avatar: Icon(Icons.calendar_month_outlined, size: 14,
                                  color: hasDate ? const Color(0xFF2260FF) : Colors.grey.shade600),
                              label: Text(
                                hasDate
                                    ? '${DateFormat('dd MMM').format(_dateFrom!)} – ${DateFormat('dd MMM yy').format(_dateTo!)}'
                                    : 'Date',
                                style: TextStyle(fontSize: 12,
                                    color: hasDate ? const Color(0xFF2260FF) : Colors.black87),
                              ),
                              selected: hasDate,
                              selectedColor: const Color(0xFF2260FF).withOpacity(0.12),
                              checkmarkColor: const Color(0xFF2260FF),
                              onSelected: (_) => _showDateFilterDialog(),
                            ),
                            // Reset chip
                            if (hasFilter) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                avatar: Icon(Icons.refresh_rounded, size: 14, color: Colors.red.shade700),
                                label: Text('Reset', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                                backgroundColor: Colors.red.withOpacity(0.08),
                                side: BorderSide(color: Colors.red.withOpacity(0.3)),
                                onPressed: () {
                                  _searchDebounce?.cancel();
                                  _searchCtrl.clear();
                                  setState(() {
                                    _selectedFilter = 'all';
                                    _dateFrom = null;
                                    _dateTo = null;
                                    _searchActive = false;
                                    _searchResults = [];
                                    _searchLoading = false;
                                    _searchError = null;
                                    _selectedIds.clear();
                                    _isSelectionMode = false;
                                  });
                                  // Re-fetch all from backend — _applications may only
                                  // hold a status-filtered subset before reset.
                                  _loadApplications();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Active date range label
                    if (hasDate)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Row(children: [
                          Icon(Icons.info_outline, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Flexible(child: Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(_dateFrom!)} → ${DateFormat('dd MMM yyyy').format(_dateTo!)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          )),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() { _dateFrom = null; _dateTo = null; }),
                            child: Icon(Icons.close, size: 13, color: Colors.grey.shade500),
                          ),
                        ]),
                      ),
                    // Results count
                    if (anyFilterActive)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                        child: Row(children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFF2260FF), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _searchLoading ? 'Searching…' : '${displayList.length} result${displayList.length == 1 ? '' : 's'} found',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2260FF), fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                    if (_searchError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Text(_searchError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    const SizedBox(height: 10),
                  ],
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
                        value: _selectedIds.length == displayList.length
                            ? true
                            : _selectedIds.isEmpty ? false : null,
                        onChanged: (_) {
                          if (_selectedIds.length == displayList.length) { _deselectAll(); } else { _selectAll(); }
                        },
                        activeColor: const Color(0xFF2260FF),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${_selectedIds.length} of ${displayList.length} selected',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2260FF)),
                        ),
                      ),
                      TextButton(
                        onPressed: _selectedIds.length == displayList.length ? _deselectAll : _selectAll,
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                        child: Text(
                          _selectedIds.length == displayList.length ? 'Deselect All' : 'Select All',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2260FF), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // Applications List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _searchLoading
                        ? const Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF2260FF)),
                              SizedBox(height: 12),
                              Text('Searching…', style: TextStyle(color: Color(0xFF2260FF))),
                            ],
                          ))
                        : displayList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FaIcon(FontAwesomeIcons.inbox, size: 72, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      _searchActive
                                          ? 'No results for "${_searchCtrl.text.trim()}"'
                                          : 'No applications found',
                                      style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadApplications,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: displayList.length,
                                  itemBuilder: (context, index) {
                                    return _buildApplicationCard(displayList[index]);
                                  },
                                ),
                              ),
              ),
            ],
          );
        }),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // Status filter is applied client-side in _getDisplayList — no need
        // to reload from backend. This keeps search results in sync.
        setState(() {
          _selectedFilter = value;
          _selectedIds.clear();
          _isSelectionMode = false;
        });
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
                      child: const FaIcon(
                        FontAwesomeIcons.user,
                        color: Color(0xFF2260FF),
                        size: 22,
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
                      _buildInfoRow(FontAwesomeIcons.fingerprint, 'ID: ${application['id'] ?? 'N/A'}'),
                      const SizedBox(height: 8),
                      _buildInfoRow(FontAwesomeIcons.envelope, application['email'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(FontAwesomeIcons.phone, application['mobile_number'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(FontAwesomeIcons.locationDot, application['city'] ?? 'N/A'),
                      const SizedBox(height: 8),
                      _buildInfoRow(FontAwesomeIcons.calendarDays, formattedDate),
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
                      const FaIcon(
                        FontAwesomeIcons.chevronRight,
                        size: 11,
                        color: Colors.grey,
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
        FaIcon(icon, size: 13, color: Colors.grey[600]),
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
