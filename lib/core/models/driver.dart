class Driver {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? vehicleType;
  final String? vehiclePlate;
  final String availabilityStatus; // 'available', 'busy', 'offline'

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
    return Driver(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      availabilityStatus: json['availability_status'] as String? ?? 'available',
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
