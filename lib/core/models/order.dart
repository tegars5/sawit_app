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
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OrderItem>? orderItems;
  final Payment? payment;
  final DeliveryOrder? deliveryOrder;

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
    this.cancelledAt,
    required this.createdAt,
    this.updatedAt,
    this.orderItems,
    this.payment,
    this.deliveryOrder,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      orderCode: json['order_code'] as String? ?? '',
      userId: json['user_id'] as int? ?? 0,
      // ✅ Safe parsing for totalAmount
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      destinationAddress: json['destination_address'] as String? ?? '',
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
              .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : null,
      payment: json['payment'] != null
          ? Payment.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      deliveryOrder: json['delivery_order'] != null
          ? DeliveryOrder.fromJson(
              json['delivery_order'] as Map<String, dynamic>)
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
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'order_items': orderItems?.map((item) => item.toJson()).toList(),
      'payment': payment?.toJson(),
      'delivery_order': deliveryOrder?.toJson(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isOnDelivery => status == 'on_delivery';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  bool get canBeCancelled => isPending || isConfirmed;

  /// Get customer/driver user info from deliveryOrder
  /// Returns driver info if available, null otherwise
  User? get user => deliveryOrder?.driver;
}
