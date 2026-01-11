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
    this.isAvailable = false,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      profilePicture: json['profile_picture'] as String?,
      fcmToken: json['fcm_token'] as String?,
      token: json['token'] as String?,
      isAvailable: json['is_available'] == 1 ||
          json['is_available'] == true ||
          json['is_available'] == 'available',
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
      'name': name,
      'email': email,
      'role': role,
      'phone': phone,
      'address': address,
      'profile_picture': profilePicture,
      'fcm_token': fcmToken,
      'token': token,
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
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isMitra => role == 'mitra';
  bool get isDriver => role == 'driver';
}
