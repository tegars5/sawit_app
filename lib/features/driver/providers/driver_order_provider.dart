import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';

class DriverOrderProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  bool _isAvailable = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAvailable => _isAvailable;

  void setToken(String token) {
    _apiClient.setToken(token);
  }

  Future<void> loadOrders() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiClient.getDriverOrders();
      _orders = response.data;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDeliveryStatus(int deliveryOrderId, String status) async {
    try {
      await _apiClient.updateDeliveryStatus(deliveryOrderId, status);
      await loadOrders();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateLocation(
      int deliveryOrderId, double lat, double lng) async {
    try {
      await _apiClient.updateDriverLocation(deliveryOrderId, lat, lng);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleAvailability(bool available) async {
    try {
      // Convert bool to string: 'available' or 'unavailable'
      final status = available ? 'available' : 'unavailable';
      await _apiClient.updateDriverAvailability(status);
      _isAvailable = available;
      notifyListeners();
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
