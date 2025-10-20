// Payment Models for 3-Tier Payment System
// Registration (₹100) → Pre-Visit (50%) → Post-Visit (50%)

class PaymentStage {
  static const String registration = 'registration';
  static const String preVisit = 'pre_visit';
  static const String finalPayment = 'final_payment';
}

class AppointmentStatus {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String booked = 'booked'; // After ₹100 paid
  static const String amountSet = 'amount_set'; // After healthcare provider sets total amount
  static const String prePaid = 'pre_paid'; // After 50% pre-payment
  static const String completed = 'completed'; // After 100% payment
  static const String cancelled = 'cancelled';
}

class PaymentDetails {
  final String paymentId;
  final String receiptId;
  final double amount;
  final DateTime paidAt;
  final String stage; // registration, pre_visit, final_payment

  PaymentDetails({
    required this.paymentId,
    required this.receiptId,
    required this.amount,
    required this.paidAt,
    required this.stage,
  });

  Map<String, dynamic> toJson() => {
    'payment_id': paymentId,
    'receipt_id': receiptId,
    'amount': amount,
    'paid_at': paidAt.toIso8601String(),
    'stage': stage,
  };

  factory PaymentDetails.fromJson(Map<String, dynamic> json) => PaymentDetails(
    paymentId: json['payment_id'] ?? '',
    receiptId: json['receipt_id'] ?? '',
    amount: (json['amount'] ?? 0).toDouble(),
    paidAt: DateTime.parse(json['paid_at']),
    stage: json['stage'] ?? '',
  );
}

class AppointmentPaymentInfo {
  final int appointmentId;
  final String status;
  
  // Registration payment (₹100)
  final bool registrationPaid;
  final String? registrationPaymentId;
  final String? registrationReceiptId;
  final DateTime? registrationPaidAt;
  
  // Total amount set by nurse
  final double? totalAmount;
  final String? nurseRemarks;
  
  // Pre-visit payment (50%)
  final bool prePaid;
  final String? prePaymentId;
  final String? preReceiptId;
  final DateTime? prePaidAt;
  
  // Final payment (50%)
  final bool finalPaid;
  final String? finalPaymentId;
  final String? finalReceiptId;
  final DateTime? finalPaidAt;

  AppointmentPaymentInfo({
    required this.appointmentId,
    required this.status,
    this.registrationPaid = false,
    this.registrationPaymentId,
    this.registrationReceiptId,
    this.registrationPaidAt,
    this.totalAmount,
    this.nurseRemarks,
    this.prePaid = false,
    this.prePaymentId,
    this.preReceiptId,
    this.prePaidAt,
    this.finalPaid = false,
    this.finalPaymentId,
    this.finalReceiptId,
    this.finalPaidAt,
  });

  // Calculate amounts
  double get registrationAmount => 100.0;
  double? get preAmount => totalAmount != null ? totalAmount! / 2 : null;
  double? get finalAmount => totalAmount != null ? totalAmount! / 2 : null;
  
  double get totalPaid {
    double paid = 0;
    if (registrationPaid) paid += 100;
    if (prePaid && totalAmount != null) paid += totalAmount! / 2;
    if (finalPaid && totalAmount != null) paid += totalAmount! / 2;
    return paid;
  }
  
  double get totalPending {
    double pending = 0;
    if (!registrationPaid) pending += 100;
    if (totalAmount != null) {
      if (!prePaid) pending += totalAmount! / 2;
      if (!finalPaid) pending += totalAmount! / 2;
    }
    return pending;
  }
  
  String get paymentStatusText {
    if (finalPaid) return 'Fully Paid';
    if (prePaid) return 'Pre-Payment Done';
    if (registrationPaid) return 'Registration Done';
    return 'Not Paid';
  }
  
  bool get canPayRegistration => status == AppointmentStatus.approved && !registrationPaid;
  bool get canPayPreVisit => status == AppointmentStatus.amountSet && registrationPaid && !prePaid;
  bool get canPayFinal => prePaid && !finalPaid;

  factory AppointmentPaymentInfo.fromJson(Map<String, dynamic> json) {
    return AppointmentPaymentInfo(
      appointmentId: json['id'],
      status: json['status'] ?? 'pending',
      registrationPaid: json['registration_paid'] ?? false,
      registrationPaymentId: json['registration_payment_id'],
      registrationReceiptId: json['registration_receipt_id'],
      registrationPaidAt: json['registration_paid_at'] != null 
          ? DateTime.parse(json['registration_paid_at']) 
          : null,
      totalAmount: json['total_amount'] != null 
          ? (json['total_amount'] as num).toDouble() 
          : null,
      nurseRemarks: json['nurse_remarks'],
      prePaid: json['pre_paid'] ?? false,
      prePaymentId: json['pre_payment_id'],
      preReceiptId: json['pre_receipt_id'],
      prePaidAt: json['pre_paid_at'] != null 
          ? DateTime.parse(json['pre_paid_at']) 
          : null,
      finalPaid: json['final_paid'] ?? false,
      finalPaymentId: json['final_payment_id'],
      finalReceiptId: json['final_receipt_id'],
      finalPaidAt: json['final_paid_at'] != null 
          ? DateTime.parse(json['final_paid_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': appointmentId,
    'status': status,
    'registration_paid': registrationPaid,
    'registration_payment_id': registrationPaymentId,
    'registration_receipt_id': registrationReceiptId,
    'registration_paid_at': registrationPaidAt?.toIso8601String(),
    'total_amount': totalAmount,
    'nurse_remarks': nurseRemarks,
    'pre_paid': prePaid,
    'pre_payment_id': prePaymentId,
    'pre_receipt_id': preReceiptId,
    'pre_paid_at': prePaidAt?.toIso8601String(),
    'final_paid': finalPaid,
    'final_payment_id': finalPaymentId,
    'final_receipt_id': finalReceiptId,
    'final_paid_at': finalPaidAt?.toIso8601String(),
  };
}
