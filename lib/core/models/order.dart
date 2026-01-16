import 'order_item.dart';
import 'payment.dart';
import 'delivery_order.dart';
import 'user.dart';

class Order {
  final int id;
  final String orderCode;
  final int userId;
  final double totalAmount;
  final String
      status; // 'pending', 'confirmed', 'on_delivery', 'completed', 'cancelled'
  final String destinationAddress;
  final double? destinationLat;
  final double? destinationLng;
  final double? distanceKm;
  final int? estimatedMinutes;
  final String? waybillPdf;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OrderItem>? orderItems;
  final Payment? payment;
  final DeliveryOrder? deliveryOrder;
  final User? user; // Customer/Mitra user info

  Order({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.totalAmount,
    required this.status,
    required this.destinationAddress,
    this.destinationLat,
    this.destinationLng,
    this.distanceKm,
    this.estimatedMinutes,
    this.waybillPdf,
    this.cancelledAt,
    required this.createdAt,
    this.updatedAt,
    this.orderItems,
    this.payment,
    this.deliveryOrder,
    this.user,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Helper function untuk konversi int yang aman
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    return Order(
      id: toInt(json['id'], 0),
      orderCode: json['order_code']?.toString() ?? '',
      userId: toInt(json['user_id'], 0),
      // ✅ Safe parsing for totalAmount
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'pending',
      destinationAddress: json['destination_address']?.toString() ?? '',
      // ✅ Safe parsing for coordinates
      destinationLat: json['destination_lat'] != null
          ? (json['destination_lat'] is String
              ? double.tryParse(json['destination_lat'])
              : (json['destination_lat'] as num?)?.toDouble())
          : null,
      destinationLng: json['destination_lng'] != null
          ? (json['destination_lng'] is String
              ? double.tryParse(json['destination_lng'])
              : (json['destination_lng'] as num?)?.toDouble())
          : null,
      // ✅ Safe parsing for distanceKm
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] is String
              ? double.tryParse(json['distance_km'])
              : (json['distance_km'] as num?)?.toDouble())
          : null,
      // ✅ Safe parsing for estimatedMinutes
      estimatedMinutes: json['estimated_minutes'] != null
          ? (json['estimated_minutes'] is String
              ? int.tryParse(json['estimated_minutes'])
              : json['estimated_minutes'] as int?)
          : null,
      waybillPdf: json['waybill_pdf']?.toString(),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      orderItems: json['order_items'] != null
          ? (json['order_items'] as List)
              .map((item) => OrderItem.fromJson(item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map)))
              .toList()
          : null,
      payment: json['payment'] != null
          ? Payment.fromJson(json['payment'] is Map<String, dynamic>
              ? json['payment']
              : Map<String, dynamic>.from(json['payment'] as Map))
          : null,
      deliveryOrder: json['delivery_order'] != null
          ? DeliveryOrder.fromJson(
              json['delivery_order'] is Map<String, dynamic>
                  ? json['delivery_order']
                  : Map<String, dynamic>.from(json['delivery_order'] as Map))
          : null,
      user: json['user'] != null
          ? User.fromJson(json['user'] is Map<String, dynamic>
              ? json['user']
              : Map<String, dynamic>.from(json['user'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_code': orderCode,
      'user_id': userId,
      'total_amount': totalAmount,
      'status': status,
      'destination_address': destinationAddress,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'distance_km': distanceKm,
      'estimated_minutes': estimatedMinutes,
      'waybill_pdf': waybillPdf,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'order_items': orderItems?.map((item) => item.toJson()).toList(),
      'payment': payment?.toJson(),
      'delivery_order': deliveryOrder?.toJson(),
      'user': user?.toJson(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isOnDelivery => status == 'on_delivery';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get canBeCancelled => isPending || isConfirmed;

  /// Get driver info from deliveryOrder
  /// Returns driver info if available, null otherwise
  User? get driver => deliveryOrder?.driver;

  /// Get formatted distance for UI display
  String get formattedDistance {
    if (distanceKm == null) return '0 KM';
    return '${distanceKm!.toStringAsFixed(1)} KM';
  }

  /// Get formatted estimated time for UI display
  String get formattedEstimatedTime {
    if (estimatedMinutes == null) return '0 Menit';
    if (estimatedMinutes! < 60) {
      return '$estimatedMinutes Menit';
    }
    final hours = estimatedMinutes! ~/ 60;
    final minutes = estimatedMinutes! % 60;
    return minutes > 0 ? '$hours Jam $minutes Menit' : '$hours Jam';
  }

  /// Check if order has location data
  bool get hasLocationData => destinationLat != null && destinationLng != null;

  /// Check if order has distance calculation
  bool get hasDistanceCalculation =>
      distanceKm != null && estimatedMinutes != null;

  /// Get full waybill PDF URL from delivery_order
  String? get waybillUrl {
    // Priority 1: Check delivery_order.waybill_pdf (from backend)
    if (deliveryOrder?.waybillPdf != null &&
        deliveryOrder!.waybillPdf!.isNotEmpty) {
      // Use ngrok URL from AppConfig (without /api suffix)
      const baseUrl = 'https://unpensionable-zander-unmotioned.ngrok-free.dev';
      return '$baseUrl/storage/waybills/${deliveryOrder!.waybillPdf}';
    }

    // Priority 2: Check order.waybill_pdf (fallback)
    if (waybillPdf != null && waybillPdf!.isNotEmpty) {
      const baseUrl = 'https://unpensionable-zander-unmotioned.ngrok-free.dev';
      return '$baseUrl/storage/$waybillPdf';
    }

    return null;
  }

  /// Check if waybill is available
  bool get hasWaybill =>
      (deliveryOrder?.waybillPdf != null &&
          deliveryOrder!.waybillPdf!.isNotEmpty) ||
      (waybillPdf != null && waybillPdf!.isNotEmpty);
}
