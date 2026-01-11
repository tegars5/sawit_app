import 'user.dart';

class DeliveryOrder {
  final int id;
  final int orderId;
  final int driverId;
  final String
      status; // 'assigned', 'on_the_way', 'arrived', 'completed', 'cancelled'
  final User? driver;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryOrder({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.status,
    this.driver,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    return DeliveryOrder(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      driverId: json['driver_id'] as int,
      status: json['status'] as String,
      driver: json['driver'] != null
          ? User.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'driver_id': driverId,
      'status': status,
      'driver': driver?.toJson(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isAssigned => status == 'assigned';
  bool get isOnTheWay => status == 'on_the_way';
  bool get isArrived => status == 'arrived';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
}
