import 'product.dart';

class OrderItem {
  final int id;
  final int orderId;
  final int productId;
  final int quantity;
  final double price;
  final double subtotal;
  final Product? product;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.product,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Fungsi helper lokal untuk parsing double secara aman
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return OrderItem(
      id: json['id'] as int,
      orderId: json['order_id'] as int,
      productId: json['product_id'] as int,
      quantity: json['quantity'] as int,
      // ✅ Perbaikan: Gunakan parseDouble
      price: parseDouble(json['price']),
      subtotal: parseDouble(json['subtotal']),
      product: json['product'] != null
          ? Product.fromJson(json['product'] as Map<String, dynamic>)
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
