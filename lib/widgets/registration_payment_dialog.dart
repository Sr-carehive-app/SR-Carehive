import 'package:flutter/material.dart';
import 'package:care12/services/payment_service.dart';

class RegistrationPaymentDialog extends StatefulWidget {
  final String appointmentId;  // Changed from int to String (UUID)
  final String patientName;
  final String patientEmail;
  final String patientPhone;
  final VoidCallback onSuccess;

  const RegistrationPaymentDialog({
    Key? key,
    required this.appointmentId,
    required this.patientName,
    required this.patientEmail,
    required this.patientPhone,
    required this.onSuccess,
  }) : super(key: key);

  @override
  State<RegistrationPaymentDialog> createState() => _RegistrationPaymentDialogState();
}

class _RegistrationPaymentDialogState extends State<RegistrationPaymentDialog> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: screenHeight * 0.9, // Use 90% of screen height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2260FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.payment,
                      color: Color(0xFF2260FF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registration Fee',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Confirm Your Booking',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2260FF), Color(0xFF4A80FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Amount to Pay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(
                            '₹1',  // TODO: Change to ₹100 for production
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Information Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What happens next?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildInfoRow(
                            icon: Icons.check_circle_outline,
                            text: 'Registration fee confirms your booking',
                          ),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            icon: Icons.phone_in_talk,
                            text: 'Our care provider will contact you soon',
                          ),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            icon: Icons.verified_user,
                            text: 'They will verify details and schedule your appointment',
                          ),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            icon: Icons.account_balance_wallet,
                            text: 'Final payment in 2 installments: 50% before visit, 50% after',
                          ),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            icon: Icons.medical_services,
                            text: 'Total cost depends on condition severity, duration & diagnosis',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Important Note
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Registration fee is non-refundable but will be adjusted in your final bill',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Payment Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _handlePayment(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2260FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.payment, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Pay ₹1 Now',  // TODO: Change to ₹100 for production
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Secure payment badge
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 13, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Secure Payment via Razorpay',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2260FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handlePayment(BuildContext context) async {
    // CRITICAL FIX: Store the navigator and scaffold messenger BEFORE any navigation
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    Navigator.pop(context); // Close registration dialog
    
    // Show loading dialog with a key to dismiss it later
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

    try {
      print('[Payment] Starting payment process...');
      final result = await PaymentService.payRegistrationFee(
        appointmentId: widget.appointmentId,
        email: widget.patientEmail,
        mobile: widget.patientPhone,
        name: widget.patientName,
      );
      print('[Payment] ✅ Payment completed successfully: $result');

      // Close loading dialog immediately
      navigator.pop();
      print('[Payment] Loading dialog closed');
      
      // Extract payment ID before calling callback
      final paymentId = result['razorpay_payment_id']?.toString() ?? 
                       result['payment_id']?.toString() ?? 
                       result['paymentId']?.toString() ?? 
                       'Completed';
      
      // Small delay to ensure context is stable before callback
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Call success callback to refresh appointments
      widget.onSuccess();
      print('[Payment] Success callback executed');
      
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
                      const Text(
                        '✅ Registration Payment Successful!',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment ID: $paymentId',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '📧 Confirmation email sent! Care provider will contact you.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (e) {
      print('[Payment] ❌ Payment failed: $e');
      
      // Close loading dialog
      navigator.pop();
      print('[Payment] Loading dialog closed after error');
      
      // Show error
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
