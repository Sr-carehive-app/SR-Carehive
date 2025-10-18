import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:care12/widgets/registration_payment_dialog.dart';
import 'package:care12/models/payment_models.dart';
import 'package:care12/services/payment_service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final Color primaryColor = const Color(0xFF2260FF);
  List<Map<String, dynamic>> appointments = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        setState(() {
          errorMessage = 'User not logged in';
          isLoading = false;
        });
        return;
      }

      // Get patient_id first
      final patient = await supabase
          .from('patients')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (patient == null) {
        setState(() {
          errorMessage = 'Patient profile not found';
          isLoading = false;
        });
        return;
      }

    // Fetch appointments for this patient (all statuses)
      final response = await supabase
          .from('appointments')
          .select('*')
      .eq('patient_id', patient['id'])
          .order('created_at', ascending: false);

      setState(() {
        appointments = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load appointments: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'approved':
        return Colors.green;
      case 'booked':
        return Colors.blue;
      case 'amount_set':
        return Colors.purple;
      case 'pre_paid':
        return Colors.indigo;
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.teal;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return '✓';
      case 'approved':
        return '✓';
      case 'pending':
        return '⏳';
      case 'completed':
        return '✓';
      case 'rejected':
        return '✗';
      case 'cancelled':
        return '✗';
      default:
        return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Appointments'),
        backgroundColor: primaryColor,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAppointments,
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
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAppointments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : appointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No appointments found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Schedule your first appointment to get started',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAppointments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final appointment = appointments[index];
                          final date = DateTime.tryParse(appointment['date'] ?? '');
                          final time = appointment['time'] ?? '';
                          final status = appointment['status'] ?? 'pending';
                          final problem = appointment['problem'] ?? '';
                          final patientType = appointment['patient_type'] ?? 'Yourself';
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              appointment['full_name'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Age: ${appointment['age'] ?? 'N/A'} | ${appointment['gender'] ?? 'N/A'}',
                                              style: const TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _getStatusIcon(status),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              status.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        date != null 
                                            ? DateFormat('MMM dd, yyyy').format(date)
                                            : 'Date not available',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.access_time, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        time,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.person, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        'For: $patientType',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  if (problem.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Problem Description:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      problem,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 16, color: primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        appointment['phone'] ?? 'Phone not available',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  // Payment Section
                                  if (_shouldShowPaymentSection(appointment)) ...[
                                    const Divider(height: 24),
                                    _buildPaymentSection(appointment),
                                  ],
                                  
                                  // Nurse assignment details (shown when approved)
                                  if ((appointment['status'] ?? '').toString().toLowerCase() == 'approved') ...[
                                    const Divider(height: 24),
                                    const Text(
                                      'Assigned Care Provider',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    if (appointment['nurse_name'] != null)
                                      Text('Name: ${appointment['nurse_name']}'),
                                    if (appointment['nurse_phone'] != null)
                                      Text('Phone: ${appointment['nurse_phone']}'),
                                    if (appointment['nurse_branch'] != null)
                                      Text('Branch: ${appointment['nurse_branch']}'),
                                    if (appointment['nurse_comments'] != null)
                                      Text('Comments: ${appointment['nurse_comments']}'),
                                  ],
                                  // Rejection details if any
                                  if ((appointment['status'] ?? '').toString().toLowerCase() == 'rejected') ...[
                                    const Divider(height: 24),
                                    const Text('Request Rejected', style: TextStyle(fontWeight: FontWeight.bold)),
                                    if (appointment['rejection_reason'] != null)
                                      Text('Reason: ${appointment['rejection_reason']}'),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  bool _shouldShowPaymentSection(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? '').toString().toLowerCase();
    return status == 'approved' || 
           status == 'booked' || 
           status == 'amount_set' || 
           status == 'pre_paid';
  }

  Widget _buildPaymentSection(Map<String, dynamic> appointment) {
    final status = (appointment['status'] ?? '').toString().toLowerCase();
    final registrationPaid = appointment['registration_paid'] ?? false;
    final totalAmount = appointment['total_amount'];
    final prePaid = appointment['pre_paid'] ?? false;
    final finalPaid = appointment['final_paid'] ?? false;
    final nurseRemarks = appointment['nurse_remarks'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2260FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Payment Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Registration Payment Status
          _buildPaymentStatusRow(
            'Registration Fee',
            '₹1',  // TODO: Change to ₹100 for production
            registrationPaid,
            appointment['registration_payment_id'],
          ),

          // Show "Pay ₹1" button if approved and not paid (TODO: Change to ₹100 for production)
          if (status == 'approved' && !registrationPaid) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRegistrationPaymentDialog(appointment),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text(
                  'Pay ₹1 to Register Booking',  // TODO: Change to ₹100 for production
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '💡 Our care provider will contact you after payment',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],

          // Show waiting message if booked but amount not set
          if (status == 'booked' && totalAmount == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Waiting for care provider to set the total service amount',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Show total amount and split payments
          if (totalAmount != null) ...[
            const Divider(height: 24),
            Text(
              'Total Service Amount: ₹${totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (nurseRemarks != null) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks: $nurseRemarks',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 12),

            // Pre-payment status
            _buildPaymentStatusRow(
              'Pre-Visit Charges (50%)',
              '₹${(totalAmount / 2).toStringAsFixed(0)}',
              prePaid,
              appointment['pre_payment_id'],
            ),

            // Pre-payment button
            if (!prePaid && status == 'amount_set') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payPreVisit(appointment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: Text(
                    'Pay ₹${(totalAmount / 2).toStringAsFixed(0)} (Pre-Visit)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Final payment status
            _buildPaymentStatusRow(
              'Final Charges (50%)',
              '₹${(totalAmount / 2).toStringAsFixed(0)}',
              finalPaid,
              appointment['final_payment_id'],
            ),

            // Final payment button
            if (prePaid && !finalPaid) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _payFinalAmount(appointment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.payment, color: Colors.white),
                  label: Text(
                    'Pay ₹${(totalAmount / 2).toStringAsFixed(0)} (Final)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],

            // Completion message
            if (finalPaid) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '✅ Payment Completed! Total: ₹',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${(100 + totalAmount).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentStatusRow(
    String label,
    String amount,
    bool isPaid,
    String? paymentId,
  ) {
    return Row(
      children: [
        Icon(
          isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isPaid ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (isPaid && paymentId != null)
                Text(
                  'ID: ${paymentId.length > 20 ? paymentId.substring(0, 20) + '...' : paymentId}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isPaid ? Colors.green : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isPaid ? 'PAID' : 'PENDING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.green : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  void _showRegistrationPaymentDialog(Map<String, dynamic> appointment) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    // Get appointment ID as String (UUID format)
    final String appointmentId = appointment['id'].toString();
    
    print('🔍 DEBUG: appointment ID = $appointmentId');
    
    showDialog(
      context: context,
      builder: (context) => RegistrationPaymentDialog(
        appointmentId: appointmentId,
        patientName: appointment['full_name'] ?? '',
        patientEmail: user?.email ?? appointment['patient_email'] ?? '',
        patientPhone: appointment['phone'] ?? '',
        onSuccess: () {
          _loadAppointments(); // Reload appointments
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Registration payment successful!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _payPreVisit(Map<String, dynamic> appointment) async {
    final totalAmount = appointment['total_amount'];
    if (totalAmount == null) return;

    // Get appointment ID as String (UUID format)
    final String appointmentId = appointment['id'].toString();

    // CRITICAL FIX: Store navigator and scaffold messenger before any navigation
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing Payment...'),
                ],
              ),
            ),
          ),
        ),
      );

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      final result = await PaymentService.payPreVisitAmount(
        appointmentId: appointmentId,
        totalAmount: (totalAmount as num).toDouble(),
        email: user?.email ?? appointment['patient_email'] ?? '',
        mobile: appointment['phone'] ?? '',
        name: appointment['full_name'] ?? '',
      );

      // Close loading dialog immediately
      navigator.pop();
      
      // Extract payment ID
      final paymentId = result['razorpay_payment_id']?.toString() ?? 
                       result['payment_id']?.toString() ?? 
                       result['paymentId']?.toString() ?? 
                       'Completed';
      
      // Small delay to ensure context stability
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Reload appointments to reflect updated status
      if (mounted) {
        await _loadAppointments();
      }
      
      // Show success message
      scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '✅ Pre-visit payment of ₹${(totalAmount / 2).toStringAsFixed(0)} successful!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment ID: $paymentId',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      // Close loading dialog
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('❌ Payment failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _payFinalAmount(Map<String, dynamic> appointment) async {
    final totalAmount = appointment['total_amount'];
    if (totalAmount == null) return;

    // Get appointment ID as String (UUID format)
    final String appointmentId = appointment['id'].toString();

    // CRITICAL FIX: Store navigator and scaffold messenger before any navigation
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing Payment...'),
                ],
              ),
            ),
          ),
        ),
      );

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      final result = await PaymentService.payFinalAmount(
        appointmentId: appointmentId,
        totalAmount: (totalAmount as num).toDouble(),
        email: user?.email ?? appointment['patient_email'] ?? '',
        mobile: appointment['phone'] ?? '',
        name: appointment['full_name'] ?? '',
      );

      // Close loading dialog immediately
      navigator.pop();
      
      // Extract payment ID
      final paymentId = result['razorpay_payment_id']?.toString() ?? 
                       result['payment_id']?.toString() ?? 
                       result['paymentId']?.toString() ?? 
                       'Completed';
      
      // Small delay to ensure context stability
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Reload appointments to reflect updated status
      if (mounted) {
        await _loadAppointments();
      }
      
      // Show success message
      scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '✅ Final payment of ₹${(totalAmount / 2).toStringAsFixed(0)} successful!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment ID: $paymentId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '🎉 Appointment completed! Thank you.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      // Close loading dialog
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('❌ Payment failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
} 