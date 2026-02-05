import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tracking_response.dart';
import '../../config/app_config.dart';
import 'storage_service.dart';

class OrderService {
  String? _errorMessage;

  String? get error => _errorMessage;

  /// Get order tracking information
  /// Returns TrackingResponse or null if error
  Future<TrackingResponse?> getOrderTracking(int orderId) async {
    try {
      _errorMessage = null;
      final token = StorageService.getToken();

      if (token == null) {
        _errorMessage = 'No authentication token found';
        return null;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/tracking'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TrackingResponse.fromJson(data);
      } else if (response.statusCode == 403) {
        _errorMessage = 'Unauthorized to view this tracking';
        return null;
      } else if (response.statusCode == 404) {
        _errorMessage = 'Order not found';
        return null;
      } else {
        _errorMessage = 'Failed to load tracking';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      return null;
    }
  }

  /// Update driver location (for driver role)
  /// Returns true if successful, false otherwise
  Future<bool> updateDriverLocation(int orderId, double lat, double lng) async {
    try {
      _errorMessage = null;
      final token = StorageService.getToken();

      if (token == null) {
        _errorMessage = 'No authentication token found';
        return false;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/update-location'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'lat': lat,
          'lng': lng,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else if (response.statusCode == 403) {
        final data = json.decode(response.body);
        _errorMessage =
            data['message'] ?? 'Unauthorized. You are not the assigned driver';
        return false;
      } else if (response.statusCode == 404) {
        final data = json.decode(response.body);
        _errorMessage = data['message'] ?? 'Delivery order not found';
        return false;
      } else {
        _errorMessage = 'Failed to update location';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      return false;
    }
  }

  /// Cancel order with refund logic
  /// Returns order data if successful, null otherwise
  Future<Map<String, dynamic>?> cancelOrder(int orderId) async {
    try {
      _errorMessage = null;
      final token = StorageService.getToken();

      if (token == null) {
        _errorMessage = 'No authentication token found';
        return null;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        _errorMessage = data['message'] ?? 'Cannot cancel order';
        return null;
      } else if (response.statusCode == 403) {
        _errorMessage = 'Unauthorized to cancel this order';
        return null;
      } else {
        _errorMessage = 'Failed to cancel order';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      return null;
    }
  }

  /// Get order list with filters
  Future<Map<String, dynamic>?> getOrders({
    int page = 1,
    int perPage = 15,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      _errorMessage = null;
      final token = StorageService.getToken();

      if (token == null) {
        _errorMessage = 'No authentication token found';
        return null;
      }

      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;

      final uri = Uri.parse('${AppConfig.baseUrl}/orders')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        _errorMessage = 'Failed to load orders';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      return null;
    }
  }

  /// Get single order detail
  Future<Map<String, dynamic>?> getOrderDetail(int orderId) async {
    try {
      _errorMessage = null;
      final token = StorageService.getToken();

      if (token == null) {
        _errorMessage = 'No authentication token found';
        return null;
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 403) {
        _errorMessage = 'Unauthorized to view this order';
        return null;
      } else if (response.statusCode == 404) {
        _errorMessage = 'Order not found';
        return null;
      } else {
        _errorMessage = 'Failed to load order';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      return null;
    }
  }

  /// Returns success response if within radius, error if too far
  Future<Map<String, dynamic>?> completeDelivery({
    required int orderId,
    required double currentLat,
    required double currentLng,
  }) async {
    try {
      _errorMessage = null;
      final token = StorageService.getToken();

      if (token == null) {
        _errorMessage = 'No authentication token found';
        return null;
      }

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/driver/orders/$orderId/complete'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'lat': currentLat,
          'lng': currentLng,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 400) {
        // Geofencing validation failed - driver too far from destination
        final data = json.decode(response.body);
        _errorMessage = data['message'] ?? 'Anda belum sampai di lokasi tujuan';
        return data; // Return data with distance info
      } else if (response.statusCode == 404) {
        final data = json.decode(response.body);
        _errorMessage = data['message'] ?? 'Pesanan tidak ditemukan';
        return null;
      } else if (response.statusCode == 500) {
        _errorMessage = 'Terjadi kesalahan sistem';
        return null;
      } else {
        _errorMessage = 'Failed to complete delivery';
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error: ${e.toString()}';
      return null;
    }
  }
}
