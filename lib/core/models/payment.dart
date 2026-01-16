class Payment {
  final int id;
  final int?
      orderId; // ✅ Made optional - backend doesn't send this in driver orders
  final String? reference; // ✅ Made optional
  final String? merchantRef;
  final double amount;
  final String paymentMethod;
  final String status; // 'unpaid', 'paid', 'failed', 'expired'
  final DateTime? paidAt;
  final DateTime? expiredAt;
  final DateTime? createdAt;

  Payment({
    required this.id,
    this.orderId, // ✅ Now optional
    this.reference, // ✅ Now optional
    this.merchantRef,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.paidAt,
    this.expiredAt,
    this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    // Helper function untuk konversi yang aman
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Payment(
      id: toInt(json['id'], 0),
      orderId: json['order_id'] != null ? toInt(json['order_id'], 0) : null,
      reference: json['reference']?.toString(),
      merchantRef: json['merchant_ref']?.toString(),
      // ✅ Perbaikan: Handle String to Double
      amount: parseDouble(json['amount']),
      paymentMethod: json['payment_method']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unpaid',
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
      expiredAt: json['expired_at'] != null
          ? DateTime.tryParse(json['expired_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
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
