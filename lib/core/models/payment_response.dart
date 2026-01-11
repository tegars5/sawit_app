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
      message: json['message'] as String,
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      checkoutUrl: json['checkout_url'] as String?,
      paymentInstructions:
          json['payment_instructions'] as Map<String, dynamic>?,
    );
  }

  // Get QR code URL if available
  String? get qrUrl {
    if (paymentInstructions == null) return null;
    final data = paymentInstructions!['data'] as Map<String, dynamic>?;
    return data?['qr_url'] as String?;
  }

  // Alias for compatibility
  String? get qrCodeUrl => qrUrl;

  // Get payment code if available
  String? get payCode {
    if (paymentInstructions == null) return null;
    final data = paymentInstructions!['data'] as Map<String, dynamic>?;
    return data?['pay_code'] as String?;
  }

  // Alias for compatibility
  String? get paymentCode => payCode;

  // Get reference from payment
  String get reference => payment.reference;

  // Get payment method from payment
  String get paymentMethod => payment.paymentMethod;

  // Get status from payment
  String get status => payment.status;

  // Get expires at from payment
  DateTime get expiresAt =>
      payment.createdAt?.add(const Duration(hours: 24)) ??
      DateTime.now().add(const Duration(hours: 24));
}
