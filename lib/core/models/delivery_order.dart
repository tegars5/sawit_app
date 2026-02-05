import 'user.dart';

class DeliveryOrder {
  final int id;
  final int? orderId; 
  final int driverId;
  final String
      status; 
  final String? waybillPdf;
  final User? driver;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryOrder({
    required this.id,
    this.orderId,
    required this.driverId,
    required this.status,
    this.waybillPdf,
    this.driver,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    return DeliveryOrder(
      id: toInt(json['id'], 0),
      orderId: json['order_id'] != null ? toInt(json['order_id'], 0) : null,
      driverId: toInt(json['driver_id'], 0),
      status: json['status']?.toString() ?? 'assigned',
      waybillPdf: json['waybill_pdf']?.toString(),
      driver: json['driver'] != null
          ? User.fromJson(json['driver'] is Map<String, dynamic>
              ? json['driver']
              : Map<String, dynamic>.from(json['driver'] as Map))
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'driver_id': driverId,
      'status': status,
      'waybill_pdf': waybillPdf,
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
