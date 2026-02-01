class TrackingResponse {
  final String orderStatus;
  final DriverLocation? driverLocation;
  final DestinationLocation destinationLocation;
  final double distanceKm;
  final int estimatedMinutes;
  final DriverInfo? driver;

  TrackingResponse({
    required this.orderStatus,
    this.driverLocation,
    required this.destinationLocation,
    required this.distanceKm,
    required this.estimatedMinutes,
    this.driver,
  });

  factory TrackingResponse.fromJson(Map<String, dynamic> json) {
    return TrackingResponse(
      orderStatus: json['order_status'] ?? 'pending',
      driverLocation: json['driver_location'] != null
          ? DriverLocation.fromJson(json['driver_location'])
          : null,
      destinationLocation: DestinationLocation.fromJson(
        json['destination_location'] ?? {'latitude': 0.0, 'longitude': 0.0},
      ),
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      estimatedMinutes: json['estimated_minutes'] ?? 0,
      driver:
          json['driver'] != null ? DriverInfo.fromJson(json['driver']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_status': orderStatus,
      'driver_location': driverLocation?.toJson(),
      'destination_location': destinationLocation.toJson(),
      'distance_km': distanceKm,
      'estimated_minutes': estimatedMinutes,
      'driver': driver?.toJson(),
    };
  }

  // Helper untuk cek apakah driver sudah tersedia
  bool get hasDriver => driver != null && driverLocation != null;

  // Helper untuk status display
  String get statusDisplay {
    switch (orderStatus) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'on_the_way':
        return 'Dalam Perjalanan';
      case 'delivered':
        return 'Terkirim';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return orderStatus;
    }
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
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class DestinationLocation {
  final double latitude;
  final double longitude;

  DestinationLocation({
    required this.latitude,
    required this.longitude,
  });

  factory DestinationLocation.fromJson(Map<String, dynamic> json) {
    return DestinationLocation(
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
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
      name: json['name'] ?? 'Driver',
      phone: json['phone'] ?? '-',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}
