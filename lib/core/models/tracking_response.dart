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
          ? LocationPoint.fromJson(json['driver_location'])
          : null,
      destinationLocation: LocationPoint.fromJson(json['destination_location']),
      orderStatus: json['order_status'] as String,
      distanceKm: json['distance_km'] != null
          ? (json['distance_km'] as num).toDouble()
          : null,
      estimatedMinutes: json['estimated_minutes'] as int?,
      driver:
          json['driver'] != null ? DriverInfo.fromJson(json['driver']) : null,
    );
  }
}

class LocationPoint {
  final double latitude;
  final double longitude;

  LocationPoint({required this.latitude, required this.longitude});

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class DriverInfo {
  final String name;
  final String phone;

  DriverInfo({required this.name, required this.phone});

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}
