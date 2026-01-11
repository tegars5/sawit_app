import 'package:flutter/material.dart';
import '../../../config/app_config.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/models/product.dart';

class ProductProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<Product> _products = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMore = true;

  // Search/Filter state
  String? _searchQuery;
  String? _selectedCategory;
  double? _minPrice;
  double? _maxPrice;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  bool get hasMore => _hasMore;
  String? get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;

  void setToken(String token) {
    _apiClient.setToken(token);
  }

  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _products = [];
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      PaginatedResponse<Product> response;

      if (_searchQuery != null ||
          _selectedCategory != null ||
          _minPrice != null ||
          _maxPrice != null) {
        response = await _apiClient.searchProducts(
          query: _searchQuery,
          category: _selectedCategory,
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          page: _currentPage,
          perPage: AppConfig.pageSize,
        );
      } else {
        response = await _apiClient.getProducts(
          page: _currentPage,
          perPage: AppConfig.pageSize,
        );
      }

      if (refresh) {
        _products = response.data;
      } else {
        _products.addAll(response.data);
      }

      _currentPage = response.currentPage;
      _totalPages = response.lastPage;
      _hasMore = response.hasNextPage;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_hasMore && !_isLoading) {
      _currentPage++;
      await loadProducts();
    }
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query.isEmpty ? null : query;
    await loadProducts(refresh: true);
  }

  Future<void> filterByCategory(String? category) async {
    _selectedCategory = category;
    await loadProducts(refresh: true);
  }

  Future<void> filterByPrice(double? min, double? max) async {
    _minPrice = min;
    _maxPrice = max;
    await loadProducts(refresh: true);
  }

  void clearFilters() {
    _searchQuery = null;
    _selectedCategory = null;
    _minPrice = null;
    _maxPrice = null;
    loadProducts(refresh: true);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
