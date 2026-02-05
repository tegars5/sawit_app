class Driver {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? vehicleType;
  final String? vehiclePlate;
  final String availabilityStatus; 

  Driver({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.vehicleType,
    this.vehiclePlate,
    required this.availabilityStatus,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    return Driver(
      id: toInt(json['id'], 0),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      vehiclePlate: json['vehicle_number']?.toString() ??
          json['vehicle_plate']?.toString(),
      availabilityStatus:
          json['availability_status']?.toString() ?? 'available',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'vehicle_type': vehicleType,
      'vehicle_plate': vehiclePlate,
      'availability_status': availabilityStatus,
    };
  }

  bool get isAvailable => availabilityStatus == 'available';
}
