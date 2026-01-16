import 'product.dart';

class OrderItem {
  final int id;
  final int?
      orderId; // ✅ Made optional - backend doesn't send this in driver orders
  final int productId;
  final int quantity;
  final double price;
  final double subtotal;
  final Product? product;

  OrderItem({
    required this.id,
    this.orderId, // ✅ Now optional
    required this.productId,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Fungsi helper lokal untuk parsing secara aman
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

    return OrderItem(
      id: toInt(json['id'], 0),
      orderId: json['order_id'] != null ? toInt(json['order_id'], 0) : null,
      productId: toInt(json['product_id'], 0),
      quantity: toInt(json['quantity'], 0),
      // ✅ Perbaikan: Gunakan parseDouble
      price: parseDouble(json['price']),
      subtotal: parseDouble(json['subtotal']),
      product: json['product'] != null
          ? Product.fromJson(json['product'] is Map<String, dynamic>
              ? json['product']
              : Map<String, dynamic>.from(json['product'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      'product': product?.toJson(),
    };
  }
}
