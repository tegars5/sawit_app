import 'payment.dart';

class PaymentResponse {
  final String message;
  final Payment payment;
  final String? checkoutUrl;
  final Map<String, dynamic>? paymentInstructions;

  PaymentResponse({
    required this.message,
    required this.payment,
    this.checkoutUrl,
    this.paymentInstructions,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      message: json['message']?.toString() ?? '',
      payment: Payment.fromJson(json['payment'] is Map<String, dynamic>
          ? json['payment']
          : Map<String, dynamic>.from(json['payment'] as Map)),
      checkoutUrl: json['checkout_url']?.toString(),
      paymentInstructions: json['payment_instructions'] is Map<String, dynamic>
          ? json['payment_instructions']
          : (json['payment_instructions'] != null
              ? Map<String, dynamic>.from(json['payment_instructions'] as Map)
              : null),
    );
  }

  // Get QR code URL if available
  String? get qrUrl {
    if (paymentInstructions == null) return null;
    final data = paymentInstructions!['data'];
    if (data == null) return null;
    final dataMap = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    return dataMap['qr_url']?.toString();
  }

  // Alias for compatibility
  String? get qrCodeUrl => qrUrl;

  // Get payment code if available
  String? get payCode {
    if (paymentInstructions == null) return null;
    final data = paymentInstructions!['data'];
    if (data == null) return null;
    final dataMap = data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
    return dataMap['pay_code']?.toString();
  }

  // Alias for compatibility
  String? get paymentCode => payCode;

  // Get reference from payment (nullable since backend doesn't always send it)
  String? get reference => payment.reference;

  // Get payment method from payment
  String get paymentMethod => payment.paymentMethod;

  // Get status from payment
  String get status => payment.status;

  // Get expires at from payment
  DateTime get expiresAt =>
      payment.createdAt?.add(const Duration(hours: 24)) ??
      DateTime.now().add(const Duration(hours: 24));
}
