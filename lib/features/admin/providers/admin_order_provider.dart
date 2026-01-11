import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/models/paginated_response.dart';
import '../../../config/app_config.dart';

class AdminOrderProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _statusFilter;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  void setToken(String token) {
    _apiClient.setToken(token);
  }

  Future<void> loadOrders({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _orders = [];
      _hasMore = true;
    }

    if (_isLoading || !_hasMore) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiClient.getAdminOrders(
        page: _currentPage,
        perPage: AppConfig.pageSize,
        status: _statusFilter,
      );

      if (refresh) {
        _orders = response.data;
      } else {
        _orders.addAll(response.data);
      }

      _currentPage = response.currentPage;
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
      await loadOrders();
    }
  }

  Future<void> filterByStatus(String? status) async {
    _statusFilter = status;
    await loadOrders(refresh: true);
  }

  Future<bool> approveOrder(int orderId) async {
    try {
      await _apiClient.approveOrder(orderId);
      await loadOrders(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignDriver(int orderId, int driverId) async {
    try {
      await _apiClient.assignDriver(orderId, driverId);
      await loadOrders(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
