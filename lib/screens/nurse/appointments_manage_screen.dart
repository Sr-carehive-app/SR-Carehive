import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:care12/services/nurse_api_service.dart';

class NurseAppointmentsManageScreen extends StatefulWidget {
  const NurseAppointmentsManageScreen({Key? key}) : super(key: key);

  @override
  State<NurseAppointmentsManageScreen> createState() => _NurseAppointmentsManageScreenState();
}

class _NurseAppointmentsManageScreenState extends State<NurseAppointmentsManageScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _historyItems = [];
  String _statusFilter = 'All';
  String _historySub = 'All';
  bool _historyLoading = false;
  String? _historyError;
  bool _historyEverLoaded = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { _items = await NurseApiService.listAppointments(); } catch (e) { _error = e.toString(); }
    if (mounted) setState(() { _loading = false; });
  }

  Future<void> _loadHistory({bool force=false}) async {
    if (_historyLoading) return; // prevent overlap
    if (!force && _historyEverLoaded) {
      // Still refetch if sub-filter changed (we cleared list before calling)
      if (_historyItems.isNotEmpty) return;
    }
    setState(() { _historyLoading = true; _historyError = null; });
    try {
      debugPrint('[History] Fetch start (status=$_historySub, force=$force)');
      final status = _historySub == 'All' ? null : _historySub.toLowerCase();
      final items = await NurseApiService.listHistory(status: status);
      debugPrint('[History] Fetched ${items.length} rows');
      _historyItems = items;
      _historyEverLoaded = true;
    } catch (e) {
      _historyError = e.toString();
      debugPrint('[History] Error: $_historyError');
    }
    if (mounted) setState(() { _historyLoading = false; });
  }

  Future<void> _approveDialog(Map<String, dynamic> appt) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final branchCtrl = TextEditingController();
    final commentsCtrl = TextEditingController();
    bool available = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & Assign Nurse'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nurse name')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Nurse phone')),
              TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Branch/Office')),
              TextField(controller: commentsCtrl, decoration: const InputDecoration(labelText: 'Comments'), maxLines: 3),
              const SizedBox(height: 8),
              StatefulBuilder(builder: (ctx, setS) => CheckboxListTile(
                    title: const Text('Available for selected time/duration'),
                    value: available,
                    onChanged: (v) => setS(() => available = v ?? true),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await NurseApiService.approveAppointment(
          id: (appt['id'] ?? '').toString(),
          nurseName: nameCtrl.text.trim(),
          nursePhone: phoneCtrl.text.trim(),
          branch: branchCtrl.text.trim().isEmpty ? null : branchCtrl.text.trim(),
          comments: commentsCtrl.text.trim().isEmpty ? null : commentsCtrl.text.trim(),
          available: available,
        );
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved'))); _load();
      } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approve failed: $e'))); }
    }
  }

  Future<void> _rejectDialog(Map<String, dynamic> appt) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (ok == true) {
      if (reasonCtrl.text.trim().isEmpty) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a reason to reject.'))); return; }
      try { await NurseApiService.rejectAppointment(id: (appt['id'] ?? '').toString(), reason: reasonCtrl.text.trim()); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected'))); _load(); } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reject failed: $e'))); }
    }
  }

  Future<void> _viewDetails(Map<String, dynamic> a) async {
    String fmtDate() { final d = DateTime.tryParse(a['date'] ?? ''); return d != null ? DateFormat('MMM dd, yyyy').format(d) : 'N/A'; }
    String fmtVal(dynamic v) => (v == null || (v is String && v.trim().isEmpty)) ? '-' : v.toString();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a['full_name'] ?? 'Appointment Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Date', fmtDate()),
              _kv('Time', fmtVal(a['time'])),
              _kv('Duration', a['duration_hours'] != null ? '${a['duration_hours']} hr' : '-'),
              _kv('Amount', a['amount_rupees'] != null ? '₹${a['amount_rupees']}' : '-'),
              const SizedBox(height: 8),
              _kv('Phone', fmtVal(a['phone'])),
              _kv('Address', fmtVal(a['address'])),
              _kv('Emergency Contact', fmtVal(a['emergency_contact'])),
              _kv('Patient Type', fmtVal(a['patient_type'])),
              _kv('Gender', fmtVal(a['gender'])),
              const SizedBox(height: 8),
              if (a['problem'] != null && (a['problem'] as String).isNotEmpty) _kv('Problem', a['problem']),
              const Divider(),
              _kv('Order ID', fmtVal(a['order_id'])),
              _kv('Payment ID', fmtVal(a['payment_id'])),
              if (a['status']?.toString().toLowerCase() == 'approved') ...[
                const Divider(), const Text('Assigned Nurse', style: TextStyle(fontWeight: FontWeight.bold)),
                _kv('Name', fmtVal(a['nurse_name'])), _kv('Phone', fmtVal(a['nurse_phone'])), _kv('Branch', fmtVal(a['nurse_branch'])), _kv('Comments', fmtVal(a['nurse_comments'])), _kv('Available', a['nurse_available'] == true ? 'Yes' : (a['nurse_available'] == false ? 'No' : '-')),
              ],
              if (a['status']?.toString().toLowerCase() == 'rejected') ...[ const Divider(), _kv('Rejection reason', fmtVal(a['rejection_reason'])), ],
            ],
          ),
        ),
        actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')) ],
      ),
    );
  }

  Color _statusColor(String s) { switch (s.toLowerCase()) { case 'approved': return Colors.green; case 'pending': return Colors.orange; case 'rejected': return Colors.red; default: return Colors.grey; } }

  DateTime? _parseIst(Map a) {
    final dateStr = (a['date'] ?? '').toString(); if (dateStr.isEmpty) return null; DateTime? base = DateTime.tryParse(dateStr); if (base == null) return null; base = base.toUtc(); final timeStr = (a['time'] ?? '').toString().trim(); int hour=0,minute=0; if (timeStr.isNotEmpty) { try { final t = DateFormat('h:mm a').parseStrict(timeStr); hour = t.hour; minute = t.minute; } catch(_){} } return DateTime(base.year, base.month, base.day, hour, minute).add(const Duration(hours:5, minutes:30)); }

  bool _isPast(Map a){ final dt=_parseIst(a); if(dt==null) return false; final nowIst=DateTime.now().toUtc().add(const Duration(hours:5, minutes:30)); return dt.isBefore(nowIst); }

  @override
  Widget build(BuildContext context) {
    final listFiltered = _filtered();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Appointments'),
        actions:[
          IconButton(
            onPressed: () {
              if (_statusFilter == 'History') { _historyItems.clear(); _loadHistory(force:true); }
              else { _load(); }
            },
            icon: const Icon(Icons.refresh))
        ],
        backgroundColor: const Color(0xFF2260FF),
        centerTitle:true),
      body: _loading
          ? const Center(child:CircularProgressIndicator())
          : _error!=null
            ? Center(child: Text(_error!, style: const TextStyle(color:Colors.red)))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 1 + listFiltered.length,
                  itemBuilder: (ctx,i){
                    if(i==0){
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        _filtersBar(),
                        if(_statusFilter=='History')...[
                          const SizedBox(height:8), _historyFiltersBar(),
                          if(_historyLoading) const Padding(padding: EdgeInsets.only(top:12), child: LinearProgressIndicator(minHeight:3)),
                          if(_historyError!=null) Padding(padding: const EdgeInsets.only(top:12), child: Text(_historyError!, style: const TextStyle(color: Colors.red))),
                        ],
                        const SizedBox(height:12),
                        if(listFiltered.isEmpty) Padding(
                          padding: const EdgeInsets.symmetric(vertical:24),
                          child: Center(child: Text(_statusFilter=='History' ? 'No history records' : 'No appointments to show')),
                        ),
                      ]);
                    }
                    final a = listFiltered[i-1];
                    final date = DateTime.tryParse(a['date'] ?? '');
                    final time = a['time'] ?? '';
                    final status = (a['status'] ?? 'pending') as String;
                    Widget? header;
                    if(_statusFilter=='History'){
                      final curDt=_parseIst(a); final curLabel= curDt!=null? DateFormat('EEE, MMM dd yyyy').format(curDt):'Unknown Date';
                      String? prevLabel; if(i-2>=0){ final prev=listFiltered[i-2]; final prevDt=_parseIst(prev); prevLabel = prevDt!=null? DateFormat('EEE, MMM dd yyyy').format(prevDt):'Unknown Date'; }
                      if(prevLabel==null || prevLabel!=curLabel){
                        header = Padding(padding: const EdgeInsets.only(bottom:6, top:4), child: Row(children:[Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: const Color(0xFF2260FF).withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Text(curLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2260FF)))))]));
                      }
                    }
                    final card = Card(margin: const EdgeInsets.only(bottom:16), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                        Text(a['full_name'] ?? 'Unknown', style: const TextStyle(fontSize:16, fontWeight: FontWeight.bold)),
                        Container(padding: const EdgeInsets.symmetric(horizontal:8, vertical:4), decoration: BoxDecoration(color:_statusColor(status), borderRadius: BorderRadius.circular(12)), child: Text(status.toUpperCase(), style: const TextStyle(color:Colors.white, fontSize:12, fontWeight: FontWeight.bold)))
                      ]),
                      const SizedBox(height:8),
                      Row(children:[ const Icon(Icons.calendar_today, size:14, color: Color(0xFF2260FF)), const SizedBox(width:6), Text(date!=null? DateFormat('MMM dd, yyyy').format(date):'N/A'), const SizedBox(width:12), const Icon(Icons.access_time, size:14, color: Color(0xFF2260FF)), const SizedBox(width:6), Text(time) ]),
                      const SizedBox(height:4),
                      Text('Phone: ${a['phone'] ?? '-'}'),
                      if(a['problem']!=null && (a['problem'] as String).isNotEmpty)...[ const SizedBox(height:8), Text('Problem: ${a['problem']}', style: const TextStyle(color: Colors.black54)) ],
                      if(a['nurse_name']!=null)...[ const Divider(), Text('Assigned Nurse: ${a['nurse_name']}'), if(a['nurse_phone']!=null) Text('Phone: ${a['nurse_phone']}'), if(a['nurse_branch']!=null) Text('Branch: ${a['nurse_branch']}'), if(a['nurse_comments']!=null) Text('Comments: ${a['nurse_comments']}') ],
                      const SizedBox(height:12),
                      Row(children:[
                        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.close, color: Colors.red), label: const Text('Reject', style: TextStyle(color:Colors.red)), onPressed: status.toLowerCase()=='rejected'? null : () => _rejectDialog(a))),
                        const SizedBox(width:8),
                        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.check_circle, color: Colors.white), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), label: const Text('Approve', style: TextStyle(color:Colors.white)), onPressed: status.toLowerCase()=='approved'? null : () => _approveDialog(a))),
                        const SizedBox(width:8),
                        IconButton(tooltip:'View details', onPressed: () => _viewDetails(a), icon: const Icon(Icons.visibility, color: Color(0xFF2260FF)))
                      ])
                    ])));
                    if(header!=null) return Column(crossAxisAlignment: CrossAxisAlignment.start, children:[header!, card]);
                    return card;
                  },
                ),
              ),
    );
  }

  List<Map<String, dynamic>> _filtered(){
    // Build past/upcoming only if we have any current appointments; history shouldn't depend on this
    final past=<Map<String,dynamic>>[]; final upcoming=<Map<String,dynamic>>[];
    for(final a in _items){ (_isPast(a) ? past : upcoming).add(a); }

    if(_statusFilter=='History'){
      List<Map<String,dynamic>> base = _historyItems.isNotEmpty
          ? List<Map<String,dynamic>>.from(_historyItems)
          : past; // fallback to locally derived past if server history empty or not fetched
      if(_historySub!='All'){
        final want=_historySub.toLowerCase();
        base = base.where((e)=>(e['status']??'').toString().toLowerCase()==want).toList();
      }
      base.sort((a,b){
        DateTime? ad=_parseIst(a); DateTime? bd=_parseIst(b);
        ad ??= DateTime.tryParse(a['date']??'') ?? DateTime.fromMillisecondsSinceEpoch(0);
        bd ??= DateTime.tryParse(b['date']??'') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return base;
    }

    if(_statusFilter=='All') return upcoming;
    final want=_statusFilter.toLowerCase();
    return upcoming.where((e)=>(e['status']??'').toString().toLowerCase()==want).toList();
  }

  Widget _filtersBar(){
    final options=['All','Pending','Approved','Rejected','History'];
    return Wrap(spacing:8, runSpacing:8, children: options.map((o){ final sel=_statusFilter==o; return ChoiceChip(label: Text(o), selected: sel, onSelected:(_)=> setState((){ _statusFilter=o; if(_statusFilter!='History') _historySub='All'; })); }).toList());
  }

  Widget _historyFiltersBar(){
    final sub=['All','Pending','Approved','Rejected'];
    return Wrap(spacing:8, children: sub.map((s){ final sel=_historySub==s; return ChoiceChip(label: Text(s), selected: sel, onSelected:(_)=> setState((){ _historySub=s; _historyItems.clear(); _loadHistory(force:true); })); }).toList());
  }

  Widget _kv(String k, String v){
    return Padding(padding: const EdgeInsets.only(bottom:6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[ SizedBox(width:140, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(v)) ]));
  }
}
