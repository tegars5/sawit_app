class TrackingResponse {
  final DriverLocation? driverLocation;
  final String orderStatus;
  final double? distanceKm;
  final int? estimatedMinutes;
  final DriverInfo? driver;

  TrackingResponse({
    this.driverLocation,
    required this.orderStatus,
    this.distanceKm,
    this.estimatedMinutes,
    this.driver,
  });

  factory TrackingResponse.fromJson(Map<String, dynamic> json) {
    return TrackingResponse(
      driverLocation: json['driver_location'] != null
          ? DriverLocation.fromJson(
              json['driver_location'] as Map<String, dynamic>)
          : null,
      orderStatus: json['order_status'] as String,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      estimatedMinutes: json['estimated_minutes'] as int?,
      driver: json['driver'] != null
          ? DriverInfo.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DriverLocation {
  final double latitude;
  final double longitude;

  DriverLocation({
    required this.latitude,
    required this.longitude,
  });

  factory DriverLocation.fromJson(Map<String, dynamic> json) {
    return DriverLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class DriverInfo {
  final String name;
  final String phone;

  DriverInfo({
    required this.name,
    required this.phone,
  });

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}
