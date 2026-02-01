import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../config/theme.dart';
import '../../../core/models/product.dart';
import '../../../core/api/api_client.dart';
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
  late Product _product;
  bool _isLoading = false;
  int _quantity = 1;
  final ApiClient _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _fetchProduct();
  }

  Future<void> _fetchProduct() async {
    setState(() => _isLoading = true);
    try {
      await _apiClient.initializeToken();
      final updatedProduct = await _apiClient.getProduct(_product.id);
      if (mounted) {
        setState(() {
          _product = updatedProduct;
          // Adjust quantity if stock is lower than current quantity
          if (_quantity > _product.stock) {
            _quantity = _product.stock > 0 ? _product.stock : 1;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching product: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final cartProvider = context.watch<CartProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchProduct,
        child: CustomScrollView(
          slivers: [
            // App Bar with Image
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    (_product.primaryImage != null &&
                            _product.primaryImage!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: _product.primaryImage!,
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
                    // Gradient overlay for better text visibility if needed
                  ],
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
                        _product.category.toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Product Name
                    Text(
                      _product.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),

                    // Price
                    Text(
                      currencyFormat.format(_product.price),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),

                    // Stock Status
                    Row(
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        Icon(
                          _product.isInStock
                              ? Icons.check_circle
                              : Icons.cancel,
                          size: 20,
                          color: _product.isInStock
                              ? AppColors.success
                              : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _product.isInStock
                              ? 'In Stock (${_product.stock} units)'
                              : 'Out of Stock',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: _product.isInStock
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
                      _product.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // Quantity Selector
                    if (_product.isInStock) ...[
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
                            onPressed: _quantity < _product.stock
                                ? () => setState(() => _quantity++)
                                : null,
                            icon: const Icon(Icons.add),
                          ),
                          const Spacer(),
                          Text(
                            'Total: ${currencyFormat.format(_product.price * _quantity)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
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
      ),

      // Bottom Action Bar
      bottomNavigationBar: _product.isInStock
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
                    cartProvider.addItem(_product, quantity: _quantity);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '$_quantity x ${_product.name} added to cart',
                        ),
                        action: SnackBarAction(
                          label: 'VIEW CART',
                          onPressed: () {
                            // Usually navigate to cart here, but user previous implementation was pop?
                            // Assuming pop is correct for their flow if Cart is previous screen.
                            // But standard is pushing CartScreen.
                            // Keeping original behavior: pop.
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
