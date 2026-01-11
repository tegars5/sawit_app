import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/models/product.dart';
import '../providers/cart_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final cartProvider = context.watch<CartProvider>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: (widget.product.primaryImage != null &&
                      widget.product.primaryImage!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: widget.product.primaryImage!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: AppColors.textHint,
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(
                        Icons.eco,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),

          // Product Details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.product.category.toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product Name
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Text(
                    currencyFormat.format(widget.product.price),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // Stock Status
                  Row(
                    children: [
                      Icon(
                        widget.product.isInStock
                            ? Icons.check_circle
                            : Icons.cancel,
                        size: 20,
                        color: widget.product.isInStock
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.product.isInStock
                            ? 'In Stock (${widget.product.stock} units)'
                            : 'Out of Stock',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: widget.product.isInStock
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 32),

                  // Quantity Selector
                  if (widget.product.isInStock) ...[
                    Text(
                      'Quantity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton.outlined(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            '$_quantity',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton.outlined(
                          onPressed: _quantity < widget.product.stock
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                        const Spacer(),
                        Text(
                          'Total: ${currencyFormat.format(widget.product.price * _quantity)}',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: widget.product.isInStock
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: () {
                    cartProvider.addItem(widget.product, quantity: _quantity);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$_quantity x ${widget.product.name} added to cart',
                        ),
                        action: SnackBarAction(
                          label: 'VIEW CART',
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to Cart'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
