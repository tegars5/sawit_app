class Product {
  final int id;
  final String name;
  final String description;
  final String category;
  final double price;
  final int stock;
  final String? images;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    this.images,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper functions untuk konversi yang aman
    int toInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Product(
      id: toInt(json['id'], 0),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      // ✅ Perbaikan: Handle jika price datang sebagai String
      price: parseDouble(json['price']),
      stock: toInt(json['stock'], 0),
      images: json['images']?.toString(),
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
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
      'images': images,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Get list of image URLs
  List<String> get imageList {
    if (images == null || images!.isEmpty) return [];
    return images!.split(',').map((e) => e.trim()).toList();
  }

  String? get primaryImage {
    final imgs = imageList;
    return imgs.isNotEmpty ? imgs.first : null;
  }

  bool get isInStock => stock > 0;
  bool get isLowStock => stock > 0 && stock <= 10;
}
