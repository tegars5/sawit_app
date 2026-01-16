import 'package:flutter/material.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/order.dart';
import '../../../core/services/location_service.dart';

class DriverOrderProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  late final LocationService _locationService;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;
  bool _isAvailable = false;
  bool _isTrackingLocation = false;

  DriverOrderProvider() {
    _locationService = LocationService(_apiClient);
  }

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAvailable => _isAvailable;
  bool get isTrackingLocation => _isTrackingLocation;

  void setToken(String token) {
    _apiClient.setToken(token);
  }

  /// Initialize token from SharedPreferences
  Future<void> initializeToken() async {
    await _apiClient.initializeToken();
  }

  Future<void> loadOrders() async {
    try {
      print('🔍 DEBUG PROVIDER: Starting loadOrders...');
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiClient.getDriverOrders();
      print('🔍 DEBUG PROVIDER: Response received');
      print('🔍 DEBUG PROVIDER: Response data length: ${response.data.length}');

      _orders = response.data;
      print('🔍 DEBUG PROVIDER: Orders set to provider: ${_orders.length}');

      if (_orders.isNotEmpty) {
        print(
            '🔍 DEBUG PROVIDER: First order code: ${_orders.first.orderCode}');
        print('🔍 DEBUG PROVIDER: First order status: ${_orders.first.status}');
      }

      _isLoading = false;
      notifyListeners();
      print('🔍 DEBUG PROVIDER: loadOrders completed successfully');
    } catch (e) {
      print('🔍 DEBUG PROVIDER: Error occurred: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update order status dengan endpoint baru
  /// Otomatis trigger GPS tracking jika status = 'on_delivery'
  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      print('🚀 Updating order #$orderId to status: $status');

      // Update status di backend (response tidak digunakan karena kita reload semua data)
      await _apiClient.updateDriverOrderStatus(orderId, status);

      print('✅ Status update success, waiting for Google API calculation...');

      // Beri jeda 2 detik agar Backend selesai menghitung jarak dengan Google
      await Future.delayed(Duration(seconds: 2));

      print('🔄 Reloading orders data...');

      // Reload orders untuk mendapatkan data terbaru termasuk distance_km dan estimated_minutes
      await loadOrders();

      // Cek apakah distance_km sudah terisi
      final updatedOrder = _orders.firstWhere(
        (order) => order.id == orderId,
        orElse: () => _orders.first,
      );

      if (updatedOrder.distanceKm != null) {
        print('✅ Distance calculated: ${updatedOrder.distanceKm} km');
        print('✅ Estimated time: ${updatedOrder.estimatedMinutes} minutes');
      } else {
        print('⚠️ Warning: distance_km still null after update');
        print('   Check Laravel logs for Google API errors');
      }

      // Jika status on_delivery, mulai tracking GPS
      if (status == 'on_delivery') {
        await startLocationTracking(orderId);
      } else if (status == 'delivered' || status == 'cancelled') {
        stopLocationTracking();
      }

      return true;
    } catch (e) {
      print('❌ Error updating status: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Legacy method - gunakan updateOrderStatus untuk endpoint baru
  @Deprecated('Use updateOrderStatus instead')
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

  /// Start GPS location tracking untuk order tertentu
  Future<bool> startLocationTracking(int orderId) async {
    final success = await _locationService.startTracking(orderId);
    if (success) {
      _isTrackingLocation = true;
      notifyListeners();
      print('🚚 GPS Tracking started for order #$orderId');
    } else {
      _error = 'Gagal memulai tracking GPS. Periksa izin lokasi.';
      notifyListeners();
    }
    return success;
  }

  /// Stop GPS location tracking
  void stopLocationTracking() {
    _locationService.stopTracking();
    _isTrackingLocation = false;
    notifyListeners();
    print('🛑 GPS Tracking stopped');
  }

  /// Update location ke server (untuk real-time tracking)
  Future<bool> updateOrderLocation(int orderId, double lat, double lng) async {
    try {
      await _apiClient.updateOrderLocation(
        orderId: orderId,
        lat: lat,
        lng: lng,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Legacy method untuk backward compatibility
  @Deprecated('Use updateOrderLocation instead')
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

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }
}
