import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/product.dart';
import '../../../core/models/paginated_response.dart';

class AdminProductListScreen extends StatefulWidget {
  const AdminProductListScreen({super.key});

  @override
  State<AdminProductListScreen> createState() => _AdminProductListScreenState();
}

class _AdminProductListScreenState extends State<AdminProductListScreen> {
  final ApiClient _apiClient = ApiClient();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _products.clear();
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final token = await StorageService.getToken();
      if (token != null) {
        _apiClient.setToken(token);
      }

      final response = await _apiClient.getProducts(page: _currentPage);

      setState(() {
        if (refresh) {
          _products = response.data;
        } else {
          _products.addAll(response.data);
        }
        _hasMore = response.hasNextPage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _currentPage++;
    await _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        actions: [
          IconButton(
            onPressed: () => _loadProducts(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadProducts(refresh: true),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _products.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 64, color: AppColors.textSecondary),
                          SizedBox(height: 16),
                          Text('No products found'),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadProducts(refresh: true),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _products.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _products.length) {
                            _loadMore();
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final product = _products[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: product.primaryImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        product.primaryImage!,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 60,
                                          height: 60,
                                          color: AppColors.surfaceVariant,
                                          child: const Icon(Icons.image),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.inventory_2),
                                    ),
                              title: Text(product.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.category),
                                  Text(
                                    'Rp ${product.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: product.isInStock
                                              ? AppColors.success
                                                  .withOpacity(0.1)
                                              : AppColors.error
                                                  .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          product.isInStock
                                              ? 'In Stock'
                                              : 'Out of Stock',
                                          style: TextStyle(
                                            color: product.isInStock
                                                ? AppColors.success
                                                : AppColors.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Stock: ${product.stock}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      if (value == 'edit') {
                                        final result =
                                            await Navigator.pushNamed(
                                          context,
                                          '/admin/product-form',
                                          arguments: product,
                                        );
                                        if (result == true) {
                                          _loadProducts(refresh: true);
                                        }
                                      } else if (value == 'delete') {
                                        _showDeleteDialog(product);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                size: 20,
                                                color: AppColors.error),
                                            SizedBox(width: 8),
                                            Text('Delete',
                                                style: TextStyle(
                                                    color: AppColors.error)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () {
                                // TODO: Navigate to product detail/edit
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Edit product: ${product.name}'),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(
            context,
            '/admin/product-form',
          );
          if (result == true) {
            _loadProducts(refresh: true);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  void _showDeleteDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteProduct(product);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    try {
      setState(() => _isLoading = true);

      final token = await StorageService.getToken();
      if (token != null) {
        _apiClient.setToken(token);
      }

      await _apiClient.deleteProduct(product.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product deleted successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadProducts(refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
