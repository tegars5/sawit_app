class TrackingResponse {
  final LocationPoint? driverLocation;
  final LocationPoint destinationLocation; // Titik rumah Mitra
  final String orderStatus;
  final double? distanceKm;
  final int? estimatedMinutes;
  final DriverInfo? driver;

  TrackingResponse({
    this.driverLocation,
    required this.destinationLocation,
    required this.orderStatus,
    this.distanceKm,
    this.estimatedMinutes,
    this.driver,
  });

  factory TrackingResponse.fromJson(Map<String, dynamic> json) {
    return TrackingResponse(
      driverLocation: json['driver_location'] != null
          ? LocationPoint.fromJson(
              json['driver_location'] is Map<String, dynamic>
                  ? json['driver_location']
                  : Map<String, dynamic>.from(json['driver_location'] as Map))
          : null,
      destinationLocation: LocationPoint.fromJson(
          json['destination_location'] is Map<String, dynamic>
              ? json['destination_location']
              : Map<String, dynamic>.from(json['destination_location'] as Map)),
      orderStatus: json['order_status']?.toString() ?? '',
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num?)?.toDouble()
          : null,
      estimatedMinutes: json['estimated_minutes'] is int
          ? json['estimated_minutes']
          : int.tryParse(json['estimated_minutes']?.toString() ?? ''),
      driver: json['driver'] != null
          ? DriverInfo.fromJson(json['driver'] is Map<String, dynamic>
              ? json['driver']
              : Map<String, dynamic>.from(json['driver'] as Map))
          : null,
    );
  }
}

class LocationPoint {
  final double latitude;
  final double longitude;

  LocationPoint({required this.latitude, required this.longitude});

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DriverInfo {
  final String name;
  final String phone;

  DriverInfo({required this.name, required this.phone});

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
    );
  }
}
