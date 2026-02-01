class AdminDashboardSummary {
  final int pendingOrders;
  final int processedOrders;
  final int activeDrivers;
  final int totalDrivers;
  final String bestSellingProduct;
  final String bestSellingProductQty; // e.g., "450 Ton"
  final List<int> weeklyOrders;
  final List<DriverLocation> activeFleetLocations;

  AdminDashboardSummary({
    required this.pendingOrders,
    required this.processedOrders,
    required this.activeDrivers,
    required this.totalDrivers,
    required this.bestSellingProduct,
    required this.bestSellingProductQty,
    required this.weeklyOrders,
    required this.activeFleetLocations,
  });

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    final bestProductQty = parseInt(json['best_selling_product_qty']);

    return AdminDashboardSummary(
      pendingOrders: parseInt(json['pending_orders']),
      processedOrders: parseInt(json['processed_orders']),
      activeDrivers: parseInt(json['active_drivers']),
      totalDrivers: parseInt(json['total_drivers']),
      bestSellingProduct: json['best_selling_product']?.toString() ?? '-',
      bestSellingProductQty: '$bestProductQty Ton',
      weeklyOrders: (json['weekly_orders'] as List<dynamic>?)
              ?.map((e) => parseInt(e))
              .toList() ??
          List.filled(7, 0),
      activeFleetLocations: (json['active_fleet_locations'] as List<dynamic>?)
              ?.map((e) => DriverLocation.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DriverLocation {
  final int driverId;
  final String driverName;
  final int orderId;
  final double latitude;
  final double longitude;

  DriverLocation({
    required this.driverId,
    required this.driverName,
    required this.orderId,
    required this.latitude,
    required this.longitude,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      driverId: json['driver_id'] is int
          ? json['driver_id']
          : int.parse(json['driver_id'].toString()),
      driverName: json['driver_name'] ?? 'Unknown',
      orderId: json['order_id'] is int
          ? json['order_id']
          : int.parse(json['order_id'].toString()),
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : double.parse(json['latitude'].toString()),
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : double.parse(json['longitude'].toString()),
    );
  }
}
