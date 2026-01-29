import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/driver.dart';
import '../models/paginated_response.dart';
import '../models/tracking_response.dart';
import '../models/payment_response.dart';

class ApiClient {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  /// Initialize token from SharedPreferences
  /// Call this before making API requests to ensure token is loaded
  Future<bool> initializeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null && token.isNotEmpty) {
        _token = token;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error initializing token: $e');
      return false;
    }
  }

  /// Check if user is authenticated (has token)
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ========== AUTH APIs ==========

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/register'),
          headers: _headers,
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
            'password_confirmation': passwordConfirmation,
          }),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 201) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<AuthResponse> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/login'),
          headers: _headers,
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<User> getCurrentUser() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/me'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<void> logout() async {
    await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/logout'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));
  }

  // ========== PROFILE APIs ==========

  Future<User> getProfile() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/profile'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  Future<User> updateProfile(Map<String, dynamic> data) async {
    final response = await http
        .put(
          Uri.parse('${AppConfig.baseUrl}/profile'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return User.fromJson(json['user']);
    }
    throw _handleError(response);
  }

  Future<void> changePassword(Map<String, dynamic> data) async {
    final response = await http
        .put(
          Uri.parse('${AppConfig.baseUrl}/profile/password'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/fcm-token'),
          headers: _headers,
          body: jsonEncode({'fcm_token': fcmToken}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));
  }

  // ========== PRODUCT APIs ==========

  Future<PaginatedResponse<Product>> getProducts({
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse(
              '${AppConfig.baseUrl}/products?page=$page&per_page=$perPage'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Product>.fromJson(
        jsonDecode(response.body),
        (json) => Product.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<PaginatedResponse<Product>> searchProducts({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int perPage = 15,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty) 'category': category,
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/products/search')
        .replace(queryParameters: queryParams);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Product>.fromJson(
        jsonDecode(response.body),
        (json) => Product.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<Product> getProduct(int productId) async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/products/$productId'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  /// Create new product (Admin only)
  Future<Product> createProduct(
    Map<String, dynamic> productData, {
    File? imageFile,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/admin/products'),
    );

    request.headers.addAll({
      'Authorization': _headers['Authorization']!,
      'Accept': 'application/json',
    });

    request.fields['name'] = productData['name'].toString();
    request.fields['description'] = productData['description'].toString();
    request.fields['category'] = productData['category'].toString();
    request.fields['price'] = productData['price'].toString();
    request.fields['stock'] = productData['stock'].toString();

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Product.fromJson(json['product']);
    }
    throw _handleError(response);
  }

  /// Update product (Admin only)
  Future<Product> updateProduct(
    int productId,
    Map<String, dynamic> productData, {
    File? imageFile,
  }) async {
    // Use POST for multipart compatibility
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/admin/products/$productId'),
    );

    request.headers.addAll({
      'Authorization': _headers['Authorization'] ?? '',
      'Accept': 'application/json',
    });
    // Add product data
    request.fields['name'] = productData['name'].toString();
    request.fields['description'] = productData['description'].toString();
    request.fields['category'] = productData['category'].toString();
    request.fields['price'] = productData['price'].toString();
    request.fields['stock'] = productData['stock'].toString();

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image_file', imageFile.path),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Product.fromJson(json['product']);
    }
    throw _handleError(response);
  }

  /// Delete product (Admin only)
  Future<void> deleteProduct(int productId) async {
    final response = await http
        .delete(
          Uri.parse('${AppConfig.baseUrl}/admin/products/$productId'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  // ========== ORDER APIs ==========

  Future<PaginatedResponse<Order>> getOrders({
    int page = 1,
    int perPage = 15,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (dateFrom != null && dateFrom.isNotEmpty) 'date_from': dateFrom,
      if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/orders')
        .replace(queryParameters: queryParams);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Order>.fromJson(
        jsonDecode(response.body),
        (json) => Order.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<Order> getOrder(int orderId) async {
    print('📡 API: GET /orders/$orderId');
    print('📋 Headers: ${_headers.keys.toList()}');
    print('🔑 Has Authorization: ${_headers.containsKey('Authorization')}');

    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    print('📥 Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      return Order.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  // ✅ Admin-specific order detail endpoint
  Future<Order> getAdminOrder(int orderId) async {
    print('📡 API: GET /admin/orders/$orderId (ADMIN)');
    print('📋 Headers: ${_headers.keys.toList()}');
    print('🔑 Has Authorization: ${_headers.containsKey('Authorization')}');

    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/admin/orders/$orderId'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    print('📥 Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      // Backend returns { success: true, data: order }
      if (jsonData['data'] != null) {
        return Order.fromJson(jsonData['data']);
      }
      return Order.fromJson(jsonData);
    }
    throw _handleError(response);
  }

  Future<Map<String, dynamic>> initiateCheckoutPayment({
    required String destinationAddress,
    required double destinationLat,
    required double destinationLng,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/payments/initiate-checkout'),
          headers: _headers,
          body: jsonEncode({
            'destination_address': destinationAddress,
            'destination_lat': destinationLat,
            'destination_lng': destinationLng,
            'items': items,
            'payment_method': paymentMethod,
          }),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _handleError(response);
  }

  Future<Order> createOrder(Map<String, dynamic> data) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders'),
          headers: _headers,
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 201) {
      // Debug: Print response to see structure
      print('=== CREATE ORDER RESPONSE ===');
      print(response.body);
      print('============================');

      final jsonResponse = jsonDecode(response.body);
      return Order.fromJson(jsonResponse);
    }
    throw _handleError(response);
  }

  Future<Order> cancelOrder(int orderId) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId/cancel'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return Order.fromJson(json['order']);
    }
    throw _handleError(response);
  }

  // ========== DRIVER APIs ==========

  /// Fetch available drivers for assignment
  Future<List<Driver>> getAvailableDrivers() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/admin/drivers/available'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((json) => Driver.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw _handleError(response);
  }

  /// Assign driver to order (Auto-generate waybill PDF)
  ///
  /// ✅ UPDATED: No PDF upload required, backend auto-generates from database
  /// Backend: POST /api/admin/orders/{orderId}/assign-driver
  /// Body: { "driver_id": int }
  Future<Order> assignDriver(int orderId, int driverId) async {
    // Ensure token is initialized
    if (_token == null) await initializeToken();

    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/admin/orders/$orderId/assign-driver'),
          headers: _headers,
          body: jsonEncode({
            'driver_id': driverId,
          }),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      // Check response structure
      if (jsonData != null) {
        if (jsonData['data'] != null) {
          return Order.fromJson(jsonData['data']);
        } else if (jsonData['order'] != null) {
          return Order.fromJson(jsonData['order']);
        }
      }

      // If data not found in response, reload order
      throw Exception('Data order tidak ditemukan dalam respon server');
    }

    throw _handleError(response);
  }

  /// Get waybill PDF URL for order
  String getWaybillPdfUrl(int orderId) {
    return '${AppConfig.baseUrl}/orders/$orderId/waybill/pdf';
  }

  // ========== TRACKING API ==========

  Future<TrackingResponse> getOrderTracking(int orderId) async {
    try {
      // Kita gunakan _headers yang sudah otomatis menyertakan _token jika ada
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/orders/$orderId/tracking'),
        headers: _headers, // 👈 Gunakan ini, jangan buat Map baru manual
      );

      print("📡 API Tracking Status: ${response.statusCode}");
      print(
          "🔑 Header Digunakan: $_headers"); // Debug untuk memastikan token ada

      if (response.statusCode == 200) {
        return TrackingResponse.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Gagal memuat data tracking. Status: ${response.statusCode}');
      }
    } catch (e) {
      print("❌ Error API Client: $e");
      rethrow;
    }
  }

  // ========== PAYMENT API ==========

  Future<PaymentResponse> createPayment(int orderId) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId/pay'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaymentResponse.fromJson(jsonDecode(response.body));
    }
    throw _handleError(response);
  }

  // ========== ADMIN APIs ==========

  Future<Map<String, dynamic>> getAdminDashboard() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/admin/dashboard-summary'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _handleError(response);
  }

  Future<PaginatedResponse<Order>> getAdminOrders({
    int page = 1,
    int perPage = 20,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/admin/orders')
        .replace(queryParameters: queryParams);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<Order>.fromJson(
        jsonDecode(response.body),
        (json) => Order.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  Future<void> approveOrder(int orderId) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/admin/orders/$orderId/approve'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  Future<PaginatedResponse<User>> getDrivers({
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse(
              '${AppConfig.baseUrl}/admin/drivers?page=$page&per_page=$perPage'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      return PaginatedResponse<User>.fromJson(
        jsonDecode(response.body),
        (json) => User.fromJson(json),
      );
    }
    throw _handleError(response);
  }

  // ========== DRIVER APIs ==========

  Future<PaginatedResponse<Order>> getDriverOrders({
    int page = 1,
    int perPage = 15,
  }) async {
    final response = await http
        .get(
          Uri.parse(
              '${AppConfig.baseUrl}/driver/orders?page=$page&per_page=$perPage'),
          headers: _headers,
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    // 🔍 DEBUG: Print raw response
    print('🔍 DEBUG API: Status Code: ${response.statusCode}');
    print('🔍 DEBUG API: Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);

      // 🔍 DEBUG: Print parsed data structure
      print('🔍 DEBUG API: jsonData keys: ${jsonData.keys}');
      print('🔍 DEBUG API: Has "success"? ${jsonData.containsKey("success")}');
      print('🔍 DEBUG API: Has "data"? ${jsonData.containsKey("data")}');

      // Backend wraps response in { success: true, data: {...} }
      // Extract the actual paginated data
      final paginatedData = jsonData['data'] ?? jsonData;

      // 🔍 DEBUG: Print paginated data structure
      print('🔍 DEBUG API: paginatedData keys: ${paginatedData.keys}');
      if (paginatedData.containsKey('total')) {
        print('🔍 DEBUG API: Total items: ${paginatedData["total"]}');
      }
      if (paginatedData.containsKey('data')) {
        print(
            '🔍 DEBUG API: Data array length: ${paginatedData["data"]?.length}');
      }

      try {
        return PaginatedResponse<Order>.fromJson(
          paginatedData,
          (json) {
            try {
              print('🔍 DEBUG PARSING: Parsing order ID ${json['id']}');
              return Order.fromJson(json);
            } catch (e, stackTrace) {
              print('🔍 DEBUG PARSING ERROR: Failed to parse order');
              print('🔍 DEBUG PARSING ERROR: JSON: $json');
              print('🔍 DEBUG PARSING ERROR: Error: $e');
              print('🔍 DEBUG PARSING ERROR: StackTrace: $stackTrace');
              rethrow;
            }
          },
        );
      } catch (e, stackTrace) {
        print('🔍 DEBUG API ERROR: Failed to create PaginatedResponse');
        print('🔍 DEBUG API ERROR: Error: $e');
        print('🔍 DEBUG API ERROR: StackTrace: $stackTrace');
        rethrow;
      }
    }
    throw _handleError(response);
  }

  Future<void> updateAvailability(String status) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/driver/availability'),
          headers: _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  /// Update order status by driver (New endpoint)
  /// Endpoint: POST /api/driver/orders/{orderId}/status
  /// Body: { "status": "on_delivery" | "arrived" | "completed" }
  Future<Map<String, dynamic>> updateDriverOrderStatus(
      int orderId, String status) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/driver/orders/$orderId/status'),
          headers: _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      return jsonData;
    }
    throw _handleError(response);
  }

  /// Update delivery status (Legacy endpoint - untuk backward compatibility)
  /// Gunakan updateDriverOrderStatus untuk endpoint baru
  @Deprecated('Use updateDriverOrderStatus instead')
  Future<void> updateDeliveryStatus(int deliveryId, String status) async {
    // Pastikan token terisi
    if (_token == null) await initializeToken();

    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/driver/orders/$deliveryId/status'),
          headers: _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200) {
      throw _handleError(response);
    }
  }

  /// Update lokasi driver ke tabel delivery_tracks (Endpoint Baru)
  Future<void> updateDriverLocation(int orderId, double lat, double lng) async {
    // Pastikan token terisi
    if (_token == null) await initializeToken();

    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/orders/$orderId/update-location'),
          headers: _headers,
          body: jsonEncode({'lat': lat, 'lng': lng}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleError(response);
    }
  }

  /// Update driver location for real-time tracking (Driver App)
  /// Update driver location during delivery
  ///
  /// ✅ FIXED: Changed endpoint to match backend driver tracking route
  /// Backend: POST /api/driver/orders/{id}/track (DriverOrderController@track)
  /// This endpoint saves tracking history to delivery_tracks table
  ///
  /// Endpoint: POST /api/driver/orders/{orderId}/track
  /// Body: { "lat": double, "lng": double }
  Future<void> updateOrderLocation({
    required int orderId,
    required double lat,
    required double lng,
  }) async {
    // Ensure token is initialized
    if (_token == null) await initializeToken();

    final response = await http
        .post(
          // ✅ Use driver-specific endpoint that records tracking history
          Uri.parse('${AppConfig.baseUrl}/driver/orders/$orderId/track'),
          headers: _headers,
          body: jsonEncode({
            'lat': lat,
            'lng': lng,
          }),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeout));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _handleError(response);
    }
  }

  // ========== ALIAS METHODS (for backward compatibility) ==========

  /// Alias for getOrderTracking
  Future<TrackingResponse> trackOrder(int orderId) => getOrderTracking(orderId);

  /// Alias for createPayment
  Future<PaymentResponse> processPayment(
      int orderId, String paymentMethod) async {
    // For now, just call createPayment. In future, can pass paymentMethod
    return createPayment(orderId);
  }

  /// Alias for updateAvailability
  Future<void> updateDriverAvailability(String status) async {
    return updateAvailability(status);
  }

  // ========== ERROR HANDLING ==========

  Exception _handleError(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      final message = json['message'] ?? 'An error occurred';
      return Exception('Error ${response.statusCode}: $message');
    } catch (e) {
      return Exception('Error ${response.statusCode}: ${response.body}');
    }
  }
}
