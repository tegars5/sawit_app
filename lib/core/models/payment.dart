class Payment {
  final int id;
  final int orderId;
  final String reference;
  final String? merchantRef;
  final double amount;
  final String paymentMethod;
  final String status; // 'unpaid', 'paid', 'failed', 'expired'
  final DateTime? paidAt;
  final DateTime? expiredAt;
  final DateTime? createdAt;

  Payment({
    required this.id,
    required this.orderId,
    required this.reference,
    this.merchantRef,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.paidAt,
    this.expiredAt,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      reference: json['reference'] as String? ?? '',
      merchantRef: json['merchant_ref'] as String?,
      // ✅ Perbaikan: Handle String to Double
      amount: json['amount'] != null
          ? (json['amount'] is String
              ? (double.tryParse(json['amount']) ?? 0.0)
              : (json['amount'] as num).toDouble())
          : 0.0,
      paymentMethod: json['payment_method'] as String? ?? '',
      status: json['status'] as String? ?? 'unpaid',
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'] as String)
          : null,
      expiredAt: json['expired_at'] != null
          ? DateTime.tryParse(json['expired_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'reference': reference,
      'merchant_ref': merchantRef,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': status,
      'paid_at': paidAt?.toIso8601String(),
      'expired_at': expiredAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  bool get isPaid => status == 'paid';
  bool get isUnpaid => status == 'unpaid';
  bool get isFailed => status == 'failed';
  bool get isExpired => status == 'expired';
}
