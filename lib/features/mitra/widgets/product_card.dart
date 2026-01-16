import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/models/product.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Stock Badge
              Stack(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.2,
                      child: (product.primaryImage != null &&
                              product.primaryImage!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImage!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey[200]!,
                                      Colors.grey[300]!,
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.surfaceVariant,
                                      Colors.grey[300]!,
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 48,
                                  color: AppColors.textHint,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primaryLight,
                                    AppColors.primary,
                                  ],
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.eco,
                                  size: 56,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                  ),

                  // Stock Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: product.isInStock
                            ? AppColors.success
                            : AppColors.error,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        product.isInStock ? 'Stock: ${product.stock}' : 'Habis',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Product Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          product.category.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Product Name
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),

                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.payments,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                currencyFormat.format(product.price),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Add to Cart Button
              if (onAddToCart != null && product.isInStock)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: onAddToCart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_shopping_cart, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
