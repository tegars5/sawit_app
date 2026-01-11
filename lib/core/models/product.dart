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
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      // ✅ Perbaikan: Handle jika price datang sebagai String
      price: json['price'] != null
          ? (json['price'] is String
              ? (double.tryParse(json['price']) ?? 0.0)
              : (json['price'] as num).toDouble())
          : 0.0,
      stock: json['stock'] as int? ?? 0,
      images: json['images'] as String?,
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
