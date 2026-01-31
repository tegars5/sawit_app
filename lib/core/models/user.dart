import '../../config/app_config.dart';

class User {
  final int id;
  final String name;
  final String email;
  final String role; // 'admin', 'mitra', 'driver'
  final String? phone;
  final String? address;
  final String? profilePicture;
  final String? fcmToken;
  final String? token; // Auth token
  final String? vehicleType;
  final String? vehiclePlate;
  final bool isAvailable; // For drivers
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.address,
    this.profilePicture,
    this.fcmToken,
    this.token,
    this.vehicleType,
    this.vehiclePlate,
    this.isAvailable = false,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper function untuk konversi int yang aman
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    String? parseProfileUrl(String? url) {
      if (url == null) return null;
      if (url.startsWith('http')) return url;

      var cleanPath = url;
      // Handle file:/// prefix
      if (cleanPath.startsWith('file:///')) {
        cleanPath = cleanPath.replaceFirst('file:///', '');
      }
      // Remove leading slash
      if (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.substring(1);
      }

      final base = AppConfig.baseUrl.replaceAll('/api', '');
      // Assuming standard Laravel storage link
      return '$base/storage/$cleanPath';
    }

    return User(
      id: toInt(json['id'], 0),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ??
          'mitra', // ✅ Default to 'mitra' if not provided
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      profilePicture: parseProfileUrl(json['profile_picture']?.toString() ??
          json['profile_photo']?.toString()),
      fcmToken: json['fcm_token']?.toString(),
      token: json['token']?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      vehiclePlate: json['vehicle_number']?.toString() ??
          json['vehicle_plate']?.toString(),
      // ✅ Parse availability from multiple possible fields
      // Backend sends 'availability_status' with values: 'available' or 'busy'
      // Some endpoints might still send 'is_available' as boolean
      isAvailable: json['availability_status'] == 'available' ||
          json['is_available'] == 1 ||
          json['is_available'] == true ||
          json['is_available'] == 'available',
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
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'profile_picture': profilePicture,
      'fcm_token': fcmToken,
      'token': token,
      'vehicle_type': vehicleType,
      'vehicle_number':
          vehiclePlate, // Backend expects vehicle_number for some operations, but let's send both or standardized. Backend sends vehicle_number. Let's send vehicle_number in toJson to align with backend "Update" body if we reuse this method?
      // Actually Admin uses createDriver/updateDriver with map. toJson might be used for caching.
      'vehicle_plate': vehiclePlate,
      'is_available': isAvailable,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    String? phone,
    String? address,
    String? profilePicture,
    String? fcmToken,
    String? token,
    String? vehicleType,
    String? vehiclePlate,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      profilePicture: profilePicture ?? this.profilePicture,
      fcmToken: fcmToken ?? this.fcmToken,
      token: token ?? this.token,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isMitra => role == 'mitra';
  bool get isDriver => role == 'driver';
}
