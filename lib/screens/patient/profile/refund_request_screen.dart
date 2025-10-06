import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:care12/services/support_service.dart';

class RefundRequestScreen extends StatefulWidget {
  const RefundRequestScreen({Key? key}) : super(key: key);

  @override
  State<RefundRequestScreen> createState() => _RefundRequestScreenState();
}

class _RefundRequestScreenState extends State<RefundRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentId = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _amount = TextEditingController();
  final _complaint = TextEditingController();
  // removed fields by request: referenceId, screenshotUrl, method, refundType, expected amount UI remains optional? We'll hide it.
  final _txnDateCtrl = TextEditingController();
  DateTime? _txnDate;
  String _reason = 'Duplicate charge';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _email.text = user.email ?? '';
      // Try to prefill name/phone from patients
      Supabase.instance.client
          .from('patients')
          .select('name, phone')
          .eq('user_id', user.id)
          .maybeSingle()
          .then((p) {
        if (!mounted || p == null) return;
        setState(() {
          if ((p['name'] ?? '').toString().isNotEmpty) _name.text = p['name'];
          if ((p['phone'] ?? '').toString().isNotEmpty) _mobile.text = p['phone'];
        });
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _paymentId.dispose();
  // orderId removed
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _amount.dispose();
    _complaint.dispose();
  // expectedRefundAmount removed
  // removed controllers disposed
    _txnDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await SupportService.submitPaymentQuery(
        paymentId: _paymentId.text.trim(),
  // orderId removed
        name: _name.text.trim(),
        email: _email.text.trim(),
        mobile: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
        amount: _amount.text.trim().isEmpty ? null : _amount.text.trim(),
        complaint: _complaint.text.trim().isEmpty ? null : _complaint.text.trim(),
        reason: _reason,
        // removed fields by request
        transactionDate: _txnDate?.toIso8601String(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Query submitted. We will get back to you soon.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2260FF);
    return Scaffold(
      appBar: AppBar(title: const Text('Ask for Refund'), backgroundColor: primary, centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Refund & Cancellation Policy', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• Refunds are processed only if a valid payment issue is identified and verified with the Razorpay payment gateway.'),
              const SizedBox(height: 6),
              const Text('• Cancellations of queries are allowed only before the issue has been resolved.'),
              const SizedBox(height: 6),
              const Text('• Refunds (if approved) will be credited back to your original payment method within 5–10 business days.'),
              const SizedBox(height: 6),
              Wrap(
                children: [
                  const Text('• For further help, contact us at '),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse('mailto:contact@srcarehive.com');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: const Text('contact@srcarehive.com', style: TextStyle(color: primary, decoration: TextDecoration.underline)),
                  ),
                  const Text(' .'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Payment Query Form', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                _field(label: 'Payment ID', controller: _paymentId, validator: (v) => v!.trim().isEmpty ? 'Payment ID is required' : null),
                // Order ID removed by request
                _field(label: 'Full Name', controller: _name, validator: (v) => v!.trim().isEmpty ? 'Full name is required' : null),
                _field(label: 'Email Address', controller: _email, keyboardType: TextInputType.emailAddress, validator: (v) => v!.contains('@') ? null : 'Enter a valid email'),
                _field(label: 'Mobile Number', controller: _mobile, keyboardType: TextInputType.phone),
                _field(label: 'Amount (₹)', controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                _field(label: 'Complaint / Remarks', controller: _complaint, maxLines: 4),
                const SizedBox(height: 8),
                _dropdown(label: 'Reason', value: _reason, items: const ['Duplicate charge','Service not received','Accidental payment','Other'], onChanged: (v) => setState(() => _reason = v!)),
                const SizedBox(height: 8),
                // Removed Method, Refund Type, Expected Amount, Reference ID, Screenshot URL by request
                _dateField(label: 'Transaction Date', controller: _txnDateCtrl, onPick: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(context: context, firstDate: DateTime(now.year-1), lastDate: DateTime(now.year+1), initialDate: _txnDate ?? now);
                  if (picked != null) {
                    setState(() { _txnDate = picked; _txnDateCtrl.text = picked.toIso8601String().split('T').first; });
                  }
                }),
                const SizedBox(height: 16),
                _submitting
                    ? const CircularProgressIndicator(color: primary)
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: _submit,
                          child: const Text('Submit Payment Query'),
                        ),
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFEDEFFF),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _dropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFEDEFFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateField({required String label, required TextEditingController controller, required VoidCallback onPick}) {
    return GestureDetector(
      onTap: onPick,
      child: AbsorbPointer(
        child: _field(label: label, controller: controller),
      ),
    );
  }
}
